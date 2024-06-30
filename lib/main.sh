#shellcheck shell=bash


. ./config.sh


. ./lib/util.sh
. ./lib/json.sh

. ./lib/httpd.sh
. ./lib/http.sh

. ./lib/act.sh

. ./lib/inbox.sh
. ./lib/db.sh
. ./lib/meta.sh
. ./lib/users.sh



DOMAINURL=https://$DOMAIN


do_routes() {
  # this *isn't* a daemon - every request spawns a new instance
  # a bad response can fuck up federation permanently if you get unlucky - better not to respond

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

