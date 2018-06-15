ARG PG_VERSION

FROM timescale/timescaledb-postgis:latest-pg${PG_VERSION}

# installing inotify
RUN apk add --no-cache inotify-tools

# scripts & entrypoint
COPY bootstrap.sh /home/
RUN chmod 755 /home/bootstrap.sh && \
	chown root:root /home/bootstrap.sh
ENTRYPOINT /home/bootstrap.sh