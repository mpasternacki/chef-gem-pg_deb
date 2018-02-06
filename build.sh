#!/bin/sh
set -e

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
Usage: $0 [-i|--image IMAGE] [BUILD_ARGS]

  -i IMAGE, --image IMAGE (default: ${image})
    Run build in specified Docker image. Will work only for
    Debian-based distros. Must be first flag on the command line.

  BUILD_ARGS -- args passed to inner build script:
EOF
        ./scripts/build.inner.sh -H >&2
        exit 0
        ;;
esac

here="$(pwd)"

set -x
docker run \
       --name "chef-gem-pg.build.$$" \
       --rm \
       --volume "${here}:/mnt" \
       --env BUILDING_IN_DOCKER=yes \
       --workdir /root \
       "${image}" \
       /mnt/scripts/build.inner.sh "${@}"

./test.sh -i "${image}" "$(cat .latest)"
