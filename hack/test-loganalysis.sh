#!/usr/bin/env bash

### Only support gcloud 
### Please ensure gcloud is installed before run this script
GRS_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

if [ "${DESTINATION}" == "" ]; then
  echo "Env: DESTINATION cannot be empty, Please double check."
  exit 1
fi
mkdir -p ${DESTINATION}/csv

function grep-string {
  local file_name="$1"
  local start_string="$2"
  local end_string="${3:-}"

  grep_string=$(grep "${start_string}" ${file_name})
  if [ "${end_string}" == "" ]; then
    echo "$grep_string" | sed -E "s/.*${start_string}//"
  else
    echo "$grep_string" | sed -E "s/.*${start_string}(.*)${end_string}.*/\1/"
  fi

}

cd ${DESTINATION}

echo "Collecting scheduler test summary to csv"
echo "file name","RegisterClientDuration","ListDuration","Number of nodes listed","Watch session last","Number of nodes Added","Updated","Deleted","watch prolonged than 1s","Watch perc50","Watch perc90","Watch perc99">> ./csv/test.csv
for name in $( ls | grep client);do
  start_string="RegisterClientDuration: "
  end_string=""
  register_client_duration=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="ListDuration: "
  end_string=". Number"
  list_duration=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="Number of nodes listed: "
  end_string=""
  nodes_listed=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="Watch session last: "
  end_string=". Number"
  watch_session_last=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="Number of nodes Added :"
  end_string=", Updated"
  number_nodes_added=$(grep-string "${name}" "${start_string}" "${end_string}") 
  
  start_string="Updated: "
  end_string=", Deleted"
  number_nodes_updated=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="Deleted: "
  end_string=". watch prolonged"
  number_nodes_deleted=$(grep-string "${name}" "${start_string}" "${end_string}") 
  
  start_string="watch prolonged than 1s: "
  end_string=""
  watch_prolonged_than1s=$(grep-string "${name}" "${start_string}" "${end_string}") 
  
  start_string="perc50 "
  end_string=", perc90"
  watch_perc50=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="perc90 "
  end_string=", perc99"
  watch_perc90=$(grep-string "${name}" "${start_string}" "${end_string}")
  
  start_string="perc99 "
  end_string=". Total"
  watch_perc99=$(grep-string "${name}" "${start_string}" "${end_string}")

  echo "${name}","${register_client_duration}","${list_duration}","${nodes_listed}","${watch_session_last}","${number_nodes_added}","${number_nodes_updated}","${number_nodes_deleted}","${watch_prolonged_than1s}","${watch_perc50}","${watch_perc90}","${watch_perc99}" >> ./csv/test.csv
done

###adding empty line to csv
echo "" >> ./csv/test.csv
echo "" >> ./csv/test.csv
echo "" >> ./csv/test.csv
echo "" >> ./csv/test.csv


echo "Collecting service test summary to csv"

for name in $( ls | grep server);do

  grep "\[Metrics\]\[AGG_RECEIVED\]" ${name} >> ./csv/test.csv
  
  ###adding empty line to csv
  echo "" >> ./csv/test.csv
  echo "" >> ./csv/test.csv
  grep "\[Metrics\]\[DIS_RECEIVED\]" ${name} >> ./csv/test.csv
  
  ###adding empty line to csv
  echo "" >> ./csv/test.csv
  echo "" >> ./csv/test.csv
  grep "\[Metrics\]\[DIS_SENDING\]" ${name} >> ./csv/test.csv

  ###adding empty line to csv
  echo "" >> ./csv/test.csv
  echo "" >> ./csv/test.csv
  grep "\[Metrics\]\[DIS_SENT\]" ${name} >> ./csv/test.csv

  ###adding empty line to csv
  echo "" >> ./csv/test.csv
  echo "" >> ./csv/test.csv
  grep "\[Metrics\]\[SER_ENCODED\]" ${name} >> ./csv/test.csv

  ###adding empty line to csv
  echo "" >> ./csv/test.csv
  echo "" >> ./csv/test.csv
  grep "\[Metrics\]\[SER_SENT\]" ${name} >> ./csv/test.csv
done

echo "Please check generated csv report under ./csv/test.csv"