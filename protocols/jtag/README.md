AXI Stream to JTAG Core
=======================

This package implements a component which drives a JTAG port from data
send over an AXI Stream.

Motivation
----------

Xilinx Vivado ILAs are accessed over JTAG but in many cases using a physical
JTAG connection is impractical. Recent versions of Vivado support the Xilinx
"virtual cable" protocol [XVC](https://www.xilinx.com/products/intellectual-property/xvc.html)
which is very simple and permits remote access to embedded ILA cores.

However, the protocol and its current support in Vivado has several drawbacks

  - Fully synchronous, i.e., the reply to one request must be received before
    the next one is sent.
  - TCP based. This makes an in-firmware implementation cumbersome and more
    resource-intensive.
  - The AXI <-> JTAG bridge which is available as an IP in Vivado is inefficient
    and requires AXI. In some use cases the AXI interface is already "owned"
    by an application and a second master to be used by XVC is not available.

For the Impatient
-----------------

1) Add the AxisJtagDebugBridge module to your design; hook up to an AXI Stream.
   This should probably be a UDP server.
   Note that there are two VHDL 'architectures' of this module ('entity') -
   a stub (`AxisJtagDebugBridgeStub`) and the true implementation:
   `AxisJtagDebugBridgeImpl`. The stub will be used by default by Vivado so you
   have to explicitly specify the `AxisJtagDebugBridgeImpl` architecture for
   instantiation.
2) Add ILA cores; under Vivado-2016.04 these *must* be added to the hdl and
   cannot be added to an already synthesized design!
3) Compile and install the `xvcSrv` program on a machine that is directly
   connected to FW.
4) Start `xvcSrv` (`udp_server_port` is where the AXI Stream is connected)

       xvcSrv -t <fw_ip_address>:<udp_server_port>

5) In Vivado connect to the target:

       open_hw_target -xvc_url <xvc_server_ip>:2542

Design Goals
------------

The package addresses the aforementioned issues:

  - Use a simple AXI Stream for communication. Unlike a register-based approach
    this permits processing of larger messages which improves throughput.

    In our enviroment where registers are accessed via ethernet the Vivado bundled IP
    is particularly inefficient as for every 32 bits of JTAG data there must be
    multiple register writes and reads, each of which requires a network transaction.

  - The firmware can be configured to enable a memory buffer. This buffer is used
    to support unreliable transport media (such as UDP). Each message is sent to
    the firmware tagged with a "transaction ID". If no reply arrives the same 
    message (with the same ID) is re-sent. The firmware, upon receiving a new ID
    drives JTAG, remembers the transaction ID and stores the TDO vector in the buffer
    while sending it back. If firmware receives the same ID again (supposedly because
    the reply was lost) it does *not* execute the JTAG vectors again but "plays back"
    the stored TDO data from memory (JTAG transactions are not idempotent).

  - The firmware core can easily be hooked to a separate UDP server port which 
    allows orthogonal access to JTAG with minimal FPGA resource overhead.

Note that the firmware does *not* directly implement the XVC protocol (since that
would require in-firmware TCP support) but a slightly modified variant which is
documented below. Instead, there is a software program which operates as an XVC
server and acts as a bridge to the firmware. Different transport methods can
be employed for communication between firm-and software:

                                                    
    | Xilinx hw_server | <--- XVC / TCP --> | xvcSrv SW | <- transport -> | AxisToJtag FW |


Examples for transport methods are UDP or an AXI/AXIS Fifo on a Zynq platform.

It is imperative that the xvcSrv software be as tightly coupled to the AXI Stream
as possible for sake of optimal throughput.

Other Uses
----------

While the most common use case may be establishing connectivity to a Xilinx
debug hub the package is not restricted to this use case -- it is suitable as
a general-purpose JTAG controller.
                                                    
Firmware Configuration and Use
------------------------------

There are two top-level wrappers `AxisToJtag` and `AxisJtagDebugBridge` which support
the same generics and the same streaming interface. For convenience the latter
variant already instantiates a JTAG to BSCAN IP and connects to its JTAG port.

