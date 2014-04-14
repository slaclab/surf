-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotVector.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity SynchronizerOneShotVector is
   generic (
      TPD_G           : time     := 1 ns;   -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;  -- Reset is asynchronous
      BYPASS_SYNC_G   : boolean  := false;  -- Bypass RstSync module for synchronous data configuration
      RELEASE_DELAY_G : positive := 3;      -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : slv      := "1";    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  : slv      := "1";    -- 0 for active LOW, 1 for active HIGH
      WIDTH_G         : integer  := 16);
   port (
      clk     : in  sl;                        -- Clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0));  -- synced data
end SynchronizerOneShotVector;

architecture mapping of SynchronizerOneShotVector is

   type PolarityVectorArray is array (WIDTH_G-1 downto 0) of sl;

   function FillVectorArray (INPUT : slv)
      return PolarityVectorArray is
      variable retVar : PolarityVectorArray := (others => '1');
   begin
      if INPUT = "1" then
         retVar := (others => '1');
      else
         for i in WIDTH_G-1 downto 0 loop
            retVar(i) := INPUT(i);
         end loop;
      end if;
      return retVar;
   end function FillVectorArray;

   constant IN_POLARITY_C  : PolarityVectorArray := FillVectorArray(IN_POLARITY_G);
   constant OUT_POLARITY_C : PolarityVectorArray := FillVectorArray(OUT_POLARITY_G);
   
begin

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate
      
      SyncOneShot_Inst : entity work.SynchronizerOneShot
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            BYPASS_SYNC_G   => BYPASS_SYNC_G,
            RELEASE_DELAY_G => RELEASE_DELAY_G,
            IN_POLARITY_G   => IN_POLARITY_C(i),
            OUT_POLARITY_G  => OUT_POLARITY_C(i))      
         port map (
            clk     => clk,
            rst     => rst,
            dataIn  => dataIn(i),
            dataOut => dataOut(i)); 

   end generate GEN_VEC;
   
end architecture mapping;
