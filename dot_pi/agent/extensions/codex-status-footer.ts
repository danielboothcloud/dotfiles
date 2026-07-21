import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const CONFIG_PATH = join(process.env.HOME ?? "", ".pi", "agent", "codex-status.json");
const CODEX_LOGS_DB = join(process.env.HOME ?? "", ".codex", "logs_2.sqlite");

type Config = {
  /** Text shown after the model name, matching Codex's "default" status. */
  mode?: string;
  /** Fallback percentage remaining if no Codex rate-limit event is available. */
  limitPercent?: number;
  /** Fallback time-left text if no Codex rate-limit event is available. */
  limitLeft?: string;
  /** Fallback weekly percentage remaining if no Codex rate-limit event is available. */
  weeklyPercent?: number;
};

type CodexRateLimitWindow = {
  used_percent?: number;
  reset_after_seconds?: number;
  reset_at?: number;
};

type CodexRateLimitsMessage = {
  type: "codex.rate_limits";
  plan_type?: string;
  rate_limits?: {
    primary?: CodexRateLimitWindow;
    secondary?: CodexRateLimitWindow;
  };
};

const DEFAULT_CONFIG: Required<Config> = {
  mode: "default",
  limitPercent: 70,
  limitLeft: "5h",
  weeklyPercent: 95,
};

function ensureConfig(): void {
  if (!existsSync(CONFIG_PATH)) {
    writeFileSync(CONFIG_PATH, JSON.stringify(DEFAULT_CONFIG, null, 2) + "\n", "utf8");
  }
}

function readConfig(): Config {
  ensureConfig();
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
  } catch {
    return DEFAULT_CONFIG;
  }
}

function shortModel(id?: string): string {
  if (!id) return "no-model";
  return id
    .replace(/^openai[/:]/, "")
    .replace(/^codex[/:]/, "")
    .replace(/^chatgpt[/:]/, "");
}

function formatDuration(ms: number): string {
  if (ms <= 0) return "0m";
  const minutes = Math.ceil(ms / 60000);
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const mins = minutes % 60;
  if (days > 0) return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
  if (hours > 0) return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  return `${mins}m`;
}

function remainingPercent(window?: CodexRateLimitWindow, fallback = 0): number {
  const used = window?.used_percent;
  if (typeof used !== "number" || !Number.isFinite(used)) return fallback;
  return Math.max(0, Math.min(100, Math.round(100 - used)));
}

function resetMs(window?: CodexRateLimitWindow): number | undefined {
  if (!window) return undefined;
  if (typeof window.reset_at === "number") return window.reset_at * 1000 - Date.now();
  if (typeof window.reset_after_seconds === "number") return window.reset_after_seconds * 1000;
  return undefined;
}

function extractJson(line: string): CodexRateLimitsMessage | undefined {
  const start = line.indexOf("{");
  if (start === -1) return undefined;
  try {
    const parsed = JSON.parse(line.slice(start));
    return parsed?.type === "codex.rate_limits" ? parsed : undefined;
  } catch {
    return undefined;
  }
}

let cachedRateLimits: { checkedAt: number; value: CodexRateLimitsMessage | undefined } | undefined;

function latestCodexRateLimits(): CodexRateLimitsMessage | undefined {
  const now = Date.now();
  if (cachedRateLimits && now - cachedRateLimits.checkedAt < 30_000) return cachedRateLimits.value;
  if (!existsSync(CODEX_LOGS_DB)) return undefined;

  // Codex already fetches account/rateLimits/read. Reuse its latest local log event;
  // no auth tokens or extra network calls needed. Cache it because render() is hot.
  try {
    const body = execFileSync(
      "sqlite3",
      [
        CODEX_LOGS_DB,
        "select feedback_log_body from logs where feedback_log_body like 'Received message {\"type\":\"codex.rate_limits\"%' order by ts desc, ts_nanos desc, id desc limit 1;",
      ],
      { encoding: "utf8", timeout: 1000 },
    ).trim();
    cachedRateLimits = { checkedAt: now, value: body ? extractJson(body) : undefined };
    return cachedRateLimits.value;
  } catch {
    cachedRateLimits = { checkedAt: now, value: undefined };
    return undefined;
  }
}

function quotaText(config: Config): string {
  const limits = latestCodexRateLimits()?.rate_limits;
  if (limits) {
    const primaryLeft = remainingPercent(limits.primary, config.limitPercent ?? DEFAULT_CONFIG.limitPercent);
    const secondaryLeft = remainingPercent(limits.secondary, config.weeklyPercent ?? DEFAULT_CONFIG.weeklyPercent);
    const ms = resetMs(limits.primary);
    const timeLeft = ms === undefined ? (config.limitLeft ?? DEFAULT_CONFIG.limitLeft) : formatDuration(ms);
    return `${timeLeft} ${primaryLeft}% left · weekly ${secondaryLeft}% left`;
  }

  return `${config.limitLeft ?? DEFAULT_CONFIG.limitLeft} ${config.limitPercent ?? DEFAULT_CONFIG.limitPercent}% left · weekly ${config.weeklyPercent ?? DEFAULT_CONFIG.weeklyPercent}% left`;
}

function installFooter(ctx: ExtensionContext): void {
  if (ctx.mode !== "tui") return;

  ctx.ui.setFooter((tui, theme) => {
    const timer = setInterval(() => tui.requestRender(), 30_000);
    return {
      dispose() {
        clearInterval(timer);
      },
      invalidate() {},
      render(width: number): string[] {
        const config = readConfig();
        const usage = ctx.getContextUsage();
        const contextPercent = usage?.percent == null ? 0 : Math.round(usage.percent);
        const text = `${shortModel(ctx.model?.id)} ${config.mode ?? DEFAULT_CONFIG.mode} · Context ${contextPercent}% used · ${quotaText(config)}`;
        return [theme.fg("dim", truncateToWidth(text, width))];
      },
    };
  });
}

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => installFooter(ctx));
  pi.on("model_select", async (_event, ctx) => installFooter(ctx));

  pi.registerCommand("codex-status", {
    description: "Show the Codex-style status footer source and fallback config",
    handler: async (_args, ctx) => {
      ensureConfig();
      const latest = latestCodexRateLimits();
      ctx.ui.notify(
        latest
          ? `Using latest Codex rate limits from ${CODEX_LOGS_DB}`
          : `No Codex rate-limit log found; using fallback ${CONFIG_PATH}`,
        latest ? "info" : "warning",
      );
      const edited = await ctx.ui.editor("Edit fallback Codex status footer config", readFileSync(CONFIG_PATH, "utf8"));
      if (edited !== undefined) {
        JSON.parse(edited);
        writeFileSync(CONFIG_PATH, edited.trimEnd() + "\n", "utf8");
        installFooter(ctx);
        ctx.ui.notify(`Updated ${CONFIG_PATH}`, "info");
      }
    },
  });
}
