FROM ruby:3.2.2

ADD . /app
WORKDIR /app
RUN bundle i

EXPOSE 9292

CMD ["/bin/bash"]
