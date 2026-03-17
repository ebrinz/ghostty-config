# electrode-shaper.sh — Lab Instrument Readout Prompt
# Source this file to activate the electrode shaper prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/electrode-shaper.sh
#
# Renders:
#   ┌─[PLASMA:92%]─[EMF:340mT]─[ARCS:7]─[FREQ:40.0Hz]
#   └─╼ crashy@lab:~ $

# Idempotency guard
[[ -n "$_ELECTRODE_SHAPER_PROMPT_LOADED" ]] && return
_ELECTRODE_SHAPER_PROMPT_LOADED=1

# Colors — cyan (matches electrode-shaper violet/cyan theme)
_ES_DIM=$'\e[36m'        # dim cyan
_ES_BRIGHT=$'\e[96m'     # bright cyan
_ES_RESET=$'\e[0m'

# Session state
_ES_PLASMA=$(( 80 + RANDOM % 20 ))     # 80-99
_ES_EMF=$(( 200 + (RANDOM % 16) * 20 ))  # 200-500 in steps of 20
_ES_ARCS=0

# Precmd hook
_electrode_shaper_precmd() {
    # Random walk PLASMA: drift -1 to +1, clamp 80-99
    local plasma_drift=$(( (RANDOM % 3) - 1 ))
    _ES_PLASMA=$(( _ES_PLASMA + plasma_drift ))
    (( _ES_PLASMA > 99 )) && _ES_PLASMA=99
    (( _ES_PLASMA < 80 )) && _ES_PLASMA=80

    # Random walk EMF: drift -20 to +20 (steps of 20), clamp 200-500
    local emf_drift=$(( ((RANDOM % 3) - 1) * 20 ))
    _ES_EMF=$(( _ES_EMF + emf_drift ))
    (( _ES_EMF > 500 )) && _ES_EMF=500
    (( _ES_EMF < 200 )) && _ES_EMF=200

    # Increment arc counter
    _ES_ARCS=$(( _ES_ARCS + 1 ))

    local line1="${_ES_DIM}┌─[${_ES_BRIGHT}PLASMA:${_ES_PLASMA}%${_ES_DIM}]─[${_ES_BRIGHT}EMF:${_ES_EMF}mT${_ES_DIM}]─[${_ES_BRIGHT}ARCS:${_ES_ARCS}${_ES_DIM}]─[${_ES_BRIGHT}FREQ:40.0Hz${_ES_DIM}]${_ES_RESET}"
    local line2="${_ES_DIM}└─╼ ${_ES_RESET}%n@lab:%~ ${_ES_BRIGHT}\$ ${_ES_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_electrode_shaper_precmd]} == 0 )); then
    precmd_functions+=(_electrode_shaper_precmd)
fi
