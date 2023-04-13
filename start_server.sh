#!/bin/bash

# Import variables
source ./config_server.sh


#--- INITIALIZE SERVER ---

# Check if server is already running
CHECK=`screen -ls | grep -o $SERVER_NAME`
if [ "$CHECK" == "$SERVER_NAME" ]
then
	echo "The server is already running"
	exit 0

else

	# Clear previous log file and link it to the screen
	echo "" > serverLog
	screen -dmS $SERVER_NAME -L -Logfile serverLog bash -c "LD_LIBRARY_PATH=${SOURCE_PATH}/ ${SOURCE_PATH}/bedrock_server"

	echo "Server is now starting!"
	sleep 2

	# Check if server is running, exit if not.
	CHECK=`screen -ls | grep -o $SERVER_NAME`
	if [ "$CHECK" != "$SERVER_NAME" ]
	then
		echo "Server failed to start!"
		exit 0
	else
		# Set day and weather cycle to false until a player joins
		screen -Rd $SERVER_NAME -X stuff "gamerule dodaylightcycle false \r"
		screen -Rd $SERVER_NAME -X stuff "gamerule doweathercycle false \r"

		echo "Server has started successfully - You can connect at $(curl -s ifconfig.me)/19132."
	fi
fi


#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

# Loop while server is running
while [ "$(screen -ls | grep -o $SERVER_NAME)" == "$SERVER_NAME" ]
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -q -q -e MODIFY serverLog
	if [ "$(tail -3 serverLog | grep -o 'Player connected:')" == "Player connected:" ]
	then
		echo "---" >> serverLog
		echo "Player Connected - Restarting time!" >> serverLog
		echo "---" >> serverLog

		# Set day and weather cycle to false
		screen -Rd $SERVER_NAME -X stuff "gamerule dodaylightcycle true \r"
		screen -Rd $SERVER_NAME -X stuff "gamerule doweathercycle true \r"

	else
		# If player disconnects, check for remaining players
		if [ "$(tail -3 serverLog | grep -o 'Player disconnected:')" == "Player disconnected:" ]
		then
			echo "---" >> serverLog
			echo "Player Disconnected - Checking for remaining players." >> serverLog
			echo "---" >> serverLog
			screen -Rd $SERVER_NAME -X stuff "list \r"

			# Wait for file update, if no players are online set day and weather cycle to be false
			inotifywait -q -q -e MODIFY serverLog > /dev/null
			if [ "$(tail -3 serverLog | grep -o 'There are 0')" == "There are 0" ]
			then
				echo "---" >> serverLog
				echo "There are no players currently online - pausing time!" >> serverLog
				echo "---" >> serverLog

				# Set day and weather cycle to false
				screen -Rd $SERVER_NAME -X stuff "gamerule dodaylightcycle false \r"
				screen -Rd $SERVER_NAME -X stuff "gamerule doweathercycle false \r"
			fi
		fi
	fi
done &
