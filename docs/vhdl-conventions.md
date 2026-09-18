# SURF VHDL conventions

A SURF module should make three things easy to see: what state it owns, how that
state changes, and when its interfaces transfer data. This guide describes the
patterns we use to make those decisions visible in the code.

Use these conventions for new and substantially reworked VHDL. Older modules
will differ in places; preserve their public interfaces and implementation
requirements when making a focused change. There is no need to restyle unrelated
code. Correct combinational assignments, reset behavior and protocol timing
matter in every module, regardless of its age or layout.

The examples are architecture or process excerpts unless stated otherwise.
They assume the usual SURF imports and the ports and generics described with
each example. [AGENTS.md](../AGENTS.md) covers repository workflow, while
[tests/README.md](../tests/README.md) describes the regression methodology.

## Contents

- [Language, layout and naming](#language-layout-and-naming)
- [Two-process VHDL style](#two-process-vhdl-style)
- [Output ownership and interface timing](#output-ownership-and-interface-timing)
- [State and process variables](#state-and-process-variables)
- [Multiple clock domains](#multiple-clock-domains)
- [Packages and interface records](#packages-and-interface-records)
- [Constants, arithmetic and wire layouts](#constants-arithmetic-and-wire-layouts)
- [Reset and CDC rules](#reset-and-cdc-rules)
- [Bus and protocol semantics](#bus-and-protocol-semantics)
- [AXI Stream conventions](#axi-stream-conventions)
- [AXI-Lite register implementation](#axi-lite-register-implementation)
- [Simulation and testbench VHDL](#simulation-and-testbench-vhdl)
- [VHDL headers](#vhdl-headers)
- [RTL review checklist](#rtl-review-checklist)

## Language, layout and naming

SURF targets VHDL-2008. The Makefile/GHDL flow also supports Synopsys IEEE
packages and relaxed rules used by existing modules. Match a module's arithmetic
package family: both `numeric_std` and `std_logic_arith`/`std_logic_unsigned`
are established here. Prefer `numeric_std` for new standalone arithmetic, and
avoid mixing the two families or changing packages during an unrelated edit.
Use SURF types such as `sl` and `slv` from `StdRtlPkg` and existing bus records.

### Give the code room to be read

Use three spaces per indentation level, spaces rather than tabs, ASCII text
including comments, and no trailing whitespace. Each declaration, assignment
and procedure call gets its own line. Branch labels and control-flow openers
and terminators also stand on their own:

```vhdl
case r.state is
   when IDLE_S =>
      if start = '1' then
         v.count := (others => '0');
         v.state := RUN_S;
      end if;
   when RUN_S =>
      if finished = '1' then
         v.state := IDLE_S;
      end if;
end case;
```

A long expression may span several lines. Separate logical stages with blank
lines, and align colons and associations within a group. Put every record field,
initialization association and generic/port association on a separate line.
Compressing statements to reduce line count makes the algorithm harder to follow.

### Names and instantiations

These are the usual naming conventions. Keep established public names and local
exceptions, including vendor ports and uppercase configuration fields.

| Item | Usual form | Example |
| --- | --- | --- |
| Entity or type | PascalCase | `AxiStreamMux`, `StateType` |
| Record type | Ends in `Type` | `AxiStreamMasterType` |
| Array type | Ends in `Array` | `AxiStreamMasterArray` |
| Signal, field, variable or subprogram | lowerCamelCase | `frameCount`, `advancePointer` |
| Generic | Uppercase, `_G` | `FIFO_DEPTH_G` |
| Constant | Uppercase, `_C` | `REG_INIT_C` |
| FSM state | Uppercase, `_S` | `IDLE_S`, `WAIT_ACK_S` |
| Instance / generate label | `U_...` / descriptive uppercase | `U_Pipeline`, `GEN_LANES` |
| Architecture | Lowercase | `rtl`, `mapping` |

### Common generics

Put common timing/reset generics first where applicable: `TPD_G`, followed by
the supported reset options. Group functional, buffering and implementation
options after them. Reuse established names for established meanings, and pass
the parent's setting to children that participate in that contract.

| Generic | Meaning and expectations |
| --- | --- |
| `TPD_G` | Simulation propagation delay, usually `time := 1 ns`. Pipeline latency is specified separately in clock cycles. |
| `RST_POLARITY_G`, `RST_ASYNC_G` | Supported reset polarity and synchronous/asynchronous behavior. Prefer `RST_ASYNC_G := false` for new behavioral modules. |
| `PIPE_STAGES_G` | Configurable pipeline stages. Document whether these add to the block's inherent latency and what zero means. |
| `COMMON_CLK_G`, `GEN_SYNC_FIFO_G` | Clocking implementation choices. Selecting a synchronous implementation requires the connected clocks to satisfy that block's common-clock contract. |
| `SYNTH_MODE_G`, `MEMORY_TYPE_G`, `XIL_DEVICE_G` | Implementation, memory or device choices. Document supported string values beside the declaration. |

See [Fifo.vhd](../base/fifo/rtl/Fifo.vhd) and
[AxiStreamFifoV2.vhd](../axi/axi-stream/rtl/AxiStreamFifoV2.vhd) for common
buffering options. Expose only the options a module supports; preserve existing
names, types and defaults, and account for differences in child reset support.

State frequency and period units explicitly. Many general blocks use real
frequencies in Hz and periods in seconds, as in
[Heartbeat.vhd](../base/general/rtl/Heartbeat.vhd). Vendor clock wrappers such
as [ClockManagerUltraScale.vhd](../xilinx/UltraScale/clocking/rtl/ClockManagerUltraScale.vhd)
use real periods in nanoseconds. Preserve those interface units.

### Port declarations

Group ports by clock domain. **Declare the clock first, followed by its reset,
then the signals belonging to that domain.** Within each domain, keep related
ports together: an AXI-Lite bank, an input stream, an output stream, or a set of
controls and status signals. Keep both directions of an interface together
rather than separating all inputs from all outputs.

Use a short comment and a blank line to identify each domain and interface:

```vhdl
port (
   -- AXI-Lite clock domain
   axilClk        : in  sl;
   axilRst        : in  sl;

   -- Register interface
   axiReadMaster  : in  AxiLiteReadMasterType;
   axiReadSlave   : out AxiLiteReadSlaveType;
   axiWriteMaster : in  AxiLiteWriteMasterType;
   axiWriteSlave  : out AxiLiteWriteSlaveType;

   -- Stream clock domain
   axisClk        : in  sl;
   axisRst        : in  sl;
   enable         : in  sl;

   -- Input stream
   sAxisMaster    : in  AxiStreamMasterType;
   sAxisSlave     : out AxiStreamSlaveType;

   -- Output stream
   mAxisMaster    : out AxiStreamMasterType;
   mAxisSlave     : in  AxiStreamSlaveType);
```

Here `enable` belongs to `axisClk`; its position makes that ownership visible.
Ports without a clocked relationship, such as asynchronous device pins, belong
in a separately labeled functional group. Follow the same grouping and order
in port maps where practical. When maintaining an existing interface, account
for positional instantiations and component declarations before reordering ports.

Default optional inputs to their documented inactive or always-enabled value,
using package constants for records. An optional reset commonly defaults to
`not RST_POLARITY_G`; a default valid or ready of `'1'` needs an explicit
always-enabled interface contract. Keep required clocks and inputs required.
Choose record defaults and disabled outputs according to their
[idle and tie-off behavior](#idle-and-disabled-interfaces).

### Instantiations

Use named association and prefer direct SURF entity instantiation. Group clocks,
resets and interfaces consistently, with aligned comments showing the direction
of the instantiated port:

```vhdl
U_Pipeline : entity surf.AxiStreamPipeline
   generic map (
      TPD_G          => TPD_G,
      RST_POLARITY_G => RST_POLARITY_G,
      RST_ASYNC_G    => RST_ASYNC_G,
      PIPE_STAGES_G  => 1)
   port map (
      axisClk     => axisClk,       -- [in]
      axisRst     => axisRst,       -- [in]
      sAxisMaster => inputMaster,   -- [in]
      sAxisSlave  => inputSlave,    -- [out]
      mAxisMaster => outputMaster,  -- [out]
      mAxisSlave  => outputSlave);  -- [in]
```

Use `-- [inout]` for bidirectional ports. Component binding remains appropriate
for vendor IP, primitives and flows that require it. Attributes such as
`ASYNC_REG`, `shreg_extract`, `ram_style` and `use_dsp` express implementation
constraints and must survive formatting changes.

### Structural generates

Use labeled `if generate` branches for static feature, bypass and implementation
choices, and `for generate` for replicated instances. Alternative implementations
must be mutually exclusive. Give each selected branch complete ownership of the
outputs it implements, including defined outputs when a feature is disabled.
A bypass must connect forward data and sidebands together with reverse flow
control; see the `ZERO_LATENCY` branch in
[AxiStreamPipeline.vhd](../axi/axi-stream/rtl/AxiStreamPipeline.vhd).

Reuse shared FIFO, RAM and pipeline wrappers when they support the required
configuration. Keep primitive selection inside those wrappers rather than
repeating it in each consumer. [Fifo.vhd](../base/fifo/rtl/Fifo.vhd) illustrates
implementation selection, while
[AxiLiteAsync.vhd](../axi/axi-lite/rtl/AxiLiteAsync.vhd) separates common-clock
and asynchronous paths. Document supported generic values and reject unsupported
combinations with assertions, following the checks below.

### Source layout and checks

Place synthesizable modules in `rtl/`, simulation models in `sim/`, VHDL benches
in `tb/`, and adapters in `wrappers/` or `ip_integrator/`. Family-specific code
belongs in directories such as `7Series`, `UltraScale` or `gtyUltraScale+`.
Update the nearest `ruckus.tcl` when adding or moving HDL; use `loadRuckusTcl`
for child directories and `getFpgaArch` guards for family-specific sources.

Constrain generics to meaningful ranges and assert relationships between them:

```vhdl
assert DATA_BYTES_G mod LANES_G = 0
   report "DATA_BYTES_G must be a multiple of LANES_G"
   severity failure;
```

Here `LANES_G` is positive. Array interfaces also need compatible bounds and
direction, not just equal lengths; see
[AxiLiteRegs.vhd](../axi/axi-lite/rtl/AxiLiteRegs.vhd). Keep supported boundary
cases such as one channel or a zero-stage pipeline bypass.

With VSG installed and available on `PATH`, run the style check from the
repository root:

```sh
vsg -c vsg-linter.yml -f path/to/file.vhd
```

The written conventions still apply where a linter rule is disabled. Lint
cannot decide whether the control flow is readable or a handshake is correct.

## Two-process VHDL style

Most SURF behavioral modules use two processes. `comb` computes the next state;
`seq` stores it on the clock edge. A record keeps the module's state together:
`r` is the current state, `v` is the working next state, and `rin` carries the
result from `comb` to `seq`.

This example captures a 16-bit sample and reports its capture with a registered
one-cycle indication. `sampleValid` is a capture strobe, not a backpressured
transaction interface.

```vhdl
type RegType is record
   dataOut : slv(15 downto 0);
   updated : sl;
end record;

constant REG_INIT_C : RegType := (
   dataOut => (others => '0'),
   updated => '0');

signal r   : RegType := REG_INIT_C;
signal rin : RegType;

begin

comb : process (r, rst, sampleValid, sampleData) is
   variable v : RegType;
begin
   v := r;

   v.updated := '0';
   if sampleValid = '1' then
      v.dataOut := sampleData;
      v.updated := '1';
   end if;

   if RST_ASYNC_G = false and rst = RST_POLARITY_G then
      v := REG_INIT_C;
   end if;
   rin <= v;

   dataOut <= r.dataOut;
   updated <= r.updated;
end process comb;

seq : process (clk, rst) is
begin
   if RST_ASYNC_G and rst = RST_POLARITY_G then
      r <= REG_INIT_C after TPD_G;
   elsif rising_edge(clk) then
      r <= rin after TPD_G;
   end if;
end process seq;
```

Start `comb` with `v := r` and make all next-state updates through `v`. Clear
pulse fields before setting them conditionally. A transaction-valid flag has a
different lifetime: it stays asserted with its payload until the interface
accepts or cancels it. The [AXI Stream example](#axi-stream-conventions) shows
that distinction.

Keep the behavioral algorithm in `comb`: arithmetic, validation, arbitration,
state transitions and priority decisions all belong there. `seq` contains only
the clock/reset idiom and `r <= rin after TPD_G`. Include every combinational
input in the sensitivity list; match the surrounding use of explicit lists or
`process(all)`.

Declaration-time initialization of `r` serves startup behavior separately from
runtime reset. Preserve both, including existing `TPD_G`, reset polarity and
synchronous/asynchronous options. An initialization value alone is not a reason
to add a reset port or reset previously unreset storage.

### Let the process tell the story

Arrange `comb` in dependency order: defaults, input handling and state changes,
final priority/reset decisions, then publication. Keep each decision beside the
action it controls. For example, a receive path can read as framing checks,
protocol validation, then message delivery. An `if`/`elsif` chain makes priority
visible; a `case` is useful for message types or named transaction phases.

Keep acceptance, execution and acknowledgement distinct when their lifetimes
differ. Finishing a command does not by itself authorize a replacement on the
same edge. Make that admission policy visible in the state machine.

Use signal assignments at the end only to publish resolved values, following
the [signal-assignment rule](#signal-assignments-in-comb) below. Keep conditional
logic in the calculations that update `v`. Concurrent assignments are for
wiring, constant tie-offs and record flattening; instances and structural
generates also remain outside `comb`.

Before splitting a long module, look for repeated calculations, validation or
bounded searches that a small local helper could clarify. Keep state updates,
selection priority and cancellation in the owning process. A useful module
boundary has an independent responsibility and a clear interface.

### Apply reset before publishing outputs

Place the synchronous `v := REG_INIT_C` override near the bottom of `comb`,
after normal next-state calculations and **before `rin <= v` and output
assignments**. This gives reset priority and makes outputs driven from `v`
observe the resolved reset value. Avoid subsequent updates to `v` that undo
the reset unless explicitly required by the interface.

Ordering matters: `inputReady <= v.inputReady;` evaluates its right-hand side
when that statement executes. A later `v := REG_INIT_C` does not change the
value already scheduled for `inputReady`. Publishing before reset can therefore
advertise acceptance or assert a control while the corresponding next state is
being reset. The same applies to a scratch variable copied from `v` before
reset; resetting `v` does not reset that copy.

Outputs driven directly from `r` still reflect the current registers; moving
their publication below the reset override does not make synchronous reset
asynchronous. Keep asynchronous reset in `seq` and preserve the specialized
templates below. If an existing interface intentionally publishes a value
before reset, document why and verify its reset behavior at both ends. Treat
changing that ordering as a behavior change, not a formatting edit.

### Where the template does not apply

Memory inference, synchronizer internals and primitive-specific logic need their
own clocked templates, reset placement and attributes. Preserve those patterns
and reuse the existing blocks: examples include
[SimpleDualPortRamInferred.vhd](../base/ram/inferred/SimpleDualPortRamInferred.vhd),
[Synchronizer.vhd](../base/sync/rtl/Synchronizer.vhd) and
[OutputBufferReg.vhd](../xilinx/UltraScale/general/rtl/OutputBufferReg.vhd).
A structural wrapper likewise needs no artificial register bank.

## Output ownership and interface timing

### Registered boundaries are the default

Design functional module outputs, including connections to child instances, to
come directly from registers. The receiving module should have a full clock
period for its own logic, without an upstream mux, decode or arithmetic path
already consuming that budget. Register payload, valid and associated controls
together. Prefer computing those registers from resolved next state; adding a
register after an existing output equation can add unnecessary latency.

Coding style does not establish this boundary. Publishing a local variable or
`v` field is still combinational. Selecting `r.queue(r.readPointer)` also puts
a mux after the registers; fixed slices and representation-only casts do not.
Place selection before the output register when the interface needs a timing
boundary, even if that requires an explicit queue output stage.

An exception needs a concrete requirement or buffering/latency tradeoff, stated
near the interface. "The current implementation needs this on the same edge"
is a dependency to examine, not sufficient justification. Consider changing
producer and consumer together: retain payload with a delayed acknowledgement,
reserve capacity before advertising ready, or define an explicit cancellation
window. Specify detection, publication and consumption edges, including what
can no longer be revoked after commit. Preserve reset, memory and synchronizer
implementation requirements.

Combinational ready/backpressure may be appropriate when it expresses current
capacity and the interface lacks storage to honor delayed backpressure. Review
that path explicitly; use existing buffered pipeline blocks when a timing break
is needed. Structural wiring preserves the child's boundary and needs no extra
register. A wrapper that computes selection or policy is doing more than wiring.

### Signal assignments in comb

**Within `comb`, use `<=` only for unconditional publication. Registered
outputs must be driven explicitly from `r`.** Apply this rule to internal
signals connecting child instances as well as module ports.

- Put decisions and calculations in assignments to `v` or justified scratch
  using `:=`. Publish each signal once, near the end of the process.
- **Do not put `<=` assignments inside `if`/`elsif`/`else` or `case` branches.**
  Do not default an output with `<=` and then override it conditionally.
- **Do not put conditional expressions, Boolean qualification or arithmetic
  decisions on the right-hand side of `<=`.** A `when ... else` expression or
  helper that hides the selection has the same problem. Compute the result
  in the owning logic before publication.
- Use a direct registered field, such as `requestValid <= r.requestValid;`.
  Even a decode using only `r` fields is combinational logic; it does not become
  a registered output merely because its inputs are registered.

For example, this state decode in the output section is **not the SURF pattern**:

```vhdl
if r.state = ISSUE_S then
   requestValid <= '1';
else
   requestValid <= '0';
end if;
```

Instead, give `RegType` a `requestValid : sl` field, initialize it to `'0'`,
and compute it with the resolved next state and request operands:

```vhdl
-- In the owning state/priority logic, after resolving v.state:
v.requestValid := '0';
if v.state = ISSUE_S then
   v.requestValid := '1';
end if;

-- Unconditional publication:
requestValid <= r.requestValid;
rin          <= v;
```

Here valid and the request operands are registered together. `rin <= v` is
the next-state transfer, so its source is naturally `v`.

The limited exceptions to an `r` source are justified combinational
ready/backpressure or fixed-latency interface controls, structural forwarding,
constants and representation-only boundary packing, slicing or type conversion.
Evaluate exceptions against the registered-boundary guidance above; documenting
an existing dependency alone does not justify retaining it. **These exceptions
still require unconditional publication.** Resolve a combinational ready field
through `v`, then write `inputReady <= v.inputReady;`; do not wrap that assignment
in an `if`. Simple representation changes must not conceal selection or policy.
The [AXI Stream example](#axi-stream-conventions) shows this in context.

### Give each output one state owner

An output normally has a field of the same type in `RegType`, preferably with
the same name. For a record output, store and update the complete record. This
makes the output and its internal use refer to one state owner.

For example, using the `LinkStatusType` defined in the package example below:

```vhdl
-- In RegType:
status : LinkStatusType;

-- In REG_INIT_C:
status => LINK_STATUS_INIT_C,

-- In the frame-acceptance branch of comb:
v.status.frameCount := slv(unsigned(r.status.frameCount) + 1);

-- Output publication:
status <= r.status;
```

There is no separate `frameCount` register copied into `status` at the end.
Live status owns its counters and diagnostics; frozen software snapshots are
separate storage with a separate purpose. Keep wider arithmetic intermediates
where needed, and derive status from the appropriate next state so it reports
the intended edge.

Explain intentional timing exceptions near the code. A wrapper flattening a
record does not need another pipeline stage just to give each output a matching
register.

For justified combinational control records, a fully assigned local variable can
collect the decision before publication. Keep output assignment separate from
computing that decision, and apply the intended reset override to the value
being published. Follow the [reset ordering](#apply-reset-before-publishing-outputs)
above. Changing an output from `r` to `v`, or the reverse, changes its timing.

### Register related controls together

For interfaces we define, prefer registered payload, valid and lifecycle
controls. Compute controls with the state or payload they describe. For example,
the request-valid example above uses resolved next state so valid is registered
on the same edge as its operands. Decoding `r.state` into a new register instead
would add a cycle. The same alignment consideration applies to mode bits,
rounding controls and diagnostics.

When reinitializing a payload, clear only that payload. Resetting a whole command
record may also erase a cancellation decision already made in the evaluation.
Review whole-record assignments and output/reset ordering together.

Document assertion and release latency at both ends of a control interface. If
a receiver accepts a command at edge N and commits at N+1, cancellation produced
at N can still veto that pending commit. Cancellation first produced at N+1
cannot undo it. Ownership and completion must follow the accepted command.

A custom interface with shared cancellation must define transfer to exclude
cancel/reset edges at both ends, even if registered valid remains high until
the edge. AXI Stream has its own protocol; do not add a private cancellation rule
to it. The [stream section](#axi-stream-conventions) describes its ready/valid
pattern and the related scalar `inputReady` convention.

## State and process variables

Use `r` when the calculation needs the current registered value and `v` when it
needs an update made earlier in this evaluation. Read configuration from its
owner rather than copying it into a temporary alias. A signal assignment does
not update the signal immediately, so signals are not a way to pass intermediate
results between steps of one `comb` evaluation.

Local variables are useful for arithmetic, type conversion, sorting, bounded
searches and helper objects such as `AxiLiteEndpointType`. Here a temporary keeps
the carry from adding two unsigned 16-bit operands:

```vhdl
-- In the comb declarations:
variable sum : unsigned(16 downto 0);

-- In comb, after v := r:
if addEnable = '1' then
   sum      := resize(unsigned(operandA), 17) + resize(unsigned(operandB), 17);
   v.result := slv(sum(15 downto 0));
   v.carry  := sum(16);
end if;
```

Every use of `sum` follows its assignment in the same branch. It needs no
persistent state and no unconditional default. A top-of-process default is
also valid, as is a complete `if`/`else` assignment before use. What matters is
that every path reaching a use assigns the value during the current evaluation;
process variables must not accidentally retain a value from an earlier one.
See [FirFilterTap.vhd](../dsp/generic/fixed/FirFilterTap.vhd) for branch-local
arithmetic and [AxiStreamMux.vhd](../axi/axi-stream/rtl/AxiStreamMux.vhd) for
selection scratch.

Local variables declared inside a function or procedure may be initialized in
their declarations; those initializers run on each call. A process-declaration
initializer does not run on each process activation, so it cannot replace the
assignment-before-use rule above. The conversion functions in
[AxiDmaPkg.vhd](../axi/dma/rtl/AxiDmaPkg.vhd) and `initQuarterWaveLut` in
[SinCosLut.vhd](../dsp/xilinx/fixed/SinCosLut.vhd) illustrate subprogram-local
initialization.

Use a register when a value must survive a clock edge or is a useful retained
diagnostic. Adding a register solely to eliminate a temporary obscures that
distinction. The combinational ready field is a deliberate output-organization
pattern: it is recomputed each evaluation and published from `v`.

Bound search indices to the table depth. An `integer range -1 to DEPTH_G-1`
can use `-1` for no match, provided every array access first excludes it. A named
subtype is useful when it adds meaning or reuse, not just another name for the
range. Check synthesis when widths or inference are uncertain; the source range
or a generic netlist alone does not prove FPGA resource use or timing.

## Multiple clock domains

Each clock domain with local behavioral state gets its own complete two-process
implementation. A module with AXI-Lite management and stream processing might
use these names:

| Element | AXI-Lite domain | Stream domain |
| --- | --- | --- |
| State type | `AxilRegType` | `AxisRegType` |
| Initial state | `AXIL_REG_INIT_C` | `AXIS_REG_INIT_C` |
| Current / next signals | `rAxil`, `rinAxil` | `rAxis`, `rinAxis` |
| Processes | `combAxil`, `seqAxil` | `combAxis`, `seqAxis` |
| Clock / reset | `axilClk`, `axilRst` | `axisClk`, `axisRst` |

`combAxil` starts with a local `v := rAxil` and ends with `rinAxil <= v`;
`seqAxil` registers only that state on `axilClk`. The stream pair does the same
for its own state and clock. Each domain retains its initialization and
synchronous/asynchronous reset handling. Never drive a shared state record from
different clock domains or combine multiple clocks in one sequential process.

Separate process pairs do not synchronize data. Each `comb` consumes the
receiving side of an appropriate CDC block, not raw fields of the other domain's
`r` or `rin`. Name signals and section comments so clock/reset ownership is clear.
Clocks merely forwarded to child instances need no artificial local state.
The memory and primitive exceptions still apply within each domain.

[SsiPrbsRx.vhd](../protocols/ssi/rtl/SsiPrbsRx.vhd) and
[AxiMemTester.vhd](../axi/axi4/rtl/AxiMemTester.vhd) provide existing examples
of separate stream and AXI-Lite state/process pairs.

## Packages and interface records

Put shared types, initialization values, encodings and interface helpers in the
nearest appropriate `*Pkg.vhd`. A record groups fields with a common purpose,
owner and timing contract. Document that contract beside the type:

```vhdl
-- Produced in linkClk. Live registered diagnostics, with no handshake.
-- frameCount counts accepted frames and wraps modulo 2**32.
type LinkStatusType is record
   up         : sl;
   frameCount : slv(31 downto 0);
end record;

constant LINK_STATUS_INIT_C : LinkStatusType := (
   up         => '0',
   frameCount => (others => '0'));

type LinkStatusArray is array (natural range <>) of LinkStatusType;
```

For transaction records, also explain units, valid/ready or acknowledgement
rules, cancellation priority and clock domain. Use separate records for opposite
directions and independent lifetimes; unrelated clocks, resets and enables do
not belong in one record just to shorten a port list. Connect whole records
between production modules and flatten them at tool-facing boundaries.

Use existing SURF records before defining a new one. Exported records normally
have an `_INIT_C` constant; an intentionally non-default-initialized type is an
exception. Prefix exported constants by package or protocol, as in `AXI_`,
`SSI_` or `PGP2B_`. Use unconstrained `natural range <>` arrays for replicated
channels. For distinct blocks, named controls such as `rxConfigValid` and
`txConfigValid` are clearer than an anonymous vector with positional meanings.
Defined register/protocol bitfields retain their documented layout.

Check `StdRtlPkg` before defining an equivalent array type. Reuse types such as
`Slv32Array`, `IntegerArray`, `NaturalArray` and the established matrix types
when they express the interface. Preserve actual bounds and direction:
`natural range <>` permits both ascending and descending constraints. Both
forms are established in SURF; choose the one appropriate to the interface.

Keep one definition of protocol encodings, CRCs and sidebands. A helper used
only by one entity belongs locally, not in a growing catch-all package. Avoid
circular dependencies and keep foundational packages independent of their
applications. Layering follows responsibilities: for example,
[RawEthFramerPkg.vhd](../ethernet/RawEthFramer/rtl/RawEthFramerPkg.vhd) can use
foundational SSI helpers even though they live under `protocols/`.

Helpers called by synthesized logic must be deterministic and synthesizable.
Packages may also contain clearly identified elaboration or simulation helpers;
use the established tool pragmas to isolate synthesis-incompatible code, as in
[StdRtlPkg.vhd](../base/general/rtl/StdRtlPkg.vhd).

### Record packing

When a record crosses a vector-only storage or tool boundary, keep its packed
size and paired pack/unpack helpers together with the type. Reuse existing
`toSlv`/`to<Type>` helpers and size functions or constants. Make field order,
enabled fields and separately transported valid/handshake bits explicit.

[AxiDmaPkg.vhd](../axi/dma/rtl/AxiDmaPkg.vhd) pairs size constants with `toSlv`
and record decoders such as `toAxiReadDmaReq`, which reconstructs `request` from
a separate `valid` argument. In
[AxiStreamPkg.vhd](../axi/axi-stream/rtl/AxiStreamPkg.vhd), `getSlvSize`, `toSlv`
and `toAxiStreamMaster` share a stream configuration, and `tValid` is supplied
separately. Keep the configuration and layout consistent on both sides.

`StdRtlPkg.assignSlv` and `assignRecord` provide cursor-based packing and
unpacking when useful. Clear, commented slices remain appropriate for fixed
wire fields; see [Keep wire fields recognizable](#keep-wire-fields-recognizable).

## Constants, arithmetic and wire layouts

A constant should explain a value's meaning. Name protocol encodings, units,
bounds and policy choices, and comment where defaults come from. Equal values
with different meanings stay separate: nanoseconds per second and the ppb scale
both happen to be a billion.

### Make the calculation readable

For a design running at 125 MHz, a two-second timeout can be expressed directly:

```vhdl
constant TICKS_PER_SECOND_C : unsigned(63 downto 0) := to_unsigned(125000000, 64);
-- Two seconds is the application's timeout policy.
constant TIMEOUT_TICKS_C : unsigned(63 downto 0) := resize(TICKS_PER_SECOND_C*2, 64);
```

Multiplication/division expresses durations more clearly than shifts. Division
by 64 expresses a 1/64-second interval rounded down to whole ticks. Use shifts
when they describe bit placement or fixed-point scaling, and name repeated
conversion calculations:

```vhdl
constant INPUT_FRAC_BITS_C  : natural := 16;
constant OUTPUT_FRAC_BITS_C : natural := 32;
constant FRAC_SHIFT_C       : natural := OUTPUT_FRAC_BITS_C-INPUT_FRAC_BITS_C;

-- Inside comb: signed input in Q16, widened before conversion to Q32.
v.scaledValue := shift_left(resize(signed(inputValue), 64), FRAC_SHIFT_C);
```

Check signedness and intermediate widths before narrowing a result. For example,
resizing after an already-overflowed addition cannot recover the carry. Make
truncation, rounding and overflow policy explicit; keep vector arithmetic wide
enough that long durations do not pass through an overflowing VHDL integer.

### Standard helpers

Check [StdRtlPkg.vhd](../base/general/rtl/StdRtlPkg.vhd) before writing an
equivalent helper. Its common functions have specific conversion and rounding
semantics:

| Helper | Behavior to preserve |
| --- | --- |
| `ite(condition, a, b)` | Selects between values; commonly used in generic-derived constants and static configuration. |
| `wordCount(number, wordSize)` | Rounds a positive count up to whole words. |
| `getTimeRatio(real, real)` | Returns `natural(ROUND(abs(T1/T2)))`; replacing it with a truncating ratio changes behavior. |
| `resize(slv, size, pad)` | Trims upper bits or pads with the supplied bit, default `'0'`. Use the appropriate signed arithmetic overload when sign extension is needed. |
| `toSlv(integer, size)` | Returns zero for negative integers in the current implementation. Use a signed conversion when encoding signed values. |
| `toSl`, `uOr`, `uAnd`, `uXor` | Boolean-to-logic conversion and vector OR/AND/XOR reductions. |

See [AxiStreamGearbox.vhd](../axi/axi-stream/rtl/AxiStreamGearbox.vhd) for
generic-derived sizes and [Heartbeat.vhd](../base/general/rtl/Heartbeat.vhd)
for a timing ratio. Using `ite` does not relax the
[signal-assignment rule](#signal-assignments-in-comb): resolve behavioral
selection before output publication.

SURF helpers have specific size semantics: `bitSize(N)` sizes a value, while
`log2(N)` sizes a count of choices. For example, the value 8 needs four bits,
but eight choices need three. Both helpers return at least one bit for their
small-input cases. Check the actual overloads of arithmetic and conversion
helpers, and preserve array direction and bounds; use `'range` and `'length`
when they express the interface.

### Keep wire fields recognizable

Direct slices with field comments can be clearer than repeated arithmetic on
header-base and byte-offset constants. For example, for a byte array in network
order containing an untagged Ethernet header:

```vhdl
-- EtherType occupies bytes 12 and 13.
bytes(12) := ETH_TYPE_C(15 downto 8);
bytes(13) := ETH_TYPE_C(7 downto 0);
```

The encoding has a name; the field position remains easy to recognize. Use small
accessors when a field extraction or construction repeats. Shared helpers
belong in a package, while entity-specific helpers stay local. Naming every
literal is not useful if the resulting expression hides the layout.

## Reset and CDC rules

### Prefer synchronous reset for behavioral state

**Synchronous reset is the default preference. Encode it in `comb`**, using
`v := REG_INIT_C` after the normal next-state calculations and before `rin`
and output publication, as described in
[reset ordering](#apply-reset-before-publishing-outputs). For a synchronous-only
module, `seq` needs only the clock edge and `r <= rin after TPD_G`; do not move
the behavioral reset branch into `seq`.

Synchronous reset takes effect in the registers on an active clock edge. The
reset must meet the receiving clock's timing requirements and remain asserted
through an active edge. A stopped clock cannot reset those registers. Outputs
intentionally published from `v` can respond to the reset before that edge;
this does not make the state registers asynchronously resettable.

### Use asynchronous reset when the implementation requires it

Asynchronous reset is sometimes necessary. ASIC targets are an important case:
the selected standard-cell library may provide only asynchronous reset pins on
its available resettable registers. Other reasons include state that must reset
while its clock is stopped and device primitives with a required asynchronous
reset. Document the target or functional requirement; the synchronous preference
does not override it.

Encode asynchronous reset in `seq`, with reset in the sensitivity list and the
reset branch before `elsif rising_edge(clk)`. For ordinary behavioral modules
that support both modes, use the mutually exclusive guards shown in the
[two-process example](#two-process-vhdl-style):

- In `comb`, apply `v := REG_INIT_C` when `RST_ASYNC_G = false` and reset is active.
- In `seq`, apply `r <= REG_INIT_C after TPD_G` when `RST_ASYNC_G` and reset is
  active; otherwise capture `rin` on the clock edge.

[AxiLiteRegs.vhd](../axi/axi-lite/rtl/AxiLiteRegs.vhd) is a concrete example.
Default `RST_ASYNC_G` to `false` for new behavioral modules unless their intended
implementation requires otherwise. Expose only supported modes and propagate
the selection to children that share the reset contract.

Reset is part of the interface. Preserve `TPD_G`, `RST_POLARITY_G`,
`RST_ASYNC_G`, default values and optional reset ports when maintaining a module.
Changing reset mode changes behavior and implementation; it is not a style
cleanup. Declaration-time initialization is separate from runtime reset and
must not be assumed to initialize ASIC registers in hardware.

### Reset distribution and implementation exceptions

Synchronize release of an asynchronous reset to each receiving clock domain
and respect the target registers' recovery/removal requirements. Use
[RstSync.vhd](../base/sync/rtl/RstSync.vhd) for asynchronous assertion and
synchronized release with its default configuration. Its `OUT_REG_RST_G`
option changes assertion at the final stage; choose that deliberately when
reset must reach a stopped domain. A reset synchronized to one clock is not
automatically synchronized to another.

[RstPipeline.vhd](../base/general/rtl/RstPipeline.vhd) and `RstPipelineVector`
pipeline reset distribution in a clock domain; they do not replace a reset
synchronizer. Account for their assertion and release latency at connected
interfaces. [FifoAsync.vhd](../base/fifo/rtl/inferred/FifoAsync.vhd) illustrates
separate reset synchronizers for its read and write clocks.

Preserve the specialized clocked templates in synchronizers, inferred memories
and primitive wrappers. For example,
[Synchronizer.vhd](../base/sync/rtl/Synchronizer.vhd) implements both reset modes
in clocked processes, while
[SimpleDualPortRamInferred.vhd](../base/ram/inferred/SimpleDualPortRamInferred.vhd)
resets its read-data register without clearing the memory array. Do not move
these resets into a behavioral `comb` template or add whole-array resets as a
style change; retain inference structure, attributes and supported reset modes.

### Reuse CDC blocks

Use existing `base/sync` blocks for synchronizing levels, transferring pulses,
crossing status and managing reset. `RstPipeline`, `RstPipelineVector` and
`RstSync` cover common reset fanout and release needs. A custom synchronizer,
FIFO or reset pipeline needs a concrete reason the existing block cannot serve.

Choose the crossing for the information being transferred. Independently
synchronizing each bit of a multi-bit value does not make a coherent snapshot.
A stream crossing needs a suitable asynchronous FIFO; a pulse crossing needs
a pulse-transfer mechanism. Consume the synchronized result in the destination
domain, and retain the primitive's inference structure and CDC attributes.

## Bus and protocol semantics

Reuse the SURF record types and helpers for AXI-Lite, AXI4, AXI Stream, SSI, PGP,
SRP and Ethernet. Extend the existing encoder, decoder or stream helper before
creating a second implementation of the same protocol.

An interface includes more than payload values. Backpressure, arbitration order,
burst length, frame boundaries and error sidebands are observable behavior.
A change that delivers the right bytes on a different handshake can still break
its consumer. Keep reset values, readback, response codes and write side effects
deterministic, and keep register names and bit meanings aligned across RTL,
PyRogue, tests and documentation.

### Idle and disabled interfaces

Choose package constants for their transaction behavior. An initial state and
an interface that accepts or answers traffic serve different purposes:

- `AXI_STREAM_MASTER_INIT_C` represents an inactive source.
- `AXI_STREAM_SLAVE_INIT_C` has ready low; `AXI_STREAM_SLAVE_FORCE_C` has ready
  high. Use the latter for an intentional always-accepting sink or a connection
  whose contract needs no backpressure.
- AXI-Lite slave `_INIT_C` records have response-valid low. A disabled crossbar
  destination commonly uses `AXI_LITE_READ_SLAVE_EMPTY_DECERR_C` and
  `AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C` so accesses receive an error response.
  The `_EMPTY_OK_C` and `_EMPTY_SLVERR_C` variants select different response
  policies; preserve the intended behavior.

These constants are defined in
[AxiStreamPkg.vhd](../axi/axi-stream/rtl/AxiStreamPkg.vhd) and
[AxiLitePkg.vhd](../axi/axi-lite/rtl/AxiLitePkg.vhd). The `GEN_NO_PATTERN_CHECK`
branch in [AdcDdrCore.vhd](../devices/AnalogDevices/adcDdr/rtl/AdcDdrCore.vhd)
shows explicit tie-offs for a disabled bank. Static empty responses are SURF
integration idioms; implement transaction handling with the endpoint helpers
when building a functional register slave.

The following sections give the stream and register patterns in more detail.

## AXI Stream conventions

### Records and stream configuration

Use `AxiStreamMasterType` for forward data/valid/sidebands and
`AxiStreamSlaveType` for reverse ready, from
[AxiStreamPkg.vhd](../axi/axi-stream/rtl/AxiStreamPkg.vhd). Connect complete
records between modules. Keep a registered output master and the input slave
record in the owning `RegType`, with the appropriate package initialization
constants or `axiStreamMasterInit(CONFIG_G)`. Structural forwarding and
boundary flattening remain exceptions; do not add storage to a wire-only wrapper.

Treat `AxiStreamConfigType` as part of the interface contract: data width,
`TKEEP` encoding, `TUSER` mode, destination/ID widths and strobe use must agree
across a connection. Do not assume that every configuration uses one keep bit
per byte or identical user-bit placement. Reuse package accessors and existing
SURF resize/packing adapters when representations differ.

### Transfers and backpressure

- Outside reset, a beat transfers on an active clock edge when `tValid` and
  `tReady` are both high. Advance input-consumption state, beat counts and frame
  tracking on that handshake, not on `tValid` alone.
- A producer must offer available data without waiting for downstream ready.
  Once offered, hold `tValid`, data and all associated sidebands stable while
  stalled. A registered master record is retained by `v := r`; do not clear
  its valid every evaluation as though it were a pulse.
- A receiver may advertise available capacity before valid arrives or assert
  ready in the branch that accepts a valid beat. Preserve the module's existing
  convention. In either case, asserting ready must mean the beat can be accepted
  on that edge.
- Resolve downstream consumption before testing output capacity through `v`.
  This allows a consumed beat to be replaced on the same edge when the design
  supports it. Never overwrite a stalled output or claim a new input without
  capacity to retain or process it.
- For a deliberately dropping or filtering receiver, consuming a beat still
  requires its input handshake. Keep the drop decision and frame-draining
  state explicit. AXI Stream has no private cancellation signal: an unrelated
  abort must not silently withdraw a stalled valid beat. Define recovery using
  the interface's reset or documented framing/error behavior.

### Combinational ready outputs

Follow the common SURF AXI Stream pattern: keep the ready field or slave record
in `RegType`, default it through `v` on each evaluation, assert it beside the
logic that can accept the input, and publish it directly from `v`. For example,
`inputReady <= v.inputReady;` or `sAxisSlave <= v.sAxisSlave;`. This is an
intentional combinational output; belonging to `RegType` does not require
publishing the previous cycle's value from `r`. Do not rely on retained ready
state when using this pattern. See [AxiStreamMux.vhd](../axi/axi-stream/rtl/AxiStreamMux.vhd)
and the scalar equivalent in [DspAddSub.vhd](../dsp/generic/fixed/DspAddSub.vhd).

Ready describes acceptance on the current edge. Preserve whether the interface
advertises capacity before valid arrives or asserts ready only with valid.
Account for backpressure, cancellation, reset and whole-record initialization
in the owning logic; do not recreate the readiness decision in the output
assignment section. In particular, accepting an input and initializing its
transaction state must not accidentally clear that same edge's ready value.

### Example: one output slot with combinational input ready

This `comb` excerpt assumes `sAxisSlave : AxiStreamSlaveType` and
`mAxisMaster : AxiStreamMasterType` in `RegType`, initialized with ready and
valid low, plus the usual `r`, `rin` and `seq`. The input and output use the
same stream configuration. Use existing SURF pipeline blocks when a pipeline
is all the module needs; the example shows the flow-control ordering inside a
functional module.

```vhdl
comb : process (r, sAxisMaster, mAxisSlave, axisRst) is
   variable v : RegType;
begin
   v := r;

   -- Resolve this edge's output consumption before input admission.
   v.sAxisSlave.tReady := '0';
   if mAxisSlave.tReady = '1' then
      v.mAxisMaster.tValid := '0';
   end if;

   if v.mAxisMaster.tValid = '0' then
      v.sAxisSlave.tReady := '1';
      if sAxisMaster.tValid = '1' then
         v.mAxisMaster := sAxisMaster;
      end if;
   end if;

   if RST_ASYNC_G = false and axisRst = RST_POLARITY_G then
      v := REG_INIT_C;
   end if;
   rin <= v;

   -- Publish after reset so combinational ready observes the override.
   sAxisSlave  <= v.sAxisSlave;
   mAxisMaster <= r.mAxisMaster;
end process comb;
```

Publishing ready from `r.sAxisSlave` instead would delay backpressure and
change the storage required to honor already-advertised capacity. Do not make
that substitution as a style edit. Use
[AxiStreamPipeline.vhd](../axi/axi-stream/rtl/AxiStreamPipeline.vhd) or a suitable
FIFO when registered ready or a timing break is needed; preserve its buffering,
latency and supported bypass modes. Check compositions for combinational loops
and excessive ready-path depth.

### Reset, framing and integration

The example publishes ready after the synchronous whole-record reset, so ready
is low while synchronous reset is asserted. Some existing SURF modules publish
ready before reset and rely on the shared reset excluding transfers. Preserve
such behavior only as an intentional, documented interface choice; see
[reset ordering](#apply-reset-before-publishing-outputs). Preserve reset polarity,
and clear registered valid and partial-frame state according to the module's
contract. Asynchronous reset still belongs in `seq`; registering or delaying
ready is not a reset fix.

Move data and sidebands together. Preserve byte order, `tKeep`, enabled `tStrb`,
`tLast`, `tDest`, `tId` and `tUser` through stalls, arbitration and width changes.
For SSI, use [SsiPkg.vhd](../protocols/ssi/rtl/SsiPkg.vhd) helpers for SOF/EOFE
and preserve end-of-frame behavior. Document routing, interleaving, partial-beat
and malformed-frame assumptions rather than silently relying on them.

Keep stream clock/reset ownership explicit. A ready/valid connection does not
perform CDC; use existing SURF asynchronous FIFO/stream crossing blocks. A
FIFO's `AxiStreamCtrlType.pause`/overflow interface has its own capacity and
latency contract and must not be treated as a per-beat `tReady` substitute.

Review back-to-back transfers, simultaneous consume/refill, prolonged stalls
including the final beat, reset with work pending, and sideband alignment.
Use the shared [regression methodology](../tests/README.md) for executable
checks, subject to the task's verification authorization.

## AXI-Lite register implementation

Keep a block's configuration, diagnostics, snapshots and AXI decode in the
functional block that owns them. The AXI slave records live in its existing
`RegType`; a separate register wrapper is usually unnecessary. Central registers
are useful for shared identification and coordination, not as a collection of
every child's local bank.

### A contiguous register section

Use the SURF endpoint helpers for ordinary register banks. The following excerpt
assumes `AxiLitePkg` is imported, `ep` is a process-local `AxiLiteEndpointType`,
and `RegType` owns `axiWriteSlave`, `axiReadSlave`, `threshold`, `frameCount` and
`clearCount`. Initialize the slave records with their `AXI_LITE_*_INIT_C` values.

```vhdl
-- In comb, after v := r:
v.clearCount := '0';
axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

axiSlaveRegister(ep, x"000", 0, v.threshold);
axiSlaveRegisterR(ep, x"004", 0, r.frameCount);
axiSlaveRegister(ep, x"008", 0, v.clearCount);

-- This example's clear command wins over a count update earlier in comb.
if v.clearCount = '1' then
   v.frameCount := (others => '0');
end if;

axiSlaveDefault(ep, v.axiWriteSlave, v.axiReadSlave, AXI_RESP_DECERR_C);

-- Output publication:
axiWriteSlave <= r.axiWriteSlave;
axiReadSlave  <= r.axiReadSlave;
```

Call `axiSlaveWaitTxn` once near the start of the register section, group direct
register calls by address, handle submission checks and side effects, then close
with `axiSlaveDefault`. The helpers qualify transactions themselves, so the map
needs no surrounding read-enable/write-enable guard. A rejection that changes
the transaction response must be resolved before the default helper.

Use `axiSlaveRegister` for writable fields and `axiSlaveRegisterR` for read-only
values. Preserve writable readback unless the hardware contract says otherwise.
For strobes, counter resets, FIFO writes and write-one-to-clear fields, make the
side effect and its priority visible beside the map and describe it in PyRogue.
Synchronize status from other clock domains before exposing it through registers.

### Addresses and bank connections

Write fixed offsets as hex literals such as `x"3FC"`. Each digit supplies four
decode bits, so choose the literal width with the bank aperture and crossbar
configuration. Changing `x"3FC"` to a wider literal is a decode change, not just
formatting. Computed offsets remain appropriate for repeated register arrays.

Follow the alignment and strobe behavior of the selected
[AxiLitePkg.vhd](../axi/axi-lite/rtl/AxiLitePkg.vhd) helper. Word-register helpers
ignore address bits 1:0 when matching. Once a helper has responded,
`axiSlaveDefault` cannot turn that low-bit alias into an error; it handles
unmapped accesses, commonly with `AXI_RESP_DECERR_C`. Add stricter alignment
checks only when the block's contract calls for them.

Compose banks with the standard crossbar, address-map helpers and base-address
generics. Name each distinct destination and use its index for all four buses:

```vhdl
-- Port-map excerpt for the RX register bank:
axiReadMaster  => readMasters(RX_AXIL_INDEX_C),   -- [in]
axiReadSlave   => readSlaves(RX_AXIL_INDEX_C),     -- [out]
axiWriteMaster => writeMasters(RX_AXIL_INDEX_C),  -- [in]
axiWriteSlave  => writeSlaves(RX_AXIL_INDEX_C)     -- [out]
```

Use those same indices in address-map aggregates and child base-address lookups.
A common count such as `NUM_AXIL_MASTERS_C` defines bus-array bounds and crossbar
slot counts. Preserve slot order because it determines the register ABI. The
sole upstream slave can use `(0)`; replicated channels can use a generate index
or a named base plus that index. See
[ClinkTop.vhd](../protocols/clink/rtl/ClinkTop.vhd) and
[Pgp3Gtx7.vhd](../protocols/pgp/pgp3/gtx7/rtl/Pgp3Gtx7.vhd).

Configure apertures directly rather than rewriting bus addresses or clearing
bits to compensate for a crossbar mismatch. Test fixtures should exercise the
real register bank through a thin adapter; they do not need a parallel direct
configuration path or a new AXI-enable generic. Keep established public
interfaces compatible when maintaining existing blocks.

Update PyRogue, focused tests and register-map documentation with changes to
offsets, fields, access modes or reset values.

## Simulation and testbench VHDL

Keep VHDL wrappers focused on connectivity: clocks/resets, record flattening,
tie-offs, small integration topologies and required vendor models. Prefer
existing SURF adapters for bus packing. Name the real instance `U_DUT`, unless
the fixture intentionally contains multiple peer instances, and annotate its
port map with directions just as in production RTL.

Use Python/cocotb for new stimulus, transaction sequencing, independent models
and randomized or parameterized checks. Maintenance of an existing VHDL bench
does not require a cocotb migration. Assertions for invalid generics or array
shapes belong in the RTL so they also protect users outside the test fixture.

Reusable adapters live beside their RTL family in `wrappers/` or
`ip_integrator/`; pure simulation models belong in `sim/` and VHDL benches in
`tb/`. Executable cocotb tests live under `tests/`. A thin wrapper should expose
the production behavior, not hide a second implementation of it.

## VHDL headers

Start maintained VHDL with the standard SLAC/SURF banner. A useful description
introduces the module's role, explains the data/control path and states the
handshake, clock and reset assumptions a new reader needs. For example:

```vhdl
-- Description: Buffers one measurement between the sampler and formatter.
--
-- Captures a complete sample when valid and ready are asserted together.
-- Holds the sample and its channel tag stable while the formatter is stalled.
-- Input ready is combinational; the output sample and valid are registered.
-- All ports use sampleClk, and sampleRst discards any pending sample.
```

A restatement of the module name supplies much less information. Within the
implementation, comments are most useful for units, priority and ordering
constraints. Preserve vendor, generated and third-party headers rather than
normalizing them during an unrelated edit.

The standard banner is:

```vhdl
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Module purpose and role in the surrounding architecture.
--
-- Explain the main processing stages and how inputs become outputs.
-- Describe the relevant handshake, state ownership, timing and reset contract.
-- Include the assumptions a first-time reader needs to understand the design.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
```

## RTL review checklist

Read the control flow and trace a transaction through the module before relying
on lint or test results. These questions catch common mistakes:

- **State and ownership:** Does each clock domain have its own record and
  process pair? Do output records own their values? Are retained state and
  temporary calculations clearly distinguished?
- **Registered boundaries:** Do functional outputs come directly from registers,
  without selection, qualification or arithmetic after them? Does each exception
  have a concrete interface requirement or buffering/latency tradeoff, with
  producer and consumer timing considered together?
- **Timing:** Are payload, valid and controls aligned? What happens on a stall,
  simultaneous consume/refill, cancellation or command completion? Do whole-record
  assignments preserve decisions made earlier in `comb`?
- **Reset and CDC:** Are startup values, reset options and `TPD_G` preserved?
  Is synchronous reset the default, with any asynchronous requirement explained?
  Does the synchronous reset override precede `rin` and output publication,
  including reset handling for outputs derived from `v` or scratch variables?
  Are any intentional ordering exceptions justified by the interface?
  Is asynchronous reset release synchronized to each receiving domain, with
  stopped-clock behavior and reset distribution latency accounted for?
  Does every crossing use the right primitive? Are memory/synchronizer inference
  templates and synthesis attributes intact?
- **Arithmetic and parameters:** Are widths, signedness, rounding and overflow
  deliberate? Do array bounds/direction and supported zero/one cases work?
  Do constants explain units and policy? Are generic settings propagated and
  alternative generate branches complete?
- **Interfaces and software:** Are byte order, framing and sidebands preserved?
  Do packed sizes and conversion helpers agree? Are optional and disabled
  interfaces tied off with the intended transaction behavior? Do AXI decode,
  side effects, PyRogue and the documented map agree?
- **Readability and integration:** Can a reader follow `comb` in order, with
  unconditional `<=` publication from registered fields or documented exceptions,
  no conditional signal assignments, and a clock/reset-only `seq`? Are statements
  and associations laid out clearly, wrappers thin, headers useful and ruckus
  manifests current? Were unrelated vendor/generated files left alone?
- **Evidence:** Which lint, build and behavioral checks ran, and what remains
  unverified? A clean compile or generic synthesis netlist does not establish
  behavioral equivalence, FPGA timing or resource use.

Use [tests/README.md](../tests/README.md) for the regression method and
[AGENTS.md](../AGENTS.md#tests-and-verification) for repository verification
practice. Respect any agreed review gate before running regressions, and record
skipped checks and remaining risks with the change.
