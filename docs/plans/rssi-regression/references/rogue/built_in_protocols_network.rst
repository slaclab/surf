.. _protocols_network:

===============
Network Wrapper
===============

For building a standard UDP, RSSI, and packetizer stack under one tree-managed
object, PyRogue provides ``pyrogue.protocols.UdpRssiPack``. It wires together
the underlying ``rogue.protocols.udp.*``, ``rogue.protocols.rssi.*``, and
``rogue.protocols.packetizer.*`` modules internally.

For software that needs to connect to an FPGA RSSI endpoint, this is almost
always the module to use. In most deployed systems, ``UdpRssiPack`` is the
standard wrapper for register links and data links built on UDP and RSSI.

For the underlying protocol behavior, see :ref:`protocols_udp`,
:ref:`protocols_rssi`, and :ref:`protocols_packetizer`.

Overview
========

``pyrogue.protocols.UdpRssiPack`` is a convenience ``pyrogue.Device`` that
bundles the network stack used by many Rogue and PyRogue systems:

* UDP transport (``rogue.protocols.udp.Client`` or ``Server``)
* RSSI reliability layer (``rogue.protocols.rssi.Client`` or ``Server``)
* Packetizer framing (``rogue.protocols.packetizer.Core`` or ``CoreV2``)

Internally, it wires the stream graph as:

.. code-block:: text

   UDP <-> RSSI Transport <-> RSSI Application <-> Packetizer

Because it is a ``pyrogue.Device``, RSSI status and configuration variables are
exposed directly in the PyRogue tree.

Implementation Details
======================

- ``server=False``:
  Creates ``udp.Client(host, port, jumbo)`` and ``rssi.Client(...)``.
- ``server=True``:
  Creates ``udp.Server(port, jumbo)`` and ``rssi.Server(...)``.
- Packetizer selection by ``packVer``:
  ``packVer=1`` uses ``packetizer.Core(enSsi)``;
  ``packVer=2`` uses ``packetizer.CoreV2(False, True, enSsi)``.
- RSSI segment size is derived from transport payload budget:
  ``udp.maxPayload() - 8``.

When To Use
===========

Use ``UdpRssiPack`` when you want:

* A standard UDP + RSSI + packetizer stack with minimal setup code
* Link status/counters in the PyRogue variable tree
* Start/stop lifecycle managed through the Root interface mechanism

For most hardware systems (software talking to an FPGA RSSI endpoint), use
``server=False`` so Rogue acts as the RSSI/UDP client and connects outbound to
the FPGA target.

Key Constructor Arguments
=========================

* ``server``:
  Choose server mode (``True``) or client mode (``False``). Typical FPGA
  register/data links use ``False``.
* ``host``/``port``:
  Remote endpoint for client mode, or bind port for server mode.
* ``jumbo``:
  Enable jumbo-MTU path assumptions in UDP setup.
* ``packVer``:
  Packetizer version, ``1`` or ``2``.
* ``enSsi``:
  Enable SSI handling in packetizer.
* ``wait``:
  In client mode, wait for RSSI link-up during startup.
* ``defaults`` (via ``kwargs``):
  Optional RSSI parameter overrides such as ``locMaxBuffers``,
  ``locCumAckTout``, ``locRetranTout``, ``locNullTout``,
  ``locMaxRetran``, ``locMaxCumAck``.

In practice, real trees usually only set ``host``, ``port``, ``packVer``,
``jumbo``, and sometimes ``enSsi``. The local example roots in this repository
and nearby Rogue-based projects follow that pattern, often instantiating one
``UdpRssiPack`` for SRP traffic and another for event data.

Startup Behavior
================

During ``UdpRssiPack._start()``:

- RSSI is started first.
- In client mode with ``wait=True``, startup waits for link-open.
- After link bring-up, UDP RX buffer count is tuned from negotiated RSSI
  buffer depth (``udp.setRxBufferCount(rssi.curMaxBuffers())``).

This startup behavior is why using the wrapper through Root-managed lifecycle
is preferred for full applications.

Typical Root Integration
========================

Use ``add()`` to place the wrapper in the tree, then ``addInterface()`` so
Root start/stop sequencing manages the transport lifecycle.

