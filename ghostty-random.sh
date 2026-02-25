#!/usr/bin/env zsh
# ghostty-random.sh — Launch Ghostty with a random theme + shader pair.
# Every shader in the repository includes 40 Hz gamma entrainment by convention.
#
# Usage:
#   ~/.config/ghostty/ghostty-random.sh        # random theme
#   ~/.config/ghostty/ghostty-random.sh street-shaman  # force a specific theme
#
# To make every new window random, add to ~/.zshrc:
#   alias ghostty='~/.config/ghostty/ghostty-random.sh'

GHOSTTY_DIR="${HOME}/.config/ghostty"
THEMES_DIR="${GHOSTTY_DIR}/themes"
SHADERS_DIR="${GHOSTTY_DIR}/shaders"

# Discover available theme pairs (theme file must have a matching .glsl shader)
themes=()
for theme_file in "${THEMES_DIR}"/*; do
    name="${theme_file:t}"  # basename (zsh syntax)
    if [[ -f "${SHADERS_DIR}/${name}.glsl" ]]; then
        themes+=("$name")
    fi
done

if (( ${#themes[@]} == 0 )); then
    echo "No theme+shader pairs found in ${THEMES_DIR}. Launching default Ghostty." >&2
    exec /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
fi

# Pick theme: use argument if provided, otherwise random
if [[ -n "$1" && " ${themes[*]} " == *" $1 "* ]]; then
    chosen="$1"
    shift
else
    chosen="${themes[RANDOM % ${#themes[@]} + 1]}"
fi

shader="${SHADERS_DIR}/${chosen}.glsl"

exec /Applications/Ghostty.app/Contents/MacOS/ghostty \
    --theme="${chosen}" \
    --custom-shader="${shader}" \
    --custom-shader-animation=true \
    "$@"
