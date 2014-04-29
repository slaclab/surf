# Note:
# SIMLINK_PWD gets defined in the vivado_vcs_v1.tcl script

# Variables
CC     := gcc
DEF    := 
OUT    := $(SIMLINK_PWD)
OBJ    := $(SIMLINK_PWD)/.obj
CFLAGS := -Wall -fPIC -I$(VCS_HOME)/include
LFLAGS := 
LIB    := $(OUT)/libAxiSim.so

# Generic Sources
GEN_DIR := $(SIMLINK_PWD)
GEN_SRC := $(wildcard $(GEN_DIR)/*.c)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.c,$(OBJ)/%.o,$(GEN_SRC))

# Default
all: dir $(GEN_OBJ) $(LIB)

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(LIB)

# Compile General Sources
$(OBJ)/%.o: $(GEN_DIR)/%.c $(GEN_DIR)/%.h
	$(CC) -c -O $(CFLAGS) $(DEF) -o $@ $<

# Compile Library
$(OUT)/%.so: $(GEN_OBJ)
	$(CC) -shared $(DEF) $(OBJ)/* -o $@ $(LFLAGS) 
   