.. code-block:: python

   import pyrogue as pr
   import pyrogue.protocols
   import pyrogue.utilities.fileio
   import rogue.protocols.srp

   class MyRoot(pr.Root):
       def __init__(self):
           super().__init__(name='MyRoot')

           # Add bundled UDP + RSSI + packetizer stack.
           self.add(pyrogue.protocols.UdpRssiPack(
               name='Net',
               server=False,
               host='10.0.0.5',
               port=8192,
               jumbo=True,
               packVer=2,
               enSsi=True,
           ))
           # Register managed interface lifecycle with Root.
           self.addInterface(self.Net)

           # VC 0: register/memory path (for Device memBase)
           srp = rogue.protocols.srp.SrpV3()
           self.Net.application(dest=0) == srp

           # VC 1: data path to file writer
           self.add(pyrogue.utilities.fileio.StreamWriter(
               name='DataWriter'
           ))
           self.Net.application(dest=1) >> self.DataWriter.getChannel(1)

           # Example memory-mapped device:
           self.add(MyDevice(name='Dev', memBase=srp, offset=0x0))

Lifecycle Notes
===============

- Root-managed mode:
  Add ``UdpRssiPack`` to the tree and register it via ``Root.addInterface(...)``.
- Standalone mode:
  Direct scripts can call wrapper ``start``/``stop`` commands (or ``_start`` /
  ``_stop``) when no Root lifecycle manager is present.
- Managed Interface Lifecycle reference:
  :ref:`pyrogue_tree_node_device_managed_interfaces`

Server Mode (Less Common)
=========================

``server=True`` is typically used for software peer links, integration tests,
or cases where the remote endpoint must initiate the connection to Rogue.
This is not the common deployment for FPGA RSSI endpoints.

.. code-block:: python

   self.add(pyrogue.protocols.UdpRssiPack(
       name='Net',
       server=True,
       port=8192,
       jumbo=True,
       packVer=2,
       enSsi=True,
   ))
   self.addInterface(self.Net)

Available Helper Methods/Commands
=================================

* ``application(dest)``:
  Return packetizer application endpoint for a destination VC.
* ``countReset()``:
  Reset RSSI counters.
* ``start`` / ``stop``:
  Local commands exported by the wrapper device for link control.

Logging
=======

``UdpRssiPack`` itself is a PyRogue ``Device``, so any wrapper-level Python log
messages follow normal PyRogue logger naming. Most transport/protocol debug
output, however, comes from the underlying Rogue C++ modules:

- ``pyrogue.udp.Client`` / ``pyrogue.udp.Server``
- ``pyrogue.rssi.controller``
- ``pyrogue.packetizer.Controller``

- Unified Logging API:
  ``pyrogue.setLogLevel('pyrogue.udp', 'DEBUG')``,
  ``pyrogue.setLogLevel('pyrogue.rssi', 'DEBUG')``, and
  ``pyrogue.setLogLevel('pyrogue.packetizer', 'DEBUG')``
- Legacy Logging API:
  ``rogue.Logging.setFilter('pyrogue.udp', rogue.Logging.Debug)``,
  ``rogue.Logging.setFilter('pyrogue.rssi', rogue.Logging.Debug)``, and
  ``rogue.Logging.setFilter('pyrogue.packetizer', rogue.Logging.Debug)``

In practice, enable the underlying protocol loggers rather than relying on any
wrapper-level Python logging when debugging link behavior.

Relationship To The Lower-Level Modules
=======================================

``UdpRssiPack`` is the right page when you want the preassembled wrapper and
tree-visible RSSI controls. If you need to reason about the transport behavior
itself, or to build a custom stack without the wrapper, move to the direct
protocol pages for UDP, RSSI, and packetizer. Those pages stay focused on the
underlying ``rogue.protocols.*`` modules rather than on the convenience device.

Related Topics
==============

* :ref:`protocols_rssi`
* :ref:`protocols_udp`
* :ref:`protocols_packetizer`

API Reference
=============

- Python:

  - :doc:`/api/python/pyrogue/protocols/network_udprssipack`
