#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"

printHelp(){
	echo "-h: Show this page and exit"
	echo "-s: Autostart the sever whenever this exits sucessfully"
}

AUTOSTART=false
# Handle flags
while getopts 'hs' OPTION
do
	case "$OPTION" in
		h)
			printHelp
			exit 0
			;;
		s)
			AUTOSTART=true
			;;
    	?)
			echo "Unknown option, '$OPTION'" >&2
			echo "Valid options are:"
			printHelp
			exit 1
      		;;
	esac
done

# Create server.config if it doesn't exist, eventually should ask things like java/bedrock
if ! [ -f "./server.config" ]
then
    echo 'File server.config does not exist... Creating config file!'

    source .configDefaults.txt

    read -r -p "Would you like to download Minecraft to the current directory? ($(pwd)) [Y/n] " VAL

    if [[ ! "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]] && [ "$VAL" != "" ]
    then
        read -r -p "Where should Minecraft be stored? " SERVER_PATH

        SERVER_PATH=$(eval echo "$SERVER_PATH")

        if ! (cd "$SERVER_PATH")
        then
            echo "Invalid location. Check to make sure this directory ($SERVER_PATH) exists and that you have access to it."
            exit 1
        fi
    fi

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
if ! touch "$SERVER_PATH/minecraft_version.txt" >> /dev/null
then
    echo "Cannot write to directory '$(pwd)', check if you have permisson to write there."
    exit 1
fi

if [ "$(cat "$SERVER_PATH/minecraft_version.txt")" == "$VERSION_NUM" ]
then
    echo "Minecraft is already up to date! Currently on version $(cat "$SERVER_PATH/minecraft_version.txt")."

    # Start sever ### TODO: Add check here for if the server is already running
    $AUTOSTART || read -r -p "Would you like to start the sever now? ($(pwd)) [Y/n] " VAL
    if [[ "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]] || [ "$VAL" == "" ] || $AUTOSTART
    then
        ./start_server.sh || exit 1
    fi
    exit 0
fi

# Download file
if [ "$(cat "$SERVER_PATH/minecraft_version.txt")" == "" ]
then
    echo "Downloading newest version of Minecraft (Version: $VERSION_NUM). If this is your first time installing Minecraft on this device, don't worry about any copy errors below."
else
    echo "Update found! Downloading new files for Minecraft version $VERSION_NUM. (Currently on version: $(cat "$SERVER_PATH/minecraft_version.txt"))"
fi

if ! wget -q --show-progress -O "$SERVER_PATH/minecraft-server-files.zip" "$FILE_LINK"
then
    echo "Failed to download file"
fi

echo "Finished downloading files"

# Stop server if running, wait 15 minutes if there are players online
./stop_server.sh -t 15 || exit 1

# Copy these files so they are not overwritten by the update
echo "Making a copy of your server files so the new ones won't overwrite them..."
mv "$SERVER_PATH/allowlist.json" "$SERVER_PATH/allowlist.json.old" && echo "• Copied allowlist.json"
mv "$SERVER_PATH/behavior_packs/" "$SERVER_PATH/behavior_packs.old/" && echo "• Copied behavior_packs/"
mv "$SERVER_PATH/config/" "$SERVER_PATH/config.old/" && echo "• Copied config/"
mv "$SERVER_PATH/definitions/" "$SERVER_PATH/definitions.old/" && echo "• Copied definitions/"
mv "$SERVER_PATH/permissions.json" "$SERVER_PATH/permissions.json.old" && echo "• Copied permissions.json"
mv "$SERVER_PATH/resource_packs/" "$SERVER_PATH/resource_packs.old/" && echo "• Copied resource_packs/"
mv "$SERVER_PATH/server.properties" "$SERVER_PATH./server.properties.old" && echo "• Copied server.properties"

# Extract new files
echo "Extracting new server files..."
(cd "$SERVER_PATH" && unzip -o "$SERVER_PATH/minecraft-server-files.zip" > /dev/null && rm "$SERVER_PATH/minecraft-server-files.zip")
echo "Extraction complete!"

# Restore the old files
### TODO: Check how these mergre/replace (e.g. not put folders inside folders)
echo "Finally, restoring copies..."
mv -f "$SERVER_PATH/allowlist.json.old" "$SERVER_PATH/allowlist.json" && echo "• Restored allowlist.json"
mv -f "$SERVER_PATH/behavior_packs.old/" "$SERVER_PATH/behavior_packs/" && echo "• Restored behavior_packs/"
mv -f "$SERVER_PATH/config.old/" "$SERVER_PATH/config/" && echo "• Restored config/"
mv -f "$SERVER_PATH/definitions.old/" "$SERVER_PATH/definitions/" && echo "• Restored definitions/"
mv -f "$SERVER_PATH/permissions.json.old" "$SERVER_PATH/permissions.json" && echo "• Restored permissions.json"
mv -f "$SERVER_PATH/resource_packs.old/" "$SERVER_PATH/resource_packs/" && echo "• Restored resource_packs/"
mv -f "$SERVER_PATH/server.properties.old" "$SERVER_PATH/server.properties" && echo "• Restored server.properties"
echo "Done! Your server is now updated to version $VERSION_NUM."

echo "$VERSION_NUM" > "$SERVER_PATH/minecraft_version.txt"

# Restart server
$AUTOSTART || read -r -p "Would you like to start the sever now? ($(pwd)) [Y/n] " VAL
if [[ "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]] || [ "$VAL" == "" ] || $AUTOSTART
then
    ./start_server.sh || exit 1
fi
