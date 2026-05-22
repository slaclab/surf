.. _protocols_rssi_classes_header:

======
Header
======

``Header`` is a helper codec/container for RSSI header fields. It parses frame
bytes into structured fields (`verify()`), and encodes fields back into frame
bytes with updated checksum (`update()`).
For conceptual guidance, see :doc:`/built_in_modules/protocols/rssi/index`.


Header objects in C++ are referenced by the following shared pointer typedef:

.. doxygentypedef:: rogue::protocols::rssi::HeaderPtr

The class description is shown below:

.. doxygenclass:: rogue::protocols::rssi::Header
   :members:
