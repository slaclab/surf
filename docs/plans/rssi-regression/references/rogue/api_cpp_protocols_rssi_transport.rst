.. _protocols_rssi_classes_transport:

=========
Transport
=========

``Transport`` is the lower RSSI stream endpoint. It exchanges RSSI frames
between the controller and the underlying link transport.
For conceptual guidance, see :doc:`/built_in_modules/protocols/rssi/index`.


Python binding
--------------

This C++ class is also exported into Python as ``rogue.protocols.rssi.Transport``.

Python API page:
- :doc:`/api/python/rogue/protocols/rssi/transport`

objects in C++ are referenced by the following shared pointer typedef:

.. doxygentypedef:: rogue::protocols::rssi::TransportPtr

The class description is shown below:

.. doxygenclass:: rogue::protocols::rssi::Transport
   :members:
