.PHONY: bin image push release clean

TAG=vancluever/nomad
VERSION=0.8.7

GO_VERSION=1.10.8

bin:
	rm -rf 0.X/pkg
	mkdir -p 0.X/pkg
	docker run --rm -v $(shell pwd)/0.X/pkg:/tmp/pkg golang:$(GO_VERSION)-alpine sh -x -c '\
	apk add --no-cache alpine-sdk bash nodejs yarn && \
	go get -d github.com/hashicorp/nomad && \
	cd $$GOPATH/src/github.com/hashicorp/nomad && \
	git checkout v$(VERSION) && \
	make GO_TAGS=ui deps ember-dist static-assets pkg/linux_amd64/nomad && \
	cp pkg/linux_amd64/nomad /tmp/pkg'

image: bin
	docker build \
		--tag $(TAG):latest \
		--tag $(TAG):$(VERSION) \
		--build-arg NOMAD_VERSION=$(VERSION) \
		0.X/

push: image
	docker push $(TAG):latest
	docker push $(TAG):$(VERSION)

release: push

clean:
	rm -rf 0.X/pkg
	docker rmi -f $(TAG)
