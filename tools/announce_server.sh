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

# Check for arguments
while getopts 'ha:p:' OPTION
do
	case "$OPTION" in
    h)
        printHelp
        exit 0
        ;;
    a)
        announcement="$OPTARG"
        ;;
    p)
        player_name="$OPTARG"
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
printAnnouncements() {

    if grep -q -P -m 1 "[^s]" "$1"
    then
        # Add each line to the announcement

        if [ "$announcement" == "" ]
        then
            while read -r line
            do
                line=$(echo "$line" | sed -r 's/"+/\\\\"/g') # Escape any double quotes
                announcement+="$line\\\n"
            done < "$1"
        else
            announcement=$(echo "$announcement" | sed -r 's/"+/\\\\"/g')
            announcement=$(echo "$announcement" | sed -r 's/\\+/\\\\/g') # Add extra backslashes any time the user uses one
        fi

        # Wait 1 sec to make sure player actually recieves it.
        sleep 1;

        # Print message with tellraw
        screen -Rd "$SERVER_NAME" -X stuff "tellraw $player_name {\"rawtext\": [{\"text\": \"$announcement\"}]} \r"
    fi
}

# Cases for admin announcement handling
if [ "$announcement" == "" ] && [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
then
    touch .adminAnnouncements.txt
    touch .hasSeenAdminAnnouncement
    # If set to once, check if seen
    if [ "$(echo "$ADMIN_LIST" | grep -o "$player_name")" == "$player_name" ] #
    then
        if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
        then
            if ! grep -q -o "$player_name" .hasSeenAdminAnnouncement
            then
                echo "$player_name" >> .hasSeenAdminAnnouncement
                printAnnouncements ".adminAnnouncements.txt"

            # Check if announcement has been changed.
            elif ! cmp --silent .adminAnnouncements.txt .prevAdminAnnouncement
            then
                echo "$player_name" > .hasSeenAdminAnnouncement
                cat .adminAnnouncements.txt > .prevAdminAnnouncement
                printAnnouncements ".adminAnnouncements.txt"
            fi
        fi
    fi

    announcement="" #Set announcement back to "" so regular announcement will run

fi

    # Cases for Announcement handling, check if enabled
if [ "${DO_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ] || [ "$player_name" != "" ]
then
    touch announcements.txt
    touch .hasSeenAnnouncement
    # If set to once, check if seen
    if [ "$player_name" == "" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
    then

        if ! grep -q -o "$player_name" .hasSeenAnnouncement
        then
            echo "$player_name" >> .hasSeenAnnouncement
            printAnnouncements "announcements.txt"

        # Check if announcement has been changed.
        elif ! cmp --silent announcements.txt .prevAnnouncement
        then
            echo "$player_name" > .hasSeenAnnouncement
            cat announcements.txt > .prevAnnouncement
            printAnnouncements "announcements.txt"
        fi
    fi
else
    printAnnouncements "announcements.txt"
fi
