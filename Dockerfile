FROM ruby:4.0.1

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy Gemfile first for better layer caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

EXPOSE 9292

CMD ["/bin/bash"]
