#shellcheck shell=bash


# this *isn't* a daemon - every request spawns a new instance so set -e is okay
# a bad response can fuck up federation permanently if you get unlucky - better not to respond
set -e


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
  httpd_listen
}

webfinger() {
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

nodeinfo() {
  httpd_clear
  httpd_header "Content-Type" "application/json"
  httpd_json 200\
    @links 2
      ! 2\
        .rel "http://nodeinfo.diaspora.software/ns/schema/2.1"\
        .href "$DOMAINURL/nodeinfo/2.1"\
      ! 2\
        .rel "http://nodeinfo.diaspora.software/ns/schema/2.0"\
        .href "$DOMAINURL/nodeinfo/2.0"\

}

nodeinfo21() {
  httpd_clear
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

user() {
  uid=$1
  echo "User: $uid"
  . "$DB_USERS/$uid/info"


  httpd_clear
  httpd_header "Content-Type" "application/activity+json"
  httpd_json 200\
    %@context "$(<context.json)"\
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
      .publicKeyPem "$(echo -en "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAr9Uyle4vSD4pVrQMpfRZ\n/apjEdwCBBvi1XZWTInOpxlQDBVggqsnM+4DVoA8QOGcb28QNTn/pSk/zbtlSlbN\nkAGrH13mYOhk/TAGID228Z+kU0BooI8wKjf6s5HTgxABjHAUIO9FxEkl6AQLSPDl\nHjO5x2rq/RBaCwhLpDivLydqmZ2f+G7i4gMbH5hYeuob8LvIJYKvc6hQ0VU0HxgM\np5yDGUA2fpjgwVk5fdAElFIB64tdW76/hCCUdwzJ/8rzXvbCwLVeb3Y63igi0dN5\nEzac4yNogkJmfA3l45SnsoRw1LGnT4e8b0jio3qAD45tyOehLfoMsNAe8rapLUCW\nJwIDAQAB\n-----END PUBLIC KEY-----\n")"\
    %isCat true\
    %noindex true\
    %speakAsCat false\
    @attachment 0\
    @alsoKnownAs 0

}

httpd_request() {
  echo "Request: $1 $2"

  for key in "${!G_search[@]}"; do
    echo "Search: $key ${G_search[$key]}"
  done

  # for key in "${!G_headers[@]}"; do
  #   echo "$key: ${G_headers[$key]}"
  # done

  if [ "$1" = "GET" ]; then
    if [[ "$2" = "/.well-known/webfinger"* ]]; then
      webfinger
    fi

    if [[ "$2" = "/.well-known/nodeinfo" ]]; then
      nodeinfo
    fi
    
    if [[ "$2" = "/nodeinfo/"* ]]; then
      nodeinfo21
    fi

    if [[ "$2" = "/users/"* ]]; then
      uid=${2#*users/}
      user "$uid"
    fi

    if [[ "$2" = "/banner/"* ]]; then
      uid=${2#*banner/}

      httpd_clear
      httpd_header "Content-Type" "image/png"
      httpd_sendfile "$DB_USERS/$uid/banner.png"
    fi

    if [[ "$2" = "/pfp/"* ]]; then
      uid=${2#*pfp/}

      httpd_clear
      httpd_header "Content-Type" "image/png"
      httpd_sendfile "$DB_USERS/$uid/pfp.png"
    fi


    if [[ "$2" = "/@"* ]]; then
      username=${2#*@}
      echo username: $username
      uid=$(finduser "$username")

      user "$uid"
    fi
  fi


  echo
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
