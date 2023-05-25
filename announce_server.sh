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
			ANNOUNCEMENT="$OPTARG"
			;;
        p)
            PLAYER_NAME="$OPTARG"
            ;;
    	?)
			echo "Valid options are:"
			printHelp
			exit 1
      		;;
	esac
done

# If no player name is supplied, announce to everyone.
if [ "$PLAYER_NAME" == "" ]
then
    PLAYER_NAME="@a"
fi

# Announcement system, defined as a function for easy use with cases below.
printAnnouncements(){

    if grep -q -P -m 1 "[^s]" "$1"
    then
        # Add each line to the announcement

        if [ "$ANNOUNCEMENT" == "" ]
        then
            while read -r LINE
            do
                LINE=$(echo "$LINE" | sed -r 's/"+/\\\\"/g') # Escape any double quotes
                ANNOUNCEMENT+="$LINE\\\n"
            done < "$1" 
        else
            ANNOUNCEMENT=$(echo "$ANNOUNCEMENT" | sed -r 's/"+/\\\\"/g') 
            ANNOUNCEMENT=$(echo "$ANNOUNCEMENT" | sed -r 's/\\+/\\\\/g') # Add extra backslashes any time the user uses one
        fi

        # Wait 2 sec to make sure player actually recieves it.
        sleep 2;

        # Print message with tellraw
        screen -Rd "$SERVER_NAME" -X stuff "tellraw $PLAYER_NAME {\"rawtext\": [{\"text\": \"$ANNOUNCEMENT\"}]} \r"
    fi
}

# Cases for admin announcement handling
if [ "$ANNOUNCEMENT" == "" ] && [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] 
then
    touch .adminAnnouncements.txt
    touch .hasSeenAdminAnnouncement
    # If set to once, check if seen
    if [ "$(echo "$ADMIN_LIST" | grep -o "$PLAYER_NAME")" == "$PLAYER_NAME" ] #
    then
        if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] 
        then
            if ! grep -q -o "$PLAYER_NAME" .hasSeenAdminAnnouncement
            then
                echo "$PLAYER_NAME" >> .hasSeenAdminAnnouncement
                printAnnouncements ".adminAnnouncements.txt"
            else
                # Check if announcement has been changed.
                if ! cmp --silent .adminAnnouncements.txt .prevAdminAnnouncement
                then
                    echo "$PLAYER_NAME" > .hasSeenAdminAnnouncement
                    cat .adminAnnouncements.txt > .prevAdminAnnouncement
                    printAnnouncements ".adminAnnouncements.txt"
                fi
            fi
        fi
    fi

    ANNOUNCEMENT="" #Set announcement back to "" so regular announcement will run

fi

    # Cases for Announcement handling, check if enabled
if [ "${DO_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ] || [ "$PLAYER_NAME" != "" ]
then
    touch announcements.txt
    touch .hasSeenAnnouncement
    # If set to once, check if seen
    if [ "$PLAYER_NAME" == "" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
    then 
    
        if ! grep -q -o "$PLAYER_NAME" .hasSeenAnnouncement 
        then
            echo "$PLAYER_NAME" >> .hasSeenAnnouncement
            printAnnouncements "announcements.txt"
        else
            # Check if announcement has been changed.
            if ! cmp --silent announcements.txt .prevAnnouncement 
            then
                echo "$PLAYER_NAME" > .hasSeenAnnouncement
                cat announcements.txt > .prevAnnouncement
                printAnnouncements "announcements.txt"
            fi
        fi
    else
        printAnnouncements "announcements.txt"
    fi
fi
