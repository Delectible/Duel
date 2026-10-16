#!/usr/bin/env bash
# One-time Google Cloud setup for Duel's online side. Paste into Cloud Shell
# (console.cloud.google.com, the >_ button, with the Duel Firebase project
# selected), or run with: bash setup_gcp.sh <project-id>
#
# - Turns on the services the referee needs.
# - A home for the referee's images (Artifact Registry, Northern Virginia).
# - duel-referee: the account the referee runs as. It may read and write
#   Firestore, nothing else.
# - duel-deploy: the account GitHub deploys with. Its key is printed at
#   the end: paste it into the repo secret GCP_DEPLOY_KEY.
# Safe to run twice.
set -euo pipefail
PROJECT="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION=us-east4
[ -n "$PROJECT" ] || { echo "Usage: bash setup_gcp.sh <project-id>"; exit 1; }
echo "Setting up $PROJECT"
gcloud config set project "$PROJECT" >/dev/null

gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  firestore.googleapis.com firebaserules.googleapis.com iam.googleapis.com \
  cloudresourcemanager.googleapis.com

gcloud artifacts repositories describe duel --location "$REGION" >/dev/null 2>&1 ||
  gcloud artifacts repositories create duel --location "$REGION" --repository-format docker \
    --description "Duel referee images"
# Keep only the 5 newest images (storage costs money).
cat > /tmp/duel-cleanup.json <<'JSON'
[{"name": "keep-5", "action": {"type": "Keep"}, "mostRecentVersions": {"keepCount": 5}},
 {"name": "delete-rest", "action": {"type": "Delete"}, "condition": {"tagState": "ANY"}}]
JSON
gcloud artifacts repositories set-cleanup-policies duel --location "$REGION" \
  --policy /tmp/duel-cleanup.json --no-dry-run >/dev/null

account() {
  gcloud iam service-accounts describe "$1@$PROJECT.iam.gserviceaccount.com" >/dev/null 2>&1 ||
    gcloud iam service-accounts create "$1" --display-name "$2"
}
grant() {
  gcloud projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$1@$PROJECT.iam.gserviceaccount.com" \
    --role "$2" --condition None >/dev/null
}
account duel-referee "Duel referee (Cloud Run)"
account duel-deploy "Duel deploy (GitHub Actions)"
grant duel-referee roles/datastore.user
for role in roles/run.admin roles/artifactregistry.writer roles/firebaserules.admin \
  roles/datastore.indexAdmin roles/datastore.viewer roles/serviceusage.serviceUsageConsumer roles/firebase.viewer; do
  grant duel-deploy "$role"
done
# The deployer may start the referee as duel-referee (and nothing else).
gcloud iam service-accounts add-iam-policy-binding "duel-referee@$PROJECT.iam.gserviceaccount.com" \
  --member "serviceAccount:duel-deploy@$PROJECT.iam.gserviceaccount.com" \
  --role roles/iam.serviceAccountUser >/dev/null

gcloud iam service-accounts keys create duel-deploy-key.json \
  --iam-account "duel-deploy@$PROJECT.iam.gserviceaccount.com"
echo
echo "Done. Next, on GitHub (Delectible/Duel > Settings > Secrets and variables > Actions):"
echo "  1. Secrets: New repository secret GCP_DEPLOY_KEY = everything between the lines below."
echo "  2. Variables: New repository variable FIREBASE_PROJECT = $PROJECT"
echo "------------------------------------------------------------------"
cat duel-deploy-key.json
echo
echo "------------------------------------------------------------------"
rm duel-deploy-key.json
echo "(The key file is deleted here; GitHub keeps the only copy.)"
