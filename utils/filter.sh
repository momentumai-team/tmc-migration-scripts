#!/bin/bash

# Shared helpers for the comma-separated name filters used by this fork
# (TMC_CG_FILTER, TMC_WC_FILTER, etc.). Designed so call sites can pipe
# `tanzu ... -o yaml` output through a yq expression unconditionally —
# the helper returns either a real `select(...)` or a `.` passthrough
# depending on whether the filter is set.

# Turn a comma-separated list of names (with optional surrounding whitespace)
# into a yq/jq regex alternation: "a, b ,c" -> "a|b|c". Empty input -> empty.
build_filter_pattern() {
    local input="$1"
    if [[ -z "$input" ]]; then
        echo ""
        return
    fi
    echo "$input" \
        | tr ',' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$' \
        | paste -sd'|' -
}

# Echo a yq pipeline fragment that filters items by a JSON path matching the
# comma-separated names. When the filter env var is empty, returns "." so the
# pipeline becomes a no-op.
#
# Usage:
#   FILTER=$(yq_filter_or_passthrough '.fullName.clusterGroupName' "$TMC_CG_FILTER")
#   tanzu tmc secret list -s clustergroup -o yaml | yq ".secrets[] | $FILTER" -s '...'
yq_filter_or_passthrough() {
    local path="$1"
    local input="$2"
    local pattern
    pattern=$(build_filter_pattern "$input")
    if [[ -z "$pattern" ]]; then
        echo "."
    else
        echo "select($path | test(\"^($pattern)\$\"))"
    fi
}

# Same as yq_filter_or_passthrough but emits a jq-compatible expression. Useful
# when the surrounding pipeline is already in jq (see 002, 031-export which
# round-trip through jq to reshape lists).
jq_filter_or_passthrough() {
    yq_filter_or_passthrough "$@"
}
