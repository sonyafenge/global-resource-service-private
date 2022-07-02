#!/usr/bin/env bash

# A library of helper functions and constant for the local config.

# Use the config file specified in $SERVICE_CONFIG_FILE, or default to
# config-default.sh.

SERVICE_ROOT=$(dirname "${BASH_SOURCE[0]}")/../../..
source "${SERVICE_ROOT}/test/service/gce/${KUBE_CONFIG_FILE-"config-default.sh"}"

source "${SERVICE_ROOT}/test/service/gce/region-simulator-helper.sh"
source "${SERVICE_ROOT}/test/service/gce/server-helper.sh"

# These prefixes must not be prefixes of each other, so that they can be used to
# detect mutually exclusive sets of nodes.
SIMULATOR_INSTANCE_PREFIX=${NODE_INSTANCE_PREFIX:-"${INSTANCE_PREFIX}-sim"}
PROMPT_FOR_UPDATE=${PROMPT_FOR_UPDATE:-"n"}

function join_csv() {
  local IFS=','; echo "$*";
}

# This function returns the first string before the comma
function split_csv() {
  echo "$*" | cut -d',' -f1
}

# Verify prereqs
function verify-prereqs() {
  local cmd

  # we use gcloud to create the server, gsutil to stage binaries and data
  for cmd in gcloud gsutil; do
    if ! which "${cmd}" >/dev/null; then
      local resp="n"
      if [[ "${PROMPT_FOR_UPDATE}" == "y" ]]; then
        echo "Can't find ${cmd} in PATH.  Do you wish to install the Google Cloud SDK? [Y/n]"
        read resp
      fi
      if [[ "${resp}" != "n" && "${resp}" != "N" ]]; then
        curl https://sdk.cloud.google.com | bash
      fi
      if ! which "${cmd}" >/dev/null; then
        echo "Can't find ${cmd} in PATH, please fix and retry. The Google Cloud " >&2
        echo "SDK can be downloaded from https://cloud.google.com/sdk/." >&2
        exit 1
      fi
    fi
  done
  update-or-verify-gcloud
}

# Update or verify required gcloud components are installed
# at minimum required version.
# Assumed vars
#   KUBE_PROMPT_FOR_UPDATE
function update-or-verify-gcloud() {
  local sudo_prefix=""
  if [ ! -w $(dirname `which gcloud`) ]; then
    sudo_prefix="sudo"
  fi
  # update and install components as needed
  if [[ "${PROMPT_FOR_UPDATE}" == "y" ]]; then
    ${sudo_prefix} gcloud ${gcloud_prompt:-} components install alpha
    ${sudo_prefix} gcloud ${gcloud_prompt:-} components install beta
    ${sudo_prefix} gcloud ${gcloud_prompt:-} components update
  else
    local version=$(gcloud version --format=json)
    python -c'
import json,sys
from distutils import version

minVersion = version.LooseVersion("1.3.0")
required = [ "alpha", "beta", "core" ]
data = json.loads(sys.argv[1])
rel = data.get("Google Cloud SDK")
if "CL @" in rel:
  print("Using dev version of gcloud: %s" %rel)
  exit(0)
if rel != "HEAD" and version.LooseVersion(rel) < minVersion:
  print("gcloud version out of date ( < %s )" % minVersion)
  exit(1)
missing = []
for c in required:
  if not data.get(c):
    missing += [c]
if missing:
  for c in missing:
    print ("missing required gcloud component \"{0}\"".format(c))
    print ("Try running `gcloud components install {0}`".format(c))
  exit(1)
    ' """${version}"""
  fi
}

# Use the gcloud defaults to find the project.  If it is already set in the
# environment then go with that.
#
# Vars set:
#   PROJECT
#   NETWORK_PROJECT
#   PROJECT_REPORTED
function detect-project() {
  if [[ -z "${PROJECT-}" ]]; then
    PROJECT=$(gcloud config list project --format 'value(core.project)')
  fi

  NETWORK_PROJECT=${NETWORK_PROJECT:-${PROJECT}}

  if [[ -z "${PROJECT-}" ]]; then
    echo "Could not detect Google Cloud Platform project.  Set the default project using " >&2
    echo "'gcloud config set project <PROJECT>'" >&2
    exit 1
  fi
  if [[ -z "${PROJECT_REPORTED-}" ]]; then
    echo "Project: ${PROJECT}" >&2
    echo "Network Project: ${NETWORK_PROJECT}" >&2
    echo "Zone: ${ZONE}" >&2
    PROJECT_REPORTED=true
  fi
}

