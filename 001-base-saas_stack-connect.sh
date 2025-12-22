#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/utils/log.sh

# export TANZU_API_TOKEN=<CSP-TOKEN>
# export ORG_NAME=tanzumissioncontroluserorgstg
# export TANZU_CLI_CEIP_OPT_IN_PROMPT_ANSWER=no

if [ -z "$TANZU_API_TOKEN" ]; then
  log error "❌ TANZU_API_TOKEN environment variable is not set."
  exit 1
fi

if [[ -z "$TMC_ENDPOINT" && -z "$ORG_NAME" ]]; then
  log error "❌ Environment variables TMC_ENDPOINT or ORG_NAME is not set."
  exit 1
fi

if [ -z "$TMC_ENV" ]; then
  TMC_ENV="tmc" # "tmc-dev" for dev stack
fi
# The URL can be overridden by environment variable, e.g for dev stack
# export TMC_ENDPOINT={{ORG_NAME}}.tmc-dev.tanzu.broadcom.com
if [ -z "$TMC_ENDPOINT" ]; then
  TMC_ENDPOINT="${ORG_NAME}.${TMC_ENV}.tanzu.broadcom.com"
fi

# The CSP_URL can be overridden by environment variable, e.g for stg CSP
#  export CSP_URL=https://console-stg.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize
if [ -z "$CSP_URL" ]; then
  CSP_URL="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize"
fi

## Create CLI context.
TMC_CONTEXT=migration

# Clear the context first if it exists.
tanzu context delete ${TMC_CONTEXT} -y

tanzu config eula accept

STAGING=""
if [[ $CSP_URL == *"console-stg.tanzu.broadcom.com"* ]]; then
  STAGING="--staging"
fi

tanzu context create ${TMC_CONTEXT} --type tmc $STAGING --endpoint $TMC_ENDPOINT:443


## Alternative option:
## Exchange the access token.
#export TOKEN_URL=https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize
#export REFRESH_TOKEN=<CSP Token>

echo ""
log info "Fetch the access token:"

export TMC_ACCESS_TOKEN="$(curl -s -X POST $CSP_URL \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "refresh_token=$TANZU_API_TOKEN" | jq -r .access_token)"

echo $TMC_ACCESS_TOKEN
