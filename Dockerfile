# docker build -t jekyll .
# docker run -it --publish 4000:4000 --name ricalo-com -v f:\code\ricalo.github.io:/usr/src/app jekyll ./bundle_jekyll.sh
FROM ruby:2.3.1
WORKDIR /usr/src/app
ENV LANG=C.UTF-8
