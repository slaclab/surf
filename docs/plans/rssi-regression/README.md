# RSSI Regression Task

This directory tracks the plan for adding focused cocotb regressions for the
SURF RSSI RTL under `protocols/rssi/v1/`.

Current status: the RSSI regression suite now covers the original leaf-FSM and
core integration findings plus the 2026-05-28 follow-up expansion for partial
`TKEEP`, BUSY recovery, reconnect lifecycle, full-core AXI-Lite control,
checksum-disabled integration, and transport-output backpressure. The latest
coverage notes and validation commands are in `progress.md`; compact resume
context is in `handoff.md`.

Start with `handoff.md` when resuming implementation. Use `plan.md` for the
original test strategy, `progress.md` for chronological status and validation,
and `rtl-changes.md` for production RTL changes made during the task.
