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


  if [[ "$resource" = "acct:"* ]]; then
    account=${resource#*acct:}

    username=${account%@*}

    uid=$(finduser "$username")
  else
    # iceshrimp.net resource
    uid=${resource#*users/}
  fi

  if ! userlookup "$uid"; then
    httpd_clear
    httpd_send 404 "no such user!"
    return
  fi

  


  httpd_clear
  httpd_header "Content-Type" "application/jrd+json"
  httpd_json 200\
    .subject "acct:$setUsername@$DOMAIN"\
    @links 3\
      ! 3\
        .rel self\
        .type "application/activity+json"\
        .href "$DOMAINURL/users/$uid"\
      ! 3\
        .rel "http://webfinger.net/rel/profile-page"\
        .type "text/html"\
        .href "$DOMAINURL/@$setUsername"\
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

