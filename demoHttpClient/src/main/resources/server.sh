#!/bin/sh
#
# Start/Stop the ${SERVER_NAME} server.
#



SERVER_PID_DIR="./logs"
SERVER_LOG="${SERVER_PID_DIR}/server.out"
SERVER_PID="./server.pid"
SERVER_NAME="HttpClientApp"
CLASSPATH="conf/"  
MAIN_CLASS="com.example.http.HttpClientApp"
for jarfile in `ls lib/.`; do  
   CLASSPATH="${CLASSPATH}:lib/$jarfile"  
done  

if [ ! -d "${SERVER_PID_DIR}" ]; then
mkdir "${SERVER_PID_DIR}"
fi 

if [ ! -f "${SERVER_LOG}" ]; then
touch "${SERVER_LOG}"
fi 
 
loadJavaOpts () {
  server_java_opts=`grep '^[ \t]*server\.java\.opts' ./conf/server.conf | sed 's/[ \t]*server\.java\.opts=//'`
  if [ -z "${server_java_opts}" ]; then
  echo "-XX:MaxPermSize=192m -Xmx512m -Xms512m"
  fi
  echo "${server_java_opts}"
}

waitForPid () {
  MTRPID=${1}
  MAXTRIES=${2}

  TRIES=0
  echo "waitForPid: waiting for ${MTRPID}"
  while [ 1 -eq 1 ]; do
    PIDCHECK=`kill -0 ${MTRPID} 2> /dev/null`
    if [ $? -eq 1 ]; then
      echo "MT-Receiver server PID ${MTRPID} exited"
      return 1
    fi
 	echo "waitForPid: PID ${MTRPID} still alive" 
    sleep 2
    TRIES=`expr ${TRIES} + 1`
    if [ ${TRIES} -ge ${MAXTRIES} ] ; then
       echo "num TRIES exhausted: ${TRIES} -ge ${MAXTRIES}"
       break
    fi
  done

  echo "${SERVER_NAME} server PID ${MTRPID} did not exit."
  return 0;
}

doStop () {
  doStopSignal "TERM"
}

doStopSignal () {

  SIGNAME=${1}
  if [ "x${SIGNAME}" = "x" ] ; then
    echo "No signal specified"
    exit 127
  fi

  echo "checking pidfile exists: ${SERVER_PID}"
  if [ -f "${SERVER_PID}" ] ; then
    MTRPID=`cat ${SERVER_PID} | tr -d ' '`
    if [ "x${MTRPID}" = "x" ] ; then
      echo "${SERVER_NAME} pid file was empty: ${SERVER_PID}"
      exit 127
    fi
    kill -${SIGNAME} ${MTRPID} 2> /dev/null
    
    waitForPid ${MTRPID} 60
    if [ $? -eq 0 ] ; then
      exit 1
    fi
    rm -f ${SERVER_PID}
  else 
    echo "${SERVER_NAME} server not running (no pid file found: ${SERVER_PID})"
  fi
}

doStart () {
# Is the server already running?
echo "checking pidfile exists: ${SERVER_PID}"
if [ -f "${SERVER_PID}" ] ; then
  MTRPID=`cat ${SERVER_PID} | tr -d ' '`
  if [ ! "x${MTRPID}" = "x" ] ; then
    PIDCHECK=`kill -0 ${MTRPID} 2> /dev/null`
    if [ $? -eq 1 ]; then
      echo "Removing stale pid file ${SERVER_PID}"
      rm -f ${SERVER_PID}
    else 
      echo "${SERVER_NAME} server is already running (pid ${MTRPID})."
      exit 0
    fi
  fi
fi

# Setup JAVA_OPTS from server.conf
JAVA_OPTS=`loadJavaOpts`

# Start the server
echo "Booting the ${SERVER_NAME} server (Using JAVA_OPTS=${JAVA_OPTS})..."

java ${JAVA_OPTS} -cp ${CLASSPATH} ${MAIN_CLASS} > ${SERVER_LOG} 2>&1 &

  # Save the pid to a pidfile
  MTRPID=$!
  echo "${MTRPID}" > ${SERVER_PID}
}

case "$1" in
  start)
    echo "Starting ${SERVER_NAME} server..."
    doStart
    echo "${SERVER_NAME} server booted."
    ;;
  stop)
    echo "Stopping ${SERVER_NAME} server..."
    doStop
    echo "${SERVER_NAME} server is stopped."
    ;;
  restart)
	doStop
	doStart
	;;
  *)
    # Print help, don't advertise halt, it's nasty
    echo "Usage: $0 {start|stop|restart}" 1>&2
    exit 1
    ;;
esac

exit 0