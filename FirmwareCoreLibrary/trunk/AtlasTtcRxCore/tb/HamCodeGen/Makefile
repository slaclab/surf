# Project: hamming
# Makefile created by Dev-C++ 4.9.9.2

CPP  = g++ -D__DEBUG__
CC   = gcc -D__DEBUG__
RES  = 
OBJ  = main.o hamm_sec_gen.o hamm_secded_gen.o $(RES)
LINKOBJ  = main.o hamm_sec_gen.o hamm_secded_gen.o $(RES)
LIBS = -g3 
INCS = -I"." 
CXXINCS = -I"." 
BIN  = hamming
CXXFLAGS = $(CXXINCS)   -g3
CFLAGS = $(INCS)   -g3
RM = rm -f

.PHONY: all all-before all-after clean clean-custom

all: all-before hamming all-after


clean: clean-custom
	${RM} $(OBJ) $(BIN)

$(BIN): $(OBJ)
	$(CPP) $(LINKOBJ) -o "hamming" $(LIBS)

main.o: main.cpp
	$(CPP) -c main.cpp -o main.o $(CXXFLAGS)

hamm_sec_gen.o: hamm_sec_gen.cpp
	$(CPP) -c hamm_sec_gen.cpp -o hamm_sec_gen.o $(CXXFLAGS)

hamm_secded_gen.o: hamm_secded_gen.cpp
	$(CPP) -c hamm_secded_gen.cpp -o hamm_secded_gen.o $(CXXFLAGS)
