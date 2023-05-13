#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"

if ! [ -f "./server.config" ]
then
    echo 'File server.config does not exist... Creating config file!'

    source .configDefaults.txt

    while read -r LINE
    do
       if [ "${LINE:0:1}" == '#' ]
       then
            echo "$LINE" >> server.config
        else
            eval echo "$LINE" >> server.config
        fi
    done < ".baseConfig.txt"

    echo "Config file created"
fi

source ./server.config

URL="https://www.minecraft.net/en-us/download/server/bedrock" # If planning on Java support in the future, this URL should be set based on the edition we are using.
AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"

echo "Checking for an update..."
FILE_LINK="$(curl -A "$AGENT" "$URL" 2> /dev/null | grep -o "https://minecraft.azureedge.net/bin-linux/bedrock-server-.*.zip")"

VERSION_NUM=$(echo "$FILE_LINK" | grep -o "bedrock-server-.*.zip" | awk '{ print substr($0, 16, length($0)-19) }')

# Check if version from link matches the current installed version.
touch minecraft.version
if [ "$(cat minecraft.version)" == "$VERSION_NUM" ]
then
    echo "Minecraft is already up to date! Currently on version $(cat minecraft.version)."
    exit 0
fi

# Download file
if [ "$(cat minecraft.version)" == "" ]
then
    echo "Downloading newest version of Minecraft (Version: $VERSION_NUM). If this is your first time installing Minecraft on this device, don't worry about any copy errors below."
else
    echo "Update found! Downloading new files for Minecraft version $VERSION_NUM. (Currently on version: $(cat minecraft.version))"
fi

wget -q --show-progress -O "minecraft-server-files.zip" "$FILE_LINK"
echo "Finished downloading files"

# Stop server if running, wait 15 minutes if there are players online
./stop_server.sh -t 15 || exit 1

# Copy these files so they are not overwritten by the update
echo "Making a copy of your server files so the new ones won't overwrite them..."
mv ./allowlist.json ./allowlist.json.old && echo "• Copied allowlist.json"
mv ./behavior_packs/ ./behavior_packs.old/ && echo "• Copied behavior_packs/"
mv ./config/ ./config.old/ && echo "• Copied config/"
mv ./definitions/ ./definitions.old/ && echo "• Copied definitions/"
mv ./permissions.json ./permissions.json.old && echo "• Copied permissions.json"
mv ./resource_packs/ ./resource_packs.old/ && echo "• Copied resource_packs/"
mv ./server.properties server.properties.old && echo "• Copied server.properties"

# Extract new files
echo "Extracting new server files..."
unzip -o "minecraft-server-files.zip" > /dev/null && rm "minecraft-server-files.zip"
echo "Extraction complete!"

# Restore the old files
echo "Finally, restoring copies..."
mv -f ./allowlist.json.old ./allowlist.json && echo "• Restored allowlist.json"
mv -f ./behavior_packs.old/ ./behavior_packs/ && echo "• Restored behavior_packs/"
mv -f ./config.old/ ./config/ && echo "• Restored config/"
mv -f ./definitions.old/ ./definitions/ && echo "• Restored definitions/"
mv -f ./permissions.json.old ./permissions.json && echo "• Restored permissions.json"
mv -f ./resource_packs.old/ ./resource_packs/ && echo "• Restored resource_packs/"
mv -f ./server.properties.old ./server.properties && echo "• Restored server.properties"
echo "Done! Your server is now updated to version $VERSION_NUM."

echo "$VERSION_NUM" > minecraft.version

# Restart server
./start_server.sh
