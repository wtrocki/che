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
# See: https://sipb.mit.edu/doc/safe-shell/
set -e
set +o posix

init_global_variables () {
  # For coloring console output
  BLUE='\033[1;34m'
  GREEN='\033[0;32m'
  NC='\033[0m'

  NEW_USAGE="
Usage:
  che [COMMAND]
     start                              Starts server with output in the background
     stop                               Stops ${CHE_MINI_PRODUCT_NAME} server
     run                                Starts server with output in the foreground

Variables:
    CHE_SERVER_ACTION                   Another way to set the [COMMAND] to [run | start | stop]
    CHE_PORT                            The port the Che server will listen on
    CHE_IP                              The IP address of the host - must be set if remote clients connecting
    CHE_LOCAL_CONF_DIR                  If set, will load che.properties from folder
    CHE_BLOCKING_ENTROPY                Starts Tomcat with blocking entropy: -Djava.security.egd=file:/dev/./urandom
    CHE_IN_CONTAINER                    Set to true if this server is running inside of a Docker container
    CHE_LAUNCH_DOCKER_REGISTRY          If true, uses Docker registry to save ws snapshots instead of disk
    CHE_REGISTRY_HOST                   Hostname of Docker registry to launch, otherwise 'localhost'
    CHE_LOG_LEVEL                       [INFO | DEBUG] Sets the output level of Tomcat messages
    CHE_DEBUG_SERVER                    If true, activates Tomcat's JPDA debugging mode
    CHE_SKIP_JAVA_VERSION_CHECK         If true, skips the pre-flight check for a valid JAVA_HOME
    CHE_SKIP_DOCKER_UID_ENFORCEMENT     If true, skips the pre-flight check for current user with UID=1000 for Docker 
    CHE_HOME                            Where the Che assembly resides - self-determining if not set
"

  # Use blocking entropy -- needed for some servers
  DEFAULT_CHE_BLOCKING_ENTROPY=false
  CHE_BLOCKING_ENTROPY=${CHE_BLOCKING_ENTROPY:-${DEFAULT_CHE_BLOCKING_ENTROPY}}

  DEFAULT_CHE_SERVER_ACTION=run
  CHE_SERVER_ACTION=${CHE_SERVER_ACTION:-${DEFAULT_CHE_SERVER_ACTION}}

  DEFAULT_CHE_IN_CONTAINER=false
  CHE_IN_CONTAINER=${CHE_IN_CONTAINER:-${DEFAULT_CHE_IN_CONTAINER}}

  DEFAULT_CHE_LAUNCH_DOCKER_REGISTRY=false
  CHE_LAUNCH_DOCKER_REGISTRY=${CHE_LAUNCH_DOCKER_REGISTRY:-${DEFAULT_CHE_LAUNCH_DOCKER_REGISTRY}}

  # Must be exported as this will be needed by Tomcat's JVM
  DEFAULT_CHE_REGISTRY_HOST=localhost
  export CHE_REGISTRY_HOST=${CHE_REGISTRY_HOST:-${DEFAULT_CHE_REGISTRY_HOST}}

  DEFAULT_CHE_PORT=8080
  CHE_PORT=${CHE_PORT:-${DEFAULT_CHE_PORT}}

  DEFAULT_CHE_IP=
  CHE_IP=${CHE_IP:-${DEFAULT_CHE_IP}}

  DEFAULT_CHE_LOG_LEVEL=INFO
  CHE_LOG_LEVEL=${CHE_LOG_LEVEL:-${DEFAULT_CHE_LOG_LEVEL}}

  DEFAULT_CHE_DEBUG_SERVER=false
  CHE_DEBUG_SERVER=${CHE_DEBUG_SERVER:-${DEFAULT_CHE_DEBUG_SERVER}}

  DEFAULT_CHE_SKIP_JAVA_VERSION_CHECK=false
  CHE_SKIP_JAVA_VERSION_CHECK=${CHE_SKIP_JAVA_VERSION_CHECK:-${DEFAULT_CHE_SKIP_JAVA_VERSION_CHECK}}

  DEFAULT_CHE_SKIP_DOCKER_UID_ENFORCEMENT=false
  CHE_SKIP_DOCKER_UID_ENFORCEMENT=${CHE_SKIP_DOCKER_UID_ENFORCEMENT:-${DEFAULT_CHE_SKIP_DOCKER_UID_ENFORCEMENT}}
  #### TODO: Use docker codenvy/che-ip to determine the right IP?

  # Sets value of operating system
  HOST="linux"
  GLOBAL_HOST_ARCH=$(docker version --format {{.Client}} | cut -d" " -f5)

}