# Use gsutil to get the md5 hash for a particular tar
function gsutil_get_tar_md5() {
  # location_tar could be local or in the cloud
  # local tar_location example ./_output/release-tars/kubernetes-server-linux-amd64.tar.gz
  # cloud tar_location example gs://kubernetes-staging-PROJECT/kubernetes-devel/kubernetes-server-linux-amd64.tar.gz
  local -r tar_location=$1
  #parse the output and return the md5 hash
  #the sed command at the end removes whitespace
  local -r tar_md5=$(gsutil hash -h -m ${tar_location} 2>/dev/null | grep "Hash (md5):" | awk -F ':' '{print $2}' | sed 's/^[[:space:]]*//g')
  echo "${tar_md5}"
}

# Example:  trap_add 'echo "in trap DEBUG"' DEBUG
# See: http://stackoverflow.com/questions/3338030/multiple-bash-traps-for-the-same-signal
function trap_add() {
  local trap_add_cmd
  trap_add_cmd=$1
  shift

  for trap_add_name in "$@"; do
    local existing_cmd
    local new_cmd

    # Grab the currently defined trap commands for this trap
    existing_cmd=$(trap -p "${trap_add_name}" |  awk -F"'" '{print $2}')

    if [[ -z "${existing_cmd}" ]]; then
      new_cmd="${trap_add_cmd}"
    else
      new_cmd="${trap_add_cmd};${existing_cmd}"
    fi

    # Assign the test. Disable the shellcheck warning telling that trap
    # commands should be single quoted to avoid evaluating them at this
    # point instead evaluating them at run time. The logic of adding new
    # commands to a single trap requires them to be evaluated right away.
    # shellcheck disable=SC2064
    trap "${new_cmd}" "${trap_add_name}"
  done
}

# Opposite of ensure-temp-dir()
cleanup-temp-dir() {
  rm -rf "${SERVICE_TEMP}"
}

# Create a temp dir that'll be deleted at the end of this bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir() {
  if [[ -z ${SERVICE_TEMP-} ]]; then
    SERVICE_TEMP=$(mktemp -d 2>/dev/null || mktemp -d -t grs.XXXXXX)
    trap_add cleanup-temp-dir EXIT
  fi
}

# Detect region simulators created in the instance group.
#
# Assumed vars:
#   SIM_INSTANCE_PREFIX

# Vars set:
#   SIM_NAMES
#   INSTANCE_GROUPS
function detect-sim-names() {
  detect-project
  INSTANCE_GROUPS=()
  INSTANCE_GROUPS+=($(gcloud compute instance-groups managed list \
    --project "${PROJECT}" \
    --filter "name ~ '${SIM_INSTANCE_PREFIX}-.+' AND zone:(${ZONE})" \
    --format='value(name)' || true))
  SIM_NAMES=()
  if [[ -n "${INSTANCE_GROUPS[@]:-}" ]]; then
    for group in "${INSTANCE_GROUPS[@]}"; do
      SIM_NAMES+=($(gcloud compute instance-groups managed list-instances \
        "${group}" --zone "${ZONE}" --project "${PROJECT}" \
        --format='value(instance)'))
    done
  fi

  echo "INSTANCE_GROUPS=${INSTANCE_GROUPS[*]:-}" >&2
  echo "SIM_NAMES=${SIM_NAMES[*]:-}" >&2
}


