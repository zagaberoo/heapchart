FROM ruby:3.2.1
MAINTAINER "Michael Shick" "mike@shick.xyz"

ENV APP_ENV=production

WORKDIR /heapchart

COPY Gemfile Gemfile.lock .
RUN bundler install

COPY main.rb .


ENTRYPOINT ["ruby", "main.rb"]
