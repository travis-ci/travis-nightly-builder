# travis-nightly-builder
Rake tasks to build compatible language runtimes via API.

The Rake task `build` tasks 3 arguments (shown below) and invokes appropriate
API calls to initiate builds.

## `build` Rake task arguments

1. Repository name
1. Branch to build
1. Space-delimited argument list to override the builds
1. String to filter jobs. The string should be a semicolon-delimited list of
   equal-delimited key-values pairs. Those jobs in `jobs.include` that match
   _all_ of the filters will be chosen and put on the payload; e.g.,
   'dist=bionic'

## Compatible repositories

### [travis-rubies](https://github.com/travis-ci/travis-rubies)

Builds Ruby

```sh-session
$ rake build['travis-rubies','build','RUBY=2.1.9']
```

### [php-src-builder](https://github.com/travis-ci/php-src-builder)

Builds PHP

```sh-session
$ rake build['php-src-builder','default','VERSION=7.0.6 ALIAS=7.0']
```

### [cpython-builder](https://github.com/travis-ci/cpython-builder)

Builds Python

```sh-session
$ rake build['cpython-builder','default','VERSION=3.5.0b3']
```

The task needs `VERSION=…` set, or else it will fail.

### [travis-erlang-builder](https://github.com/travis-ci/travis-erlang-builder)

Builds OTP Release

```sh-session
$ rake build['travis-erlang-builder','master','VERSION=19.0']
```

### [perl-builder](https://github.com/travis-ci/perl-builder)

Builds Perl

```sh-session
$ bundle exec rake build['perl-builder','master',"VERSION=5.24.0 ALIAS=5.24"]
```

For Perl with extra configuration flags, do:

```sh-sessin
$ bundle exec rake build['perl-builder','master',"VERSION=perl-5.24.0 NAME=5.24.0-shrplib ARGS='-Duseshrplib -Duseithreads'"]
```

### [apt-whitelist-checker](https://github.com/travis-ci/apt-whitelist-checker)

Runs tests for APT package whitelist requests

## Web App

This repository also includes a Sinatra app which serves two purposes:

1. List known archives for given criteria:
   ```
   GET /builds/:lang/:os/:release/:arch
   ```
   The list is stored as JSON in a Redis instance and refreshed if the local data are
   older than 2 hours.
   Each of the trailing parts can be omitted, in which case all archives matching
   the given criteria are shown.

   1. This endpoint normally serves HTML content, and in this case a Travis CI
      account is required.
   1. You may also request the list as JSON or YAML with the `Accept` header; e.g.,
      ```
      curl -H "Accept: application/json" https://language-archives.travis-ci.com/builds/erlang
      ```
      No Travis CI account is required in this case.
2. Request builds with given criteria:
   ```
   POST /build
   ```
   with body containing the following parameters:
    * repo:
    * branch:
    * env:
    * os:
    * dist:
    * arch:
    * version:

   This endpoint is valid for Travis CI administrators only.
