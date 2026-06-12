#!/bin/bash

# TMC SM REST API helper. Pulls auth tokens and endpoint from whichever tanzu
# context is currently active, so the same helper works for both the source
# (`migration` context, set by 001) and the destination (`tmc-sm` context,
# set by 033). Callers are responsible for switching to the right context
# before invoking curl_api_call.

curl_api_call() {
  local method="GET"
  local data=""
  local url=""

  # Parse flags
  while [[ $# -gt 0 ]]
  do
    opt=${1:-""}
    case $opt in
      -X) method="$2"; shift 2;;
      -d) data="$2"; shift 2;;
      *) url="$1"; shift;;
    esac
  done

  if [ -z "$url" ]; then
    echo "Usage: curl_api_call [-X METHOD] [-d DATA] <URL>"
    return 1
  fi

  # Resolve the currently active tanzu context so this helper works against
  # whichever TMC SM stack the caller is pointing at.
  local TMC_CTX
  TMC_CTX=$(tanzu context current --short 2>/dev/null)
  if [ -z "$TMC_CTX" ]; then
    echo "No active tanzu context. Run 001 (source) or 033 (destination) first."
    return 1
  fi

  # Refresh the token by issuing a cheap authenticated call, then re-read the
  # context to pull the newly-minted accessToken / IDToken.
  tanzu tmc clustergroup get default >/dev/null && eval $(tanzu context get "$TMC_CTX" | yq -r '.globalOpts.auth | "export TMC_SM_ACCESS_TOKEN=\"\(.accessToken)\"; export TMC_SM_ID_TOKEN=\"\(.IDToken)\";"' )

  # Derive the API endpoint from the pinniped issuer in the active context.
  export TMC_SM_ENDPOINT=$(tanzu context get "$TMC_CTX" | yq -r '.globalOpts.auth.issuer' | sed -E 's|https://pinniped-supervisor\.([^/]+)/provider/pinniped|\1|')

  # Build base curl command
  local cmd="curl -X $method"
  cmd+=" -H \"Content-Type: application/json\""
  cmd+=" -H \"Authorization: Bearer $TMC_SM_ACCESS_TOKEN\""
  cmd+=" -H \"grpc-metadata-x-user-id: $TMC_SM_ID_TOKEN\""

  # Add data if provided
  if [ -n "$data" ]; then
    cmd+=" -d '$data'"
  fi

  # Add the URL
  cmd+=" \"https://$TMC_SM_ENDPOINT/$url\""

  eval "$cmd"
}
