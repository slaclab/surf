# Protocol Spec Style Guide

This repository keeps protocol specifications as Markdown source that can be
reviewed in Git and rendered with Pandoc.

## Goals

- Make the repository copy the canonical specification.
- Derive normative behavior from implementation-backed sources.
- Separate interoperability requirements from implementation notes.

## Required Structure

Each protocol spec should include:

1. Introduction and scope
2. Reading and conformance guidance, including draft/evidence status
3. Protocol overview
4. Exact structural definitions
5. Behavioral rules
6. Profile or feature distinctions
7. Implementation and reference appendices

## Normative Language

- Prefer direct prose, following the PGP4 specification: "uses", "requires",
  "accepts", and "treats as an error" can state requirements without RFC
  keywords. Explain this convention near the beginning of the document.
- If using `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, or `MAY`, define them
  and use them consistently in sections that establish requirements.
- Distinguish observed behavior, tested expectations, agreed compatibility
  requirements, and unresolved defects in drafts derived from implementation.
  Do not label a document release-ready merely because it renders successfully.
- Mark implementation notes and explanatory examples separately from
  requirements. An endpoint binding can contain requirements even when placed
  in an appendix; its location does not make externally visible behavior
  incidental.

## Tables vs Diagrams

- Use tables for exact bit layouts, value maps, and feature matrices.
- Use diagrams for data flow, state flow, timing relationships, or interactions
  between blocks.
- Do not present the same semantics twice unless one form is explicitly
  explanatory and the other is normative.
- Capitalize the first word of every bullet item.
- Capitalize the first word of visible diagram text, including SVG labels,
  captions, and short annotations.

## Assets

- Keep protocol-local figures under `spec/assets/`.
- Prefer checked-in `SVG` for diagrams.
- Use `PNG` only when vector art is impractical.

## Rendering

- Canonical source format is GitHub-flavored Markdown.
- Initial rendered target is standalone HTML via Pandoc.
- Specs should render without requiring network access.
