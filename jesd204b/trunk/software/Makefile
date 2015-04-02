# Variables
MACHINE    := $(shell uname -m)
CC         := g++
BIN        := $(PWD)/bin
DEF_CFLAGS := -Wall -g `xml2-config --cflags` -I$(PWD)/generic -I$(PWD)/deviceLib -I$(PWD)/tracker -I$(PWD)/offline -I$(PWD)/driver
DEF_LFLAGS := `xml2-config --libs` -lpthread -lrt -lbz2 -g

# RCE Build
ifeq ($(MACHINE), armv7l)
   $(info Compiling for RCE)
   DEF      := -DARM
   CFLAGS   := $(DEF_CFLAGS)
   LFLAGS   := $(DEF_LFLAGS)
   EXT_TARS := 
   CLN      := 
   UTL_DIR  := $(PWD)/rce
   OBJ      := $(PWD)/.rce_obj

# Server Build
else
   $(info Compiling for Server)
   DEF      :=
   CFLAGS   := $(DEF_CFLAGS) -fpermissive
   LFLAGS   := $(DEF_LFLAGS)
   EXT_TARS := gui ana
   CLN      := server_clean
   UTL_DIR  := $(PWD)/util
   OBJ      := $(PWD)/.obj
endif

# Generic Sources
GEN_DIR := $(PWD)/generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Device Sources
DEV_DIR := $(PWD)/deviceLib
DEV_SRC := $(wildcard $(DEV_DIR)/*.cpp)
DEV_HDR := $(wildcard $(DEV_DIR)/*.h)
DEV_OBJ := $(patsubst $(DEV_DIR)/%.cpp,$(OBJ)/%.o,$(DEV_SRC))

# JESD Sources
JESD_DIR := $(PWD)/jesd204b
JESD_SRC := $(wildcard $(JESD_DIR)/*.cpp)
JESD_HDR := $(wildcard $(JESD_DIR)/*.h)
JESD_OBJ := $(patsubst $(JESD_DIR)/%.cpp,$(OBJ)/%.o,$(JESD_SRC))

# Util Sources
UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Default
all: dir $(GEN_OBJ) $(DEV_OBJ) $(JESD_OBJ) $(UTL_BIN) pylibs $(EXT_TARS)

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
server_clean:
	cd cntrlGui; qmake; make clean; make distclean

# Clean
clean: $(CLN)
	rm -rf $(OBJ)
	rm -f $(UTL_BIN)
	cd python; make clean

# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Common Sources
$(OBJ)/%.o: $(DEV_DIR)/%.cpp $(DEV_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Tracker Sources
$(OBJ)/%.o: $(JESD_DIR)/%.cpp $(JESD_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
$(BIN)/%: $(UTL_DIR)/%.cpp $(GEN_OBJ) $(JESD_OBJ) $(DEV_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

# Compile gui
gui:
	cd cntrlGui; qmake
	cd cntrlGui; make


# python libs
pylibs:
ifneq ($(PYTHONPATH),)
	cd python; make
endif

