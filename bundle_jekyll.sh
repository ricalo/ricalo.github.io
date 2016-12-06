#!/bin/bash
set -x
bundle install
jekyll serve --config _config.yml,_config_dev.yml --host 0.0.0.0

