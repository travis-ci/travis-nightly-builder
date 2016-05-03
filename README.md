# travis-nightly-builder
Rake tasks to build compatible language runtimes via API.

The Rake task `build` tasks a few arguments and invokes appropriate
API calls to initiate builds.

The Rake task taks 3 arugments:

1. Repository name
1. Branch to build
1. Space-delimited argument list to override the builds

## [travis-rubies](https://github.com/travis-ci/travis-rubies)

Builds Ruby

```sh-session
$ rake build['travis-rubies','build','RUBY=2.1.9']
```

## [php-src-builder](https://github.com/travis-ci/php-src-builder)

Builds PHP

## [cpython-builder](https://github.com/travis-ci/cpython-builder)

Builds Python

```sh-session
$ rake build['cpython-builder','version','VERSION=3.5.0b3']
```

The task needs `VERSION=…` set, or else it will fail.

## [travis-nightly-builder](https://github.com/travis-ci/apt-whitelist-checker)

Runs tests for APT package whitelist requests
