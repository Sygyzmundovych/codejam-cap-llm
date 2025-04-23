#!/usr/bin/env bash
# Check if BTP CLI is logged in
if btp --info | grep -q "You are currently not logged in."; then
  echo "Error: Not logged in to BTP CLI. Please log in and try again."
  exit 1
fi

set -uo pipefail

ORG="Developer Advocates Free Tier_cap-codejam-2xnpct8z"
SPACE="dev"
ROLE="SpaceDeveloper"
SUBACCOUNT="13f4f274-4515-4c67-8274-cbde80a4e744"
GLOBAL_ACCOUNT="sap-developer-advocates-free-tier"

email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

while IFS= read -r email || [[ -n "$email" ]]; do
  # Trim whitespace (including newlines)
  email=$(echo "$email" | xargs)

  if [[ "$email" =~ $email_regex ]]; then
    echo -e "\n➡️  Processing: $email"

    if cf org-users "$ORG" -a | grep "$email"; then
      echo "   🔍 User found in Cloud Foundry org. Proceeding with cleanup..."

      echo "1️⃣  Unsetting space roles..."
      for role in SpaceDeveloper SpaceManager SpaceAuditor SpaceSupporter; do
        echo "   🔄 Attempting to unset role: $role"
        if ! cf unset-space-role "$email" "$ORG" "$SPACE" "$role"; then
          echo "   ❌ Failed to unset space role $role for $email"
        else
          echo "   ✅ Successfully unset space role $role for $email"
        fi
      done

      echo "2️⃣  Getting user GUID..."
      user_guid=$(cf curl "/v3/users?usernames=$email" | jq -r '.resources[0].guid')

      if [[ -n "$user_guid" && "$user_guid" != "null" ]]; then
        echo "   ✅ User GUID: $user_guid"

        echo "3️⃣  Getting organization_user role GUID..."
        role_guid=$(cf curl "/v3/roles?user_guids=$user_guid" | jq -r '.resources[] | select(.type=="organization_user") | .guid')

        if [[ -n "$role_guid" ]]; then
          echo "   🧹 Removing role assignment: $role_guid"
          if ! cf curl -X DELETE "/v3/roles/$role_guid"; then
            echo "   ❌ Failed to remove role assignment for $email"
          fi
        else
          echo "   ⚠️  No organization_user role found for user."
        fi

        echo "4️⃣  Checking if user is still in org..."
        if cf org-users "$ORG" -a | grep -q "$email"; then
          echo "   ❌ User still present in org."
        else
          echo "   ✅ User successfully removed from org."
        fi
      else
        echo "   ❌ Failed to retrieve user GUID for $email"
      fi
    else
      echo "   ⚠️  User not found in Cloud Foundry org. Skipping steps 1–4."
    fi

    echo "5️⃣  Deleting user from BTP subaccount..."
    if ! btp delete security/user "$email" --subaccount "$SUBACCOUNT"; then
      echo "   ❌ Failed to delete user from BTP subaccount: $email"
    else
      echo "   ✅ User successfully deleted from BTP subaccount."
    fi

    echo "6️⃣  Deleting user from BTP global account..."
    if ! btp delete security/user "$email" --global-account "$GLOBAL_ACCOUNT"; then
      echo "   ❌ Failed to delete user from BTP global account: $email"
    else
      echo "   ✅ User successfully deleted from BTP global account."
    fi

  else
    echo "❌ Invalid email: $email"
  fi

done
echo -e "\n✅  Cleanup completed."