# inboxUrl: /inbox or /users/uid/inbox
# uid: the uid of the sending user
http_post_signed() { 
  url=$1
  uid=$2
  toSign=$3

  protocol=${url%%:*}
  url=${url#*://}
  host=${url%%/*}
  url=${url#*/}
  pathname=/${url%%\?*}

  if [ "$protocol" != "https" ]; then
    dbg "attempting to send to non-https url"
  fi


  if ! userlookup "$uid"; then
    dbg "http_post_signed: no such user $uid!"
    return
  fi


  # create b64 digest
  digest=$(openssl dgst -sha256 -binary <(echosafe "$toSign") | openssl enc -base64)


  # sendDate needs to be rfc2616
  sendDate=$(date -u +"%a, %d %b %Y %T GMT")



  signed=$(openssl dgst -sha256 -sign "$DB_USERS/$uid/privkey.pem" <(
    echo -en "(request-target): post ${pathname}\nhost: ${host}\ndate: ${sendDate}\ndigest: SHA-256=${digest}"
  ) | openssl base64 -A)

  header="keyId=\"$DOMAINURL/users/$uid#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date digest\",signature=\"$signed\""

  curl -X POST\
    -H "Content-Type: application/activity+json"\
    -H "User-Agent: kiki.sh/$VERSION $DOMAINURL"\
    -H "Accept: application/activity+json"\
    -H "Algorithm: rsa-sha256"\
    -H "Host: $host"\
    -H "Date: $sendDate"\
    -H "Digest: SHA-256=$digest"\
    -H "Signature: $header"\
    -d "$toSign"\
    "$protocol://$host$pathname"
}

http_get_signed() {
  url=$1
  uid=${2:-$INSTANCEACTOR}

  protocol=${url%%:*}
  url=${url#*://}
  host=${url%%/*}
  url=${url#*/}
  pathname=/${url%%\?*}

  if [ "$protocol" != "https" ]; then
    dbg "attempting to send to non-https url"
  fi


  if ! userlookup "$uid"; then
    dbg "http_get_signed: no such user $uid!"
    return
  fi

  sendDate=$(date -u +"%a, %d %b %Y %T GMT")


  signed=$(openssl dgst -sha256 -sign "$DB_USERS/$uid/privkey.pem" <(
    echo -en "(request-target): get ${pathname}\nhost: ${host}\ndate: ${sendDate}"
  ) | openssl base64 -A)

  header="keyId=\"$DOMAINURL/users/$uid#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date\",signature=\"$signed\""

  curl\
    -H "Content-Type: application/activity+json"\
    -H "User-Agent: kiki.sh/$VERSION $DOMAINURL"\
    -H "accept: application/activity+json"\
    -H "Algorithm: rsa-sha256"\
    -H "host: $host"\
    -H "date: $sendDate"\
    -H "signature: $header"\
    "$protocol://$host$pathname"

}

verify_signature(){
  pubpath=$1
  signature=$2

  openssl dgst -sha256 -verify "$pubpath" -signature <(openssl enc -base64 -d <<<"$signature") body
}

http_post_json_signed(){
  url=$1
  shift
  uid=$1
  shift

  json=$(json "$@")

  http_post_signed "$url" "$uid" "$json"
}
