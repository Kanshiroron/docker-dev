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

# no watch
if [ -n "${NO_WATCH}" ] && ${NO_WATCH}; then
	if [ -n "${WATCH_FOLDER}" ]; then
		echo "ERROR :: Can't have both NO_WATCH set to true, and WATCH_FOLDER set to a value"
		exit 1
	fi
	echo "INFO :: No watch"
	NO_WATCH=true
else
	NO_WATCH=false
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

# stop timeout
if [ -n "${STOP_TIMEOUT}" ]; then
	if ! [[ ${STOP_TIMEOUT} =~ ^[0-9]+$ ]]; then
		echo "ERROR :: STOP_TIMEOUT is not a positive integer"
		exit 1
	fi
else
	STOP_TIMEOUT=5
fi
echo "INFO :: Stop timeout set to ${STOP_TIMEOUT} seconds"

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
if ! ${NO_WATCH}; then
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
		echo "INFO :: Waiting up to ${STOP_TIMEOUT} seconds for old process to stop"
		maxdate=$(( $(date +%s) + ${STOP_TIMEOUT} ))

		while ps aux | awk 'FNR>1 {print $1}' | grep -q ${pid}; do
			now=$(date +%s)
			if [ ${now} -ge ${maxdate} ]; then
				echo "INFO :: The application did not stop within ${STOP_TIMEOUT} seconds, sending kill signal"
				kill -9 ${pid}
			fi
			sleep 1
		done
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
	cmd=("go build -a -installsuffix cgo -o ${output_bin} ${COMPILATION_EXTRA_ARGS} ${APP_FOLDER}")
	eval "${cmd}"

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

if ${NO_WATCH}; then
	while true; do
		# must create a non-blocking loop for events to work
		while read path event file; do echo ""; done < <(inotifywait --quiet --event delete /)
	done
else
	# starting iwatch
	echo "INFO :: Starting iwatch to automatically rebuild project inside ${WATCH_FOLDER}"
	while true; do
		while read path event file; do
			echo "INFO :: New ${event} event for file: ${path}${file}"

			# rebuilding service
			compile
		done < <(inotifywait --quiet --event create --event delete --event modify --event moved_to --recursive ${WATCH_FOLDER}) # needed for trap functions to work since otherwise the command blocks the bash thread
	done
fi