-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotCntVector.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-05-27
-------------------------------------------------------------------------------
-- Description: Wrapper for multiple SynchronizerOneShotCnt modules
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

entity SynchronizerOneShotCntVector is
   generic (
      TPD_G           : time     := 1 ns;  -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;  -- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G    : boolean  := false;  -- True if wrClk and rdClk are the same clock
      RELEASE_DELAY_G : positive := 3;  -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (dataIn port)
      OUT_POLARITY_G  : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (dataOut port)
      USE_DSP48_G     : string   := "no";  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
      SYNTH_CNT_G     : slv      := "1";  -- Set to 1 for synthesising counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G  : boolean  := true;  -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G     : positive := 16;
      WIDTH_G         : positive := 16);
   port (
      -- Write Ports (wrClk domain)    
      dataIn     : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      -- Read Ports (rdClk domain)    
      rollOverEn : in  slv(WIDTH_G-1 downto 0);   -- '1' allows roll over of the counter
      cntRst     : in  sl := not RST_POLARITY_G;  -- Optional counter reset
      dataOut    : out slv(WIDTH_G-1 downto 0);   -- Synced data
      cntOut     : out SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);  -- Synced counter
      -- Clocks and Reset Ports
      wrClk      : in  sl;
      wrRst      : in  sl := not RST_POLARITY_G;
      rdClk      : in  sl;              -- clock to be SYNC'd to
      rdRst      : in  sl := not RST_POLARITY_G);      
end SynchronizerOneShotCntVector;

architecture mapping of SynchronizerOneShotCntVector is

   function fillVectorArray (INPUT : slv) return slv is
   begin
      return ite(INPUT = "1", slvOne(WIDTH_G),
                 ite(INPUT = "0", slvZero(WIDTH_G),
                     INPUT));
   end function fillVectorArray;

   constant IN_POLARITY_C  : slv(WIDTH_G-1 downto 0) := fillVectorArray(IN_POLARITY_G);
   constant OUT_POLARITY_C : slv(WIDTH_G-1 downto 0) := fillVectorArray(OUT_POLARITY_G);
   constant SYNTH_CNT_C    : slv(WIDTH_G-1 downto 0) := fillVectorArray(SYNTH_CNT_G);

   type MySlvArray is array (WIDTH_G-1 downto 0) of slv(CNT_WIDTH_G-1 downto 0);
   signal cnt : MySlvArray;
   
begin

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate
      
      SyncOneShotCnt_Inst : entity work.SynchronizerOneShotCnt
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            COMMON_CLK_G    => COMMON_CLK_G,
            RELEASE_DELAY_G => RELEASE_DELAY_G,
            IN_POLARITY_G   => IN_POLARITY_C(i),
            OUT_POLARITY_G  => OUT_POLARITY_C(i),
            USE_DSP48_G     => USE_DSP48_G,
            SYNTH_CNT_G     => SYNTH_CNT_C(i),
            CNT_RST_EDGE_G  => CNT_RST_EDGE_G,
            CNT_WIDTH_G     => CNT_WIDTH_G)           
         port map (
            -- Write Ports (wrClk domain)    
            dataIn     => dataIn(i),
            -- Read Ports (rdClk domain)    
            rollOverEn => rollOverEn(i),
            cntRst     => cntRst,
            dataOut    => dataOut(i),
            cntOut     => cnt(i),
            -- Clocks and Reset Ports
            wrClk      => wrClk,
            wrRst      => wrRst,
            rdClk      => rdClk,
            rdRst      => rdRst);            

      GEN_MAP :
      for j in (CNT_WIDTH_G-1) downto 0 generate
         cntOut(i, j) <= cnt(i)(j);
      end generate GEN_MAP;
      
   end generate GEN_VEC;
   
end architecture mapping;
