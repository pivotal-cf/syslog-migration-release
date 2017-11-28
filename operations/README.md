# BOSH Operations Files
While this release principally targets Ops Manager,
it is often easier and faster
to test with BOSH and [`cf-deployment`][cf-d] directly.
The ops file in this directory
is intended to ease testing
of integration with this release
with OSS resources,
in order to tighten
and simplify
feedback loops.

`switch-to-syslog-migration.yml`
is meant to be applied after
`cf-deployment/operations/addons/enable-component-syslog.yml`
in the [`cf-deployment`][cf-d] repo.
All it does is switch the release used in the add-on.
In order to use any migration-specific features,
you will need to create further ops-files.

[cf-d]: https:github.com/cloudfoundry/cf-deployment

