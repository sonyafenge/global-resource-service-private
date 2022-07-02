#!/usr/bin/env bash

# create-server-instance creates the server instance. If called with
# an argument, the argument is used as the name to a reserved IP
# address for the server. (In the case of upgrade/repair, we re-use
# the same IP.)
#
# variables are set:
#   ensure-temp-dir
#   detect-project
#   get-bearer-token
function create-server-instance {
  local address=""
  [[ -n ${1:-} ]] && address="${1}"
  local internal_address=""
  [[ -n ${2:-} ]] && internal_address="${2}"

  write-server-env
  ensure-gci-metadata-files
  create-server-instance-internal "${SERVER_NAME}" "${address}" "${internal_address}"
}

function create-server-instance-internal() {
  local gcloud="gcloud"
  local retries=5
  local sleep_sec=10

  local -r server_name="${1}"
  local -r address="${2:-}"
  local -r internal_address="${3:-}"

  local network=$(make-gcloud-network-argument \
    "${NETWORK_PROJECT}" "${REGION}" "${NETWORK}" "${SUBNETWORK:-}" \
    "${address:-}")

  #local metadata="kube-env=${KUBE_TEMP}/master-kube-env.yaml"
  #metadata="${metadata},kubelet-config=${KUBE_TEMP}/master-kubelet-config.yaml"
  #metadata="${metadata},user-data=${KUBE_ROOT}/cluster/gce/gci/master.yaml"
  #metadata="${metadata},configure-sh=${KUBE_ROOT}/cluster/gce/gci/configure.sh"
  #metadata="${metadata},${MASTER_EXTRA_METADATA}"

  local disk="name=${server_name}-pd"
  disk="${disk},device-name=server-pd"
  disk="${disk},mode=rw"
  disk="${disk},boot=no"
  disk="${disk},auto-delete=no"

  for attempt in $(seq 1 ${retries}); do
    if result=$(${gcloud} compute instances create "${server_name}" \
      --project "${PROJECT}" \
      --zone "${ZONE}" \
      --machine-type "${SERVER_SIZE}" \
      --image-project="${SERVER_IMAGE_PROJECT}" \
      --image "${SERVER_IMAGE}" \
      --tags "${SERVER_TAG}" \
      --scopes "storage-ro,compute-rw,monitoring,logging-write" \
      #--metadata-from-file "${metadata}" \
      --disk "${disk}" \
      --boot-disk-size "${SERVER_ROOT_DISK_SIZE}" \
      #${MASTER_MIN_CPU_ARCHITECTURE:+"--min-cpu-platform=${MASTER_MIN_CPU_ARCHITECTURE}"} \
      #${preemptible_master} \
      ${network} 2>&1); then
      echo "${result}" >&2

      return 0
    else
      echo "${result}" >&2
      if [[ ! "${result}" =~ "try again later" ]]; then
        echo "Failed to create server instance due to non-retryable error" >&2
        return 1
      fi
      sleep $sleep_sec
    fi
  done

  echo "Failed to create server instance despite ${retries} attempts" >&2
  return 1
}
