#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
source ./config_server.sh || exit 1

#Create announcent file if missing. Should eventually be moved to update script.
touch announcements.txt

#--- INITIALIZE SERVER ---

# Check if server is already running
CHECK=$(screen -ls | grep -o "$SERVER_NAME")
if [ "$CHECK" == "$SERVER_NAME" ]
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
screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle false \r"
screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle false \r"

inotifywait -q -q -e MODIFY serverLog

# An excessive number of grep uses to pull a single number (>_<)
PORT=$(grep "IPv4" serverLog | grep -o -P " port: \d+" | grep -o -P "\d+")

echo "Server has started successfully - You can connect at $(curl -s ifconfig.me):$PORT."



#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

# Loop while server is running
while [ "$(screen -ls | grep -o "$SERVER_NAME")" == "$SERVER_NAME" ]
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -q -q -e MODIFY serverLog
	if [ "$(tail -3 serverLog | grep -o 'Player connected:')" == "Player connected:" ]
	then

		# I think I'm making this more complicated than it needs to be... Oh well, gotta love grep
		PLAYER_NAME=$(tail -3 serverLog | grep "Player connected" | grep -o ': .* xuid' | awk '{ print substr($0, 2, length($0)-7) }')

		echo "Player Connected - Restarting time!" >> serverLog

		# Set day and weather cycle to false
		screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle true \r"
		screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle true \r"

		# Send player a message after they spawn to make sure they recieve it
		COUNT=0
		( while [ "$(tail -3 serverLog | grep -o 'Player Spawned:')" != "Player Spawned:" ] && [ "$COUNT" -lt 10 ] ### Should add counter to cancel if player disconnects before spawning
		do
		inotifywait -q -q -e MODIFY serverLog
		done

		COUNT+=1
		sleep 1

		ANNOUNCEMENT=""
		while read -r LINE
		do
		ANNOUNCEMENT+="$LINE\\\n"
		done < "announcements.txt" 
		
		screen -Rd "$SERVER_NAME" -X stuff "tellraw $PLAYER_NAME {\"rawtext\": [{\"text\": \"$ANNOUNCEMENT\"}]} \r"

		) &


	else
		# If player disconnects, check for remaining players
		if [ "$(tail -3 serverLog | grep -o 'Player disconnected:')" == "Player disconnected:" ]
		then

			screen -Rd "$SERVER_NAME" -X stuff "list \r"

			# Wait for file update, if no players are online set day and weather cycle to be false
			inotifywait -q -q -e MODIFY serverLog > /dev/null
			if [ "$(tail -3 serverLog | grep -o 'There are 0')" == "There are 0" ]
			then

				echo "There are no players currently online - pausing time!" >> serverLog

				# Set day and weather cycle to false
				screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle false \r"
				screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle false \r"
			fi
		fi
	fi
done &
