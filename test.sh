#!/bin/sh
set -e -x

image=ubuntu:16.04
case "$1" in
    -i|--image)
        image="$2"
        shift 2
        ;;
    -i*)
        image="${1#-i}"
        shift 1
        ;;
    --image=*)
        image="${1#--image=}"
        shift 1
        ;;
    -h|--help)
        cat >&2 <<EOF
Usage: $0 [-i|--image IMAGE] DEB

  -i IMAGE, --image IMAGE (default: ${image})
    Run build in specified Docker image. Will work only for
    Debian-based distros. Must be first flag on the command line.
EOF
        exit 0
        ;;
esac


docker run -d --rm \
       --name chef-gem-pg.test.postgres \
       -e POSTGRES_PASSWORD=chef_gem_pg \
       postgres

trap 'docker rm -f chef-gem-pg.test.postgres' EXIT

docker run --rm \
       --volume `pwd`:/mnt \
       --workdir /root \
       --link chef-gem-pg.test.postgres:postgres \
       "${image}" \
       /mnt/scripts/test.inner.sh "${@}"
