#!/bin/sh

# This script randomly selects an image from a specified directory and sets it as the desktop wallpaper using feh. 
# It replaces the macOS-specific functionality with Linux standards.

IMAGE_DIR="/saturn/titan/jupiter/NASA" # <--- Updated target path for random backgrounds!

# Check for required tools
if ! command -v feh &> /dev/null; then
    echo "Error: 'feh' is required to set the wallpaper, but it could not be found."
    echo "Please install a utility like feh (e.g., sudo apt install feh)."
    exit 1
fi

# Check if image directory exists
if [ ! -d "$IMAGE_DIR" ]; then
    echo "Error: Image directory '$IMAGE_DIR' does not exist."
    exit 1
fi

# Find all JPG files in the directory and select one randomly
random_image=$(find "$IMAGE_DIR" -maxdepth 1 -type f -iname "*.jpg" | shuf -n 1)

if [ -z "$random_image" ]; then
    echo "Error: No JPG or PNG images found in the '$IMAGE_DIR' directory."
    exit 1
fi

# Set wallpaper using feh. 
# The --bg-fill flag ensures the image covers the screen without stretching artifacts.
feh --bg-fill "$random_image" &
