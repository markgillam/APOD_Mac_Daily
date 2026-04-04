#!/bin/bash

# Basic Environment Setup
WORKDIR=$(dirname "${BASH_SOURCE[0]}")
cd "$WORKDIR" || exit

# Handle target directory argument (default to ./tmp)
TARGET_DIR="${1:-$PWD/tmp}"
[[ ! -d "$TARGET_DIR" ]] && mkdir -p "$TARGET_DIR"

# Proxy Detection (SOCKS -> HTTP -> None)
# Fetch system proxy state from macOS configuration database
PROXY_INFO=$(echo "show State:/Network/Global/Proxies" | scutil)
DETECTED_PORT=$(echo "$PROXY_INFO" | awk '/SOCKSPort/ {print $3; exit}')

# Fallback to HTTP port if SOCKS is not found
if [[ -z "$DETECTED_PORT" ]]; then
	DETECTED_PORT=$(echo "$PROXY_INFO" | awk '/HTTPPort/ {print $3; exit}')
fi

# Construct the curl proxy argument if a port is found
CURL_PROXY=""
if [[ -n "$DETECTED_PORT" ]]; then
	CURL_PROXY="--proxy 127.0.0.1:$DETECTED_PORT"
	echo "Proxy detected on port: $DETECTED_PORT"
else
	echo "No system proxy detected. Proceeding with direct connection."
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
APOD_JSON=$(fetch_data "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY")

if [[ -z "$APOD_JSON" ]]; then
	echo "Error: Failed to fetch APOD data. Check your connection/proxy."
	exit 1
fi

# Parse JSON using JavaScript engine
parse_json() {
	local key=$1
	osascript -l JavaScript -e "function run(argv) { return JSON.parse(argv[0]).$key; }" "$APOD_JSON"
}

DATE=$(parse_json "date")
TITLE=$(parse_json "title")
EXPLANATION=$(parse_json "explanation")
MEDIA_TYPE=$(parse_json "media_type")
HDURL=$(parse_json "hdurl")
URL=$(parse_json "url")

# Handle Content
SCREEN_NUM=$(osascript -e "tell application \"System Events\" to return count of desktops")

if [[ "$MEDIA_TYPE" == "video" ]]; then
	echo "Today is a video: $URL"
	osascript -e "display notification \"Today is a video, please click to view.\" with title \"APOD: $TITLE\" subtitle \"$URL\" sound name \"Glass\""

elif [[ "$MEDIA_TYPE" == "image" ]]; then
	TODAY_FILE="$TARGET_DIR/apod_${DATE}.jpg"
	if [[ ! -f "$TODAY_FILE" ]]; then
		echo "Downloading today's image: $DATE"
		fetch_data "$HDURL" "$TODAY_FILE"
	fi

	echo "Setting wallpapers for $SCREEN_NUM screens..."
	EPOCH=$(date -j -f "%Y-%m-%d" "$DATE" +%s)

	for ((i = 1; i <= SCREEN_NUM; i++)); do
		OFFSET_SECONDS=$(((i - 1) * 86400))
		TARGET_DATE=$(date -r $((EPOCH - OFFSET_SECONDS)) +"%Y-%m-%d")
		IMG_PATH="$TARGET_DIR/apod_${TARGET_DATE}.jpg"

		[[ ! -f "$IMG_PATH" ]] && IMG_PATH="$TODAY_FILE"

		echo "Screen $i -> $TARGET_DATE"
		osascript -e "tell application \"System Events\" to set picture of desktop $i to POSIX file \"$IMG_PATH\""
	done

	osascript -e "display notification \"Astronomy Picture of the Day\" with title \"$TITLE\" subtitle \"$EXPLANATION\"  sound name \"Glass\""
else
	echo "Error! Today APOD is something weird."
	#do somthing
fi

# Cleanup
KEEP_DAYS=$((SCREEN_NUM + 3))
find "$TARGET_DIR" -name "apod_*.jpg" -mtime +"$KEEP_DAYS" -delete
