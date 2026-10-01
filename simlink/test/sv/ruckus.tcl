# Vivado-free ruckus project for the self-driving SimLink SV tops in this
# directory.
source $::env(RUCKUS_PROC_TCL)

# surf's simlink tree is located relative to this file because MODULES is the
# surf root in CI (ruckus cloned into ./ruckus) but surf's parent locally, so
# no MODULES-relative path can name surf.
loadRuckusTcl [file normalize "$::DIR_PATH/../.."]

# All self-driving tops load; SIM_TOP picks the root that is elaborated
# (mirrors the ldrd sim_verilog consumer).
loadSource -sim_only -dir "$::DIR_PATH"
