#!/bin/bash

SERVER_NAME="minecraft_bedrock"

#--- STOP SERVER ---

# Check if server is running, exit if false
CHECK=`screen -ls | grep -o $SERVER_NAME`
if [ "$CHECK" == "$SERVER_NAME" ]
then
	echo "Shutting down server!"

	# Send the server a stop message
	screen -Rd $SERVER_NAME -X stuff "stop \r"

	sleep 2
else
	echo "Server failed to shutdown - Server was not running!"
	exit 0
fi

# Check if the server was actually closed
CHECK=`screen -ls | grep -o $SERVER_NAME`
if [ "$CHECK" == "$SERVER_NAME" ]
then
	echo "Server failed to shutdown - Attempting to force shutdown"

	# Tell screen to quit
	screen -Rd $SERVER_NAME -X stuff "^A :quit" > /dev/null

	sleep 2

	# Check if server shut down
	CHECK=`screen -ls | grep -o $SERVER_NAME`
	if [ "$CHECK" == "$SERVER_NAME" ]
	then
		echo "Server failed to shutdown - Could not terminate screen"
	else
		echo "Server has been terminated successfully"
	fi
else
	echo "Server has shut down successfully!"
fi
