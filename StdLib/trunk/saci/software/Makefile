# Variables
CC     := g++
DEF    := 
BIN    := $(PWD)/bin
OBJ    := $(PWD)/.obj
CFLAGS := -Wall `xml2-config --cflags` -I$(PWD)/generic -I$(PWD)/saci -I$(PWD)/offline
LFLAGS := `xml2-config --libs` -pthread -lrt

# Generic Sources
GEN_DIR := $(PWD)/generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Local Sources
LOC_DIR := $(PWD)/saci
LOC_SRC := $(wildcard $(LOC_DIR)/*.cpp)
LOC_HDR := $(wildcard $(LOC_DIR)/*.h)
LOC_OBJ := $(patsubst $(LOC_DIR)/%.cpp,$(OBJ)/%.o,$(LOC_SRC))

# Util Sources
UTL_DIR := $(PWD)/util
UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Default
all: dir $(GEN_OBJ) $(LOC_OBJ) $(UTL_BIN) gui pylibs

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(BIN)/*
	cd cntrlGui; qmake; gmake clean
	cd python; gmake clean

# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile local Sources
$(OBJ)/%.o: $(LOC_DIR)/%.cpp $(LOC_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
$(BIN)/%: $(UTL_DIR)/%.cpp $(GEN_OBJ) $(LOC_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

# python libs
pylibs:
ifneq ($(PYTHONPATH),)
	cd python; gmake
endif

# Compile gui
gui:
	cd cntrlGui; qmake
	cd cntrlGui; gmake

