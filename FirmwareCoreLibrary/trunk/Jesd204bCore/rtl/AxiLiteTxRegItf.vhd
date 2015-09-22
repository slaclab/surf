-------------------------------------------------------------------------------
-- Title      : Axi-lite interface for register access  
-------------------------------------------------------------------------------
-- File       : AxiLiteTxRegItf.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-08-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  Register decoding for JESD TX core
--               0x00 (RW)- Enable TX lanes (L_G downto 1)
--               0x01 (RW)- SYSREF delay (5 bit)
--               0x02 (RW)- Enable AXI Stream transfer (L_G downto 1) (Not used-Reserved)
--               0x03 (RW)- AXI stream packet size (24 bit) (Not used-Reserved)
--               0x04 (RW)- Common control register:
--                   bit 0: JESD Subclass (Default '1')
--                   bit 1: Enable control character replacement(Default '1')
--                   bit 2: Reset MGTs (Default '0') 
--                   bit 3: Clear Registered errors (Default '0')  (Not used-Reserved)
--                   bit 4: Invert nSync (Default '1'-inverted)
--                   bit 5: Enable test signal. Note: Has to be toggled if test signal type is changed to align the lanes.
--               0x05 (RW)- Test signal control: Ramp step and Square signal period control
--                   bit 31-16: Square signal period (Clock cycles)
--                   bit 15-0:  Ramp step (Clock cycles)
--               0x06 (RW)- Square wave test signal amplitude low
--               0x07 (RW)- Square wave test signal amplitude high
--               0x1X (R) - Lane X status
--                   bit 0: GT Reset done
--                   bit 1: Transmuting valid data
--                   bit 2: Transmitting ILA sequence
--                   bit 3: Synchronisation input status 
--                   bit 4: TX lane enabled status
--                   bit 5: SysRef detected (active only when the TX lane is enabled)
--               0x2X (RW) - Lane X signal select (Mux control)
--                   bit 5-4: Test signal select:
--                         "00" - Saw signal increment
--                         "01" - Saw signal decrement
--                         "10" - Square wave
--                         "11" - Output zero
--                   bit 1-0: Signal source select:
--                         "00" - Output zero 
--                         "01" - Internal FPGA source (Not used-Reserved)
--                         "10" - AXI Stream data source 
--                         "11" - Test signal
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;

entity AxiLiteTxRegItf is
  generic (
    -- General Configurations
    TPD_G            : time            := 1 ns;
    AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
    -- JESD 
    -- Number of TX lanes (1 to 16)
    L_G              : positive        := 2;

    F_G : positive := 2
    );    
  port (
    -- JESD axiClk
    axiClk_i : in sl;
    axiRst_i : in sl;

    -- Axi-Lite Register Interface (locClk domain)
    axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
    axilWriteSlave  : out AxiLiteWriteSlaveType;

    -- JESD devClk
    devClk_i : in sl;
    devRst_i : in sl;

    -- JESD registers
    -- Status
    statusTxArr_i : in txStatuRegisterArray(L_G-1 downto 0);

    -- Control
    muxOutSelArr_o  : out Slv3Array(L_G-1 downto 0);
    sigTypeArr_o    : out Slv2Array(L_G-1 downto 0);
    sysrefDlyTx_o   : out slv(SYSRF_DLY_WIDTH_C-1 downto 0);
    enableTx_o      : out slv(L_G-1 downto 0);
    replEnable_o    : out sl;
    swTrigger_o     : out slv(L_G-1 downto 0);
    rampStep_o      : out slv(PER_STEP_WIDTH_C-1 downto 0);
    squarePeriod_o  : out slv(PER_STEP_WIDTH_C-1 downto 0);
    subClass_o      : out sl;
    gtReset_o       : out sl;
    clearErr_o      : out sl;
    invertSync_o    : out sl;
    enableTestSig_o : out sl;

    posAmplitude_o : out slv(F_G*8-1 downto 0);
    negAmplitude_o : out slv(F_G*8-1 downto 0);

    axisPacketSize_o : out slv(23 downto 0)
    );   
end AxiLiteTxRegItf;

