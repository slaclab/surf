# Devices

This tree contains vendor and component-specific RTL support. It is organized primarily by manufacturer, with shared transceiver support in `transceivers/`.

## Layout

- Manufacturer folders such as [`AnalogDevices/`](AnalogDevices/), `Microchip/`, `Micron/`, `Silabs/`, `Ti/`, and `Xilinx/` hold individual device cores.
- Device folders usually contain `rtl/` for synthesizable register/control logic, optional `sim/` models, optional FPGA-family implementation directories, and a local `ruckus.tcl`.
- `transceivers/` holds generic pluggable transceiver support such as SFP/QSFP control and status blocks.

Keep register maps and control names aligned with vendor data sheets and with the matching PyRogue modules under `python/surf/devices` when they exist. Add new device sources to the nearest `ruckus.tcl`.

The Analog Devices tree includes the shared [`adcDdr`](AnalogDevices/adcDdr/)
source-synchronous readout and software-calibration infrastructure used by the
normalized AD9249, AD9252, and AD9681 implementations.
