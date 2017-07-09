# A Docker Container for Nomad

This repo contains the Dockerfiles and shell scripts for my [Nomad Docker
image][1] on [Docker Hub][2], based on the [official Consul image][3].

Make sure you check out the [Nomad homepage][4] for more information on Nomad
itself.

[1]: https://hub.docker.com/r/vancluever/nomad/ 
[2]: https://hub.docker.com/
[3]: https://registry.hub.docker.com/_/consul/
[4]: https://nomadproject.io/ 

## About this Image

As this image is based on the Consul image, many of the same idioms apply to
this image. The construction is similar, using [Alpine Linux][5] as the base.
However, since Nomad uses cgo and normally is dynamically linked, the binary is
custom built against a specific release beforehand and uploaded to the image in
the place of the upstream binary.

[5]: https://alpinelinux.org/

## Usage

This doc assumes you are familiar with Nomad - if you need to learn how to use
it specifically, make sure you check out the [homepage][4].

### Implications of running Nomad in a Container

Keep in mind that by running this container you are, in fact, running any
scheduling operations executed by this instance of Nomad within the container.
This means a few things:

 * Anything run via the non-containerized drivers (ie: Fork/Exec, Java) will
   need to have respective dependencies baked in, ie: by building a new image
   off this one.
 * Containers (Docker/rkt) will need to have respective permissions delegated to
   the container. Docker is discussed in detail below.

#### Docker driver considerations

In order to use Docker properly with this container, you need to share the
Docker socket with the container. Appropriate in-container permissions need to
be applied too. The init script takes care of this as long as you pass in
`DOCKER_GID` to the container with the group ID of the local host's `docker`
group.

`/tmp` also needs to be shared, possibly until [go-dockerclient#528][6] is
fixed. [More info][7]. Hence, the full command for dev mode is:

```
docker run --net=host --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /tmp:/tmp --env DOCKER_GID=`getent group docker | cut -d: -f3` \
  --rm vancluever/nomad
```

[6]: https://github.com/fsouza/go-dockerclient/issues/528
[7]: https://github.com/hashicorp/nomad/issues/1080

Note that if you build your own container with Docker baked in, you do not need
to supply the local Docker host's GID - we assume you know what you are doing,
and fail if we see a Docker group with the GID passed in.

### Development Mode

Running this container with no arguments will load the container in development
mode.

```
docker run --net=host --rm vancluever/nomad
```

`--net=host` is important to ensure that you will be able to reach respective
ports from the host.

## Running with Data Dir Mounted

If you are running Nomad just as an easy way to get the software, but
otherwise are running off the host, you may need to mount the data directory
to the host:

```
docker run --net=host --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /tmp:/tmp --volume /nomad/data:/nomad/data \
  --env DOCKER_GID=`getent group docker | cut -d: -f3` \
  --rm vancluever/nomad agent AGENTOPTS
```

Note that `AGENTOPTS` here represents the agent options that would need to be
added to agent, example: `-server`.

## Coming Soon

Watch this space and the [GitHub repo][8] for more examples, such as running as
a service, more details on internals, and what not.

[8]: https://github.com/vancluever/docker-nomad
