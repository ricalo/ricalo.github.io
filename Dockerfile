# docker build -t ricalo-com .
# docker run -it --rm -e LANG=C.UTF-8 --name "ricalo-com" --publish 4000:4000 ricalo-com jekyll serve --config _config.yml,_config_dev.yml --host 0.0.0.0
FROM ruby:2.3.1
WORKDIR /usr/src/app
RUN ["gem", "install", "bundler"]

