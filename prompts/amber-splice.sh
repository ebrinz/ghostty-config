# amber-splice.sh — Amber Splice Genetics Field-Lab Prompt
# Source this file to activate the genetics field-lab prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/amber-splice.sh
#
# Renders:
#   ┌─⌬─[AMBER FIELD LAB]─[SITE·B]─[SEQ 63%]─[VIABILITY:88%]─[SPLICE:α-9]─⌬─
#   └─⌖ user@lab:~ $

# Idempotency guard
[[ -n "$_AMBER_SPLICE_PROMPT_LOADED" ]] && return
_AMBER_SPLICE_PROMPT_LOADED=1

# Colors — amber gold (matches amber-splice theme) + cyan alien accent
_AS_DIM=$'\e[33m'        # dim gold
_AS_BRIGHT=$'\e[93m'     # bright gold
_AS_CYAN=$'\e[36m'       # alien cyan
_AS_RESET=$'\e[0m'

# Session state
_AS_SEQ=$(( RANDOM % 100 ))             # 0-99 sequencing progress
_AS_VIABILITY=$(( 70 + RANDOM % 30 ))   # 70-99
_AS_CMD_COUNT=0

# Splice strain codes — cycle through 4
_AS_STRAINS=('α-9' 'β-2' 'Δ-7' 'Ω-1')

# Precmd hook
_amber_splice_precmd() {
    _AS_CMD_COUNT=$(( _AS_CMD_COUNT + 1 ))

    # SEQ: climb +0..+3, wrap at 100 (a sequencing run completing and restarting)
    local seq_drift=$(( RANDOM % 4 ))
    _AS_SEQ=$(( (_AS_SEQ + seq_drift) % 100 ))

    # VIABILITY random walk -2..+2, clamp 40-99
    local via_drift=$(( (RANDOM % 5) - 2 ))
    _AS_VIABILITY=$(( _AS_VIABILITY + via_drift ))
    (( _AS_VIABILITY > 99 )) && _AS_VIABILITY=99
    (( _AS_VIABILITY < 40 )) && _AS_VIABILITY=40

    # Strain — cycles every 8 commands
    local strain_idx=$(( (_AS_CMD_COUNT / 8) % ${#_AS_STRAINS[@]} + 1 ))
    local strain="${_AS_STRAINS[$strain_idx]}"

    # Build the prompt
    local line1="${_AS_DIM}┌─${_AS_BRIGHT}⌬${_AS_DIM}─[${_AS_BRIGHT}AMBER FIELD LAB${_AS_DIM}]─[${_AS_BRIGHT}SITE·B${_AS_DIM}]─[${_AS_BRIGHT}SEQ ${_AS_SEQ}%${_AS_DIM}]─[${_AS_BRIGHT}VIABILITY:${_AS_VIABILITY}%${_AS_DIM}]─[${_AS_CYAN}SPLICE:${strain}${_AS_DIM}]─${_AS_BRIGHT}⌬${_AS_DIM}─${_AS_RESET}"
    local line2="${_AS_DIM}└─${_AS_BRIGHT}⌖ ${_AS_RESET}%n@lab:%~ ${_AS_BRIGHT}\$ ${_AS_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_amber_splice_precmd]} == 0 )); then
    precmd_functions+=(_amber_splice_precmd)
fi
