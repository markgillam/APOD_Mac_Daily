#!/bin/bash

# Basic Environment Setup
WORKDIR=$(dirname "${BASH_SOURCE[0]}")
cd "$WORKDIR" || exit

# Handle target directory argument (default to /saturn/titan/jupiter/NASA)
TARGET_DIR="/saturn/titan/jupiter/NASA"
[[ ! -d "$TARGET_DIR" ]] && mkdir -p "$TARGET_DIR"

# Proxy Detection (SOCKS -> HTTP -> Environment -> GNOME)
CURL_PROXY=""
if [[ -n "$all_proxy" ]]; then
	CURL_PROXY="--proxy $all_proxy"
elif [[ -n "$ALL_PROXY" ]]; then
	CURL_PROXY="--proxy $ALL_PROXY"
elif [[ -n "$http_proxy" ]]; then
	CURL_PROXY="--proxy $http_proxy"
elif [[ -n "$HTTP_PROXY" ]]; then
	CURL_PROXY="--proxy $HTTP_PROXY"
elif command -v gsettings >/dev/null 2>&1; then
	PROXY_MODE=$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'")
	if [[ "$PROXY_MODE" == "manual" ]]; then
		SOCKS_HOST=$(gsettings get org.gnome.system.proxy.socks host 2>/dev/null | tr -d "'")
		SOCKS_PORT=$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)
		if [[ -n "$SOCKS_HOST" && "$SOCKS_PORT" -gt 0 ]]; then
			CURL_PROXY="--proxy socks5://$SOCKS_HOST:$SOCKS_PORT"
		else
			HTTP_HOST=$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | tr -d "'")
			HTTP_PORT=$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)
			if [[ -n "$HTTP_HOST" && "$HTTP_PORT" -gt 0 ]]; then
				CURL_PROXY="--proxy http://$HTTP_HOST:$HTTP_PORT"
			fi
		fi
	fi
fi

if [[ -n "$CURL_PROXY" ]]; then
	echo "Proxy detected: $CURL_PROXY"
else
	echo "No system proxy detected or using curl default. Proceeding with direct connection."
fi

# Helper function for network operations
# Usage: fetch_data "URL" "OUTPUT_FILE" (optional)
fetch_data() {
	local url=$1
	local output=$2
	if [[ -n "$output" ]]; then
		# Download to file
		curl -s -L $CURL_PROXY -f -o "$output" "$url"
	else
		# Return content to stdout
		curl -s -L $CURL_PROXY -f "$url"
	fi
}

# Fetch and Parse APOD Data
echo "Fetching APOD data..."
APOD_JSON=$(fetch_data "https://api.nasa.gov/planetary/apod?api_key=k9aW1Yl0MFp7IEdCPVKGn5IlRIiDCCiCOEJyw0op")

if [[ -z "$APOD_JSON" ]]; then
	echo "Error: Failed to fetch APOD data. Check your connection/proxy."
	exit 1
fi

# Parse JSON using available parser (jq, python3, python, node)
parse_json() {
	local key=$1
	if command -v jq >/dev/null 2>&1; then
		echo "$APOD_JSON" | jq -r ".$key"
	elif command -v python3 >/dev/null 2>&1; then
		python3 -c "import sys, json; print(json.loads(sys.argv[1]).get('$key', ''))" "$APOD_JSON"
	elif command -v python >/dev/null 2>&1; then
		python -c "import sys, json; print(json.loads(sys.argv[1]).get('$key', ''))" "$APOD_JSON"
	elif command -v node >/dev/null 2>&1; then
		node -e "console.log(JSON.parse(process.argv[1]).$key)" "$APOD_JSON"
	else
		echo "Error: No JSON parser found (jq, python3, python, node)." >&2
		exit 1
	fi
}

# Helper function to send desktop notifications
show_notification() {
	local title=$1
	local body=$2
	if command -v notify-send >/dev/null 2>&1; then
	    if ! notify-send -t 10000 "$title" "$body" 2>/dev/null; then
		echo "Notification (fallback): [$title] - $body"
	    fi
	else
		echo "Notification: [$title] - $body"
	fi
}

