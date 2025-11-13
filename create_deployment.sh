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

check_and_update_deployment_status () {
    if [ $deployment_id -eq $1 ]; then
        continue
    fi

    current_state=$(gh api -XGET \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments/$1/statuses | jq -r '.[0].state')
    if [[ "$current_state" != "inactive" ]]; then
        update_deployment_status $1 "inactive"
    else
        echo "Deployment $1 is in state $current_state, not updating it."
    fi
}

jq -n \
    --arg tag "$TAG" \
    --arg service "$SERVICE" \
    --arg env "$ENV" \
    '{ "ref": $tag, "task": $service, "environment": $env, "required_contexts": [] }' > payload.json
deployment_id=$(gh api --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$REPO/deployments \
    --input payload.json | jq '.id')
echo "Created deployment $deployment_id for $SERVICE with tag $TAG in $ENV"

update_deployment_status $deployment_id "success"

previous_deployment_ids=$(gh api -XGET \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$REPO/deployments \
  -f 'task='$SERVICE \
  -f 'per_page=2' \
  -f 'environment='$ENV | jq '.[].id')
for previous_deployment_id in $previous_deployment_ids; do
    check_and_update_deployment_status $previous_deployment_id
done

previous_deployment_ids=$(gh api -XGET \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$REPO/deployments \
  -f 'task=deploy' \
  -f 'per_page=5' \
  -f 'environment='$ENV | jq '.[].id')
for previous_deployment_id in $previous_deployment_ids; do
    check_and_update_deployment_status $previous_deployment_id
done

rm payload.json