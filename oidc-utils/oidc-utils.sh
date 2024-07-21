#!/bin/sh

# Handle SIGINT or SIGTERM
trap "echo && print_red '[ x ] Bailing...'; exit 1" SIGINT SIGTERM

ARROW="→"
print_cyan() {
    echo -e "\033[0;36m$1\033[0m"
}

print_green() {
    echo -e "\033[0;32m$1\033[0m"
}

print_red() {
    echo -e "\033[0;31m$1\033[0m"
}

print_yellow() {
    echo -e "\033[0;33m$1\033[0m"
}
reset_color() {
    echo -en "\033[0m"
}

print_bye() {
    print_green "[ ✔ ] Mischief managed; Arrivederci!"
}

# Function to inspect the sub claim format
inspect_sub_claim_format() {
    echo "[ + ] $(print_yellow "Inspecting \`sub\` claim formats...")"
    local org_config="$1"
    local repo_config="$2"

    # Extract claim keys from the configurations
    local org_claim_keys
    org_claim_keys=$(echo "$org_config" | jq -r '.include_claim_keys[]')
    local repo_claim_keys=""
    [[ -n "$repo_config" ]] && repo_claim_keys=$(echo "$repo_config" | jq -r '.include_claim_keys[]' 2>/dev/null)

    # Define dangerous and risky claims
    local dangerous_claims="workflow environment"
    local risky_claims="ref context head_ref base_ref"

    # Function to check claim keys
    check_claim_keys() {
        local claim_keys="$1"
        local danger=""
        local risk=""

        for key in $claim_keys; do
            # Check if the claim key is dangerous
            if echo "$dangerous_claims" | grep -q "$key"; then
                # If there are more claims after the dangerous claim - it is dangerous.
                # Check if the found claim first in the claim_keys list
                # If it is the only claim - it is dangerous.
                if [[ "$key" == "$(echo "$claim_keys" | head -n 1)" ]]; then
                    [[ -z "$danger" ]] && danger="true"
                else
                    [[ -z "$risk" ]] && risk="true"
                fi
            fi
            if echo "$risky_claims" | grep -q "$key"; then
                if [[ "$key" == "$(echo "$claim_keys" | head -n 1)" ]]; then
                    [[ -z "$danger" ]] && danger="true"
                else
                    [[ -z "$risk" ]] && risk="true"
                fi
            fi
        done

        [[ -n "$danger" ]] && echo "danger" && return
        [[ -n "$risk" ]] && echo "risk" && return
        echo "ok"
    }

    # Check org claim keys
    echo "[ + ] Checking organization claim keys $ARROW $(print_cyan $(echo "$org_claim_keys" | tr '\n' ', ' | sed 's/,$//'))"
    local org_status
    org_status=$(check_claim_keys "$org_claim_keys")
    # Print result
    if [[ "$org_status" == "danger" ]]; then
        print_red "[ x ] Organization claim keys contain dangerous claims"
    elif [[ "$org_status" == "risk" ]]; then
        print_yellow "[ ! ] Organization claim keys contain risky claims"
    else
        print_green "[ ✔ ] Organization's \`sub\` claim format is safe"
    fi

    # Check repo claim keys if present
    local repo_status="ok"
    if [[ -n "$repo_claim_keys" ]]; then
        echo "[ + ] Checking repository claim keys $ARROW $(print_cyan $(echo "$repo_claim_keys" | tr '\n' ', ' | sed 's/,$//'))"
        repo_status=$(check_claim_keys "$repo_claim_keys")
        # Print result
        if [[ "$repo_status" == "danger" ]]; then
            print_red "[ x ] Repository claim keys contain dangerous claims"
        elif [[ "$repo_status" == "risk" ]]; then
            print_yellow "[ ! ] Repository claim keys contain risky claims"
        else
            print_green "[ ✔ ] Repository's \`sub\` claim format is safe"
        fi
    fi
    exit 0
}

print_cyan '
 .d88888b. 8888888 8888888b.   .d8888b.                  888    d8b 888          
d88P" "Y88b  888   888  "Y88b d88P  Y88b                 888    Y8P 888          
888     888  888   888    888 888    888                 888        888          
888     888  888   888    888 888               888  888 888888 888 888 .d8888b  
888     888  888   888    888 888               888  888 888    888 888 88K      
888     888  888   888    888 888    888 888888 888  888 888    888 888 "Y8888b. 
Y88b. .d88P  888   888  .d88P Y88b  d88P        Y88b 888 Y88b.  888 888      X88 
 "Y88888P" 8888888 8888888P"   "Y8888P"          "Y88888  "Y888 888 888  88888P
 '
# Check if we were passed "--help" or "-h" as the first argument
if [ "$1" == "-h" ] || [ "$1" == "--help" ] || [ "$1" == "help" ]; then
    print_yellow "[ ! ] Update or inspect the OIDC configuration for an organization or a repository"
    print_yellow "[ ! ] Make sure the TOKEN (== github token with admin perms) environment variable is set"
    print_yellow "[ ! ] Usage: $0 [inspect|update|-h] org-name repo-name<optional>"
    echo
    exit 0
fi

# First argument is "update" or "inspect"
if [ "$1" == "inspect" ]; then
    MODE="inspect"
else
    if [ "$1" == "update" ]; then
        MODE="update"
    else
        print_red "[ x ] Invalid mode"
        print_red "[ x ] Please provide either 'inspect' or 'update' as the first argument"
        exit 1
    fi
fi

# Print current  mode in bold purple with underline
echo -n "[ + ] Mode $ARROW " && echo -e "\033[1;35;4m$MODE\033[0m"

# Check if the TOKEN environment variable is set
if [ -z "$TOKEN" ]; then
    print_red "[ x ] TOKEN environment variable not set"
    print_red "[ x ] Please set the TOKEN environment variable to a valid GitHub token"
    exit 1
fi

# Print the used token; print only first 8 characters, use a non-slice approach
echo -n "[ + ] Received GitHub token: " && print_green "$(echo $TOKEN | awk '{print substr($0, 1, 8)}')..."

# Second argument is the org name; if it's empty, print an error and exit
if [ -z "$2" ]; then
    print_red "[ x ] No org name provided"
    print_red "[ x ] Please provide the org name as the first argument"
    exit 1
fi
ORG="$2"

# Third argument is the repo name; if it's empty, we will update the org claim format
if [ -z "$3" ]; then
    echo "[ ! ] No repo name provided"
    print_yellow "[ ! ] Will update \`sub\` claim format for the entire organization"
    REPO=""
else
    REPO="$3"
    URL_FOR_REPO="https://api.github.com/repos/$ORG/$REPO/actions/oidc/customization/sub"
fi

# Echo the names. if REPO is empty, it will print the ORG name, otherwise print both
# echo without newline
echo -n "[ + ] Organization: " && print_green "$ORG"
if ! [[ -z "$REPO" ]]; then
    echo -n "[ + ] Repository: " && print_green "$REPO"
fi
URL="https://api.github.com/orgs/$ORG/actions/oidc/customization/sub"

# Print the org current configuration; print the org name in bold green
echo -n "[ + ] Current configuration for org: " && print_green "$ORG"
org_oidc_config=$(curl -Lsk \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    $URL)

# if the response contains "Bad credentials" then print the error and exit; make is sh compatible for alpine
if echo $org_oidc_config | grep -q "Bad credentials"; then
    print_red "[ x ] Bad credentials"
    print_red "[ x ] Please provide a valid GitHub token"
    exit 1
fi

# Verify we didn't get a "Not Found" error
if echo $org_oidc_config | grep -q "Not Found"; then
    print_red "[ x ] Organization not found"
    print_red "[ x ] Please provide a valid organization name"
    exit 1
fi

print_yellow "$org_oidc_config"

# Check if the response contains a "No Actions OIDC sustom sub claim"
if echo $org_oidc_config | grep -q "No Actions OIDC custom sub claim template"; then
    org_oidc_config=""
fi

# check using negative if we got the repo name
if ! [[ -z "$URL_FOR_REPO" ]]; then
    echo -n "[ + ] Current configuration for repo: " && print_green "$REPO"
    repo_oidc_config=$(curl -Lsk \
        -X GET \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        $URL_FOR_REPO)

    # if the response contains "Bad credentials" then print the error and exit; make is sh compatible for alpine
    if echo $repo_oidc_config | grep -q "Bad credentials"; then
        print_red "[ x ] Bad credentials"
        print_red "[ x ] Please provide a valid GitHub token"
        exit 1
    fi

    # Verify we didn't get a "Not Found" error
    if echo $repo_oidc_config | grep -q "Not Found"; then
        print_red "[ x ] Repository not found"
        print_red "[ x ] Please provide a valid repository name"
        exit 1
    fi

    print_yellow "$repo_oidc_config"
fi

# if we have url for repo, use it; otherwise use the url for org
if [ -z "$URL_FOR_REPO" ]; then
    URL="https://api.github.com/orgs/$ORG/actions/oidc/customization/sub"
else
    URL="$URL_FOR_REPO"
fi

# Switch between the modes
if [ "$MODE" == "inspect" ]; then
    # check if the organization configuration is empty
    if [[ -z "$org_oidc_config" ]]; then
        print_green "[ ✔️ ] The organization \"$ORG\" does not have custom OIDC configuration; It defaults to [repo, context]"
        exit 0
    fi
    inspect_sub_claim_format "$org_oidc_config" "$repo_oidc_config"
fi

# Continue with update mode
# Ask which claim keys to include
VALID_KEYS="
repository ✅
repository_owner ✅
actor ✅
aud ✅
workflow_ref ✅
workflow_sha ✅
job_workflow_ref ✅
job_workflow_sha ✅
runner_environment ✅
repository_id ✅
repository_owner_id ✅
actor_id ✅
run_id ✅
run_number ✅
environment_node_id ✅
workflow ❓
run_attempt ❓
ref ❓
event_name ❓
ref_type ❓
repository_visibility ❓
context ❓
head_ref ❓
base_ref ❓
environment ❓
"

echo -n "[ + ] Select claims for your OIDC \`sub\` claim format from the below list:"
echo -n "$VALID_KEYS" | awk '{
  if ($0 ~ /✅/) {
    print "\033[0;32m" $0 "\033[0m"
  } else if ($0 ~ /❓/) {
    print "\033[0;37m" $0 "\033[0m"
  } else {
    # Reset the color
    print "\033[0m" $0 "\033[0m"
  }
}'

# Print the "Enter the claim keys separated by a comma" message in color
echo -n "[ ? ] Type the claims you'd like to set for the format (comma separated list) "
# Set the input to be yellow
echo -ne "\033[0;33m" && read -p "$ARROW " CLAIM_KEYS && reset_color

# Claim keys is a "," delimited list; convert it to a json array; strip spaces; each entry should be quoted
CLAIM_KEYS=$(echo $CLAIM_KEYS | sed 's/ //g' | sed 's/,/","/g')

# Ask to use defaults if and only if we are updating the repo
if [[ -n "$REPO" ]]; then
    # Ask if we want to use the default configuration
    echo -n "[ ? ] Do you want to use the default configuration? (type 'true' or 'false')"
    echo -ne "\033[0;33m" && read -p "$ARROW " USE_DEFAULT && reset_color
else
    USE_DEFAULT=""
fi

# Update the OIDC configuration
echo -n "[ + ] " && print_yellow "Updating OIDC configuration..."
# Print the curl payload
echo -n "[ + ] " && print_yellow "Payload:"
# Check if 'USE_DEFAULT' is empty; if it is - omit it from the payload
if [[ -z "$USE_DEFAULT" ]]; then
    payload="{\"include_claim_keys\": [\"$CLAIM_KEYS\"]}"
else
    payload="{\"include_claim_keys\": [\"$CLAIM_KEYS\"], \"use_default\": $USE_DEFAULT}"
fi

# Print the payload in color
# echo -e "\033[0;35m$payload\033[0m" | jq
# Add background color to jq print and indent it by 4 spaces
print_yellow "$(echo $payload | jq)"

RESP=$(curl -Lk \
    -X PUT \
    --silent \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    $URL \
    -d "$payload")

# If is empty "{}" or with space between the brackets "{ }" or is with new line and spaces in any order "{\n  }" then is ok, otherwise print the response
if [[ $(echo $RESP | jq -r 'length') -ne 0 ]]; then
    print_red "[ - ] Something went wrong"
    print_red "[ - ] Response from GitHub:"
    print_red "$RESP"
    exit 1
fi

# Print the updated configuration
echo -n "[ + ] " && print_green "New configuration (coming from GitHub):"
r=$(curl -Lk \
    --silent \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    $URL)

# Make sure the response is not empty and not an error
if [[ $(echo $r | jq -r 'length') -eq 0 ]]; then
    print_red "[ - ] Something went wrong"
    print_red "[ - ] Response from GitHub:"
    print_red "$r"
    exit 1
fi

print_green "$r"
