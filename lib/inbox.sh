
add_object() {
  object=$1
  ourid=$(uuid)
  mkdir -p "$DB_OBJECTS/$ourid"

  type=$(jq -r '.type' <<< "$object")

  echosafe "$type" > "$DB_OBJECTS/$ourid/type"
  echosafe "$object" > "$DB_OBJECTS/$ourid/object.json"
}

req_note(){
  id=${path#*notes/}


  httpd_clear
  httpd_header "Content-Type" "application/activity+json"
  httpd_json 200\
    %@context "$(< ./context.json)"\
    .id "$DOMAINURL/notes/$id"\
    .type "Note"\
    .attributedTo "$DOMAINURL/users/shuid"\
    .content "i love bash"\
    .published "2024-01-01T00:00:00Z"\
    @to 1\
      . "https://www.w3.org/ns/activitystreams#Public"\
    @cc 1\
      . "$DOMAINURL/followers/shuid"\
    %inReplyTo null\
    @attachment 0\
    %sensitive false\
    @tag 0
}



in_act_follow() {
  local json=$1
  local followid
  local actor
  local object
  local uid


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
}

req_user_inbox() {
  uid=${path#*inbox/}

  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  if [[ "$type" = "Follow" ]]; then
    in_act_follow "$json"
  elif [[ "$type" = "Accept" ]]; then
    :
  else
    echo "UNKNOWN USER ACTIVITY: $type"
    echo "$json"
  fi


  httpd_clear
  httpd_send 200
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
    %@context "$(< ./context.json)"\
    .id "$DOMAINURL/outbox/$uid"\
    .type OrderedCollection\
    %totalItems $numactivities\
    .first "$DOMAINURL/outbox/$uid?page=true"\
    .last "$DOMAINURL/outbox/$uid?page=true?since_id=0"\

    
}


req_ap_inbox() {
  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  if [[ "$type" = "Create" ]]; then
    add_object "$(jq -r '.object' <<< "$json")"
  elif [[ "$type" = "Follow" ]]; then
    in_act_follow "$json"
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
