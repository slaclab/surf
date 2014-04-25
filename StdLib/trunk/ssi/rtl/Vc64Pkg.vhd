-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Pkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-23
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

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
   type Vc64DataVectorArray is array (natural range<>, natural range<>)of Vc64DataType;
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
   type Vc64CtrlVectorArray is array (natural range<>, natural range<>)of Vc64CtrlType;
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

   type Vc64CmdMasterOutType is record
      valid  : sl;                      -- Command Opcode is valid (formerly cmdEn)
      opCode : slv(7 downto 0);         -- Command OpCode
      ctxOut : slv(23 downto 0);        -- Command Context
   end record;
   type Vc64CmdMasterOutArray is array (natural range <>) of Vc64CmdMasterOutType;
   type Vc64CmdMasterOutVectorArray is array (natural range<>, natural range<>)of Vc64CmdMasterOutType;
   constant VC64_CMD_MASTER_OUT_INIT_C : Vc64CmdMasterOutType := (
      '0',
      (others => '0'),
      (others => '0'));

   -- 64-bit Generic Streaming Data Functions       
   function toSlv (vec       : Vc64DataType) return slv;
   function toVc64Data (vec  : slv(72 downto 0)) return Vc64DataType;
   function vc64DeMux (encIn : Vc64DataType; count : integer range 1 to 16) return Vc64DataArray;
   
end Vc64Pkg;

package body Vc64Pkg is

   ------------------------------------------------------------------------
   -- 64-bit Generic Streaming Data Functions                          
   ------------------------------------------------------------------------   
   function toSlv (vec : Vc64DataType) return slv is
      variable retVar : slv(72 downto 0);
   begin
      retVar(72)          := vec.valid;
      retVar(71 downto 8) := vec.data;
      retVar(7 downto 4)  := vec.vc;
      retVar(3)           := vec.size;
      retVar(2)           := vec.sof;
      retVar(1)           := vec.eof;
      retVar(0)           := vec.eofe;
      return retVar;
   end function;

   function toVc64Data (vec : slv(72 downto 0)) return Vc64DataType is
      variable retVar : Vc64DataType;
   begin
      retVar.valid := vec(72);
      retVar.data  := vec(71 downto 8);
      retVar.vc    := vec(7 downto 4);
      retVar.size  := vec(3);
      retVar.sof   := vec(2);
      retVar.eof   := vec(1);
      retVar.eofe  := vec(0);
      return retVar;
   end function;

   function vc64DeMux (encIn : Vc64DataType; count : integer range 1 to 16) return Vc64DataArray is
      variable retData : Vc64DataArray(count-1 downto 0);
   begin

      -- Init
      for i in 0 to count-1 loop
         retData(i)       := encIn;
         retData(i).valid := '0';
         retData(i).vc    := conv_std_logic_vector(i, 4);
      end loop;

      retData(conv_integer(encIn.vc)).valid := encIn.valid;

      return retData;
   end function;

end package body Vc64Pkg;

