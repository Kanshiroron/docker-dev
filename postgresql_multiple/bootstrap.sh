#!/usr/bin/env bash

# checking if watch folder is mounted
watch_folder="/psql"
if ! [ -d ${watch_folder} ]; then
	echo "ERROR :: You need to mount to PostgreSQL watched folder: ${watch_folder}"
	exit 1
fi

declare -A psql_databases
declare -A psql_users
declare -A psql_password
order_file_name=order
for file in $(ls ${watch_folder}); do
	# checking if file is a folder
	if ! [ -d ${watch_folder}/${file} ]; then
		echo "WARNING :: ${watch_folder}/${file} is not a folder, skipping"
		continue
	elif ! [ -f ${watch_folder}/${file}/${order_file_name} ]; then
		echo "WARNING :: No order file found in ${watch_folder}/${file}/${order_file_name}, skipping"
		continue
	fi

	# db name
	ENV_DB=$(echo ${file} | awk '{print toupper($0)}')_DB
	if ! [ -n "${!ENV_DB}" ]; then
		DB=$(echo ${file} | awk '{print tolower($0)}')
		echo "INFO :: ${ENV_DB} environment variable not set, using default: ${DB}"
		psql_databases["${file}"]=${DB}
	else
		psql_databases["${file}"]=${!ENV_DB}
	fi

	# db user
	ENV_USER=$(echo ${file} | awk '{print toupper($0)}')_USER
	if ! [ -n "${!ENV_USER}" ]; then
		USER=$(echo ${file} | awk '{print tolower($0)}')
		echo "INFO :: ${ENV_USER} environment variable not set, using default: ${USER}"
		psql_users["${file}"]=${USER}
	else
		psql_users["${file}"]=${!ENV_USER}
	fi

	# db password
	ENV_PASS=$(echo ${file} | awk '{print toupper($0)}')_PASSWORD
	if ! [ -n "${!ENV_PASS}" ]; then
		PASS=$(echo ${file} | awk '{print tolower($0)}')
		echo "INFO :: ${ENV_PASS} environment variable not set, using default: ${PASS}"
		psql_password["${file}"]=${PASS}
	else
		psql_password["${file}"]=${!ENV_PASS}
	fi
done

# checking list not empty
if [ ${#psql_databases[@]} -eq 0 ]; then
	echo "ERROR :: No folder to watch, exiting."
	exit 1
fi

# setting postgres
if ! [ -n "${POSTGRES_USER}" ]; then
	export POSTGRES_USER=postgres
	echo "INFO :: Setting default PostgreSQL user: ${POSTGRES_USER}"
fi
if ! [ -n "${POSTGRES_PASSWORD}" ]; then
	export POSTGRES_PASSWORD=password
	echo "INFO :: Setting default PostgreSQL password: ${POSTGRES_PASSWORD}"
fi
export POSTGRES_DB=postgres

# starting PostgreSQL
echo "INFO :: Starting PostgreSQL"
/usr/local/bin/docker-entrypoint.sh postgres &

# waiting for PostgreSQL to be up
echo "INFO :: Waiting for PostgreSQL to be up"
while ! pg_isready -U ${POSTGRES_USER}; do sleep 1; done
sleep 5

# load function
function watchPSQL {
	# args:
	# 1: folder name
	# 2: db name
	# 3: db user
	# 4: db user password
	while true; do
		echo -e "\n\n\nINFO :: Disconnecting clients"
		PGPASSWORD=${POSTGRES_PASSWORD} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${2}' AND pid <> pg_backend_pid();";

		echo "INFO :: Dropping old database"
		PGPASSWORD=${POSTGRES_PASSWORD} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "DROP DATABASE IF EXISTS ${2};"
		PGPASSWORD=${POSTGRES_PASSWORD} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "CREATE DATABASE ${2};"
		PGPASSWORD=${POSTGRES_PASSWORD} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "GRANT ALL PRIVILEGES ON DATABASE ${2} TO ${3};"

		echo "INFO :: Loading database schema"
		for psql_file in $(cat ${watch_folder}/${1}/${order_file_name}); do
			echo "INFO :: Importing ${watch_folder}/${1}/${psql_file}"
			PGPASSWORD=${4} psql -U ${3} -f ${watch_folder}/${1}/${psql_file} ${2}
		done

		# waiting for inotify
		inotifywait -e create -e delete -e modify -e moved_to -r ${watch_folder}/${1}
	done
}

# creating db users and starting iwatch
for folder in ${!psql_databases[@]}; do
	echo "INFO :: Creating ${psql_users[$folder]} db user"
	PGPASSWORD=${POSTGRES_PASSWORD} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "CREATE USER ${psql_users[$folder]} WITH PASSWORD '${psql_password[$folder]}';"
	echo "INFO :: Starting iwatch to automatically reload scripts inside ${watch_folder}/${folder}"
	watchPSQL "${folder}" "${psql_databases[$folder]}" "${psql_users[$folder]}" "${psql_password[$folder]}" &
done

# waiting until the end of time
while true; do
	sleep 60
done
