#!/bin/bash

. ./lib/main.sh
PORT=${PORT:-4206}


# bash does not have any mechanism to LISTEN on a port. nmap's netcat is the best non-cheaty solution

# ncat -k with -c will run the command for every request. this means every time main runs it's in a different process
# inside the shell, stdin will be the request, and stdout will be the response
# we want to keep stdout for debugging, so we redirect it to fd 4, and use fd 3 for the response
# fd 4 of ncat then goes back to stdout so everything works

ncat -k -l -p "$PORT" -c "bash -c '. ./lib/main.sh; ( do_routes>&4 ) 3>&1'" 4>&1