### Architectures
There are two VHDL architectures of the `AxisJtagDebugBridge` entity: 
`AxisJtagDebugBridgeStub` and `AxisJtagDebugBridgeImpl`. While the latter provides the
real implementation described in this document the stub only implements
the QUERY command and replies with a `ERR_NOT_PRESENT_C` error, thus informing
a software client that firmware support is not implemented.

The stub appears after the full implementation in the source code so that it
is picked by default by the synthesis tool if `AxisJtagDebugBridge` is
instanitated without specifying an architecture.
Therefore, the user has to explicitly request the `AxisJtagDebugBridgeImpl`
architecture.

The purpose of the stub is allowing a design to unconditionally provide
the upstream components but optionally use either the stub or the real
implementation for sake of saving resources or avoiding the limitations
(see below) associated with the JTAG to BSCAN IP.

### Generics

    AXIS_FREQ_G  : real
    AXIS_WIDTH_G : positive range 4 to 16
    CLK_DIV2_G   : positive
    MEM_DEPTH_G  : natural range 0 to 65535
    MEM_STYLE_G  : string

  - `AXIS_FREQ_G`: The value of the clock frequency (in Hz). This information is
    used to communicate the JTAG TCK period back to the XVC protocol.

  - `AXIS_WIDTH_G`: The width (in bytes) of the AXI Stream. Note that this affects
    the format of the data that the xvcSrv software must supply (see section about
    stream format).

  - `CLK_DIV2_G`: Clock divider for generating TCK. The value defines the length
    of a TCK *half-period*. I.e., the frequency is the AXI Stream clock divided by
    twice `CLK_DIV2_G`.

    Note: TCK is "bit-banged", i.e., *not* generated by a true clock source -- however,
    inspection of the circuit the vivado AXI<->BSCAN IP implements reveals that they
    use the same approach -- even though the BSCAN module does not sample TCK but
    drive register clocks directly from it. A question has been filed with Xilinx
    but no answer has been received to date.

  - `MEM_DEPTH_G`: how many words (of size `AXIS_WIDTH_G`) of TDO data to store
    (in order to support unreliable transport). This limits the maximum message size
    that can be processed at once. If the transport between the XVC server and FW
    is reliable then `MEM_DEPTH_G` may be set to zero (no memory).

  - `MEM_STYLE_G`: memory type (block- vs. distributed RAM) to use for the buffer memory.
    Valid choices are: "auto", "block" or "distributed" (defaults to "auto").

### Ports

There are standard clock/reset as well as AXI Stream signals.

Software (xvcSrv)
-----------------

The `xvcSrv` software must be installed and executed on a machine with
connectivity to the firmware. The basic options for execution are:

    xvcSrv [-D transport_driver] -t <target> [ -- <driver_options> ]

where `<target>` is a string that passes information to the transport driver
how to reach the firmware target. In case of the "udp" transport (which is
the default) `target` is a `<ip_addr>:<udp_port>` string, thus, e.g.,

    xvcSrv -t 192.168.2.10:8196

The local TCP port is 2542 by default but can be changed with the `-p` option.

Other Options:

    -h             : program prints basic usage information to the console.
    -v             : print protocol parameter info (retrieved from target).
                     Multiple 'v' can be given to increase debugging verbosity.
    -D <driver>    : use/load transport driver <driver>. E.g., `/path/myDriver.so`.
    -p <port>      : TCP port where to listen for XVC connections.
    -M             : Max XVC vectors size. This defines the max. block size
                     to be used on the TCP side (it is beneficial to let this
                     be big!).
                     The block size between the driver and the target may well
                     be smaller (and xvcSrv will break transactions accordingly)
                     due to limits in the transport (e.g., UDP/ethernet MTU) or
                     firmware memory. However, if xvcSrv is tightly coupled
                     to the target then using large blocks on TCP is desirable
                     in order to mitigate TCP round-trip times.
    --             : Delimiter; any options (and args) after '--' are passed to
                     and interpreted by the transport driver.

### Transport drivers

