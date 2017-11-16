-------------------------------------------------------------------------------
-- File       : ClinkPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Package
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

package ClinkPkg is

   ------------------------------------
   -- Link Modes
   ------------------------------------
   constant CLM_LITE_C : slv(3 downto 0) := "0001";
   constant CLM_BASE_C : slv(3 downto 0) := "0010";
   constant CLM_MEDM_C : slv(3 downto 0) := "0011";
   constant CLM_FULL_C : slv(3 downto 0) := "0100";
   constant CLM_DECA_C : slv(3 downto 0) := "0101";

   ------------------------------------
   -- Data Modes
   ------------------------------------
   constant CDM_8BIT_C  : slv(3 downto 0) := "0001";
   constant CDM_10BIT_C : slv(3 downto 0) := "0010";
   constant CDM_12BIT_C : slv(3 downto 0) := "0011";

   ------------------------------------
   -- Data Type
   ------------------------------------
   type ClDataType is record
      valid  : sl;
      data   : Slv8Array(9 downto 0);
      dv     : sl;
      fv     : sl;
      lv     : sl;
   end record ClDataType;

   constant CL_DATA_INIT_C : ClDataType := (
      valid  => '0',
      data   => (others=>(others=>'0')),
      dv     => '0',
      fv     => '0',
      lv     => '0');

   ------------------------------------
   -- Port Mapping 
   ------------------------------------

   -- Map channel to port for lite mode
   procedure clMapLitePorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType);

   -- Map channel to port for base mode
   procedure clMapBasePorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType);

   -- Map channel to port for medium mode
   procedure clMapMedmPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType);

   -- Map channel to port for full mode
   procedure clMapFullPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType);

   -- Map channel to port for deca mode
   procedure clMapDecaPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType);

   ------------------------------------
   -- Byte Mapping 
   ------------------------------------

   -- Remap data bytes
   procedure clMapBytes ( dataMode : slv; 
                          portData : ClDataType;
                          byteData : inout ClDataType );


end package ClinkPkg;

