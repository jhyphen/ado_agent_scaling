#!/bin/bash
set -e

DIRS=("agent")

for DIR in "${DIRS[@]}"; do 
    DIR_PATH="/home/ubuntu/${DIR}/"
    cd ${DIR_PATH}
    echo "Running $DIR/svc.sh"
    sudo ./svc.sh stop
    sudo ./svc.sh uninstall    
done
