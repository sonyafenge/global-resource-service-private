#!/usr/bin/env bash
#
# Copyright 2022 Authors of Global Resource Service.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# gcloud multiplexing for shared GCE/GKE tests.
GRS_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..

#Default GCE config
GCLOUD=gcloud
ZONE=${GRS_GCE_ZONE:-us-central1-b}
REGION=${ZONE%-*}
RELEASE_REGION_FALLBACK=${RELEASE_REGION_FALLBACK:-false}

NETWORK=${GRS_GCE_NETWORK:-default}
CREATE_CUSTOM_NETWORK=${CREATE_CUSTOM_NETWORK:-false}
# Enable network deletion by default, unless we're using 'default' network.
if [[ "${NETWORK}" == "default" ]]; then
  GRS_DELETE_NETWORK=${GRS_DELETE_NETWORK:-false}
else
  GRS_DELETE_NETWORK=${GRS_DELETE_NETWORK:-true}
fi
if [[ "${CREATE_CUSTOM_NETWORK}" == true ]]; then
  SUBNETWORK="${SUBNETWORK:-${NETWORK}-custom-subnet}"
fi


#common config
GOLANG_VERSION=${GOLANG_VERSION:-"1.17.11"}
REDIS_VERSION=${REDIS_VERSION:-"6:7.0.0-1rl1~focal1"}
INSTANCE_PREFIX="${GRS_INSTANCE_PREFIX:-grs}"
SERVER_NAME="${INSTANCE_PREFIX}-server"
SIM_INSTANCE_PREFIX="${INSTANCE_PREFIX}-sim"
GCI_VERSION="ubuntu-2004-focal-v20220701"
GCE_PROJECT="ubuntu-os-cloud"
GCE_IMAGE="ubuntu-2004-focal-v20220701"
ENABLE_IP_ALIASES=${ENABLE_IP_ALIASES:-false}

#Region simulator config
SIM_SIZE=${SIM_SIZE:-n1-standard-8}
NUM_SIMS=${NUM_SIMS:-5}
SIM_DISK_TYPE=pd-standard
SIM_DISK_SIZE=${SIM_DISK_SIZE:-"100GB"}
SIM_ROOT_DISK_SIZE=${SIM_ROOT_DISK_SIZE:-"20GB"}
SIM_OS_DISTRIBUTION=${SIM_OS_DISTRIBUTION:-gci}
SIM_LOG_LEVEL=${SIM_LOG_LEVEL:-"--v=4"}
SIM_REGION_NAME=${SIM_REGION_NAME:-"Beijing"}
SIM_RP_NUM=${SIM_RP_NUM:-10}
SIM_NODES_PER_RP=${SIM_NODES_PER_RP:-20000}
GCE_SIM_PROJECT=${GCE_PROJECT:-"ubuntu-os-cloud"}
GCE_SIM_IMAGE=${GCE_IMAGE:-"ubuntu-2004-focal-v20220701"}
SIM_TAG="${INSTANCE_PREFIX}-sim"

#Resource manager server config
SERVER_SIZE=${SERVER_SIZE:-n1-standard-32}
SERVER_DISK_TYPE=pd-ssd
SERVER_DISK_SIZE=${SERVER_DISK_SIZE:-"200GB"}
SERVER_ROOT_DISK_SIZE=${SERVER_ROOT_DISK_SIZE:-"20GB"}
SERVER_OS_DISTRIBUTION=${SERVER_OS_DISTRIBUTION:-gci}
SERVER_LOG_LEVEL=${SERVER_LOG_LEVEL:-"--v=4"}
GCE_SERVER_PROJECT=${GCE_PROJECT:-"ubuntu-os-cloud"}
GCE_SERVER_IMAGE=${GCE_IMAGE:-"ubuntu-2004-focal-v20220701"}
SERVER_TAG="${INSTANCE_PREFIX}-server"
RESOURCE_URLS=${RESOURCE_URLS:-}

  