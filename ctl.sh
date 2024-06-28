#!/bin/bash

. ./main.sh


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
}


$1
