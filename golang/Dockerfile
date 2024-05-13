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

# entrypoint
COPY bootstrap.sh recompile restart /home/
RUN for file in bootstrap.sh recompile restart; do \
	chown root:root /home/${file}; \
	chmod 750 /home/${file}; \
	done
ENTRYPOINT /home/bootstrap.sh
WORKDIR /go
