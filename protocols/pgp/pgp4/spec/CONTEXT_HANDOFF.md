# PGP4 Spec Context Handoff

This document is a compact handoff for a future engineer or agent continuing
work on the PGP4 specification effort.

## Current State

- The canonical PGP4 spec source is
  `protocols/pgp/pgp4/spec/pgp4.md`.
- The rendered HTML target is
  `build/specs/protocols/pgp/pgp4/pgp4.html`.
- The rendered PDF target is
  `build/specs/protocols/pgp/pgp4/pgp4.pdf`.
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
- Confluence and earlier proceedings material are reference-only; exact
  protocol behavior follows the repository implementation where the sources
  disagree.
- The main body uses narrative prose rather than RFC keyword style.
- Existing implementation details are concentrated in appendices unless a
  repository default is also useful as a protocol profile default.
- Exact bit and field structures are primarily represented as tables.
- Diagrams are used where flow, layering, or block interaction is clearer than
  a table.
- Figure assets are checked-in SVG files.
- The first document scope includes:
  - Full PGP4
  - Pgp4Lite
  - FEC-enabled profile behavior at the protocol/profile level
- Vendor/transceiver wrapper internals are intentionally excluded from the
  main body except where they affect wire-visible behavior.

## Files That Matter Most

### Spec and framework

- `protocols/pgp/pgp4/spec/pgp4.md`
- `protocols/pgp/pgp4/spec/Makefile`
- `docs/protocol-specs/STYLE.md`
- `docs/protocol-specs/TEMPLATE.md`
- `docs/protocol-specs/protocol-spec.css`
- `scripts/render_protocol_spec.sh`
- `scripts/render_protocol_pdf.sh`

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
- Added and revised the first PGP4 specification draft with:
  - Motivation and scope discussion
  - Link direction and half-duplex/unidirectional discussion
  - Table-driven field definitions
  - Full PGP4 control-word, flow-control, cell, frame, CRC, and transmit
    behavior
  - Receive alignment, gearbox-style acquisition, link maintenance, and link
    loss behavior
  - Pgp4Lite subset narrative and compatibility notes
  - Optional FEC profile boundary
  - Glossary
  - Local stream mapping, monitor/control, repository implementation notes, and
    a 10.3125 Gb/s design example appendix
- Added seven SVG diagrams:
  - `pgp4-stack.svg`
  - `pgp4-txrx-path.svg`
  - `pgp4-link-state.svg`
  - `pgp4-flow-control.svg`
  - `pgp4-cell-sequence.svg`
  - `pgp4-rx-pipeline.svg`
  - `pgp4-word-processing.svg`
- Added a protocol-local `Makefile` render target.
- Updated the render script to:
  - accept YAML metadata
  - inline CSS in the output head
  - produce a portable standalone HTML artifact
- Added `scripts/render_protocol_pdf.sh` and `make pdf`; the PDF path uses
  Pandoc to generate standalone HTML, then prefers Chrome/Chromium headless for
  PDF output so browser SVG rendering matches the HTML view. WeasyPrint,
  wkhtmltopdf, and pagedjs-cli remain fallback engines.
- Updated style guidance to capitalize bullet items and visible diagram text.
- Removed Pandoc automatic section numbering from generated HTML/PDF because
  the Markdown headings are already explicitly numbered.

## Verification Performed

- Rendered the spec with:
  - `make -C protocols/pgp/pgp4/spec html`
- Verified the output file exists:
  - `build/specs/protocols/pgp/pgp4/pgp4.html`
- Verified the HTML title is populated from Markdown metadata.
- Verified the output inlines CSS instead of linking to an absolute local path.
- Verified SVG syntax with:
  - `xmllint --noout protocols/pgp/pgp4/spec/assets/*.svg`
- Verified capitalization scans for bullet items and SVG text.
- Verified whitespace with:
  - `git diff --check`
- Installed WeasyPrint 68.1 with Homebrew and verified PDF rendering with:
  - `make -C protocols/pgp/pgp4/spec pdf`
- Switched PDF rendering to Chrome headless after WeasyPrint rendered SVG
  markers incorrectly in the generated PDF.
- Verified the PDF artifact exists:
  - `build/specs/protocols/pgp/pgp4/pgp4.pdf`

## Known Limitations

- Open RTL issue: the no-elastic-buffer receive path used when `SKIP_EN_G` is
  false bypasses the `Pgp4RxEb` control-word checksum check. That means
  no-skip or Lite-style configurations may accept malformed control words that
  the full elastic-buffer path would reject. This should be investigated in RTL
  and tests rather than treated as protocol behavior.
- Startup semantics need a later maintainer decision. The protocol prose
  describes startup as a period of control-word transmission before user frame
  traffic, but the current full transmit RTL appears to hold `protTxValid` low
  until `STARTUP_HOLD_G` completes. Revisit whether the spec should require
  valid `IDLE`/`SKP` during startup hold or document the current RTL behavior.
- Low-speed wrapper bit order is configurable. `Pgp4RxLiteLowSpeedReg` exposes
  a 2-bit `bitOrder` register at AXI-Lite offset `0x818`, and
  `Pgp4RxLiteLowSpeedLane` applies it to the 8:66 receive gearbox input and
  output ordering. This appears intended as a compatibility aid for serializers
  with non-standard bit ordering; it does not change the protocol wire order.
- The full PGP4 RTL/cocotb regression suite was not re-run after the spec work,
  because this task only added documentation assets and render tooling.
- The current diagrams are static SVG assets, not generated from a source DSL.
- PDF rendering prefers Google Chrome, Chromium, or Microsoft Edge. If no
  browser is available, the script falls back to `weasyprint`, `wkhtmltopdf`,
  or `pagedjs-cli`. Set `PDF_ENGINE` or `CHROME_BIN` to override detection.
- WeasyPrint emits harmless warnings for a few screen-oriented CSS properties
  such as horizontal overflow and narrow-screen media rules while producing
  paged PDF output. More importantly, WeasyPrint currently renders some SVG
  markers incorrectly, so Chrome is the preferred engine.

## Recommended Next Steps

1. Do a visual review of `build/specs/protocols/pgp/pgp4/pgp4.pdf`, especially
   diagrams and wide tables.
2. Do a final technical review pass on `pgp4.md` with a maintainer who knows
   the original protocol intent.
3. Check whether any remaining repository-default values should move between
   the main protocol profile discussion and Appendix C.
4. If this workflow is accepted, apply the same structure to the next protocol
   spec under `protocols/.../spec/`.

## Editing Guidance for the Next Person

- Keep `pgp4.md` authoritative over any generated HTML.
- Prefer changing the Markdown or SVG sources rather than editing rendered
  output.
- When changing protocol behavior text, cross-check against both RTL and the
  targeted regression that exercises that behavior.
- Use tables for bit layouts unless a flow diagram communicates something that
  the table cannot.
- Do not pull Confluence or proceedings text in verbatim as protocol content
  unless it is confirmed by code/tests.

## Useful Commands

Render the spec:

```sh
make -C protocols/pgp/pgp4/spec html
```

Render the PDF:

```sh
make -C protocols/pgp/pgp4/spec pdf
```

Use a specific supported PDF engine:

```sh
PDF_ENGINE=weasyprint make -C protocols/pgp/pgp4/spec pdf
```

Inspect the spec files:

```sh
find protocols/pgp/pgp4/spec -maxdepth 2 -type f | sort
```

Spot-check the generated HTML title:

```sh
rg -n "<title>" build/specs/protocols/pgp/pgp4/pgp4.html
```
