SSI_PCIE_HOME := $(shell pwd)
SSI_PCIE_KVER := $(shell uname -r)

obj-m := SsiPcie.o

all:
	make -C /lib/modules/$(SSI_PCIE_KVER)/build M=$(SSI_PCIE_HOME) modules

clean:
	make -C /lib/modules/$(SSI_PCIE_KVER)/build M=$(SSI_PCIE_HOME) clean
