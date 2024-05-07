#!/usr/bin/env bash

# adding custom TLS CA certificates to store
echo "INFO :: Adding custom certificates to store"
update-ca-certificates

# checking if environment variable have been set
if ! [ -n "${APP_FOLDER}" ]; then
	echo "ERROR :: You must specify which folder to watch through the variable APP_FOLDER (below the 'src' folder)"
	exit 1
fi
if [ -n "${COMPILE_ONLY}" ]; then
	echo "INFO :: Compile only"
fi

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

# compiler function
function compile() {
	# building service
	echo "INFO :: Compiling service"
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ${output_bin} ${APP_FOLDER}

	# restart service if compilation went well
	if [ $? -eq 0 ]; then
		# exit if compile only
		if [ -n "${COMPILE_ONLY}" ] && ${COMPILE_ONLY}; then
			if [ -n "${UID}" ]; then
				chown ${UID} ${output_bin}
			fi
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
			rm ${GOPID} ${exec_bin}
		fi

		# starting service
		echo "INFO :: Starting service"
		mv ${output_bin} ${exec_bin} # moving to /tmp in case /go/bin is tmpfs (noexec)
		${exec_bin} ${APP_ARGS} &
		echo $! > ${GOPID}
	fi
}

# building project for the first time
compile

# starting iwatch
echo "INFO :: Starting iwatch to automatically rebuild project inside ${WATCH_FOLDER}"
while true; do
	# waiting for files to be modified
	inotifywait -e create -e delete -e modify -e moved_to -r ${WATCH_FOLDER}

	# rebuilding service
	compile
done