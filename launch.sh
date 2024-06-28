#!/bin/bash

. ./main.sh
PORT=${PORT:-4206}

ncat -k -l -p "$PORT" -c "source ./main.sh; ( start>&4 ) 3>&1" 4>&1
