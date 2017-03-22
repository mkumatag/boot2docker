#!/bin/sh -x

sudo apt-get -y install git make docker docker.io

DOCKER_REPO="https://github.com/docker/docker"
DOCKER_TAG="17.03.0-ce"

mkdir -p docker-src
cd docker-src
git clone -b "v$DOCKER_TAG" "$DOCKER_REPO"

cd docker

make build

make binary

cp  ./bundles/$DOCKER_TAG/binary-daemon/* ./bundles/$DOCKER_TAG/binary-client/*  ../../build_scripts/docker-binaries/
cd ../../build_scripts/docker-binaries/

rm -f dockerd-$DOCKER_TAG*
rm -f docker-$DOCKER_TAG*
sudo chgrp root *
sudo chown root *

cd ../

#sudo docker build -t boot2docker-ppc64le  .



echo "***********************************************"
echo "Completed building boot2docker.iso for ppc64le "
echo "**********************************************"




