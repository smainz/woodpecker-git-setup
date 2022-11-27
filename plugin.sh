#!/bin/bash

#set -Eeo pipefail

function usage() {
cat << EOF

woodpecker-git-setup: Configure the cloned git repository for interactions.

Settings:
  REMOTE:       remote to configure (default: 'origin')
  REMOTE_URL:   (ssh) url to configure for remote
                leave empty to convert existing http-url to ssh url
  SSH_KEY:      ssh key to use for authentication
  USER_EMAIL:   email address of the user
  USER_NAME:    name of the user (Default: 'Woodpecker-CI')

EOF
exit 1
}

GIT_USER_NAME="Woodpecker-CI"
GIT_REMOTE="origin"
FAIL=""

echo ""

if [ -n "${PLUGIN_USER_NAME}" ]
then
  GIT_USER_NAME=${PLUGIN_USER_NAME}
fi

if [ -n "${PLUGIN_REMOTE}" ]
then
  GIT_REMOTE=${PLUGIN_REMOTE}
fi

if [ -z "${PLUGIN_USER_EMAIL}" ]
then
  echo "USER_EMAIL must be set"
  FAIL=true
else
  GIT_USER_EMAIL=${PLUGIN_USER_EMAIL}
fi

if [ -z "$PLUGIN_SSH_KEY" ]
then
  echo "SSH_KEY must be set"
  FAIL=true
else
  GIT_SSH_KEY="$PLUGIN_SSH_KEY"
fi

REMOTE_EXISTS=$(git remote | grep "${GIT_REMOTE}")

if [ -z "${REMOTE_EXISTS}" ]
then
  echo "Remote '${GIT_REMOTE}' does not yet exist."
  if [ -z "${PLUGIN_REMOTE_URL}" ]
  then
    echo "REMOTE_URL must be set, if remote does not exist"
    usage
  fi
fi

if [ -z "${PLUGIN_REMOTE_URL}" ]
then
  CURRENT_REMOTE_URL=$(git remote get-url "${GIT_REMOTE}")
  if [[ "${CURRENT_REMOTE_URL}" =~ ^http(s)?.* ]]; then
    GIT_REMOTE_URL=$(git remote get-url "${GIT_REMOTE}" | sed -E -e "s/https?:\\/\\//git@/g" -e "s/\\//:/")
  else
    echo "Can not convert ${CURRENT_REMOTE_URL} to ssh-url, try setting REMOTE_URL"
    usage
  fi
else
  GIT_REMOTE_URL=${PLUGIN_REMOTE_URL}
fi

if [ -n "$FAIL" ]
then
  usage
fi


# Prepare ssh key to use with git
echo "${GIT_SSH_KEY}" > $(pwd)/.git/woodpecker.key
chmod 600 $(pwd)/.git/woodpecker.key
# Define git user
git config --local user.name "${GIT_USER_NAME}"
git config --local user.email "${GIT_USER_EMAIL}"
git config --local core.sshCommand 'ssh -i $(pwd)/.git/woodpecker.key -o StrictHostKeyChecking=no'

if [ -z "${REMOTE_EXISTS}" ]
then
  echo "Adding remote ${GIT_REMOTE} with url ${GIT_REMOTE_URL}"
  git remote add "${GIT_REMOTE}" "${GIT_REMOTE_URL}"
else
  echo "Changing url of remote ${GIT_REMOTE} to url ${GIT_REMOTE_URL}"
  git remote set-url "${GIT_REMOTE}" "${GIT_REMOTE_URL}"
fi
