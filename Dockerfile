FROM ruby:3.4
RUN apt-get update && apt-get install -y cmake nodejs npm
WORKDIR /app
COPY Gemfile* package*.json ./
RUN bundle install && npm install
COPY . .
CMD ["bash"]
