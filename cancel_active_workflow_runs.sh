#! /bin/bash

ENV="$1"
SERVICE="$2"
CURRENT_RUN_ID="$3"
REPO="nick-reck/test-environments"

if [[ -z "$ENV" || -z "$SERVICE" || -z "$CURRENT_RUN_ID" ]]; then
  echo "Usage: $0 <env_to_check> <service> <current_run_id>"
  exit 1
fi

echo "Fetching workflow runs with status 'waiting' for $REPO..."

run_ids=$(gh api \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/actions/runs?status=waiting" \
  --jq '.workflow_runs[].id')

if [ -z "${run_ids+x}" ] || [ ${#run_ids[*]} -eq 0 ]; then
  echo "No runs with status 'waiting' found."
  exit 0
fi

num_waiting_workflows=${#run_ids[*]}
echo "$num_waiting_workflows runs with status 'waiting' found."
echo "Checking pending deployments for each run..."

current_run_created_at=$(gh run view $CURRENT_RUN_ID \
  --json createdAt \
  -q '.createdAt')
# current_run_created_at_timestamp=$(date -juf "%Y-%m-%dT%H:%M:%SZ" "$current_run_created_at" +%s)
current_run_created_at_timestamp=$(date -d "$current_run_created_at" +"%s")
job_name_to_cancel="$SERVICE $ENV"
for run_id in $run_ids; do
  pending_run_created_at=$(gh run view $run_id \
    --json createdAt \
    -q '.createdAt')
  if [ -z "$pending_run_created_at" ]; then
    echo "Failed to retrieve created at date for run $run_id"
    continue
  fi

  # pending_run_created_at_timestamp=$(date -juf "%Y-%m-%dT%H:%M:%SZ" "$pending_run_created_at" +%s)
  pending_run_created_at_timestamp=$(date -d "$pending_run_created_at" +"%s")
  if (( pending_run_created_at_timestamp > current_run_created_at_timestamp )); then
    echo "Run $run_id is newer than current run, skipping cancellation"
    continue
  fi

  pending_job_name=$(gh run view $run_id \
    --json jobs \
    -q '.jobs[] | select(.status == "waiting") | .name')
  if [ -z "$pending_job_name" ]; then
    echo "No jobs with status 'waiting' found."
    continue
  fi

  pending_job_name="${pending_job_name#Approval gate | }"
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