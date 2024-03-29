#!/usr/bin/env bash

### Only support gcloud 
### Please ensure gcloud is installed before run this script
GRS_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

source "${GRS_ROOT}/hack/test-config.sh"
source "${GRS_ROOT}/hack/lib/util.sh"

function start-service {
        local name="$1"
        local urls="$2"
        local zone="$3"
        local log_level="${4:-}"
        local extra_args="${5:-}"
        echo "Starting resource management service on ${name}"
        cmd="cd ${SERVER_CODE_ROOT}"
        cmd+=" && mkdir -p ${SERVER_LOG_DIR}"
        args=" --master_ip=${name}"
        args+=" --resource_urls=${urls}"
        if [ ${log_level} != "" ]; then
                args+=" -v=${log_level}"
        fi
        args+=" ${extra_args}"
        log_file="${name}.log"
        cmd+=" && /usr/local/go/bin/go run resource-management/cmds/service-api/service-api.go ${args} > ${SERVER_LOG_DIR}/${log_file} 2>&1 "
        ssh-config "${cmd}" "${name}" "${SERVICE_ZONE}"
}


function start-simulator {
        local name="$1"
        local region_name="$2"
        local rp_num="$3"
        local nodes_per_rp="$4"
        local sim_port="$5"
        local zone="$6"
        local log_level="${7:-}"
        local extra_args="${8:-}"
        echo "Starting simulator on ${name}"
        cmd="cd ${SIM_CODE_ROOT}"
        cmd+=" && mkdir -p ${SIM_LOG_DIR}"
        args=" --region_name=${region_name}"
        args+=" --rp_num=${rp_num}"
        args+=" --nodes_per_rp=${nodes_per_rp}"
        args+=" --master_port=${sim_port}"
        if [ ${log_level} != "" ]; then
                args+=" -v=${log_level}"
        fi
        args+=" ${extra_args}"
        log_file="${name}.log"
        cmd+=" && /usr/local/go/bin/go run resource-management/test/resourceRegionMgrSimulator/main.go ${args} > ${SIM_LOG_DIR}/${log_file} 2>&1 "
        ssh-config "${cmd}" "${name}" "${zone}"

}

function start-scheduler {
        local name="$1"
        local zone="$2"
        local service_num="$3"
        local service_url="$4"
        local request_machines="$5"
        local limit="$6"
        local log_level="${7:-}"
        local extra_args="${8:-}"
        echo "Starting ${service_num} schedluer service on ${name}"
        cmd="cd ${CLIENT_CODE_ROOT}"
        cmd+=" && mkdir -p ${CLIENT_LOG_DIR}"
        args=" --service_url=${service_url}"
        args+=" --request_machines=${request_machines}"
        args+=" --limit=${limit}"
        args+=" --action=watch"
        args+=" --repeats=1"
        if [ ${log_level} != "" ]; then
                args+=" -v=${log_level}"
        fi
        args+=" ${extra_args}"
        log_file="${name}.log"
        for (( i=0; i<${service_num}; i++ )); do
                sleep 1
                gocmd=" && /usr/local/go/bin/go run resource-management/test/e2e/singleClientTest.go ${args} > ${SIM_LOG_DIR}/${log_file}.$i 2>&1 &"
                sshcmd="${cmd}${gocmd}"
                ssh-config "${sshcmd}" "${name}" "${zone}"
        done
}

###############
#   main function
###############

#IFS=','; INSTANCE_SERVER_ZONE=($SERVER_ZONE); unset IFS;
IFS=','; INSTANCE_SIM_ZONE=($SIM_ZONE); unset IFS;
IFS=','; INSTANCE_CLIENT_ZONE=($CLIENT_ZONE); unset IFS;
IFS=','; SIM_REGION_LIST=($SIM_REGIONS); unset IFS;

###TODO
###using go run to start all component for now
###will add build and start from bin

##Only support to start service on one resource management server
if [ ${SERVER_NUM} -gt 0 ]; then
        if [[ "${MASTER_IP}" != "" && "${RESOURCE_URLS}" != "" ]]; then
                start-service "${MASTER_IP}" "${RESOURCE_URLS}" "${SERVICE_ZONE}" "${SERVER_LOG_LEVEL}" "${SERVICE_EXTRA_ARGS}"
        else
                echo "Failed to start service, Please ensure MASTER_IP: ${MASTER_IP} and RESOURCE_URLS: ${RESOURCE_URLS} set correctly"
        fi
