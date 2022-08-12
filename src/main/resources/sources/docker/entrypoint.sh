#!/bin/bash

trap " trap_wait " 3 15

DEBUG=${ENTRYPOINT_DEBUG}
DEBUG_APP=${DEBUG_APP}
APP_DEF=$2

export CLOUD_NODE_ID=$(basename "$(cat /proc/1/cpuset)")

if [ "$CLOUD_NODE_ID"x = x ]
then
   export CLOUD_NODE_ID=$(date +%y%m%d%H%M%S)
fi

export CLOUD_NODE_ID_TRUNC=${CLOUD_NODE_ID:0:12}

# reset umask to -rw-rw-rw- / drwxrwxrwx
#umask 000

# reset umask to -rw-r--r-- / drwxr-xr-x
umask 022

if [ ! -f /tmp/entrypoint_init_flag ]
then
  echo "export CLOUD_NODE_ID=$CLOUD_NODE_ID" >> ~/.bash_profile 2>/dev/null
  echo "export CLOUD_NODE_ID=$CLOUD_NODE_ID" >> ~/.bashrc 2>/dev/null
  echo "export CLOUD_NODE_ID_TRUNC=$CLOUD_NODE_ID_TRUNC" >> ~/.bash_profile 2>/dev/null
  echo "export CLOUD_NODE_ID_TRUNC=$CLOUD_NODE_ID_TRUNC" >> ~/.bashrc 2>/dev/null
  touch /tmp/entrypoint_init_flag
fi

if [ "$APP_DEF"x = x ]
then
    APP_DEF=app.def
fi

source ${APP_DEF}

if [ "${PAAS_ENV_TYPE}"x = "dev"x -o "${PAAS_ENV_TYPE}"x = "test"x -o "${PAAS_ENV_TYPE}"x = "testbed"x ]
then
    export JAVA_OPTS="${JAVA_OPTS_TEST} ${JAVA_OPTS}"
else
    export JAVA_OPTS="${JAVA_OPTS_PROD} ${JAVA_OPTS}"
fi

print_banner(){
    printf "# Run 'docker run xxx help\' for help information\n\n"
}

print_help(){
    printf "\nUsage: $0 command [application define file]\n"
    printf "\n\n"
    printf "Command list:\n"
    printf "\thelp\t\tPrint help for information\n"
    printf "\tbash\t\tEnter bash for command line\n"
    printf "\tstart\t\tStart the application\n"
    printf "\tstop\t\tStop the application\n"
    printf "\trestart\t\tRestart the application\n"
    printf "\tstatus\t\tReturn the application status\n"
    printf "\tliveness\tReturn liveness of the application\n"
    printf "\treadiness\tReturn readiness of the application\n"
    printf "\tdebug\t\tDebug the application\n"
    printf "\n\n"
    printf "Default application define file name: docker-app.def\n"
    printf "\n\n"
    print_banner
}

print_console()
{
    printf "[$(date +'%Y-%m-%d %H:%M:%S')][$1]->$2\n"
}

print_debug(){
    if [ ${DEBUG} ]
    then
        print_console "DEBUG" "$1"
    fi
}

print_log(){
    print_console "WARN" "$1"
}

watch_loop(){
    LOOP_SECS=5
    RETRY_SEC=3
    MAX_ERR=4
    ERR_CNT=0
    sleep 10
    print_debug "enter watch loop"
    while [ true ]
    do
        if $(main status)
        then
           ERR_CNT=0
           sleep $LOOP_SECS
        else
           sleep $RETRY_SEC
         fi
    done
}

trap_wait(){
    print_log "graceful_stop_waiting"
    GRACEFUL_LOOP_SECS=1;
    while [ true ]
    do
        if $(main graceful_status)
        then
          sleep 1;
          print_log "stopping, waiting for $GRACEFUL_LOOP_SECS s"
          GRACEFUL_LOOP_SECS=$[$GRACEFUL_LOOP_SECS+1]
        else
          break;
        fi
    done
    exit
}

query_pid(){
    PID=$(ps -ef | grep "$1" | grep -v grep | awk '{print $2}' | tr "\n" " ")
    echo $PID
}

proc_check(){
    PID=$(query_pid "$1")
    print_debug "query process:[$1], pid:[$PID]"
    if [ "$PID"x = ""x ]
    then
        return 1
    else
        return 0
    fi
}

run_app(){
    # use exec and gosu to trap unix signal
    # exec gosu user "$@" &
    exec $1 &
    print_log "app [$1] started, pid:[$!]"
    return $?
}

