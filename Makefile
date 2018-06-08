.PHONY: bin image push release clean

TAG=vancluever/nomad
VERSION=0.8.3

GO_VERSION=1.10.2

bin:
	rm -rf 0.X/pkg
	mkdir -p 0.X/pkg
	docker run --rm -v $(shell pwd)/0.X/pkg:/tmp/pkg golang:$(GO_VERSION) sh -x -c '\
	apt-get update && apt-get -y install g++-multilib && \
	go get -d github.com/hashicorp/nomad && \
	cd $$GOPATH/src/github.com/hashicorp/nomad && \
	git checkout v$(VERSION) && \
	go build --ldflags "all= \
    -X github.com/hashicorp/nomad/version.GitCommit=$$(git rev-parse HEAD) \
    -extldflags \"-static\" \
    " -o /tmp/pkg/nomad'

image: bin
	docker build --tag $(TAG):latest --tag $(TAG):$(VERSION) 0.X/

push: image
	docker push $(TAG):latest
	docker push $(TAG):$(VERSION)

release: push

clean:
	rm -rf 0.X/pkg
	docker rmi -f $(TAG)
