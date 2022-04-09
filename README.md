# Scaffold

A framework for developing, testing, and deploying scalable software services, using hierarchical [*Makefiles*](https://en.wikipedia.org/wiki/Make_(software)#Makefile) and a simple templating mechanism to drive [*Canonical Multipass*](https://Multipass.run/) and [*Docker*](https://www.docker.com/) configurations.

I developed this framework while learning about [*Multipass*](https://Multipass.run/) and [*Docker*](https://www.docker.com/). I know there are other solutions available for building such configurations, but I wanted to focus on those two technologies at first and not on the build automation aspect. It was convenient to use a familiar tool like [*make*](https://en.wikipedia.org/wiki/Make_(software)) in order to maintain focus and avoid some complexities that simply weren't required for my purposes. At some point later I may replace this piece with [Kubernetes](https://kubernetes.io/) or something else.

To see an example how a project would use this scaffold code, see https://github.com/codecat555/deduplifier .

## Usage

1. Check out this code.
1. Create a project subdirectory in the top level of the repository and populate it with your configuration files and templates.
1. Run `make -e <your-project-name>`

## Controls

By default, the system only builds things if they do not already exist. You can override this behavior with the following environment variables:

* **FORCE_VM_CREATION** - tear down existing multipass docker host and recreate it, implies recreating the hosted docker instances and database as well.
* **FORCE_CONTAINER_CREATION** - tear down existing docker instances and recreate them, implies recreating the database as well.
* **FORCE_DB_CREATION** - recreate the database within the existing container(s) without preserving the existing data (however, see **DB_DUMP_FILE**).

Example:

    $ FORCE_CONTAINER_CREATION=1 make -e deduplifier

### Database Backup/Restore

By default, the database is dumped to local disk before the database container is destroyed. This step is skipped if FORCE_DB_CREATION=1...unless **DB_DUMP_FILE** is set.

The **DB_DUMP_FILE** environment variable can be used to control where the data is dumped and/or which data file should be used to restore the data after the containers have been recreated.

That is, if the file indicated by the **DB_DUMP_FILE** variable does not exist when the database container is destroyed, then the database will be dumped into that file first. If that file does already exist, then it is assumed to be up-to-date and the database will not be saved to it.

Later in the build process, after the database container is recreated, if the file indicated by the **DUMP_FILE** variable exists then it will be used to populate the new instance. Otherwise, all the database structures (tables, indexes, code) are initialized with no data.

Example:

    * DB_DUMP_FILE=<your-path-here>

## How It Works

My goal was to develop a general system that could be used across any number of software projects I might want to tackle. To that end, this system defines some general values and processes at this top level, and then each managed project provides it's own individual definitions and overrides as required.

For example, the top level defines a *make* target for creating a multipass-based virtual docker host, but the particulars of how that host should be configured (*number of cpus, disk sizes, hostname, etc*) are contained in files located within each individual project directory.

Among other things, the system provides facilities for creating the virtual systems, for mounting local paths onto those systems and for managing network firewall access to/from those systems.

The project configuration files may be templates containing tokens to be replaced at build time. So, the template *Docker* configuration file may contain the token *\_\_\_DB_NAME\_\_\_* which is replaced by the corresponding *$DB_NAME* value defined by that project's makefiles.

### *Makefile*

The top level makefile pulls in the definitions contained in the *Makefile.common* file, and then descends into the project subdirectory in order to run the make files there.

### *Makefile.common*

The *Makefile.common* file# contains *global* definitions and *default* definitions.

* The *global* definitions are common across all the projects, such as which external ports are defined for each. These port assignments must be unique for each project and so there is one global list which applies for all.

* The *default* definitions are values that the project might choose to use or override in order to produce the desired configuration. An example would be the name used for the docker configuration file:

    >DOCKER_COMPOSE_FILE=docker-compose.yml 

### *Makefile.post*

This file contains the *make* rules used to the project's configuration file templates, create the virtual systems required and to handle any additional tasks like firewall changes.


Typically, this file is *included* at the bottom of the project's makefiles, after everything else has been defined. 

Any definitions in the project's make files which appear after *Makefile.post* is included may override (redefine) the definitions from that file.
