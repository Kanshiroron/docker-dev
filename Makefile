REPO_NAME=dev
ALPINE_VERSION=3.7
GOLANG_VERSION=1.10
PG_VERSION=10

all: golang postgresql timescaledb

golang:
	docker build --pull -t ${REPO_NAME}/golang --build-arg ALPINE_VERSION=${ALPINE_VERSION} --build-arg GOLANG_VERSION=${GOLANG_VERSION} golang

postgresql:
	docker build --pull -t ${REPO_NAME}/postgresql --build-arg PG_VERSION=${PG_VERSION} postgresql

timescaledb:
	docker build --pull -t ${REPO_NAME}/timescaledb --build-arg PG_VERSION=${PG_VERSION} timescaledb

.PHONY: all golang postgresql timescaledb