Other transport drivers can be easily implemented and compiled into shared
objects which can then be loaded. As an example there is the xvcDrvAxisFifo.cc
file which supports a custom AXI Stream FIFO but illustrates what needs to be
done. The `xvcDriver.h` header gives more information about implementing a
driver.

If you have a driver, e.g., `myDriver.so` then you can start the server

    xvcSrv -D ./myDriver.so -t my_driver_info

#### UDP Transport Driver

The UDP Transport driver is built-in and used by default. The target
string must be of the form (udp port 2542 is used by default):

    <target_ip>[:<udp_port]

The driver recognizes the following options (given to `xvcSrv` after `--`)

    -m <mtu>       : Limit UDP datagrams to less than <mtu> octets. By default
                     the program tries to guess the MTU size but in some cases
                     it might be necessary to override this default.

                     Note that xvcSrv sets the DF (dont-fragment) bit on the
                     UDP connection, so that UDP datagrams are never broken up.
                     (firmware does not support IP defragmentation AFAIK.)
                     
    -f             : Disable DF; i.e., allow IP fragmentation.

Vivado Notes
------------

#### Connecting Vivado Hardware Manager to the XVC Server

From vivado (e.g., tcl console in the hardware manager) a connection to the
`xvcSrv` can be established with

    open_hw_target -xvc_url <xvcSrvHost>:2542

If the port xvcSrv binds to was changed (with -p) then the port passed to
`open_hw_target` must be changed accordingly.

*Note*: When using an ssh tunnel (or another kind of WAN connection) then it
seems to be better to run a `hw_server` close to the target, i.e., the
machine where `xvcSrv` runs. This gives better response than connecting
from far away to the XVC server directly. E.g.,:

    bash$  ssh -tt -L3121:localhost:3121 gateway_host hw_server

and in Vivado you proceed as usual, i.e., connect to the default
server (which is now visible at tcp port 3121) and open a xvc target:

    %open_hw_server -url     localhost:3121
    %open_hw_target -xvc_url <xvcSrvHost>:2542


#### Limitation of ILA Design Flow in Vivado 2016.04

When trying to add ILAs to a synthesized design (e.g., via tcl `create_debug_core`)

>
>     Vivado% create_debug_core ila_test ila
>     ERROR: [Common 17-69] Command failed: This design contains a
>     debug_bridge IP configured in either 'From_AXI_to_BSCAN' or
>     'From_JTAG_to_BSCAN' mode. Debug insertion is not currently supported
>     for such designs. Please use the debug instantiation flow. 

Therefore, under 2016.04 you can only use XVC when instantiating ILAs
into your hdl code.

A basic test under 2017.03 indicated that this limitation has been removed.

Unfortunately, however, even under 2017.03 and 2017.04 it is not possible
to add debug ports to ILAs added by `create_debug_core` -- the old error
message appears -- and you are limited to a single port (the width of which
you can change just fine).

Since the ILA with a single port works just fine we believe the restriction
to a single port to be a simple bug (failure to remove an obsolete check).
Contact the authors for more information.

Appendix
========

Stream Format
-------------

The format of the JTAG vectors in the AXI stream deviates from the XVC layout
because the original layout is not well-suited for streaming as XVC transmits
the TMS and TDI vectors one after the other whereas they have to be driven
onto the JTAG lines in parallel. For streaming we use the following format:

    header_word [ , payload ]

where the payload depends on the type of transaction that is executed. All words
are in little-endian, i.e., LSbits are transmitted/received first (on JTAG).

The 32 least-significant bits of the header are defined; it is left-padded
so that the payload is always word aligned. The word size depends on the
configuration of the core (`AXIS_WIDTH_G`).

### INCOMING STREAM

The incoming Stream consists of consecutive words of `AXIS_WIDTH_G` bytes,
must be framed with `TLAST` and is expected to have the aforementioned format :

    Header_Word [, Payload ]

The header word is defined as

    [31:30]  Protocol Version -- currently "00"
    [29:28]  Command
    [27:00]  Command-specific parameter(s)

Note that if the core is configured for a stream width (`AXIS_WIDTH_G`) > 4
then the header is padded up to the desired width, i.e., the paylod must
be word-aligned.

