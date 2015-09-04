-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasSLinkLscDmaMon.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-05
-- Last update: 2015-03-06
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AtlasSLinkLscDmaMon is
   generic (
      -- General Configurations
      TPD_G : time := 1 ns);   
   port (
      -- Streaming RX Data Interface (sAxisClk domain) 
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : in  AxiStreamSlaveType;
      -- Reference 100 MHz clock and reset
      sysClk      : in  sl;
      sysRst      : in  sl;
      -- Status Signals (sysClk domain)
      dmaSize     : out slv(31 downto 0);
      dmaMinSize  : out slv(31 downto 0);
      dmaMaxSize  : out slv(31 downto 0));
end AtlasSLinkLscDmaMon;

architecture rtl of AtlasSLinkLscDmaMon is

   type RegType is record
      cnt       : slv(31 downto 0);
      pktCnt    : slv(31 downto 0);
      pktCntMax : slv(31 downto 0);
      pktCntMin : slv(31 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      cnt       => (others => '0'),
      pktCnt    => (others => '0'),
      pktCntMax => (others => '0'),
      pktCntMin => (others => '1'));      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sysReset : sl;

begin

   comb : process (r, sAxisMaster, sAxisRst, sAxisSlave, sysReset) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check for a FIFO transaction
      if(sAxisMaster.tValid = '1') and (sAxisSlave.tReady = '1') then
         -- Count the number of 32-bit words
         if sAxisMaster.tKeep(15 downto 0) = x"FFFF" then
            v.cnt := r.cnt + 2;
         elsif sAxisMaster.tKeep(15 downto 8) = x"FF" then
            v.cnt := r.cnt + 1;
         elsif sAxisMaster.tKeep(7 downto 0) = x"FF" then
            v.cnt := r.cnt + 1;
         end if;

         -- Check for EOF
         if sAxisMaster.tLast = '1' then
            -- Latch the current value
            v.pktCnt := v.cnt;
            -- Check the max. value
            if (v.cnt > r.pktCntMax) then
               -- Update max. value
               v.pktCntMax := v.cnt;
            end if;
            -- Check the min. value
            if (v.cnt < r.pktCntMin) then
               -- Update min. value
               v.pktCntMin := v.cnt;
            end if;
            -- Reset the counter
            v.cnt := (others => '0');
         end if;
      end if;
      -- Synchronous Reset
      if (sAxisRst = '1') or (sysReset = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sAxisClk) is
   begin
      if rising_edge(sAxisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SyncIn_usrRst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => sAxisClk,
         asyncRst => sysRst,
         syncRst  => sysReset);    

   SyncOut_dmaSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sAxisClk,
         din    => r.pktCnt,
         rd_clk => sysClk,
         dout   => dmaSize);   

   SyncOut_dmaMinSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sAxisClk,
         din    => r.pktCntMin,
         rd_clk => sysClk,
         dout   => dmaMinSize);   

   SyncOut_dmaMaxSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sAxisClk,
         din    => r.pktCntMax,
         rd_clk => sysClk,
         dout   => dmaMaxSize);            

end rtl;
