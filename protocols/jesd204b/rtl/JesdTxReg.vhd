-------------------------------------------------------------------------------
-- File       : JesdTxReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2016-02-12
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface for register access  
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;

entity JesdTxReg is
   generic (
      -- General Configurations
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      -- JESD 
      L_G : positive range 1 to 16 := 2;
      F_G : positive := 2);
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
      scrEnable_o     : out sl;
      invertData_o    : out slv(L_G-1 downto 0);   
      rampStep_o      : out slv(PER_STEP_WIDTH_C-1 downto 0);
      squarePeriod_o  : out slv(PER_STEP_WIDTH_C-1 downto 0);
      subClass_o      : out sl;
      gtReset_o       : out sl;
      clearErr_o      : out sl;
      invertSync_o    : out sl;
      enableTestSig_o : out sl;

      posAmplitude_o : out slv(F_G*8-1 downto 0);
      negAmplitude_o : out slv(F_G*8-1 downto 0);
      
      -- TX Configurable Driver Ports
      txDiffCtrl    : out Slv8Array(L_G-1 downto 0);
      txPostCursor  : out Slv8Array(L_G-1 downto 0);
      txPreCursor   : out Slv8Array(L_G-1 downto 0);       
      txPolarity    : out slv(L_G-1 downto 0);       
      loopback      : out slv(L_G-1 downto 0));       
end JesdTxReg;

architecture rtl of JesdTxReg is

   type RegType is record
      -- JESD Control (RW)
      enableTx        : slv(L_G-1 downto 0);
      invertData      : slv(L_G-1 downto 0);      
      commonCtrl      : slv(6 downto 0);
      sysrefDlyTx     : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      signalSelectArr : Slv8Array(L_G-1 downto 0);
      periodStep      : slv(31 downto 0);
      posAmplitude    : slv(F_G*8-1 downto 0);
      negAmplitude    : slv(F_G*8-1 downto 0);
      txDiffCtrl      : Slv8Array(L_G-1 downto 0);
      txPostCursor    : Slv8Array(L_G-1 downto 0);
      txPreCursor     : Slv8Array(L_G-1 downto 0);  
      txPolarity      : slv(L_G-1 downto 0);       
      loopback        : slv(L_G-1 downto 0);        
      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      enableTx        => (others => '0'),
      invertData     => (others => '0'),      
      commonCtrl      => "0110011",
      sysrefDlyTx     => (others => '0'),
      --signalSelectArr=> (others => b"0010_0011"), -- Set to squarewave
      --periodStep     => intToSlv(1,PER_STEP_WIDTH_C) & intToSlv(4096,PER_STEP_WIDTH_C),
      signalSelectArr => (others => b"0000_0001"),  -- Set to external
      periodStep      => intToSlv(1, PER_STEP_WIDTH_C) & intToSlv(1, PER_STEP_WIDTH_C),
      --signalSelectArr=> (others => b"0001_0011"), -- Set to ramp
      --periodStep     => intToSlv(1,PER_STEP_WIDTH_C) & intToSlv(1,PER_STEP_WIDTH_C),      

      posAmplitude => (others => '1'),
      negAmplitude => (others => '0'),
      
      txDiffCtrl    => (others => x"FF"),
      txPostCursor  => (others => x"00"),
      txPreCursor   => (others => x"00"),       
      txPolarity    => (others => '0'),
      loopback      => (others => '0'),

      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Integer address
   signal s_RdAddr : natural := 0;
   signal s_WrAddr : natural := 0;

   -- Synced status signals
   signal s_statusTxArr : txStatuRegisterArray(L_G-1 downto 0);
   signal s_statusCnt   : SlVectorArray(L_G-1 downto 0, 31 downto 0);
   signal s_adcValids   : slv(L_G-1 downto 0);
   
