#!/bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke"

printHelp(){
	echo "-h: Show this page and exit"
	echo "-s Show the current status of the server and exit"
    echo "-p Print the currently online players and exit"
}

# Check for arguments
while getopts 'hsp' OPTION
do
	case "$OPTION" in
    h)
        printHelp
        exit 0
        ;;
    s)
        status
        ;;
	p)
		playerCheck
		;;
    ?)
        echo "Valid options are:"
        printHelp
        exit 1
        ;;
	esac
done

# Check for server update
if ! source server.config 2> /dev/null || [ "$AUTO_UPDATE" == 'YES' ]
then
	./update_server.sh
else
	./update_server.sh -c
fi

online() { [ "$(screen -ls | grep -o "$SERVER_NAME")" == "$SERVER_NAME" ] || return 1; }

status() {

	if ! online
	then
		echo 'The server is currently offline'
		exit 1
	fi

	echo 'The server is currently online'
	exit 0
}

playerCheck() {
	screen -Rd "$SERVER_NAME" -X stuff "list\r"

	sleep 2

	if [ "$(tail -3 .server.log | grep -o '] There are 0')" == "] There are 0" ]
	then
		echo 'There are currently no players online'
		exit 1
	fi

	local number
	local players
	number="$(tac .server.log | awk '/] There are/{ print NR; exit }' )"
	((number--))
	players="$(tail "-$number" .server.log)"

	echo "Players online: $number"
	echo "$players"

	exit 0
}

if ! command -v inotifywait -v screen > /dev/null
then
     echo "Dependencies are not met, please check that the following programs are installed:"
	 printf "\t- screen\n"
	 printf "\t- wget\n"
	 printf "\t- inotify-tools\n"
	 printf "\t- unzip\n"
     exit 1
fi

# Generate fortune
if [ "${DO_FORTUNE^^}" == "YES" ]
then
	if command -v fortune > /dev/null
	then
		echo "Generating fortune..."

		echo "§k~~~§rToday's fortune:§k~~~§r" > announcements.txt
		fortune -s >> announcements.txt
	else
		>&2 echo "Fortune has not been installed, so a new announcement cannot be generated. Please install fortune-mod and try again."
		sleep 2
	fi
fi

# Check if server is already running
if online
then
	echo "The server is already running"

	# Backup world(s) if someone has been online (used when start server is run automatically each day, otherwise this should never succeed)
	if [ "${WORLD_BACKUP^^}" == "YES" ]
	then
		grep -q "[^[:space:]]" ".playedToday" 2> /dev/null && ./backup_server.sh -a
	fi

	exit 0
fi

rm -f ".playedToday"

### INITIALIZE SERVER ###

cd "../${EDITION,,}-server/" || echo "Something broke, server folder is missing. Make sure Minecraft (run update-server.sh) is installed and try again."

echo "Starting server..."

if [ "${EDITION^^}" == "BEDROCK" ]
then
	echo 'Starting Minecraft: Bedrock Edition' > ../tools/.server.log
	screen -dmS "$SERVER_NAME" -L -Logfile "../tools/.server.log" bash -c "LD_LIBRARY_PATH=./ ./bedrock_server"
elif [ "${EDITION^^}" == "JAVA" ]
then
	echo 'Starting Minecraft: Java Edition' > ../tools/.server.log
	screen -dmS "$SERVER_NAME" -L -Logfile "../tools/.server.log" bash -c "java -Xmx1024M -Xms1024M -jar java_server.jar nogui"
else
	echo "Invalid edition, check server.config and try again."
	exit 1
fi
screen -Rd "$SERVER_NAME" -X logfile flush 1 # 1 sec delay to file logging as instant logging was too fast to handle properly

# Check if server is running, exit if not.
if ! online
then
	echo "Server failed to start! Check 'tools/.server.log' for more information."
	exit 1
fi

# Wait for IPv4 address to be avalible, or if Java, check if EULA has been accepted.
i=0
while [[ i -lt 5 ]]
do
	grep -q "IPv4" "../tools/.server.log" && break
	grep -q "Starting Minecraft server on" "../tools/.server.log" && break
	if grep -q "You need to agree to the EULA in order to run the server" "../tools/.server.log"
	then
		echo "You need to agree to the EULA in order to run the server, see java-server/eula.txt for more info."
		exit 1
	fi
	inotifywait -qq -t 5 -e MODIFY "../tools/.server.log"
	((i++))
done

# An excessive number of grep uses to pull out a single number (>_<)
[ "${EDITION^^}" == "BEDROCK" ] && port=$(grep -m 1 "IPv4" "../tools/.server.log" | grep -o -P " port: \d+" | grep -o -P "\d+")
[ "${EDITION^^}" == "JAVA" ] && port=$(grep "Starting Minecraft server on" "../tools/.server.log" | grep -o -P "\*:\d+" | grep -o -P "\d+")

echo "Server has started successfully - You can connect at $(curl -s ifconfig.me):$port."

rm -f .playedToday

pkill -f "../tools/.monitor_players.sh"	# Kill process if already running for some reason (It shouldn't be!)

../tools/.monitor_players.sh
