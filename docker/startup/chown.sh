#!/bin/bash

# check ownership on /home/app/myapp
APP_UID=`stat --format '%u' /home/app/myapp`
APP_GID=`stat --format '%g' /home/app/myapp`

echo "Setting app user uid/gid to $APP_UID/$APP_GID"
groupmod -g $APP_GID app
usermod -u $APP_UID -g $APP_GID app

echo "chowning lib, node_modules directories (created from volumes)"
cd /home/app/myapp && mkdir -p lib node_modules && chown app: lib node_modules
