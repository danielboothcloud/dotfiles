# Shared mise volume: Sundae session pods mount one RWX volume at /mise, so a tool
# installed in one sandbox serves every sandbox and survives pod restarts.
if [ -d /mise ] && [ -w /mise ]; then
  : "${MISE_DATA_DIR:=/mise/data}"; export MISE_DATA_DIR
  : "${MISE_CACHE_DIR:=/mise/cache}"; export MISE_CACHE_DIR
  case ":${PATH}:" in
    *":${MISE_DATA_DIR}/shims:"*) ;;
    *) PATH="${MISE_DATA_DIR}/shims:${PATH}"; export PATH ;;
  esac
fi
