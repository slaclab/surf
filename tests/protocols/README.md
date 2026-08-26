# Protocol Regression Guidance

Protocol tests follow the repository-wide [cocotb regression style
guide](../README.md). This page captures the additional practices that apply to
framed, reliable, layered, or specification-defined protocols.

## Build One Shared Protocol Oracle

Put packet constants, field encoders/decoders, checksum or CRC reference code,
and mechanical source/sink helpers in the subsystem's `*_test_utils.py` module.
Derive them from the normative protocol specification or the established SURF
package definitions, not from copied literals in individual tests.

Keep policy assertions in the test that names the behavior. A helper may build
a DATA frame or calculate its checksum; the test should still say that an
out-of-order frame must be dropped, an EOFE marker must propagate, or a timeout
must increment a particular counter. This keeps helpers from becoming an
unreviewed second implementation of the DUT.

When the specification and current RTL disagree, make the distinction explicit:

- A clear specification requirement should become a directed regression and,
  when necessary, an RTL fix.
- An ambiguous behavior should first be a characterization test with its scope
  documented.
- A deliberately narrower SURF profile should be described in the subsystem
  README and test methodology rather than presented as full protocol
  compliance.

## Test By Layer

Prefer a progression that establishes trustworthy lower-level behavior before
large integration scenarios:

1. Field packing, checksums/CRCs, encoders, and decoders.
2. Leaf transmit and receive state machines.
3. Flow control, retries, timeouts, register interfaces, and CDC boundaries.
4. Core or wrapper integration, routing, and multi-stream interaction.

An integration test should focus on what the integrated layer adds. Reuse the
same protocol oracle, but do not duplicate every leaf permutation at the top
level.

## Required Protocol Cases

Choose the cases relevant to the DUT, including:

- minimum, typical, maximum, and non-word-aligned payload sizes;
- exact and partial final beats with correct `TKEEP`/`TSTRB`;
- SOF, EOF, EOFE, `TLAST`, `TDEST`, `TID`, and per-byte `TUSER` propagation;
- output backpressure and input idle gaps;
- malformed headers, lengths, flags, checksums/CRCs, and trailers;
- truncated frames, early/late termination, and recovery on the next frame;
- retry, acknowledgment, busy, timeout, overflow, and drop behavior;
- reset while idle and, where meaningful, reset with a partial transaction;
- sequence/tag wraparound and representative parameter boundaries;
- multi-lane or multi-stream ordering and arbitration when supported.

Assert both positive and negative behavior. For invalid traffic, verify not only
that an error is reported but also that forbidden payload or control output is
not emitted and that subsequent valid traffic recovers.

## Ready/Valid Discipline

A source must hold data and all sidebands stable until an accepting clock edge.
A sink applying backpressure should verify that the DUT does the same. Use the
shared sampled-ready helper or a suitable `cocotbext.axi` endpoint instead of
open-coding subtly different handshake loops.

Monitor accepted handshakes when timing, arbitration, or frame boundaries are
part of the contract. Comparing only final payload bytes can miss duplicated
beats, dropped sidebands, premature `TLAST`, or incorrect ordering.

## Wrappers And Integration Models

Keep wrapper HDL limited to record flattening, deterministic tie-offs,
simulator-friendly generics, or the smallest required topology. Packet
generation, retry peers, scoreboards, and assertions belong in Python.

Use real protocol dependencies at the chosen DUT boundary. Do not replace a
generated core or lower protocol layer with a permissive test double and then
claim coverage of the full assembly. If the standard GHDL flow cannot compile
the real mixed-language or vendor dependency, document the deferral in the
subsystem README and test the accessible leaves directly.