begin

   ----------------------------------------------------------------------------------------------
   -- Data Valid Status Counter
   ----------------------------------------------------------------------------------------------
   GEN_LANES : for I in L_G-1 downto 0 generate
      s_adcValids(I) <= statusTxArr_i(I)(1);
   end generate GEN_LANES;
   
   
   U_SyncStatusVector : entity work.SyncStatusVector
   generic map (
      TPD_G          => TPD_G,
      OUT_POLARITY_G => '1',
      CNT_RST_EDGE_G => true,
      CNT_WIDTH_G    => 32,
      WIDTH_G        => L_G)     
   port map (
      -- Input Status bit Signals (wrClk domain)
      statusIn             => s_adcValids,
      -- Output Status bit Signals (rdClk domain)  
      statusOut            => open,
      -- Status Bit Counters Signals (rdClk domain) 
      cntRstIn             => r.commonCtrl(3),
      cntOut               => s_statusCnt,
      -- Clocks and Reset Ports
      wrClk                => devClk_i,
      rdClk                => axiClk_i);

   -- Convert address to integer (lower two bits of address are always '0')
   s_RdAddr <= slvToInt(axilReadMaster.araddr(9 downto 2));
   s_WrAddr <= slvToInt(axilWriteMaster.awaddr(9 downto 2));

   comb : process (axilReadMaster, axilWriteMaster, r, axiRst_i, s_statusTxArr, s_RdAddr, s_WrAddr, s_statusCnt) is
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
            when 16#00# =>              -- ADDR (0x0)
               v.enableTx := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#01# =>              -- ADDR (0x4)
               v.sysrefDlyTx := axilWriteMaster.wdata(SYSRF_DLY_WIDTH_C-1 downto 0);
            when 16#02# =>              -- ADDR (0x8)
               v.txPolarity := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#03# =>              -- ADDR (0xC)
               v.loopback := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#04# =>              -- ADDR (0x10)
               v.commonCtrl := axilWriteMaster.wdata(6 downto 0);
            when 16#05# =>              -- ADDR (0x14)
               v.periodStep := axilWriteMaster.wdata;
            when 16#06# =>              -- ADDR (0x18)
               v.negAmplitude := axilWriteMaster.wdata(F_G*8-1 downto 0);
            when 16#07# =>              -- ADDR (0x1C)
               v.posAmplitude := axilWriteMaster.wdata(F_G*8-1 downto 0);
            when 16#08# =>              -- ADDR (0x20)
               v.invertData  := axilWriteMaster.wdata(L_G-1 downto 0);            
            when 16#20# to 16#2F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(5 downto 2) = I) then
                     v.signalSelectArr(I) := axilWriteMaster.wdata(7 downto 0);
                  end if;
               end loop;
            when 16#80# to 16#9F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(6 downto 2) = I) then
                     v.txDiffCtrl(I)   := axilWriteMaster.wdata(7 downto 0);
                     v.txPostCursor(I) := axilWriteMaster.wdata(15 downto 8);
                     v.txPreCursor(I)  := axilWriteMaster.wdata(23 downto 16);               
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
            when 16#00# =>              -- ADDR (0x0)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.enableTx;
            when 16#01# =>              -- ADDR (0x4)
               v.axilReadSlave.rdata(SYSRF_DLY_WIDTH_C-1 downto 0) := r.sysrefDlyTx;
            when 16#02# =>              -- ADDR (0x8)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.txPolarity;
            when 16#03# =>              -- ADDR (0xC)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.loopback;
            when 16#04# =>              -- ADDR (0x10)
               v.axilReadSlave.rdata(6 downto 0) := r.commonCtrl;
            when 16#05# =>              -- ADDR (0x14)
               v.axilReadSlave.rdata := r.periodStep;
            when 16#06# =>              -- ADDR (0x18)
               v.axilReadSlave.rdata(F_G*8-1 downto 0) := r.negAmplitude;
            when 16#07# =>              -- ADDR (0x1C)
               v.axilReadSlave.rdata(F_G*8-1 downto 0) := r.posAmplitude;
            when 16#08# =>              -- ADDR (0x20)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.invertData;
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
               
            when 16#40# to 16#4F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     for J in 31 downto 0 loop
                        v.axilReadSlave.rdata(J) := s_statusCnt(I,J);
                     end loop;
                  end if;
               end loop;
            when 16#80# to 16#9F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(6 downto 2) = I) then
                     v.axilReadSlave.rdata(7 downto 0)   := r.txDiffCtrl(I);
                     v.axilReadSlave.rdata(15 downto 8)  := r.txPostCursor(I);
                     v.axilReadSlave.rdata(23 downto 16) := r.txPreCursor(I);              
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
      txDiffCtrl     <= r.txDiffCtrl;
      txPostCursor   <= r.txPostCursor;
      txPreCursor    <= r.txPreCursor;      
      txPolarity     <= r.txPolarity;      
      loopback       <= r.loopback;      
      
   end process comb;

   seq : process (axiClk_i) is
   begin
      if rising_edge(axiClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Input assignment and synchronization
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


   -- Output assignment and synchronization
   SyncFifo_OUT0 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         PIPE_STAGES_G => 1,
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
         PIPE_STAGES_G => 1,
         DATA_WIDTH_G => L_G
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.enableTx,
         rd_clk => devClk_i,
         dout   => enableTx_o
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
         
   Sync_OUT10 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(6),
         dataOut => scrEnable_o
         );

   SyncFifo_OUT10 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         PIPE_STAGES_G => 1,
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
         PIPE_STAGES_G => 1,
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
         PIPE_STAGES_G => 1,
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
         PIPE_STAGES_G => 1,
         DATA_WIDTH_G => F_G*8
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.negAmplitude,
         rd_clk => devClk_i,
         dout   => negAmplitude_o
         );
   SyncFifo_OUT14 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         PIPE_STAGES_G => 1,
         DATA_WIDTH_G => L_G
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.invertData,
         rd_clk => devClk_i,
         dout   => invertData_o
         );  

   GEN_1 : for I in L_G-1 downto 0 generate
      SyncFifo_OUT0 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            PIPE_STAGES_G => 1,
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
            PIPE_STAGES_G => 1,
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
