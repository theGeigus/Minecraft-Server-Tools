#!/bin/bash

# This file contains the configuration for all server script files (*_server.sh).
# Allows all variables to be set in one convienient location instead of within each file.
# Created by Geigus

# Used as the name of the screen, can be anything but needs to be unique if running multiple servers.
SERVER_NAME="minecraft-server"

# Directory path to server folder location, default should automatically get the server path, but change it if something doesn't work
# DEFAULT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )
SOURCE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )

# The following lines are planned, but are not yet functional
# Enable daily automatic world backups
WORLD_BACKUP="YES"

# Directory worlds will be backed up to - recommended to use a directory located in a drive different than your server
BACKUP_PATH="/home/$USER/Backups/$SERVER_NAME"

# Number of daily backups to keep
BACKUP_NUM=5