DATE=$(parse_json "date")
TITLE=$(parse_json "title")
EXPLANATION=$(parse_json "explanation")
MEDIA_TYPE=$(parse_json "media_type")
HDURL=$(parse_json "hdurl")
URL=$(parse_json "url")

# Detect Desktop Environment
DE="${XDG_CURRENT_DESKTOP:-}"
DE_LOWER=$(echo "$DE" | tr '[:upper:]' '[:lower:]')

# Try to detect number of screens/monitors on Linux
SCREEN_NUM=1
if command -v xrandr >/dev/null 2>&1; then
	SCREEN_NUM=$(xrandr --listmonitors | grep -c '^[ 0-9]:')
elif command -v swaymsg >/dev/null 2>&1; then
	SCREEN_NUM=$(swaymsg -t get_outputs | grep -c '"name":')
fi

# Ensure SCREEN_NUM is at least 1 and a valid integer
if [[ -z "$SCREEN_NUM" || ! "$SCREEN_NUM" =~ ^[0-9]+$ || "$SCREEN_NUM" -lt 1 ]]; then
	SCREEN_NUM=1
fi

# Helper function to set wallpaper for a given screen index (1-based)
set_wallpaper() {
	local screen_idx=$1
	local img_path=$2

	# GNOME
	if [[ "$DE_LOWER" == *"gnome"* || "$DE_LOWER" == *"unity"* ]]; then
		if [[ "$screen_idx" -eq 1 ]]; then
			gsettings set org.gnome.desktop.background picture-uri "file://$img_path"
			gsettings set org.gnome.desktop.background picture-uri-dark "file://$img_path"
		fi

	# KDE Plasma
	elif [[ "$DE_LOWER" == *"kde"* ]]; then
		dbus-send --dest=org.kde.plasmashell --object-path=/PlasmaShell --method=org.kde.PlasmaShell.evaluateScript \
			"var allDesktops = desktops(); var idx = $screen_idx - 1; if (idx >= 0 && idx < allDesktops.length) { var d = allDesktops[idx]; d.wallpaperPlugin = 'org.kde.image'; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$img_path'); }" >/dev/null 2>&1

	# XFCE
	elif [[ "$DE_LOWER" == *"xfce"* ]]; then
		local monitor_idx=$((screen_idx - 1))
		local props
		props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "monitor${monitor_idx}/workspace.*/last-image")
		if [[ -n "$props" ]]; then
			for prop in $props; do
				xfconf-query -c xfce4-desktop -p "$prop" -s "$img_path"
			done
		else
			xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor0/workspace0/last-image" -s "$img_path" 2>/dev/null
		fi

	# Cinnamon
	elif [[ "$DE_LOWER" == *"cinnamon"* ]]; then
		if [[ "$screen_idx" -eq 1 ]]; then
			gsettings set org.cinnamon.desktop.background picture-uri "file://$img_path"
		fi

	# MATE
	elif [[ "$DE_LOWER" == *"mate"* ]]; then
		if [[ "$screen_idx" -eq 1 ]]; then
			gsettings set org.mate.background picture-filename "$img_path"
		fi

	# Sway (Wayland)
	elif command -v swaymsg >/dev/null 2>&1; then
		local output_name=""
		if command -v jq >/dev/null 2>&1; then
			output_name=$(swaymsg -t get_outputs | jq -r ".[$((screen_idx - 1))].name" 2>/dev/null)
		fi
		if [[ -n "$output_name" ]]; then
			swaymsg output "$output_name" bg "$img_path" fill >/dev/null 2>&1
		else
			swaymsg output "*" bg "$img_path" fill >/dev/null 2>&1
		fi

	# Hyprland (Wayland)
	elif command -v hyprctl >/dev/null 2>&1; then
		hyprctl hyprpaper preload "$img_path" >/dev/null 2>&1
		hyprctl hyprpaper wallpaper ",$img_path" >/dev/null 2>&1

	# Fallbacks: feh / nitrogen
	else
		if [[ "$screen_idx" -eq 1 ]]; then
			if command -v nitrogen >/dev/null 2>&1; then
				nitrogen --set-zoom-fill "$img_path" >/dev/null 2>&1
			fi
		fi
	fi
}

