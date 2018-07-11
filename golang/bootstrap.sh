#!/usr/bin/env bash

# checking if environment variable have been set
if ! [ -n "${SOFT_FOLDER}" ]; then
	echo "ERROR :: You must specify which folder to watch through the variable SOFT_FOLDER (below the 'src' folder)"
	exit 1
fi
if [ -n "${COMPILE_ONLY}" ]; then
	echo "INFO :: Compile only"
fi

# checking if folder is mounted
BASE_FOLDER=/go/src
WATCH_FOLDER=${BASE_FOLDER}/${SOFT_FOLDER}
if ! [ -d ${WATCH_FOLDER} ]; then
	echo "ERROR :: You must mount your golang source folder under '${BASE_FOLDER}''"
	exit 1
fi
output_bin=/go/bin/$(basename ${SOFT_FOLDER})
exec_bin=/tmp/$(basename ${SOFT_FOLDER})
export GOPID=/tmp/gosoft.pid

# compiler function
function compile() {
	# building service
	echo "INFO :: Compiling service"
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ${output_bin} ${SOFT_FOLDER}

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
		${exec_bin} ${SOFT_ARGS} &
		echo $! > ${GOPID}
	fi
}

# building project for the first time
compile

# starting iwatch
echo "INFO :: Starting iwatch to automatically rebuild project inside ${WATCH_FOLDER}"
while true; do
	# waiting for files to be modified
	inotifywait -e create -e delete -e modify -e moved_to -r ${BASE_FOLDER}

	# rebuilding service
	compile
done