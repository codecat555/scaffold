
build: TARGET=build
clean: TARGET=clean

export TOP=$(PWD)

# an application is a subdir containing a Makefile
APPS=$(shell echo */Makefile | xargs dirname)

.PHONY: $(APPS)

all:
	@echo "Please specify an explicit build target: $(APPS)"

$(APPS):
	@(cd $(TOP)/$@ && $(MAKE) $(TARGET))

