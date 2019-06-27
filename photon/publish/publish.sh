#!/bin/bash

set -ex

git clone https://github.com/prisma/photonjs
cd photonjs/packages/photon
yarn
yarn test