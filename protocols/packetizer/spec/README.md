# Packetizer2 specification

[packetizer2.md](packetizer2.md) is the working specification for the V2 wire
format and its RTL and Rogue endpoint bindings. See the parent
[packetizer overview](../README.md) and the
[review record](../../../docs/plans/packetizer2-spec/README.md).

The Markdown and local SVG figures are the maintained sources. With Pandoc
installed, render standalone HTML from the repository root:

```sh
make -C protocols/packetizer/spec html
```

Render PDF with a supported browser or PDF engine:

```sh
make -C protocols/packetizer/spec pdf
```

Outputs go to `build/specs/protocols/packetizer/` and are not checked in.
`OUT_DIR` overrides the output directory. Shared
[rendering guidance](../../../docs/protocol-specs/README.md) describes engine
selection and the inherited PGP4 presentation style. Rendering embeds figures
and styling without network access; links into the repository remain source
references rather than bundled copies of those files.
