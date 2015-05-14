-------------------------------------------------------------------------------
-- Title      : Axi-lite interface for register access  
-------------------------------------------------------------------------------
-- File       : AxiLiteRegItf.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  Register decoding for JESD core
--               Registers
--               0x000 (RW)- Enable RX lanes (1 to L_G)
--               0x004 (RW)- SYSREF delay (5 bit)
--               0x100 (R) - Lane 1 status 
--               0x101 (R) - Lane 2 status               
--               ...
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

entity AxiLiteRxRegItf is
   generic (
   -- General Configurations
      TPD_G                      : time                       := 1 ns;
      AXI_ERROR_RESP_G           : slv(1 downto 0)            := AXI_RESP_SLVERR_C;  
   -- JESD 
      -- Number of RX lanes (1 to 8)
      L_G : positive := 2
   );    
   port (
    -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;

    -- Axi-Lite Register Interface (locClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      
   -- JESD registers
      -- Status
      statusRxArr_i   : in   rxStatuRegisterArray(0 to L_G-1);
      
      -- Control
      sysrefDlyRx_o     : out  slv(SYSRF_DLY_WIDTH_C-1 downto 0); 
      enableRx_o        : out  slv(L_G-1 downto 0);
      replEnable_o      : out  sl;
      dlyTxArr_o        : out  Slv4Array(L_G-1 downto 0); -- 1 to 16 clock cycles
      alignTxArr_o      : out  alignTxArray(L_G-1 downto 0); -- 0001, 0010, 0100, 1000
      axisTrigger_o     : out  slv(L_G-1 downto 0);
      axisPacketSize_o  : out  slv(23 downto 0) 
   );   
end AxiLiteRxRegItf;

architecture rtl of AxiLiteRxRegItf is

   type RegType is record
      -- JESD Control (RW)
      enableRx       : slv(L_G-1 downto 0);
      replEnable     : sl;
      sysrefDlyRx    : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      testTXItf      : Slv16Array(0 to L_G-1);
      axisTrigger    : slv(L_G-1 downto 0);
      axisPacketSize : slv(23 downto 0);
      
      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   
   constant REG_INIT_C : RegType := (
      enableRx       => (others => '0'),
      replEnable     => '1',  
      sysrefDlyRx    => (others => '0'),
      testTXItf      => (others => (others => '0')),
      axisTrigger    => (others => '0'),   
      axisPacketSize =>  AXI_PACKET_SIZE_DEFAULT_C,
 
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- Integer address
   signal s_RdAddr: natural := 0;
   signal s_WrAddr: natural := 0; 
   
begin
   
   -- Convert address to integer (lower two bits of address are always '0')
   s_RdAddr <= slvToInt( axilReadMaster.araddr(9 downto 2) );
   s_WrAddr <= slvToInt( axilWriteMaster.awaddr(9 downto 2) ); 
   
   comb : process (axilReadMaster, axilWriteMaster, r, devRst_i, statusRxArr_i, s_RdAddr, s_WrAddr) is
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
               v.enableRx        := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#01# => -- ADDR (4)
               v.sysrefDlyRx     := axilWriteMaster.wdata(SYSRF_DLY_WIDTH_C-1 downto 0);
            when 16#02# => -- ADDR (8)
               v.axisTrigger     := axilWriteMaster.wdata(L_G-1 downto 0);   
            when 16#03# => -- ADDR (12)
               v.axisPacketSize  := axilWriteMaster.wdata(23 downto 0);
            when 16#04# => -- ADDR (16)
               v.replEnable      := axilWriteMaster.wdata(0);               
            when 16#20# to 16#2F# =>               
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.testTXItf(I)  := axilWriteMaster.wdata(15 downto 0);
                  end if;
               end loop; 
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
               v.axilReadSlave.rdata(L_G-1 downto 0)                 := r.enableRx;
            when 16#01# =>  -- ADDR (4)
               v.axilReadSlave.rdata(SYSRF_DLY_WIDTH_C-1 downto 0)   := r.sysrefDlyRx;
            when 16#02# =>  -- ADDR (8)
               v.axilReadSlave.rdata(L_G-1 downto 0)                 := r.axisTrigger;
            when 16#03# =>  -- ADDR (12)
               v.axilReadSlave.rdata(23 downto 0)                    := r.axisPacketSize;
            when 16#04# =>  -- ADDR (16)
               v.axilReadSlave.rdata(0)                              := r.replEnable;               
            when 16#10# to 16#1F# => 
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata(RX_STAT_WIDTH_C-1 downto 0)     := statusRxArr_i(I);
                  end if;
               end loop;
            when 16#20# to 16#2F# =>               
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata(15 downto 0)                    := r.testTXItf(I);
                  end if;
               end loop;            
            when others =>
               axilReadResp                                          := AXI_ERROR_RESP_G;
         end case;
         axiSlaveReadResponse(v.axilReadSlave);
      end if;

      -- Reset
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      
   end process comb;

   seq : process (devClk_i) is
   begin
      if rising_edge(devClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -- Output assignment
   sysrefDlyRx_o     <= r.sysrefDlyRx;
   enableRx_o        <= r.enableRx;
   replEnable_o      <= r.replEnable;
   axisTrigger_o     <= r.axisTrigger;
   axisPacketSize_o  <= r.axisPacketSize;
   
   TX_LANES_GEN : for I in L_G-1 downto 0 generate 
      dlyTxArr_o(I)    <=   r.testTXItf(I) (11 downto 8);
      alignTxArr_o(I)  <=   r.testTXItf(I) (GT_WORD_SIZE_C-1 downto 0);
   end generate TX_LANES_GEN;   
---------------------------------------------------------------------
end rtl;
