FROM ruby:3.3.1

ADD . /app
WORKDIR /app
RUN bundle i

EXPOSE 9292

CMD ["/bin/bash"]
