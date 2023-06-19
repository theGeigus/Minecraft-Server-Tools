#! /bin/bash

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
	echo "-b NAME: Create backup with the supplied name."
	echo "-l: List backups and exit."
	echo "-r NAME: Restore backup with the supplied name."
	echo "-d NAME: Delete backup with the supplied name. Will NOT ask for confirmation!"
	echo "-a: Auto backup mode, will run backup and name automatically, however backups will be deleted when max is reached.    	"
}

GETOPTIONS=true
AUTOBACKUP=false
# Check for arguments, if any. Only takes -t as of now
while getopts 'halb:d:r:' OPTION
do
	case "$OPTION" in
		h)
			printHelp
			exit 0
			;;
		a)
            AUTOBACKUP=true
			GETOPTIONS=false
			;;
		l)
			LIST=true
			GETOPTIONS=false
			;;
		b)
			BACKUP=$OPTARG
			GETOPTIONS=false
			;;
        r)
            RESTORE=$OPTARG
			GETOPTIONS=false
            ;;
		d)
			DELETE=$OPTARG
			GETOPTIONS=false
			;;
    	?)
			echo "Unknown option, '$OPTION'"
			echo "Valid options are:"
			printHelp
			exit 1
      		;;
	esac
done

### World Backup ###

BACKUP_PATH="$(eval echo "$BACKUP_PATH")"

# Autobackup
if $AUTOBACKUP
then
	echo "Running autobackup..."
	mkdir -p "$BACKUP_PATH"
	cp -r "$SERVER_PATH/worlds" "$BACKUP_PATH/AUTOBACKUP_$(date +%y-%m-%d_%H:%M:%S)"

	while read -r LINE
	do
		LIST_AUTOBACKUPS+=("$LINE")
	done <<< "$(ls "$BACKUP_PATH")"

	# Remove oldest auto-backups over the limit
	OVERMAX=$((${#LIST_AUTOBACKUPS[@]}-BACKUP_NUM))
	[ $OVERMAX -gt 0 ] && echo "Removing old backup(s)..."
	i=0
	while [ $OVERMAX -gt 0 ]
	do
		rm -r "$BACKUP_PATH/${LIST_AUTOBACKUPS[$i]:?}"
		((i++))
		((OVERMAX--))
	done

	exit 0
fi

echo "Backup directory: $BACKUP_PATH."

# List backups
listBackups(){
	unset LIST_BACKUPS
	while read -r LINE
	do
		LIST_BACKUPS+=("$LINE")
	done <<< "$(ls "$BACKUP_PATH")"

	echo "List of backups:"

	COUNT="${#LIST_BACKUPS[@]}"
	i=0
	while [ $i -lt "$COUNT" ]
	do
		echo "$((i+1)). ${LIST_BACKUPS[$i]}"
		((i++))
	done
}

# Get options if none set

getOptions(){
	LIST=false
	BACKUP=""
	RESTORE=""
	DELETE=""

	echo "Select an option:"
	printf "\t1. Backup worlds.\n"
	printf "\t2. Restore backup.\n"
	printf "\t3. Delete backup.\n"
	printf "\t4. List backups.\n"
	printf "\t0. Exit.\n"
	read -r -p "Enter number here: " VAL

	if [ "$VAL" -lt 0 ] || [ "$VAL" -gt 4 ]
	then
		echo "Invalid option"
		exit 1
	fi

	[ "$VAL" == 0 ] && exit 0

	listBackups

	[ "$VAL" == 1 ] && read -r -p "Enter a name for your backup: " BACKUP
	
	if [ "$VAL" == 2 ] # TODO: Add check for taken name
	then
		read -r -p "Enter the backup to restore: " NUM

		if [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#LIST_BACKUPS[@]}" ]
		then
			echo "Invalid option"
			exit 1
		fi

		RESTORE="${LIST_BACKUPS[((NUM-1))]}"
		read -r -p "Are you sure you want to restore '$RESTORE'? [Y/n] " VAL
		if ! [[ "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]] && [ "$VAL" != "" ]
		then
			echo "Canceled"
			exit 0
		fi

	fi
	
	if [ "$VAL" == 3 ]
	then


		read -r -p "Enter the number of the backup to delete: " NUM

		if [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#LIST_BACKUPS[@]}" ]
		then
			echo "Invalid option"
			exit 1
		fi
		DELETE="${LIST_BACKUPS[((NUM-1))]}"

		read -r -p "Are you sure you want to delete '$DELETE'? [Y/n] " VAL
		if ! [[ "$VAL" =~ ^([yY][eE][sS]|[yY])$ ]] && [ "$VAL" != "" ]
		then
			echo "Canceled"
			exit 0
		fi

	fi
}

if $GETOPTIONS
then
	getOptions
fi

# List
if $LIST
then
	listBackups
fi

while true #Loop indefinately until exited
do

# Delete backups
if [ "$DELETE" != "" ]
then
	rm -r "${BACKUP_PATH:?}/$DELETE" && echo "Deleted '$DELETE'"
fi

# Backup
if [ "$BACKUP" != "" ]
then
	mkdir -p "$BACKUP_PATH"
	cp -r "$SERVER_PATH/worlds" "${BACKUP_PATH:?}/$BACKUP" &&
	echo "Successfully created backup '$BACKUP'"

fi

if [ "$RESTORE" != "" ]
then
	echo "Stopping server for restoration."
	./stop_server.sh || exit 1
	mkdir -p "$BACKUP_PATH"
	BACKUP="AUTOBACKUP_$(date +%y-%m-%d_%H:%M:%S)"
	echo "A backup of the current world will be created just incase you want it back. It will be titled: $BACKUP"
	
	if ! mv "$SERVER_PATH/worlds" "${BACKUP_PATH:?}/$BACKUP"
	then
		echo "Backup failed, aborting restoration"
		exit 1
	fi

	cp -r "${BACKUP_PATH:?}/$RESTORE" "$SERVER_PATH/worlds" && echo "Restored '$RESTORE'"
fi

$GETOPTIONS || exit 0

# Get options again
getOptions
done
