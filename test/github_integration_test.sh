#!/bin/bash

## Use current time to create new and unique workflow file.
DATETIME=$(date +%Y%m%d%H%M%S)

sed -i "s/Datetime - [0-9]\{14\}/Datetime - $DATETIME/" './test/distributed/dummy.yaml'


## Use script to apply workflow to remote repository
./push_workflow_files.sh 'navikt/pb-workflow-authority-test-dummy' './test/distributed'


## Find latest commit on main branch
CURRENT_MAIN_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/refs/heads/main" | jq -r '.object.sha')

## Find sha of remote workflow file after changes were attempted.
DUMMY_WORKFLOW_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/trees/$CURRENT_MAIN_SHA?recursive=1" | jq -r '.tree[] | select(.path == ".github/workflows/dummy.yaml").sha')

## Exit with error if file was not found
if [[ -z $DUMMY_WORKFLOW_SHA ]]; then
  echo "dummy.yaml workflow file was not found in destionation repository."
  exit 1
fi

## Find contents of remote file
curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/blobs/$DUMMY_WORKFLOW_SHA" | jq -r '.content' | base64 -d >> ./test/distributed/remote-dummy.yaml

## Verify that contents of remote file matches local file
if ! diff -q './test/distributed/dummy.yaml' './test/distributed/remote-dummy.yaml' &>/dev/null; then
  echo 'Failed in applying changes to remote repository.'
  exit 1
fi


## Run script again, this time with delete config defined
./push_workflow_files.sh 'navikt/pb-workflow-authority-test-dummy' './test/distributed' './test/delete.conf'

## Fetch remaining files in remote workflow repository
CURRENT_MAIN_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/refs/heads/main" | jq -r '.object.sha')

DUMMY_REPOSITORY_CONTENTS=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/navikt/pb-workflow-authority-test-dummy/git/trees/$CURRENT_MAIN_SHA?recursive=1" | jq -r '.tree[]')

## Verify that no files marked for deletion remains in remote repository
while read file_to_delete; do

  REMOTE_FILE_SHA=$(echo "$DUMMY_REPOSITORY_CONTENTS" | jq -r 'select(.path == ".github/workflows/'"$file_to_delete"'").sha')

  if [[ ! -z $REMOTE_FILE_SHA ]]; then
    echo 'Remote file was not deleted as requested.'
    exit 1
  fi
done < ./test/delete.conf
