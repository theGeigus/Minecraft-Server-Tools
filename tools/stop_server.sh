#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" ||  echo "Something broke, could not find directory?"

# Check for config
if ! source server.config
then
    echo "File 'server.config' not found. Run please run 'update_server.sh' or 'start_server.sh' and try again."
    exit 1
fi

printHelp(){
	echo "-h: Show this page and exit"
	echo "-t NUMBER: set delay to stop the server, given in minutes. Ignored if there are no players are online."
	echo "-r MESSAGE: shows reason for shutdown when kicking players, as well as during the countdown to shutdown."
}

time=-1
# Check for arguments, if any. Only takes -t as of now
while getopts 'ht:r:' OPTION
do
	case "$OPTION" in
	h)
		printHelp
		exit 0
		;;
	t)
		if [ "$OPTARG" -ge 0 ]
		then
			time=$OPTARG
		else
			echo "Given time must be 0 or greater (in minutes)"
			exit 1
		fi
		;;
	?)
		echo "Unknown option, '$OPTION'" >&2
		echo "Valid options are:"
		printHelp
		exit 1
		;;
	esac
done

#--- STOP SERVER ---

# Check if server is running, exit if false
echo "Checking if server is running..."
check=$(screen -ls | grep -o $SERVER_NAME)
if [ "$check" == "$SERVER_NAME" ]
then
	screen -Rd "$SERVER_NAME" -X stuff "list\r"
	inotifywait -qq -e MODIFY .server.log > /dev/null
	# Check if any players are currently online, or if time is set
	if [ "$time" != 0 ] && [ "$(tail -3 .server.log | grep -o 'There are 0')" != "There are 0" ]
	then
		# If time is set, send warning message - TODO: eventually add time intervals for messaging
		if [ "$time" -ge 0 ]
		then
			# Yes, because grammar.
			if [ "$time" == 1 ]
			then
				minute="minute"
			else
				minute="minutes"
			fi

			echo "There are currently players online. Delaying server shutdown by $time $minute."

			### TODO: This should eventually support custom messages as well (such as when updating).
			announce_server.sh -a "The server is scheduled for shutdown in $time $minute!"
			sleep $((time*60))
		else
		read -r -p "There are players still online. Are you sure you want to shut down now? [y/N] " VAL

		if [[ ! "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]]
		then
			echo Canceled
			exit 0
		fi

		fi
	fi

	# Backup world(s) if someone has been online (used when start server is run automatically each day, otherwise this should never succeed)
	if [ "${WORLD_BACKUP^^}" == "YES" ]
	then
		grep -q "[^[:space:]]" .playedToday 2> /dev/null && ./backup_server.sh -a
	fi

	echo "Shutting down server!"

	# Send the server a stop message
	screen -Rd $SERVER_NAME -X stuff "stop\r"

	sleep 5

	check=$(screen -ls | grep -o "$SERVER_NAME")
	if [ "$check" == "$SERVER_NAME" ]
	then
		echo "Screen is shutting down. Just a moment..."
		i=0
		while [ "$check" == "$SERVER_NAME" ] && [[ i -lt 5 ]]
		do
			sleep 2
			check=$(screen -ls | grep -o "$SERVER_NAME")
			((i++))
		done
	fi

else
	echo "Server not running, skipping shutdown."
	exit 0
fi

# Check if the server was actually closed
check=$(screen -ls | grep -o "$SERVER_NAME")
if [ "$check" == "$SERVER_NAME" ]
then
	echo "Server failed to shutdown - Attempting to close screen..."

	# Tell screen to quit
	screen -Rd "$SERVER_NAME" -X stuff "^A\r:quit\r"

	sleep 5

	# Check if server shut down
	check=$(screen -ls | grep -o "$SERVER_NAME")
	if [ "$check" == "$SERVER_NAME" ]
	then
		echo "One more try - Attempting to terminate screen..."
		screen -Rd "$SERVER_NAME" -X stuff "^C\r"

		sleep 5

		check=$(screen -ls | grep -o "$SERVER_NAME")
		if [ "$check" == "$SERVER_NAME" ]
			then
					echo "Server failed to shutdown."
			else
					echo "Server has been terminated successfully."
			fi

	else
		echo "Server has been closed successfully."
	fi
else
	echo "Server has shut down successfully."
fi
