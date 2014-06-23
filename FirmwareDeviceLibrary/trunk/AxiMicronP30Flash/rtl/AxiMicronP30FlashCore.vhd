-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMicronP30FlashCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-23
-- Last update: 2014-06-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to FLASH Memory
--
--    Note: Set the addrBits on the crossbar for this module to 12 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;
use work.AxiI2cQsfpPkg.all;

entity AxiMicronP30FlashCore is
   generic (
      TPD_G              : time                  := 1 ns;
      AXI_CLK_FREQ_G     : real                  := 200.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- FLASH Interface 
      flashInOut     : inout AxiMicronP30FlashInOutType;
      flashOut       : out   AxiMicronP30FlashOutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiMicronP30FlashCore;

architecture rtl of AxiMicronP30FlashCore is
   
   signal tristate : sl;
   signal din,
      dout : slv(15 downto 0);
   
begin

   -- Place holder for future module
   AxiLiteEmpty_Inst : entity work.AxiLiteEmpty
      port map (
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         axiClk         => axiClk,
         axiClkRst      => axiRst); 

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : IOBUF
         port map (
            O  => dout(i),              -- Buffer output
            IO => flashInOut.data(i),   -- Buffer inout port (connect directly to top-level port)
            I  => din(i),               -- Buffer input
            T  => tristate);            -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;
   
   tristate <= '1';
   
   din           <= (others=>'0');
   flashOut.Addr <= (others=>'0');
   flashOut.Adv  <= '0';
   flashOut.Ce   <= '1';
   flashOut.Oe   <= '1';
   flashOut.We   <= '1';   

       
end rtl;
