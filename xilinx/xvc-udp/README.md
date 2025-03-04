XVC Debugging
=======================================

The FW instantiates a Debug Bridge (`AxisJtagDebugBridge`)
component from the SURF library (see surf/protocols/jtag/README.md) and
connects it to a UDP server at port 2542.

The FW provides two DCP modules which the application
can 'plug' into the debug bridge instantiation:

      ________________________
     |       Firmware         |       Stub DCP      'Real' DCP
     |   _____                |         _____         ____
     |  |_   |_  Debug Bridge |        |_   |_       |_   |_
     |   _|XXX_| (Black Box   |         _|stub|       _|impl|
     |  |____|    Component)  |        |____|        |____|
     |________________________|

- A stub module which does not actually instantiate a debug bridge.
  It merely terminates the AXI Stream and replies to QUERY commands
  with an error code.

- A 'true' Axis Debug Bridge.

The Application's `Makefile` may define the environment variable

    export USE_XVC_DEBUG = 1

if it wishes to use the real debug bridge. If this variable is undefined
(default) or zero then the stub DCP is used.

*Note:* If `USE_XVC_DEBUG` is set to `-1` then *the debug bridge
is left as a black box* and it is the application's responsibility to define
a suitable implementation.
