declare -A G_headers
declare -A G_search

httpd_listen() {
  read -r line

  request=($line)


  httpd_clear

  while read -r line; do
    if [ "$line" = "$(echo -en "0d0a" | xxd -r -p)" ]; then
      break
    fi
    line=${line//$'\r'/}
    key=${line%: *}
    value=${line#*: }
    G_headers[$key]=$value
  done



  path=${request[1]}


  if [[ "$path" == *"?"* ]]; then
    path=${path%%\?*}
    query=${request[1]#*\?}

    while read -r -d "&" fragment; do
      key=${fragment%=*}
      value=${fragment#*=}
      G_search[$key]=$(urldecode "$value")
    done <<< "$query&"
  fi


  httpd_request "${request[0]}" "$(urldecode "$path")"
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
  length=${G_headers[Content-Length]}
  head -c "$length"
}
