#!/bin/bash

# Read JSON input from Claude Code
input=$(cat)

# Get current directory from Claude Code context
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model_display=$(echo "$input" | jq -r '.model.display_name')

# Oxocarbon theme colors
grey='\033[38;2;82;82;82m'      # #525252
red='\033[38;2;255;126;182m'    # #ff7eb6
yellow='\033[38;2;255;171;145m' # #ffab91
blue='\033[38;2;120;169;255m'   # #78a9ff
magenta='\033[38;2;190;149;255m' # #be95ff
cyan='\033[38;2;61;219;217m'    # #3ddbd9
white='\033[38;2;242;244;248m'  # #f2f4f8
green='\033[38;2;66;190;101m'   # #42be65
reset='\033[0m'

output=""

# Context (user@host) - only show if root or in SSH
if [[ $EUID -eq 0 ]] || [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
    if [[ $EUID -eq 0 ]]; then
        output+="${white}$(whoami)${reset}${grey}@$(hostname -s)${reset} "
    else
        output+="${grey}$(whoami)@$(hostname -s)${reset} "
    fi
fi

# Directory (shortened like p10k config)
dir_path="$cwd"
if [[ "$dir_path" == "$HOME"* ]]; then
    dir_path="~${dir_path#$HOME}"
fi

# Shorten directory path (keep last 2 components like POWERLEVEL9K_SHORTEN_DIR_LENGTH=2)
if [[ "$dir_path" =~ ^~/.*/.*/.*/.* ]]; then
    dir_path="~/.../${dir_path##*/../../*}"
fi

output+="${red}${dir_path}${reset} "

# Git status (if in git repository)
if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    
    if [[ -n "$branch" ]]; then
        git_output="${magenta}󰊢-${branch}"
        
        # Check for dirty state
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
            git_output+="*"
        fi
        
        # Check ahead/behind
        upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            ahead_behind=$(git rev-list --left-right --count HEAD...$upstream 2>/dev/null)
            if [[ -n "$ahead_behind" ]]; then
                ahead=$(echo "$ahead_behind" | cut -f1)
                behind=$(echo "$ahead_behind" | cut -f2)
                if [[ "$behind" -gt 0 ]] && [[ "$ahead" -gt 0 ]]; then
                    git_output+=":${cyan}⇣⇡${reset}${magenta}"
                elif [[ "$behind" -gt 0 ]]; then
                    git_output+=":${cyan}⇣${reset}${magenta}"
                elif [[ "$ahead" -gt 0 ]]; then
                    git_output+=":${cyan}⇡${reset}${magenta}"
                fi
            fi
        fi
        
        git_output+="${reset}"
        output+="${git_output} "
    fi
fi

# Kubernetes context (when KUBECONFIG is set)
if [[ -n "$KUBECONFIG" ]] && command -v kubectl &>/dev/null; then
    context=$(kubectl config current-context 2>/dev/null)
    if [[ -n "$context" ]]; then
        namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
        namespace=${namespace:-default}
        output+="${blue}⎈ ${context}:${namespace}${reset} "
    fi
fi

# Python virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    venv_name=$(basename "$VIRTUAL_ENV")
    output+="${grey}${venv_name}${reset} "
fi

# Claude model info (subtle)
output+="${grey}${model_display}${reset}"

# Output style indicator (visually distinct)
output_style=$(echo "$input" | jq -r '.output_style.name // "default"')
if [[ "$output_style" != "null" && "$output_style" != "default" ]]; then
    # Use different colors for different styles
    case "$output_style" in
        "Conservative"|"conservative")
            output+=" ${blue}◆${output_style}${reset}"
            ;;
        "Adaptive"|"adaptive")
            output+=" ${green}◇${output_style}${reset}"
            ;;
        "Exploratory"|"exploratory"|"Explanatory"|"explanatory")
            output+=" ${yellow}◈${output_style}${reset}"
            ;;
        "Learning"|"learning")
            output+=" ${magenta}◉${output_style}${reset}"
            ;;
        *)
            output+=" ${cyan}◊${output_style}${reset}"
            ;;
    esac
fi

# Output the final status line
printf "%b" "$output"
