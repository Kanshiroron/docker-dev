#!/usr/bin/env bash

# checking if environment variable have been set
if ! [ -n "${APP_FOLDER}" ]; then
	echo "ERROR :: You must specify which folder to watch through the variable APP_FOLDER (below the 'src' folder)"
	exit 1
fi

# compile only
if [ -n "${COMPILE_ONLY}" ] && ${COMPILE_ONLY}; then
	echo "INFO :: Compile only"
	COMPILE_ONLY=true
else
	COMPILE_ONLY=false
fi

# uid/gid
if [ -n "${APP_UID}" ]; then
	if [ -z "${APP_GID}" ]; then
		APP_GID="${APP_UID}"
	fi
	echo "INFO :: Adding user uid:gid ${APP_UID}:${APP_GID}"
	addgroup -g ${APP_GID} golanggroup
	adduser -G golanggroup -u ${APP_UID} -D -H golanguser
fi

# adding custom TLS CA certificates to store
echo "INFO :: Adding custom certificates to store"
update-ca-certificates

# checking if folder is mounted
BASE_FOLDER=/go/src
APP_FOLDER=${BASE_FOLDER}/${APP_FOLDER}
if ! [ -d ${APP_FOLDER} ]; then
	echo "ERROR :: You must mount your golang source folder under '${BASE_FOLDER}'"
	exit 1
fi
# watch folder
if [ -z "${WATCH_FOLDER}" ]; then
	WATCH_FOLDER=${BASE_FOLDER}
else
	# prefix BASE_FOLDER if WATCH_FOLDER doesn't start with '/'
	if ! [[ "${WATCH_FOLDER}" =~ ^/.* ]]; then
		WATCH_FOLDER=${BASE_FOLDER}/${WATCH_FOLDER}
	fi

	# checking if watch folder exists
	if ! [ -d ${WATCH_FOLDER} ]; then
		echo "ERROR :: Watch folder '${WATCH_FOLDER}' doesn't exists"
		exit 1
	fi
fi

cd ${APP_FOLDER} # needed for go modules
output_bin=/go/bin/$(basename ${APP_FOLDER})
exec_bin=/tmp/$(basename ${APP_FOLDER})
export GOPID=/tmp/gosoft.pid

# start bin
function start_bin() {
	# do nothing if it's compile only
	if ${COMPILE_ONLY}; then
		echo "INFO :: Set to compile only, the application will not be run"
		return
	fi

	# killing existing service if any
	if [ -f ${GOPID} ]; then
		# killing old process
		pid=$(cat ${GOPID})
		echo -e "\n\n\nINFO :: Killing old process ${output_bin} (${pid})"
		kill ${pid}

		# Waiting for old process to stop
		echo "INFO :: Waiting for old process to stop"
		while ps aux | awk '{print $2}' | grep ${pid}; do sleep 1; done
		rm ${GOPID}
	fi

	# starting service
	echo "INFO :: Starting service"
	# is it a new build?
	if [ -f ${output_bin} ]; then
		[ -f ${exec_bin} ] && rm ${exec_bin}
		mv ${output_bin} ${exec_bin} # moving to /tmp in case /go/bin is tmpfs (noexec)
	fi
	if [ -n "${APP_UID}" ]; then
		su golanguser -c "${exec_bin} ${APP_ARGS}" &
	else
		${exec_bin} ${APP_ARGS} &
	fi
	echo $! > ${GOPID}
}

# compiler function
function compile() {
	# building service
	echo "INFO :: Compiling service"
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ${output_bin} ${APP_FOLDER}

	# restart service if compilation went well
	if [ $? -eq 0 ]; then
		# exit if compile only
		if ${COMPILE_ONLY} && [ -n "${APP_UID}" ]; then
			chown ${APP_UID} ${output_bin}
		fi

		# starting application
		start_bin
	fi
}

# trap functions to rebuild and restart
echo "INFO :: Setting trap functions for recompile and restart"
trap "compile" SIGUSR1
trap "start_bin" SIGUSR2

# building project for the first time
compile

# starting iwatch
echo "INFO :: Starting iwatch to automatically rebuild project inside ${WATCH_FOLDER}"
while true; do
	while read path event file; do
		echo "INFO :: New ${event} event for file: ${path}${file}"

		# rebuilding service
		compile
	done < <(inotifywait --quiet --event create --event delete --event modify --event moved_to --recursive ${WATCH_FOLDER}) # needed for trap functions to work since otherwise the command blocks the bash thread
done