stop_app(){
    PID=$(query_pid "$1")
    print_log "kill app [$1], pid:[$PID]"
    kill $PID
    return $?
}

main(){
    case $1 in
        run)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval START_CMD=\${${APPNODE}[0]}
                run_app "$START_CMD"
                RET_CODE=$[$RET_CODE | $?]
            done
            return $RET_CODE
        ;;

        stop)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval PROCESS_KEY=\${${APPNODE}[1]}
                stop_app "$PROCESS_KEY"
                RET_CODE=$[$RET_CODE | $?]
            done
            return $RET_CODE
        ;;

        status)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval PROCESS_KEY=\${${APPNODE}[1]}
                proc_check "$PROCESS_KEY"
                RET_CODE=$[$RET_CODE | $?]
            done
            if [ ${DEBUG_APP} ]
              then
              RET_CODE=0
            fi
            return $RET_CODE
        ;;

        graceful_status)
            RET_CODE=1
            for APPNODE in ${APP[@]}
            do
                eval PROCESS_KEY=\${${APPNODE}[1]}
                proc_check "$PROCESS_KEY"
                RET_CODE=$[$RET_CODE & $?]
            done
            return $RET_CODE
        ;;

        start)
            main run
            watch_loop
        ;;

        restart)
            main stop
            main run
        ;;

        liveness)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval VERIFY_SCRIPT=\${${APPNODE}[2]}
                eval VERIFY_NORMAL=\${${APPNODE}[3]}
                if [ ! "$VERIFY_SCRIPT"x = x -a ! "$VERIFY_NORMAL"x = x ]
                then
                   resp_code=$(eval $VERIFY_SCRIPT)
                   print_debug "liveness app: [$APPNODE] response_code:[$resp_code]"
                   if [ "$resp_code"x = "$VERIFY_NORMAL"x ]
                   then
                       RET_CODE=$[$RET_CODE | 0 ]
                   else
                       RET_CODE=$[$RET_CODE | 1 ]
                   fi
                fi
            done
            if [ ${DEBUG_APP} ]
            then
              RET_CODE=0
            fi
            if [ ${RET_CODE} != 0 ]
            then
               if $(apm_loading)
               then
                   RET_CODE=0
               fi
            fi
            return ${RET_CODE}
        ;;

        readiness)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval VERIFY_SCRIPT=\${${APPNODE}[4]}
                eval VERIFY_NORMAL=\${${APPNODE}[5]}
                if [ ! "$VERIFY_SCRIPT"x = x -a ! "$VERIFY_NORMAL"x = x ]
                then
                   resp_code=$(eval $VERIFY_SCRIPT)
                   print_debug "readiness app: [$APPNODE] response_code:[$resp_code]"
                   if [ "$resp_code"x = "$VERIFY_NORMAL"x ]
                   then
                       RET_CODE=$[$RET_CODE | 0 ]
                   else
                       RET_CODE=$[$RET_CODE | 1 ]
                   fi
                fi
            done
            if [ ${DEBUG_APP} ]
              then
              RET_CODE=0
            fi
            return $RET_CODE
        ;;

        refresh)
            RET_CODE=0
            for APPNODE in ${APP[@]}
            do
                eval REFRESH_SCRIPT=\${${APPNODE}[6]}
                eval REFRESH_NORMAL=\${${APPNODE}[7]}
                if [ ! "$REFRESH_SCRIPT"x = x -a ! "$REFRESH_NORMAL"x = x ]
                then
                   resp_code=$($REFRESH_SCRIPT)
                   print_debug "refresh app: [$APPNODE] response_code:[$resp_code]"
                   if [ "$resp_code"x = "$REFRESH_NORMAL"x ]
                   then
                       RET_CODE=$[$RET_CODE | 0 ]
                   else
                       RET_CODE=$[$RET_CODE | 1 ]
                   fi
                fi
            done
            return $RET_CODE
        ;;

        debug)
            DEBUG=true
            main run
            print_debug "run:[$?]"
            main status
            print_debug "status:[$?]"
            main liveness
            print_debug "liveness check:[$?]"
            main readiness
            print_debug "readiness check:[$?]"
            main stop
            print_debug "stop:[$?]"
            main status
            print_debug "status:[$?]"
            main liveness
            print_debug "liveness check:[$?]"
            main readiness
            print_debug "readiness check:[$?]"

        ;;

        help | h | -h)
            print_help
        ;;

        *)
           print_banner
           print_log "default: exec $@"
           exec "$@"
        ;;
    esac
}

main $@