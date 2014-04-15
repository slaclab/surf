-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Iprog7Series.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-11-01
-- Last update: 2014-03-10
-- Platform   : ISE 14.6
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   Uses the ICAP primitive to internally 
--                toggle the PROG_B via IPROG command
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Iprog7Series is
   generic (
      TPD_G : time := 1 ns);
   port (
      start       : in sl;
      bootAddress : in slv(31 downto 0);
      clk         : in sl;
      rst         : in sl);
end Iprog7Series;

architecture rtl of Iprog7Series is
   function SelectMapBitSwapping (input : slv) return slv is
      variable i      : integer;
      variable j      : integer;
      variable output : slv(0 to 31);
   begin
      for i in 0 to 3 loop
         for j in 0 to 7 loop
            output((8*i)+j) := input((8*i)+(7-j));
         end loop;
      end loop;
      return output;
   end function SelectMapBitSwapping;

   type StateType is (
      IDLE_S,
      PHASE_UP_S,
      LO_PHASE_S,
      HI_PHASE_S);
   signal state : StateType := IDLE_S;

   signal configStrb : sl := '0';
   signal configRnW,
      configCsL : sl := '1';
   signal cnt,
      dataPtnr : slv(3 downto 0) := (others => '0');
   signal address,
      configIn,
      configOut : slv(31 downto 0) := (others => '0');
begin
   ICAPE2_inst : ICAPE2
      generic map (
         -- Specifies the pre-programmed Device ID value to be used for simulation
         -- purposes
         DEVICE_ID         => x"03651093",
         -- Specifies the input and output data width to be used with the ICAPE2. 
         -- Possible values: (X8,X16 or X32).
         ICAP_WIDTH        => "X32",
         -- Specifies the Raw Bitstream (RBT) file to be parsed by the simulation      
         -- model
         SIM_CFG_FILE_NAME => "NONE")
      port map (
         O     => open,      -- 32-bit output: Configuration data output bus
         CLK   => configStrb,-- 1-bit input: Clock Input
         CSIB  => configCsL, -- 1-bit input: Active-Low ICAP Enable
         I     => configIn,  -- 32-bit input: Configuration data input bus
         RDWRB => configRnW);-- 1-bit input: Read/Write Select input

   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            configRnW  <= '1'             after TPD_G;
            configCsL  <= '1'             after TPD_G;
            configStrb <= '0'             after TPD_G;
            configIn   <= (others => '0') after TPD_G;
            address    <= (others => '0') after TPD_G;
            cnt        <= (others => '0') after TPD_G;
            dataPtnr   <= (others => '0') after TPD_G;
            state      <= IDLE_S          after TPD_G;
         else
            cnt <= cnt + 1 after TPD_G;
            if cnt = x"F" then
               cnt <= (others => '0') after TPD_G;
               if configStrb = '1' then
                  configStrb <= '0' after TPD_G;
               else
                  configStrb <= '1' after TPD_G;
               end if;
            end if;
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  configCsL <= '1' after TPD_G;
                  configRnW <= '1' after TPD_G;
                  if start = '1' then
                     address  <= bootAddress     after TPD_G;
                     configIn <= (others => '1') after TPD_G;  --Dummy Word
                     state    <= PHASE_UP_S      after TPD_G;
                  end if;
                  ----------------------------------------------------------------------
               when PHASE_UP_S =>
                  if (cnt = x"F") and (configStrb = '1') then
                     configCsL <= '0'        after TPD_G;
                     configRnW <= '0'        after TPD_G;
                     state     <= LO_PHASE_S after TPD_G;
                  end if;
                  ----------------------------------------------------------------------
               when LO_PHASE_S =>
                  if cnt = x"F" then
                     state <= HI_PHASE_S after TPD_G;
                  end if;
                  ----------------------------------------------------------------------
               when HI_PHASE_S =>
                  if cnt = x"F" then
                     dataPtnr <= dataPtnr + 1 after TPD_G;
                     if dataPtnr = x"7" then
                        dataPtnr <= (others => '0') after TPD_G;
                        state    <= IDLE_S          after TPD_G;
                     else
                        if dataPtnr = x"0" then
                           --Sync Word
                           configIn <= SelectMapBitSwapping(x"AA995566") after TPD_G;
                        elsif dataPtnr = x"1" then
                           --Type 1 NO OP
                           configIn <= SelectMapBitSwapping(x"20000000") after TPD_G;
                        elsif dataPtnr = x"2" then
                           --Type 1 Write 1 Words to WBSTAR
                           configIn <= SelectMapBitSwapping(x"30020001") after TPD_G;
                        elsif dataPtnr = x"3" then
                           --Warm Boot Start Address (Load the Desired Address)
                           configIn <= SelectMapBitSwapping(bitReverse(address)) after TPD_G;
                        elsif dataPtnr = x"4" then
                           --Type 1 Write 1 Words to CMD
                           configIn <= SelectMapBitSwapping(x"30008001") after TPD_G;
                        elsif dataPtnr = x"5" then
                           --IPROG Command
                           configIn <= SelectMapBitSwapping(x"0000000F") after TPD_G;
                        elsif dataPtnr = x"6" then
                           --Type 1 NO OP
                           configIn <= SelectMapBitSwapping(x"20000000") after TPD_G;
                        end if;
                        state <= LO_PHASE_S after TPD_G;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;
end rtl;
