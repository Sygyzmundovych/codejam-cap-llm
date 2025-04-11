#!/usr/bin/env bash

# This script lists users in a CloudFoundry org who are not privileged users
# (i.e., not Org Manager, Billing Manager, or Org Auditor)
#
# Usage: ./script_name.sh [org_name]
# If org_name is not provided, it defaults to 'Developer Advocates Free Tier_cap-ai-codejam-op6zhda1'

set -euo pipefail

# Get ORG from parameter or use default
ORG="${1:-Developer Advocates Free Tier_cap-ai-codejam-op6zhda1}"

# Get emails of privileged users (Org Manager, Billing Manager, Org Auditor)
if ! cf org-users "$ORG" | tail -n +2 | grep "@" | sort | uniq > privileged_users.txt; then
    echo "Error: Failed to get privileged users for org $ORG" >&2
    exit 1
fi

# Get emails of all org users
if ! cf org-users "$ORG" -a | tail -n +2 | grep "@" | sort | uniq > all_org_users.txt; then
    echo "Error: Failed to get all users for org $ORG" >&2
    exit 1
fi

# Print users who are not privileged users
if ! comm -23 all_org_users.txt privileged_users.txt; then
    echo "Error: Failed to compare user lists for org $ORG" >&2
    exit 1
fi

# Clean up temp files, if not needed for verification
# rm privileged_users.txt all_org_users.txt
