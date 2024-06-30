req_user_banner() {
  uid=${path#*banner/}
  echo "Banner: $uid"

  httpd_clear
  httpd_header "Content-Type" "image/png"
  httpd_sendfile 200 "$DB_USERS/$uid/banner.png"
}

req_user_pfp() {
  uid=${path#*pfp/}
  echo "PFP: $uid"

  httpd_clear
  httpd_header "Content-Type" "image/png"
  httpd_sendfile 200 "$DB_USERS/$uid/pfp.png"
}



actorjson() {
  uid=$1

  if ! userlookup "$uid"; then
    httpd_clear
    httpd_send 404 "no such user!"
    return
  fi

  json\
    .type Person\
    .id "$DOMAINURL/users/$uid"\
    .inbox "$DOMAINURL/inbox/$uid"\
    .outbox "$DOMAINURL/outbox/$uid"\
    .followers "$DOMAINURL/follwers/$uid"\
    .following "$DOMAINURL/following/$uid"\
    .featured "$DOMAINURL/collectionsfeatured/$uid"\
    .sharedInbox "$DOMAINURL/sharedinbox"\
    !endpoints 1\
      .sharedInbox "$DOMAINURL/sharedinbox"\
    .url "$DOMAINURL/@$setUsername"\
    .preferredUsername "$setUsername"\
    .name "$setName"\
    .summary "$setSummary"\
    ._misskey_summary "$setSummary"\
    !icon 4\
      .type Image\
      .url "$DOMAINURL/pfp/$uid"\
      %sensitive false\
      %name null\
    !image 4\
      .type Image\
      .url "$DOMAINURL/banner/$uid"\
      %sensitive false\
      %name null\
    !backgroundUrl 4\
      .type Image\
      .url "$DOMAINURL/banner/$uid"\
      %sensitive false\
      %name null\
    @tag 0\
    %manuallyApprovesFollowers false\
    %discoverable true\
    !publicKey 3\
      .id "$DOMAINURL/users/$uid#main-key"\
      .owner "$DOMAINURL/users/$uid"\
      .publicKeyPem "$(< "$DB_USERS/$uid/pubkey.pem")"$'\n'\
    %isCat true\
    %noindex true\
    %speakAsCat false\
    @attachment 0\
    @alsoKnownAs 0
}

senduserinfo() {
  uid=$1
  echo "User: $uid"

  if ! userlookup "$uid"; then
    httpd_clear
    httpd_send 404 "no such user!"
    return
  fi


  httpd_clear
  httpd_header "Content-Type" "application/activity+json"

  actor=$(actorjson "$uid")

  # add json-ld context to actor object
  actor=$(echosafe "$actor" | jq '.["@context"] = $context' --argjson context "$CONTEXT")

  httpd_send 200 "$actor"
}
