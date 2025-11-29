FROM ruby:3.4
RUN apt-get update && apt-get install -y cmake nodejs npm
WORKDIR /app
COPY Gemfile Gemfile.lock package.json package-lock.json ./
RUN bundle install && npm install
COPY . .
CMD ["bash"]
