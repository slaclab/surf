-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL Package for MDIO Protocol
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;

package MdioPkg is

   subtype PhyAddrType is slv( 4 downto 0);
   subtype RegAddrType is slv( 4 downto 0);

   -- A command to be submitted to the MdioCore.
   -- Use the 'mdioReadCommand()/mdioWriteCommand() convenience
   -- functions to initialize/create a MdioCommandType object.
   type MdioCommandType is record
      rdNotWr      : sl;                 -- 'direction': read vs. write
      phyAddr      : PhyAddrType;        -- phy to be addressed by this command
      regAddr      : RegAddrType;        -- register address
      dataOut      : slv( 15 downto 0 ); -- for a read command dataOut MUST be set to x"FFFF"
   end record MdioCommandType;

   constant MDIO_CMD_INIT_C : MdioCommandType :=
      (
         rdNotWr => '1',
         phyAddr => (others => '0'),
         regAddr => (others => '0'),
         dataOut => (others => '1')
      );

   -- create a READ command
   function mdioReadCommand(
      phyAddr : in natural;
      regAddr : in natural
   ) return MdioCommandType;

   -- create a WRITE command
   function mdioWriteCommand(
      phyAddr : in natural;
      regAddr : in natural;
      dataOut : in slv(15 downto 0)
   ) return MdioCommandType;

   -- An mdio instruction. This record is intended to
   -- be used as an element in a MdioProgramArray which
   -- is a list of MdioCommandTypes amended with a 'last'
   -- bit. The 'last' bit marks the last command of a
   -- sequence.
   type MdioInstType is record
      lst : sl;
      cmd : MdioCommandType;
   end record MdioInstType;

   -- create/initialize a READ instruction. 'theLast' must
   -- be set to 'true' if this instruction is the last one
   -- of a sequence.
   function mdioReadInst(
      phyAddr : in natural;
      regAddr : in natural;
      theLast : in boolean := false
   ) return MdioInstType;

   -- create/initialize a WRITE instruction. 'theLast' must
   -- be set to 'true' if this instruction is the last one
   -- of a sequence.
   function mdioWriteInst(
      phyAddr : in natural;
      regAddr : in natural;
      dataOut : in slv(15 downto 0);
      theLast : in boolean := false
   ) return MdioInstType;

   -- A sequence of instructions. The 'MdioSeqCore' module
   -- processes a sequence of commands up to and including one
   -- that has the 'theLast' flag set.
   -- An array may typically contain more than one sequence
   -- of instructions. The user submits the index of the
   -- first instruction to the MdioSeqCore which then executes
   -- commands up to the next one that has the 'last' flag set.
   --
   -- Example:
   --    constant seq1 : MdioProgramArray := (
   --       mdioWriteInst( PHY, REG0, DATA0 );
   --       mdioWriteInst( PHY, REG1, DATA1 );
   --       mdioWriteInst( PHY, REG2, DATA2, true );
   --    );
   --    constant seq2 : MdioProgramArray := (
   --       mdioWriteInst( PHY, REGx, DATAx );
   --       mdioWriteInst( PHY, REGy, DATAy, true );
   --    );
   --
   --    constant PROGRAMS_C : MdioProgramArray := ( seq1 & seq2 );
   --    constant SEQ_1_START_C : natural := 0;
   --    constant SEQ_2_START_C : natural := SEQ_1_START_C + seq1'length;
   --
   -- PROGRAMS_C is then used as the MDIO_PROG_G generic (MdioSeqCore) and
   -- the indices 'SEQ_1_START_C', 'SEQ_2_START_C' etc. are used to
   -- initiate processing of the respective sequences.

   type MdioProgramArray is array (natural range <>) of MdioInstType;

   -- calculate the number of read transactions in a sequence
   function mdioProgNumReadTransactions(
      prog : in MdioProgramArray
   ) return natural;

end package MdioPkg;

package body MdioPkg is

   function mdioReadCommand(
      phyAddr : in natural;
      regAddr : in natural
   ) return MdioCommandType is
   variable rval : MdioCommandType;
   begin
      rval.rdNotWr := '1';
      rval.regAddr := toSlv( regAddr, rval.regAddr'length );
      rval.phyAddr := toSlv( phyAddr, rval.phyAddr'length );
      rval.dataOut := (others => '1');
      return rval;
   end function mdioReadCommand;

   function mdioWriteCommand(
      phyAddr : in natural;
      regAddr : in natural;
      dataOut : in slv(15 downto 0)
   ) return MdioCommandType is
   variable rval : MdioCommandType;
   begin
      rval.rdNotWr := '0';
      rval.regAddr := toSlv( regAddr, rval.regAddr'length );
      rval.phyAddr := toSlv( phyAddr, rval.phyAddr'length );
      rval.dataOut := dataOut;
      return rval;
   end function mdioWriteCommand;

   function mdioReadInst(
      phyAddr : in natural;
      regAddr : in natural;
      theLast : in boolean := false
   ) return MdioInstType is
   variable rval : MdioInstType;
   begin
      rval.cmd := mdioReadCommand(phyAddr, regAddr);
      rval.lst := ite( theLast, '1', '0' );
      return rval;
   end function mdioReadInst;

   function mdioWriteInst(
      phyAddr : in natural;
      regAddr : in natural;
      dataOut : in slv(15 downto 0);
      theLast : in boolean := false
   ) return MdioInstType is
   variable rval : MdioInstType;
   begin
      rval.cmd := mdioWriteCommand(phyAddr, regAddr, dataOut);
      rval.lst := ite( theLast, '1', '0' );
      return rval;
   end function mdioWriteInst;

   function mdioProgNumReadTransactions(
      prog : in MdioProgramArray
   ) return natural is
      variable n : natural := 0;
      variable i : natural;
   begin
      for i in prog'range loop
         if prog(i).cmd.rdNotWr /= '0' then
            n := n + 1;
         end if;
      end loop;
      return n;
   end function mdioProgNumReadTransactions;


end package body MdioPkg;
