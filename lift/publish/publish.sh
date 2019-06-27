#!/bin/bash
set -ex
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
env
git clone https://github.com/prisma/lift
cd lift
yarn
yarn test
yarn publish --patch --no-git-tag-version

git config --global user.email "prismabots@gmail.com"
git config --global user.name "prisma-bot"
export VERSION=`cat package.json | jq .version`
git commit -a -m $VERSION
git remote add origin-push https://${GH_TOKEN}@github.com/prisma/lift.git > /dev/null 2>&1
git push --quiet --set-upstream origin-push $branch