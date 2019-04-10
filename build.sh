#!/bin/sh

set -e

VERSION=`cat Dockerfile | grep "${VERSION_KEYWORD}" | awk -F '=' '{print $2}'`
MAJOR=`echo ${VERSION} | cut -d. -f1`
MINOR=`echo ${VERSION} | cut -d. -f2`

docker build --no-cache -t ${IMAGE_NAME}:travis .
docker images

if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then

  if [ "$TRAVIS_BRANCH" = "master" ]; then

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:latest
    docker push ${IMAGE_NAME}:latest

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:${MAJOR}
    docker push ${IMAGE_NAME}:${MAJOR}

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:${MAJOR}.${MINOR}
    docker push ${IMAGE_NAME}:${MAJOR}.${MINOR}

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:${VERSION}
    docker push ${IMAGE_NAME}:${VERSION}

  else

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:dev
    docker push ${IMAGE_NAME}:dev

    docker tag ${IMAGE_NAME}:travis ${IMAGE_NAME}:${VERSION}-dev
    docker push ${IMAGE_NAME}:${VERSION}-dev

  fi

fi
