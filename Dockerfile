FROM ruby:3.4.5

ADD . /app
WORKDIR /app
RUN bundle i

EXPOSE 9292

CMD ["/bin/bash"]
