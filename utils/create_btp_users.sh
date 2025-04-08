#!/bin/bash
# Check if BTP CLI is logged in
if btp --info | grep -q "You are currently not logged in."; then
  echo "Error: Not logged in to BTP CLI. Please log in and try again."
  exit 1
fi

# Default values
DEFAULT_ROLE_COLLECTION="CodeJam_Participant"
DEFAULT_SUBACCOUNT_ID="6088766d-dcc4-4e56-972f-652baad796be"

# Check if CSV file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 path/to/file-with-registrations.csv [--role-collection ROLE_COLLECTION] [--subaccount-id SUBACCOUNT_ID]"
  exit 1
fi

# Check if the CSV file exists and is readable
if [ ! -f "$1" ] || [ ! -r "$1" ]; then
  echo "Error: File '$1' does not exist or is not readable."
  exit 1
fi

CSV_FILE="$1"

# Parse command-line arguments starting from the second argument
shift # Skip the first argument (mandatory CSV file)
while [[ "$#" -gt 0 ]]; do
  # echo "Processing argument: $1"
  case $1 in
    --role-collection) ROLE_COLLECTION="$2"; shift ;;
    --subaccount-id) SUBACCOUNT_ID="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Use default values if not provided
ROLE_COLLECTION="${ROLE_COLLECTION:-$DEFAULT_ROLE_COLLECTION}"
SUBACCOUNT_ID="${SUBACCOUNT_ID:-$DEFAULT_SUBACCOUNT_ID}"

# Skip the header and extract the user_email column (column 6)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r type id user_type user_sso_id user_login user_email user_first_name user_last_name rsvp_response || [ -n "$type" ]; do
  # Remove quotes from email
  email=$(echo "$user_email" | tr -d '"')
  
  # Run BTP CLI command
  echo "Assigning role to: $email"
  btp assign security/role-collection "$ROLE_COLLECTION" --subaccount "$SUBACCOUNT_ID" --to-user "$email"
done