import { spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "codex-quota";
const CODEX_PROVIDER = "openai-codex";
const REFRESH_INTERVAL_MS = 5 * 60_000;
const REQUEST_TIMEOUT_MS = 10_000;

type CodexRateLimitWindow = {
  usedPercent?: number;
  windowDurationMins?: number | null;
  resetsAt?: number | null;
};

type CodexRateLimitSnapshot = {
  primary?: CodexRateLimitWindow | null;
  secondary?: CodexRateLimitWindow | null;
  planType?: string | null;
};

type CodexRateLimitsResult = {
  rateLimits?: CodexRateLimitSnapshot;
  rateLimitsByLimitId?: Record<string, CodexRateLimitSnapshot | undefined> | null;
  rateLimitResetCredits?: {
    availableCount?: number;
  } | null;
};

type CodexQuota = {
  rateLimits: CodexRateLimitSnapshot;
  availableResetCredits: number;
  fetchedAt: number;
};

type RpcMessage = {
  id?: number;
  result?: CodexRateLimitsResult;
  error?: {
    message?: string;
  };
};

let quotaTimer: ReturnType<typeof setInterval> | undefined;
let activeCtx: ExtensionContext | undefined;
let activeRequest: AbortController | undefined;
let refreshInFlight: Promise<void> | undefined;
let latestQuota: CodexQuota | undefined;
let latestError: string | undefined;

function isCodexModel(model: ExtensionContext["model"]): boolean {
  return model?.provider === CODEX_PROVIDER;
}

function remainingPercent(window: CodexRateLimitWindow): number | undefined {
  const used = window.usedPercent;
  if (typeof used !== "number" || !Number.isFinite(used)) return undefined;
  return Math.max(0, Math.min(100, Math.round(100 - used)));
}

function windowLabel(window: CodexRateLimitWindow, fallback: string): string {
  const minutes = window.windowDurationMins;
  if (typeof minutes !== "number" || !Number.isFinite(minutes) || minutes <= 0) return fallback;
  if (minutes === 10_080) return "weekly";
  if (minutes % 1_440 === 0) return `${minutes / 1_440}d`;
  if (minutes % 60 === 0) return `${minutes / 60}h`;
  return `${minutes}m`;
}

function quotaText(quota: CodexQuota): string {
  const windows = [
    { window: quota.rateLimits.primary, fallback: "primary" },
    { window: quota.rateLimits.secondary, fallback: "secondary" },
  ]
    .filter((entry): entry is { window: CodexRateLimitWindow; fallback: string } => Boolean(entry.window))
    .sort((a, b) => (a.window.windowDurationMins ?? Number.MAX_SAFE_INTEGER) - (b.window.windowDurationMins ?? Number.MAX_SAFE_INTEGER));

  const parts = windows.flatMap(({ window, fallback }) => {
    const left = remainingPercent(window);
    return left === undefined ? [] : [`${windowLabel(window, fallback)} ${left}% left`];
  });

  if (quota.availableResetCredits === 1) parts.push("1 reset available");
  if (quota.availableResetCredits > 1) parts.push(`${quota.availableResetCredits} resets available`);
  return parts.join(" · ") || "quota unavailable";
}

type RpcAction =
  | { kind: "initialized" }
  | { kind: "quota"; quota: CodexQuota }
  | { kind: "error"; error: Error };

function decodeRpcAction(line: string): RpcAction | undefined {
  let message: RpcMessage;
  try {
    message = JSON.parse(line) as RpcMessage;
  } catch {
    return undefined;
  }

  if (message.id === 1) {
    return message.error
      ? { kind: "error", error: new Error(message.error.message ?? "Codex app-server initialization failed") }
      : { kind: "initialized" };
  }
  if (message.id !== 2) return undefined;
  if (message.error) {
    return { kind: "error", error: new Error(message.error.message ?? "Codex rate-limit request failed") };
  }

  const result = message.result;
  const rateLimits = result?.rateLimitsByLimitId?.codex ?? result?.rateLimits;
  if (!rateLimits) {
    return { kind: "error", error: new Error("Codex rate-limit response did not include the codex quota") };
  }

  return {
    kind: "quota",
    quota: {
      rateLimits,
      availableResetCredits: Math.max(0, result?.rateLimitResetCredits?.availableCount ?? 0),
      fetchedAt: Date.now(),
    },
  };
}

function startCodexQuotaRequest(
  signal: AbortSignal,
  resolve: (quota: CodexQuota) => void,
  reject: (error: Error) => void,
): void {
  const child = spawn("codex", ["app-server", "--stdio"], {
    stdio: ["pipe", "pipe", "pipe"],
  });
  let settled = false;
  let outputBuffer = "";
  let stderr = "";

  const cleanup = (): void => {
    clearTimeout(timeout);
    signal.removeEventListener("abort", onAbort);
    if (!child.killed) child.kill();
  };

  const finish = (error?: Error, quota?: CodexQuota): void => {
    if (settled) return;
    settled = true;
    cleanup();
    if (error) reject(error);
    else if (quota) resolve(quota);
    else reject(new Error("Codex quota request completed without data"));
  };

  const send = (message: object): void => {
    try {
      child.stdin.write(`${JSON.stringify(message)}\n`);
    } catch (error) {
      finish(error instanceof Error ? error : new Error(String(error)));
    }
  };

  const onAbort = (): void => finish(new Error("Codex quota request aborted"));
  const timeout = setTimeout(
    () => finish(new Error(`Codex quota request timed out after ${REQUEST_TIMEOUT_MS / 1000}s`)),
    REQUEST_TIMEOUT_MS,
  );

  signal.addEventListener("abort", onAbort, { once: true });
  child.on("error", (error) => finish(error));
  child.stdin.on("error", (error) => finish(error));
  child.on("exit", (code, exitSignal) => {
    if (settled) return;
    const detail = stderr.trim() || `exit ${code ?? exitSignal ?? "unknown"}`;
    finish(new Error(`Codex app-server stopped before returning quota data: ${detail}`));
  });
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk: string) => {
    if (stderr.length < 2_000) stderr += chunk;
  });
  child.stdout.setEncoding("utf8");
  child.stdout.on("data", (chunk: string) => {
    outputBuffer += chunk;
    const lines = outputBuffer.split("\n");
    outputBuffer = lines.pop() ?? "";

    for (const rawLine of lines) {
      const action = decodeRpcAction(rawLine.trim());
      if (!action) continue;
      if (action.kind === "error") {
        finish(action.error);
        return;
      }
      if (action.kind === "quota") {
        finish(undefined, action.quota);
        return;
      }
      send({ method: "initialized", params: {} });
      send({ method: "account/rateLimits/read", id: 2 });
    }
  });

  send({
    method: "initialize",
    id: 1,
    params: {
      clientInfo: {
        name: "pi_codex_status",
        title: "Pi Codex Status",
        version: "1.0.0",
      },
      capabilities: {
        optOutNotificationMethods: ["account/rateLimits/updated"],
      },
    },
  });
}

