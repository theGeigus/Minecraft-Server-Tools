#! /bin/bash

### TODO: Add check to see if the server is running

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"

# Check for config
if ! source server.config
then
    echo "File 'server.config' not found. Run please run 'update_server.sh' or 'start_server.sh' and try again."
    exit 1
fi

printHelp(){
	echo "-h: Show this page and exit"
	echo "-a MESSAGE: prints given message as an announcement"
    echo "-p PLAYER: Send announcement to only the given player"
}

announce() {
    # Print message with tellraw
    announcement="{\"text\": \"$announcement\"}"
    [ "${EDITION^^}" == "BEDROCK" ] && announcement="{\"rawtext\": [$announcement]}"
    screen -Rd "$SERVER_NAME" -X stuff "tellraw $player_name $announcement\r"
}

# Check for arguments
while getopts 'ha:p:' OPTION
do
	case "$OPTION" in
    h)
        printHelp
        exit 0
        ;;
    p)
        player_name="$OPTARG"
        ;;
    a)
        # If no player name is supplied, announce to everyone.
        if [ "$player_name" == "" ]
        then
            player_name="@a"
        fi
        announcement="$(echo "$OPTARG" | sed -r 's/\\+/\\\\/g')" # Add extra backslashes any time the user uses one

        announce
        exit 0
        ;;
    ?)
        echo "Valid options are:"
        printHelp
        exit 1
        ;;
	esac
done

# If no player name is supplied, announce to everyone.
if [ "$player_name" == "" ]
then
    player_name="@a"
fi

# Announcement system, defined as a function for easy use with cases below.
getAnnouncements() {
    announcement=""

    # Add each line to the announcement
    while read -r line
    do
        line=$(echo "$line" | sed -r 's/"+/\\\\"/g') # Escape any double quotes
        announcement+="$line\\\n"
    done < "$1"
}

# Cases for admin announcement handling
if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
then
    touch .adminAnnouncements.txt
    touch .hasSeenAdminAnnouncement

    getAnnouncements .adminAnnouncements.txt
    if [ "$(echo "$ADMIN_LIST" | grep -o "$player_name")" == "$player_name" ]
    then
        if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
        then
            if ! grep -q -o "$player_name" .hasSeenAdminAnnouncement
            then
                echo "$player_name" >> .hasSeenAdminAnnouncement
                announce
            elif ! cmp --silent .adminAnnouncements.txt .prevAdminAnnouncement
            then
                echo "$player_name" > .hasSeenAdminAnnouncement
                cat .adminAnnouncements.txt > .prevAdminAnnouncement
                announce
            fi
        else
            announce
        fi
    fi
fi

    # Cases for Announcement handling, check if enabled
if [ "${DO_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
then
    touch announcements.txt
    touch .hasSeenAnnouncement

    getAnnouncements announcements.txt
    # If set to once, check if seen
    if [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
    then
        if ! grep -q -o "$player_name" .hasSeenAnnouncement
        then
            echo "$player_name" >> .hasSeenAnnouncement
        elif ! cmp --silent announcements.txt .prevAnnouncement
        then
            echo "$player_name" > .hasSeenAnnouncement
            cat announcements.txt > .prevAnnouncement
        else
            exit 0
        fi
    fi
    announce
fi
