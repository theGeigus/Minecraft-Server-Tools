#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"
TOOLS_PATH=$(pwd)

# Check for config
if ! source server.config
then
    echo "File 'server.config' not found. Run please run 'update_server.sh' and try again."
    exit 1
fi

### INITIALIZE SERVER ###

if [ "${WORLD_BACKUP^^}" == "YES" ]
then
	./backup_server.sh -a
fi

# Generate fortune
if [ "${DO_FORTUNE^^}" == "YES" ]
	then
	echo "Generating fortune..."

	echo "§k~~~§rToday's fortune:§k~~~§r" > announcements.txt
	fortune -s >> announcements.txt
fi

cd "$SERVER_PATH" || echo "Something broke, could not find directory?"

# Check if server is already running
if [ "$(screen -ls | grep -o "$SERVER_NAME")" == "$SERVER_NAME" ]
then
	echo "The server is already running"
	exit 0
fi

echo "Starting server..."

# Clear previous log file and link it to the screen
echo "" > "$TOOLS_PATH/.server.log"
screen -dmS "$SERVER_NAME" -L -Logfile "$TOOLS_PATH/.server.log" bash -c "LD_LIBRARY_PATH=${SERVER_PATH}/ ${SERVER_PATH}/bedrock_server"
screen -Rd "$SERVER_NAME" -X logfile flush 1 # 1 sec delay to file logging as instant logging was too fast to handle properly

# Error reporting for wrong directory, we'll let it keep running for now as next step should terminate it anyway.
grep -q "No such file or directory" "$TOOLS_PATH/.server.log" &&
	echo "ERROR: Could not find Minecraft's server files. Check your path in 'server.config' or run 'update_server.sh' and try again."

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
PORT=$(grep "IPv4" "$TOOLS_PATH/.server.log" | grep -o -P " port: \d+" | grep -o -P "\d+")

#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

# Loop while server is running
while [ "$(screen -ls | grep  -o "$SERVER_NAME")" == "$SERVER_NAME" ]
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -qq -e MODIFY "$TOOLS_PATH/.server.log"
	if [ "$(tail -3 "$TOOLS_PATH/.server.log" | grep -o 'Player connected:')" == 'Player connected:' ]
	then

		# I think I'm making this more complicated than it needs to be... Oh well
		PLAYER_NAME=$(tail -3 "$TOOLS_PATH/.server.log" | grep "Player connected" | grep -o ': .* xuid' | awk '{ print substr($0, 3, length($0)-8) }')

		echo "Player Connected - Restarting time!" >> "$TOOLS_PATH/.server.log"

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
			if [ "$(tail -3 "$TOOLS_PATH/.server.log" | grep -o 'Player Spawned:')" == 'Player Spawned:' ]
			then
				"$TOOLS_PATH/announce_server.sh" -p "$PLAYER_NAME"
				break
			else
				inotifywait -qq -e MODIFY "$TOOLS_PATH/.server.log"
				((COUNT+=1))
			fi
		done
		)&

	else
		# If player disconnects, check for remaining players
		if [ "$(tail -3 "$TOOLS_PATH/.server.log" | grep -o 'Player disconnected:')" == "Player disconnected:" ]
		then

			screen -Rd "$SERVER_NAME" -X stuff "list \r"

			# Wait for file update, if no players are online set day and weather cycle to be false
			inotifywait -qq -e MODIFY "$TOOLS_PATH/.server.log" > /dev/null
			if [ "$(tail -3 "$TOOLS_PATH/.server.log" | grep -o 'There are 0')" == "There are 0" ]
			then

				echo "There are no players currently online - pausing time!" >> "$TOOLS_PATH/.server.log"

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
