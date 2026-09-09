# SURF

[DOE Code](https://www.osti.gov/doecode/biblio/8176)

SLAC Ultimate RTL Framework

<!--- ########################################################################################### -->

# Repository Map

- [Agent guidance](AGENTS.md): project layout, coding conventions, and verification notes for contributors and coding agents.
- [AXI](axi/README.md): AXI-Lite, AXI4, AXI Stream, DMA, and bridges.
- [Base](base/README.md): foundational packages, CDC, FIFO, RAM, reset, delay, CRC, and generic RTL helpers.
- [Devices](devices/README.md): vendor and component-specific RTL support.
- [DSP](dsp/README.md): generic and Xilinx-specific DSP support.
- [Ethernet](ethernet/README.md): MAC, raw Ethernet, IPv4, UDP, RoCEv2, and high-speed Ethernet cores.
- [Protocols](protocols/README.md): PGP, SSI, SRP, RSSI, CoaXPress, JESD204B, peripheral buses, and related protocol cores.
- [SimLink](simlink/README.md): setup and reference documentation for Rogue-facing Stream, Memory, and SideBand simulation links with GHDL, VCS, or Vivado xsim.
- [Xilinx](xilinx/README.md): Xilinx-family wrappers, primitive integrations, and XVC UDP support.
- [Python](python/README.md): PyRogue package layout under `python/surf`.
- [Tests](tests/README.md): cocotb regression layout, methodology, helpers, and simulator conventions.

<!--- ########################################################################################### -->

# Before you clone the GIT repository

Setup for large filesystems on github.  `git-lfs` used for all binary files (example: .dcp)

```sh
$ git lfs install
```

<!--- ########################################################################################### -->

# Presentations

[An Introduction to SURF Presentation](https://docs.google.com/presentation/d/1kvzXiByE8WISo40Xd573DdR7dQU4BpDQGwEgNyeJjTI/edit?usp=sharing)

[IEEE RT 2024: SURF Workshop Presentation](https://docs.google.com/presentation/d/1pPfELOniJzBMBpp1lE9Xmid71ckkBH4wsoWzUGZyyy4/edit?usp=sharing)

<!--- ########################################################################################### -->

# Misc

[Tutorial](https://github.com/slaclab/surf-tutorial)

[Doxygen Homepage](https://slaclab.github.io/surf/index.html)

[Support Homepage](https://confluence.slac.stanford.edu/display/ppareg/Build+System%3A+Vivado+Support)

[Bug Tracking](https://jira.slac.stanford.edu/projects/ESSURF)

<!--- ########################################################################################### -->
