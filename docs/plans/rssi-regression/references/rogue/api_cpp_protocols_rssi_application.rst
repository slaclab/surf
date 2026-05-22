.. _protocols_rssi_classes_application:

===========
Application
===========

``Application`` is the upper RSSI stream endpoint. It carries payload frames
between user protocol layers and the RSSI controller.
For conceptual guidance, see :doc:`/built_in_modules/protocols/rssi/index`.


Python binding
--------------

This C++ class is also exported into Python as ``rogue.protocols.rssi.Application``.

Python API page:
- :doc:`/api/python/rogue/protocols/rssi/application`

objects in C++ are referenced by the following shared pointer typedef:

.. doxygentypedef:: rogue::protocols::rssi::ApplicationPtr

The class description is shown below:

.. doxygenclass:: rogue::protocols::rssi::Application
   :members:
