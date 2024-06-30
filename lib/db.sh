
DB=./db
DB_USERS=$DB/users

# remote objects and actors
DB_OBJECTS=$DB/objects
DB_ACTORS=$DB/actors


finduser() {
  username=$1
  for actor in $DB_USERS/*; do
    source "$actor/info"
    if [ "$setUsername" = "$username" ]; then
      echo "$setUid"
      return
    fi
  done
}

userlookup() {
  uid=$1
  if [ -f "$DB_USERS/$uid/info" ]; then
    source "$DB_USERS/$uid/info"
    return 0
  else
    return 1
  fi
}

actorlookup(){
  local actorurl=$1
  local actor
  local json
  local ourid


  local found=0

  files=$(shopt -s nullglob dotglob; echo $DB_ACTORS/*)
  if (( ${#files} > 0 )); then
    for actor in $DB_ACTORS/*; do
      if [ "$(<"$actor/url" )" = "$actorurl" ]; then
        ourid=$(basename "$actor")
        found=1
        json=$(<"$actor/actor.json")
      fi
    done
  fi

  if [ "$found" = 0 ]; then
    json=$(http_get_signed "$actorurl")
    if ! jsonvalid <<<"$json"; then
      dbg "$json"
      return 1
    fi

    ourid=$(uuid)

    mkdir -p "$DB_ACTORS/$ourid"

    echosafe "$json" > "$DB_ACTORS/$ourid/actor.json"
    echosafe "$actorurl" > "$DB_ACTORS/$ourid/url"
  fi



  setOurId="$ourid"
  setInbox=$(jq -r '.inbox' <<< "$json")
  setOutbox=$(jq -r '.outbox' <<< "$json")
  setUrl=$(jq -r '.url' <<< "$json")

}
