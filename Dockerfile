FROM ruby:3.2.1
MAINTAINER "Michael Shick" "mike@shick.xyz"

ENV APP_ENV=production

RUN mkdir /heapchart
WORKDIR /heapchart

COPY Gemfile Gemfile.lock /heapchart/
RUN bundler install

COPY . /heapchart/

ENTRYPOINT ["ruby", "main.rb"]