# Checks if there are any present resources related service.
#
# Assumed vars:
#   SERVER_NAME
#   SIM_INSTANCE_PREFIX
#   ZONE
#   REGION
# Vars set:
#   SERVICE_RESOURCE_FOUND
function check-resources() {
  detect-project
  detect-sim-names

  echo "Looking for already existing resources"
  SERVICE_RESOURCE_FOUND=""

  if [[ -n "${INSTANCE_GROUPS[@]:-}" ]]; then
    SERVICE_RESOURCE_FOUND="Managed instance groups ${INSTANCE_GROUPS[@]}"
    return 1
  fi

  if gcloud compute instance-templates describe --project "${PROJECT}" "${SIM_INSTANCE_PREFIX}-template" &>/dev/null; then
    SERVICE_RESOURCE_FOUND="Instance template ${SIM_INSTANCE_PREFIX}-template"
    return 1
  fi

  if gcloud compute instances describe --project "${PROJECT}" "${SERVER_NAME}" --zone "${ZONE}" &>/dev/null; then
    SERVICE_RESOURCE_FOUND="Resource management server ${SERVER_NAME}"
    return 1
  fi

  if gcloud compute disks describe --project "${PROJECT}" "${SERVER_NAME}"-pd --zone "${ZONE}" &>/dev/null; then
    SERVICE_RESOURCE_FOUND="Persistent disk ${SERVER_NAME}-pd"
    return 1
  fi

  # Find out what sim_groups are running.
  local -a sim_groups
  sim_groups=( $(gcloud compute instances list \
                --project "${PROJECT}" \
                --filter="(name ~ '${SIM_INSTANCE_PREFIX}-.+' AND zone:(${ZONE})" \
                --format='value(name)') )
  if (( "${#sim_groups[@]}" > 0 )); then
    SERVICE_RESOURCE_FOUND="${#sim_groups[@]} matching ${SIM_INSTANCE_PREFIX}-.+"
    return 1
  fi

  if gcloud compute firewall-rules describe --project "${NETWORK_PROJECT}" "${SERVER_NAME}-https" &>/dev/null; then
    SERVICE_RESOURCE_FOUND="Firewall rules for ${SERVER_NAME}-https"
    return 1
  fi

  if gcloud compute addresses describe --project "${PROJECT}" "${SERVER_NAME}-ip" --region "${REGION}" &>/dev/null; then
    KUBE_RESOURCE_FOUND="Server's reserved IP"
    return 1
  fi

  # No resources found.
  return 0
}

function check-existing() {
  local running_in_terminal=false
  # May be false if tty is not allocated (for example with ssh -T).
  if [[ -t 1 ]]; then
    running_in_terminal=true
  fi

  if [[ ${running_in_terminal} == "true" || ${SERVICE_UP_AUTOMATIC_CLEANUP} == "true" ]]; then
    if ! check-resources; then
      local run_service_down="n"
      echo "${SERVER_RESOURCE_FOUND} found." >&2
      # Get user input only if running in terminal.
      if [[ ${running_in_terminal} == "true" && ${SERVICE_UP_AUTOMATIC_CLEANUP} == "false" ]]; then
        read -p "Would you like to shut down the old resources (call service-down)? [y/N] " run_service_down
      fi
      if [[ ${run_service_down} == "y" || ${run_service_down} == "Y" || ${SERVICE_UP_AUTOMATIC_CLEANUP} == "true" ]]; then
        echo "... calling service-down" >&2
        service-down
      fi
    fi
  fi
}

function check-network-mode() {
  local mode="$(gcloud compute networks list --filter="name=('${NETWORK}')" --project ${NETWORK_PROJECT} --format='value(x_gcloud_subnet_mode)' || true)"
  # The deprecated field uses lower case. Convert to upper case for consistency.
  echo "$(echo $mode | tr [a-z] [A-Z])"
}

function create-network() {
  if ! gcloud compute networks --project "${NETWORK_PROJECT}" describe "${NETWORK}" &>/dev/null; then
    # The network needs to be created synchronously or we have a race. The
    # firewalls can be added concurrent with instance creation.
    local network_mode="auto"
    if [[ "${CREATE_CUSTOM_NETWORK:-}" == "true" ]]; then
      network_mode="custom"
    fi
    echo "Creating new ${network_mode} network: ${NETWORK}"
    gcloud compute networks create --project "${NETWORK_PROJECT}" "${NETWORK}" --subnet-mode="${network_mode}"
  else
    PREEXISTING_NETWORK=true
    PREEXISTING_NETWORK_MODE="$(check-network-mode)"
    echo "Found existing network ${NETWORK} in ${PREEXISTING_NETWORK_MODE} mode."
  fi
}

