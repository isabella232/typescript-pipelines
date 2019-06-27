#!/bin/bash

set -ex
env
git clone https://github.com/prisma/lift
cd lift
yarn
yarn test
# yarn publish --