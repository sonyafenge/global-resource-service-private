#!/usr/bin/env bash


set -o errexit
set -o nounset
set -o pipefail

SERVICE_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..

if [ -f "${SERVICE_ROOT}/test/service/env.sh" ]; then
    source "${SERVICE_ROOT}/test/service/env.sh"
fi

source "${SERVICE_ROOT}/test/service/util.sh"

if [ -z "${ZONE-}" ]; then
  echo "... Starting cluster using provider: ${CLOUD_PROVIDER}" >&2
else
  echo "... Starting cluster in ${ZONE} using provider ${CLOUD_PROVIDER}" >&2
fi

echo "... calling verify-prereqs" >&2
verify-prereqs

echo "... calling service-up" >&2
service-up

echo -e "Done, resource management service is running!\n" >&2

echo

exit 0