function create-subnetworks() {
  case ${ENABLE_IP_ALIASES} in
    true) echo "IP aliases are enabled. Creating subnetworks.";;
    false)
      echo "IP aliases are disabled."
      if [[ "${ENABLE_BIG_CLUSTER_SUBNETS}" = "true" ]]; then
        if [[  "${PREEXISTING_NETWORK}" != "true" ]]; then
          expand-default-subnetwork
        else
          echo "${color_yellow}Using pre-existing network ${NETWORK}, subnets won't be expanded to /19!${color_norm}"
        fi
      elif [[ "${CREATE_CUSTOM_NETWORK:-}" == "true" && "${PREEXISTING_NETWORK}" != "true" ]]; then
          gcloud compute networks subnets create "${SUBNETWORK}" --project "${NETWORK_PROJECT}" --region "${REGION}" --network "${NETWORK}" --range "${NODE_IP_RANGE}"
      fi
      return;;
    *) echo "${color_red}Invalid argument to ENABLE_IP_ALIASES${color_norm}"
       exit 1;;
  esac

  # Look for the alias subnet, it must exist and have a secondary
  # range configured.
  local subnet=$(gcloud compute networks subnets describe \
    --project "${NETWORK_PROJECT}" \
    --region ${REGION} \
    ${IP_ALIAS_SUBNETWORK} 2>/dev/null)
  if [[ -z ${subnet} ]]; then
    echo "Creating subnet ${NETWORK}:${IP_ALIAS_SUBNETWORK}"
    gcloud compute networks subnets create \
      ${IP_ALIAS_SUBNETWORK} \
      --description "Automatically generated subnet for ${INSTANCE_PREFIX} cluster. This will be removed on cluster teardown." \
      --project "${NETWORK_PROJECT}" \
      --network ${NETWORK} \
      --region ${REGION} \
      --range ${NODE_IP_RANGE} \
      --secondary-range "pods-default=${CLUSTER_IP_RANGE}" \
      --secondary-range "services-default=${SERVICE_CLUSTER_IP_RANGE}"
    echo "Created subnetwork ${IP_ALIAS_SUBNETWORK}"
  else
    if ! echo ${subnet} | grep --quiet secondaryIpRanges; then
      echo "${color_red}Subnet ${IP_ALIAS_SUBNETWORK} does not have a secondary range${color_norm}"
      exit 1
    fi
  fi
}

# Robustly try to create a static ip.
# $1: The name of the ip to create
# $2: The name of the region to create the ip in.
function create-static-ip() {
  detect-project
  local attempt=0
  local REGION="$2"
  while true; do
    if gcloud compute addresses create "$1" \
      --project "${PROJECT}" \
      --region "${REGION}" -q > /dev/null; then
      # successful operation - wait until it's visible
      start="$(date +%s)"
      while true; do
        now="$(date +%s)"
        # Timeout set to 15 minutes
        if [[ $((now - start)) -gt 900 ]]; then
          echo "Timeout while waiting for master IP visibility"
          exit 2
        fi
        if gcloud compute addresses describe "$1" --project "${PROJECT}" --region "${REGION}" >/dev/null 2>&1; then
          break
        fi
        echo "Master IP not visible yet. Waiting..."
        sleep 5
      done
      break
    fi

    if gcloud compute addresses describe "$1" \
      --project "${PROJECT}" \
      --region "${REGION}" >/dev/null 2>&1; then
      # it exists - postcondition satisfied
      break
    fi

    if (( attempt > 4 )); then
      echo -e "${color_red}Failed to create static ip $1 ${color_norm}" >&2
      exit 2
    fi
    attempt=$(($attempt+1))
    echo -e "${color_yellow}Attempt $attempt failed to create static ip $1. Retrying.${color_norm}" >&2
    sleep $(($attempt * 5))
  done
}

# Instantiate a kubernetes cluster
#
# Assumed vars
#   KUBE_ROOT
#   <Various vars set in config file>
function service-up() {
  ensure-temp-dir
  detect-project
    #check-existing
  create-network
    #create-subnetworks
    #detect-subnetworks
    #create-cloud-nat-router
    #write-cluster-location
    #write-cluster-name
    #create-autoscaler-config
    #create-server
    create-resourcemanagement-server
    #create-nodes-firewall
    create-region-simulator
    #create-nodes-template
    #create-linux-nodes
}

function create-resourcemanagement-server() {
  echo "Starting rersource management server"
  
  # We have to make sure the disk is created before creating the master VM, so
  # run this in the foreground.
  gcloud compute disks create "${SERVER_NAME}-pd" \
    --project "${PROJECT}" \
    --zone "${ZONE}" \
    --type "${SERVER_DISK_TYPE}" \
    --size "${SERVER_DISK_SIZE}"

  # Reserve the master's IP so that it can later be transferred to another VM
  # without disrupting the kubelets.
  create-static-ip "${SERVER_NAME}-ip" "${REGION}"
  SERVER_RESERVED_IP=$(gcloud compute addresses describe "${SERVER_NAME}-ip" \
    --project "${PROJECT}" --region "${REGION}" -q --format='value(address)')

  create-server-instance "${SERVER_RESERVED_IP}" 


}

function create-region-simulator() {
  echo "Starting region simulatotrs"
    #create-nodes-template
    #create-linux-nodes
}
