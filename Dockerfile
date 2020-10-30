# system dependency image
FROM ruby:2.7.2-buster AS spotlight-sys-deps

ENV HOME /app
ENV BLACKLIGHT_INSTALL_OPTIONS "--devise"

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} app_spotlight && \
    useradd -m -l -g app_spotlight -u ${USER_ID} app_spotlight && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get update -qq && \
    apt-get install -y build-essential nodejs yarn
RUN yarn && \
    yarn config set no-progress && \     
    yarn config set silent

###
# ruby dependencies image
FROM spotlight-sys-deps AS spotlight-deps
RUN mkdir /app && chown app_spotlight:app_spotlight /app
WORKDIR /app

ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_ENV production

COPY --chown=app_spotlight:app_spotlight . .

USER app_spotlight:app_spotlight

RUN gem update bundler && \
    bundle install -j 2 --retry=3 --deployment --without development test

ENTRYPOINT ["bundle", "exec"]

###
# webserver image
FROM spotlight-deps as spotlight-web
USER app_spotlight:app_spotlight

RUN mkdir /app/tmp/pids
RUN rake assets:precompile

# Image will not start if there is no database, so even in a
#  server deployment where a migrated DB already exists we
#  need to create the default DB for local dev containers.
RUN bundle exec rake db:migrate
EXPOSE 3000
ARG SOURCE_COMMIT
ENV SOURCE_COMMIT $SOURCE_COMMIT
CMD puma -b tcp://0.0.0.0:3000