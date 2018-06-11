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

# Due to how sensitive Nomad is to mounting, we don't create any volumes for
# Nomad data or config. You will probably want these exposed to the host.
#
# Depending on your setup, you may want these in alternate locations other than
# the default /nomad paths, but if you do this, you need to also reconfigure
# them here by supplying the NOMAD_DATA_DIR and NOMAD_CONFIG_DIR environment
# variables.
if [ -z "${NOMAD_DATA_DIR}" ]; then
  NOMAD_DATA_DIR=/nomad/data
fi
if [ -z "${NOMAD_CONFIG_DIR}" ]; then
  NOMAD_CONFIG_DIR=/nomad/config
fi

# If NOMAD_RUN_ROOT is selected, then run as root. This will be necessary to
# run pretty much any job on the host, so it needs to be set for client and
# development mode.
if [ -n "${NOMAD_RUN_ROOT}" ]; then
  echo "==> NOMAD_RUN_ROOT specified, running Nomad as root."
  NOMAD_RUN_USER="root"
else
  echo "==> Running Nomad as unprivileged \"nomad\" user"
  echo "==> Set NOMAD_RUN_ROOT if job execution is required"
  NOMAD_RUN_USER="nomad"
fi

# You can also set the NOMAD_LOCAL_CONFIG environemnt variable to pass some
# Nomad configuration JSON without having to bind any volumes.
if [ -n "$NOMAD_LOCAL_CONFIG" ]; then
	echo "$NOMAD_LOCAL_CONFIG" > "$NOMAD_CONFIG_DIR/local.json"
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
    if [ "$(stat -c %u "${NOMAD_DATA_DIR}")" != "$(id -u ${NOMAD_RUN_USER})" ]; then
        chown "${NOMAD_RUN_USER}":nomad "${NOMAD_DATA_DIR}"
    fi
    if [ "$(stat -c %u "${NOMAD_CONFIG_DIR}")" != "$(id -u ${NOMAD_RUN_USER})" ]; then
        chown "${NOMAD_RUN_USER}":nomad "${NOMAD_CONFIG_DIR}"
    fi

    set -- su-exec "${NOMAD_RUN_USER}":nomad "$@"
fi

exec "$@"
