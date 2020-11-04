#!/bin/bash

DATETIME=$(date +%Y%m%d%H%M%S)

sed -i "s/Datetime - [0-9]\{14\}/Datetime - $DATETIME/" './test/workflows/__DISTRIBUTED_dummy.yml'

./push_workflow_files.sh 'navikt/pb-workflow-authority-test-dummy' './test/workflows'

CURRENT_MAIN_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/refs/heads/main" | jq -r '.object.sha')

DUMMY_WORKFLOW_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/trees/$CURRENT_MAIN_SHA?recursive=1" | jq -r '.tree[] | select(.path == ".github/workflows/dummy.yml").sha')

if [[ -z $DUMMY_WORKFLOW_SHA ]]; then
  echo "dummy.yml workflow file was not found in destionation repository."
  exit 1
fi

curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/blobs/$DUMMY_WORKFLOW_SHA" | jq -r '.content' | base64 -d >> ./test/workflows/dummy.yml

if diff -q './test/workflows/dummy.yml' './test/workflows/__DISTRIBUTED_dummy.yml' &>/dev/null; then
  echo 'Changes were exported successfully.'
  exit 0
else
  echo 'Failed in applying changes to remote repository.'
  exit 1
fi