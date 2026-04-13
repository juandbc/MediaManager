#!/usr/bin/env bash
set -eEuo pipefail # fail if any errors are encountered

# This script is used to start the MediaManager service.


# text created with https://patorjk.com/software/taag/ font: Slanted
display_cool_text() {
  local ascii_art="$1"

  local r_blue=80
  local g_blue=100
  local b_blue=230

  local r_orange=255
  local g_orange=140
  local b_orange=80

  local r_red=230
  local g_red=40
  local b_red=70

  local max_width=0
  while IFS= read -r line; do
    local line_length=${#line}
    if (( line_length > max_width )); then
      max_width=$line_length
    fi
  done <<< "$ascii_art"

  # Pre-compute color gradient for the entire width
  local -a color_codes
  local seg1=$((max_width / 2))

  for (( i=0; i<max_width; i++ )); do
    local r=0
    local g=0
    local b=0

    if (( i < seg1 )); then
      # Blue to Orange gradient (first half)
      local ratio=$((i * 1000 / seg1))
      r=$(((r_blue * (1000 - ratio) + r_orange * ratio) / 1000))
      g=$(((g_blue * (1000 - ratio) + g_orange * ratio) / 1000))
      b=$(((b_blue * (1000 - ratio) + b_orange * ratio) / 1000))
    else
      # Orange to Red gradient (second half)
      local segment_pos=$((i - seg1))
      local segment_length=$((max_width - seg1))
      [[ $segment_length -eq 0 ]] && segment_length=1
      local ratio=$((segment_pos * 1000 / segment_length))
      r=$(((r_orange * (1000 - ratio) + r_red * ratio) / 1000))
      g=$(((g_orange * (1000 - ratio) + g_red * ratio) / 1000))
      b=$(((b_orange * (1000 - ratio) + b_red * ratio) / 1000))
    fi

    [[ $r -lt 0 ]] && r=0
    [[ $r -gt 255 ]] && r=255
    [[ $g -lt 0 ]] && g=0
    [[ $g -gt 255 ]] && g=255
    [[ $b -lt 0 ]] && b=0
    [[ $b -gt 255 ]] && b=255

    color_codes[$i]="\033[38;2;${r};${g};${b}m"
  done

  local output=""
  local reset="\033[0m"

  while IFS= read -r line; do
    local length=${#line}

    if [[ $length -eq 0 ]]; then
      output+=$'\n'
      continue
    fi

    for (( i=0; i<length; i++ )); do
      local char="${line:$i:1}"

      if [[ "$char" == " " ]]; then
        output+=" "
      else
        output+="${color_codes[$i]}${char}${reset}"
      fi
    done
    output+=$'\n'
  done <<< "$ascii_art"

  echo -e "$output"
}
ASCII_ART='

 ██████   ██████              █████  ███
░░██████ ██████              ░░███  ░░░
 ░███░█████░███   ██████   ███████  ████   ██████
 ░███░░███ ░███  ███░░███ ███░░███ ░░███  ░░░░░███
 ░███ ░░░  ░███ ░███████ ░███ ░███  ░███   ███████
 ░███      ░███ ░███░░░  ░███ ░███  ░███  ███░░███
 █████     █████░░██████ ░░████████ █████░░████████
░░░░░     ░░░░░  ░░░░░░   ░░░░░░░░ ░░░░░  ░░░░░░░░



 ██████   ██████
░░██████ ██████
 ░███░█████░███   ██████   ████████    ██████    ███████  ██████  ████████
 ░███░░███ ░███  ░░░░░███ ░░███░░███  ░░░░░███  ███░░███ ███░░███░░███░░███
 ░███ ░░░  ░███   ███████  ░███ ░███   ███████ ░███ ░███░███████  ░███ ░░░
 ░███      ░███  ███░░███  ░███ ░███  ███░░███ ░███ ░███░███░░░   ░███
 █████     █████░░████████ ████ █████░░████████░░███████░░██████  █████
░░░░░     ░░░░░  ░░░░░░░░ ░░░░ ░░░░░  ░░░░░░░░  ░░░░░███ ░░░░░░  ░░░░░
                                                ███ ░███
                                               ░░██████
                                                ░░░░░░

'
if [[ -v MEDIAMANAGER_NO_STARTUP_ART ]]; then
  echo
  echo "   +================+"
  echo "   |  MediaManager  |"
  echo "   +================+"
  echo
else
  display_cool_text "$ASCII_ART"
fi

echo "Buy me a coffee at https://buymeacoffee.com/maxdorninger"

# Initialize config if it doesn't exist
CONFIG_DIR=${CONFIG_DIR:-/app/config}
CONFIG_FILE="$CONFIG_DIR/config.toml"
EXAMPLE_CONFIG="/app/config.example.toml"

echo "Checking configuration setup..."

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Copy example config if config.toml doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found. Copying example config to: $CONFIG_FILE"
    if [ -f "$EXAMPLE_CONFIG" ]; then
        cp "$EXAMPLE_CONFIG" "$CONFIG_FILE"
        echo "Example config copied successfully!"
        echo "Please edit $CONFIG_FILE to configure MediaManager for your environment."
        echo "Important: Make sure to change the token_secret value!"
    else
        echo "ERROR: Example config file not found at $EXAMPLE_CONFIG"
        exit 1
    fi
else
    echo "Config file found at: $CONFIG_FILE"
fi

echo "Running DB migrations..."
uv run alembic upgrade head

echo "Starting MediaManager backend service..."
echo ""
echo "   LOGIN INFORMATION:"
echo "   If this is a fresh installation, a default admin user will be created automatically."
echo "   Check the application logs for the login credentials."
echo "   You can also register a new user and it will become admin if the email"
echo "   matches one of the admin_emails in your config.toml"
echo ""

DEVELOPMENT_MODE=${MEDIAMANAGER_MISC__DEVELOPMENT:-FALSE}
PORT=${PORT:-8000}

if [ "$DEVELOPMENT_MODE" == "TRUE" ]; then
    echo "Development mode is enabled, enabling auto-reload..."
    DEV_OPTIONS="--reload"
else
    DEV_OPTIONS=""
fi

exec uv run fastapi run /app/media_manager/main.py --port "$PORT" --proxy-headers $DEV_OPTIONS
