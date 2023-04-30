#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
source ./config_server.sh || exit 1

URL="https://www.minecraft.net/en-us/download/server/bedrock" # If planning on Java support in the future, this URL should be set based on the edition we are using.
AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"

FILE_LINK="$(curl -A "$AGENT" "$URL" 2> /dev/null | grep -o "https://minecraft.azureedge.net/bin-linux/bedrock-server-.*.zip")"
echo "Downloading new files..." 
wget -q --show-progress -O "minecraft-server-files.zip" "$FILE_LINK"
echo "Finished downloading files"

echo "Making a copy of your server files so the new ones won't overwrite them..."
mv ./allowlist.json ./allowlist.json.old
mv ./behavior_packs/ ./behavior_packs.old/
mv ./config/ ./config.old/
mv ./definitions/ ./definitions.old/
mv ./permissions.json ./permissions.json.old
mv ./resource_packs/ ./resource_packs.old/
mv ./server.properties server.properties.old
echo "Copies created"

echo "Extracting files..."
unzip -o "minecraft-server-files.zip" > /dev/null && rm "minecraft-server-files.zip"
echo "Extraction complete!"

echo "Finally, restoring copies..."
mv -f ./allowlist.json.old ./allowlist.json
mv -f ./behavior_packs.old/ ./behavior_packs/
mv -f ./config.old/ ./config/
mv -f ./definitions.old/ ./definitions/
mv -f ./permissions.json.old ./permissions.json
mv -f ./resource_packs.old/ ./resource_packs/
mv -f ./server.properties.old ./server.properties
echo "Done! Your server is now up-to-date!"