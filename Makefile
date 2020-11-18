
include Makefile.common

# an application is a subdir containing a Makefile
APPS=$(shell echo */Makefile | xargs dirname)

.PHONY: $(APPS)

all:
	@echo "Please specify an explicit build target: $(APPS)"

$(APPS):
	@(cd $@ && $(MAKE) $(TARGET))

