.. _protocols_rssi_classes_server:

======
Server
======

``Server`` is the role-specific convenience wrapper that owns and wires the
RSSI ``Transport``, ``Application``, and ``Controller`` objects for server
operation.
For conceptual guidance, see :doc:`/built_in_modules/protocols/rssi/server`.

Threading and Lifecycle
=======================

- Delegates protocol-state execution to ``Controller`` and does not create a
  dedicated ``Server`` worker thread.
- Implements Managed Interface Lifecycle:
  :ref:`pyrogue_tree_node_device_managed_interfaces`


Python binding
--------------

This C++ class is also exported into Python as ``rogue.protocols.rssi.Server``.

Python API page:
- :doc:`/api/python/rogue/protocols/rssi/server`

objects in C++ are referenced by the following shared pointer typedef:

.. doxygentypedef:: rogue::protocols::rssi::ServerPtr

The class description is shown below:

.. doxygenclass:: rogue::protocols::rssi::Server
   :members:
