#shellcheck shell=bash


jsonvalid(){
  jq -e . >/dev/null 2>&1
}

uuid(){
  tr -dc 'a-f0-9' < /dev/urandom | head -c 8
}

echosafe() {
  printf "%s" "$1"
}

fromhex() {
  xxd -p -r -c999999
}

tohex() {
  xxd -p
}


urldecode() {
 : "${*//+/ }"
 echo -e "${_//%/\\x}"
}

urlencode() {
  local length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
      *) printf "%%%02X" "'$c" ;;
    esac
  done
}
