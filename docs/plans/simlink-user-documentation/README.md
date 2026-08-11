# SimLink User Documentation

## Goal

Provide a task-oriented SimLink guide that lets a downstream SURF user choose
a simulator backend, prepare a working environment, instantiate the public
VHDL wrappers, connect Rogue/PyRogue software, run the simulation, and diagnose
common failures without reconstructing the workflow from implementation or
regression-test documentation.

The existing documentation contains substantial architecture and protocol
detail, but setup and usage are split across the top-level SimLink README, four
backend/internal READMEs, and the test guide. This effort will reorganize and
extend that material rather than create a second competing description.

## Status

- Planning and documentation inventory complete.
- Phase 1 is complete: current lifecycle/test-layout text is corrected,
  historical plans are marked, and user navigation is present.
- Phase 2 documentation is complete: the first GHDL plus real-Rogue Memory
  workflow is documented and both focused tests have been exercised locally.
- Phase 3 is substantially drafted: HDL integration, verified Rogue API
  examples with explicit CI-coverage limits, legacy VCS migration, and
  cross-backend troubleshooting now have task-oriented guides.
- Phase 4 is complete: the landing page is task-oriented, while architecture
  and wire/protocol details each have one canonical reference document.
- A clean pinned-environment walkthrough and possible required real-Rogue
  Stream/SideBand contracts remain open follow-up validation.

## Audiences and required workflows

| Audience | Workflow the documentation must support |
| --- | --- |
| Downstream RTL developer | Add a Stream, Memory, or SideBand wrapper; choose non-overlapping ports; run it with the project's ruckus simulator target |
| Rogue/PyRogue user | Create the matching software client, connect to the correct port pair, wait for readiness where supported, and cleanly shut down |
| Simulation user | Select GHDL, VCS, or xsim; install or source prerequisites; build/load the correct shared library; interpret startup diagnostics |
| Existing VCS user | Move from the legacy `axi/simlink` layout and library behavior to the top-level multi-backend implementation without changing the public wrapper contract |
| SimLink maintainer | Find architecture, wire-contract, lifecycle, backend-ABI, and test-coverage references without mixing them into the beginner path |

## Current-state findings

Useful material already exists:

- `simlink/README.md` documents the public interfaces, architecture, port/socket
  directions, wire contracts, pacing model, backend selection, and compatibility
  invariants.
- `simlink/{ghdl,vcs,xsim}/README.md` describe each foreign-function boundary
  and contain partial build/run instructions.
- `simlink/shared/README.md` is a good maintainer reference for common C model,
  transport, and lifecycle internals.
- `tests/simlink/README.md` documents the regression layers and executable test
  commands.
- `tests/simlink/rogue/rogue_memory_client.py` is a checked and CI-backed
  production Rogue/PyRogue Memory example.
- PGP and HTSP simulation wrappers provide real multi-channel
  `RogueTcpStreamWrap` and `RogueSideBandWrap` instantiation examples.

The main gaps are:

- no short, end-to-end quick start from a clean shell;
- no backend decision table organized by user prerequisites and constraints;
- no complete environment setup recipe covering compiler, `pkg-config`,
  `libzmq`, simulator tools, Rogue/PyRogue, and relevant environment variables;
- no task-oriented HDL integration guide with copyable Stream, Memory, and
  SideBand wrapper examples;
- no task-oriented software guide for the matching Rogue clients, startup
  ordering, readiness, port directions, and shutdown;
- no explicit migration guide for legacy VCS-only users and old
  `axi/simlink` paths/library names;
- troubleshooting is xsim-heavy and does not cover common cross-backend
  failures;
- user, protocol-reference, maintainer, and test-contributor material are
  mixed together in the landing README;
- some text is already stale: the VCS docs still claim that an
  end-of-simulation callback is registered, and the test guide still places
  the simulator-free VHPI lifecycle test under `tests/simlink/vcs/` after its
  move to `tests/simlink/native/`.

The `pre-release` tree did not contain a dedicated legacy SimLink README; most
historical VCS behavior must therefore be reconstructed from the old source
layout, current compatibility notes, and known downstream use rather than
copied from an authoritative old guide.

## Proposed information architecture

Keep `simlink/README.md` as the stable landing page and put deeper user guides
under a new `simlink/docs/` directory.

