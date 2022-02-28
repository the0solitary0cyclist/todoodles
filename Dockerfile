# FROM cypress/included:4.4.0
FROM lcxat/cypress-ruby
RUN mkdir ./app
COPY app.rb ./app
# COPY . .
# COPY . /e2e
# WORKDIR /e2e
