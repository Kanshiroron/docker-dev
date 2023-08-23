ARG PG_VERSION

FROM postgres:${PG_VERSION}-alpine

# installing inotify & shadow (for changing postgres UID/GID)
RUN apk add --no-cache \
	inotify-tools \
	shadow

# scripts & entrypoint
COPY bootstrap.sh /home/
RUN chmod 755 /home/bootstrap.sh && \
	chown root:root /home/bootstrap.sh
ENTRYPOINT /home/bootstrap.sh
ENTRYPOINT ["/home/bootstrap.sh"]
CMD [""]