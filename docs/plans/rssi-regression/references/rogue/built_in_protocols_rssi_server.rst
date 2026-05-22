.. _protocols_rssi_server:

====================
RSSI Protocol Server
====================

For RSSI links where Rogue should wait for the remote side and run the server
side of the handshake, Rogue provides ``rogue::protocols::rssi::Server``.
This is the lower-level server bundle used underneath wrappers such as
``pyrogue.protocols.UdpRssiPack`` when that wrapper runs in server mode.

``Server`` bundles and wires:

- ``Transport`` on the lower link side
- ``Application`` on the upper payload side
- ``Controller`` for handshake, negotiation, retransmission, and state control

Construction
============

``Server(segSize)`` is shaped primarily by ``segSize``, the initial local
maximum segment size in bytes. As with the client side, this is typically
derived from the lower transport payload budget.

Use ``transport()`` to connect the lower transport and ``application()`` to
connect upper protocol blocks.

Lifecycle And Runtime Controls
==============================

The server bundle exposes the same RSSI control surface as the client bundle:

- ``start()`` / Python ``_start()``
  Start or restart connection establishment.
- ``stop()`` / Python ``_stop()``
  Stop the link.
- ``getOpen()``
  Report whether the link is open.
- Local parameter setters such as ``setLocMaxSegment()`` and
  ``setLocRetranTout()``
  Control the requested server-side link parameters.
- Negotiated-parameter getters such as ``curMaxSegment()``
  Report the active values after negotiation.

The controller owns the actual protocol-state machine. ``Server`` is the
convenience wrapper that surfaces that state and the associated tuning APIs.

Threading And Lifecycle
=======================

- ``Server`` is a wrapper, not a separate transport thread owner.
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

   udp = rogue.protocols.udp.Server(0, True)
   rssi = rogue.protocols.rssi.Server(udp.maxPayload() - 8)

   # Link-layer stream connection.
   udp == rssi.transport()

   # Upper-layer payload connection.
   rssi.application() == app_transport

   # Start controller state machine.
   rssi._start()

Standalone script pattern:

.. code-block:: python

   udp = rogue.protocols.udp.Server(0, True)
   rssi = rogue.protocols.rssi.Server(udp.maxPayload() - 8)
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

   #include <rogue/protocols/rssi/Server.h>

   namespace rpr = rogue::protocols::rssi;

   auto rssi = rpr::Server::create(segSize);
   lower_link == rssi->transport();
   rssi->application() == upper_layer;
   rssi->start();

Related Topics
==============

- :doc:`/built_in_modules/protocols/rssi/index`
- :doc:`client`
- :doc:`/built_in_modules/protocols/network`

API Reference
=============

- Python: :doc:`/api/python/rogue/protocols/rssi/server`
- C++: :doc:`/api/cpp/protocols/rssi/server`
