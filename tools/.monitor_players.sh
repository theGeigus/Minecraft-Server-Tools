#! /bin/bash

#--- MONITOR PLAYER CONNECTION/DISCONNECTION ---

cd "$(dirname "${BASH_SOURCE[0]}")" || echo "Something broke, could not find directory?"

source server.config 2> /dev/null

status=true

setStatus() {
    online=$1

    if [ "$online" == 1 ]
    then
        $status && return
        [ "$NO_PLAYER_ACTION" == "PAUSE" ] && echo "Player connected - Restarting time!" >> .server.log
        status=true
    else
        $status || return
        [ "$NO_PLAYER_ACTION" == "PAUSE" ] && echo "There are no players currently online - pausing time!" >> .server.log
        status=false
    fi

    if [ "$NO_PLAYER_ACTION" == "PAUSE" ]
            then
                # Set day and weather cycle to false
                screen -Rd "$SERVER_NAME" -X stuff "gamerule doDaylightCycle $status\r"
                screen -Rd "$SERVER_NAME" -X stuff "gamerule doWeatherCycle $status\r"
            elif [ "$online" == 0 ] && [ "$NO_PLAYER_ACTION" == "SHUTDOWN" ]
            then
                echo "There are no players currently online - shutting down server!" >> .server.log
                (./stop_server.sh -t 0)

            fi
}

# Set to false initially before players join
setStatus -1

# Loop while server is running
while [ "$(screen -ls | grep  -o "$SERVER_NAME")" == "$SERVER_NAME" ]
do
	# Wait for log update, if player connects set day and weather cycle to true
	inotifywait -qq -e MODIFY .server.log
    line="$(tail -1 .server.log)"
	if [ "$(echo "$line" | grep -o 'Player Spawned:')" == 'Player Spawned:' ] || [ "$(echo "$line" | grep -o 'joined the game')" == "joined the game" ]
	then
        [ "${EDITION^^}" == "BEDROCK" ] && player_name=$(echo "$line"| grep -n -o ': .* xuid' | awk '{ print substr($0, 5, length($0)-9) }')
		[ "${EDITION^^}" == "JAVA" ] && player_name=$(echo "$line" | grep -n -o ': .* joined the game' | awk '{ print substr($0, 5, length($0)-20) }')

        echo "$player_name" >> .server.log
        grep -q "$player_name" .playedToday 2> /dev/null || echo "$player_name" >> .playedToday
        setStatus 1
		./announce_server.sh -p "$player_name"

    # If player disconnects, check for remaining players
	elif [ "$(echo "$line" | grep -o 'Player disconnected:')" == "Player disconnected:" ] || [ "$(echo "$line" | grep -o 'left the game')" == "left the game" ]
    then

        screen -Rd "$SERVER_NAME" -X stuff "list\r"

        sleep 2

        if [ "$(tail -3 .server.log | grep -o 'There are 0')" == "There are 0" ]
        then
            setStatus 0
        fi

    # Case for if server crashes, this is how Java Edition crashes print out... Add Bedrock's format later
    elif [ "$(echo "$line" | grep -o 'This crash report has been saved')" == "This crash report has been saved" ]
    then
        if [ "${RESTART_ON_CRASH^^}" == "YES" ]
        then
            ./stop_server.sh # Should have stopped already, but might as well check anyway
            ./start_server.sh
            exit 1
        fi
    fi
done &
