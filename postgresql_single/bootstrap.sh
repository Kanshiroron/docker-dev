#!/usr/bin/env bash
[ -n "${DEBUG}" ] && set -x

# checking if watch folder is mounted
watch_folder="/psql"
order_file_name=order
order_file=${watch_folder}/${order_file_name}
if ! [ -d ${watch_folder} ]; then
	echo "ERROR :: You need to mount to PostgreSQL watched folder: ${watch_folder}"
	exit 1
fi
if ! [ -f ${order_file} ]; then
	echo "ERROR :: You need create a file that list and order your PSQL imports (named ${order_file_name})"
	exit 1
fi

# setting defaults
if ! [ -n "${POSTGRES_USER}" ]; then
	export POSTGRES_USER=postgres
	echo "INFO :: Setting default PostgreSQL user: ${POSTGRES_USER}"
fi
if ! [ -n "${POSTGRES_PASSWORD}" ]; then
	export POSTGRES_PASSWORD=password
	echo "INFO :: Setting default PostgreSQL password: ${POSTGRES_PASSWORD}"
fi
if ! [ -n "${POSTGRES_DB}" ]; then
	export USER_DB=mydb
	echo "INFO :: Setting default PostgreSQL database: ${USER_DB}"
elif [ "${POSTGRES_DB}" = "postgres" ]; then
	echo "ERROR :: You can't use 'postgres' as database name"
	exit 1
else
	export USER_DB=${POSTGRES_DB}
fi
export POSTGRES_DB=postgres

# starting PostgreSQL
echo "INFO :: Starting PostgreSQL"
/usr/local/bin/docker-entrypoint.sh postgres &

# waiting for PostgreSQL to be up
echo "INFO :: Waiting for PostgreSQL to be up"
while ! pg_isready -U ${POSTGRES_USER}; do sleep 1; done

# load function
function loadSQLFiles {
	# args:
	# 1: folder
	# 2: db name
	# 3: db user
	# 4: db user password
	for psql_file in $(cat ${1}/${order_file_name}); do
		if [ "$(basename "${psql_file}")" = "${order_file_name}" ]; then
			new_folder="${1}/$(dirname ${psql_file})"
			loadSQLFiles "${new_folder}" "${2}" "${3}" "${4}"
		else
			echo "INFO :: Importing ${1}/${psql_file}"
			PGPASSWORD=${4} psql -U ${3} -f ${1}/${psql_file} ${2}
		fi
	done
}

# watch function
function loadPSQL() {
	echo -e "\n\n\nINFO :: Disconnecting clients"
	PGPASSWORD=${POSTGRES_PASSWORD} psql --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${USER_DB}' AND pid <> pg_backend_pid();";

	echo "INFO :: Dropping old database"
	PGPASSWORD=${POSTGRES_PASSWORD} psql --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --command="DROP DATABASE ${USER_DB};"
	PGPASSWORD=${POSTGRES_PASSWORD} psql --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --command="CREATE DATABASE ${USER_DB};"
	PGPASSWORD=${POSTGRES_PASSWORD} psql --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --command="GRANT ALL PRIVILEGES ON DATABASE ${USER_DB} TO ${POSTGRES_USER};"

	echo "INFO :: Loading database schema"
	loadSQLFiles "${watch_folder}" "${USER_DB}" "${POSTGRES_USER}" "${POSTGRES_PASSWORD}"
}

# load PSQL for the first time
sleep 5
echo "INFO :: Loading PostgreSQL schema"
loadPSQL

echo "INFO :: Starting iwatch to automatically reload scripts inside ${watch_folder}"
while true; do
	inotifywait -e create -e delete -e modify -e moved_to -r ${watch_folder}
	loadPSQL
done
