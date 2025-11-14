#! /bin/bash

ENV="$1"
REPO="nick-reck/test-environments"

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <env_to_check_deploys_from>"
  exit 1
fi

case "$ENV" in
    "prod")
        from_env="test"
        ;;
    "test")
        from_env="dev"
        ;;
esac

services=("campaigns" "audience")
deployable_services=()
deployable_tags=()
for service in "${services[@]}"; do
    from_env_deployment_id=$(gh api -XGET \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments \
        -f 'task='$service \
        -f 'per_page=1' \
        -f 'environment='$from_env | jq '.[].id')
    from_tag=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments/$from_env_deployment_id \
        | jq -r '.ref')
    to_env_deployment_id=$(gh api -XGET \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments \
        -f 'task='$service \
        -f 'per_page=1' \
        -f 'environment='$ENV | jq '.[].id')
    if [[ -z "$to_env_deployment_id" ]]; then
        deployable_tags+=("$from_tag")
        deployable_services+=("$service")
        continue
    fi
    to_tag=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /repos/$REPO/deployments/$to_env_deployment_id \
        | jq -r '.ref')
    if [[ "$from_tag" != "$to_tag" ]]; then
        deployable_tags+=("$from_tag")
        deployable_services+=("$service")
        continue
    fi
done

json_array="[]"

for i in "${!deployable_services[@]}"; do
  service="${deployable_services[i]}"
  tag="${deployable_tags[i]}"
  
  json_object=$(jq -n --arg service "$services" --arg tag "$tag" '{"service": $service, "tag": $tag}')
  json_array=$(echo "$json_array" | jq --argjson obj "$json_object" '. + [$obj]')
done

json_string="$(echo "$json_array" | jq -Rs .)"
str=${json_string//\\n/}
st=${str#\"}
echo ${st%\"} | sed 's/ //g'

# echo "$(jq -c -n '$ARGS.positional' --args "${deployable_services[@]}")"