# A Docker Container for Nomad

This repo contains the Dockerfiles and shell scripts for my [Nomad Docker
image][nomad-docker-image] on [Docker Hub][docker-hub], based on the [official
Consul image][official-consul-image].

Make sure you check out the [Nomad homepage][nomad-homepage] for more
information on Nomad itself.

[nomad-docker-image]: https://hub.docker.com/r/vancluever/nomad/ 
[docker-hub]: https://hub.docker.com/
[official-consul-image]: https://registry.hub.docker.com/_/consul/
[nomad-homepage]: https://nomadproject.io/ 

## About this Image

As this image is based on the Consul image, many of the same idioms apply to
this image. The construction is similar, using [Alpine Linux][alpine-linux] as
the base.  However, since Nomad uses cgo and is dynamically linked, the binary
is custom built against a Alpine beforehand and uploaded to the image in the
place of the upstream binary.

[alpine-linux]: https://alpinelinux.org/

## Usage

This doc assumes you are familiar with Nomad - if you need to learn how to use
it specifically, make sure you check out the [homepage][nomad-homepage].

### Development Mode

Running this container with no arguments will load the container in development
mode.

```
docker run --net=host --rm vancluever/nomad
```

`--net=host` is important to ensure that you will be able to reach respective
ports from the host.

Note that in this very basic form you will not be able to do much as Nomad's
privileges will be highly restricted within the container. Continue reading for
further details.

### Implications of running Nomad in a Container

Keep in mind that by running this container you are, in fact, running any
scheduling operations executed by this instance of Nomad within the container.
This means a few things:

* Anything run via the non-containerized drivers (ie: Fork/Exec, Java) will need
  to have respective dependencies baked in, ie: by building a new image off this
  one.
* Your ability to run jobs may be severely limited unless you run the Nomad
  container as root by setting `NOMAD_RUN_ROOT`. For more details, see below.
* You will also need `SYS_ADMIN` capabilities, which are not granted to the
  container by default, so you will need to add these with `cap-add` (again, see
  below).
* In order for containerized jobs to be able to be run properly, you will need
  to share your Nomad data directory (defaults to `/nomad/data`) from the host
  machine to the container. The path to data directory in the container **must**
  match the path on the host - this is due to how Nomad shares certain
  directories during job execution.  `NOMAD_DATA_DIR` must also be set with this
  directory.

Note that depending on _how_ you run your Nomad jobs, privileges, capabilities,
or shared directories above what is mentioned may also be needed.

### Directory permission information for shared volumes

The config and data directories have their permissions reset to that
of the running Nomad process (usually `root:nomad` or `nomad:nomad`, depending
on the value of `NOMAD_RUN_ROOT`) to ensure proper access to the data. Keep this
in mind when designing your system's filesystem layout.

### Examples

The following examples are basic examples of what is necessary to run the Nomad
image and have it successfully execute containers. The key takeaways are:

* The docker socket is shared with the host.
* `/tmp` is shared with the host so that the default syslog sockets that Nomad
  creates for allocations work.
* On some examples, `/tmp/nomad/data` is shared from the host at the same path
  within the Nomad container, and `NOMAD_DATA_DIR` is set to the appropriate
  path so that Nomad configures with that data directory set.
* `NOMAD_RUN_ROOT` works to grant appropriate permissions for access such to
  things such as the Docker socket.
* `SYS_ADMIN` capabilities are added so that Nomad can perform general
  operations such as mounting and unmounting directories.

#### Host networking

```
docker run \
  --cap-add=SYS_ADMIN \
  --env=NOMAD_DATA_DIR=/tmp/nomad/data \
  --env=NOMAD_RUN_ROOT=1 \
  --net=host \
  --rm \
  --volume=/tmp:/tmp \
  --volume=/tmp/nomad/data:/tmp/nomad/data \
  --volume=/var/run/docker.sock:/var/run/docker.sock \
  vancluever/nomad
```

#### Non-host networking with Nomad API endpoint exposed

Note the extra options as shown below to not only publish the API endpoint, but
also to ensure Nomad listens on all IPv4 addresses.

```
docker run \
  --cap-add=SYS_ADMIN \
  --env=NOMAD_DATA_DIR=/tmp/nomad/data \
  --env=NOMAD_RUN_ROOT=1 \
  --publish=4646:4646 \
  --rm \
  --volume=/tmp:/tmp \
  --volume=/tmp/nomad/data:/tmp/nomad/data \
  --volume=/var/run/docker.sock:/var/run/docker.sock \
  vancluever/nomad agent -dev -bind=0.0.0.0
```

#### CoreOS systemd unit example

If you run the Nomad image as a service (such as on CoreOS), you will want to do
something along the lines of the following:

```
[Unit]
Description=HashiCorp Nomad
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker kill nomad
ExecStartPre=-/usr/bin/docker rm nomad
ExecStartPre=/usr/bin/docker pull nomad:VERSION
ExecStart=/usr/bin/docker run \
  --name=nomad \
  --cap-add=SYS_ADMIN \
  --env=NOMAD_RUN_ROOT=1 \
  --net=host \
  --rm \
  --volume /nomad/config:/nomad/config \
  --volume /nomad/data:/nomad/data \
  --volume=/tmp:/tmp \
  --volume=/var/run/docker.sock:/var/run/docker.sock \
  vancluever/nomad:VERSION agent -server -client

[Install]
WantedBy=multi-user.target
```

Note that you will need to set VERSION to the version of Nomad you want to run.
Also, unless you plan on using a directory other than `/nomad`, you don't need
to set `NOMAD_DATA_DIR`, as the default data directory is not changing from the
default.

The container's [entrypoint script][entrypoint-script] adds some pre-existing
configuration. See the script for futher details and take care to not overwrite
any of the values, namely having to do with directories.

[entrypoint-script]: https://github.com/vancluever/docker-nomad/blob/master/0.X/docker-entrypoint.sh

Finally note that this example also does not include any bootstrapping data or
what not, and won't work on its own. You may want to set it up in tandem with
the [Consul image][official-consul-image].

## Further Details

For further details or information on how to work with the image, or to submit
an issue or a pull request, check the [GitHub repository][github-repository].

[github-repository]: https://github.com/vancluever/docker-nomad
