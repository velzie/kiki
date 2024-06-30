#!/bin/bash

. ./lib/main.sh


db_init() {
  mkdir -p "$DB_USERS"
  mkdir -p "$DB_OBJECTS"
}

useradd() {
  read -r -p "Username: " username
  read -r -p "UID: " uid
  read -r -p "Name: " name
  read -r -p "Summary: " summary


  dir="$DB_USERS/$uid"
  mkdir -p "$dir"

  openssl genpkey -algorithm RSA -out "$dir/privkey.pem" -pkeyopt rsa_keygen_bits:2048
  openssl rsa -pubout -in "$dir/privkey.pem" -out "$dir/pubkey.pem"


  cat >"$dir/info" <<EOF
setUsername=$uid
setUid=$uid
setName=$name
setSummary='$summary'
EOF

  :>"$dir/followers"
  :>"$dir/following"
}

act() {
  cmd=$1
  shift

  "act_$cmd" "$@"
}

"$@"
