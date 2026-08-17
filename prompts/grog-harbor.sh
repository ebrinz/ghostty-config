# grog-harbor.sh — SCUMM Verb Interface Prompt
# Source this file to activate the grog-harbor verb-panel prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/grog-harbor.sh
#
# Renders:
#    Look at   Open   Push   Give
#    Talk to   Close   Pull   Use   Pick up   Walk to <branch>
#  » ~/current/dir ◂

# Idempotency guard
[[ -n "$_GROG_HARBOR_PROMPT_LOADED" ]] && return
_GROG_HARBOR_PROMPT_LOADED=1

# Colors — approximate grog-harbor theme palette (256-color)
_GH_PARCH=$'\e[38;5;223m'   # parchment  (~#d8c898)
_GH_TORCH=$'\e[38;5;208m'   # torch orange (~#e89838)
_GH_TEAL=$'\e[38;5;73m'     # dock teal  (~#48a8a0)
_GH_RED=$'\e[38;5;124m'     # brick red  (~#b83820)
_GH_RESET=$'\e[0m'

# Verb list (9 verbs; row 1 = indices 1-4, row 2 = indices 5-9 in zsh 1-indexed)
_GH_VERBS=('Look at' 'Open' 'Push' 'Give' 'Talk to' 'Close' 'Pull' 'Use' 'Pick up')

# Precmd hook
_grog_harbor_precmd() {
    local last_exit=$?

    # Pick a random verb to highlight (0-based index 0..8)
    local hl=$(( RANDOM % ${#_GH_VERBS[@]} ))

    # Build row 1 — verbs 0-3 (zsh indices 1-4)
    local row1="  ${_GH_PARCH}"
    local i
    local first=1
    for i in 1 2 3 4; do
        local zero_idx=$(( i - 1 ))
        local verb="${_GH_VERBS[$i]}"
        if (( first )); then
            first=0
        else
            row1+="   "
        fi
        if (( zero_idx == hl )); then
            row1+="${_GH_TORCH}${verb}${_GH_PARCH}"
        else
            row1+="${verb}"
        fi
    done

    # Build row 2 — verbs 4-8 (zsh indices 5-9)
    local row2="  ${_GH_PARCH}"
    first=1
    for i in 5 6 7 8 9; do
        local zero_idx=$(( i - 1 ))
        local verb="${_GH_VERBS[$i]}"
        if (( first )); then
            first=0
        else
            row2+="   "
        fi
        if (( zero_idx == hl )); then
            row2+="${_GH_TORCH}${verb}${_GH_PARCH}"
        else
            row2+="${verb}"
        fi
    done

    # Git branch injection — always teal, never highlighted
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        row2+="   ${_GH_TEAL}Walk to ${branch}${_GH_PARCH}"
    fi

    # Arrow color: red on error, parchment otherwise
    local arrow_color=${_GH_PARCH}
    (( last_exit != 0 )) && arrow_color=${_GH_RED}

    # Line 3: » ~/path ◂
    local line3="${arrow_color}»${_GH_RESET} %~ ${arrow_color}◂${_GH_RESET} "

    # Assemble prompt
    PROMPT=$'\n'"${row1}${_GH_RESET}"$'\n'"${row2}${_GH_RESET}"$'\n'"${line3}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_grog_harbor_precmd]} == 0 )); then
    precmd_functions+=(_grog_harbor_precmd)
fi
