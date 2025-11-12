#!/usr/bin/env bash

ENV="$1"
SERVICE="$2"
REPO="nick-reck/test-environments"

if [[ -z $ENV || -z $SERVICE ]]; then
  echo "Usage: $0 <env_to_check> <service>"
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

job_name_to_cancel="$SERVICE-$ENV"
for run_id in $run_ids; do
  pending_job_name=$(gh run view $run_id \
    --json jobs \
    -q '.jobs[] | select(.status == "waiting") | .name')
  if [ -z $pending_job_name ]; then
    echo "No jobs with status 'waiting' found."
    continue
  fi

  pending_job_name="${pending_job_name% / deploy}"
  if [[ $pending_job_name == $job_name_to_cancel ]]; then
    if gh run cancel $run_id; then
        echo "Cancelled workflow with run id $run_id"
    else
        echo "Failed to cancel run id $run_id"
    fi
  else
    echo "Skipping run id $run_id, since $pending_job_name isn't waiting for the service $SERVICE and environment $ENV"
  fi
done