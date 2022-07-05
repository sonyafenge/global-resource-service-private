#!/usr/bin/env bash


set -o errexit
set -o nounset
set -o pipefail

SERVICE_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..

if [ -f "${SERVICE_ROOT}/test/service/env.sh" ]; then
    source "${SERVICE_ROOT}/test/service/env.sh"
fi

source "${SERVICE_ROOT}/test/service/util.sh"

echo "Bring down service using provider: ${CLOUD_PROVIDER}" >&2

echo "... calling verify-prereqs" >&2
verify-prereqs

echo "... calling service-down" >&2
service-down

echo "Done"

