#!/usr/bin/env bash

BIN_DIR=$(cd `dirname "$0"`; pwd)

exec $BIN_DIR/app.sh start "$@"

