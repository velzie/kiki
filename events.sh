#!/bin/bash

# this file will get run when users interact with posts from this instance. you might want to customize this file


. ./lib/main.sh


if [[ $1 == "tag" ]]; then
  uid=$2
  noteid=$3
  tagger=$4


  actorlookup "$tagger"
    

  ./ctl.sh act post "$uid" "$setAcct hi!" "$noteid"

  echo ./ctl.sh act post "$uid" "$setAcct hi!" "$noteid"
fi
