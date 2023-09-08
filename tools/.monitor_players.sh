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
                screen -Rd "$SERVER_NAME" -X stuff "gamerule dodaylightcycle $status \r"
                screen -Rd "$SERVER_NAME" -X stuff "gamerule doweathercycle $status \r"
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
	if [ "$(tail -1 .server.log | grep -o 'Player connected:')" == 'Player connected:' ]
	then

		player_name=$(tail -3 .server.log | grep "Player connected" | grep -n -o ': .* xuid' | awk '{ print substr($0, 5, length($0)-10) }')

		grep -q "$player_name" .playedToday 2> /dev/null || echo "$player_name" >> .playedToday

		setStatus 1

		# Send player a message after they spawn to make sure they recieve it
		i=0
		( while [ $i -lt 5 ]
		do
			if [ "$(tail -1 .server.log | grep -o 'Player Spawned:')" == 'Player Spawned:' ]
			then
				./announce_server.sh -p "$player_name"
				exit
			else
				inotifywait -qq -e MODIFY .server.log
				((COUNT+=1))
			fi
		done
		)&

	else
		# If player disconnects, check for remaining players
		if [ "$(tail -1 .server.log | grep -o 'Player disconnected:')" == "Player disconnected:" ]
        then

            screen -Rd "$SERVER_NAME" -X stuff "list \r"

            sleep 2

			if [ "$(tail -3 .server.log | grep -o 'There are 0')" == "There are 0" ]
			then
                setStatus 0
            fi
        fi
	fi
done &
