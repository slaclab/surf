# Software-Firmware co-simulation with VCS and Rogue

## Instantiate `RogueStreamSimWrap` in Firmware

The firmware will need an instance of `RogueStreamSimWrap` per Virtual Channel / TDEST.

For cases where a PGP2b interface is being emulated, you can use `RoguePgpSim` instead.
This will instantiate 4 `RogueStreamSimWrap` instances, one per VC. It will also
instantiate a 5th instance specifically for OpCodes.

The `DEST_ID_G` and `USER_ID_G` generics constitute the channel addressing.
You will use these same numbers when instantiating the streams on the software side.

Example:

``` VHDL

SIM_GEN : if (SIMULATION_G) generate
   DESTS : for i in 1 downto 0 generate
    U_RogueStreamSimWrap_1 : entity work.RogueStreamSimWrap
         generic map (
            TPD_G               => TPD_G,
            DEST_ID_G           => i,
            USER_ID_G           => 1,
            COMMON_MASTER_CLK_G => true,
            COMMON_SLAVE_CLK_G  => true,
            AXIS_CONFIG_G       => AXIS_CONFIG_C)
         port map (
            clk         => pgpClk,            -- [in]
            rst         => pgpRst,            -- [in]
            sAxisClk    => pgpClk,            -- [in]
            sAxisRst    => pgpRst,            -- [in]
            sAxisMaster => txMasters(i),      -- [in]
            sAxisSlave  => txSlaves(i),       -- [out]
            mAxisClk    => pgpClk,            -- [in]
            mAxisRst    => pgpRst,            -- [in]
            mAxisMaster => rxMasters(i),      -- [out]
            mAxisSlave  => rxSlaves(i));      -- [in]
   end generate DESTS;
end generate SIM_GEN;
HW_GEN : if (not SIMULATION_G) generate
  -- Instantiate normal PGP or Ethernet/UDP blocks here
end generate HW_GEN;
```

#### Warning

> `RogueStreamSimWrap uses normal AxiStream flow control with AxiStreamSlave.
> PGP blocks use PAUSE based flow control with AxiStreamCtrl for RX streams

This means you'll probably have to do something like this:

``` VHDL
U_SRPv3 : entity work.SrpV3AxiLite
   generic map (
      TPD_G               => TPD_G,
      SLAVE_READY_EN_G    => SIMULATION_G, -- Use READY when in SIMULATION mode
      GEN_SYNC_FIFO_G     => false,
      AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
   port map (
      -- Streaming Slave (Rx) Interface (sAxisClk domain) 
      sAxisClk         => pgpClk,
      sAxisRst         => pgpRst,
      sAxisMaster      => rxMasters(0),
      sAxisSlave       => rxSlaves(0),
      sAxisCtrl        => rxCtrl(0),
      -- Streaming Master (Tx) Data Interface (mAxisClk domain)
      mAxisClk         => pgpClk,
      mAxisRst         => pgpRst,
      mAxisMaster      => txMasters(0),
      mAxisSlave       => txSlaves(0),
      -- AXI Lite Bus (axilClk domain)
      axilClk          => axilClk,
      axilRst          => axilClk,
      mAxilReadMaster  => mAxilReadMaster,
      mAxilReadSlave   => mAxilReadSlave,
      mAxilWriteMaster => mAxilWriteMaster,
      mAxilWriteSlave  => mAxilWriteSlave);
```

Note thate `SLAVE_READY_EN_G` gets set to `True` when compiling for simulation.

## Instantiate `StreamSim` in Software

The class `pyrogue.interfaces.simulation.StreamSim` is a Rogue Stream Master+Slave.
You can instantiate and use it in place of `pyrogue.protocols.UdpRssiPack` or `rogue.hardware.pgp.PgpCard`.

Example:

```python
 if mode == "SIM":
     dest0 = pyrogue.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=1, ssi=True)
     dest1 = pyrogue.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=1, ssi=True)
 
 elif mode == "HW":
     udp = pyrogue.protocols.UdpRssiPack( host='192.168.1.10', port=8192, packVer=2 )                
     dest0 = udp.application(dest=0)
     dest1 = udp.application(dest=1)
```

Note that `StreamSim` `dest=` and `uid=` parameters correspond to the `DEST_ID_G` and `USER_ID_G` generics respectively.

## Symlink the SURF simlink folder into the firmware target folder

```bash
> cd firmawre/targets/Project1
> ln -s ../../submodules/surf/axi/simlink/ simlink
```

## Build and run your firmware with VCS

First, you'll need to setup the Vivado and VCS environment if you haven't already:

```tcsh
> source /afs/slac/g/reseng/xilinx/vivado_2018.1/Vivado/2018.1/settings64.csh
> source /afs/slac/g/reseng/synopsys/vcs-mx/M-2017.03-1/settings.csh
> source /path/to/rogue/setup_slac.csh
> source /path/to/rogue/setup_rogue.csh
```

**VCS version N-2017.12-1 does not work!**

Also, your makefile needs to set:

```export REMOVE_UNUSED_CODE = 1```

Then make your firmware with VCS

```tcsh
> cd firmware/targets/Project1
> make vcs
```

What `make vcs` does is build VCS project makefiles based on your Vivado project heirarchy.
When `make vcs` is done it will give you instructions on how to procede:


```
********************************************************
The VCS simulation script has been generated.
To compile and run the simulation:
	$ cd /u/re/bareese/projects/kpix/firmware/build/DesyTracker/DesyTracker_project.sim/sim_1/behav/
	$ ./sim_vcs_mx.sh
	$ source setup_env.csh
	$ ./simv
********************************************************
```

You might get the following error:

>Error-[VH-DANGLEVL-NA] VL top in pure VHDL flow
>  A pure VHDL design is currently being simulated. In this pure VHDL design 
>  flow, dangling verilog top(s) 'xil_defaultlib.glbl' have been specified and 
>  this is not supported by VCS.
>  Either remove the dangling verilog top(s) from vcs command line, or modify 
>  the pure VHDL design to mixed HDL.

To fix it, open up `sim_vcs_mx.sh` and make this change:
```diff
# RUN_STEP: <elaborate>
elaborate()
{
-  vcs $vcs_elab_opts xil_defaultlib.DesyTrackerTb xil_defaultlib.glbl -o simv
+  vcs $vcs_elab_opts xil_defaultlib.DesyTrackerTb -o simv
}
```

Now source the environment file and run vcs:

```tcsh
> source setup_env.csh
> ./simv -gui&
```

This will launch the GUI. You can drag whatever you want to see into the waveform viewer then start the simulation running.

## Run the software

In a separate terminal, launch your Rogue GUI or script that uses `pyrogue.interfaces.simulation.StreamSim`.
It should act on the running VCS sim.