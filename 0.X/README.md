# A Docker Container for Nomad

This repo contains the Dockerfiles and shell scripts for my [Nomad Docker
image][1] on [Docker Hub][2], based on the [official Consul image][3].

[1]: https://registry.hub.docker.com/vancluever/nomad/
[2]: https://hub.docker.com/
[3]: https://registry.hub.docker.com/_/consul/

As Nomad and Consul's semantics are very similar, only incremental changes have
been made to this container over the official Consul one. As with the official
image, the basic building blocks are:

* We start with an Alpine base image and add CA certificates in order to reach
  the HashiCorp releases server. These are useful to leave in the image so that
  the container can access Atlas features as well.
* Official HashiCorp builds of some base utilities are then included in the
  image by pulling a release of docker-base. This includes dumb-init and gosu.
  See https://github.com/hashicorp/docker-base for more details.
* Finally a specific Consul build is fetched and the rest of the Consul-specific
  configuration happens according to the Dockerfile.
