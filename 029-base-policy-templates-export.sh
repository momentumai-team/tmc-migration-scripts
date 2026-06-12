#! /bin/bash

source utils/log.sh

register_last_words "Export policy templates"

log "************************************************************************"
log "* Exporting Policy Templates from source TMC SM ..."
log "************************************************************************"

DATA_DIR="data"
DIR="$DATA_DIR/policies/templates"
mkdir -p $DIR

log info "Exporting policy templates ..."
tanzu tmc policy policy-template list -o yaml > $DIR/templates.yaml