Each command word is answered with a reply word on the outgoing stream
(see below).

The following commands are currently defined:

    "00"  QUERY: request basic features such as word length, memory depth.

          Payload: NONE, i.e., TLAST should be asserted with this command.

    "01"  JTAG: shift jtag vectors. The vectors are shipped in the payload.
          The parameter bits for this command are defined as follows:

          [27:20] Transaction ID; this is used when the core is configured
                  with MEM_DEPTH_G > 0 in order to support a non-reliable
                  transport.
          [19:00] JTAG vector length (in bits). The payload must provide
                  2*ceil( length / AXIS_WIDTH_G ) words of TMS/TDI vector
                  data. I.e., the length refers to the length of a single
                  TMS or TDI vector.
                  !!!!!!!
                   NOTE: the number in [19:00] encodes the actual number
                         minus 1. E.g., a value of 0 transmits one TMS
                         and one TDI bit. Two payload words are expected
                         in this example.
                  !!!!!!!

          Payload: sequence of words from the TMS and TDI bit-vectors:

                  TMS_WORD, TDI_WORD, TMS_WORD, TDI_WORD, ...

                  Note that the user must format the stream accordingly
                  and therefore must be aware of the stream width. This
                  parameter is returned by the QUERY command.

                  If the number of bits supplied does not fill the last
                  word then the relevant bits must be lsb/right-aligned
                  in the last word.

                  TLAST must be asserted during the transmission of the
                  last TDI/payload word.

### OUTGOING STREAM

The outgoing stream consists of consecutive words of `AXIS_WIDTH_G` bytes
and is framed with `TLAST`. Each reply has the following format:

     Header Word [, Payload ]

The header word is defined as

    [31:30]  Protocol Version; if the user supplies an unsupported protocol
             version in the request header then the reply contains an error
             code (see below) and the protocol version in the reply is set
             to the supported version.

    [29:28]  Command -- the request command is returned unless an error occurred;
             in case of an error the command bits in the reply are:
 
             "10"  ERROR: An error was detected. The 8 least-significant bits
                   [7:0] contain an error code:
                      1: bad protocol version; the protocol version in the reply
                         is set to the supported version.
                      2: bad/unsupported command code
                      3: truncated input stream (TLAST detected before the
                         first TDI word was received). Note that a premature
                         TLAST which is detected after the first TDI word
                         does NOT flag an error but yields a truncated reply
                         (less TDO words than requested by the number of bits).
                      4: 'debug bridge not present' error. I.e., the FW only
                         implements a stub and no true debug bridge.


             "00"  QUERY: the response to a QUERY command encodes information
                         in the command-specific bits:

                 [ 3: 0] AXIS_WIDTH_G - 1. I.e., this field encodes the
                         word size (minus one) used by the core. This information
                         is important for formatting the stream.
                 [19: 4] MEM_DEPTH_G. Indicates how much memory (if any) was
                         configured in words.
                 [27:20] TCK period. Encoded as

                                          200Mhz     1
                            round{ log10( ------- ) --- 256 }
                                           Ttck      4

                        With the special value 0 representing 'unknown'.


            "01"  JTAG: the response to a JTAG command is a sequence of
                  TDO words which form the TDO bit vector. The vector
                  stored in little-endian format (first bit of the vector
                  is the LSB of the first TDO word).
                  If the number of JTAG bits does not fill the last TDO
                  word completely then the relevant bits are right-
                  aligned.

### RELIABILITY SUPPORT

If the transport mechanism contains unreliable segments with a potential for
data loss then a simple retry mechanism is not suitable because JTAG operations
are not necessarily idempotent.
The core can be configured to use internal memory (`MEM_DEPTH_C > 0`) in which
case it stores the last JTAG TDO response in memory.
When the next JTAG command arrives the core inspects the 'transaction ID' field
of the command and if it is identical with the ID submitted along with the previous
transaction then the core detects a retried operation and does not actually execute
it again on JTAG but plays back the stored TDO response to the requestor.
