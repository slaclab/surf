# Note:
# SIMLINK_PWD gets defined in the vivado_vcs_v1.tcl script

# Variables
CC     := gcc
DEF    := 
OUT    := $(SIMLINK_PWD)
OBJ    := $(SIMLINK_PWD)/.obj
CFLAGS := -Wall -fPIC -I$(VCS_HOME)/include -I$(SIMLINK_PWD)/../../../general/simlink/src
LFLAGS := -lrt -pthread 
LIB    := $(OUT)/libAxiSim.so

# Generic Sources
GEN_DIR := $(SIMLINK_PWD)/../../../general/simlink/src/
GEN_SRC := $(wildcard $(GEN_DIR)/*.c)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.c,$(OBJ)/%.o,$(GEN_SRC))

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

# Compile Generic Sources
$(OBJ)/%.o: $(GEN_DIR)/%.c $(GEN_DIR)/%.h
	$(CC) -c -O $(CFLAGS) $(DEF) -o $@ $<

# Compile Local Sources
$(OBJ)/%.o: $(LOC_DIR)/%.c $(LOC_DIR)/%.h
	$(CC) -c -O $(CFLAGS) $(DEF) -o $@ $<

# Compile Library
$(OUT)/%.so: $(LOC_OBJ)
	$(CC) -shared $(DEF) $(OBJ)/* -o $@ $(LFLAGS) 
   
