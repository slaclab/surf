-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Iprog7Series.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-11-01
-- Last update: 2014-05-30
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
      clk         : in sl;
      rst         : in sl;
      start       : in sl;
      bootAddress : in slv(31 downto 0) := X"00000000");


end Iprog7Series;

architecture rtl of Iprog7Series is

   signal icape2Clk : sl;
   signal icape2Rst : sl;
   
   function selectMapBitSwapping (input : slv) return slv is
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
   end function selectMapBitSwapping;

   type StateType is (IDLE_S, PROG_S);

   type RegType is record
      state       : StateType;
      csl         : sl;
      rnw         : sl;
      cnt         : slv(3 downto 0);
      configData  : slv(31 downto 0);
      bootAddress : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      csl         => '1',
      rnw         => '1',
      cnt         => (others => '0'),
      configData  => (others => '0'),
      bootAddress => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal startEdge : sl;

begin

   BUFR_ICPAPE2 : BUFR
      generic map (
         BUFR_DIVIDE => "8")
      port map (
         CE  => '1',
         CLR => '0',
         I   => clk,
         O   => icape2Clk);

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => icape2Clk, 
         asyncRst => rst,
         syncRst  => icape2Rst);

   SynchronizerOneShot_1 : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => icape2Clk,
         rst     => icape2Rst,
         dataIn  => start,
         dataOut => startEdge);

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
         O     => open,                 -- 32-bit output: Configuration data output bus
         CLK   => icape2Clk,            -- 1-bit input: Clock Input
         CSIB  => r.csl,                -- 1-bit input: Active-Low ICAP Enable
         I     => r.configData,         -- 32-bit input: Configuration data input bus
         RDWRB => r.rnw);               -- 1-bit input: Read/Write Select input


   comb : process (bootAddress, icape2Rst, r, startEdge) is
      variable v : RegType;
   begin
      v := r;

      case (r.state) is
         when IDLE_S =>
            v.csl         := '1';
            v.rnw         := '1';
            v.cnt         := (others => '0');
            v.bootAddress := bootAddress;
            if (startEdge = '1') then
               v.state := PROG_S;
            end if;

         when PROG_S =>
            v.csl := '0';
            v.rnw := '0';
            v.cnt := r.cnt + 1;
            case (r.cnt) is
               when X"0" =>
                  --Sync Word
                  v.configData := selectMapBitSwapping(X"AA995566");
               when X"1" =>
                  --Type 1 NO OP
                  v.configData := selectMapBitSwapping(X"20000000");
               when X"2" =>
                  --Type 1 Write 1 Words to WBSTAR
                  v.configData := selectMapBitSwapping(X"30020001");
               when X"3" =>
                  --Warm Boot Start Address (Load the Desired Address)
                  v.configData := selectMapBitSwapping(bitReverse(r.bootAddress));
               when X"4" =>
                  --Type 1 Write 1 Words to CMD
                  v.configData := selectMapBitSwapping(X"30008001");
               when X"5" =>
                  --IPROG Command
                  v.configData := selectMapBitSwapping(X"0000000F");
               when X"6" =>
                  --Type 1 NO OP
                  v.configData := selectMapBitSwapping(X"20000000");
                  v.state      := IDLE_S;
               when others => null;
            end case;
            
         when others => null;
      end case;

      if (icape2Rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
   end process comb;

   seq : process (icape2Clk) is
   begin
      if (rising_edge(icape2Clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end rtl;
