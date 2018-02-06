#!/bin/sh
set -e -x

basedir="$(cd $(dirname "$0") && cd .. && pwd)"

pkg_path="${basedir}/$(basename "${1%.meta}")"

. "${pkg_path}.meta"

test "${use_pgdg:-0}" -eq 0 || "${basedir}/scripts/setup_pgdg_repo.sh"
apt-get update --yes
apt-get install --yes curl

"${basedir}/scripts/chef-install.sh" ${chef_version:+-v "${chef_version}"}

dpkg -i "${pkg_path}" || :
apt-get install -f --yes

/opt/chef/embedded/bin/ruby "${basedir}/scripts/test.rb"
