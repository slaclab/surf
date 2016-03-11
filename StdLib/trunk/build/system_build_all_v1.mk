# Default
all: build

# Check variables
test:
	@echo PARALLEL_BUILD: $(PARALLEL_BUILD)
	@echo TARGET_DIRS:
	@echo -e "$(foreach ARG,$(TARGET_DIRS),\t$(ARG)\n)"

# Clean all firmware builds
clean:
	for i in $(TARGET_DIRS); do \
      cd $$i; make clean; \
   done

# Build all firmware
# Note: Builds happen in clusters of up to $(PARALLEL_BUILD) 
# builds at a time to prevent over subscribing the server
build:
	@n=0 ; \
   for i in $(TARGET_DIRS); do \
      let "n+=1";\
      if test $$n != $(PARALLEL_BUILD); then \
         (konsole --workdir $$i --new-tab --noclose -e tcsh -c 'source ../../setup_env.csh; make'); \
      fi; \
      if test $$n = $(PARALLEL_BUILD); then \
         cd $$i; tcsh -c 'source ../../setup_env.csh; make'; \
         let "n=0";\
      fi; \
   done
