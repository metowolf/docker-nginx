#!/bin/sh

set -e

VERSION=`cat Dockerfile | grep 'ARG NGINX_VERSION' | awk -F '=' '{print $2}'`

docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
docker build -t metowolf/nginx .

docker images

docker push metowolf/nginx
docker tag metowolf/nginx metowolf/nginx:$VERSION
docker push metowolf/nginx:$VERSION
