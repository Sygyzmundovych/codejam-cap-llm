#!/usr/bin/env bash
cf target | grep -E 'org:|space:' && echo "space_guid: $(cf space $(cf target | grep 'space:' | awk '{print $2}') --guid)"

space_guid=$(cf space $(cf target | grep 'space:' | awk '{print $2}') --guid)
echo -n "HDI instances to be removed: "; cf curl "/v3/service_instances?service_plan_names=hdi-shared&per_page=100&space_guids="$space_guid | jq '.pagination.total_results'

cf curl "/v3/service_instances?service_plan_names=hdi-shared&per_page=100&space_guids=$space_guid" | jq -c '.resources[] | {guid: .guid, name: .name}' | while read -r instance; do
    read guid name < <(echo "$instance" | jq -r '"\(.guid) \(.name)"')
    echo "Deleting $name with guid $guid"
    cf curl -X DELETE "/v3/service_instances/"$guid
    # cf curl "/v3/service_instances/?names="$name | jq '.resources[].last_operation'
    cf curl "/v3/service_instances/"$guid | jq '.last_operation'
done