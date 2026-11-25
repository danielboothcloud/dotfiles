# Sundae session pods mount a Secret at /etc/sundae-session-env: one file per
# variable (e.g. EXA_API_KEY). Files keep keys off the pod spec and out of `ps`.
if [ -d /etc/sundae-session-env ]; then
  for _f in /etc/sundae-session-env/*; do
    [ -f "${_f}" ] && [ -r "${_f}" ] || continue
    _n="${_f##*/}"
    case "${_n}" in
      [A-Za-z_]*) ;;
      *) continue ;;
    esac
    case "${_n}" in
      *[!A-Za-z0-9_]*) continue ;;
    esac
    # An explicit value in the environment wins over the mounted one.
    eval "_set=\${${_n}+x}"
    [ -n "${_set}" ] && continue
    export "${_n}=$(cat "${_f}")"
  done
  unset _f _n _set
fi
