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

    declare val

    while [ "$val" != 1 ] && [ "$val" != 2 ]
    do

        echo "What edition of Minecraft will this server be?"
        printf "\t1. Bedrock Edition\n"
        printf "\t2. Java Edition\n"
        read -r -p  "Enter number: " val

    done

    if [ "$val" == 1 ]
    then
        EDITION="BEDROCK"
        serverPath="bedrock-server"
    else
        EDITION="JAVA"
        serverPath="java-server"
    fi

    if ! (cd "../$serverPath" > /dev/null)
    then
        echo "Creating new location: ../$serverPath"
        if ! mkdir -p "../$serverPath"
        then
            echo "Invalid location. Check to make sure you have permission to access this directory. ($(cd .. && pwd)/$serverPath)"
            exit 1
        fi
    fi

    if ! touch "../$serverPath/minecraft_version.txt" 2> /dev/null
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
serverPath="${EDITION,,}-server/"

agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36"
echo "Checking for an update..."

if [ "${EDITION^^}" == "BEDROCK" ]
then
    url="https://www.minecraft.net/en-us/download/server/bedrock"
    download_link="$(curl -A "$agent" "$url" 2> /dev/null | grep -o "https://minecraft.azureedge.net/bin-linux/bedrock-server-.*.zip")"
    version=$(echo "$download_link" | grep -o "bedrock-server-.*.zip" | awk '{ print substr($0, 16, length($0)-19) }')

elif [ "${EDITION^^}" == "JAVA" ]
then
    url="https://www.minecraft.net/en-us/download/server"
    # Because of course Java Edition wouldn't put its version number neatly in the download URL like Bedrock would. :(
    web="$(curl -A "$agent" "$url" 2> /dev/null)"
    download_link="$(echo "$web" | grep -o -m 1 "https://piston-data.mojang.com/v1/objects/.*/server.jar")"
    version="$(echo "$web" | grep -o -m 1 "minecraft_server.*.jar" | awk '{ print substr($0, 18, length($0)-21) }' )"
else
    echo "Invalid version, check your server.config and try again"
    exit 1
fi

# Check if version from link matches the current installed version.
if ! touch "../$serverPath/minecraft_version.txt" 2> /dev/null
then
    echo "Cannot write to directory '$(cd .. && pwd)/$serverPath', check if you have permisson to write there."
    exit 1
fi

if [ "$(cat "../$serverPath/minecraft_version.txt")" == "$version" ]
then
    echo "Minecraft is already up to date! Currently on version $(cat "../$serverPath/minecraft_version.txt")."

    exit 0
elif $check_update
then
    echo "There is an update avalible for your server. Minecraft version $version is now avalible. (Currently on version $(cat "../$serverPath/minecraft_version.txt"))"

    [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] &&
        echo "There is an update avalible for your server. Minecraft version $version is now avalible. (Currently on version $(cat "../$serverPath/minecraft_version.txt"))" > .adminAnnouncements.txt

    exit 0
fi

# Download file
if [ "$(cat "../$serverPath/minecraft_version.txt")" == "" ]
then
    echo "new install" > "../$serverPath/minecraft_version.txt" # For message printed later
    echo "Downloading newest version of Minecraft (Version: $version)."
    [ "${EDITION^^}" == "BEDROCK" ] && echo "If this is your first time installing Minecraft on this device, don't worry about any copy errors below."
else
    echo "Update found! Downloading new files for Minecraft version $version. (Currently on version: $(cat "../$serverPath/minecraft_version.txt"))"
fi

if [ "${EDITION^^}" == "BEDROCK" ]
then
    if ! wget -q --show-progress -O "../$serverPath/minecraft-server-files.zip" "$download_link"
    then
        echo "Failed to download file"
        exit 1
    fi

    echo "Finished downloading files"

    # Stop server if running, wait 15 minutes if there are players online
    ./stop_server.sh -t 15 || exit 1

    # Copy these files so they are not overwritten by the update
    echo "Making a copy of your server files so the new ones won't overwrite them..."
    mv "../$serverPath/allowlist.json" "../$serverPath/allowlist.json.old" && echo "• Copied allowlist.json"
    mv "../$serverPath/behavior_packs/" "../$serverPath/behavior_packs.old/" && echo "• Copied behavior_packs/"
    mv "../$serverPath/config/" "../$serverPath/config.old/" && echo "• Copied config/"
    mv "../$serverPath/definitions/" "../$serverPath/definitions.old/" && echo "• Copied definitions/"
    mv "../$serverPath/permissions.json" "../$serverPath/permissions.json.old" && echo "• Copied permissions.json"
    mv "../$serverPath/resource_packs/" "../$serverPath/resource_packs.old/" && echo "• Copied resource_packs/"
    mv "../$serverPath/server.properties" "../$serverPath/server.properties.old" && echo "• Copied server.properties"

    # Extract new files
    echo "Extracting new server files..."
    (cd "../$serverPath" && unzip -o "../$serverPath/minecraft-server-files.zip" > /dev/null && rm "../$serverPath/minecraft-server-files.zip")
    echo "Extraction complete!"

    # Restore the old files
    ### TODO: Check how these mergre/replace (e.g. not put folders inside folders)
    echo "Finally, restoring copies..."
    mv -f "../$serverPath/allowlist.json.old" "../$serverPath/allowlist.json" && echo "• Restored allowlist.json"
    mv -f "../$serverPath/behavior_packs.old/" "../$serverPath/behavior_packs/" && echo "• Restored behavior_packs/"
    mv -f "../$serverPath/config.old/" "../$serverPath/config/" && echo "• Restored config/"
    mv -f "../$serverPath/definitions.old/" "../$serverPath/definitions/" && echo "• Restored definitions/"
    mv -f "../$serverPath/permissions.json.old" "../$serverPath/permissions.json" && echo "• Restored permissions.json"
    mv -f "../$serverPath/resource_packs.old/" "../$serverPath/resource_packs/" && echo "• Restored resource_packs/"
    mv -f "../$serverPath/server.properties.old" "../$serverPath/server.properties" && echo "• Restored server.properties"
else
    # Clearly updating Java Edition is SIGNIFICANTLY easier...
    if ! wget -q --show-progress -O "../$serverPath/java_server.jar" "$download_link"
    then
        echo "Failed to download file"
        exit 1
    fi

    echo "Finished downloading files"
fi

echo "Done! Your server is now updated to version $version."

[ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] &&
    echo "Minecraft was updated to version $version. (From $(cat "../$serverPath/minecraft_version.txt"))" > .adminAnnouncements.txt

echo "$version" > "../$serverPath/minecraft_version.txt"
