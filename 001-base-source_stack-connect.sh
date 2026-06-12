#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/utils/log.sh

# Connect to the source TMC stack and create the `migration` tanzu CLI context.
#
# Both sides of this migration are TMC Self-Managed. Source-specific env vars
# keep this script's inputs separate from the destination's (set in 033), so
# the operator never has to swap env vars between source and destination runs.
#
# export TMC_SOURCE_USERNAME=admin-user@customer.com
# export TMC_SOURCE_PASSWORD=Fake@Pass
# export TMC_SOURCE_DNS=tmc-source.tanzu.io
#
# If MFA is enabled for the source IDP, export this:
# export TMC_SOURCE_IDP_MFA_ENABLED=true

if [ -z "$TMC_SOURCE_USERNAME" ]; then
  log error "❌ TMC_SOURCE_USERNAME environment variable is not set."
  exit 1
fi

if [ -z "$TMC_SOURCE_PASSWORD" ]; then
  log error "❌ TMC_SOURCE_PASSWORD environment variable is not set."
  exit 1
fi

if [ -z "$TMC_SOURCE_DNS" ]; then
  log error "❌ TMC_SOURCE_DNS environment variable is not set."
  exit 1
fi

TMC_CONTEXT="migration"

# Clear the context first if it exists.
tanzu context delete ${TMC_CONTEXT} -y

tanzu config eula accept

# `tanzu tmc context create --basic-auth` reads TMC_SELF_MANAGED_USERNAME and
# TMC_SELF_MANAGED_PASSWORD by name. Map the source-specific vars onto those
# names only for this invocation so the destination's env vars (set for 033)
# remain untouched in the caller's shell.
if [[ "$TMC_SOURCE_IDP_MFA_ENABLED" == "true" ]]; then
  echo "The source IDP MFA is enabled. Follow the CLI prompt to open the URL in a browser and complete the authentication process."
  tanzu tmc context create ${TMC_CONTEXT} --endpoint ${TMC_SOURCE_DNS} -i pinniped
else
  TMC_SELF_MANAGED_USERNAME="$TMC_SOURCE_USERNAME" \
  TMC_SELF_MANAGED_PASSWORD="$TMC_SOURCE_PASSWORD" \
    tanzu tmc context create ${TMC_CONTEXT} --endpoint ${TMC_SOURCE_DNS} -i pinniped --basic-auth
fi
