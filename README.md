# Docker images for development

This repository gather some Docker images that helps for development. They basically watch a folder for changes, and rebuild/reload sources whenever an event occurs. They are all based on respective official Docker images (the Alpine version when available).

## Building images

To build a single image, you can run `make <folder_name>`. To build all images: `make all`. You can change versions by editing the `Makefile`.

## GoLang

[Website](https://golang.org/) - [Base image](https://hub.docker.com/_/golang/)

Watch for changes in the`/go/src` folder.

To run this image:

```bash
$ docker run -ti -e SOFT_FOLDER=test -v <your_project_folder>/src:/go/src:ro -v <your_gopath>:/gopath:ro dev/golang
```

- `SOFT_FOLDER`: is the path of your application (main package), from the `src` folder. In previous example, the `test` folder should be located at `<your_project_folder>/src/test` (`/go/src/test` in the container).
- `SOFT_ARGS` (optional): arguments to add to your software.
- `COMPILE_ONLY` (boolean, optional): do not run your software once compiled. In this case, your compiled program will sit under `/go/bin` (inside the Docker container). When active, you should also set the `UID` parameter to make sure you are the owner of the ouput program.
- `UID` (optional): your user id to change the owner of the output program (only active with `COMPILE_ONLY`). 
- `<your_gopath>`: this binding is optional. Add it if your project is not included in your gopath.

Since building will be really frequent, we recommend you mounting both `/go/bin` and `/go/pkg` as `tmpfs` ([docker documentation](https://docs.docker.com/storage/tmpfs/)).

## PostgreSQL single

[Website](https://www.postgresql.org/) - [Base image](https://hub.docker.com/_/postgres/)

Watch for changes in the `/psql`. When a event occurs, it closes all db connections, drops the current database and reload all sources. You need to have an `order` file listing and sorting every SQL files that need to be imported (at the root of your binded folder).

To run this image:

```bash
$ docker run -ti -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword -e POSTGRES_DB=mydb -v $(pwd):/psql:ro dev/postgresql
```

- `POSTGRES_USER`: PosgreSQL user name. Optional, defaults to `postgres`
- `POSTGRES_PASSWORD`: PosgreSQL user password. Optional, defaults to `password`
- `POSTGRES_DB`: PostgreSQL database. Optional, defaults to `mydb`. You CAN'T use `postgres`.

You can also use other options listed in the [official image](https://hub.docker.com/_/postgres/).

## PostgreSQL mulitiple

[Website](https://www.postgresql.org/) - [Base image](https://hub.docker.com/_/postgres/)

Works basically the same as the `PostgreSQL single` multiple image, but designed for micro-services as it watches for multiple folders. Each folder being tied to a database. You also need an order file in each folder (see `PostgreSQL single`). **Your folders can't have any space or special characters in their name.**

To run this image:

```bash
$ docker run -ti -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword \
	-v $(pwd)/service1/sql:/psql/service1:ro -e SERVICE1_DB=myservice -e SERVICE1_USER=myserviceuser -e SERVICE1_PASSWORD=myservicepassword \
	-v $(pwd)/service2/sql:/psql/service2:ro \
	dev/postgresql
```

- `POSTGRES_USER`: PosgreSQL user name. Optional, defaults to `postgres`
- `POSTGRES_PASSWORD`: PosgreSQL user password. Optional, defaults to `password`
- `<FOLDER_NAME | UPPERCASE>_DB`: Name of the database for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.
- `<FOLDER_NAME | UPPERCASE>_USER`: Name of the database user for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.
- `<FOLDER_NAME | UPPERCASE>_PASSWORD`: Name of the database user password for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.

You can also use other options listed in the [official image](https://hub.docker.com/_/postgres/).

## TimescaleDB (with PostGIS)

[Website](https://www.timescale.com/) - [Base image](https://hub.docker.com/r/timescale/timescaledb-postgis/)

Works the same way as PostgreSQL image.