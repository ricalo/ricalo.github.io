#!/bin/bash
set -x
bundle install
JEKYLL_GITHUB_TOKEN=9cd2ae43355fcdcfe58994cad27c4c188296af7d jekyll serve --config _config.yml,_config_dev.yml --host 0.0.0.0 --force_polling

