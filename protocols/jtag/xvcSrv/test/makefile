all: test

testDataTdoOnly.txt: testData.txt
	$(RM) $@
	grep TDO $^ > $@

clean:
	$(RM) testDataTdoOnly.txt

test: ../src/xvcSrv test.py testDataTdoOnly.txt
	sh -c "(./xvcSrv -D udpLoopback -o -t testDataTdoOnly.txt & sleep 1 ; python3 test.py -k)"
