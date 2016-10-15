#!/bin/bash
#
# Copyright (c) 2012-2016 Codenvy, S.A.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Codenvy, S.A. - initial API and implementation
#
pid=0

check_docker() {
  if [ ! -S /var/run/docker.sock ]; then
    echo "Docker socket (/var/run/docker.sock) hasn't been mounted. Verify your \"docker run\" syntax."
    return 1;
  fi

  if ! docker ps > /dev/null 2>&1; then
    output=$(docker ps)
    error_exit "Error when running \"docker ps\": ${output}"
  fi
}

init() {
  # Set variables that use docker as utilities to avoid over container execution
  ETH0_ADDRESS=$(docker run --rm --net host alpine /bin/sh -c "ifconfig eth0 2> /dev/null" | \
                                                            grep "inet addr:" | \
                                                            cut -d: -f2 | \
                                                            cut -d" " -f1)

  ETH1_ADDRESS=$(docker run --rm --net host alpine /bin/sh -c "ifconfig eth1 2> /dev/null" | \
                                                            grep "inet addr:" | \
                                                            cut -d: -f2 | \
                                                            cut -d" " -f1) 

  DOCKER0_ADDRESS=$(docker run --rm --net host alpine /bin/sh -c "ifconfig docker0 2> /dev/null" | \
                                                              grep "inet addr:" | \
                                                              cut -d: -f2 | \
                                                              cut -d" " -f1)

  DEFAULT_DOCKER_HOST_IP=$(get_docker_host_ip)
  export CHE_IP=${CHE_IP:-${DEFAULT_DOCKER_HOST_IP}}
  export CHE_IN_CONTAINER="true"
  export CHE_SKIP_JAVA_VERSION_CHECK="true"
  export CHE_SKIP_DOCKER_UID_ENFORCEMENT="true"
 
  HOSTNAME=$(get_docker_external_hostname)
  if has_external_hostname; then
    # Internal property used by Che to set hostname.
    # See: LocalDockerInstanceRuntimeInfo.java#L9
    export CHE_DOCKER_MACHINE_HOST_EXTERNAL=${HOSTNAME}
  fi

  DEFAULT_CHE_HOME="/home/user/che"
  CHE_HOME=${CHE_LOCAL_BINARY:-${DEFAULT_CHE_HOME}}

  if [ ! -f $CHE_HOME/bin/che.sh ]; then
    echo "!!!"
    echo "!!! Error: Could not find $CHE_HOME/bin/che.sh."
    echo "!!! Error: Did you use CHE_LOCAL_BINARY with a typo?"
    echo "!!!"
    exit 1
  fi

  DEFAULT_CHE_CONF_DIR="${CHE_HOME}/conf"
  CHE_LOCAL_CONF_DIR=${CHE_LOCAL_CONF_DIR:-${DEFAULT_CHE_CONF_DIR}}

  if [ ! -f $CHE_LOCAL_CONF_DIR/che.properties ]; then
    echo "!!!"
    echo "!!! Error: Could not find $CHE_LOCAL_CONF_DIR/che.properties."
    echo "!!! Error: Did you use CHE_LOCAL_CONF_DIR with a typo?"
    echo "!!!"
    exit 1
  fi
}

get_docker_host_ip() {
  case $(get_docker_install_type) in
   boot2docker)
     echo $ETH1_ADDRESS
   ;;
   native)
     echo $DOCKER0_ADDRESS
   ;;
   *)
     echo $ETH0_ADDRESS
   ;;
  esac
}

get_docker_install_type() {
  if is_boot2docker; then
    echo "boot2docker"
  elif is_docker_for_windows; then
    echo "docker4windows"
  elif is_docker_for_mac; then
    echo "docker4mac"
  else
    echo "native"
  fi
}

is_boot2docker() {
  if uname -r | grep -q 'boot2docker'; then
    return 0
  else
    return 1
  fi
}

is_docker_for_windows() {
  if uname -r | grep -q 'moby' && has_docker_for_windows_ip; then
    return 0
  else
    return 1
  fi
}

has_docker_for_windows_ip() {
  if [ "${ETH0_ADDRESS}" = "10.0.75.2" ]; then
    return 0
  else
    return 1
  fi
}

is_docker_for_mac() {
  if uname -r | grep -q 'moby' && ! has_docker_for_windows_ip; then
    return 0
  else
    return 1
  fi
}

get_docker_external_hostname() {
  if is_docker_for_mac || is_docker_for_windows; then
    echo "localhost"
  else
    echo ""
  fi
}

has_external_hostname() {
  if [ "${HOSTNAME}" = "" ]; then
    return 1
  else
    return 0
  fi
}

# SIGUSR1-handler
responsible_shutdown() {
  "${CHE_HOME}"/bin/che.sh stop
}

# setup handlers
# on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
trap 'responsible_shutdown' SIGHUP SIGTERM SIGINT

check_docker
init

# run application
"${CHE_HOME}"/bin/che.sh run &
PID=$!

# See: http://veithen.github.io/2014/11/16/sigterm-propagation.html
wait $PID
wait $PID
EXIT_STATUS=$?

# wait forever
while true
do
  tail -f /dev/null & wait ${!}
done
