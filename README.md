# Docker Images For Development Purposes

This repository gather some Docker images that helps for development. They all basically watch a folder for changes, and rebuild/reload sources whenever an event occurs. Those images can be found very useful when running a micro-services local environment with [Docker Compose](https://docs.docker.com/compose/).

All those images are based on respective official Docker images (the Alpine version when available).

## List Of Images

- [Golang](#golang)
- [PostgreSQL](#postgresql)

### Building Images

Each image have an associated Docker Hub repository, but you can also modify and build your own images.

**Prerequisites**

- Docker
- Make

**Build**

To build a image, you just need to run :

```bash
make <folder_name>
make golang # to build the golang image
```

To build all images, run `make all`.

You can change versions by editing the `Makefile`.

## Golang

[![Docker Hub repo](https://img.shields.io/docker/pulls/kanshiroron/docker-dev-golang.svg)](https://hub.docker.com/r/kanshiroron/docker-dev-golang)

[Golang's website](https://golang.org/) - [Base image](https://hub.docker.com/_/golang/)

This image watches for changes in the`/go/src` folder, and when an event occurs it recompiles the programm and runs it if the build is successfull (the old version will not be stopped if the build fails). Watch can also be disabled (with the `NO_WATCH` environment variable), so compilations will have to be triggered manually (see the [commands](#commands) section below).

### Configuration

#### Environment variables

- `APP_FOLDER`: is the path of your application (main package), from the `src` folder. In previous example, the `test` folder should be located at `<your_project_folder>/src/test` (`/go/src/test` in the container).
- `APP_ARGS` (optional): arguments to pass to your app when ran.
- `COMPILE_ONLY` (boolean, optional): do not run your software once compiled. In this case, your compiled program will sit under `/go/bin` (inside the Docker container). When active, you should also set the `UID` parameter to make sure you are the owner of the ouput program.
- `COMPILATION_EXTRA_ARGS` (string, optional): optionaly define some extra agurments that you want to pass on to the golang compiler.
- `NO_WATCH` (boolean, optional): Does not watch for any file change. Compilations will have to be triggered manually (see the [commands](#commands) section below). This option is incompatible with the `WATCH_FOLDER` option.
- `WATCH_FOLDER` (optional): Witch folder to watch for changes (to trigger rebuild). If the path doesn't start with a `/`, `/go/src/` will be prefixed to the variable. Defaults to `/go/src`.
- `APP_UID` (optional): the id of the user the program should be ran with. If `COMPILE_ONLY` is set to `true`, then it will change the owner of the output binary. This can be usefull if the application writes data to a binded folder (so you do not have to deal with access rights).
- `APP_GID` (optional, defaults to the same value of `APP_UID`, if set): the id of the user group the program should be ran with. Only works if `APP_UID` is set.
- `STOP_TIMEOUT` (optional, defaults to `5`): the maximum number of seconds we should wait for the program to stop (after sending the `SIGTERM` signal) Once the timeout reach, the program will be kill with the `SIGKILL` signal.

#### Volumes

- `<your_project_folder>`: (mandatory), this folder contains your Golang project (can be in a sub-folder).
- `<your_gopath>`: (optional), add it if your project contains depencies that are included in your gopath.

Since building will be really frequent, we recommend you mounting both `/go/bin` and `/go/pkg` as `tmpfs` ([docker documentation](https://docs.docker.com/storage/tmpfs/)).

### Run

```bash
docker run -ti -e APP_FOLDER=test \
	-v <your_project_folder>/src:/go/src:ro \
	-v <your_gopath>:/gopath:ro \
	kanshiroron/docker-dev-golang:1.22
```

### Commands

The Golang image comes with three binaries, one to trigger a rebuild, another to trigger a restart of the application and the last to stop the application (if running). Those three binaries can be found under the `/usr/local/bin/` folder of the docker image. This folder is part of the `PATH`, so they are accessible everywhere.

- `recompile`: recompiles the application and restarts it if the compilation succeeds (and if `COMPILE_ONLY` is not set to `true`). This may be usefull when modifications made are outside of the watched folder (like in the GOPATH).
- `restart`: stops the running application and starts it again (has no effect if `COMPILE_ONLY` is set to `true`).
- `stop`: stops the running application.

**Example:**

```bash
docker exec <mycontainername> recompile
```

## PostgreSQL

[![Docker Hub repo](https://img.shields.io/docker/pulls/kanshiroron/docker-dev-postgresql.svg)](https://hub.docker.com/r/kanshiroron/docker-dev-postgresql)

[PostgreSQL's website](https://www.postgresql.org/) - [Base image](https://hub.docker.com/_/postgres/)

Watch for changes in each of `/psql`'s subfolders, and when a event occurs it closes all db connections (for the specific database only), drops the current database and reload all sources. By default, the name of the subfolder becomes the name of the database, the name of the user and its password (see the [Configuration](#configuration-1) section for more options).

**Your database folders can't contain any space or special characters in their name otherwise PostgreSQL will throw an error.**

Since the order of resources creation is important in PostgreSQL, you need to have a file named `order` at the root of each subfolders which lists every SQL files you want to import (one file per line). This `order` file may reference another `order` file (the name of the other file must also be named `order`).

### Configuration

All configuration is done via environment variables.

- `POSTGRES_USER`: PosgreSQL user name. Optional, defaults to `postgres`
- `POSTGRES_PASSWORD`: PosgreSQL user password. Optional, defaults to `password`
- `<FOLDER_NAME | UPPERCASE>_DB`: Name of the database for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.
- `<FOLDER_NAME | UPPERCASE>_USER`: Name of the database user for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.
- `<FOLDER_NAME | UPPERCASE>_PASSWORD`: Name of the database user password for the `FOLDER_NAME` service. Optional, defaults to the folder name, lower case.
- `POSTGRES_USER_UID`: Change the default user id for the postgres user (useful if you need to mount data volumes or certificates).
- `POSTGRES_USER_GID`: Change the default group id for the postgres user (useful if you need to mount data volumes or certificates).

You can also use other options listed in the [base PostgreSQL image](https://hub.docker.com/_/postgres/).

### Run

In this example the `service1` application will have the default database name, user and password `service1`, and `service2` will has the database named `myservice`, the user `myserviceuser` and password `myservicepassword`.

```bash
docker run -ti -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword \
	-v $(pwd)/service1/sql:/psql/service1:ro \
	-v $(pwd)/service2/sql:/psql/service2:ro \
	-e SERVICE2_DB=myservice -e SERVICE2_USER=myserviceuser -e SERVICE2_PASSWORD=myservicepassword \
	kanshiroron/docker-dev-postgresql:16
```

## License

The Integration Toolbox WebServer is released under the [GPL3 license](LICENSE), allowing you to use and modify it freely for your testing needs.

## Credits

### Authors

- Kanshiroron [![Follow on X](https://img.shields.io/twitter/follow/AntoineKanshi)](https://x.com/AntoineKanshi)
