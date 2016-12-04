.PHONY: bin image push release clean

TAG=vancluever/nomad
VERSION=0.5.0

bin:
	rm -rf 0.X/pkg
	mkdir -p 0.X/pkg
	docker run --rm -v $(shell pwd)/0.X/pkg:/tmp/pkg golang sh -c '\
	apt-get update && apt-get -y install g++-multilib && \
	go get -u github.com/hashicorp/nomad && \
	cd $$GOPATH/src/github.com/hashicorp/nomad && \
	git checkout v$(VERSION) && \
	make bootstrap && \
	make generate && \
	go build --ldflags "-extldflags \"-static\"" -o /tmp/pkg/nomad'

image: bin
	docker build --tag $(TAG):latest --tag $(TAG):$(VERSION) 0.X/

push: image
	docker push $(TAG):latest
	docker push $(TAG):$(VERSION)

release: push

clean:
	rm -rf 0.X/pkg
	docker rmi -f $(TAG)
