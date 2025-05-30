# Build compilation image
ARG RUBY_VERSION=3.4.4
ARG ALPINE_VERSION=3.21
FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION} AS builder

# The application runs from /app
WORKDIR /app

# build-base: compilation tools for bundle
# git: used to pull gems from git
# yarn: node package manager
RUN apk add --update --no-cache build-base git tzdata yaml-dev && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

# Install gems defined in Gemfile
COPY .ruby-version Gemfile Gemfile.lock /app/
RUN bundle config set without 'development test'
RUN bundle install --jobs=4 --no-binstubs

# Copy all files to /app (except what is defined in .dockerignore)
COPY . /app/

RUN RAILS_ENV=production SECRET_KEY_BASE=secret bundle exec rails assets:precompile

# Cleanup to save space in the production image
RUN rm -rf node_modules log tmp && \
  rm -rf /usr/local/bundle/cache && \
  rm -rf .env && \
  find /usr/local/bundle/gems -name "*.c" -delete && \
  find /usr/local/bundle/gems -name "*.h" -delete && \
  find /usr/local/bundle/gems -name "*.o" -delete && \
  find /usr/local/bundle/gems -name "*.html" -delete

# Build runtime image
FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION} AS production

RUN apk add --update --no-cache tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

# The application runs from /app
WORKDIR /app

ENV RAILS_SERVE_STATIC_FILES=true \
  RAILS_ENV=production \
  PORT=8080

RUN bundle config set without 'development test'

# Copy files generated in the builder image
COPY --from=builder /app /app
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

RUN addgroup -S tariff && \
  adduser -S tariff -G tariff && \
  chown -R tariff:tariff /app && \
  chown -R tariff:tariff /usr/local/bundle

HEALTHCHECK CMD nc -z 0.0.0.0 $PORT

USER tariff

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
