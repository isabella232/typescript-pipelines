#!/bin/bash

set -ex

echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
mv jq-linux64 /usr/local/bin/jq
chmod +x /usr/local/bin/jq
env

git clone https://github.com/prisma/photonjs
cd photonjs


if [ "$PUBLISH_FETCH_ENGINE" != "true" ] && [ "$PUBLISH_ENGINE_CORE" != "true" ] && [ "$PUBLISH_PHOTON" != "true" ]; then
  echo "Nothing to build"
  exit 0
fi

# collecting git messages
commitMessages=()

if [ "$PUBLISH_FETCH_ENGINE" == "true" ]; then
  cd packages/fetch-engine 
  yarn

  # ensure latest version
  fetchEngineVersion=$(npm info @prisma/fetch-engine --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${fetchEngineVersion}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  yarn publish --patch --no-git-tag-version
  fetchEngineVersion=$(cat package.json | jq .version | sed 's/"//g')
  commitMessages+=(-m "@prisma/fetch-engine@$fetchEngineVersion")
  cd ../..
  sleep 4 # let npm breathe
fi

if [ "$PUBLISH_ENGINE_CORE" == "true" ]; then
  cd packages/engine-core
  yarn
  yarn update-deps

  # ensure latest version
  engineCoreVersion=$(npm info @prisma/engine-core --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${engineCoreVersion}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  yarn publish --patch --no-git-tag-version
  engineCoreVersion=$(cat package.json | jq .version | sed 's/"//g')
  commitMessages+=(-m "@prisma/engine-core@$engineCoreVersion")
  cd ../..
  sleep 4 # let npm breathe
fi

gitArgs=(
  -a
)

if [ "$PUBLISH_PHOTON" == "true" ]; then
  cd packages/photon
  yarn
  yarn update-deps

  # ensure latest version
  photonVersion=$(npm info @prisma/photon --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${photonVersion}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  if [ -z "$BUMP_ONLY" ]; then
    yarn publish --patch --no-git-tag-version
    photonVersion=$(cat package.json | jq .version | sed 's/"//g')
    gitArgs+=(-m "@prisma/photon@$photonVersion")
  fi

  cd ../..
fi

# concatenate messages
# order: -a [-m photon-message] [-m fetch-engine-message] [-m engine-core-message] [-m [skip ci]]
commitMessages+=(-m "[skip ci]")
gitArgs+=( "${commitMessages[@]}" )

# init git config
git config --global user.email "prismabots@gmail.com"
git config --global user.name "prisma-bot"

# spread gitArgs array
git commit "${gitArgs[@]}"

# push
git remote add origin-push https://${GITHUB_TOKEN}@github.com/prisma/photonjs.git > /dev/null 2>&1
git push --quiet --set-upstream origin-push $branch