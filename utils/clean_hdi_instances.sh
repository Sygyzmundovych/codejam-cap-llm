#!/usr/bin/env bash
cf space $(cf target | grep 'space:' | awk '{print $2}') --guid
# cf target | grep -E 'org:|space:' && echo "guid: $(cf space $(cf target | grep 'space:' | awk '{print $2}') --guid)"

echo -n "HDI instances to be removed: "; cf curl "/v3/service_instances?service_plan_names=hdi-shared&space_guids=cb8de26a-a8f1-43d7-b0c9-f4c12f5a5fd0" | jq '.pagination.total_results'
cf curl "/v3/service_instances?service_plan_names=hdi-shared&space_guids=cb8de26a-a8f1-43d7-b0c9-f4c12f5a5fd0&per_page=5000" | jq -c '.resources[] | {guid: .guid, name: .name}' | while read -r instance; do
    read name guid < <(echo "$instance" | jq -r '.name, .guid')
    echo "Deleting HDI: $name"
    cf curl -X DELETE "/v3/service_instances/"$guid
done
