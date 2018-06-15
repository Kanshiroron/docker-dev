#!/usr/bin/env bash

# checking if environment variable have been set
if ! [ -n "${SOFT_FOLDER}" ]; then
	echo "ERROR :: You must specify which folder to watch through the variable SOFT_FOLDER (below the 'src' folder)"
	exit 1
fi

# checking if folder is mounted
BASE_FOLDER=/go/src
WATCH_FOLDER=${BASE_FOLDER}/${SOFT_FOLDER}
if ! [ -d ${WATCH_FOLDER} ]; then
	echo "ERROR :: You must mount your golang source folder under '${BASE_FOLDER}''"
	exit 1
fi
service=$(basename ${SOFT_FOLDER})
export GOPID=/tmp/gosoft.pid

# compiler function
function compile() {
	# building service
	echo "INFO :: Compiling service"
	go install ${SOFT_FOLDER}

	# starting service
	echo "INFO :: Starting service"
	${service} &
	echo $! > ${GOPID}
}

# building project for the first time
compile

# starting iwatch
echo "INFO :: Starting iwatch to automatically rebuild project inside ${WATCH_FOLDER}"
while true; do
	# waiting for files to be modified
	inotifywait -e create -e delete -e modify -e moved_to -r ${BASE_FOLDER}

	# killing old process
	echo -e "\n\n\nINFO :: Killing old process ${service}"
	pid=$(cat ${GOPID})
	kill ${pid}

	# Waiting for old process to stop
	echo "INFO :: Waiting for old process to stop"
	while [ $(ps aux | awk '{print $2}' | grep ${pid}) ]; do sleep 1; done
	rm ${GOPID} $(which ${service})

	# rebuilding service
	compile
done