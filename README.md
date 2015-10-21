# travis-nightly-builder
Rake tasks to build "nightly" builds

## [php-src-builder](https://github.com/travis-ci/php-src-builder)

Builds PHP

## [cpython-builder](https://github.com/travis-ci/cpython-builder)

Builds Python

`cpython-builder` has the branch named `version` that builds a specific
version of Python (as defined by python-build).

To invoke this, set up `TRAVIS_TOKEN` correctly,
and run:

```ruby
rake build['cpython-builder','version','VERSION=3.5.0b3']
```

The task needs `VERSION=…` set, or else it will fail.

## [travis-nightly-builder](https://github.com/travis-ci/apt-whitelist-checker)

Runs tests for APT package whitelist requests
