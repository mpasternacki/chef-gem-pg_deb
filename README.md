chef-gem-pg package builder
===========================

Scripts in this repository build a `.deb` package with the
[pg gem](https://rubygems.org/gems/pg) for
[Omnibus Chef client](https://downloads.chef.io/chef).

The [postgresql
cookbook](https://supermarket.chef.io/cookbooks/postgresql) needs the
`pg` gem installed within Chef environment. Installing directly with
`gem install` it is problematic, because of linking issues (system vs
omnibus OpenSSL). The gem needs to be patched. The cookbook handles
that, but it needs some [quite awful
workarounds](https://github.com/sous-chefs/postgresql/blob/v6.1.1/recipes/ruby.rb#L64-L121).
This needs to run on every node that needs Postgres integration, and
it's difficult to debug when it goes wrong.

This scripting will build a `chef-gem-pg` Debian package that will
include a prebuilt `pg` gem. It has a strict dependency on Omnibus Chef
package version to make sure dynamic linking won't break when Chef is
upgraded, and it depends on `libpq5`, the PostgreSQL client library.

Building
--------

The package is built in a Docker container. Run `./build.sh` to build
the package with latest Chef and Ubuntu 16.04. Run `./build.sh -h` to
see available options. You can choose base image, Chef version, pg gem
version, and you can build against libraries from the [PGDG
repository](https://wiki.postgresql.org/wiki/Apt).

At the end, package is tested in a separate container against a
dockerized PostgreSQL server. You should see `{"hello"=>"world"}` near
the bottom of the output.

The `test.sh` script can be used to test an already built package.

Using the package
-----------------

If you use the `postgresql` cookbook, make sure the package is
installed (in compile time) before `postgresq::ruby` recipe
runs. Distributing the package is left as an exercise to the reader.

For example, if the package is available in an apt repository, the
following should work:

    package('chef-gem-pg').action(:install)
    include_recipe 'postgresql::ruby'

If Postgres integration outside what `postgresql` cookbook provides is
needed, just install the package in compile time before it's required.
