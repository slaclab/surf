.. _protocols_rssi_client:

====================
RSSI Protocol Client
====================

For RSSI links where Rogue should initiate and maintain the client side of the
connection, Rogue provides ``rogue::protocols::rssi::Client``. This is the
lower-level RSSI bundle used underneath wrappers such as
``pyrogue.protocols.UdpRssiPack``.

``Client`` bundles and wires:

- ``Transport`` on the lower link side
- ``Application`` on the upper payload side
- ``Controller`` for handshake, negotiation, retransmission, and state control

Construction
============

``Client(segSize)`` is shaped primarily by ``segSize``, the initial local
maximum segment size in bytes. In real deployments this is usually derived from
the lower transport payload budget, for example ``udp.maxPayload() - 8``.

Use ``transport()`` to connect the lower transport and ``application()`` to
connect upper protocol blocks such as packetizer or SRP.

Lifecycle And Runtime Controls
==============================

The wrapper exposes the RSSI control surface directly:

- ``start()`` / Python ``_start()``
  Start or restart connection establishment.
- ``stop()`` / Python ``_stop()``
  Stop the link.
- ``getOpen()``
  Report whether the link is open.
- ``setLocMaxBuffers()``, ``setLocMaxSegment()``, ``setLocRetranTout()``, and
  related methods
  Adjust local requested link parameters before or during operation.
- ``curMaxBuffers()``, ``curMaxSegment()``, and related methods
  Report the negotiated parameters actually in use.

The controller owns the actual protocol-state machine. ``Client`` is the
convenience wrapper that surfaces that state and the associated tuning APIs.

Threading And Lifecycle
=======================

- ``Client`` is a wrapper, not a separate transport thread owner.
- The internal ``Controller`` owns the RSSI protocol-state machine and link
  progression.
- The internal ``Application`` endpoint starts a background worker thread once
  the controller is attached.
- The lower ``Transport`` endpoint forwards received link frames directly into
  the controller.
- In Root-managed applications, register the RSSI objects with
  ``Root.addInterface(...)`` so Managed Interface Lifecycle handles startup and
  shutdown.
- In standalone scripts, call ``_start()`` and ``_stop()`` explicitly when no
  ``Root`` manages the link.

Managed Interface Lifecycle reference:
:ref:`pyrogue_tree_node_device_managed_interfaces`

Python Example
==============

.. code-block:: python

   import rogue.protocols.udp
   import rogue.protocols.rssi

   udp = rogue.protocols.udp.Client("127.0.0.1", 8200, True)
   rssi = rogue.protocols.rssi.Client(udp.maxPayload() - 8)

   # Link-layer stream connection.
   udp == rssi.transport()

   # Upper-layer payload connection.
   rssi.application() == app_transport

   # Start controller state machine.
   rssi._start()

Standalone script pattern:

.. code-block:: python

   udp = rogue.protocols.udp.Client("127.0.0.1", 8200, True)
   rssi = rogue.protocols.rssi.Client(udp.maxPayload() - 8)
   udp == rssi.transport()

   rssi._start()
   try:
       rssi.application() == app_transport
       # ... run application traffic ...
       pass
   finally:
       rssi._stop()
       udp._stop()

C++ Example
===========

.. code-block:: cpp

   #include <rogue/protocols/rssi/Client.h>

   namespace rpr = rogue::protocols::rssi;

   auto rssi = rpr::Client::create(segSize);
   lower_link == rssi->transport();
   rssi->application() == upper_layer;
   rssi->start();

Related Topics
==============

- :doc:`/built_in_modules/protocols/rssi/index`
- :doc:`server`
- :doc:`/built_in_modules/protocols/network`

API Reference
=============

- Python: :doc:`/api/python/rogue/protocols/rssi/client`
- C++: :doc:`/api/cpp/protocols/rssi/client`
