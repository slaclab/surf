all:
	g++ -Wall -m32 -I "../SSI PCIe driver" xstatus.cpp -o xstatus
	g++ -Wall -m32 -I "../SSI PCIe driver" xreset.cpp -o xreset
	g++ -Wall -m32 -I "../SSI PCIe driver" xloop.cpp -o xloop
	g++ -Wall -m32 -I "../SSI PCIe driver" xwrite.cpp -o xwrite
	g++ -Wall -m32 -I "../SSI PCIe driver" xread.cpp -o xread
	g++ -Wall -m32 -I "../SSI PCIe driver" xtest.cpp -o xtest
	g++ -Wall -m32 -I "../SSI PCIe driver" xrate.cpp -o xrate -lpthread

clean:
	rm -f xstatus
	rm -f xreset
	rm -f xloop
	rm -f xwrite
	rm -f xread
	rm -f xtest
	rm -f xrate