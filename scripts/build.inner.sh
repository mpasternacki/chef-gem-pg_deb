#!/bin/sh
set -e

_options () {
    cat <<EOF
    -p -- set up pgdg repo
    -c VERSION -- install chef omnibus package VERSION
    -v VERSION -- install pg gem VERSION
EOF

}
usage () {
    cat >&2 <<EOF
Usage: $0 [OPTIONS]

Options:
$(_options)
    -f -- force (run even when it seems we're not in docker)
    -h -- show this help
EOF
    exit "${1:-0}"
}

dpkg_version () {
    dpkg-query -W -f '${Version}\n' "${@}"
}

basedir="$(cd $(dirname "$0") && cd .. && pwd)"

# metadata
meta="# chef-gem-pg metadata"
addmeta () {
    meta="$(for metum in "${meta}" "${@}" ; do echo "${metum}" ; done)"
}

# defaults
use_pgdg=0
chef_version=
pg_gem_version=
force=0

while getopts pc:v:fhH opt
do
    case "$opt" in
        p) use_pgdg=1 ;;
        c)
            chef_version="-v $OPTARG"
            addmeta "chef_version=$OPTARG"
            ;;
        v) pg_gem_version="-v $OPTARG" ;;
        f) force=1 ;;
        h) usage 0 ;;
        H)
            # undocumented options list for outer script help message
            _options
            exit 0
            ;;
        *) usage 1 ;;
    esac
done

# sanity
if [ "${BUILDING_IN_DOCKER:-0}" != yes ] ; then
    echo "*** It seems we're not building in Docker. Suspicious." >&2
    if [ "${force}" -ne 0 ] ; then
        echo "*** Force flag specified, continuing" >&2
    else
        echo "*** Please use the \`-f\` flag if you want to run anyway." >&2
        exit 1
    fi
fi

# pgdg repo
addmeta "use_pgdg=${use_pgdg}"
test "${use_pgdg}" -eq 0 || "${basedir}/scripts/setup_pgdg_repo.sh"

# install packages
apt-get update --yes
apt-get install --yes \
        build-essential \
        curl \
        libpq-dev \
        libgmp-dev

# install chef
"${basedir}/scripts/chef-install.sh" ${chef_version}
export PATH=/opt/chef/embedded/bin:$PATH

# install fpm
gem install --no-document fpm

# prepare work dir
wd="$(mktemp -d pg.gem.patch.XXXXXXX)"
cd "${wd}"

# download and unpack pg gem
gem fetch pg ${pg_gem_version}
pg_gem="$(echo pg-*.gem)"
addmeta "pg_gem=${pg_gem}"
gem unpack "${pg_gem}"
gem spec --ruby "${pg_gem}" > "${pg_gem%.gem}"/pg.gemspec

# patch pg gem
cd "${pg_gem%.gem}"
cp ext/extconf.rb ext/extconf.rb.orig
cat >ext/extconf.rb <<EOF
require 'rbconfig'
%w(
configure_args
LIBRUBYARG_SHARED
LIBRUBYARG_STATIC
LIBRUBYARG
LDFLAGS
).each do |key|
  RbConfig::CONFIG[key].gsub!(/-Wl[^ ]+( ?\\/[^ ]+)?/, '')
  RbConfig::MAKEFILE_CONFIG[key].gsub!(/-Wl[^ ]+( ?\\/[^ ]+)?/, '')
end
RbConfig::CONFIG['RPATHFLAG'] = ''
RbConfig::MAKEFILE_CONFIG['RPATHFLAG'] = ''

EOF
cat ext/extconf.rb.orig >> ext/extconf.rb

# rebuild pg gem
gem build pg.gemspec

# deps
libpq5_version="$(dpkg_version libpq5)"
chef_pkg_version="$(dpkg_version chef)"
addmeta \
    libpq5_version="${libpq5_version}" \
    chef_pkg_version="${chef_pkg_version}"

. /etc/lsb-release
iteration="${DISTRIB_CODENAME}+chef${chef_pkg_version}"
if [ "${use_pgdg}" -ne 0 ] ; then
    iteration="${iteration}+pgdg"
fi

# repackage the rebuilt pg gem as deb
fpm -s gem -t deb \
    --iteration "${iteration}" \
    --url 'https://github.com/mpasternacki/chef-gem-pg_deb' \
    --gem-gem /opt/chef/embedded/bin/gem \
    --gem-package-prefix chef-gem \
    --depends "libpq5 >= ${libpq5_version}" \
    --depends "chef = ${chef_pkg_version}" \
    --verbose \
    "${pg_gem}"

# copy built deb file to volume
deb="$(echo chef-gem-*.deb)"
addmeta deb_file="${deb}"
cp -v "${deb}" "${basedir}"
echo "${meta}" > "${basedir}/${deb}.meta"
echo "${deb}" > "${basedir}/.latest"

chown --reference="${basedir}" \
      "${basedir}/${deb}" \
      "${basedir}/${deb}.meta" \
      "${basedir}/.latest"
