# deep-drift.sh — USS Erebus Ship Console Prompt
# Source this file to activate the deep space terminal prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/deep-drift.sh
#
# Renders:
#   ┌─[USS EREBUS]─[DECK 7 TERM 03]─[SOL 10957]─[O2:94%]─[HULL:87%]
#   └─╼ crashy@nav:~ $

# Idempotency guard
[[ -n "$_DEEP_DRIFT_PROMPT_LOADED" ]] && return
_DEEP_DRIFT_PROMPT_LOADED=1

# Colors — amber phosphor tones (uses theme palette slots)
_DD_DIM=$'\e[33m'       # dim amber (ANSI yellow = #c4a348)
_DD_BRIGHT=$'\e[93m'    # bright amber (ANSI bright yellow = #e8c860)
_DD_RESET=$'\e[0m'

# Ship launch date: January 1, 1996 (Unix timestamp)
_DD_LAUNCH_EPOCH=820454400

# Session-seeded O2 and HULL starting values
_DD_O2=$(( 91 + RANDOM % 7 ))        # 91-97
_DD_HULL=$(( 82 + RANDOM % 10 ))     # 82-91

# Precmd hook — updates readings and builds prompt each line
_deep_drift_precmd() {
    # Random walk O2: drift -1 to +1, clamp 91-97
    local o2_drift=$(( (RANDOM % 3) - 1 ))
    _DD_O2=$(( _DD_O2 + o2_drift ))
    (( _DD_O2 > 97 )) && _DD_O2=97
    (( _DD_O2 < 91 )) && _DD_O2=91

    # Random walk HULL: drift -1 to +1, clamp 82-91
    local hull_drift=$(( (RANDOM % 3) - 1 ))
    _DD_HULL=$(( _DD_HULL + hull_drift ))
    (( _DD_HULL > 91 )) && _DD_HULL=91
    (( _DD_HULL < 82 )) && _DD_HULL=82

    # SOL counter — days since ship launch
    local now
    now=$(date +%s)
    local sol=$(( (now - _DD_LAUNCH_EPOCH) / 86400 ))

    # Build the prompt
    local line1="${_DD_DIM}┌─[${_DD_BRIGHT}USS EREBUS${_DD_DIM}]─[${_DD_BRIGHT}DECK 7 TERM 03${_DD_DIM}]─[${_DD_BRIGHT}SOL ${sol}${_DD_DIM}]─[${_DD_BRIGHT}O2:${_DD_O2}%${_DD_DIM}]─[${_DD_BRIGHT}HULL:${_DD_HULL}%${_DD_DIM}]${_DD_RESET}"
    local line2="${_DD_DIM}└─╼ ${_DD_RESET}%n@nav:%~ ${_DD_BRIGHT}\$ ${_DD_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_deep_drift_precmd]} == 0 )); then
    precmd_functions+=(_deep_drift_precmd)
fi
