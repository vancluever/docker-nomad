#!/usr/bin/dumb-init /bin/sh
set -e

# Note above that we run dumb-init as PID 1 in order to reap zombie processes
# as well as forward signals to all processes in its session. Normally, sh
# wouldn't do either of these functions so we'd leak zombies as well as do
# unclean termination of all our sub-processes.

# You can set NOMAD_BIND_INTERFACE to the name of the interface you'd like to
# bind to and this will look up the IP and pass the proper -bind= option along
# to Nomad.
NOMAD_BIND=
if [ -n "$NOMAD_BIND_INTERFACE" ]; then
  NOMAD_BIND_ADDRESS=$(ip -o -4 addr list $NOMAD_BIND_INTERFACE | head -n1 | awk '{print $4}' | cut -d/ -f1)
  if [ -z "$NOMAD_BIND_ADDRESS" ]; then
    echo "Could not find IP for interface '$NOMAD_BIND_INTERFACE', exiting"
    exit 1
  fi

  NOMAD_BIND="-bind=$NOMAD_BIND_ADDRESS"
  echo "==> Found address '$NOMAD_BIND_ADDRESS' for interface '$NOMAD_BIND_INTERFACE', setting bind option..."
fi

# NOMAD_DATA_DIR is exposed as a volume for possible persistent storage. The
# NOMAD_CONFIG_DIR isn't exposed as a volume but you can compose additional
# config files in there if you use this image as a base, or use NOMAD_LOCAL_CONFIG
# below.
NOMAD_DATA_DIR=/nomad/data
NOMAD_CONFIG_DIR=/nomad/config

# You can also set the NOMAD_LOCAL_CONFIG environemnt variable to pass some
# Nomad configuration JSON without having to bind any volumes.
if [ -n "$NOMAD_LOCAL_CONFIG" ]; then
	echo "$NOMAD_LOCAL_CONFIG" > "$NOMAD_CONFIG_DIR/local.json"
fi

# DOCKER_GID, if set, will create a "docker" group with the GID passed in to
# the environment variable. This is to facilitate permission to any bind
# mounted docker socket.
# 
# Note that this will conflict if an image is built off of this one with Docker
# in it - if the group already exists, this will fail.
if [ -n "$DOCKER_GID" ]; then
  if [ "$(getent group docker > /dev/null; echo $?)" -eq "0" ]; then
    echo "DOCKER_GID supplied and docker group already exists"
    exit 1
  fi
  echo "==> Creating Docker group as gid $DOCKER_GID <=="
  echo "docker:x:${DOCKER_GID}:nomad" >> /etc/group
fi

# If the user is trying to run Nomad directly with some arguments, then
# pass them to Nomad.
if [ "${1:0:1}" = '-' ]; then
    set -- nomad "$@"
fi

# Look for Nomad subcommands.
if [ "$1" = 'agent' ]; then
    shift
    set -- nomad agent \
        -data-dir="$NOMAD_DATA_DIR" \
        -config="$NOMAD_CONFIG_DIR" \
        $NOMAD_BIND \
        $NOMAD_CLIENT \
        "$@"
elif [ "$1" = 'version' ]; then
    # This needs a special case because there's no help output.
    set -- nomad "$@"
elif nomad --help "$1" 2>&1 | grep -q "nomad $1"; then
    # We can't use the return code to check for the existence of a subcommand, so
    # we have to use grep to look for a pattern in the help output.
    set -- nomad "$@"
fi

# If we are running Nomad, make sure it executes as the proper user.
if [ "$1" = 'nomad' ]; then
    # If the data or config dirs are bind mounted then chown them.
    # Note: This checks for root ownership as that's the most common case.
    if [ "$(stat -c %u /nomad/data)" != "$(id -u nomad)" ]; then
        chown nomad:nomad /nomad/data
    fi
    if [ "$(stat -c %u /nomad/config)" != "$(id -u nomad)" ]; then
        chown nomad:nomad /nomad/config
    fi

    set -- su-exec nomad:nomad "$@"
fi

exec "$@"
