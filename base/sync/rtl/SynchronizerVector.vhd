-------------------------------------------------------------------------------
-- File       : SynchronizerVector.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2016-09-13
-------------------------------------------------------------------------------
-- Description: Wrapper for multiple SynchronizerVector modules
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
      clk     : in  sl;                 -- clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0));  -- synced data
end SynchronizerVector;

architecture rtl of SynchronizerVector is

   type RegArray is array (WIDTH_G-1 downto 0) of slv(STAGES_G-1 downto 0);

   function FillVectorArray (INPUT : slv)
      return RegArray is
      variable retVar : RegArray := (others => (others => '0'));
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

   constant INIT_C : RegArray := FillVectorArray(INIT_G);

   signal crossDomainSyncReg : RegArray := INIT_C;
   signal rin                : RegArray;

   -------------------------------
   -- XST/Synplify Attributes
   -------------------------------

   -- ASYNC_REG require for Vivado but breaks ISE/XST synthesis
   attribute ASYNC_REG                       : string;
   attribute ASYNC_REG of crossDomainSyncReg : signal is "TRUE";

   -- Synplify Pro: disable shift-register LUT (SRL) extraction
   attribute syn_srlstyle                       : string;
   attribute syn_srlstyle of crossDomainSyncReg : signal is "registers";

   -- These attributes will stop timing errors being reported on the target flip-flop during back annotated SDF simulation.
   attribute MSGON                       : string;
   attribute MSGON of crossDomainSyncReg : signal is "FALSE";

   -- These attributes will stop XST translating the desired flip-flops into an
   -- SRL based shift register.
   attribute shreg_extract                       : string;
   attribute shreg_extract of crossDomainSyncReg : signal is "no";

   -- Don't let register balancing move logic between the register chain
   attribute register_balancing                       : string;
   attribute register_balancing of crossDomainSyncReg : signal is "no";

   -------------------------------
   -- Altera Attributes 
   ------------------------------- 
   attribute altera_attribute                       : string;
   attribute altera_attribute of crossDomainSyncReg : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   
begin

   assert (STAGES_G >= 2) report "STAGES_G must be >= 2" severity failure;

   GEN : if (BYPASS_SYNC_G = false) generate

      comb : process (crossDomainSyncReg, dataIn, rst) is
      begin
         for i in WIDTH_G-1 downto 0 loop
            rin(i) <= crossDomainSyncReg(i)(STAGES_G-2 downto 0) & dataIn(i);

            if (OUT_POLARITY_G = '1') then
               dataOut(i) <= crossDomainSyncReg(i)(STAGES_G-1);
            else
               dataOut(i) <= not(crossDomainSyncReg(i)(STAGES_G-1));
            end if;
         end loop;
      end process comb;

      ASYNC_RST : if (RST_ASYNC_G) generate
         seq : process (clk, rst) is
         begin
            if (rising_edge(clk)) then
               crossDomainSyncReg <= rin after TPD_G;
            end if;
            if (rst = RST_POLARITY_G) then
               crossDomainSyncReg <= INIT_C after TPD_G;
            end if;
         end process seq;
      end generate ASYNC_RST;

      SYNC_RST : if (not RST_ASYNC_G) generate
         seq : process (clk) is
         begin
            if (rising_edge(clk)) then
               if (rst = RST_POLARITY_G) then
                  crossDomainSyncReg <= INIT_C after TPD_G;
               else
                  crossDomainSyncReg <= rin after TPD_G;
               end if;
            end if;
         end process seq;
      end generate SYNC_RST;


   end generate;

   BYPASS : if (BYPASS_SYNC_G = true) generate

      dataOut <= dataIn when(OUT_POLARITY_G = '1') else not(dataIn);
      
   end generate;


end architecture rtl;
