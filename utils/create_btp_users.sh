#!/bin/bash

# Check if CSV file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 path/to/file.csv"
  exit 1
fi

CSV_FILE="$1"

# Skip the header and extract the user_email column (column 6)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r type id user_type user_sso_id user_login user_email user_first_name user_last_name rsvp_response || [ -n "$type" ]; do
  # Remove quotes from email
  email=$(echo "$user_email" | tr -d '"')
  
  # Run BTP CLI command
  echo "Assigning role to: $email"
  btp assign security/role-collection CodeJam_Participant --subaccount 6088766d-dcc4-4e56-972f-652baad796be --to-user "$email"
done