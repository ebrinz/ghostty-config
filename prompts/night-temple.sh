# night-temple.sh — Egyptian Night Ritual Prompt
# Source this file to activate the hieroglyphic temple prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/night-temple.sh
#
# Renders:
#   ┌─𓊹𓉗─[𓇳 HOUR 9]─[𓂓 KA:STRONG]─[𓎂 WARD:𓏴𓏏𓊮]─[𓁹 EYE OPEN]─𓊹𓉗─
#   └─𓅃 crashy@temple:~ $

# Idempotency guard
[[ -n "$_NIGHT_TEMPLE_PROMPT_LOADED" ]] && return
_NIGHT_TEMPLE_PROMPT_LOADED=1

# Colors — gold (matches night-temple theme yellow = gold leaf)
_NT_DIM=$'\e[33m'        # dim gold
_NT_BRIGHT=$'\e[93m'     # bright gold
_NT_RESET=$'\e[0m'

# Session state
_NT_KA=$(( 60 + RANDOM % 40 ))         # 60-99
_NT_EYE_VAL=$(( 40 + RANDOM % 60 ))    # 40-99
_NT_CMD_COUNT=0

# Ward glyphs — cycle through 4 protection signs
_NT_WARDS=('𓎂' '𓏴𓏏𓊮' '𓆓𓏤' '𓁹')

# Egyptian hour calculation
_nt_egyptian_hour() {
    local hour
    hour=$(date +%H)
    # Map 24h clock to Egyptian 1-12
    # 6am-6pm = daytime hours of Ra; 6pm-6am = Duat hours
    local egyptian=$(( (hour % 12) + 1 ))
    echo "$egyptian"
}

# KA label mapping
_nt_ka_label() {
    if (( _NT_KA < 56 )); then echo "FAINT"
    elif (( _NT_KA < 71 )); then echo "WAKING"
    elif (( _NT_KA < 81 )); then echo "STEADY"
    elif (( _NT_KA < 91 )); then echo "STRONG"
    else echo "RADIANT"
    fi
}

# EYE label mapping
_nt_eye_label() {
    if (( _NT_EYE_VAL < 40 )); then echo "SHUT"
    elif (( _NT_EYE_VAL < 60 )); then echo "DROWSY"
    elif (( _NT_EYE_VAL < 80 )); then echo "OPEN"
    else echo "BLAZING"
    fi
}

# Precmd hook
_night_temple_precmd() {
    _NT_CMD_COUNT=$(( _NT_CMD_COUNT + 1 ))

    # Random walk KA: drift -1 to +1, clamp 40-99
    local ka_drift=$(( (RANDOM % 3) - 1 ))
    _NT_KA=$(( _NT_KA + ka_drift ))
    (( _NT_KA > 99 )) && _NT_KA=99
    (( _NT_KA < 40 )) && _NT_KA=40

    # Random walk EYE: drift -2 to +2, clamp 20-99
    local eye_drift=$(( (RANDOM % 5) - 2 ))
    _NT_EYE_VAL=$(( _NT_EYE_VAL + eye_drift ))
    (( _NT_EYE_VAL > 99 )) && _NT_EYE_VAL=99
    (( _NT_EYE_VAL < 20 )) && _NT_EYE_VAL=20

    # Egyptian hour
    local hour
    hour=$(_nt_egyptian_hour)

    # KA and EYE labels
    local ka_label
    ka_label=$(_nt_ka_label)
    local eye_label
    eye_label=$(_nt_eye_label)

    # Ward glyph — cycles every 8 commands
    local ward_idx=$(( (_NT_CMD_COUNT / 8) % ${#_NT_WARDS[@]} + 1 ))
    local ward="${_NT_WARDS[$ward_idx]}"

    # Build the prompt
    local line1="${_NT_DIM}┌─${_NT_BRIGHT}𓊹𓉗${_NT_DIM}─[${_NT_BRIGHT}𓇳 HOUR ${hour}${_NT_DIM}]─[${_NT_BRIGHT}𓂓 KA:${ka_label}${_NT_DIM}]─[${_NT_BRIGHT}𓎂 WARD:${ward}${_NT_DIM}]─[${_NT_BRIGHT}𓁹 EYE ${eye_label}${_NT_DIM}]─${_NT_BRIGHT}𓊹𓉗${_NT_DIM}─${_NT_RESET}"
    local line2="${_NT_DIM}└─${_NT_BRIGHT}𓅃 ${_NT_RESET}%n@temple:%~ ${_NT_BRIGHT}\$ ${_NT_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_night_temple_precmd]} == 0 )); then
    precmd_functions+=(_night_temple_precmd)
fi
