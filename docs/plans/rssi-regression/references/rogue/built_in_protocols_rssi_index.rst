.. _protocols_rssi:

=============
RSSI Protocol
=============

For reliable, in-order stream delivery over an unreliable lower layer such as
UDP, Rogue provides ``rogue.protocols.rssi``. RSSI is the protocol layer that
adds connection management, retransmission, flow control, and parameter
negotiation on top of a lower transport.

In normal PyRogue applications, the usual way to bring up RSSI to an FPGA is
still :doc:`/built_in_modules/protocols/network`. The direct
``rogue.protocols.rssi`` classes are the lower-level pieces to use when you
need custom protocol wiring, explicit debugging, or a stack that is not built
by ``pyrogue.protocols.UdpRssiPack``.

Rogue's RSSI implementation uses sequence and acknowledge exchange,
retransmission, timeout handling, and negotiated link parameters to maintain a
stable stream. Conceptually, RSSI follows the Reliable Data Protocol lineage
described in RFC 908 and RFC 1151.

Protocol Documentation
======================

- RSSI protocol reference: https://confluence.slac.stanford.edu/x/1IyfD
- Additional SLAC RSSI notes: https://confluence.slac.stanford.edu/x/xovOCw

The protocol reference links to the relevant RFC background used by RSSI's
reliability model (sequencing, acknowledgments, retransmission, and timeout
behavior).

Where RSSI Fits In The Stack
============================

Typical protocol stack:

.. code-block:: text

   UDP <-> RSSI <-> Packetizer <-> Application logic

RSSI is the layer that adds reliability and ordered delivery. Packetizer, SRP,
or other upper protocols then sit above the RSSI application side.

Key Classes
===========

The ``rogue::protocols::rssi`` classes are layered as follows:

- ``Client`` / ``Server``:
  convenience wrappers that instantiate and wire the full stack for each role.
- ``Controller``:
  the protocol state machine; performs handshake, negotiation, ACK handling,
  retransmission policy, and flow-control decisions.
- ``Transport``:
  lower stream edge carrying RSSI frames to/from the underlying transport link.
- ``Application``:
  upper stream edge carrying payload frames to/from application protocols.
- ``Header``:
  helper codec/container for parsing and encoding RSSI frame headers.

The convenience wrappers wire these pieces as:

.. code-block:: text

   [Underlying link] <-> Transport <-> Controller <-> Application <-> [Upper protocol]

Lifecycle And Threading
=======================

- Root-managed mode:
  Add interfaces to a ``Root`` with ``Root.addInterface(...)`` and let
  Managed Interface Lifecycle handle startup/shutdown.
- Standalone script mode:
  For direct stream-graph scripts without a ``Root``, start/stop RSSI
  endpoints explicitly in application code.
- Managed Interface Lifecycle reference:
  :ref:`pyrogue_tree_node_device_managed_interfaces`
- ``Controller`` owns RSSI connection state and protocol progression.
- ``Application`` starts a background worker thread once a controller is
  attached.
- ``Transport`` is the lower stream edge and forwards frames directly into the
  controller.

When To Use The Direct RSSI Classes
===================================

- You need the reliable-stream layer but want to build the full stack yourself.
- You are debugging or instrumenting the RSSI layer separately from the
  ``UdpRssiPack`` wrapper.
- Your lower transport is not hidden behind the PyRogue network wrapper.

For typical FPGA-facing links in PyRogue, prefer
:doc:`/built_in_modules/protocols/network` unless you need this lower-level
control.

Python Example
==============

The most common PyRogue-facing form is still ``pyrogue.protocols.UdpRssiPack``:

.. code-block:: python

   import pyrogue as pr
   import pyrogue.protocols
   import rogue.protocols.srp

   class MyRoot(pr.Root):
       def __init__(self):
           super().__init__(name='MyRoot')

           self.add(pyrogue.protocols.UdpRssiPack(
               name='Net',
               server=False,
               host='10.0.0.5',
               port=8192,
               jumbo=True,
               packVer=2,
               enSsi=True,
           ))
           self.addInterface(self.Net)

           srp = rogue.protocols.srp.SrpV3()
           self.Net.application(dest=0) == srp

           # Example device using SRP as memBase
           # self.add(MyDevice(name='Dev', offset=0x0, memBase=srp))

For custom wiring or lower-level debugging, instantiate the direct RSSI
classes explicitly. The following pattern shows the usual lower-level stack
shape:

.. code-block:: python

   import rogue.protocols.udp
   import rogue.protocols.rssi
   import rogue.protocols.packetizer

   # Server side
   s_udp = rogue.protocols.udp.Server(0, True)
   s_rssi = rogue.protocols.rssi.Server(s_udp.maxPayload() - 8)
   s_pack = rogue.protocols.packetizer.CoreV2(True, True, True)

   s_udp == s_rssi.transport()
   s_rssi.application() == s_pack.transport()

   # Client side
   c_udp = rogue.protocols.udp.Client("127.0.0.1", s_udp.getPort(), True)
   c_rssi = rogue.protocols.rssi.Client(c_udp.maxPayload() - 8)
   c_pack = rogue.protocols.packetizer.CoreV2(True, True, True)

   c_udp == c_rssi.transport()
   c_rssi.application() == c_pack.transport()

   s_rssi._start()
   c_rssi._start()
   # ... run traffic ...
   c_rssi._stop()
   s_rssi._stop()

C++ Example
===========

.. code-block:: cpp

   #include <rogue/protocols/udp/Client.h>
   #include <rogue/protocols/udp/Server.h>
   #include <rogue/protocols/rssi/Client.h>
   #include <rogue/protocols/rssi/Server.h>

   namespace rpu = rogue::protocols::udp;
   namespace rpr = rogue::protocols::rssi;

   auto sUdp  = rpu::Server::create(0, true);
   auto sRssi = rpr::Server::create(sUdp->maxPayload() - 8);

   auto cUdp  = rpu::Client::create("127.0.0.1", sUdp->getPort(), true);
   auto cRssi = rpr::Client::create(cUdp->maxPayload() - 8);

   sUdp == sRssi->transport();
   cUdp == cRssi->transport();

   sRssi->start();
   cRssi->start();

Logging
=======

RSSI protocol-state logging is emitted by the internal controller via Rogue C++
logging.

Static logger name:

- ``pyrogue.rssi.controller``
- Unified Logging API:
  ``pyrogue.setLogLevel('pyrogue.rssi', 'DEBUG')``
- Legacy Logging API:
  ``rogue.Logging.setFilter('pyrogue.rssi', rogue.Logging.Debug)``

This is the most useful logger when debugging link bring-up, retransmission,
and state transitions. The ``Client`` and ``Server`` wrappers themselves do not
add a separate module-specific logger.

Related Topics
==============

- :doc:`/built_in_modules/protocols/network`
- :doc:`/built_in_modules/protocols/udp/index`
- :doc:`/built_in_modules/protocols/packetizer/index`
- :doc:`/built_in_modules/protocols/srp/index`

API Reference
=============

- C++: :doc:`/api/cpp/protocols/rssi/index`
- Python:
  :doc:`/api/python/rogue/protocols/rssi/application`
  :doc:`/api/python/rogue/protocols/rssi/transport`
  :doc:`/api/python/rogue/protocols/rssi/client`
  :doc:`/api/python/rogue/protocols/rssi/server`

.. toctree::
   :maxdepth: 1
   :caption: RSSI Protocol

   client
   server