package body ClinkPkg is

   ------------------------------------
   -- Port Mapping 
   ------------------------------------

   -- Map channel to port for lite mode
   -- From page 18 of camera link spec
   procedure clMapLitePorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType) is

   begin
      portData.dv := parData(0)(26);
      portData.fv := parData(0)(25);
      portData.lv := parData(0)(24);

      portData.data(0)(4 downto 0) := parData(0)(4 downto 0));
      portData.data(0)(5)          := parData(0)(6);
      portData.data(0)(7 downto 6) := parData(0)(21 downto 20);

      -- 10 bit mode
      if dataMode = CDM_10BIT_C then
         portData.data(1)(0) := parData(0)(7);
         portData.data(1)(1) := parData(0)(19);
         bytes := 2;
      else
         bytes := 1;
      end if;
   end procedure;

   -- Map channel to port for base mode
   -- From page 15 of camera link spec
   procedure clMapBasePorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType) is

   begin
      portData.dv := parData(0)(26);
      portData.fv := parData(0)(25);
      portData.lv := parData(0)(24);

      portData.data(0)(4 downto 0) := parData(0)(4 downto 0);
      portData.data(0)(5)          := parData(0)(6);
      portData.data(0)(6)          := parData(0)(27);
      portData.data(0)(7)          := parData(0)(5);
      portData.data(1)(2 downto 0) := parData(0)(9  downto  7);
      portData.data(1)(5 downto 3) := parData(0)(14 downto 12);
      portData.data(1)(7 downto 6) := parData(0)(11 downto 10);
      portData.data(2)(0)          := parData(0)(15);
      portData.data(2)(5 downto 1) := parData(0)(22 downto 18);
      portData.data(2)(7 downto 6) := parData(0)(17 downto 16);

      -- 12 bit mode
      if dataMode = CDM_12BIT_C then
         bytes := 4;
      else
         bytes := 3;
      end if;

   end procedure;

   -- Map channel to port for medium mode
   -- From page 15 of camera link spec
   procedure clMapMedmPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType) is

      variable prevBytes : integer;

   begin

      -- Inherit base mapping
      clMapBasePorts ( dataMode, parData, prevBytes, portData );

      portData.dv := portData.dv and parData(1)(26);
      portData.fv := portData.fv and parData(1)(25);
      portData.lv := portData.lv and parData(1)(24);

      portData.data(3)(4 downto 0) := parData(1)(4 downto 0);
      portData.data(3)(5)          := parData(1)(6);
      portData.data(3)(6)          := parData(1)(27);
      portData.data(3)(7)          := parData(1)(5);
      portData.data(4)(2 downto 0) := parData(1)(9  downto  7);
      portData.data(4)(5 downto 3) := parData(1)(14 downto 12);
      portData.data(4)(7 downto 6) := parData(1)(11 downto 10);
      portData.data(5)(0)          := parData(1)(15);
      portData.data(5)(5 downto 1) := parData(1)(22 downto 18);
      portData.data(5)(7 downto 6) := parData(1)(17 downto 16);

      -- 12 bit mode
      if dataMode = CDM_12BIT_C then
         bytes := 8;
      else
         bytes := 6;
      end if;

   end procedure;

   -- Map channel to port for full mode
   -- From page 15 of camera link spec
   procedure clMapFullPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType) is

      variable prevBytes : integer;

   begin

      -- Inherit medium mapping
      clMapMedmPorts ( dataMode, parData, prevBytes,portData );

      portData.dv := portData.dv and parData(2)(26);
      portData.fv := portData.fv and parData(2)(25);
      portData.lv := portData.lv and parData(2)(24);

      portData.data(6)(4 downto 0) := parData(2)(4 downto 0);
      portData.data(6)(5)          := parData(2)(6);
      portData.data(6)(6)          := parData(2)(27);
      portData.data(6)(7)          := parData(2)(5);
      portData.data(7)(2 downto 0) := parData(2)(9  downto  7);
      portData.data(7)(5 downto 3) := parData(2)(14 downto 12);
      portData.data(7)(7 downto 6) := parData(2)(11 downto 10);

      --portData.data(8)(0)          := parData(2)(15);
      --portData.data(8)(5 downto 1) := parData(2)(22 downto 18);
      --portData.data(8)(7 downto 6) := parData(2)(17 downto 16);
      
      --bytes := 9;
      bytes := 8;

   end procedure;

   -- Map channel to port for deca mode
   -- From page 16/17 of camera link spec
   procedure clMapDecaPorts ( dataMode : slv; 
                              parData  : Slv28Array; 
                              bytes    : inout integer;
                              portData : inout ClDataType) is
   begin

      portData.dv := '0'; -- ??????
      portData.fv := parData(0)(25);
      bytes       := 10;

      -- 8-bit
      if dataMode = CDM_8BIT_C then
         portData.lv                  := parData(0)(24) and parData(1)(27) and parData(2)(27);
         portData.data(0)             := parData(0)(7  downto  0);
         portData.data(1)             := parData(0)(15 downto  8);
         portData.data(2)             := parData(0)(23 downto 16);
         portData.data(3)(1 downto 0) := parData(0)(27 downto 26);
         portData.data(3)(7 downto 2) := parData(1)(5  downto  0);
         portData.data(4)             := parData(1)(13 downto  6);
         portData.data(5)             := parData(1)(21 downto 14);
         portData.data(6)(4 downto 0) := parData(1)(26 downto 22);
         portData.data(6)(7 downto 5) := parData(2)(2  downto  0);
         portData.data(7)             := parData(2)(10 downto  3);
         portData.data(8)             := parData(2)(18 downto 11);
         portData.data(9)             := parData(2)(26 downto 19);

      -- 10-bit
      elsif dataMode = CDM_10BIT_C then
         portData.lv                  := parData(0)(24) and parData(1)(24) and parData(2)(24);
         portData.data(0)(4 downto 0) := parData(0)(4  downto  0);
         portData.data(0)(5)          := parData(0)(6);
         portData.data(0)(6)          := parData(0)(27);
         portData.data(0)(7)          := parData(0)(5);
         portData.data(1)(2 downto 0) := parData(0)(9  downto  7);
         portData.data(1)(5 downto 3) := parData(0)(14 downto 12);
         portData.data(1)(7 downto 6) := parData(0)(11 downto 10);
         portData.data(2)(0)          := parData(0)(15);
         portData.data(2)(5 downto 1) := parData(0)(22 downto 18);
         portData.data(2)(7 downto 6) := parData(0)(17 downto 16);
         portData.data(3)(4 downto 0) := parData(1)(4  downto  0);
         portData.data(3)(5)          := parData(1)(6);
         portData.data(3)(6)          := parData(1)(27);
         portData.data(3)(7)          := parData(1)(5);
         portData.data(4)(2 downto 0) := parData(1)(9  downto  7);
         portData.data(4)(5 downto 3) := parData(1)(14 downto 12);
         portData.data(4)(7 downto 6) := parData(1)(11 downto 10);
         portData.data(5)(0)          := parData(1)(15);
         portData.data(5)(5 downto 1) := parData(1)(22 downto 18);
         portData.data(5)(7 downto 6) := parData(1)(17 downto 16);
         portData.data(6)(4 downto 0) := parData(2)(4  downto  0);
         portData.data(6)(5)          := parData(2)(6);
         portData.data(6)(6)          := parData(2)(27);
         portData.data(6)(7)          := parData(2)(5);
         portData.data(7)(2 downto 0) := parData(2)(9  downto  7);
         portData.data(7)(5 downto 3) := parData(2)(14 downto 12);
         portData.data(7)(7 downto 6) := parData(2)(11 downto 10);
         portData.data(8)(0)          := parData(0)(26);
         portData.data(8)(1)          := parData(0)(23);
         portData.data(8)(3 downto 2) := parData(1)(26 downto 25);
         portData.data(8)(4)          := parData(1)(23);
         portData.data(8)(5)          := parData(2)(15);
         portData.data(8)(7 downto 6) := parData(2)(19 downto 18);
         portData.data(9)(2 downto 0) := parData(2)(22 downto 20);
         portData.data(9)(4 downto 3) := parData(2)(17 downto 16);
         portData.data(9)(6 downto 5) := parData(2)(26 downto 25);
         portData.data(9)(7)          := parData(2)(23);
      end if;
   end procedure;

   ------------------------------------
   -- Byte Mapping 
   ------------------------------------

   -- Remap data bytes
   -- From page 8 of camera link spec
   procedure clMapBytes ( dataMode : slv; 
                          portData : ClDataType;
                          byteData : inout ClDataType ) is
   begin

      byteData := portData;

      if dataMode = CDM_12BIT_C then
         byteData.data(0)             := portData.data(0);             -- A[07:00]
         byteData.data(1)(3 downto 0) := portData.data(1)(3 downto 0); -- A[11:08]
         byteData.data(1)(7 downto 4) := (others=>'0');
         byteData.data(2)             := portData.data(2);             -- B[07:00]
         byteData.data(3)(3 downto 0) := portData.data(1)(7 downto 4); -- B[11:08]
         byteData.data(3)(7 downto 4) := (others=>'0');
         byteData.data(4)             := portData.data(4);             -- C[07:00]
         byteData.data(5)(3 downto 0) := portData.data(5)(3 downto 0); -- C[11:08]
         byteData.data(5)(7 downto 4) := (others=>'0');
         byteData.data(6)             := portData.data(3);             -- D[07:00]
         byteData.data(7)(3 downto 0) := portData.data(5)(7 downto 4); -- D[11:08]
         byteData.data(7)(7 downto 4) := (others=>'0');
         byteData.data(8)             := portData.data(6);             -- E[07:00], not sure?
         byteData.data(9)(3 downto 0) := portData.data(7)(7 downto 4); -- E[11:08], not sure?
         byteData.data(9)(7 downto 4) := (others=>'0');
      end if;
   end procedure;

end package body ClinkPkg;

