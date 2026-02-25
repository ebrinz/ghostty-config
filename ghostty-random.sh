#!/usr/bin/env zsh
# ghostty-random.sh — Switch Ghostty theme live (random or directed).
# Rewrites ~/.config/ghostty/config; Ghostty auto-reloads on file change.
#
# Usage (via alias ghostty='~/.config/ghostty/ghostty-random.sh'):
#   ghostty                    # random theme
#   ghostty street-shaman      # switch to specific theme
#   ghostty list               # show available themes

GHOSTTY_DIR="${HOME}/.config/ghostty"
THEMES_DIR="${GHOSTTY_DIR}/themes"
SHADERS_DIR="${GHOSTTY_DIR}/shaders"
CONFIG="${GHOSTTY_DIR}/config"

# Discover available theme+shader pairs
themes=()
for theme_file in "${THEMES_DIR}"/*; do
    name="${theme_file:t}"
    if [[ -f "${SHADERS_DIR}/${name}.glsl" ]]; then
        themes+=("$name")
    fi
done

if (( ${#themes[@]} == 0 )); then
    echo "No theme+shader pairs found." >&2
    exit 1
fi

# Handle 'list' command
if [[ "$1" == "list" ]]; then
    echo "Available themes:"
    for t in "${themes[@]}"; do
        echo "  $t"
    done
    exit 0
fi

# Pick theme: argument or random
if [[ -n "$1" ]]; then
    if [[ " ${themes[*]} " == *" $1 "* ]]; then
        chosen="$1"
    else
        echo "Unknown theme: $1" >&2
        echo "Available: ${themes[*]}" >&2
        exit 1
    fi
else
    chosen="${themes[RANDOM % ${#themes[@]} + 1]}"
fi

shader="${SHADERS_DIR}/${chosen}.glsl"

# Pretty-print the theme name (capitalize words)
pretty="${chosen//-/ }"
pretty="${(C)pretty}"

# Rewrite config — Ghostty watches this file and reloads automatically
cat > "${CONFIG}" <<EOF
# ${pretty}
theme = ${chosen}
custom-shader = ${shader}
custom-shader-animation = true
EOF

echo "🎨 ${pretty}"
