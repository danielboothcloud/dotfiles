status is-interactive; or exit 0

# Reveal starship's kubernetes module (see detect_env_vars in starship.toml)
# as soon as a kube tool is typed (on space/enter) or run. Sticky for the
# session; `kube` with no args while active hides it again.
set -g __kube_prompt_cmds kubectl kb k9s helm helmfile kubeseal kubescape vcluster

function __kube_prompt_show
    set -q STARSHIP_KUBE; and return
    set -gx STARSHIP_KUBE 1
    commandline -f repaint
end

# Abbreviation hook: fires when the token in command position is expanded,
# i.e. before Enter is pressed. Returns the (possibly expanded) command.
function __kube_prompt_abbr
    __kube_prompt_show
    switch $argv[1]
        case kb
            echo kubectl
        case '*'
            echo $argv[1]
    end
end

for cmd in $__kube_prompt_cmds
    abbr -a $cmd --function __kube_prompt_abbr
end

# Fallback for anything the abbr hook missed (pasted commands, pipelines, etc.)
function __kube_prompt_preexec --on-event fish_preexec
    set -q STARSHIP_KUBE; and return
    set -l re '(^|[;&|(]|\bsudo|\benv)\s*('(string join '|' $__kube_prompt_cmds)')(\s|$)'
    string match -qr -- $re $argv[1]; and set -gx STARSHIP_KUBE 1
end
