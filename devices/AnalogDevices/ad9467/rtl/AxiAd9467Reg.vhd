-------------------------------------------------------------------------------
-- File       : AxiAd9467Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-24
-------------------------------------------------------------------------------
-- Description: AD9467 AXI-Lite Register Access Module
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
use work.AxiAd9467Pkg.all;

entity AxiAd9467Reg is
   generic (
      TPD_G              : time                  := 1 ns;
      DEMUX_INIT_G       : sl                    := '0';
      DELAY_INIT_G       : Slv5Array(0 to 7)     := (others => "00000");
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);  
   port (
      -- AXI-Lite Register Interface (axiClk domain)
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (axiClk domain)
      status         : in  AxiAd9467StatusType;
      config         : out AxiAd9467ConfigType;
      -- Global Signals
      adcClk         : in  sl;
      adcRst         : in  sl;
      refClk200MHz   : in  sl);      
end AxiAd9467Reg;

architecture rtl of AxiAd9467Reg is

   function CompressAddressSpace (vec : slv(7 downto 0)) return slv is
      variable retVar : slv(11 downto 0) := x"0FF";
   begin
      case (vec) is
         -- chip_port_config register
         when x"00" =>
            retVar := x"000";
         -- chip_id  register
         when x"01" =>
            retVar := x"001";
         -- chip_grade register
         when x"02" =>
            retVar := x"002";
         -- device_update register
         when x"03" =>
            retVar := x"0FF";
         -- modes register
         when x"04" =>
            retVar := x"008";
         -- test_io register
         when x"05" =>
            retVar := x"00D";
         -- adc_input register
         when x"06" =>
            retVar := x"00F";
         -- offset register
         when x"07" =>
            retVar := x"010";
         -- output_mode register
         when x"08" =>
            retVar := x"014";
         -- output_adjust register
         when x"09" =>
            retVar := x"015";
         -- output_phase register
         when x"0A" =>
            retVar := x"016";
         -- vref register
         when x"0B" =>
            retVar := x"018";
         -- analog_input register
         when x"0C" =>
            retVar := x"02C";
         -- Buffer Current Select 1 register
         when x"0D" =>
            retVar := x"036";
         -- Buffer Current Select 2 register
         when x"0E" =>
            retVar := x"107";
         -- Unmapped
         when others =>
            retVar := x"0FF";
      end case;
      return retVar;
   end function;
   
   type StateType is (
      IDLE_S,
      REQ_S,
      ACK_S);    

   type RegType is record
      config        : AxiAd9467ConfigType;
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_AD9467_CONFIG_INIT_C,
      IDLE_S,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal syncIn : AxiAd9467StatusType := AXI_AD9467_STATUS_INIT_C;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, syncIn) is
      variable i            : integer;
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.config.delay.load := '0';
      v.config.delay.rst  := '0';

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         if (axiWriteMaster.awaddr(9 downto 2) < 15) then
            v.config.spi.req  := '1';
            v.config.spi.RnW  := '0';
            v.config.spi.din  := axiWriteMaster.wdata(7 downto 0);
            v.config.spi.addr := CompressAddressSpace(axiWriteMaster.awaddr(9 downto 2));
            v.state           := REQ_S;
         else
            -- Decode address and perform write
            case (axiWriteMaster.awaddr(9 downto 2)) is
               when x"10" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(0) := axiWriteMaster.wdata(4 downto 0);
               when x"11" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(1) := axiWriteMaster.wdata(4 downto 0);
               when x"12" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(2) := axiWriteMaster.wdata(4 downto 0);
               when x"13" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(3) := axiWriteMaster.wdata(4 downto 0);
               when x"14" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(4) := axiWriteMaster.wdata(4 downto 0);
               when x"15" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(5) := axiWriteMaster.wdata(4 downto 0);
               when x"16" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(6) := axiWriteMaster.wdata(4 downto 0);
               when x"17" =>
                  v.config.delay.load    := '1';
                  v.config.delay.rst     := '1';
                  v.config.delay.data(7) := axiWriteMaster.wdata(4 downto 0);
               when x"1F" =>
                  v.config.delay.dmux := axiWriteMaster.wdata(0);
               when others =>
                  axiWriteResp := AXI_ERROR_RESP_G;
            end case;
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
         end if;
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Reset the register
         v.axiReadSlave.rdata := (others => '0');
         if (axiReadMaster.araddr(9 downto 2) < 15) then
            v.config.spi.req  := '1';
            v.config.spi.RnW  := '1';
            v.config.spi.din  := (others => '0');
            v.config.spi.addr := CompressAddressSpace(axiReadMaster.araddr(9 downto 2));
            v.state           := REQ_S;
         else
            -- Decode address and assign read data
            case (axiReadMaster.araddr(9 downto 2)) is
               when x"10" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(0);
               when x"11" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(1);
               when x"12" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(2);
               when x"13" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(3);
               when x"14" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(4);
               when x"15" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(5);
               when x"16" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(6);
               when x"17" =>
                  v.axiReadSlave.rdata(4 downto 0) := syncIn.delay.data(7);
               when x"1D" =>
                  v.axiReadSlave.rdata(0) := syncIn.pllLocked;
               when x"1E" =>
                  v.axiReadSlave.rdata(0) := syncIn.delay.rdy;
               when x"1F" =>
                  v.axiReadSlave.rdata(0) := r.config.delay.dmux;
               when x"20" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(0);
               when x"21" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(1);
               when x"22" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(2);
               when x"23" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(3);
               when x"24" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(4);
               when x"25" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(5);
               when x"26" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(6);
               when x"27" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(7);
               when x"28" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(8);
               when x"29" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(9);
               when x"2A" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(10);
               when x"2B" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(11);
               when x"2C" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(12);
               when x"2D" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(13);
               when x"2E" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(14);
               when x"2F" =>
                  v.axiReadSlave.rdata(15 downto 0) := syncIn.adcDataMon(15);
               when others =>
                  axiReadResp := AXI_ERROR_RESP_G;
            end case;
            -- Send Axi Response
            axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
         end if;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            null;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Assert the flag
            v.config.spi.req := '1';
            -- Next State
            v.state          := ACK_S;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- De-assert the flag
            v.config.spi.req := '0';
            -- Check for ack strobe
            if syncIn.spi.ack = '1' then
               -- Check if we need to perform a read or write response
               if v.config.spi.RnW = '0' then
                  axiSlaveWriteResponse(v.axiWriteSlave);
               else
                  v.axiReadSlave.rdata(7 downto 0) := syncIn.spi.dout;
                  axiSlaveReadResponse(v.axiReadSlave);
               end if;
               -- Next State
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axiRst = '1' then
         v                   := REG_INIT_C;
         v.config.delay.load := '1';
         v.config.delay.rst  := '1';
         v.config.delay.data := DELAY_INIT_G;
         v.config.delay.dmux := DEMUX_INIT_G;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------
   config.spi <= r.config.spi;

   SyncIn_delay_dmux : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => refClk200MHz,
         dataIn  => r.config.delay.dmux,
         dataOut => config.delay.dmux);    

   SyncOut_delayIn_load : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 32)   
      port map (
         clk      => refClk200MHz,
         asyncRst => r.config.delay.load,
         syncRst  => config.delay.load); 

   SyncOut_delayIn_rst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 16)   
      port map (
         clk      => refClk200MHz,
         asyncRst => r.config.delay.rst,
         syncRst  => config.delay.rst);     

   GEN_DAT_CONFIG :
   for i in 0 to 7 generate
      SyncOut_delayIn_data : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 5)
         port map (
            wr_clk => axiClk,
            din    => r.config.delay.data(i),
            rd_clk => refClk200MHz,
            dout   => config.delay.data(i));
   end generate GEN_DAT_CONFIG;

   -------------------------------
   -- Synchronization: Inputs
   -------------------------------
   syncIn.spi <= status.spi;

   SyncIn_pllLocked : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axiClk,
         dataIn  => status.pllLocked,
         dataOut => syncIn.pllLocked);   

   GEN_ADC_MON :
   for i in 0 to 15 generate
      SyncIn_adcDataMon : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 16)
         port map (
            wr_clk => adcClk,
            din    => status.adcDataMon(i),
            rd_clk => axiClk,
            dout   => syncIn.adcDataMon(i));       
   end generate GEN_ADC_MON;

   SyncIn_delayOut_rdy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axiClk,
         dataIn  => status.delay.rdy,
         dataOut => syncIn.delay.rdy);   

   GEN_DAT_STATUS :
   for i in 0 to 7 generate
      SyncIn_delayOut_data : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 5)
         port map (
            wr_clk => refClk200MHz,
            din    => status.delay.data(i),
            rd_clk => axiClk,
            dout   => syncIn.delay.data(i));       
   end generate GEN_DAT_STATUS;

end rtl;
