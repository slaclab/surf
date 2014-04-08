-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Pkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-08
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package Vc64Pkg is

   ------------------------------------------------------------------------
   -- 64-bit Generic Streaming Data Interface Types/Constants                            
   ------------------------------------------------------------------------
   type Vc64DataType is record
      valid : sl;                       -- Data Valid
      size  : sl;  -- '0' = 32-bit word valid (data[31:0]), '1' = 64-bit word valid (data[63:0])
      vc    : slv(3 downto 0);          -- VC channel pointer (Optional: depending on interface)
      sof   : sl;                       -- Start of Frame Flag
      eof   : sl;                       -- end of Frame Flag
      eofe  : sl;                       -- end of Frame with error(s) Flag
      data  : slv(63 downto 0);         -- streaming data
   end record;
   type Vc64DataArray is array (natural range <>) of Vc64DataType;
   type Vc64DataVectorArray is array (integer range<>, integer range<>)of Vc64DataType;
   constant VC64_DATA_INIT_C : Vc64DataType := (
      '0',
      '1',                              -- Default to 64-bits valid width
      (others => '0'),
      '0',
      '0',
      '0',
      (others => '0')); 

   type Vc64CtrlType is record
      overflow   : sl;  -- FIFO's overflow error status bit (only used in FIFO writing interfaces)
      almostFull : sl;  -- FIFO's progFull status bit (only used in FIFO writing interfaces)
      ready      : sl;  -- Ready to read the FIFO (only used in FIFO reading interfaces)
   end record;
   type Vc64CtrlArray is array (natural range <>) of Vc64CtrlType;
   type Vc64CtrlVectorArray is array (integer range<>, integer range<>)of Vc64CtrlType;
   constant VC64_CTRL_INIT_C : Vc64CtrlType := (
      '0',
      '1',
      '0');

   -- VC64_CTRL_FORCE_C: 
   --    This constant is used to force an enable write/read status flags
   --    without overflow error. For example, you can use this constant 
   --    to terminate a vcTxCtrl port to prevent back pressure of the 
   --    downstream logic.  This constant SHOULD NOT be used to initialize 
   --    registers.
   constant VC64_CTRL_FORCE_C : Vc64CtrlType := (
      '0',
      '0',
      '1');      

   -- 64-bit Generic Streaming Data Functions       
   function toSlv (vec      : Vc64DataType) return slv;
   function toVc64Data (vec : slv(72 downto 0)) return Vc64DataType;
   
end Vc64Pkg;

package body Vc64Pkg is

   ------------------------------------------------------------------------
   -- 64-bit Generic Streaming Data Functions                          
   ------------------------------------------------------------------------   
   function toSlv (vec : Vc64DataType) return slv is
      variable retVar : slv(72 downto 0);
   begin
      retVar(72)           := vec.valid;
      retVar(71)           := vec.size;
      retVar(70 downto 67) := vec.vc;
      retVar(66)           := vec.sof;
      retVar(65)           := vec.eof;
      retVar(64)           := vec.eofe;
      retVar(63 downto 0)  := vec.data;
      return retVar;
   end function;

   function toVc64Data (vec : slv(72 downto 0)) return Vc64DataType is
      variable retVar : Vc64DataType;
   begin
      retVar.valid := vec(72);
      retVar.size  := vec(71);
      retVar.vc    := vec(70 downto 67);
      retVar.sof   := vec(66);
      retVar.eof   := vec(65);
      retVar.eofe  := vec(64);
      retVar.data  := vec(63 downto 0);
      return retVar;
   end function;
   
end package body Vc64Pkg;
