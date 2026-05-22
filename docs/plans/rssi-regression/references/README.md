# RSSI Reference Bundle

This directory holds local reference material for the RSSI regression task.
Use these files before reaching back to external sites or the Rogue checkout.

## Confluence
- `confluence/reliable-slac-streaming-protocol-rssi.html`
  - Local copy of the SLAC Confluence page:
    <https://confluence.slac.stanford.edu/spaces/ppareg/pages/211782868/Reliable+SLAC+Streaming+Protocol+RSSI>
  - This is the primary RSSI protocol reference for header format, connection
    behavior, parameter negotiation, data flow, retransmission, NULL segments,
    BUSY flow control, and known deviations from RUDP.
- `confluence/attachments/`
  - Local copies of the diagrams and Word export linked from the primary RSSI
    protocol page.
- `confluence/rssi-discussions.html`
  - Attempted local copy of:
    <https://confluence.slac.stanford.edu/spaces/ppareg/pages/198085574/RSSI+Discussions>
  - The retrieved page redirects to SLAC SSO from this environment.
- `confluence/rssi-discussions-viewpage.html`
  - Same page requested through `viewpage.action?pageId=198085574`; also
    redirects to SLAC SSO.
- `confluence/rssi-discussions-rest.json`
  - REST API retrieval attempt. The saved response shows rate limiting after
    the SSO redirects. Treat the RSSI Discussions content as not locally
    available until someone with authenticated Confluence access exports it.

## RFC And RUDP Background
- `rfc/rfc908.txt`
  - RFC 908, Reliable Data Protocol.
- `rfc/rfc1151.txt`
  - RFC 1151, Version 2 of the Reliable Data Protocol.
- `rfc/draft-ietf-sigtran-reliable-udp-00.txt`
  - Reliable UDP Protocol Internet-Draft.
- `rfc/draft-ietf-sigtran-reliable-udp-00.html`
  - Datatracker HTML copy of the same draft.

These are background references. The SLAC Confluence RSSI page and SURF/Rogue
implementation define the concrete RSSI subset under test.

## Rogue Documentation
- `rogue/built_in_protocols_rssi_index.rst`
- `rogue/built_in_protocols_rssi_client.rst`
- `rogue/built_in_protocols_rssi_server.rst`
- `rogue/built_in_protocols_network.rst`
- `rogue/api_cpp_protocols_rssi_*.rst`
- `rogue/api_python_rogue_protocols_rssi_index.rst`
- `rogue/api_python_pyrogue_network_udprssipack.rst`

These are copied from `/Users/bareese/rogue/docs/src/` and document how Rogue
uses RSSI in normal UDP/RSSI/packetizer deployments.

