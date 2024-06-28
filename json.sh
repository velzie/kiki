#shellcheck shell=bash


dbg() {
  echo "$@" >&2
}

# .: string
# %: json
# @: array


json() {
  _json 99999 "$@"
}

_json() {
  local count=$1
  shift

  local command=(-r -n)
  local shiftby=0

  local j=0
  while [ "$j" -lt "$count" ]; do
    j=$((j+1))




    type=${1:0:1}
    name=${1:1}
    shift
    shiftby=$((shiftby+1))

    if [ "$type" = "." ]; then
      value=$1
      shift
      shiftby=$((shiftby+1))

      command+=("--arg" "$name" "$value")
    elif [ "$type" = "%" ]; then
      value=$1
      shift
      shiftby=$((shiftby+1))

      command+=("--argjson" "$name" "$value")
    elif [ "$type" = "@" ]; then
      arrlen=$1
      shift
      shiftby=$((shiftby+1))

      _jsonr "$arrlen"  "$@"
      _shiftby=$?

      for ((i=0; i<_shiftby; i++)); do
        shift
        shiftby=$((shiftby+1))
      done

      command+=("--argjson" "$name" "$out")
    
    elif [ "$type" = "!" ]; then
      local numfields=$1
      shift

      shiftby=$((shiftby+1))


      out=$(_json "$numfields" "$@")

      _shiftby=$?

      local k
      for ((k=0; k<_shiftby; k++)); do
        shift
        shiftby=$((shiftby+1))
      done

      command+=("--argjson" "$name" "$out")
    else
      dbg "Invalid type: $type"
      return 1
    fi

    if [ "$#" -eq 0 ]; then
      break
    fi
  done

  command+=('$ARGS.named')

  # dbg "${command[@]}"

  jq "${command[@]}"

  return $shiftby
}


_jsonr() {
  local count=$1
  shift

  local shiftby=0
  out="["


  for ((i=0; i<count; i++)); do
    type=$1
    shift
    shiftby=$((shiftby+1))

    if [ "$i" -gt 0 ]; then
      out+=","
    fi

    if [ "$type" = "." ]; then
      value=$1
      shift
      shiftby=$((shiftby+1))
      
      out+='"'"$value"'"'
    elif [ "$type" = "%" ]; then
      value=$1
      shift
      shiftby=$((shiftby+1))

      out+="$value"
    elif [ "$type" = "!" ]; then
      local numfields=$1
      shift
      shiftby=$((shiftby+1))


      out+=$(_json "$numfields" "$@")

      _shiftby=$?
      for ((j=0; j<_shiftby; j++)); do
        shift
        shiftby=$((shiftby+1))
      done

    # elif [ "$type" = "@" ]; then
      # count=$1
      # shift
      #
      # _jsonr "$count"  "$@"
    else
      echo "Invalid type: $type"
      return 1
    fi
  done

  out+="]"

  return $shiftby
}
