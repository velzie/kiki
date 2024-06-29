# inboxUrl: /inbox or /users/uid/inbox
# uid: the uid of the sending user
http_post_signed() { 
  inboxUrl=$1
  uid=$2
  body=$3

  protocol=${inboxUrl%%:*}
  inboxUrl=${inboxUrl#*://}
  host=${inboxUrl%%/*}
  inboxUrl=${inboxUrl#*/}
  pathname=/${inboxUrl%%\?*}

  if [ "$protocol" != "https" ]; then
    dbg "attempting to send to non-https url"
  fi


  . "$DB_USERS/$uid/info"


  # create b64 digest
  digest=$(openssl dgst -sha256 -binary <<<"$body" | openssl enc -base64)


  # sendDate needs to be rfc2616
  sendDate=$(date -u +"%a, %d %b %Y %T GMT")



  stringToSign="(request-target): post ${pathname}\nhost: ${host}\ndate: ${sendDate}\nalgorithm: rsa-sha256\ndigest: SHA-256=${digest}"

  signed=$(openssl dgst -sha256 -sign "$DB_USERS/$uid/privkey.pem" <<<"$stringToSign" | openssl enc -base64 -A)


  header="keyId=\"$DOMAINURL/users/$uid#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date algorithm digest\",signature=\"$signed\""

  echo "Sending to $protocol://$host$pathname"
  echo "signature: $signed" 
  echo "header: $header"


  curl -X POST\
    -H "Content-Type: application/activity+json"\
    -H "User-Agent: kiki.sh/$VERSION $DOMAINURL"\
    -H "Accept: application/activity+json"\
    -H "Algorithm: rsa-sha256"\
    -H "Host: $host"\
    -H "Date: $sendDate"\
    -H "Digest: SHA-256=$digest"\
    -H "Signature: $header"\
    -d "$body"\
    "$protocol://$host$pathname"
}

http_get_signed() {
  inboxUrl=$1
  uid=$2

  protocol=${inboxUrl%%:*}
  inboxUrl=${inboxUrl#*://}
  host=${inboxUrl%%/*}
  inboxUrl=${inboxUrl#*/}
  pathname=/${inboxUrl%%\?*}

  if [ "$protocol" != "https" ]; then
    dbg "attempting to send to non-https url"
  fi


  . "$DB_USERS/$uid/info"

  sendDate=$(date -u +"%a, %d %b %Y %T GMT")


  echo -en "(request-target): get ${pathname}\nhost: ${host}\ndate: ${sendDate}" > body

  signed=$(openssl dgst -sha256 -sign "$DB_USERS/$uid/privkey.pem" body | openssl base64 | tr -d "\n")

  header="keyId=\"$DOMAINURL/users/$uid#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date\",signature=\"$signed\""

    
  echo "header: $header"
  echo "Sending to $protocol://$host$pathname"
  echo "signature: $signed"

  echo "$signed" > sig64


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
  :
}
