-------------------------------------------------------------------------------
-- Title      : Axi-lite interface for Signal generator control  
-------------------------------------------------------------------------------
-- File       : AxiLiteGenRegItf.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  Register decoding for DAQ
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;

entity AxiLiteGenRegItf is
   generic (
   -- General Configurations
      TPD_G                      : time                       := 1 ns;

      AXI_ERROR_RESP_G           : slv(1 downto 0)            := AXI_RESP_SLVERR_C;  
      
      ADDR_WIDTH_G : integer range 1 to (2**24) := 9;
      
      -- Number of Axi lanes (0 to 1)
      L_G : positive := 2 
   );    
   port (
    -- AXI Clk
      axiClk_i : in sl;
      axiRst_i : in sl;

    -- Axi-Lite Register Interface (locClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
 
    -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;

   -- JESD registers
      -- Busy      
      enable_o         : out slv(L_G-1 downto 0);
      
      -- Control
      periodSize_o     : out  slv(ADDR_WIDTH_G-1 downto 0);
      dspDiv_o         : out  slv(15 downto 0)
   );   
end AxiLiteGenRegItf;

architecture rtl of AxiLiteGenRegItf is

   type RegType is record
      -- JESD Control (RW)
      enable     : slv(L_G-1 downto 0);
      periodSize : slv(ADDR_WIDTH_G-1 downto 0);
      dspDiv     : slv(15 downto 0);
      
      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   
   constant REG_INIT_C : RegType := (
      enable       => (others=> '0'),
      periodSize   => intToSlv(16, ADDR_WIDTH_G),
      dspDiv       => x"0001",
 
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- Integer address
   signal s_RdAddr: natural := 0;
   signal s_WrAddr: natural := 0; 
   
begin
   
   -- Convert address to integer (lower two bits of address are always '0')
   s_RdAddr <= slvToInt( axilReadMaster.araddr(9 downto 2));
   s_WrAddr <= slvToInt( axilWriteMaster.awaddr(9 downto 2)); 
   
   comb : process (axilReadMaster, axilWriteMaster, r, axiRst_i, s_RdAddr, s_WrAddr) is
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
            when 16#00# => -- ADDR (0)
               v.enable      := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#01# => -- ADDR (8)
               v.dspDiv  := axilWriteMaster.wdata(15 downto 0);                
            when 16#02# => -- ADDR (12)
               v.periodSize  := axilWriteMaster.wdata(ADDR_WIDTH_G-1 downto 0);
            when others =>
               axilWriteResp     := AXI_ERROR_RESP_G;
         end case;
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      if (axilStatus.readEnable = '1') then
         axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         v.axilReadSlave.rdata := (others => '0');
         case (s_RdAddr) is
            when 16#00# =>  -- ADDR (0)
               v.axilReadSlave.rdata(L_G-1 downto 0)             := r.enable;
            when 16#01# =>  -- ADDR (8)
               v.axilReadSlave.rdata(15 downto 0)                := r.dspDiv;               
            when 16#02# =>  -- ADDR (12)
               v.axilReadSlave.rdata(ADDR_WIDTH_G-1 downto 0)                := r.periodSize;
            when others =>
               axilReadResp    := AXI_ERROR_RESP_G;
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
   
   -- Output assignment and synchronisation
   SyncFifo_OUT1 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => L_G
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.enable,
      rd_clk => devClk_i,
      dout   => enable_o
   );
   
   SyncFifo_OUT2 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => ADDR_WIDTH_G
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.periodSize,
      rd_clk => devClk_i,
      dout   => periodSize_o
   );
   
   SyncFifo_OUT3 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 16
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.dspDiv,
      rd_clk => devClk_i,
      dout   => dspDiv_o
   );
---------------------------------------------------------------------
end rtl;