fi

echo "Waiting 10 seconds to get resource management service running"
sleep 10

if [ ${SIM_NUM} -gt 0 ]; then
        if [[ "${#SIM_REGION_LIST[@]}" == "${SIM_NUM}" ]]; then
                if [ ${#INSTANCE_SIM_ZONE[@]} == 1 ]; then
                        instance_names=()
                        instance_names=($(gcloud compute instance-groups managed list-instances \
                        "${SIM_INSTANCE_PREFIX}-${INSTANCE_SIM_ZONE[0]}-mig" --zone "${INSTANCE_SIM_ZONE[0]}" --project "${PROJECT}" \
                        --format='value(instance)'))

                        index=0
                        for name in "${instance_names[@]}"; do
                                start-simulator "${name}" "${SIM_REGION_LIST[$index]}" "${SIM_RP_NUM}" "${NODES_PER_RP}" "${SIM_PORT}" "${INSTANCE_SIM_ZONE[0]}" "${SIM_LOG_LEVEL}" "${SIM_EXTRA_ARGS}"
                                index=$(($index + 1))
                        done
                else
                        index=0
                        for zone in "${INSTANCE_SIM_ZONE[@]}"; do
                                start-simulator "${SIM_INSTANCE_PREFIX}-${zone}-${index}" "${SIM_REGION_LIST[$index]}" "${SIM_RP_NUM}" "${NODES_PER_RP}" "${SIM_PORT}" "${zone}" "${SIM_LOG_LEVEL}" "${SIM_EXTRA_ARGS}"
                                index=$(($index + 1)) 
                        done

                fi                      
        else
                echo "Failed to start simulator service, Please ensure SIM_REGIONS: ${SIM_REGIONS} has same number with SIM_NUM: ${SIM_NUM}"
        fi
fi

echo "Waiting 10 seconds to get simulator running"
sleep 10

if [ ${CLIENT_NUM} -gt 0 ]; then
        if [[ "${SERVICE_URL}" != "" ]]; then
                if [ ${#INSTANCE_CLIENT_ZONE[@]} == 1 ]; then
                        instance_names=()
                        instance_names=($(gcloud compute instance-groups managed list-instances \
                        "${CLIENT_INSTANCE_PREFIX}-${INSTANCE_CLIENT_ZONE[0]}-mig" --zone "${INSTANCE_CLIENT_ZONE[0]}" --project "${PROJECT}" \
                        --format='value(instance)'))

                        index=0
                        service_num=$((${SCHEDULER_NUM} / ${CLIENT_NUM} + 1))
                        for name in "${instance_names[@]}"; do
                                if [ $index == $((${CLIENT_NUM} - 1)) ]; then
                                        done_num=$((${service_num} * ${index} ))
                                        service_num=$((${SCHEDULER_NUM} - ${done_num}))
                                fi
                                start-scheduler "${name}" "${INSTANCE_CLIENT_ZONE[0]}" "${service_num}" "${SERVICE_URL}" "${SCHEDULER_REQUEST_MACHINE}" "${SCHEDULER_REQUEST_LIMIT}"  "${CLIENT_LOG_LEVEL}" "${CLIENT_EXTRA_ARGS}"
                                index=$(($index + 1))
                        done
                else
                        index=0
                        service_num=$((${SCHEDULER_NUM} / ${CLIENT_NUM} + 1))
                        for zone in "${INSTANCE_CLIENT_ZONE[@]}"; do
                                if [ $index == $((${CLIENT_NUM} - 1)) ]; then
                                        done_num=$((${service_num} * ${index} ))
                                        service_num=$((${SCHEDULER_NUM} - ${done_num}))
                                fi
                                start-scheduler "${CLIENT_INSTANCE_PREFIX}-${zone}-${index}" "${zone}" "${service_num}" "${SERVICE_URL}" "${SCHEDULER_REQUEST_MACHINE}" "${SCHEDULER_REQUEST_LIMIT}"  "${CLIENT_LOG_LEVEL}" "${CLIENT_EXTRA_ARGS}"
                                index=$(($index + 1)) 
                        done

                fi                      
        else
                echo "Failed to start scheduler service, Please ensure SERVICE_URL: ${SERVICE_URL} is correct"
        fi
fi

echo "Testing is running now, Please remember to run ./hack/test-logcollect.sh to collect logs once testing finished"