.. _protocols_rssi_classes_controller:

==========
Controller
==========

``Controller`` is the core RSSI protocol engine. It implements handshake/state
transitions, negotiated-parameter management, retransmission behavior, and
flow-control decisions while bridging ``Transport`` and ``Application`` paths.
For conceptual guidance, see :doc:`/built_in_modules/protocols/rssi/index`.

Threading and Lifecycle
=======================

- ``Controller`` owns protocol-state progression and internal worker behavior.
- Implements Managed Interface Lifecycle:
  :ref:`pyrogue_tree_node_device_managed_interfaces`


Controller objects in C++ are referenced by the following shared pointer typedef:

.. doxygentypedef:: rogue::protocols::rssi::ControllerPtr

The class description is shown below:

.. doxygenclass:: rogue::protocols::rssi::Controller
   :members:
