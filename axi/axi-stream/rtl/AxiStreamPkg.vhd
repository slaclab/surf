-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI Stream Package File
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


library surf;
use surf.StdRtlPkg.all;
-- use surf.TextUtilPkg.all;

package AxiStreamPkg is

   constant AXI_STREAM_MAX_TDATA_WIDTH_C : positive := 512;  -- Units of bits
   constant AXI_STREAM_MAX_TKEEP_WIDTH_C : positive := (AXI_STREAM_MAX_TDATA_WIDTH_C/8);  -- Units of bytes

   type AxiStreamMasterType is record
      tValid : sl;
      tData  : slv(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 0);
      tStrb  : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      tKeep  : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      tLast  : sl;
      tDest  : slv(7 downto 0);
      tId    : slv(7 downto 0);
      tUser  : slv(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 0);
   end record AxiStreamMasterType;

   constant AXI_STREAM_MASTER_INIT_C : AxiStreamMasterType := (
      tValid => '0',
      tData  => (others => '0'),
      tStrb  => (others => '1'),
      tKeep  => (others => '1'),
      tLast  => '0',
      tDest  => (others => '0'),
      tId    => (others => '0'),
      tUser  => (others => '0'));
   type AxiStreamMasterArray is array (natural range<>) of AxiStreamMasterType;
   type AxiStreamMasterVectorArray is array (natural range<>, natural range<>) of AxiStreamMasterType;
   subtype AxiStreamDualMasterType is AxiStreamMasterArray(1 downto 0);
   type AxiStreamDualMasterArray is array (natural range <>) of AxiStreamMasterArray(1 downto 0);
   subtype AxiStreamQuadMasterType is AxiStreamMasterArray(3 downto 0);
   type AxiStreamQuadMasterArray is array (natural range <>) of AxiStreamMasterArray(3 downto 0);
   subtype AxiStreamOctalMasterType is AxiStreamMasterArray(7 downto 0);
   type AxiStreamOctalMasterArray is array (natural range <>) of AxiStreamMasterArray(7 downto 0);

   type AxiStreamSlaveType is record
      tReady : sl;
   end record AxiStreamSlaveType;

   type AxiStreamSlaveArray is array (natural range<>) of AxiStreamSlaveType;
   type AxiStreamSlaveVectorArray is array (natural range<>, natural range<>) of AxiStreamSlaveType;
   subtype AxiStreamDualSlaveType is AxiStreamSlaveArray(1 downto 0);
   type AxiStreamDualSlaveArray is array (natural range <>) of AxiStreamSlaveArray(1 downto 0);
   subtype AxiStreamQuadSlaveType is AxiStreamSlaveArray(3 downto 0);
   type AxiStreamQuadSlaveArray is array (natural range <>) of AxiStreamSlaveArray(3 downto 0);
   subtype AxiStreamOctalSlaveType is AxiStreamSlaveArray(7 downto 0);
   type AxiStreamOctalSlaveArray is array (natural range <>) of AxiStreamSlaveArray(7 downto 0);

   constant AXI_STREAM_SLAVE_INIT_C : AxiStreamSlaveType := (
      tReady => '0');

   constant AXI_STREAM_SLAVE_FORCE_C : AxiStreamSlaveType := (
      tReady => '1');

   type TUserModeType is (TUSER_NORMAL_C, TUSER_FIRST_LAST_C, TUSER_LAST_C, TUSER_NONE_C);

   type TKeepModeType is (TKEEP_NORMAL_C, TKEEP_COMP_C, TKEEP_FIXED_C, TKEEP_COUNT_C);

   type AxiStreamConfigType is record
      -- TDEST_INTERLEAVE_C : boolean;
      TSTRB_EN_C         : boolean;
      TDATA_BYTES_C      : natural range 1 to AXI_STREAM_MAX_TKEEP_WIDTH_C;
      TDEST_BITS_C       : natural range 0 to 8;
      TID_BITS_C         : natural range 0 to 8;
      TKEEP_MODE_C       : TkeepModeType;
      TUSER_BITS_C       : natural range 0 to 8;
      TUSER_MODE_C       : TUserModeType;
   end record AxiStreamConfigType;

   constant AXI_STREAM_CONFIG_INIT_C : AxiStreamConfigType := (
      -- TDEST_INTERLEAVE_C => true,
      TSTRB_EN_C         => false,
      TDATA_BYTES_C      => 16,
      TDEST_BITS_C       => 4,
      TID_BITS_C         => 0,
      TKEEP_MODE_C       => TKEEP_NORMAL_C,
      TUSER_BITS_C       => 4,
      TUSER_MODE_C       => TUSER_NORMAL_C);

   type AxiStreamConfigArray is array (natural range<>) of AxiStreamConfigType;
   type AxiStreamConfigVectorArray is array (natural range<>, natural range<>) of AxiStreamConfigType;

   function axiStreamMasterInit (constant config : AxiStreamConfigType) return AxiStreamMasterType;

   function getSlvSize (c          : AxiStreamConfigType) return integer;
   function toSlv (din             : AxiStreamMasterType; c : AxiStreamConfigType) return slv;
   function toAxiStreamMaster (din : slv; valid : sl; c : AxiStreamConfigType) return AxiStreamMasterType;

   -------------------------------------------------------------------------------------------------
   -- Special control backpressure interface for use with stream fifos
   -------------------------------------------------------------------------------------------------
   type AxiStreamCtrlType is record
      pause    : sl;
      overflow : sl;
      idle     : sl;
   end record AxiStreamCtrlType;

   constant AXI_STREAM_CTRL_INIT_C : AxiStreamCtrlType := (
      pause    => '1',
      overflow => '0',
      idle     => '0');

   constant AXI_STREAM_CTRL_UNUSED_C : AxiStreamCtrlType := (
      pause    => '0',
      overflow => '0',
      idle     => '1');

   type AxiStreamCtrlArray is array (natural range<>) of AxiStreamCtrlType;
   type AxiStreamCtrlVectorArray is array (natural range<>, natural range<>) of AxiStreamCtrlType;
   subtype AxiStreamDualCtrlType is AxiStreamCtrlArray(1 downto 0);
   type AxiStreamDualCtrlArray is array (natural range <>) of AxiStreamCtrlArray(1 downto 0);
   subtype AxiStreamQuadCtrlType is AxiStreamCtrlArray(3 downto 0);
   type AxiStreamQuadCtrlArray is array (natural range <>) of AxiStreamCtrlArray(3 downto 0);
   subtype AxiStreamOctalCtrlType is AxiStreamCtrlArray(7 downto 0);
   type AxiStreamOctalCtrlArray is array (natural range <>) of AxiStreamCtrlArray(7 downto 0);

   -------------------------------------------------------------------------------------------------
   -- Helper function prototypes
   -------------------------------------------------------------------------------------------------
   function axiStreamPacked (
      constant CONFIG_C : AxiStreamConfigType;
      axisMaster        : AxiStreamMasterType)
      return boolean;

   function axiStreamGetUserPos (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bytePos    : integer := -1)       -- -1 = last
      return integer;

   function axiStreamGetUserField (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bytePos    : integer := -1)       -- -1 = last
      return slv;

   function axiStreamGetUserBit (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bitPos     : integer;
      bytePos    : integer := -1)       -- -1 = last
      return sl;

   procedure axiStreamSetUserField (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      fieldValue : in    slv;
      bytePos    : in    integer := -1);  -- -1 = last

   procedure axiStreamSetUserBit (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      bitPos     : in    integer;
      bitValue   : in    sl;
      bytePos    : in    integer := -1);  -- -1 = last

   function ite(i : boolean; t : AxiStreamConfigType; e : AxiStreamConfigType) return AxiStreamConfigType;
   function ite(i : boolean; t : AxiStreamMasterType; e : AxiStreamMasterType) return AxiStreamMasterType;
   function ite(i : boolean; t : AxiStreamSlaveType; e : AxiStreamSlaveType) return AxiStreamSlaveType;
   function ite(i : boolean; t : AxiStreamCtrlType; e : AxiStreamCtrlType) return AxiStreamCtrlType;
   function ite(i : boolean; t : TUserModeType; e : TUserModeType) return TUserModeType;
   function ite(i : boolean; t : TKeepModeType; e : TKeepModeType) return TKeepModeType;

   function genTKeep (bytes           : natural range 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C) return slv;
   function genTKeep (constant config : AxiStreamConfigType) return slv;

   function getTKeep (tKeep : slv; axisConfig : AxiStreamConfigType) return natural;

end package AxiStreamPkg;

package body AxiStreamPkg is

   function axiStreamMasterInit (constant config : AxiStreamConfigType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret       := AXI_STREAM_MASTER_INIT_C;
      ret.tKeep := genTKeep(config);
      ret.tStrb := genTKeep(config);
      return ret;
   end function axiStreamMasterInit;

   function axiStreamPacked (
      constant CONFIG_C : AxiStreamConfigType;
      axisMaster        : AxiStreamMasterType)
      return boolean is
   begin
      if (not allBits(axisMaster.tKeep(CONFIG_C.TDATA_BYTES_C-1 downto 0), '1')) then
         return false;
      end if;
      if (CONFIG_C.TSTRB_EN_C and
          not allBits(axisMaster.tStrb(CONFIG_C.TDATA_BYTES_C-1 downto 0), '1')) then
         return false;
      end if;
      return true;
   end function;

   function axiStreamGetUserPos (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bytePos    : integer := -1)
      return integer is

      variable ret : integer;
   begin

      if bytePos = -1 then
         ret := getTKeep(axisMaster.tKeep, axisConfig)-1;
         if (ret > axisConfig.TDATA_BYTES_C) then
            ret := axisConfig.TDATA_BYTES_C-1;
         end if;
         if ret < 0 then
            ret := 0;
         end if;
      else
         ret := bytePos;
      end if;

      return(ret);
   end function;

   function axiStreamGetUserField (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bytePos    : integer := -1)
      return slv is

      variable pos : integer;
      variable lsb : integer;
      variable ret : slv(maximum(axisConfig.TUSER_BITS_C-1, 0) downto 0);
   begin

      pos := axiStreamGetUserPos(axisConfig, axisMaster, bytePos);
      lsb := axisConfig.TUSER_BITS_C*pos;

      if axisConfig.TUSER_BITS_C > 0 then
         for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
            if lsb = i then
               ret := axisMaster.tUser(ret'HIGH+i downto ret'LOW+i);
            end if;
         end loop;
      else
         ret := (others => '0');
      end if;

      -- Handle TUSER_BITS_C=0 case
      if (axisConfig.TUSER_BITS_C = 0 or axisConfig.TUSER_MODE_C = TUSER_NONE_C) then
         ret := (others => '0');
      end if;

      return(ret);
   end function;

   function axiStreamGetUserBit (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType;
      bitPos     : integer;
      bytePos    : integer := -1)       -- -1 = last
      return sl is

      variable user : slv(maximum(axisConfig.TUSER_BITS_C-1, 0) downto 0);
   begin

      user := axiStreamGetuserField(axisConfig, axisMaster, bytePos);
      return(user(bitPos));

   end function;

   procedure axiStreamSetUserField (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      fieldValue : in    slv;
      bytePos    : in    integer := -1) is

      variable pos : integer;
      variable lsb : integer;
   begin

      pos := axiStreamGetUserPos(axisConfig, axisMaster, bytePos);
      lsb := axisConfig.TUSER_BITS_C*pos;

      if (axisConfig.TUSER_BITS_C > 0 and axisConfig.TUSER_MODE_C /= TUSER_NONE_C) then

         for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
            if lsb = i then
               axisMaster.tUser(fieldValue'HIGH+i downto fieldValue'LOW+i) := fieldValue;
            end if;
         end loop;

      else
         axisMaster.tUser := (others => '0');
      end if;

   end procedure;

   procedure axiStreamSetUserBit (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      bitPos     : in    integer;
      bitValue   : in    sl;
      bytePos    : in    integer := -1) is

      variable pos : integer;
   begin

      pos := axiStreamGetUserPos(axisConfig, axisMaster, bytePos);

      axisMaster.tUser((axisConfig.TUSER_BITS_C*pos) + bitPos) := bitValue;

   end procedure;

   function ite (i : boolean; t : AxiStreamConfigType; e : AxiStreamConfigType) return AxiStreamConfigType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiStreamMasterType; e : AxiStreamMasterType) return AxiStreamMasterType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiStreamSlaveType; e : AxiStreamSlaveType) return AxiStreamSlaveType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiStreamCtrlType; e : AxiStreamCtrlType) return AxiStreamCtrlType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : TUserModeType; e : TUserModeType) return TUserModeType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : TKeepModeType; e : TKeepModeType) return TKeepModeType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function genTKeep (bytes : natural range 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C) return slv is
      variable retVar : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
   begin
      retVar := (others => '0');
      for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
         if (bytes > i) then
            retVar(i) := '1';
         end if;
      end loop;
      return retVar;
   end function genTKeep;

   function genTKeep (constant config : AxiStreamConfigType) return slv is
   begin
      -- Assumes TKEEP_MODE_C /= TKEEP_COUNT_C
      return genTKeep(config.TDATA_BYTES_C);
   end function genTKeep;

   function getTKeep (tKeep : slv; axisConfig : AxiStreamConfigType) return natural is
      variable tKeepFull : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      variable retVar    : natural;
      variable i         : natural;
   begin
      -- Init
      retVar    := 0;
      tKeepFull := resize(tKeep, AXI_STREAM_MAX_TKEEP_WIDTH_C);
      -- Check if TKEEP_MODE_C = TKEEP_COUNT_C
      if (axisConfig.TKEEP_MODE_C = TKEEP_COUNT_C) then
         retVar := conv_integer(tKeep(bitSize(axisConfig.TDATA_BYTES_C)-1 downto 0));
      else
         for i in 0 to axisConfig.TDATA_BYTES_C-1 loop
            -- report "AxiStreamPkg::genTKeep( i:" & integer'image(i) & ")" severity warning;
            ----------------------------------------------------
            -- Confirmed in simulation the for loop ordering is:
            ----------------------------------------------------
            -- Warning: AxiStreamPkg::genTKeep( i:0)
            -- Warning: AxiStreamPkg::genTKeep( i:1)
            -- Warning: AxiStreamPkg::genTKeep( i:2)
            -- .....................................
            -- .....................................
            ----------------------------------------------------
            if (tKeepFull(i) = '1') then
               if (axisConfig.TKEEP_MODE_C = TKEEP_COMP_C) then
                  -- Assume LSBs are active when calculating active bytes in TKEEP_COMP_C mode
                  retVar := (i+1);
               else
                  -- TKEEP_NORMAL_C mode
                  retVar := retVar + 1;
               end if;
            end if;
         end loop;
      end if;
      return retVar;
   end function getTKeep;

   procedure axiStreamSimSendTxn (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      tData             : in  slv;
      tKeep             : in  slv                                          := "X";
      tLast             : in  sl                                           := '0';
      tDest             : in  slv(7 downto 0)                              := X"00";
      tId               : in  slv(7 downto 0)                              := X"00";
      tUser             : in  slv(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 0) := (others => '0')) is
   begin
      -- Wait for rising edge
      wait until clk = '1';

      -- Set the bus
      master        <= axiStreamMasterInit(CONFIG_C);
      master.tValid <= '1';
      master.tData  <= resize(tdata, AXI_STREAM_MAX_TDATA_WIDTH_C);
      if (tKeep /= "X") then
         master.tKeep <= resize(tkeep, AXI_STREAM_MAX_TKEEP_WIDTH_C);
      end if;
      master.tLast <= tlast;
      master.tDest <= tDest;
      master.tId   <= tid;
      master.tUser <= tUser;

      -- Wait for tReady
      while (slave.tReady = '0') loop
         wait until clk = '1';
      end loop;

   end procedure;

   procedure axiStreamSimReceiveTxn (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : in  AxiStreamMasterType;
      signal slave      : out AxiStreamSlaveType;
      tData             : out slv;
      tKeep             : out slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      tLast             : out sl;
      tDest             : out slv(7 downto 0);
      tId               : out slv(7 downto 0);
      tUser             : out slv) is
   begin
      slave.tready <= '1';

      -- Wait for rising edge
      while (master.tValid = '0') loop
         wait until clk = '1';
      end loop;
      -- Sample the bus
      tLast := master.tLast;
      tData := resize(master.tData, tData'length);
      tKeep := master.tKeep;
      tDest := master.tDest;
      tId   := master.tId;
      tUser := resize(master.tUser, tUser'length);

   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slVectorArray;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      constant DATA_WIDTH_C : natural := data'length(1);
      constant DATA_BYTES_C : natural := wordCount(DATA_WIDTH_C, 8);

      variable txWord  : slv(CONFIG_C.TDATA_BYTES_C*8-1 downto 0) := (others => '0');
      variable txKeep  : slv(CONFIG_C.TDATA_BYTES_C-1 downto 0)   := (others => '0');
      variable wordNum : integer;
   begin
      for i in data'range(1) loop
         wordNum                                                        := i mod CONFIG_C.TDATA_BYTES_C;
         txWord((wordNum+1)*DATA_WIDTH_C-1 downto wordNum*DATA_WIDTH_C) := muxSlVectorArray(data, i);
         txKeep((wordNum+1)*DATA_BYTES_C-1 downto wordNum*DATA_BYTES_C) := (others => '1');

         if (wordNum = CONFIG_C.TDATA_BYTES_C-1) then
            axiStreamSimSendTxn(CONFIG_C, clk, master, slave, txWord, txKeep, toSl(i = data'high));
            txWord := (others => '0');
            txKeep := (others => '0');
         end if;
         wait until clk = '1';
         master.tValid <= '0';
      end loop;
   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slv8Array;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      variable vec : SlVectorArray(data'range, data(0)'range);
   begin
      for i in data'range loop
         for j in data(0)'range loop
            vec(i, j) := data(i)(j);
         end loop;
      end loop;
      axiStreamSimSendFrame(CONFIG_C, clk, master, slave, vec, tUserFirst, tUserLast);
   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slv16Array;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      variable vec : SlVectorArray(data'range, data(0)'range);
   begin
      for i in data'range loop
         for j in data(0)'range loop
            vec(i, j) := data(i)(j);
         end loop;
      end loop;
      axiStreamSimSendFrame(CONFIG_C, clk, master, slave, vec, tUserFirst, tUserLast);
   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slv32Array;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      variable vec : SlVectorArray(data'range, data(0)'range);
   begin
      for i in data'range loop
         for j in data(0)'range loop
            vec(i, j) := data(i)(j);
         end loop;
      end loop;
      axiStreamSimSendFrame(CONFIG_C, clk, master, slave, vec, tUserFirst, tUserLast);
   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slv64Array;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      variable vec : SlVectorArray(data'range, data(0)'range);
   begin
      for i in data'range loop
         for j in data(0)'range loop
            vec(i, j) := data(i)(j);
         end loop;
      end loop;
      axiStreamSimSendFrame(CONFIG_C, clk, master, slave, vec, tUserFirst, tUserLast);
   end procedure;

   procedure axiStreamSimSendFrame (
      constant CONFIG_C : in  AxiStreamConfigType;
      signal clk        : in  sl;
      signal master     : out AxiStreamMasterType;
      signal slave      : in  AxiStreamSlaveType;
      data              : in  slv128Array;
      tUserFirst        : in  slv(7 downto 0) := (others => '0');
      tUserLast         : in  slv(7 downto 0) := (others => '0'))
   is
      variable vec : SlVectorArray(data'range, data(0)'range);
   begin
      for i in data'range loop
         for j in data(0)'range loop
            vec(i, j) := data(i)(j);
         end loop;
      end loop;
      axiStreamSimSendFrame(CONFIG_C, clk, master, slave, vec, tUserFirst, tUserLast);
   end procedure;

   function getSlvSize (c : AxiStreamConfigType) return integer is
      variable size : integer := 1;
   begin

      -- Data
      size := size + c.TDATA_BYTES_C*8;

      -- Keep
      size := size + ite((c.TKEEP_MODE_C = TKEEP_NORMAL_C), c.TDATA_BYTES_C,                       -- TKEEP_NORMAL_C
                     ite((c.TKEEP_MODE_C = TKEEP_COMP_C), bitSize(c.TDATA_BYTES_C-1),              -- TKEEP_COMP_C
                     ite((c.TKEEP_MODE_C = TKEEP_COUNT_C), bitSize(AXI_STREAM_MAX_TKEEP_WIDTH_C),  -- TKEEP_COUNT_C
                     0)));  -- TKEEP_FIXED_C

      -- User bits
      size := size + ite(c.TUSER_MODE_C = TUSER_FIRST_LAST_C, c.TUSER_BITS_C*2,
                     ite(c.TUSER_MODE_C = TUSER_LAST_C, c.TUSER_BITS_C,
                     ite(c.TUSER_MODE_C = TUSER_NORMAL_C, c.TDATA_BYTES_C * c.TUSER_BITS_C,
                     0)));  -- TUSER_NONE_C

      size := size + ite(c.TSTRB_EN_C, c.TDATA_BYTES_C, 0);  -- Strobe bits
      size := size + c.TDEST_BITS_C;
      size := size + c.TID_BITS_C;

      return(size);

   end function;

   function toSlv (din : AxiStreamMasterType; c : AxiStreamConfigType) return slv is
      variable size     : integer              := getSlvSize(c);
      variable retValue : slv(size-1 downto 0) := (others => '0');
      variable i        : integer              := 0;
   begin

      -- init, pass last
      assignSlv(i, retValue, din.tLast);

      -- Pack data
      assignSlv(i, retValue, din.tData((c.TDATA_BYTES_C*8)-1 downto 0));

      -- Pack keep
      if c.TKEEP_MODE_C = TKEEP_NORMAL_C then
         assignSlv(i, retValue, din.tKeep(c.TDATA_BYTES_C-1 downto 0));
      elsif c.TKEEP_MODE_C = TKEEP_COMP_C then
         -- Assume lsb is present
         assignSlv(i, retValue, toSlv(getTKeep(din.tKeep(c.TDATA_BYTES_C-1 downto 1), c), bitSize(c.TDATA_BYTES_C-1)));
      elsif c.TKEEP_MODE_C = TKEEP_COUNT_C then
         assignSlv(i, retValue, din.tKeep(bitSize(AXI_STREAM_MAX_TKEEP_WIDTH_C)-1 downto 0));
      end if;
      -- TKEEP_FIXED_C uses 0 bits

      -- Pack user bits
      if (c.TUSER_BITS_C > 0 and c.TUSER_MODE_C /= TUSER_NONE_C) then
         if c.TUSER_MODE_C = TUSER_FIRST_LAST_C then
            assignSlv(i, retValue, resize(axiStreamGetUserField(c, din, 0), c.TUSER_BITS_C));  -- First byte
            assignSlv(i, retValue, resize(axiStreamGetUserField(c, din, -1), c.TUSER_BITS_C));  -- Last valid byte

         elsif c.TUSER_MODE_C = TUSER_LAST_C then
            assignSlv(i, retValue, resize(axiStreamGetUserField(c, din, -1), c.TUSER_BITS_C));  -- Last valid byte

         elsif c.TUSER_MODE_C = TUSER_NORMAL_C then
            for j in 0 to c.TDATA_BYTES_C-1 loop
               assignSlv(i, retValue, resize(axiStreamGetUserField(c, din, j), c.TUSER_BITS_C));
            end loop;
         end if;
      end if;

      -- Strobe is optional
      if c.TSTRB_EN_C = true then
         assignSlv(i, retValue, din.tStrb(c.TDATA_BYTES_C-1 downto 0));
      end if;

      -- Dest is optional
      if c.TDEST_BITS_C > 0 then
         assignSlv(i, retValue, din.tDest(c.TDEST_BITS_C-1 downto 0));
      end if;

      -- Id is optional
      if c.TID_BITS_C > 0 then
         assignSlv(i, retValue, din.tId(c.TID_BITS_C-1 downto 0));
      end if;

      return(retValue);

   end function;

   function toAxiStreamMaster (din : slv; valid : sl; c : AxiStreamConfigType) return AxiStreamMasterType is
      variable master : AxiStreamMasterType                        := axiStreamMasterInit(c);
      variable user   : slv(maximum(c.TUSER_BITS_C-1, 0) downto 0) := (others => '0');
      variable keep   : slv(bitSize(c.TDATA_BYTES_C-1)-1 downto 0);
      variable i      : integer                                    := 0;
   begin

      -- Set valid,
      master.tValid := valid;

      -- Set last
      assignRecord(i, din, master.tLast);

      -- Get data
      assignRecord(i, din, master.tData((c.TDATA_BYTES_C*8)-1 downto 0));

      -- Get keep bits
      if c.TKEEP_MODE_C = TKEEP_NORMAL_C then
         assignRecord(i, din, master.tKeep(c.TDATA_BYTES_C-1 downto 0));
      elsif c.TKEEP_MODE_C = TKEEP_COMP_C then
         assignRecord(i, din, keep);
         master.tKeep := genTKeep(conv_integer(keep)+1);
      elsif c.TKEEP_MODE_C = TKEEP_COUNT_C then
         assignRecord(i, din, master.tKeep(bitSize(AXI_STREAM_MAX_TKEEP_WIDTH_C)-1 downto 0));
      else                              -- KEEP_MODE_C = TKEEP_FIXED_C
         master.tKeep := genTKeep(c.TDATA_BYTES_C);
      end if;

      -- get user bits
      if (c.TUSER_BITS_C > 0 and c.TUSER_MODE_C /= TUSER_NONE_C) then
         if c.TUSER_MODE_C = TUSER_FIRST_LAST_C then
            assignRecord(i, din, user);
            axiStreamSetUserField (c, master, resize(user, c.TUSER_BITS_C), 0);  -- First byte

            assignRecord(i, din, user);
            axiStreamSetUserField (c, master, resize(user, c.TUSER_BITS_C), -1);  -- Last valid byte

         elsif c.TUSER_MODE_C = TUSER_LAST_C then
            assignRecord(i, din, user);
            axiStreamSetUserField (c, master, resize(user, c.TUSER_BITS_C), -1);  -- Last valid byte

         elsif (c.TUSER_MODE_C = TUSER_NORMAL_C) then
            for j in 0 to c.TDATA_BYTES_C-1 loop
               assignRecord(i, din, user);
               axiStreamSetUserField (c, master, resize(user, c.TUSER_BITS_C), j);
            end loop;
         end if;
      else
         user := (others => '0');
      end if;

      -- Strobe is optional
      if c.TSTRB_EN_C = true then
         assignRecord(i, din, master.tStrb(c.TDATA_BYTES_C-1 downto 0));
      else
         master.tStrb := master.tKeep;  -- Strobe follows keep if unused
      end if;

      -- Dest is optional
      if c.TDEST_BITS_C > 0 then
         assignRecord(i, din, master.tDest(c.TDEST_BITS_C-1 downto 0));
      end if;

      -- ID is optional
      if c.TID_BITS_C > 0 then
         assignRecord(i, din, master.tId(c.TID_BITS_C-1 downto 0));
      end if;

      return(master);

   end function;

end package body AxiStreamPkg;

