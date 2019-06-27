#!/bin/bash

set -ex

git clone https://github.com/prisma/lift
cd lift
yarn
yarn test