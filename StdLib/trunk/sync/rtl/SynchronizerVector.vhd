-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerVector.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2014-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

use work.StdRtlPkg.all;

entity SynchronizerVector is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      OUT_POLARITY_G : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      RST_ASYNC_G    : boolean  := false;  -- Reset is asynchronous
      STAGES_G       : positive := 2;
      BYPASS_SYNC_G  : boolean  := false;  -- Bypass Synchronizer module for synchronous data configuration            
      WIDTH_G        : integer  := 16;
      INIT_G         : slv      := "0");
   port (
      clk     : in  sl;                        -- clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0));  -- synced data
end SynchronizerVector;

architecture rtl of SynchronizerVector is

   type InitVectorArray is array (WIDTH_G-1 downto 0) of slv(STAGES_G-1 downto 0);

   function FillVectorArray (INPUT : slv)
      return InitVectorArray is
      variable retVar : InitVectorArray := (others => (others => '0'));
   begin
      if INPUT = "0" then
         retVar := (others => (others => '0'));
      else
         for i in WIDTH_G-1 downto 0 loop
            for j in STAGES_G-1 downto 0 loop
               retVar(i)(j) := INIT_G(i);
            end loop;
         end loop;
      end if;
      return retVar;
   end function FillVectorArray;

   constant INIT_C : InitVectorArray := FillVectorArray(INIT_G);

begin

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate
      
      Synchronizer_Inst : entity work.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            OUT_POLARITY_G => OUT_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            STAGES_G       => STAGES_G,
            BYPASS_SYNC_G  => BYPASS_SYNC_G,
            INIT_G         => INIT_C(i))      
         port map (
            clk     => clk,
            rst     => rst,
            dataIn  => dataIn(i),
            dataOut => dataOut(i)); 

   end generate GEN_VEC;

end architecture rtl;
