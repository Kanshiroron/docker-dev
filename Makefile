REPO_NAME=kanshiroron/docker-dev
ALPINE_VERSION=3.19
GOLANG_VERSION=1.23
PG_VERSION=16

all: golang postgresql

golang:
	docker build --pull -t ${REPO_NAME}-golang:${GOLANG_VERSION} --build-arg ALPINE_VERSION=${ALPINE_VERSION} --build-arg GOLANG_VERSION=${GOLANG_VERSION} golang

postgresql:
	docker build --pull -t ${REPO_NAME}-postgresql:${PG_VERSION} --build-arg PG_VERSION=${PG_VERSION} postgresql

.PHONY: all golang postgresql
