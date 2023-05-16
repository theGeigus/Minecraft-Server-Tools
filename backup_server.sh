#! /bin/bash

# Change directory and import variables
cd "$(dirname "${BASH_SOURCE[0]}")" ||  echo "Something broke, could not find directory?"

# Check for config
if ! source server.config
then
    echo "File 'server.config' not found. Run please run 'update_server.sh' and try again."
    exit 1
fi

### World Backup ###


