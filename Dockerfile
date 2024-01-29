FROM ruby:2.7.6

LABEL maintainer Travis CI GmbH <travis-docker-images@travis-ci.com>

# packages required for bundle install
RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends git make gcc \
   && rm -rf /var/lib/apt/lists/* \
)

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

RUN bundle install --verbose --retry=3 --deployment

COPY . /app

CMD ["/bin/bash", "-c", "bundle exec rackup --port ${PORT:-4000}"]