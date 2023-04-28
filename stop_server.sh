#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" ||  echo "Something broke, could not find directory?"
source ./config_server.sh || exit 1

#--- STOP SERVER ---
stopServer(){
	# Check if server is running, exit if false
	CHECK=$(screen -ls | grep -o $SERVER_NAME)
	if [ "$CHECK" == "$SERVER_NAME" ]
	then
		echo "Shutting down server!"

		screen -Rd "$SERVER_NAME" -X stuff "list \r"
		inotifywait -qq -e MODIFY serverLog > /dev/null
		# Check if any players are currently online, or if TIME is set
		if ! [ "$TIME" -ge 0 ] && [ "$(tail -3 serverLog | grep -o 'There are 0')" != "There are 0" ]
		then
		read -r -p "There are players still online. Are you sure you want to shut down now? [y/N] " VAL
			if [[ ! "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]]
			then
				echo Canceled
				exit 0
			else
				echo "Continuing shutdown."
			fi
		fi
		
		# If time is set, send warning message - TODO: eventually add time intervals for messaging
		if [ "$TIME" -ge 0 ]
		then
			# Yes, had to fix grammar even for something as trivial as this...
			if [ "$TIME" == 1 ]
			then
				MINUTE="minute"
			else
				MINUTE="minutes"
			fi
			screen -Rd "$SERVER_NAME" -X stuff "tellraw @a {\"rawtext\": [{\"text\": \"The server is scheduled for shutdown in $TIME $MINUTE!\"}]} \r"
			sleep $((TIME*60))
		fi

		# Send the server a stop message
		screen -Rd $SERVER_NAME -X stuff "stop \r"

		sleep 2
	else
		echo "Server failed to shutdown - Server was not running!"
		exit 0
	fi

	# Check if the server was actually closed
	CHECK=$(screen -ls | grep -o "$SERVER_NAME")
	if [ "$CHECK" == "$SERVER_NAME" ]
	then
		echo "Server failed to shutdown - Attempting to quit shutdown"

		# Tell screen to quit
		screen -Rd "$SERVER_NAME" -X stuff "^A :quit \r" > /dev/null

		sleep 2

		# Check if server shut down
		CHECK=$(screen -ls | grep -o "$SERVER_NAME")
		if [ "$CHECK" == "$SERVER_NAME" ]
		then
			echo "One more try - Attempting to terminate screen"
			screen -Rd "$SERVER_NAME" -X stuff "^C" > /dev/null

			if [ "$CHECK" == "$SERVER_NAME" ]
				then
						echo "Server has been terminated successfully"
				else
						echo "Server has been terminated successfully"
				fi

		else
			echo "Server has been quit successfully"
		fi
	else
		echo "Server has shut down successfully!"
	fi
}

printHelp(){
	echo "-h: Show this page and exit"
	echo "-t NUMBER: set delay to stop the server, given in minutes. Ignores if players are online."
}

TIME=-1
# Check for arguments, if any. Only takes -t as of now
while getopts 'ht:' OPTION; do
	case "$OPTION" in
		h)
			printHelp
			exit 0
			;;
		t)
			if [ "$OPTARG" -ge 0 ]
			then
				TIME=$OPTARG
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
stopServer