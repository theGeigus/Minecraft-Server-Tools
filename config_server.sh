#!/bin/bash

# This file contains the configuration for all server script files (*_server.sh).
# Allows all variables to be set in one convienient location instead of within each file.
# Created by Geigus

# Name of the file containing the server - also used as the name of the screen
SERVER_NAME="minecraft-server-tools"

# Directory path to server folder location (do not include server folder in this)
SOURCE_PATH="/home/$USER_NAME"

# The following lines are planned, but are not yet functional
# Enable daily automatic world backups
WORLD_BACKUP="YES"

# Directory worlds will be backed up to - recommended to use a directory located in a drive different than your server
BACKUP_PATH="$SOURCE/Backups"

# Number of daily backups to keep
BACKUP_NUM=5