# Handle Content
if [[ "$MEDIA_TYPE" == "video" ]]; then
	VIDEO_THUMB_URL=""

	if [[ "$URL" == *"youtube.com"* ]] || [[ "$URL" == *"youtu.be"* ]]; then
		if [[ "$URL" =~ (v/|be/|v=|embed/)([a-zA-Z0-9_-]{11}) ]]; then
			VIDEO_ID="${BASH_REMATCH[2]}"
			VIDEO_THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/maxresdefault.jpg"
		fi

	elif [[ "$URL" == *"vimeo.com"* ]]; then
		if [[ "$URL" =~ [0-9]{7,12} ]]; then
			VIMEO_ID="${BASH_REMATCH[0]}"
			VIMEO_JSON=$(fetch_data "https://vimeo.com/api/v2/video/$VIMEO_ID.json")
			if [[ -n "$VIMEO_JSON" ]]; then
				if command -v jq >/dev/null 2>&1; then
					VIDEO_THUMB_URL=$(echo "$VIMEO_JSON" | jq -r ".[0].thumbnail_large")
				elif command -v python3 >/dev/null 2>&1; then
					VIDEO_THUMB_URL=$(python3 -c "import sys, json; print(json.loads(sys.argv[1])[0].get('thumbnail_large', ''))" "$VIMEO_JSON")
				elif command -v python >/dev/null 2>&1; then
					VIDEO_THUMB_URL=$(python -c "import sys, json; print(json.loads(sys.argv[1])[0].get('thumbnail_large', ''))" "$VIMEO_JSON")
				fi
			fi
		fi
	fi

	# If thumb found, treat as image
	if [[ -n "$VIDEO_THUMB_URL" ]]; then
		echo "Video detected, using thumbnail: $VIDEO_THUMB_URL"
		HDURL=$VIDEO_THUMB_URL
		MEDIA_TYPE="image"
	else
		echo "No thumbnail found for video: $URL"
		show_notification "APOD: $TITLE" "Today is a video (no thumb found).\n$URL"
	fi
fi

if [[ "$MEDIA_TYPE" == "image" ]]; then
	TODAY_FILE="$TARGET_DIR/apod_${DATE}.jpg"
	if [[ ! -f "$TODAY_FILE" ]]; then
		echo "Downloading today's image: $DATE"
		fetch_data "$HDURL" "$TODAY_FILE"
	fi

	echo "Setting wallpapers for $SCREEN_NUM screens..."
	EPOCH=$(date -d "$DATE" +%s)

	WALLPAPERS=()
	for ((i = 1; i <= SCREEN_NUM; i++)); do
		OFFSET_SECONDS=$(((i - 1) * 86400))
		TARGET_DATE=$(date -d "@$((EPOCH - OFFSET_SECONDS))" +"%Y-%m-%d")
		IMG_PATH="$TARGET_DIR/apod_${TARGET_DATE}.jpg"

		[[ ! -f "$IMG_PATH" ]] && IMG_PATH="$TODAY_FILE"

		echo "Screen $i -> $TARGET_DATE"
		WALLPAPERS+=("$IMG_PATH")
		set_wallpaper "$i" "$IMG_PATH"
	done

	# If feh is installed, apply the wallpapers in one go for non-DE setups
	if command -v feh >/dev/null 2>&1 && [[ "$DE_LOWER" != *"gnome"* && "$DE_LOWER" != *"kde"* && "$DE_LOWER" != *"xfce"* && "$DE_LOWER" != *"cinnamon"* && "$DE_LOWER" != *"mate"* ]]; then
		feh --bg-fill "${WALLPAPERS[@]}" >/dev/null 2>&1
	fi

	show_notification "Astronomy Picture of the Day" "$TITLE\n\n$EXPLANATION"
elif [[ "$MEDIA_TYPE" == "video" ]]; then
	: # Already handled in the video section above
else
	echo "Error! Today APOD is something weird."
fi

# Cleanup
KEEP_DAYS=$((SCREEN_NUM + 3))
find "$TARGET_DIR" -name "apod_*.jpg" -mtime +"$KEEP_DAYS" -delete
