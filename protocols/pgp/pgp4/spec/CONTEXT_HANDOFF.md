# PGP4 Spec Context Handoff

This document is a compact handoff for a future engineer or agent continuing
work on the PGP4 specification effort.

## Current State

- The canonical PGP4 spec source is
  `protocols/pgp/pgp4/spec/pgp4.md`.
- The rendered HTML target is
  `build/specs/protocols/pgp/pgp4/pgp4.html`.
- The protocol-local figure assets are under
  `protocols/pgp/pgp4/spec/assets/`.
- The reusable repository-wide spec framework is under
  `docs/protocol-specs/`.
- The shared render script is
  `scripts/render_protocol_spec.sh`.

## Decisions Already Made

- Canonical authoring format is Markdown.
- Initial renderer is Pandoc.
- The spec is implementation-first, using RTL and tests as the authority.
- Confluence is reference-only and is not the seed or normative source.
- Exact bit and field structures are primarily represented as tables.
- Diagrams are used where flow, layering, or block interaction is clearer than
  a table.
- Figure assets are checked-in SVG files.
- The first document scope includes:
  - full PGP4
  - Pgp4Lite
  - FEC-enabled profile behavior at the protocol/profile level
- Vendor/transceiver wrapper internals are intentionally excluded from the
  normative body except where they affect wire-visible behavior.

## Files That Matter Most

### Spec and framework

- `protocols/pgp/pgp4/spec/pgp4.md`
- `protocols/pgp/pgp4/spec/Makefile`
- `docs/protocol-specs/STYLE.md`
- `docs/protocol-specs/TEMPLATE.md`
- `docs/protocol-specs/protocol-spec.css`
- `scripts/render_protocol_spec.sh`

### Primary implementation sources

- `protocols/pgp/pgp4/core/rtl/Pgp4Pkg.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Core.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4CoreLite.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4TxLiteProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Rx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4AxiL.vhd`
- `python/surf/protocols/pgp/_Pgp4AxiL.py`

### Primary regression sources

- `tests/protocols/pgp/pgp4/test_Pgp4Core.py`
- `tests/protocols/pgp/pgp4/test_Pgp4CoreLite.py`
- `tests/protocols/pgp/pgp4/test_Pgp4TxProtocol.py`
- `tests/protocols/pgp/pgp4/test_Pgp4TxLiteProtocol.py`
- `tests/protocols/pgp/pgp4/test_Pgp4RxProtocol.py`
- `tests/protocols/pgp/pgp4/test_Pgp4RxCrcError.py`
- `tests/protocols/pgp/pgp4/test_Pgp4RxLiteLowSpeedLane.py`
- `tests/protocols/pgp/pgp4/test_Pgp4AxiL.py`
- `tests/protocols/pgp/pgp4/pgp4_test_utils.py`

## What Was Implemented

- Added the first repo-wide protocol spec framework:
  - style guide
  - section template
  - shared CSS
  - shared Pandoc renderer
- Added the first PGP4 specification draft with:
  - normative protocol sections
  - table-driven field definitions
  - profile comparison matrix
  - AXI-Lite monitor summary
  - non-normative Confluence comparison notes
  - non-normative implementation-backed verification notes
- Added five SVG diagrams:
  - `pgp4-stack.svg`
  - `pgp4-txrx-path.svg`
  - `pgp4-link-state.svg`
  - `pgp4-flow-control.svg`
  - `pgp4-cell-sequence.svg`
- Added a protocol-local `Makefile` render target.
- Updated the render script to:
  - accept YAML metadata
  - inline CSS in the output head
  - produce a portable standalone HTML artifact

## Verification Performed

- Rendered the spec with:
  - `make -C protocols/pgp/pgp4/spec html`
- Verified the output file exists:
  - `build/specs/protocols/pgp/pgp4/pgp4.html`
- Verified the HTML title is populated from Markdown metadata.
- Verified the output inlines CSS instead of linking to an absolute local path.

## Known Limitations

- The full PGP4 RTL/cocotb regression suite was not re-run after the spec work,
  because this task only added documentation assets and render tooling.
- `git status` hit an unrelated Git LFS clean-filter failure in this workspace:
  - `ethernet/Caui4Core/gtyUltraScale+/ip/Caui4GtyIpCore156MHz.dcp`
  This is unrelated to the spec files but may interfere with some Git commands.
- The current diagrams are static SVG assets, not generated from a source DSL.
- The HTML render path is established; PDF output has not been added.

## Recommended Next Steps

1. Do a technical review pass on `pgp4.md` with a maintainer who knows the
   original protocol intent.
2. Tighten any wording where the current draft still mixes “implementation
   behavior” and “protocol requirement” more than desired.
3. Decide whether the FEC section should stay profile-level only or gain a
   separate non-normative appendix describing the wrapper boundary in more
   detail.
4. Decide whether low-speed receive behavior should get one additional diagram
   or appendix section.
5. If this workflow is accepted, apply the same structure to the next protocol
   spec under `protocols/.../spec/`.

## Editing Guidance for the Next Person

- Keep `pgp4.md` authoritative over any generated HTML.
- Prefer changing the Markdown or SVG sources rather than editing rendered
  output.
- When changing normative text, cross-check against both RTL and the targeted
  regression that exercises that behavior.
- Use tables for bit layouts unless a flow diagram communicates something that
  the table cannot.
- Do not pull Confluence text in verbatim as normative content unless it is
  confirmed by code/tests.

## Useful Commands

Render the spec:

```sh
make -C protocols/pgp/pgp4/spec html
```

Inspect the spec files:

```sh
find protocols/pgp/pgp4/spec -maxdepth 2 -type f | sort
```

Spot-check the generated HTML title:

```sh
rg -n "<title>" build/specs/protocols/pgp/pgp4/pgp4.html
```
