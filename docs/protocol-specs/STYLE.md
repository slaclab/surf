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
2. Conformance language
3. Protocol overview
4. Exact structural definitions
5. Behavioral rules
6. Profile or feature distinctions
7. Non-normative appendices

## Normative Language

- Use `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` only in normative
  sections.
- Mark appendices, examples, and implementation notes as non-normative.

## Tables vs Diagrams

- Use tables for exact bit layouts, value maps, and feature matrices.
- Use diagrams for data flow, state flow, timing relationships, or interactions
  between blocks.
- Do not present the same semantics twice unless one form is explicitly
  explanatory and the other is normative.

## Assets

- Keep protocol-local figures under `spec/assets/`.
- Prefer checked-in `SVG` for diagrams.
- Use `PNG` only when vector art is impractical.

## Rendering

- Canonical source format is GitHub-flavored Markdown.
- Initial rendered target is standalone HTML via Pandoc.
- Specs should render without requiring network access.
