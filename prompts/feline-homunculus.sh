# feline-homunculus.sh — Tokyo Street Navigation Prompt
# Source this file to activate the feline homunculus prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/feline-homunculus.sh
#
# Renders:
#   ┌─[SHINJUKU]─[RAIN:HEAVY]─[NEON:87%]─[ALLEY:DEEP]
#   └─╼ crashy@tokyo:~ $

# Idempotency guard
[[ -n "$_FELINE_HOMUNCULUS_PROMPT_LOADED" ]] && return
_FELINE_HOMUNCULUS_PROMPT_LOADED=1

# Colors — neon magenta/pink (matches feline-homunculus theme)
_FH_DIM=$'\e[35m'        # dim magenta
_FH_BRIGHT=$'\e[95m'     # bright magenta
_FH_RESET=$'\e[0m'

# Session state
_FH_RAIN_VAL=$(( 40 + RANDOM % 60 ))   # 40-99 (maps to labels)
_FH_NEON=$(( 70 + RANDOM % 30 ))       # 70-99
_FH_ALLEY_VAL=$(( 20 + RANDOM % 80 ))  # 20-99 (maps to labels)
_FH_CMD_COUNT=0

# District rotation list
_FH_DISTRICTS=(SHINJUKU AKIHABARA SHIBUYA KABUKICHO ROPPONGI IKEBUKURO)

# Precmd hook
_feline_homunculus_precmd() {
    # Increment command count
    _FH_CMD_COUNT=$(( _FH_CMD_COUNT + 1 ))

    # Rotate district every 10 commands
    local district_idx=$(( (_FH_CMD_COUNT / 10) % ${#_FH_DISTRICTS[@]} + 1 ))
    local district="${_FH_DISTRICTS[$district_idx]}"

    # Random walk RAIN: drift -2 to +2, clamp 20-99
    local rain_drift=$(( (RANDOM % 5) - 2 ))
    _FH_RAIN_VAL=$(( _FH_RAIN_VAL + rain_drift ))
    (( _FH_RAIN_VAL > 99 )) && _FH_RAIN_VAL=99
    (( _FH_RAIN_VAL < 20 )) && _FH_RAIN_VAL=20

    # Map rain value to label
    local rain_label
    if (( _FH_RAIN_VAL < 40 )); then rain_label="DRIZZLE"
    elif (( _FH_RAIN_VAL < 60 )); then rain_label="STEADY"
    elif (( _FH_RAIN_VAL < 80 )); then rain_label="HEAVY"
    else rain_label="DOWNPOUR"
    fi

    # Random walk NEON: drift -1 to +1, clamp 70-99
    local neon_drift=$(( (RANDOM % 3) - 1 ))
    _FH_NEON=$(( _FH_NEON + neon_drift ))
    (( _FH_NEON > 99 )) && _FH_NEON=99
    (( _FH_NEON < 70 )) && _FH_NEON=70

    # Random walk ALLEY: drift -2 to +2, clamp 20-99
    local alley_drift=$(( (RANDOM % 5) - 2 ))
    _FH_ALLEY_VAL=$(( _FH_ALLEY_VAL + alley_drift ))
    (( _FH_ALLEY_VAL > 99 )) && _FH_ALLEY_VAL=99
    (( _FH_ALLEY_VAL < 20 )) && _FH_ALLEY_VAL=20

    # Map alley value to label
    local alley_label
    if (( _FH_ALLEY_VAL < 40 )); then alley_label="SHALLOW"
    elif (( _FH_ALLEY_VAL < 60 )); then alley_label="WINDING"
    elif (( _FH_ALLEY_VAL < 80 )); then alley_label="DEEP"
    else alley_label="LABYRINTH"
    fi

    local line1="${_FH_DIM}┌─[${_FH_BRIGHT}${district}${_FH_DIM}]─[${_FH_BRIGHT}RAIN:${rain_label}${_FH_DIM}]─[${_FH_BRIGHT}NEON:${_FH_NEON}%${_FH_DIM}]─[${_FH_BRIGHT}ALLEY:${alley_label}${_FH_DIM}]${_FH_RESET}"
    local line2="${_FH_DIM}└─╼ ${_FH_RESET}%n@tokyo:%~ ${_FH_BRIGHT}\$ ${_FH_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_feline_homunculus_precmd]} == 0 )); then
    precmd_functions+=(_feline_homunculus_precmd)
fi
