#!/bin/bash
# Copies audio files from the iOS project into Android assets.
# Run this once after cloning, from the ListenToGospel-Android directory.

IOS_AUDIO="${1:-../ListenToGospel/ListenToGospel/AudioFiles}"
ANDROID_ASSETS="app/src/main/assets/AudioFiles"

if [ ! -d "$IOS_AUDIO" ]; then
    echo "Error: iOS audio folder not found at '$IOS_AUDIO'"
    echo "Usage: ./copy_audio_assets.sh [path/to/iOS/AudioFiles]"
    exit 1
fi

echo "Copying audio files from: $IOS_AUDIO"
mkdir -p "$ANDROID_ASSETS"
cp -r "$IOS_AUDIO"/. "$ANDROID_ASSETS/"
echo "Done. $(find "$ANDROID_ASSETS" -name '*.m4a' | wc -l) audio files copied."
