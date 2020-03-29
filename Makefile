REPO_NAME=dev
ALPINE_VERSION=3.11
GOLANG_VERSION=1.14
PG_VERSION=12

all: golang postgresql_single postgresql_multiple timescaledb

golang:
	docker build --pull -t ${REPO_NAME}/golang:${GOLANG_VERSION} --build-arg ALPINE_VERSION=${ALPINE_VERSION} --build-arg GOLANG_VERSION=${GOLANG_VERSION} golang

postgresql_single:
	docker build --pull -t ${REPO_NAME}/postgresql_single:${PG_VERSION} --build-arg PG_VERSION=${PG_VERSION} postgresql_single

postgresql_multiple:
	docker build --pull -t ${REPO_NAME}/postgresql_multiple:${PG_VERSION} --build-arg PG_VERSION=${PG_VERSION} postgresql_multiple

timescaledb:
	docker build --pull -t ${REPO_NAME}/timescaledb:${PG_VERSION} --build-arg PG_VERSION=${PG_VERSION} timescaledb

.PHONY: all golang postgresql_single postgresql_multiple timescaledb