| Document | Responsibility |
| --- | --- |
| `simlink/README.md` | Short overview, supported interfaces/backends, backend chooser, five-step quick start, and navigation |
| `simlink/docs/getting-started.md` | Common prerequisites, supported environments, backend selection, clean-shell setup, shared-library discovery, launch order, and first smoke test |
| `simlink/docs/hdl-integration.md` | Public wrapper contracts, VHDL examples, reset/clock behavior, port allocation, multi-channel mapping, pacing, and ruckus integration |
| `simlink/docs/rogue-clients.md` | Rogue/PyRogue Memory, Stream, and SideBand client examples; address/port mapping; readiness; lifecycle; and process orchestration |
| `simlink/docs/architecture.md` | The current layered architecture, instance ownership, transport, lifecycle, timing boundary, and backend comparison |
| `simlink/docs/protocol-reference.md` | Port/socket direction and Stream, Memory, and SideBand wire contracts plus compatibility invariants |
| `simlink/docs/migration-from-vcs.md` | Legacy-to-current path/library/backend changes, preserved VHDL interfaces and wire contracts, and VCS-specific behavioral caveats |
| `simlink/docs/troubleshooting.md` | Common diagnostics first, followed by links to backend-specific tool/license issues |
| `simlink/{ghdl,vcs,xsim}/README.md` | Exact backend ABI, tool prerequisites, environment variables, build/load commands, limitations, and backend-only troubleshooting |
| `simlink/shared/README.md` | Maintainer-only common C internals; retain and link from architecture guide |
| `tests/simlink/README.md` | Contributor-facing coverage and regression commands; do not use as the primary user setup guide |

The architecture and protocol sections currently in `simlink/README.md` should
move rather than be copied. Each fact should have one canonical home, with
short links from related documents.

## Content requirements

### Backend chooser and environment setup

- State supported operating systems and validated simulator versions.
- Distinguish open-source GHDL, licensed VCS, and Vivado xsim requirements.
- Document common native dependencies and verification commands:
  `gcc`, `make`, `pkg-config`, and `pkg-config --modversion libzmq`.
- Provide a reproducible conda setup where practical, plus distro package
  examples for Linux and the supported macOS path.
- Explain when a full Rogue/PyRogue environment is required and when the
  deterministic pyzmq peer is only a test tool.
- Centralize the user-visible environment variables and label their scope:
  `RUCKUS_SIM_BACKEND`, `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS`, `VCS_HOME`,
  `VCS_VERSION`, license variables, and any ruckus target variables. Keep
  regression-only variables such as `SIMLINK_RUN_VCS` and
  `SIMLINK_ROGUE_PYTHON` in the test guide.
- Explain automatic backend selection and show explicit selection commands so
  a shell containing both Vivado and VCS settings is unambiguous.

### HDL integration

- Use the stable `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
  `RogueSideBandWrap` interfaces rather than backend leaves in user examples.
- Provide minimal compilable VHDL snippets for all three wrappers with the
  standard direction comments and realistic SURF record types.
- Explain signal direction from both the DUT and Rogue perspectives.
- Define the adjacent-port-pair rule and give a multi-instance allocation
  example, including `CHAN_COUNT_G`, `CHAN_MASK_G`, `TDEST`, and SideBand
  offsets used by PGP/HTSP simulation wrappers.
- Explain reset/startup timing, the post-reset socket bind, listening messages,
  and the asynchronous ZeroMQ connection interval.
- Document payload pacing by task and units, with a small configuration example
  and a link to the detailed timing model.
- Show how the top-level `simlink/ruckus.tcl` participates in ordinary project
  simulation targets; users should not manually add sibling backends.

### Rogue/PyRogue clients

- Start with the checked real-Rogue Memory client and reduce it to a documented
  minimal example using `rogue.interfaces.memory.TcpClient`, `pr.Root`, and a
  `RemoteVariable`.
- Add Stream and SideBand examples only after verifying their exact APIs in the
  pinned Rogue environment. Do not infer public method names from the wire
  protocol or deterministic test peer.
- Show the complete port mapping between HDL base port and each software
  socket/client.
- Explain that Memory has a production `waitReady()` probe while Stream and
  SideBand currently do not.
- Provide recommended process startup and shutdown order, bounded timeout
  behavior, and the meaning of the listening diagnostic.
- Distinguish production Rogue examples from the pyzmq protocol oracle used by
  regression tests.

### Migration and troubleshooting

- Map `axi/simlink/...` to `simlink/...` and record the three combined library
  names.
- Identify preserved public wrappers, generics, wire framing, and port-pair
  behavior.
- Explain new process-wide port collision detection, per-instance ownership,
  bounded worker transport, widened Stream boundary, and optional pacing.
- Record the VCS/cocotb shutdown workaround accurately: no
  `vhpiCbEndOfSimulation` callback is registered in that flow; process-exit
  cleanup handles worker/socket side effects, while the exported cleanup
  function remains available for a safe future non-cocotb path.
- Cover missing `libzmq`, wrong backend selection, duplicate entity loading,
  overlapping ports, peer-direction mismatch, startup races, transport timeout,
  VCS license/tool discovery, xsim DPI-library loading, and GHDL shared-library
  discovery.

## Implementation phases

### Phase 1: Correctness and navigation

1. Fix stale lifecycle and test-layout statements in the existing READMEs.
2. Add an archival/historical note to implementation plans that contain old
   `axi/simlink` commands so users do not treat them as current guides.
3. Add a clear user-versus-maintainer navigation block to the landing README.
4. Establish `simlink/docs/` and link it from the repository map.

### Phase 2: Golden getting-started path

1. Write the backend chooser and common prerequisites.
2. Document one validated clean-shell GHDL setup as the open-source baseline.
3. Add the minimal Memory wrapper plus real Rogue/PyRogue round trip as the
   first complete workflow.
4. Add VCS and xsim setup deltas without duplicating the common steps.
5. Record exact expected diagnostics and success criteria.

### Phase 3: Complete usage recipes

1. Add Stream and SideBand HDL examples and multi-instance port planning.
2. Verify and add production Rogue Stream and SideBand client examples.
3. Add pacing and multi-channel recipes using the existing PGP/HTSP wrappers
   as checked source references.
4. Add migration and cross-backend troubleshooting guides.

### Phase 4: Reference split and cleanup

1. Move architecture/lifecycle material from the landing README into
   `architecture.md`.
2. Move wire contracts and compatibility invariants into
   `protocol-reference.md`.
3. Reduce backend READMEs to backend-owned facts and link to common material.
4. Keep `tests/simlink/README.md` focused on contributors and CI.
5. Remove duplication and stale paths across the documentation set.

## Validation strategy

- Derive code snippets from checked-in, passing examples instead of maintaining
  untested parallel pseudocode.
- Run the documented GHDL quick start from a clean environment and confirm the
  expected Memory read/write/verify/post sequence.
- Compile every documented VHDL instantiation in a focused GHDL documentation
  smoke test or reuse a checked wrapper/testbench that contains the exact
  snippet.
- Execute Rogue client examples with the pinned `rogue=v6.15.0` environment.
- Run the VCS recipe in the licensed Linux environment and the xsim recipe in
  a Vivado-enabled environment; record tool versions and skips honestly.
- Check every relative Markdown link and repository path after moving content.
- Run `git diff --check`; documentation-only edits do not require the full RTL
  regression unless examples, manifests, or test fixtures change.
- Ask one user unfamiliar with the implementation to follow the GHDL quick
  start and record any undocumented assumptions.

## Acceptance criteria

- A new user can select a backend and identify all prerequisites from the
  landing page.
- A clean-shell GHDL user can run one real Rogue/PyRogue Memory transaction by
  following a single linked path.
- VCS and xsim users have complete setup deltas, shared-library load commands,
  and troubleshooting guidance.
- Stream, Memory, and SideBand each have a verified HDL integration example and
  a verified or explicitly scoped software-side example.
- Port allocation, socket direction, startup/readiness, reset, pacing, timeout,
  and cleanup behavior are explained once and linked consistently.
- Legacy VCS users can identify what changed and what remained compatible.
- No current setup command uses old `axi/simlink` paths; only the migration
  guide names them to show their replacements. No guide claims the removed VCS
  end-of-simulation callback is registered.
- Maintainer architecture/protocol detail and contributor test instructions
  remain easy to find without blocking the beginner workflow.

## Open decisions

- Confirm the canonical supported user environment: the pinned conda package,
  a SLAC Rogue setup script, or both.
- Confirm which VCS/Vivado versions and host operating systems should be
  advertised as supported versus merely known to work.
- Decide whether documentation snippets are sufficient or whether SURF should
  add a small standalone `simlink/examples/` project. The initial plan favors
  test-backed snippets; add a standalone example only if it can be kept in CI.
- Decide whether production Rogue Stream and SideBand contracts should become
  required CI coverage before those client examples are advertised as stable.

## Likely files

- Modify: `README.md`
- Modify: `simlink/README.md`
- Create: `simlink/docs/getting-started.md`
- Create: `simlink/docs/hdl-integration.md`
- Create: `simlink/docs/rogue-clients.md`
- Create: `simlink/docs/architecture.md`
- Create: `simlink/docs/protocol-reference.md`
- Create: `simlink/docs/migration-from-vcs.md`
- Create: `simlink/docs/troubleshooting.md`
- Modify: `simlink/ghdl/README.md`
- Modify: `simlink/vcs/README.md`
- Modify: `simlink/xsim/README.md`
- Modify: `simlink/shared/README.md` only for navigation/cross-links
- Modify: `tests/simlink/README.md`
- Optionally modify/add focused tests if needed to keep documentation examples
  executable and version-checked.
