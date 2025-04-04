#!/bin/bash

# Get ORG from parameter or default to a specific org
# if not called with a parameter, like ./cf_org_users_only.sh 'Developer Advocates Free Tier_cap-ai-codejam-op6zhda1'
ORG="${1:-Developer Advocates Free Tier_cap-ai-codejam-op6zhda1}"

# Get emails of privileged users (Org Manager, Billing Manager, Org Auditor)
cf org-users "$ORG" | grep "@" | awk '{print $1}' | sort | uniq > privileged_users.txt

# Get emails of all org users
cf org-users "$ORG" -a | grep "@" | awk '{print $1}' | sort | uniq > all_org_users.txt

# Print users who are not privileged users
comm -23 all_org_users.txt privileged_users.txt

# Clean up temp files
rm privileged_users.txt all_org_users.txt
