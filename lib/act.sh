

act_follow() {
  uid=$1
  actor=$2

  followid=$(uuid)

  if ! actorlookup "$actor"; then
    dbg "act_follow: no such actor $actor!"
    return
  fi


  http_post_json_signed "$setInbox" "$uid"\
    %@context "$CONTEXT"\
    .id "$DOMAINURL/follows/wtf"\
    .type Follow\
    .actor "$DOMAINURL/users/$uid"\
    .object "$actor"
}

act_bite() {
  uid=$1
  actor=$2
  note=${3-$2}

  if ! actorlookup "$actor"; then
    dbg "act_bite: no such actor $actor!"
    return
  fi

  biteid=$(uuid)
  http_post_json_signed "$setInbox" "$uid"\
    %@context "$CONTEXT"\
    .id "$DOMAINURL/bites/$biteid"\
    .type Bite\
    .actor "$DOMAINURL/users/$uid"\
    .target "$note"
}

act_accept() {
  uid=$1
  actor=$2
  followid=$3

  if ! actorlookup "$actor"; then
    dbg "act_accept: no such actor $actor!"
    return
  fi

  http_post_json_signed "$setInbox" "$uid"\
    %@context "$CONTEXT"\
    .type Accept\
    .id "$DOMAINURL/accepts/$(uuid)"\
    .actor "$DOMAINURL/users/$uid"\
    !object 4\
      .id "$followid"\
      .actor "$actor"\
      .object "$actor"\
      .type Follow
}


act_post() {
  uid=$1
  content=$2
  inreplyto=$3
  to=$4

  # first create the note
  noteid=$(uuid)
  
  mkdir -p "$DB_OBJECTS/$noteid"
  echo "Note" > "$DB_OBJECTS/$noteid/type"

  json=$(json\
    ._misskey_content "$content"\
    .content "<p><span>$content</span></p>"\
    .sensitive false\
    .published "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"\
    !source 2\
      .content "$content"\
      .mediaType "text/x.misskeymarkdown"\
    @to 2\
      . "$DOMAINURL/followers/$uid"\
      . "$to"\
    @cc 1\
      . "https://www.w3.org/ns/activitystreams#Public"\
    .attributedTo "$DOMAINURL/users/$uid"\
    @tag 0\
    .id "$DOMAINURL/notes/$noteid"\
    .type Note)


  if [ -n "$inreplyto" ]; then
    json=$(jq --arg inreplyto "$inreplyto" '.inReplyTo = $inreplyto' <<< "$json")
  fi
  
  echosafe "$json" > "$DB_OBJECTS/$noteid/object.json"


  # now add it to the user's outbox
  echo "$noteid" >> "$DB_USERS/$uid/outbox"

  # then send it to our loyal followers

  while read -r follower; do
    actorlookup "$follower"
    http_post_json_signed "$setInbox" "$uid"\
      %@context "$CONTEXT"\
      .id "$DOMAINURL/notes/$noteid"\
      .type Create\
      .actor "$DOMAINURL/users/$uid"\
      %object "$(< "$DB_OBJECTS/$noteid/object.json")"
  done < "$DB_USERS/$uid/followers"
  
}
