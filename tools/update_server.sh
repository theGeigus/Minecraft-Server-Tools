#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"

printHelp(){
	echo "-h: Show this page and exit"
    echo "-c: Check if update is avalible, but do not update"
}

check_update=false
# Handle flags
while getopts 'hsc' OPTION
do
	case "$OPTION" in
	h)
        printHelp
        exit 0
        ;;
    c)
        check_update=true
        ;;
    ?)
		echo "Unknown option, '$OPTION'" >&2
		echo "Valid options are:"
		printHelp
		exit 1
    	;;
	esac
done

if ! command -v unzip -v wget > /dev/null
then
     echo "Dependencies are not met, please check that the following programs are installed:"
	 printf "\t- screen\n"
	 printf "\t- wget\n"
	 printf "\t- inotify-tools\n"
	 printf "\t- unzip\n"
     exit 1
fi


# Create server.config if it doesn't exist, eventually should ask things like java/bedrock
if ! [ -f "./server.config" ]
then
    echo 'File server.config does not exist... Creating config file!'

    source .configDefaults.txt

    # read -r -p "Would you like to download Minecraft to the current directory? ($(pwd)) [Y/n] " val

    # if [[ ! "$val" =~ ^([yY][eE][sS]|[yY])$ ]] && [ "$val" != "" ]
    # then
    #     read -r -p "Where should Minecraft be stored? " SERVER_PATH

    #     SERVER_PATH=$(eval echo "../server")

    #     if ! (cd "../server" > /dev/null)
    #     then
    #         echo "Creating new location: ../server"
    #         if ! mkdir -p "../server"
    #         then
    #             echo "Invalid location. Check to make sure this directory (../server) exists and that you have access to it."
    #             exit 1
    #         fi
    #     fi
    # fi

    if ! touch "../server/minecraft_version.txt" 2> /dev/null
    then
        echo "Cannot write to directory '$(cd .. && pwd)/server', check if you have permisson to write there."
        exit 1
    fi

    while read -r line
    do
       if [ "${line:0:1}" == '#' ]
       then
            echo "$line" >> server.config
        else
            eval echo "$line" >> server.config
        fi
    done < ".baseConfig.txt"

    echo "Config file created"
fi

source ./server.config

url="https://www.minecraft.net/en-us/download/server/bedrock" # If planning on Java support in the future, this URL should be set based on the edition we are using.
agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"

echo "Checking for an update..."
download_link="$(curl -A "$agent" "$url" 2> /dev/null | grep -o "https://minecraft.azureedge.net/bin-linux/bedrock-server-.*.zip")"

version=$(echo "$download_link" | grep -o "bedrock-server-.*.zip" | awk '{ print substr($0, 16, length($0)-19) }')

# Check if version from link matches the current installed version.
if ! touch "../server/minecraft_version.txt" 2> /dev/null
then
    echo "Cannot write to directory '../server', check if you have permisson to write there."
    exit 1
fi

if [ "$(cat "../server/minecraft_version.txt")" == "$version" ]
then
    echo "Minecraft is already up to date! Currently on version $(cat "../server/minecraft_version.txt")."

    exit 0
else
    if $check_update
    then
        echo "There is an update avalible for your server. Minecraft version $version is now avalible. (Currently on version $(cat "../server/minecraft_version.txt"))"

        [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] &&
            echo "There is an update avalible for your server. Minecraft version $version is now avalible. (Currently on version $(cat "../server/minecraft_version.txt"))" > .adminAnnouncements.txt

        exit 0
    fi

fi

# Download file
if [ "$(cat "../server/minecraft_version.txt")" == "" ]
then
    echo "new install" > "../server/minecraft_version.txt" # For message printed later
    echo "Downloading newest version of Minecraft (Version: $version). If this is your first time installing Minecraft on this device, don't worry about any copy errors below."
else
    echo "Update found! Downloading new files for Minecraft version $version. (Currently on version: $(cat "../server/minecraft_version.txt"))"
fi

if ! wget -q --show-progress -O "../server/minecraft-server-files.zip" "$download_link"
then
    echo "Failed to download file"
fi

echo "Finished downloading files"

# Stop server if running, wait 15 minutes if there are players online
./stop_server.sh -t 15 || exit 1

# Copy these files so they are not overwritten by the update
echo "Making a copy of your server files so the new ones won't overwrite them..."
mv "../server/allowlist.json" "../server/allowlist.json.old" && echo "• Copied allowlist.json"
mv "../server/behavior_packs/" "../server/behavior_packs.old/" && echo "• Copied behavior_packs/"
mv "../server/config/" "../server/config.old/" && echo "• Copied config/"
mv "../server/definitions/" "../server/definitions.old/" && echo "• Copied definitions/"
mv "../server/permissions.json" "../server/permissions.json.old" && echo "• Copied permissions.json"
mv "../server/resource_packs/" "../server/resource_packs.old/" && echo "• Copied resource_packs/"
mv "../server/server.properties" "../server/server.properties.old" && echo "• Copied server.properties"

# Extract new files
echo "Extracting new server files..."
(cd "../server" && unzip -o "../server/minecraft-server-files.zip" > /dev/null && rm "../server/minecraft-server-files.zip")
echo "Extraction complete!"

# Restore the old files
### TODO: Check how these mergre/replace (e.g. not put folders inside folders)
echo "Finally, restoring copies..."
mv -f "../server/allowlist.json.old" "../server/allowlist.json" && echo "• Restored allowlist.json"
mv -f "../server/behavior_packs.old/" "../server/behavior_packs/" && echo "• Restored behavior_packs/"
mv -f "../server/config.old/" "../server/config/" && echo "• Restored config/"
mv -f "../server/definitions.old/" "../server/definitions/" && echo "• Restored definitions/"
mv -f "../server/permissions.json.old" "../server/permissions.json" && echo "• Restored permissions.json"
mv -f "../server/resource_packs.old/" "../server/resource_packs/" && echo "• Restored resource_packs/"
mv -f "../server/server.properties.old" "../server/server.properties" && echo "• Restored server.properties"
echo "Done! Your server is now updated to version $version."

[ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] &&
    echo "Minecraft was updated to version $version. (From $(cat "../server/minecraft_version.txt"))" > .adminAnnouncements.txt

echo "$version" > "../server/minecraft_version.txt"
