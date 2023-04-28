# FROM ruby:3.1.3-slim

# RUN apt-get update -qq \
#   && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends build-essential git-core

# ENV APP_HOME /app
# RUN mkdir $APP_HOME
# WORKDIR $APP_HOME

# COPY Gemfile* ./

# RUN gem install bundler \
#   && bundle install -j "$(getconf _NPROCESSORS_ONLN)"

# COPY . $APP_HOME

# CMD ["bundle", "exec", "ruby", "app.rb"]


FROM scratch
COPY velero-notifications /
RUN chmod +x /velero-notifications
CMD ["/velero-notifications"]
