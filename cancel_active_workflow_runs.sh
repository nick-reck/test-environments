#!/usr/bin/env bash

REPO="$1"
ENV="$2"

if [[ -z $REPO || -z $ENV ]]; then
  echo "Usage: $0 <owner/repo> <env_to_check>"
  exit 1
fi

echo "Fetching workflow runs with status 'waiting' for $REPO..."

run_ids=$(gh api \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/actions/runs?status=waiting" \
  --jq '.workflow_runs[].id')

if [ -z $run_ids ]; then
  echo "No runs with status 'waiting' found."
  exit 0
fi

num_waiting_workflows=${#run_ids[*]}
echo "$num_waiting_workflows runs with status 'waiting' found."
echo "Checking pending deployments for each run..."

for run_id in $run_ids; do
  pending_env=$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/actions/runs/$run_id/pending_deployments" \
    --jq '.[].environment.name')

  if [ $pending_env == $ENV ]; then
    if gh run cancel $run_id; then
        echo "Cancelled workflow with run id $run_id"
    else
        echo "Failed to cancel run id $run_id"
    fi
  fi
done