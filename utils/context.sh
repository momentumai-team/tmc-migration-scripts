#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")"/log.sh

function use_tmc_source_context () {
  local TMC_CONTEXT="migration"
  if ! tanzu context list -o yaml | yq '.[].name' | grep -qx "$TMC_CONTEXT"; then
    log error "❌ Tanzu context '$TMC_CONTEXT' is not found, please run script 001-base-source_stack-connect.sh to setup the '$TMC_CONTEXT' context"
    exit 1
  fi

  local CURRENT_CONTEXT
  CURRENT_CONTEXT=$(tanzu context current --short)

  if [[ "$CURRENT_CONTEXT" != "$TMC_CONTEXT" ]]; then
    log info "Switch to Tanzu context '$TMC_CONTEXT'"
    if ! tanzu context use "$TMC_CONTEXT"; then
      log error "❌ Failed to switch to Tanzu context '$TMC_CONTEXT'"
      exit 1
    fi
  fi
}

function use_tmc_sm_context () {
  local TMC_SM_CONTEXT="tmc-sm"
  if ! tanzu context list -o yaml | yq '.[].name' | grep -qx "$TMC_SM_CONTEXT"; then
    log error "❌ Tanzu context '$TMC_SM_CONTEXT' is not found, please run script 033-base-sm_stack-connect.sh to setup the '$TMC_SM_CONTEXT' context"
    exit 1
  fi

  local CURRENT_CONTEXT
  CURRENT_CONTEXT=$(tanzu context current --short)

  if [[ "$CURRENT_CONTEXT" != "$TMC_SM_CONTEXT" ]]; then
    log info "Switch to Tanzu context '$TMC_SM_CONTEXT'"
    if ! tanzu context use "$TMC_SM_CONTEXT"; then
      log error "❌ Failed to switch to Tanzu context '$TMC_SM_CONTEXT'"
      exit 1
    fi
  fi
}