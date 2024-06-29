#shellcheck shell=bash

# this *isn't* a daemon - every request spawns a new instance
# a bad response can fuck up federation permanently if you get unlucky - better not to respond


. ./util.sh

. ./httpd.sh

. ./json.sh


DOMAIN=kiki.velzie.rip
VERSION=2024.0.0
NODENAME=kiki.sh
NODEDESCRIPTION="fedi server written in bash. why did i do this"

DOMAINURL=https://$DOMAIN



DB=./db
DB_USERS=$DB/users

start() {
  httpd_init

  httpd_route GET / 'httpd_clear && httpd_sendfile 200 index.html'


  # node meta
  httpd_route GET /.well-known/webfinger req_webfinger
  httpd_route GET /.well-known/nodeinfo req_nodeinfo
  httpd_route GET /.well-known/host-meta req_hostmeta_xml
  httpd_route GET /.well-known/host-meta.json req_hostmeta_json

  httpd_route GET '/nodeinfo/*' req_disaspora_nodeinfo
  httpd_route GET /manifest.json req_manifest

  # ap routes
  httpd_route POST '/sharedinbox' req_ap_inbox

  # user routes
  httpd_route GET '/users/*' 'senduserinfo "${path#*users/}"'
  httpd_route GET '/@*' 'senduserinfo "$(finduser "${path#*@}" )"'
  httpd_route GET '/banner/*' req_user_banner
  httpd_route GET '/pfp/*' req_user_pfp

  httpd_route POST '/inbox/*' req_user_inbox


  # notes?
  httpd_route GET '/notes/*' req_note


  httpd_handle
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
      . "$DOMAINURL/followers/$uid"\
    %inReplyTo null\
    @attachment 0\
    %sensitive false\
    @tag 0
}

req_ap_inbox() {
  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  echo "SHARED INBOX REQUEST TYPE: $type"
  echo "$json"


  httpd_clear
  httpd_send 200
}

req_user_inbox() {
  uid=${path#*inbox/}

  json=$(httpd_read)
  type=$(jq -r '.type' <<< "$json")

  echo "INBOX REQUEST: $uid/$type"


  httpd_clear
  httpd_send 200
}

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

req_manifest(){
  httpd_clear
  httpd_header "Content-Type" "application/json"
  httpd_json 200\
    .short_name "$NODENAME"\
    .name "$NODENAME"\
    .start_url "/"\
    .display "standalone"\
    .description "$NODEDESCRIPTION"\
    .background_color "#00ae00"\
    .theme_color "#00ae00"\
    .icons 1\
      ! 3\
        .src "$DOMAINURL/instanceicon"\
        .sizes "512x512"\
        .type "image/png"\
    !share_target 4\
      .action "/share/"\
      .method "GET"\
      .enctype "application/x-www-form-urlencoded"\
      !params 3\
        .title "title"\
        .text "text"\
        .url "url"
}

req_hostmeta_xml(){
  httpd_clear
  httpd_header "Content-Type" "application/xrd+xml"
  httpd_send 200\
    "$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
  <Link rel="lrdd" type="application/xrd+xml" template="$DOMAINURL/.well-known/webfinger?resource={uri}"/>
</XRD>
EOF
)"
}

req_hostmeta_json() {
  httpd_clear
  httpd_header "Content-Type" "application/json"
  httpd_json 200\
    @links 1\
      ! 3\
        .rel "lrdd"\
        .type "application/json"\
        .template "$DOMAINURL/.well-known/webfinger?resource={uri}"
}

req_webfinger() {
  resource=${G_search[resource]}
  echo "Webfinger: $resource"

  account=${resource#*acct:}

  username=${account%@*}

  uid=$(finduser "$username")

  httpd_clear
  httpd_header "Content-Type" "application/jrd+json"
  httpd_json 200\
    .subject "acct:$account"\
    @links 3\
      ! 3\
        .rel self\
        .type "application/activity+json"\
        .href "$DOMAINURL/users/$uid"\
      ! 3\
        .rel "http://webfinger.net/rel/profile-page"\
        .type "text/html"\
        .href "$DOMAINURL/@$username"\
      ! 2\
        .rel "http://ostatus.org/schema/1.0/subscribe"\
        .template "$DOMAINURL/authorize-follow?acct={uri}"

}

req_nodeinfo() {
  httpd_clear
  httpd_header "Content-Type" "application/json"
  httpd_json 200\
    @links 2\
      ! 2\
        .rel "http://nodeinfo.diaspora.software/ns/schema/2.1"\
        .href "$DOMAINURL/nodeinfo/2.1"\
      ! 2\
        .rel "http://nodeinfo.diaspora.software/ns/schema/2.0"\
        .href "$DOMAINURL/nodeinfo/2.0"\

}

req_disaspora_nodeinfo() {
  httpd_header "Content-Type" "application/json"
  httpd_json 200\
    .version 2.1\
    !software 3\
      .name kiki\
      .version "$VERSION"\
      .homepage "$HOMEPAGE"\
    @protocols 1\
      . activitypub\
    !services 1\
      @inbound 0\
      @outbound 0\
    %openRegistrations false\
    !usage 3\
      !users 3\
        %total 1\
        %activeHalfyear null\
        %activeMonth null\
      %localPosts 10\
      %localComments 0\
    !metadata 28\
      .nodeName "$NODENAME"\
      .nodeDescription "$NODEDESCRIPTION"\
      @nodeAdmins 0\
      !maintainer 2\
        .name "$MAINTAINERNAME"\
        .email "$MAINTAINEREMAIL"\
      @langs 0\
      %tosUrl null\
      %privacyPolicyUrl null\
      .inquiryUrl "https://www.youtube.com/watch?v=K8GQcE-XwK0"\
      %impressumUrl null\
      %donationUrl null\
      .repositoryUrl "https://github.com/velzie/kiki"\
      %feedbackUrl null\
      %disableRegistration true\
      %disableLocalTimeline false\
      %disableGlobalTimeline false\
      %disableBubbleTimeline false\
      %emailRequiredForSignup true\
      %enableHcaptcha false\
      %enableRecaptcha false\
      %enableMcaptcha false\
      %enableTurnstile false\
      %maxNoteTextLength 8192\
      %enableEmail false\
      %enableServiceWorker false\
      %proxyAccountName null\
      .themeColor "#00ae00"


}

actorjson() {
  uid=$1
  . "$DB_USERS/$uid/info"

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
    !publicKey 4\
      .id "$DOMAINURL/users/$uid#main-key"\
      .type Key\
      .owner "$DOMAINURL/users/$uid"\
      .publicKeyPem "$(< "$DB_USERS/$uid/pubkey.pem")"\
    %isCat true\
    %noindex true\
    %speakAsCat false\
    @attachment 0\
    @alsoKnownAs 0
}

senduserinfo() {
  uid=$1
  echo "User: $uid"
  . "$DB_USERS/$uid/info"


  httpd_clear
  httpd_header "Content-Type" "application/activity+json"

  actor=$(actorjson "$uid")

  # add ./context.json to actor
  actor=$(echosafe "$actor" | jq '.["@context"] = $context' --argjson context "$(< ./context.json)")

  httpd_send 200 "$actor"
}

outbox() {
  uid=$1
  echo "Outbox: $uid"
  . "$DB_USERS/$uid/info"

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

finduser() {
  username=$1
  for file in $DB_USERS/*; do
    source "$file/info"
    if [ "$setUsername" = "$username" ]; then
      echo "$setUid"
      return
    fi
  done
}
