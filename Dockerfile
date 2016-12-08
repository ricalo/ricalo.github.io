# docker build -t jekyll .
# docker run -it -e "JEKYLL_GITHUB_TOKEN=" --publish 4000:4000 --name ricalo-com -v f:\code\ricalo.github.io:/usr/src/app jekyll
FROM ruby:2.3.1
WORKDIR /usr/src/app
ENV LANG C.UTF-8
CMD set -x && bundle install && jekyll serve --config _config.yml,_config_dev.yml --force_polling

