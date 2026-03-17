#!/usr/bin/env zsh
# ghostty-random.sh — Switch Ghostty theme live with power tier support.
# Rewrites ~/.config/ghostty/config; Ghostty auto-reloads on file change.
#
# Usage (via alias ghostty='~/.config/ghostty/ghostty-random.sh'):
#   ghostty                        # random theme, full shader
#   ghostty deep-drift             # specific theme, full shader
#   ghostty deep-drift --lite      # specific theme, reduced animation
#   ghostty deep-drift --static    # specific theme, no animation
#   ghostty --lite                 # random theme, lite shader
#   ghostty --no-shader            # random theme, theme colors only
#   ghostty list                   # show available themes
#
# Environment:
#   GHOSTTY_POWER=lite|static|full|no-shader   # default tier (flag overrides)

GHOSTTY_DIR="${HOME}/.config/ghostty"
THEMES_DIR="${GHOSTTY_DIR}/themes"
SHADERS_DIR="${GHOSTTY_DIR}/shaders"
PROMPTS_DIR="${GHOSTTY_DIR}/prompts"
CONFIG="${GHOSTTY_DIR}/config"

# --- Parse arguments ---
tier=""
theme_arg=""

for arg in "$@"; do
    case "$arg" in
        --lite)      tier="lite" ;;
        --static)    tier="static" ;;
        --full)      tier="full" ;;
        --no-shader) tier="no-shader" ;;
        *)           theme_arg="$arg" ;;
    esac
done

# Resolve tier: flag > env > default
if [[ -z "$tier" ]]; then
    tier="${GHOSTTY_POWER:-full}"
fi

# --- Discover available themes ---
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

# --- Handle 'list' command ---
if [[ "$theme_arg" == "list" ]]; then
    echo "Available themes:"
    for t in "${themes[@]}"; do
        echo "  $t"
    done
    echo ""
    echo "Power tiers: --full (default), --lite, --static, --no-shader"
    echo "Env default: export GHOSTTY_POWER=lite"
    exit 0
fi

# --- Pick theme ---
if [[ -n "$theme_arg" ]]; then
    if [[ " ${themes[*]} " == *" $theme_arg "* ]]; then
        chosen="$theme_arg"
    else
        echo "Unknown theme: $theme_arg" >&2
        echo "Available: ${themes[*]}" >&2
        exit 1
    fi
else
    chosen="${themes[RANDOM % ${#themes[@]} + 1]}"
fi

# --- Pretty-print theme name ---
pretty="${chosen//-/ }"
pretty="${(C)pretty}"

# --- Resolve shader path ---
case "$tier" in
    full)
        shader="${SHADERS_DIR}/${chosen}.glsl"
        animation="true"
        ;;
    lite)
        shader="${SHADERS_DIR}/${chosen}-lite.glsl"
        animation="true"
        if [[ ! -f "$shader" ]]; then
            echo "No lite shader for ${chosen}, falling back to full." >&2
            shader="${SHADERS_DIR}/${chosen}.glsl"
        fi
        ;;
    static)
        shader="${SHADERS_DIR}/${chosen}-static.glsl"
        animation="false"
        if [[ ! -f "$shader" ]]; then
            echo "No static shader for ${chosen}, falling back to full." >&2
            shader="${SHADERS_DIR}/${chosen}.glsl"
            animation="true"
        fi
        ;;
    no-shader)
        shader=""
        animation=""
        ;;
    *)
        echo "Unknown tier: $tier" >&2
        echo "Valid: full, lite, static, no-shader" >&2
        exit 1
        ;;
esac

# --- Write config ---
if [[ -n "$shader" ]]; then
    cat > "${CONFIG}" <<EOF
# ${pretty} (${tier})
theme = ${chosen}
custom-shader = ${shader}
custom-shader-animation = ${animation}
EOF
else
    cat > "${CONFIG}" <<EOF
# ${pretty} (no shader)
theme = ${chosen}
EOF
fi

# --- Output ---
tier_label="${tier}"
[[ "$tier" == "full" ]] && tier_label=""
[[ -n "$tier_label" ]] && tier_label=" [${tier_label}]"

echo "🎨 ${pretty}${tier_label}  · Cmd+Shift+, to reload"

# Prompt hint
prompt_file="${PROMPTS_DIR}/${chosen}.sh"
if [[ -f "$prompt_file" ]]; then
    echo "🔤 source ${prompt_file}"
fi