architecture rtl of AxiLiteTxRegItf is

  type RegType is record
    -- JESD Control (RW)
    enableTx        : slv(L_G-1 downto 0);
    commonCtrl      : slv(5 downto 0);
    sysrefDlyTx     : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
    swTrigger       : slv(L_G-1 downto 0);
    axisPacketSize  : slv(23 downto 0);
    signalSelectArr : Slv8Array(L_G-1 downto 0);
    periodStep      : slv(31 downto 0);
    posAmplitude    : slv(F_G*8-1 downto 0);
    negAmplitude    : slv(F_G*8-1 downto 0);

    -- AXI lite
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;
  
  constant REG_INIT_C : RegType := (
    enableTx        => (others => '0'),
    commonCtrl      => "110011",
    sysrefDlyTx     => (others => '0'),
    swTrigger       => (others => '0'),
    axisPacketSize  => AXI_PACKET_SIZE_DEFAULT_C,
    --signalSelectArr=> (others => b"0010_0011"), -- Set to squarewave
    --periodStep     => intToSlv(1,PER_STEP_WIDTH_C) & intToSlv(4096,PER_STEP_WIDTH_C),
    signalSelectArr => (others => b"0000_0001"),  -- Set to external
    periodStep      => intToSlv(1, PER_STEP_WIDTH_C) & intToSlv(1, PER_STEP_WIDTH_C),
    --signalSelectArr=> (others => b"0001_0011"), -- Set to ramp
    --periodStep     => intToSlv(1,PER_STEP_WIDTH_C) & intToSlv(1,PER_STEP_WIDTH_C),      

    posAmplitude => (others => '1'),
    negAmplitude => (others => '0'),

    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  -- Integer address
  signal s_RdAddr : natural := 0;
  signal s_WrAddr : natural := 0;

  -- Synced status signals
  signal s_statusTxArr : txStatuRegisterArray(L_G-1 downto 0);
  
begin

  -- Convert address to integer (lower two bits of address are always '0')
  s_RdAddr <= slvToInt(axilReadMaster.araddr(9 downto 2));
  s_WrAddr <= slvToInt(axilWriteMaster.awaddr(9 downto 2));

  comb : process (axilReadMaster, axilWriteMaster, r, axiRst_i, s_statusTxArr, s_RdAddr, s_WrAddr) is
    variable v             : RegType;
    variable axilStatus    : AxiLiteStatusType;
    variable axilWriteResp : slv(1 downto 0);
    variable axilReadResp  : slv(1 downto 0);
  begin
    -- Latch the current value
    v := r;

    ----------------------------------------------------------------------------------------------
    -- Axi-Lite interface
    ----------------------------------------------------------------------------------------------
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

    if (axilStatus.writeEnable = '1') then
      axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
      case (s_WrAddr) is
        when 16#00# =>                  -- ADDR (0)
          v.enableTx := axilWriteMaster.wdata(L_G-1 downto 0);
        when 16#01# =>                  -- ADDR (4)
          v.sysrefDlyTx := axilWriteMaster.wdata(SYSRF_DLY_WIDTH_C-1 downto 0);
        when 16#02# =>                  -- ADDR (8)
          v.swTrigger := axilWriteMaster.wdata(L_G-1 downto 0);
        when 16#03# =>                  -- ADDR (12)
          v.axisPacketSize := axilWriteMaster.wdata(23 downto 0);
        when 16#04# =>                  -- ADDR (16)
          v.commonCtrl := axilWriteMaster.wdata(5 downto 0);
        when 16#05# =>                  -- ADDR (20)
          v.periodStep := axilWriteMaster.wdata;
        when 16#06# =>                  -- ADDR (24)
          v.negAmplitude := axilWriteMaster.wdata(F_G*8-1 downto 0);
        when 16#07# =>                  -- ADDR (28)
          v.posAmplitude := axilWriteMaster.wdata(F_G*8-1 downto 0);
        when 16#20# to 16#2F# =>
          for I in (L_G-1) downto 0 loop
            if (axilWriteMaster.awaddr(5 downto 2) = I) then
              v.signalSelectArr(I) := axilWriteMaster.wdata(7 downto 0);
            end if;
          end loop;
        when others =>
          axilWriteResp := AXI_ERROR_RESP_G;
      end case;
      axiSlaveWriteResponse(v.axilWriteSlave);
    end if;

    if (axilStatus.readEnable = '1') then
      axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
      v.axilReadSlave.rdata := (others => '0');
      case (s_RdAddr) is
        when 16#00# =>                  -- ADDR (0)
          v.axilReadSlave.rdata(L_G-1 downto 0) := r.enableTx;
        when 16#01# =>                  -- ADDR (4)
          v.axilReadSlave.rdata(SYSRF_DLY_WIDTH_C-1 downto 0) := r.sysrefDlyTx;
        when 16#02# =>                  -- ADDR (8)
          v.axilReadSlave.rdata(L_G-1 downto 0) := r.swTrigger;
        when 16#03# =>                  -- ADDR (12)
          v.axilReadSlave.rdata(23 downto 0) := r.axisPacketSize;
        when 16#04# =>                  -- ADDR (16)
          v.axilReadSlave.rdata(5 downto 0) := r.commonCtrl;
        when 16#05# =>                  -- ADDR (20)
          v.axilReadSlave.rdata := r.periodStep;
        when 16#06# =>                  -- ADDR (24)
          v.axilReadSlave.rdata(F_G*8-1 downto 0) := r.negAmplitude;
        when 16#07# =>                  -- ADDR (28)
          v.axilReadSlave.rdata(F_G*8-1 downto 0) := r.posAmplitude;
        when 16#10# to 16#1F# =>
          for I in (L_G-1) downto 0 loop
            if (axilReadMaster.araddr(5 downto 2) = I) then
              v.axilReadSlave.rdata(TX_STAT_WIDTH_C-1 downto 0) := s_statusTxArr(I);
            end if;
          end loop;
        when 16#20# to 16#2F# =>
          for I in (L_G-1) downto 0 loop
            if (axilReadMaster.araddr(5 downto 2) = I) then
              v.axilReadSlave.rdata(7 downto 0) := r.signalSelectArr(I);
            end if;
          end loop;
        when others =>
          axilReadResp := AXI_ERROR_RESP_G;
      end case;
      axiSlaveReadResponse(v.axilReadSlave);
    end if;

    -- Reset
    if (axiRst_i = '1') then
      v := REG_INIT_C;
    end if;

    -- Register the variable for next clock cycle
    rin <= v;

    -- Outputs
    axilReadSlave  <= r.axilReadSlave;
    axilWriteSlave <= r.axilWriteSlave;
    
  end process comb;

  seq : process (axiClk_i) is
  begin
    if rising_edge(axiClk_i) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  -- Input assignment and synchronisation
  GEN_0 : for I in L_G-1 downto 0 generate
    SyncFifo_IN0 : entity work.SynchronizerFifo
      generic map (
        TPD_G        => TPD_G,
        DATA_WIDTH_G => TX_STAT_WIDTH_C
        )
      port map (
        wr_clk => devClk_i,
        din    => statusTxArr_i(I),
        rd_clk => axiClk_i,
        dout   => s_statusTxArr(I)
        );  
  end generate GEN_0;


  -- Output assignment and synchronisation
  SyncFifo_OUT0 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => SYSRF_DLY_WIDTH_C
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.sysrefDlyTx,
      rd_clk => devClk_i,
      dout   => sysrefDlyTx_o
      );

  SyncFifo_OUT1 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => L_G
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.enableTx,
      rd_clk => devClk_i,
      dout   => enableTx_o
      );

  SyncFifo_OUT2 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => L_G
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.swTrigger,
      rd_clk => devClk_i,
      dout   => swTrigger_o
      );

  SyncFifo_OUT3 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 24
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.axisPacketSize,
      rd_clk => devClk_i,
      dout   => axisPacketSize_o
      );

  Sync_OUT4 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(0),
      dataOut => subClass_o
      );

  Sync_OUT5 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(1),
      dataOut => replEnable_o
      );

  Sync_OUT6 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(2),
      dataOut => gtReset_o
      );

  Sync_OUT7 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(3),
      dataOut => clearErr_o
      );

  Sync_OUT8 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(4),
      dataOut => invertSync_o
   );    
      
  Sync_OUT9 : entity work.Synchronizer
    generic map (
      TPD_G => TPD_G
      )
    port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => r.commonCtrl(5),
      dataOut => enableTestSig_o
      );

  SyncFifo_OUT10 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => PER_STEP_WIDTH_C
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.periodStep(PER_STEP_WIDTH_C-1 downto 0),
      rd_clk => devClk_i,
      dout   => rampStep_o
      );

  SyncFifo_OUT11 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => PER_STEP_WIDTH_C
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.periodStep(16+PER_STEP_WIDTH_C-1 downto 16),
      rd_clk => devClk_i,
      dout   => squarePeriod_o
      );

  SyncFifo_OUT12 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => F_G*8
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.posAmplitude,
      rd_clk => devClk_i,
      dout   => posAmplitude_o
      );

  SyncFifo_OUT13 : entity work.SynchronizerFifo
    generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => F_G*8
      )
    port map (
      wr_clk => axiClk_i,
      din    => r.negAmplitude,
      rd_clk => devClk_i,
      dout   => negAmplitude_o
      );

  GEN_1 : for I in L_G-1 downto 0 generate
    SyncFifo_OUT0 : entity work.SynchronizerFifo
      generic map (
        TPD_G        => TPD_G,
        DATA_WIDTH_G => 3
        )
      port map (
        wr_clk => axiClk_i,
        din    => r.signalSelectArr(I)(2 downto 0),
        rd_clk => devClk_i,
        dout   => muxOutSelArr_o(I)
        );

    SyncFifo_OUT1 : entity work.SynchronizerFifo
      generic map (
        TPD_G        => TPD_G,
        DATA_WIDTH_G => 2
        )
      port map (
        wr_clk => axiClk_i,
        din    => r.signalSelectArr(I)(5 downto 4),
        rd_clk => devClk_i,
        dout   => sigTypeArr_o(I)
        );
  end generate GEN_1;

---------------------------------------------------------------------
end rtl;
