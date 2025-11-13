#! /bin/bash

ENV="$1"
SERVICE="$2"
TAG="$3"
REPO="nick-reck/test-environments"

if [[ -z "$ENV" || -z "$TAG" || -z "$SERVICE" ]]; then
  echo "Usage: $0 <env_to_check> <service> <tag>"
  exit 1
fi

update_deployment_status () {
    jq -n --arg state "$2" '{ "state": $state, "auto_inactive": false }' > payload.json
    if gh api --method POST \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments/$1/statuses \
        --input payload.json > /dev/null; then
        echo "Updated deployment $1 status to $2."
    else
        echo "Failed to update deployment $1 status to $2."
        exit 1
    fi
}
deployment_id=$(gh api --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$REPO/deployments \
    -f 'ref='$TAG \
    -f 'task='$SERVICE \
    -f 'environment='$ENV | jq -r '.id')
if [ -z "$deployment_id" ]; then
    echo "Created deployment $deployment_id for $SERVICE with tag $TAG in $ENV"
else
    echo "Failed to create deployment for $SERVICE with tag $TAG in $ENV"
    exit 1
fi

update_deployment_status $deployment_id "success"

previous_deployment_ids=$(gh api -XGET \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$REPO/deployments \
  -f 'task='$SERVICE \
  -f 'per_page=5' \
  -f 'environment='$ENV | jq '.[].id')
for previous_deployment_id in $previous_deployment_ids; do
    if [ $deployment_id -eq $previous_deployment_id ]; then
        continue
    fi

    current_state=$(gh api -XGET \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments/$previous_deployment_id/statuses | jq -r '.[0].state')
    if [[ "$current_state" == "success" ]]; then
        update_deployment_status $previous_deployment_id "inactive"
    else
        echo "Deployment $previous_deployment_id is in state $current_state, not updating it."
    fi
done