#!/bin/bash
set -ex
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
curl -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x /usr/local/bin/jq
env
git clone https://github.com/prisma/lift
cd lift
yarn
yarn test
# make sure we're having the latest version
VERSION=$(npm info @prisma/lift --json | jq .version)
tmp=$(mktemp)
jq ".version = \"${VERSION}\"" package.json > "$tmp" && mv "$tmp" package.json

yarn publish --patch --no-git-tag-version

git config --global user.email "prismabots@gmail.com"
git config --global user.name "prisma-bot"
export NEW_VERSION=$(cat package.json | jq .version)
git commit -a -m $NEW_VERSION
git remote add origin-push https://${GH_TOKEN}@github.com/prisma/lift.git > /dev/null 2>&1
git push --quiet --set-upstream origin-push $branch