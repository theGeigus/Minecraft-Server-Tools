#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
source ./config_server.sh


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
		PLAYER_NAME=$(grep "Player connected" serverLog | grep -o ': .* xuid' | awk '{ print substr($0, 2, length($0)-7) }')

		echo "Player Connected - Restarting time!" >> serverLog

		# Set day and weather cycle to false
		screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle true \r"
		screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle true \r"

		# Send player a message after they spawn to make sure they recieve it
		( while [ "$(tail -3 serverLog | grep -o 'Player Spawned:')" != "Player Spawned:" ] ### Should add counter to cancel if player disconnects before spawning
		do
		inotifywait -q -q -e MODIFY serverLog
		done

		sleep 1

		while read -r LINE
		do
		  screen -Rd "$SERVER_NAME" -X stuff "tellraw $PLAYER_NAME {\"rawtext\": [{\"text\": \"$LINE\"}]} \r"
		done < "announcements.txt" ) &

	else
		# If player disconnects, check for remaining players
		if [ "$(tail -3 serverLog | grep -o 'Player disconnected:')" == "Player disconnected:" ]
		then
			echo "Player Disconnected - Checking for remaining players." >> serverLog

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
