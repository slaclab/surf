-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Synchronizer.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-13
-- Last update: 2014-02-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A simple multi Flip FLop synchronization module.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity SynchronizerEdge is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      OUT_POLARITY_G : sl       := '1';  -- 0 for active LOW, 1 for active HIGH
      RST_ASYNC_G    : boolean  := false;-- Reset is asynchronous
      STAGES_G       : positive := 3;
      INIT_G         : slv      := "0");
   port (
      clk         : in  sl;                        -- clock to be SYNC'd to
      rst         : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn      : in  sl;                        -- Data to be 'synced'
      dataOut     : out sl;                        -- synced data
      risingEdge  : out sl;                        -- Rising edge detected
      fallingEdge : out sl);                       -- Falling edge detected
begin
   assert (STAGES_G >= 3) report "STAGES_G must be >= 3" severity failure;
end SynchronizerEdge;

architecture rtl of SynchronizerEdge is

   constant INIT_C : slv(STAGES_G-1 downto 0) := ite(INIT_G = "0", slvZero(STAGES_G), INIT_G);

   signal syncData,
      dataDly : sl;
   
begin

   Synchronizer_Inst : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         STAGES_G       => (STAGES_G-1),
         INIT_G         => INIT_C(STAGES_G-2 downto 0))      
   port map (
      clk     => clk,
      rst     => rst,
      dataIn  => dataIn,
      dataOut => syncData); 

   process(clk, rst)
   begin
      if (RST_ASYNC_G = true) and (rst = RST_POLARITY_G) then
         dataDly <= INIT_C(STAGES_G-1) after TPD_G;
      elsif rising_edge(clk) then
         if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
            dataDly <= INIT_C(STAGES_G-1) after TPD_G;
         else
            dataDly <= syncData after TPD_G;
         end if;
      end if;
   end process;

   dataOut     <= dataDly;
   risingEdge  <= syncData and not(dataDly);
   fallingEdge <= not(syncData) and dataDly;
   
end architecture rtl;
