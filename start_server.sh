#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
source ./config_server.sh || exit 1

#Create announcent file if missing. Should eventually be moved to update script.
touch announcements.txt

#--- INITIALIZE SERVER ---

# Check if server is already running
if screen -ls | grep -q -o "$SERVER_NAME"
then
	echo "The server is already running"
	exit 0

fi

# Clear previous log file and link it to the screen
echo "" > serverLog
screen -dmS "$SERVER_NAME" -L -Logfile serverLog bash -c "LD_LIBRARY_PATH=${SOURCE_PATH}/ ${SOURCE_PATH}/bedrock_server"
screen -Rd "$SERVER_NAME" -X logfile flush 1 # 1 sec delay to file logging as instant logging was too fast to handle properly

echo "Server is now starting!"

# Check if server is running, exit if not.
CHECK=$(screen -ls | grep -o "$SERVER_NAME")
if [ "$CHECK" != "$SERVER_NAME" ]
then
	echo "Server failed to start!"
	exit 1
fi

# Set day and weather cycle to false until a player joins
if [ "${NO_PLAYER_ACTION^^}" == "PAUSE" ]
then
	screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle false \r"
	screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle false \r"
fi

inotifywait -qq -e MODIFY serverLog

# An excessive number of grep uses to pull a single number (>_<)
PORT=$(grep "IPv4" serverLog | grep -o -P " port: \d+" | grep -o -P "\d+")

echo "Server has started successfully - You can connect at $(curl -s ifconfig.me):$PORT."



#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

# Loop while server is running
while screen -ls | grep -q -o "$SERVER_NAME"
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -qq -e MODIFY serverLog
	if tail -3 serverLog | grep -q -o 'Player connected:'
	then

		# I think I'm making this more complicated than it needs to be... Oh well, gotta love grep
		PLAYER_NAME=$(tail -3 serverLog | grep "Player connected" | grep -o ': .* xuid' | awk '{ print substr($0, 3, length($0)-8) }')

		echo "Player Connected - Restarting time!" >> serverLog

		# Set day and weather cycle to false if set to pause mode
		if [ "$NO_PLAYER_ACTION" == "PAUSE" ]
		then
			screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle true \r"
			screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle true \r"
		fi


		# Check if announcement actually has text in it.
		
		# Send player a message after they spawn to make sure they recieve it
		COUNT=0
		( while tail -3 serverLog | grep -q -o 'Player Spawned:' && [ "$COUNT" -lt 10 ] ### Should add counter to cancel if player disconnects before spawning
		do
			inotifywait -qq -e MODIFY serverLog
			COUNT+=1
		done

		### While functional, the entire announcement section is kind of a mess... Fix?
		if tail -3 serverLog | grep -q -o 'Player Spawned:'
		then
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
					screen -Rd "$SERVER_NAME" -X stuff "tellraw $PLAYER_NAME {\"rawtext\": [{\"text\": \"$ANNOUNCEMENT\"}]} \r"
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
				
					if [ "$(grep -o "$PLAYER_NAME" .hasSeenAnnouncement)" != "$PLAYER_NAME" ]
					then
						echo "$PLAYER_NAME" >> .hasSeenAnnouncement
						printAnnouncements;
					else
						# Check if announcement has been changed.
						if ! cmp --silent announcements.txt .prevAnnouncement 
						then
							echo "$PLAYER_NAME" > .hasSeenAnnouncement
							cat announcements.txt > .prevAnnouncement
							printAnnouncements;
						fi
					fi
				else
					printAnnouncements;
				fi
			fi

			# Cases for admin announcement handleing
			if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "YES" ] || [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ]
			then
				touch adminAnnouncements.txt
				touch .hasSeenAdminAnnouncement
				ANNOUNCEMENT_FILE="adminAnnouncements.txt"
				# If set to once, check if seen
				if [ "$(echo "$ADMIN_LIST" | grep -o "$PLAYER_NAME")" == "$PLAYER_NAME" ]
				then
					if [ "${DO_ADMIN_ANNOUNCEMENTS^^}" == "ONCE" ] 
					then
						if [ "$( grep -o "$PLAYER_NAME" .hasSeenAdminAnnouncement)" != "$PLAYER_NAME" ]
						then
							echo "$PLAYER_NAME" >> .hasSeenAdminAnnouncement
							printAnnouncements;
						else
							# Check if announcement has been changed.
							if ! cmp --silent adminAnnouncements.txt .prevAdminAnnouncement 
							then
								echo "$PLAYER_NAME" > .hasSeenAdminAnnouncement
								cat adminAnnouncements.txt > .prevAdminAnnouncement
								printAnnouncements;
							fi
						fi
					else
						printAnnouncements;
					fi
				fi
			fi
		fi

		)&


	else
		# If player disconnects, check for remaining players
		if [ "$(tail -3 serverLog | grep -o 'Player disconnected:')" == "Player disconnected:" ]
		then

			screen -Rd "$SERVER_NAME" -X stuff "list \r"

			# Wait for file update, if no players are online set day and weather cycle to be false
			inotifywait -qq -e MODIFY serverLog > /dev/null
			if [ "$(tail -3 serverLog | grep -o 'There are 0')" == "There are 0" ]
			then

				echo "There are no players currently online - pausing time!" >> serverLog

				if [ "$NO_PLAYER_ACTION" == "PAUSE" ]
				then
					# Set day and weather cycle to false
					screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle false \r"
					screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle false \r"
				else 
					if [ "$NO_PLAYER_ACTION" == "SHUTDOWN" ]
					then
						(./stop_server.sh -t 0)
					fi
				fi
			fi
		fi
	fi
done &
