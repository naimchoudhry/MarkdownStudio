#!/bin/zsh
# Builds a Release copy of Markdown Studio and installs it in /Applications.
# Run again after making changes to update the installed app.
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="MarkdownStudio.app"
DESTINATION="/Applications/$APP_NAME"

echo "Building Release…"
xcodebuild -project MarkdownStudio.xcodeproj -scheme MarkdownStudio -configuration Release \
  -derivedDataPath build -quiet build

if pgrep -xq MarkdownStudio; then
  echo "Quitting the running app…"
  osascript -e 'quit app id "com.example.MarkdownStudio"' || true
  sleep 1
fi

echo "Installing to $DESTINATION…"
rm -rf "$DESTINATION"
ditto "build/Build/Products/Release/$APP_NAME" "$DESTINATION"

# Make Finder and Launch Services pick up the new copy and its icon.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"

echo "Done. Open Markdown Studio from Applications, Launchpad or Spotlight."
