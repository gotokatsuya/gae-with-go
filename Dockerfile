FROM google/cloud-sdk:alpine

RUN apk add --update --no-cache make bash gcc musl-dev

## gcloud
RUN gcloud components install app-engine-go
RUN gcloud components update

## golang
RUN apk add --no-cache ca-certificates
ENV GOLANG_VERSION 1.8.3
# https://golang.org/issue/14851 (Go 1.8 & 1.7)
# https://golang.org/issue/17847 (Go 1.7)
COPY *.patch /go-alpine-patches/
RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		openssl \
		go \
	; \
	export \
# set GOROOT_BOOTSTRAP such that we can actually build Go
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
# ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
# (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GO386="$(go env GO386)" \
		GOARM="$(go env GOARM)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
	\
	wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	echo '5f5dea2447e7dcfdc50fa6b94c512e58bfba5673c039259fd843f68829d99fa6 *go.tgz' | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	cd /usr/local/go/src; \
	for p in /go-alpine-patches/*.patch; do \
		[ -f "$p" ] || continue; \
		patch -p2 -i "$p"; \
	done; \
	./make.bash; \
	\
	rm -rf /go-alpine-patches; \
	apk del .build-deps; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH
COPY go-wrapper /usr/local/bin/

## gae
ENV GAE_VERSION=1.9.59
ENV GAE_SDK=https://storage.googleapis.com/appengine-sdks/featured/go_appengine_sdk_linux_amd64-${GAE_VERSION}.zip \
    PATH=/google_appengine:${PATH} \
    GOROOT=/usr/local/go
RUN apk add --update --no-cache openssh-client git python && \
    apk add --update --no-cache --virtual=build-time-only curl unzip && \
	curl -fo /tmp/gae.zip ${GAE_SDK} &&  \
	unzip -q /tmp/gae.zip -d /tmp/ &&  \
	mv /tmp/go_appengine /google_appengine && \
    apk del build-time-only

RUN rm -rf /tmp/* /var/cache/apk/*
