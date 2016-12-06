# docker build -t jekyll .
# docker run -it -e LANG=C.UTF-8 --publish 4000:4000 --name ricalo-com -v f:\code\ricalo.github.io:/usr/src/app jekyll ./bundle_jekyll.sh
FROM ruby:2.3.1
WORKDIR /usr/src/app