usage () {
  echo "${NEW_USAGE}"
}

error () {
  echo
  echo "!!!"
  echo -e "!!! ${1}"
  echo "!!!"
  return 0
}

parse_command_line () {
  if [ $# -gt 1 ]; then
    error "'--<name>' parameters are deprecated - use CHE_ variables instead."
    usage
    return 1
  fi

  case $1 in
    start|stop|run)
      CHE_SERVER_ACTION=$1
    ;;
    -h|--help)
      usage
      return 1
    ;;
    *)
      # unknown option
      usage
      return 1
    ;;
  esac
}

determine_os () {
  # Set OS.  Mac & Windows require VirtualBox and docker-machine.
  case "${OSTYPE}" in
     linux*|freebsd*)
       HOST="linux" 
     ;;
     darwin*)
       HOST="mac" 
     ;;
     cygwin|msys|win32)
       HOST="windows" 
     ;;
     *)
       # unknown option
       error "We could not detect your operating system. Che is unlikely to work properly."
       return 1
     ;;
  esac
}

set_environment_variables () {
  ### Set value of derived environment variables.
  # The base directory of Che
  if [ -z "${CHE_HOME}" ]; then
    if [ "${HOST}" == "windows" ]; then
      # che-497: Determine windows short directory name in bash
      export CHE_HOME=`(cd "$( dirname "${BASH_SOURCE[0]}" )" && \
                      cmd //C 'FOR %i in (..) do @echo %~Si')`
    else
      export CHE_HOME="$(dirname "$(cd "$(dirname "${0}")" && pwd -P)")"
    fi
  fi

  # CHE_DOCKER_MACHINE_HOST is used internally by Che to set its IP address
  if [[ -n "${CHE_IP}" ]]; then
    export CHE_DOCKER_MACHINE_HOST="${CHE_IP}"
  fi

  #if [ "${WIN}" == "true" ] && [ ! -z "${JAVA_HOME}" ]; then
    # che-497: Determine windows short directory name in bash
    # export JAVA_HOME=`(cygpath -u $(cygpath -w --short-name "${JAVA_HOME}"))`
  #fi

  # Convert Tomcat environment variables to POSIX format.
  if [[ "${JAVA_HOME}" == *":"* ]]; then
    JAVA_HOME=$(echo /"${JAVA_HOME}" | sed  's|\\|/|g' | sed 's|:||g')
  fi

  # Convert Che environment variables to POSIX format.
  if [[ "${CHE_HOME}" == *":"* ]]; then
    CHE_HOME=$(echo /"${CHE_HOME}" | sed  's|\\|/|g' | sed 's|:||g')
  fi

  if [[ "${CHE_HOME}" =~ \ |\' ]] && [[ "${HOST}" == "windows" ]]; then
    echo "!!!"
    echo "!!! Ohhhhh boy."
    echo "!!! You are on Windows and installed Che into a directory that contains a space."
    echo "!!! Tomcat behaves badly because of this."
    echo "!!!"
    echo "!!! We attempted to work around this by converting your path to one without a space."
    echo "!!! However, it seems that the drive where Che is installed does not allow this."
    echo "!!! So we seem to be buggered."
    echo "!!!"
    echo "!!! You can fix this issue by installing Che into a directory without spaces in the name."
    echo "!!! Isn't Windows fun?  Long live William Shatner."
    echo "!!!"
    return 1
  fi

  # Che configuration directory - where che.properties lives
  if [ -z "${CHE_LOCAL_CONF_DIR}" ]; then
    export CHE_LOCAL_CONF_DIR="${CHE_HOME}/conf/"
  fi

  # Sets the location of the application server and its executables
  # Internal property - should generally not be overridden
  export CATALINA_HOME="${CHE_HOME}"/tomcat

  # Convert windows path name to POSIX
  if [[ "${CATALINA_HOME}" == *":"* ]]; then
    CATALINA_HOME=$(echo /"${CATALINA_HOME}" | sed  's|\\|/|g' | sed 's|:||g')
  fi

  # Internal property - should generally not be overridden
  export CATALINA_BASE="${CHE_HOME}"/tomcat
  export ASSEMBLY_BIN_DIR="${CATALINA_HOME}"/bin
  export CHE_LOGS_LEVEL="${CHE_LOG_LEVEL}"
  export CHE_LOGS_DIR="${CATALINA_HOME}/logs/"
}

has_docker() {
  hash docker 2>/dev/null && return 0 || return 1
}

check_docker() {
  if ! has_docker; then
    error "Docker not found. Get it at https://docs.docker.com/engine/installation/."
    return 1;
  fi

  if ! docker ps > /dev/null 2>&1; then
    output=$(docker ps)
    error "Docker not installed properly: \n${output}"
    echo "Check: Does /var/run/docker.sock have r/w permissions?"
    echo "Check: Does your Docker client & version match?"
    DOCKER_PERMS=$(stat -c %A /var/run/docker.sock)
    DOCKER_SERVER_VERSION=$(docker version --format '{{.Server.Version}}') 
    DOCKER_CLIENT_VERSION=$(docker version --format '{{.Client.Version}}')
    echo "Docker /var/run/docker.sock Permissions: $DOCKER_PERMS"
    echo "Docker Server: $DOCKER_SERVER_VERSION"
    echo "Docker Client: $DOCKER_CLIENT_VERSION"
    return 1;
  fi
}

has_docker_for_windows_client(){
  if [ "${GLOBAL_HOST_ARCH}" = "windows" ]; then
    return 0
  else
    return 1
  fi
}

docker_exec() {
  if has_docker_for_windows_client; then
    MSYS_NO_PATHCONV=1 docker.exe "$@"
  else
    "$(which docker)" "$@"
  fi
}

get_docker_ready () {
  # Test to ensure user is in Docker group with appropriate permissions
  if [ "${HOST}" == "linux" ]; then

    LINUX_USER=$(whoami)
    LINUX_GROUPS=$(groups "${LINUX_USER}")
    LINUX_UID=$(id -u "${LINUX_USER}")

    if [[ "${CHE_SKIP_DOCKER_UID_ENFORCEMENT}" == "false" ]] ; then
      if echo "${LINUX_GROUPS}" | grep "docker" &>/dev/null; then
        if [[ "${LINUX_UID}" != "1000" ]] ; then
          error "This Linux user was launched with a UID != 1000. `
                `Che must run under UID 1000. See https://eclipse-che.readme.io/docs/usage#section-cannot-create-projects"
                return 1;
        fi
      else
        error "This Linux user is not in 'docker' group. `
              `See https://docs.docker.com/engine/installation/ubuntulinux/#create-a-docker-group"
      fi
    fi
  fi

  if [ "${HOST}" == "windows" ]; then
    if [ -z ${DOCKER_HOST+x} ]; then
      export DOCKER_HOST=tcp://localhost:2375
    fi
  fi

  # Hidden parameter
  # Only used if this script is starting a Che Tomcat from inside a Docker container.
  # Copies Che ws-agent and terminal to directory mounted by ws containers.
  # The directory has to be on the host, not inside the container.
  # The files are copied from within the container to a folder host-mounted.
  if [ "${CHE_IN_CONTAINER}" == "true" ]; then

    # Make sure the user named "user" is the owner of the CHE_HOME directory.
    sudo chown -R user:user ${CHE_HOME}

    # Move files from /lib to /lib-copy.  This puts files onto the host.
    rm -rf ${CHE_HOME}/lib-copy/*
    mkdir -p ${CHE_HOME}/lib-copy
    cp -rf ${CHE_HOME}/lib/* ${CHE_HOME}/lib-copy

    # A che property, which names the Docker network used for che + ws to communicate
    export JAVA_OPTS="${JAVA_OPTS} -Dche.docker.che_host_network=bridge"
  fi 
}

call_catalina () {
  # Test to see that Che application server is where we expect it to be
  if [ ! -d "${ASSEMBLY_BIN_DIR}" ]; then
    error "Could not find Che's application server."
    return 1;
  fi

  if [ -z "${JAVA_HOME}" ]; then
    error "JAVA_HOME is not set. Please set to directory of JVM or JRE."
    return 1;
  fi

  # Test to see that Java is installed and working
  "${JAVA_HOME}"/bin/java &>/dev/null || JAVA_EXIT=$? || true
  if [ "${JAVA_EXIT}" != "1" ]; then
    error "We could not find a working Java JVM. 'java' command fails."
    return 1;
  fi

  if [[ "${CHE_SKIP_JAVA_VERSION_CHECK}" == false ]]; then
    # Che requires Java version 1.8 or higher.
    JAVA_VERSION=$("${JAVA_HOME}"/bin/java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    if [  -z "${JAVA_VERSION}" ]; then
      error "Failure running JAVA_HOME/bin/java -version. We received ${JAVA_VERSION}."
      return 1;
    fi

    if [[ "${JAVA_VERSION}" < "1.8" ]]; then
      error "Che requires Java version 1.8 or higher. We found ${JAVA_VERSION}."
      return 1;
    fi
  fi

  ### Initialize default JVM arguments to run che
  if [[ "${CHE_BLOCKING_ENTROPY}" == true ]]; then
    [ -z "${JAVA_OPTS}" ] && JAVA_OPTS="-Xms256m -Xmx1024m"
  else
    [ -z "${JAVA_OPTS}" ] && JAVA_OPTS="-Xms256m -Xmx1024m -Djava.security.egd=file:/dev/./urandom"
  fi

  ### Cannot add this in setenv.sh.
  ### We do the port mapping here, and this gets inserted into server.xml when tomcat boots
  export JAVA_OPTS="${JAVA_OPTS} -Dport.http=${CHE_PORT} -Dche.home=${CHE_HOME}"
  export SERVER_PORT=${CHE_PORT}

  # Launch the Che application server, passing in command line parameters
  if [[ "${CHE_DEBUG_SERVER}" == true ]]; then
    "${ASSEMBLY_BIN_DIR}"/catalina.sh jpda ${CHE_SERVER_ACTION}
  else
    "${ASSEMBLY_BIN_DIR}"/catalina.sh ${CHE_SERVER_ACTION}
  fi
}

stop_che_server () {
  echo -e "Stopping Che server running on localhost:${CHE_PORT}"
  call_catalina >/dev/null 2>&1
  return 1;
}

kill_and_launch_docker_registry () {
  echo -e "Launching Docker container named ${GREEN}registry${NC} from image ${GREEN}registry:2${NC}."
  docker_exec rm -f registry &> /dev/null || true
  docker_exec run -d -p 5000:5000 --restart=always --name registry registry:2
}

launch_docker_registry () {
    echo "Launching a Docker registry for workspace snapshots."
    CREATE_NEW_CONTAINER=false

    # Check to see if the registry docker was not properly shut down
    docker_exec inspect registry &> /dev/null || DOCKER_INSPECT_EXIT=$? || true
    if [ "${DOCKER_INSPECT_EXIT}" != "1" ]; then

      # Existing container running registry is found.  Let's start it.
      echo -e "Found a registry container named ${GREEN}registry${NC}. Attempting restart."
      docker_exec start registry &>/dev/null || DOCKER_EXIT=$? || true

      # Existing container found, but could not start it properly.
      if [ "${DOCKER_EXIT}" == "1" ]; then
        echo "Initial start of registry docker container failed... Attempting docker restart and exec."
        CREATE_NEW_CONTAINER=true
      fi

    echo "Successful restart of registry container."
    echo

    # No existing Che container found, we need to create a new one.
    else
      CREATE_NEW_CONTAINER=true
    fi

    if ${CREATE_NEW_CONTAINER} ; then
      # Container in bad state or not found, kill and launch new container.
      kill_and_launch_docker_registry
    fi
}

start_che_server () {
  if ${CHE_LAUNCH_DOCKER_REGISTRY} ; then
    # Export the value of host here
    launch_docker_registry
  fi

  #########################################
  # Launch Che natively as a tomcat server
  call_catalina
}

execute_che () { 
  check_docker
  init_global_variables
  parse_command_line "$@"
  determine_os
  set_environment_variables
  get_docker_ready

  if [ "${CHE_SERVER_ACTION}" == "stop" ]; then
    stop_che_server
  else
    start_che_server
  fi
}

# Run the finish function if exit signal initiated
trap "CHE_SERVER_ACTION=stop; execute_che;" SIGHUP SIGINT SIGTERM

execute_che "$@"