function queryCodexQuota(signal: AbortSignal): Promise<CodexQuota> {
  return new Promise((resolve, reject) => startCodexQuotaRequest(signal, resolve, reject));
}

function publishQuotaStatus(ctx: ExtensionContext): void {
  if (!isCodexModel(ctx.model)) {
    ctx.ui.setStatus(STATUS_KEY, undefined);
    return;
  }

  if (latestQuota) {
    const stale = latestError ? " · stale" : "";
    ctx.ui.setStatus(STATUS_KEY, `${quotaText(latestQuota)}${stale}`);
    return;
  }

  ctx.ui.setStatus(STATUS_KEY, latestError ? "quota unavailable" : "quota loading…");
}

function refreshQuotaStatus(ctx: ExtensionContext, force = false): Promise<void> {
  if (!isCodexModel(ctx.model)) {
    publishQuotaStatus(ctx);
    return Promise.resolve();
  }

  if (!force && latestQuota && Date.now() - latestQuota.fetchedAt < REFRESH_INTERVAL_MS) {
    publishQuotaStatus(ctx);
    return Promise.resolve();
  }

  if (refreshInFlight) return refreshInFlight;

  activeRequest?.abort();
  activeRequest = new AbortController();
  latestError = undefined;
  publishQuotaStatus(ctx);

  refreshInFlight = queryCodexQuota(activeRequest.signal)
    .then((quota) => {
      latestQuota = quota;
      latestError = undefined;
    })
    .catch((error) => {
      latestError = error instanceof Error ? error.message : String(error);
    })
    .finally(() => {
      refreshInFlight = undefined;
      activeRequest = undefined;
      if (activeCtx) publishQuotaStatus(activeCtx);
    });

  return refreshInFlight;
}

function startQuotaStatus(ctx: ExtensionContext): void {
  if (ctx.mode !== "tui") return;

  activeCtx = ctx;
  if (quotaTimer) clearInterval(quotaTimer);
  void refreshQuotaStatus(ctx, true);
  quotaTimer = setInterval(() => {
    if (activeCtx) void refreshQuotaStatus(activeCtx);
  }, REFRESH_INTERVAL_MS);
}

function stopQuotaStatus(): void {
  if (quotaTimer) clearInterval(quotaTimer);
  quotaTimer = undefined;
  activeRequest?.abort();
  activeRequest = undefined;
  refreshInFlight = undefined;
  activeCtx?.ui.setStatus(STATUS_KEY, undefined);
  activeCtx = undefined;
}

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => startQuotaStatus(ctx));
  pi.on("model_select", async (_event, ctx) => {
    if (isCodexModel(ctx.model)) void refreshQuotaStatus(ctx, true);
    else publishQuotaStatus(ctx);
  });
  pi.on("agent_settled", async (_event, ctx) => {
    if (isCodexModel(ctx.model)) void refreshQuotaStatus(ctx, true);
  });
  pi.on("session_shutdown", async () => stopQuotaStatus());

  pi.registerCommand("codex-status", {
    description: "Refresh and show live Codex quota status",
    handler: async (_args, ctx) => {
      if (!isCodexModel(ctx.model)) {
        ctx.ui.notify("Codex quota is only available for openai-codex models", "warning");
        return;
      }

      await refreshQuotaStatus(ctx, true);
      publishQuotaStatus(ctx);
      if (latestQuota && !latestError) {
        ctx.ui.notify(`Live Codex quota: ${quotaText(latestQuota)}`, "info");
      } else {
        ctx.ui.notify(`Unable to read live Codex quota: ${latestError ?? "unknown error"}`, "warning");
      }
    },
  });
}
