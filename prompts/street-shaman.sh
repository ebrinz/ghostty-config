# street-shaman.sh — Occult Ritual Terminal Prompt
# Source this file to activate the street shaman prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/street-shaman.sh
#
# Renders:
#   ┌─[SIGIL ACTIVE]─[WARD:73%]─[ENCOUNTERS:12]─[MOON:WAXING]
#   └─╼ crashy@ritual:~ $

# Idempotency guard
[[ -n "$_STREET_SHAMAN_PROMPT_LOADED" ]] && return
_STREET_SHAMAN_PROMPT_LOADED=1

# Colors — neon green (matches street-shaman theme)
_SS_DIM=$'\e[32m'        # dim green
_SS_BRIGHT=$'\e[92m'     # bright green
_SS_RESET=$'\e[0m'

# Session state
_SS_WARD=$(( 60 + RANDOM % 36 ))       # 60-95
_SS_ENCOUNTERS=0

# Moon phase calculation — 8 phases from synodic month
_ss_moon_phase() {
    local now
    now=$(date +%s)
    # Known new moon: Jan 6, 2000 18:14 UTC = 947181240
    local ref=947181240
    local synodic=2551443  # 29.53059 days in seconds
    local age=$(( (now - ref) % synodic ))
    local phase=$(( age * 8 / synodic ))
    local phases=(NEW WAXING-CRESCENT FIRST-QTR WAXING-GIBBOUS FULL WANING-GIBBOUS LAST-QTR WANING-CRESCENT)
    echo "${phases[$((phase + 1))]}"
}

# Precmd hook
_street_shaman_precmd() {
    # Random walk WARD: drift -1 to +1, clamp 60-95
    local ward_drift=$(( (RANDOM % 3) - 1 ))
    _SS_WARD=$(( _SS_WARD + ward_drift ))
    (( _SS_WARD > 95 )) && _SS_WARD=95
    (( _SS_WARD < 60 )) && _SS_WARD=60

    # Increment encounter counter
    _SS_ENCOUNTERS=$(( _SS_ENCOUNTERS + 1 ))

    local moon
    moon=$(_ss_moon_phase)

    local line1="${_SS_DIM}┌─[${_SS_BRIGHT}SIGIL ACTIVE${_SS_DIM}]─[${_SS_BRIGHT}WARD:${_SS_WARD}%${_SS_DIM}]─[${_SS_BRIGHT}ENCOUNTERS:${_SS_ENCOUNTERS}${_SS_DIM}]─[${_SS_BRIGHT}MOON:${moon}${_SS_DIM}]${_SS_RESET}"
    local line2="${_SS_DIM}└─╼ ${_SS_RESET}%n@ritual:%~ ${_SS_BRIGHT}\$ ${_SS_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_street_shaman_precmd]} == 0 )); then
    precmd_functions+=(_street_shaman_precmd)
fi
