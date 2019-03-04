.PHONY: bin image push release clean

TAG=vancluever/nomad
VERSION=0.8.7

# Using Node 8 right now. Latest Alpine images do not have Node 8
# any more
NODE_VERSION=8.15.1

GO_VERSION=1.10.8
GO_SHA256=6faf74046b5e24c2c0b46e78571cca4d65e1b89819da1089e53ea57539c63491

bin:
	rm -rf 0.X/pkg
	mkdir -p 0.X/pkg
	docker run --rm -v $(shell pwd)/0.X/pkg:/tmp/pkg node:$(NODE_VERSION)-alpine sh -x -c '\
	apk add --no-cache alpine-sdk bash python2 go && \
	npm install --global yarn && \
	curl -S -O https://dl.google.com/go/go$(GO_VERSION).src.tar.gz && \
	echo "$(GO_SHA256)  go$(GO_VERSION).src.tar.gz" | sha256sum -c && \
	tar -zxf go$(GO_VERSION).src.tar.gz -C /usr/local && \
	cd /usr/local/go/src && \
	GOROOT_BOOTSTRAP="$$(go env GOROOT)" ./make.bash && \
	rm -rf /usr/local/go/pkg/bootstrap /usr/local/go/pkg/obj && \
	apk del go && \
	ln -s /usr/local/go/bin/* /usr/bin/ && \
	go get -d github.com/hashicorp/nomad && \
	cd $$(go env GOPATH)/src/github.com/hashicorp/nomad && \
	git checkout v$(VERSION) && \
	PATH=$$(go env GOPATH)/bin:$$PATH make GO_TAGS=ui deps ember-dist static-assets pkg/linux_amd64/nomad && \
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
