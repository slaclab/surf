-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package SaltPkg is

   constant SSI_SALT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1);

   -- 8B10B Characters
   constant K_COM_C  : slv(7 downto 0) := "10111100";  -- K28.5, 0xBC = Communication comma
   constant K_SOC_C  : slv(7 downto 0) := "11111011";  -- K27.7, 0xFB = start of continuation (no SOF bit)
   constant K_SOF_C  : slv(7 downto 0) := "11110111";  -- K23.7, 0xF7 = start of frame
   constant K_EOF_C  : slv(7 downto 0) := "11111101";  -- K29.7, 0xFD = end of frame
   constant K_EOFE_C : slv(7 downto 0) := "11111110";  -- K30.7, 0xFE = end of frame w/ errors
   constant K_EOC_C  : slv(7 downto 0) := "01011100";  -- K28.2, 0x5C = end of continuation (no EOF bit)  
   
end package;
