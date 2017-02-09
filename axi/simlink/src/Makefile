# Note:
# SIMLINK_PWD gets defined in the vivado_vcs_v1.tcl script

# Variables
CC     := gcc
DEF    := 
OUT    := $(SIMLINK_PWD)
OBJ    := $(SIMLINK_PWD)/.obj
CFLAGS := -Wall -fPIC -I$(VCS_HOME)/include -DVCS_VERSION=$(VCS_VERSION) -I$(ZMQ_PATH)/include
LFLAGS := -lrt -pthread  -lzmq -L$(ZMQ_PATH)/lib
LIB    := $(OUT)/libAxiSim.so

# Local Sources
LOC_DIR := $(SIMLINK_PWD)
LOC_SRC := $(wildcard $(LOC_DIR)/*.c)
LOC_HDR := $(wildcard $(LOC_DIR)/*.h)
LOC_OBJ := $(patsubst $(LOC_DIR)/%.c,$(OBJ)/%.o,$(LOC_SRC))

# Default
all: dir $(GEN_OBJ) $(LOC_OBJ) $(LIB)

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(LIB)

# Compile Local Sources
$(OBJ)/%.o: $(LOC_DIR)/%.c $(LOC_DIR)/%.h
	$(CC) -c -O $(CFLAGS) $(DEF) -o $@ $<

# Compile Library
$(OUT)/%.so: $(LOC_OBJ)
	$(CC) -shared $(DEF) $(OBJ)/* -o $@ $(LFLAGS) 
