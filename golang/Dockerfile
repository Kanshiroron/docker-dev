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

# commands
COPY bootstrap.sh recompile restart /usr/local/bin/
RUN for file in recompile restart; do \
	chown root:root /usr/local/bin/${file}; \
	chmod 750 /usr/local/bin/${file}; \
	done

# entrypoint
COPY bootstrap.sh /home/
RUN chown root:root /home/bootstrap.sh && \
	chmod 750 /home/bootstrap.sh
ENTRYPOINT ["/home/bootstrap.sh"]
WORKDIR /go
