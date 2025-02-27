#!/bin/bash

set -e
set -x

input_source=($INPUT_SOURCE_FOLDER)
input_dest=($INPUT_DESTINATION_FOLDER)
if [ -z "$input_source" ]
then
  echo "Source folders must be defined"
  return -1
fi

if [ "${#input_source[@]}" != "${#input_dest[@]}" ]
then
  echo "Invalid number of source and destination folders"
  exit 1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
for i in "${!input_source[@]}"; do
    mkdir -p $CLONE_DIR/${input_dest[i]}/
    cp -r ${input_source[i]} "$CLONE_DIR/${input_dest[i]}"
    echo "${input_source[i]} ${input_dest[i]}"
done
cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  if [ $INPUT_ALLOW_FORCE_PUSH == "false" ]
  then
    git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
    echo "Creating a pull request"
    gh pr create -t $INPUT_DESTINATION_HEAD_BRANCH \
                 -b $INPUT_DESTINATION_HEAD_BRANCH \
                 -B $INPUT_DESTINATION_BASE_BRANCH \
                 -H $INPUT_DESTINATION_HEAD_BRANCH \
                    $PULL_REQUEST_REVIEWERS
  else
    echo "Force push enabled"
    git push -uf origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
    echo "Creating a pull request"
    gh pr create -t $INPUT_DESTINATION_HEAD_BRANCH \
                 -b $INPUT_DESTINATION_HEAD_BRANCH \
                 -B $INPUT_DESTINATION_BASE_BRANCH \
                 -H $INPUT_DESTINATION_HEAD_BRANCH \
                    $PULL_REQUEST_REVIEWERS || true
    return 0
  fi
else
  echo "No changes detected"
fi
