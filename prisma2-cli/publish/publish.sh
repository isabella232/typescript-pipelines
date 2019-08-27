#!/bin/bash

set -ex

# init git config
git config --global user.email "prismabots@gmail.com"
git config --global user.name "prisma-bot"


echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc

wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
mv jq-linux64 /usr/local/bin/jq
chmod +x /usr/local/bin/jq

git clone https://github.com/prisma/prisma2
cd prisma2/cli

# TODO: Remove this
# if [ -z "$PUBLISH_CLI" ] && [ -z "$PUBLISH_INTROSPECTION" ] && [ -z "$PUBLISH_PRISMA2" ]; then
#   echo "Nothing to build"
#   exit 0
# fi

if [ "$PUBLISH_CLI" != "true" ] && [ "$PUBLISH_INTROSPECTION" != "true" ] && [ "$PUBLISH_PRISMA2" != "true" ]; then
  echo "Nothing to build"
  exit 0
fi

# collecting git messages
commitMessages=()

if [ "$PUBLISH_CLI" == "true" ]; then
  cd cli
  yarn

  # ensure latest version
  cliVersion=$(npm info @prisma/cli --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${cliVersion}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  yarn publish --patch --no-git-tag-version
  cliVersion=$(cat package.json | jq .version | sed 's/"//g')
  commitMessages+=(-m "@prisma/cli@$cliVersion")
  cd ..
  sleep 4 # let npm breathe
fi

if [ "$PUBLISH_INTROSPECTION" == "true" ]; then
  cd introspection
  yarn
  yarn update-deps

  # ensure latest version
  introspectionVersion=$(npm info @prisma/introspection --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${introspectionVersion}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  yarn publish --patch --no-git-tag-version
  introspectionVersion=$(cat package.json | jq .version | sed 's/"//g')
  commitMessages+=(-m "@prisma/introspection@$introspectionVersion")
  cd ..
  sleep 4 # let npm breathe
fi

gitArgs=(
  -a
)

if [ "$PUBLISH_PRISMA2" == "true" ]; then
  cd prisma2
  yarn
  yarn update-deps

  # ensure latest version
  prisma2Version=$(npm info prisma2 --json | jq .version)
  tmp=$(mktemp)
  jq ".version = ${prisma2Version}" package.json > "$tmp" && mv "$tmp" package.json

  # publish and add to commit message
  # ghetto resiliency
  if [[ $BUILDKITE_TAG ]]; then
    yarn publish --new-version $BUILDKITE_TAG --no-git-tag-version
  else
    prisma2AlphaVersion=$(npm info prisma2 --tag alpha --json | jq .version)
    prisma2AlphaVersion=$(./scripts/bump-version.js $prisma2AlphaVersion)
    yarn publish --tag alpha --new-version $prisma2AlphaVersion  --no-git-tag-version
  fi

  prisma2Version=$(cat package.json | jq .version | sed 's/"//g')
  gitArgs+=(-m "prisma2@$prisma2Version")
  cd ..
fi

# concatenate messages
# order: -a [-m prisma2-message] [-m cli-message] [-m introspection-message] [-m [skip ci]]
commitMessages+=(-m "[skip ci]")
gitArgs+=( "${commitMessages[@]}" )

# spread gitArgs array
git commit "${gitArgs[@]}"

# push
git remote add origin-push https://${GITHUB_TOKEN}@github.com/prisma/prisma2-cli.git > /dev/null 2>&1
git push --quiet --set-upstream origin-push $branch
