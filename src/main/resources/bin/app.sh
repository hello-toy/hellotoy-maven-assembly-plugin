#!/usr/bin/env bash

BASE_DIR=$(cd `dirname "$0"`/..; pwd)
BIN_DIR=$BASE_DIR/bin
LIB_DIR=$BASE_DIR/lib
CONF_DIR=$BASE_DIR/conf
LOG_DIR=$BASE_DIR/logs
MAIN_JAR=$LIB_DIR/${project.artifactId}-${project.version}.jar
NOHUP_FILE=$LOG_DIR/application.out

JAVA_OPT=""

for key in "$@"
do
   if [ $key == $1 ] ; then
      echo "first arg"
       continue
   fi
   JAVA_OPT=$JAVA_OPT" "$key
done

if [ -n "$JAVA_HOME" ]; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="`which java`"
fi

if [ ! -x "$JAVACMD" ] ; then
    echo "Error: JAVA_HOME is not defined correctly." 1>&2
    echo "  We cannot execute java cmd." 1>&2
    exit 1
fi


if [ "$1" = "debug" ]; then
    DEBUG_PORT=${debug.port}
    DEBUG_OPTS=-agentlib:jdwp=transport=dt_socket,address=$DEBUG_PORT,suspend=y,server=y
    mkdir -p $LOG_DIR
    echo Debugging application ${project.artifactId}-${project.version}...
    nohup "$JAVACMD"  $DEBUG_OPTS -Dapp.name="${project.artifactId}" -Dapp.version="${project.version}" -Dapp.home="$BASE_DIR" -Dapp.lib="$LIB_DIR" -Dapp.conf="$CONF_DIR" -jar "$MAIN_JAR" >> "$NOHUP_FILE" 2>&1 &
elif [ "$1" = "start" ]; then
    mkdir -p $LOG_DIR
    echo Starting application ${project.artifactId}-${project.version}...
    nohup "$JAVACMD"  $JAVA_OPT -Dapp.name="${project.artifactId}" -Dapp.version="${project.version}" -Dapp.home="$BASE_DIR" -Dapp.lib="$LIB_DIR" -Dapp.conf="$CONF_DIR" -jar "$MAIN_JAR" >> "$NOHUP_FILE" 2>&1 &
elif [ "$1" = "stop" ]; then
    APP_PID=$(jps|grep '${project.artifactId}-${project.version}.jar'|awk '{print $1}')
    
    if [ "$APP_PID" = "" ]; then
        echo No startup application ${project.artifactId}-${project.version}.
        exit 0
    else
        echo Stopping application ${project.artifactId}-${project.version}...
        kill $APP_PID &
    fi
    
    for ((i = 0; i < 10; i++)); do
        sleep 1
        APP_PID=$(jps|grep '${project.artifactId}-${project.version}.jar'|awk '{print $1}')
        if [ "$APP_PID" = "" ]; then
            echo Stopped application ${project.artifactId}-${project.version} success.
            exit 0
        fi
    done
    
    kill -9 $APP_PID
    echo Killed application ${project.artifactId}-${project.version}.
    
elif [ "$1" = "version" ]; then
    echo ${project.artifactId}-${project.version}
else
    echo "Usage: app \<command\>"
    echo "command:"
    echo "  debug        Start application"
    echo "  start        Start application"
    echo "  stop         Stop application"
    echo "  version      Show application version"
    exit 1
fi
tail -100f $NOHUP_FILE
