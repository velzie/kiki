
add_object() {
  object=$1
  ourid=$(uuid)
  mkdir -p "$DB_OBJECTS/$ourid"

  type=$(jq -r '.type' <<< "$object")

  echosafe "$type" > "$DB_OBJECTS/$ourid/type"
  echosafe "$object" > "$DB_OBJECTS/$ourid/object.json"

  echo "$ourid"
}


notelookup(){
  local noteid=$1

  if ! [ -d "$DB_OBJECTS/$noteid/" ]; then
    dbg "notelookup: no such note $noteid!"
    return 1
  fi

  setType=$(<"$DB_OBJECTS/$noteid/type")
  setJson=$(<"$DB_OBJECTS/$noteid/object.json")
  setOwner=$(jq -r '.attributedTo' <<< "$setJson")
  setContent=$(jq -r '.content' <<< "$setJson")
}

req_note(){
  id=${path#*notes/}

  
  if ! notelookup "$id"; then
    httpd_clear
    httpd_send 404 "no such note!"
    return
  fi


  httpd_clear
  httpd_header "Content-Type" "application/activity+json"
  
  # add context to the note json
  setJson=$(echosafe "$setJson" | jq '.["@context"] = $context' --argjson context "$CONTEXT")

  httpd_send 200 "$setJson"
}



in_act_follow() {
  local json=$1
  local followid
  local actor
  local object
  local uid


  echo "INBOX FOLLOW $json"

  followid=$(jq -r '.id' <<< "$json")
  actor=$(jq -r '.actor' <<< "$json")
  object=$(jq -r '.object' <<< "$json")
  # actor is the remote actor, object is our actor

  uid=${object#*users/}

  if ! userlookup "$uid"; then
    httpd_clear
    httpd_send 404 "no such user!"
    return
  fi

  echo "FOLLOW REQUEST: $actor -> $object"
  echo "FOLLOW ID: $followid"

  actorlookup "$actor"

  act_accept "$uid" "$actor" "$followid"

  echo "$actor" >> "$DB_USERS/$uid/followers"


  if [ -n "$FOLLOWBACK" ]; then
    act_follow "$uid" "$actor"
  fi
}

req_user_inbox() {
  uid=${path#*inbox/}

  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  inbox
}

req_user_outbox() {
  uid=$1
  echo "Outbox: $uid"


  if ! userlookup "$uid"; then
    httpd_clear
    httpd_send 404 "no such user!"
    return
  fi

  numactivities=$(find "$DB_USERS/$uid/activities" -type f | wc -l)

  httpd_clear
  httpd_header "Content-Type" "application/activity+json"
  httpd_json 200\
    %@context "$CONTEXT"\
    .id "$DOMAINURL/outbox/$uid"\
    .type OrderedCollection\
    %totalItems $numactivities\
    .first "$DOMAINURL/outbox/$uid?page=true"\
    .last "$DOMAINURL/outbox/$uid?page=true?since_id=0"\

    
}


req_ap_inbox() {
  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  inbox
}

inbox() {

  if [[ "$type" = "Create" ]]; then
    noteid=$(add_object "$(jq -r '.object' <<< "$json")")

    attributedTo=$(jq -r '.object.attributedTo' <<< "$json")

    tags=$(jq -r '.object.tag | map (.href) | join (" ")' <<< "$json")
    for tag in $tags; do
      if [[ "$tag" = "$DOMAINURL/users"*  ]]; then
        uid=${tag#*users/}
        echo "$uid was tagged!!"
        ./events.sh tag "$uid" "$noteid" "$attributedTo"
      fi
    done

  elif [[ "$type" = "Follow" ]]; then
    in_act_follow "$json"
  elif [[ "$type" = "Like" ]]; then
    object=$(jq -r '.object' <<< "$json")
    actor=$(jq -r '.actor' <<< "$json")

    noteid=${object#*notes/}
    echo "LIKE $noteid"
    echosafe "$actor" >> "$DB_OBJECTS/$noteid/likes"
  elif [[ "$type" = "Accept" ]]; then
    :
  elif [[ "$type" = "Delete" ]]; then
    # don't care. spams the logs
    :
  else
    echo "UNKNOWN ACTIVITY: $type"
    echo "$json"
  fi


  httpd_clear
  httpd_send 200
}
