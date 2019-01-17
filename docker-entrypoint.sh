#!/bin/sh

set -e

crond -f &
exec "$@"
