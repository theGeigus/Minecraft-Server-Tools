#! /bin/bash
### While functional, the entire announcement section is kind of a mess... Fix?
source ./config_server.sh
# Announcement system, defined as a function for easy use with cases below.
printAnnouncements(){
    if grep -q -P -m 1 "[^s]" $ANNOUNCEMENT_FILE
    then
        # Add each line to the announcement
        ANNOUNCEMENT=""
        while read -r LINE
        do
            ANNOUNCEMENT+="$LINE\\\n"
        done < $ANNOUNCEMENT_FILE 

        # Wait 2 sec to make sure player actually recieves it.
        sleep 2;

        # Print message with tellraw
        screen -Rd "$SERVER_NAME" -X stuff "tellraw $1 {\"rawtext\": [{\"text\": \"$ANNOUNCEMENT\"}]} \r"
    fi
}

    # Cases for Announcement handling, check if enabled
if [ "${DO_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
then
    touch announcements.txt
    touch .hasSeenAnnouncement
    ANNOUNCEMENT_FILE="announcements.txt"
    # If set to once, check if seen
    if [ "${DO_ANNOUNCEMENTS^^}" == "ONCE" ]
    then 
    
        if ! grep -q -o "$1" .hasSeenAnnouncement 
        then
            echo "$1" >> .hasSeenAnnouncement
            printAnnouncements "$@"
        else
            # Check if announcement has been changed.
            if ! cmp --silent announcements.txt .prevAnnouncement 
            then
                echo "$1" > .hasSeenAnnouncement
                cat announcements.txt > .prevAnnouncement
                printAnnouncements "$@"
            fi
        fi
    else
        printAnnouncements "$@"
    fi
fi

# Cases for admin announcement handleing
if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
then
    touch adminAnnouncements.txt
    touch .hasSeenAdminAnnouncement
    ANNOUNCEMENT_FILE="adminAnnouncements.txt"
    # If set to once, check if seen
    if echo "$ADMIN_LIST" | grep -q -o "$1"
    then
        if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] 
        then
            if ! grep -q -o "$1" .hasSeenAdminAnnouncement
            then
                echo "$1" >> .hasSeenAdminAnnouncement
                printAnnouncements "$@"
            else
                # Check if announcement has been changed.
                if ! cmp --silent adminAnnouncements.txt .prevAdminAnnouncement 
                then
                    echo "$1" > .hasSeenAdminAnnouncement
                    cat adminAnnouncements.txt > .prevAdminAnnouncement
                    printAnnouncements "$@"
                fi
            fi
        else
            printAnnouncements "$@"
        fi
    fi
fi