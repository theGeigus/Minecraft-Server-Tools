#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
source ./config_server.sh || exit 1

#--- INITIALIZE SERVER ---

# Check if server is already running
if [ "$(screen -ls | grep -o "$SERVER_NAME")" == "$SERVER_NAME" ]
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
else
	echo "Server has started successfully - You can connect at $(curl -s ifconfig.me):$PORT."
fi

# Set day and weather cycle to false until a player joins
if [ "${NO_PLAYER_ACTION^^}" == "PAUSE" ]
then
	screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle false \r"
	screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle false \r"
fi

# An excessive number of grep uses to pull a single number (>_<)
PORT=$(grep "IPv4" serverLog | grep -o -P " port: \d+" | grep -o -P "\d+")



#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

# Loop while server is running
while [ "$(screen -ls | grep  -o "$SERVER_NAME")" == "$SERVER_NAME" ]
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -qq -e MODIFY serverLog
	if [ "$(tail -3 serverLog | grep -o 'Player connected:')" == 'Player connected:' ]
	then

		# I think I'm making this more complicated than it needs to be... Oh well
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
		( while [ $COUNT -lt 10 ] ### Should add counter to cancel if player disconnects before spawning
		do
			if [ "$(tail -3 serverLog | grep -o 'Player Spawned:')" == 'Player Spawned:' ]
			then
				./announce_server.sh "$PLAYER_NAME"
				break
			else
				inotifywait -qq -e MODIFY serverLog
				((COUNT+=1))
			fi
		done
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
