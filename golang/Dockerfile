ARG ALPINE_VERSION
ARG GOLANG_VERSION

############
# COMPILER #
############
FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION}

# installing packages
RUN apk add --no-cache bash inotify-tools

# configuration
ENV GOPATH=/gopath:/go
ENV CGO_ENABLED=0
ENV GOOS=linux

# commands
COPY --chmod=750 --chown=root:root bootstrap.sh recompile restart stop /usr/local/bin/

# entrypoint
COPY bootstrap.sh /home/
RUN chown root:root /home/bootstrap.sh && \
	chmod 750 /home/bootstrap.sh
ENTRYPOINT ["/home/bootstrap.sh"]
WORKDIR /go
