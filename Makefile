
build: TARGET=build
clean: TARGET=clean

export TOP=$(PWD)

# these can be set on make command line to start with a fresh vm and/or fresh containers
FORCE_VM_CREATION=0
FORCE_CONTAINER_CREATION=0

# an application is a subdir containing a Makefile
APPS=$(shell echo */Makefile | xargs dirname)

.PHONY: $(APPS)

all:
	@echo "Please specify an explicit build target: $(APPS)"

$(APPS):
	@(cd $(TOP)/$@ && $(MAKE) $(TARGET))

