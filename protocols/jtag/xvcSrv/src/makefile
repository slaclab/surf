all: xvcSrv drvFifo.so

OBJS=xvcSrv.o xvcDrvLoopBack.o xvcConn.o xvcDrvUdp.o

xvcSrv: $(OBJS)
	$(CROSS)$(CXX) -o $@ $^ -ldl -Wl,--export-dynamic -lm -lpthread

%.o: %.cc
	$(CROSS)$(CXX) -o $@ $^ -I. -O2 -c

drvFifo.so: xvcDrvAxisFifo.cc
	$(CROSS)$(CXX) -shared -fPIC -I. -O2 -o $@ $^

clean:
	$(RM) xvcSrv drvFifo.so $(OBJS)
