#!/usr/bin/env bash
#
#/**
# * Copyright 2007 The Apache Software Foundation
# *
# * Licensed to the Apache Software Foundation (ASF) under one
# * or more contributor license agreements.  See the NOTICE file
# * distributed with this work for additional information
# * regarding copyright ownership.  The ASF licenses this file
# * to you under the Apache License, Version 2.0 (the
# * "License"); you may not use this file except in compliance
# * with the License.  You may obtain a copy of the License at
# *
# *     http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */
# 
# Runs a Hadoop hbase command as a daemon.
#
# Environment Variables
#
#   HADOOP_CONF_DIR  Alternate conf dir. Default is ${HADOOP_HOME}/conf.
#   HBASE_CONF_DIR  Alternate hbase conf dir. Default is ${HBASE_HOME}/conf.
#   HADOOP_LOG_DIR   Where log files are stored.  PWD by default.
#   HADOOP_PID_DIR   The pid files are stored. /tmp by default.
#   HADOOP_IDENT_STRING   A string representing this instance of hadoop. $USER by default
#   HADOOP_NICENESS The scheduling priority for daemons. Defaults to 0.
#
# Modelled after $HADOOP_HOME/bin/hadoop-daemon.sh

usage="Usage: hbase-daemon.sh [--config <hadoop-conf-dir>]\
 [--hbaseconfig <hbase-conf-dir>] (start|stop) <hbase-command> \
 <args...>"

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/hbase-config.sh

# get arguments
startStop=$1
shift

command=$1
shift

hbase_rotate_log ()
{
    log=$1;
    num=5;
    if [ -n "$2" ]; then
    num=$2
    fi
    if [ -f "$log" ]; then # rotate logs
    while [ $num -gt 1 ]; do
        prev=`expr $num - 1`
        [ -f "$log.$prev" ] && mv "$log.$prev" "$log.$num"
        num=$prev
    done
    mv "$log" "$log.$num";
    fi
}

if [ -f "${HADOOP_CONF_DIR}/hadoop-env.sh" ]; then
  . "${HADOOP_CONF_DIR}/hadoop-env.sh"
fi
if [ -f "${HBASE_CONF_DIR}/hbase-env.sh" ]; then
  . "${HBASE_CONF_DIR}/hbase-env.sh"
fi

# get log directory
if [ "$HADOOP_LOG_DIR" = "" ]; then
  export HADOOP_LOG_DIR="$HADOOP_HOME/logs"
fi
mkdir -p "$HADOOP_LOG_DIR"

if [ "$HADOOP_PID_DIR" = "" ]; then
  HADOOP_PID_DIR=/tmp
fi

if [ "$HADOOP_IDENT_STRING" = "" ]; then
  export HADOOP_IDENT_STRING="$USER"
fi

# some variables
export HADOOP_LOGFILE=hbase-$HADOOP_IDENT_STRING-$command-$HOSTNAME.log
export HADOOP_ROOT_LOGGER="INFO,DRFA"
log=$HADOOP_LOG_DIR/hbase-$HADOOP_IDENT_STRING-$command-$HOSTNAME.out  
pid=$HADOOP_PID_DIR/hbase-$HADOOP_IDENT_STRING-$command.pid

# Set default scheduling priority
if [ "$HADOOP_NICENESS" = "" ]; then
    export HADOOP_NICENESS=0
fi

case $startStop in

  (start)
    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $command running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi

    hbase_rotate_log $log
    echo starting $command, logging to $log
    nohup nice -n $HADOOP_NICENESS "$HBASE_HOME"/bin/hbase \
        --hadoop "${HADOOP_HOME}" \
        --config "${HADOOP_CONF_DIR}" --hbaseconfig "${HBASE_CONF_DIR}" \
        $command $startStop "$@" > "$log" 2>&1 < /dev/null &
    echo $! > $pid
    sleep 1; head "$log"
    ;;

  (stop)
    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo -n stopping $command
        if [ "$command" = "master" ]; then
          nohup nice -n $HADOOP_NICENESS "$HBASE_HOME"/bin/hbase \
              --hadoop "${HADOOP_HOME}" \
              --config "${HADOOP_CONF_DIR}" --hbaseconfig "${HBASE_CONF_DIR}" \
              $command $startStop "$@" > "$log" 2>&1 < /dev/null &
        else
          kill `cat $pid` > /dev/null 2>&1
        fi
        while kill -0 `cat $pid` > /dev/null 2>&1; do
          echo -n "."
          sleep 1;
        done
        echo
      else
        echo no $command to stop
      fi
    else
      echo no $command to stop
    fi
    ;;

  (*)
    echo $usage
    exit 1
    ;;

esac
