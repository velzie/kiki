declare -A G_headers
declare -A G_search

httpd_init(){
  HTTPD_routes_method=()
  HTTPD_routes_path=()
  HTTPD_routes_callback=()
}

httpd_route(){
  method=$1
  path=$2
  callback=$3

  HTTPD_routes_method+=("$method")
  HTTPD_routes_path+=("$path")
  HTTPD_routes_callback+=("$callback")
}

httpd_handle() {
  read -r line

  local request=($line)


  httpd_clear

  while read -r line; do
    if [ "$line" = "$(echo -en "0d0a" | xxd -r -p)" ]; then
      break
    fi
    local line=${line//$'\r'/}
    local key=${line%: *}
    local value=${line#*: }
    G_headers[$key]="${value,,}"
  done



  # this one is global
  path=${request[1]}


  if [[ "$path" == *"?"* ]]; then
    path=${path%%\?*}
    local query=${request[1]#*\?}

    while read -r -d "&" fragment; do
      key=${fragment%=*}
      value=${fragment#*=}
      G_search[$key]=$(urldecode "$value")
    done <<< "$query&"
  fi

  echo "${request[@]}"
  echo "${G_headers[user-agent]}"
  echo "--------"
  for key in "${!G_search[@]}"; do
    echo "Search: $key ${G_search[$key]}"
  done



  for i in "${!HTTPD_routes_method[@]}"; do

    path="$(urldecode "$path")"
    #shellcheck disable=SC2053 # the path is an expression
    if [ "${HTTPD_routes_method[$i]}" = "${request[0]}" ] && [[ "$path" = ${HTTPD_routes_path[$i]} ]]; then
      eval "${HTTPD_routes_callback[$i]}"
      return
    fi
  done

  httpd_clear
  httpd_send 404 "Not Found"
}


httpd_clear() {
  G_headers=()
  G_search=()
}

httpd_header() {
  key=$1
  value=$2
  G_headers[$key]=$value
}

httpd_send() {
  status=$1
  body=$2
  length=$(echosafe "$body" | wc -c)

  {
    echo -en "HTTP/1.1 $status OK\r\n"
    echo -en "Content-Length: $length\r\n"
    echo -en "Content-Type: text/plain\r\n"
    for key in "${!G_headers[@]}"; do
      echo -en "$key: ${G_headers[$key]}\r\n"
    done
    echo -en "\r\n"
    echosafe "$body"
  } >&3
}

httpd_json() {
  status=$1
  shift

  httpd_send "$status" "$(json "$@")"
}



httpd_sendfile() {
  status=$1
  file=$2

  {
    echo -en "HTTP/1.1 $status OK\r\n"
    echo -en "Content-Length: $(stat -c %s "$file")\r\n"
    echo -en "Content-Type: $(file -b --mime-type "$file")\r\n"
    for key in "${!G_headers[@]}"; do
      echo -en "$key: ${G_headers[$key]}\r\n"
    done
    echo -en "\r\n"
    cat "$file"
  } >&3
}


httpd_read() {
  length=${G_headers[content-length]}
  length=${length:-0}
  head -c "$length"
}
