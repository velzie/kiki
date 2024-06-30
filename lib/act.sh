

act_follow() {
  uid=$1
  actor=$2

  followid=$(uuidgen)

  if ! actorlookup "$actor"; then
    dbg "act_follow: no such actor $actor!"
    return
  fi


  http_post_json_signed "$setInbox" "$uid"\
    %@context "$(< ./context.json)"\
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

  biteid=$(uuidgen)
  http_post_json_signed "$setInbox" "$uid"\
    %@context "$(< ./context.json)"\
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
    %@context "$(< ./context.json)"\
    .type Accept\
    .id "$DOMAINURL/accepts/$(uuidgen)"\
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

  # first create the note
  noteid=$(uuidgen)

  mkdir -p "$DB_OBJECTS/$noteid"
  echo "Note" > "$DB_OBJECTS/$noteid/type"
  echo "$content" > "$DB_OBJECTS/$noteid/content"
  echo "$uid" > "$DB_OBJECTS/$noteid/author"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$DB_OBJECTS/$noteid/created"
  echo "$noteid" > "$DB_OBJECTS/$noteid/id"

  # now add it to the user's outbox
  echo "$noteid" >> "$DB_USERS/$uid/outbox"

  # then send it to our loyal followers

  while read -r follower; do
    actorlookup "$follower"
    http_post_json_signed "$setInbox" "$uid"\
      %@context "$(< ./context.json)"\
      .id "$DOMAINURL/notes/$noteid"\
      .type Create\
      .actor "$DOMAINURL/users/$uid"\
      !object 4\
        .id "$noteid"\
        .type Note\
        .content "$content"\
        .author "$DOMAINURL/users/$uid"
  done < "$DB_USERS/$uid/followers"
  
}