# Protocol specifications

This directory contains shared [style guidance](STYLE.md), a
[starting template](TEMPLATE.md), and the HTML/print stylesheet for protocol
specifications. Protocol-local Markdown, figures, and Makefiles live under
`protocols/<subsystem>/spec/`. See the [repository overview](../../README.md).

The framework was imported from the `pgp4-spec` branch at
`b863a909a9eb5f22236b582496a6ff9cce7b4f89`, without that branch's RTL changes.
The initial user in this checkout is the
[Packetizer2 specification](../../protocols/packetizer/spec/README.md).
Its direct-prose and evidence conventions extend the original template.

## Rendering

[render_protocol_spec.sh](../../scripts/render_protocol_spec.sh) requires
Pandoc and produces standalone HTML with embedded styling and local figures.
[render_protocol_pdf.sh](../../scripts/render_protocol_pdf.sh) uses Pandoc
with Google Chrome, Chromium, or Microsoft Edge when available, then falls
back to WeasyPrint, wkhtmltopdf, or pagedjs-cli. Neither script installs tools.

Use the protocol's Makefile for its standard output paths. For direct use:

```sh
scripts/render_protocol_spec.sh SPEC.md OUTPUT.html docs/protocol-specs/protocol-spec.css
scripts/render_protocol_pdf.sh SPEC.md OUTPUT.pdf docs/protocol-specs/protocol-spec.css
```

Create the output directory first when invoking the scripts directly. Set
`PDF_ENGINE` to select a renderer or `CHROME_BIN` to select a browser executable.
The browser uses a temporary isolated profile and is stopped after writing a
complete PDF. A render that has not completed within 60 seconds fails and
leaves any previous PDF intact. Rendering requires no network
access when figures and styling are local. Source hyperlinks remain links;
referenced repository files are not included in the standalone output.

Check HTML and representative PDF pages after layout changes. Browser output
is preferred for the current SVG diagrams; the original PGP4 review found SVG
marker differences in WeasyPrint. Generated output belongs under ignored
`build/specs/`, not alongside the maintained sources.
