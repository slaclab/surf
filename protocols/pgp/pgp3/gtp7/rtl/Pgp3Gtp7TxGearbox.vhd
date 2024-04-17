-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTP7 64B66B to 32B33B TX Gearbox
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


library surf;
use surf.StdRtlPkg.all;

entity Pgp3Gtp7TxGearbox is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Slave Interface
      phyTxClkSlow : in  sl;
      phyTxRstSlow : in  sl;
      phyTxHeader  : in  slv(1 downto 0);
      phyTxData    : in  slv(63 downto 0);
      phyTxValid   : in  sl;
      phyTxDataRdy : out sl;
      -- Master Interface
      phyTxClkFast : in  sl;
      phyTxRstFast : in  sl;
      txHeader     : out slv(1 downto 0);
      txData       : out slv(31 downto 0);
      txSequence   : out slv(6 downto 0));
end Pgp3Gtp7TxGearbox;

architecture rtl of Pgp3Gtp7TxGearbox is

   type RegType is record
      fifoRead   : sl;
      txHeader   : slv(1 downto 0);
      txData     : slv(31 downto 0);
      txSequence : slv(6 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      fifoRead   => '0',
      txHeader   => (others => '0'),
      txSequence => (others => '0'),
      txData     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal writeEnable : sl;
   signal almostFull  : sl;
   signal slaveReady  : sl;
   signal fifoRead    : sl;
   signal fifoValid   : sl;
   signal fifoData    : slv(65 downto 0);

begin

   U_FifoAsync : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => 66,
         MEMORY_TYPE_G => "distributed",
         ADDR_WIDTH_G  => 4)
      port map (
         rst               => phyTxRstFast,
         -- Write Ports
         wr_clk            => phyTxClkSlow,
         wr_en             => writeEnable,
         din(65 downto 64) => phyTxHeader,
         din(63 downto 0)  => phyTxData,
         almost_full       => almostFull,
         -- Read Ports
         rd_clk            => phyTxClkFast,
         rd_en             => fifoRead,
         dout              => fifoData,
         valid             => fifoValid);

   phyTxDataRdy <= not(almostFull);
   writeEnable  <= phyTxValid and not(almostFull);

   comb : process (fifoData, fifoValid, phyTxRstFast, r) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.fifoRead := '0';

      -- Check for valid data
      if (fifoValid = '1') then

         -- Increment the counter
         v.txSequence := r.txSequence + 1;

         -- Check if last cycle was a pause cycle
         if (r.txSequence = 32) then
            -- Reset the counter
            v.txSequence := (others => '0');
         end if;

         --------------------------------------------------------------------------------------
         -- UG482 (v1.9) Figure 3-9 shows how a pause occurs at counter value 31 when using
         -- an 4-byte fabric interface in external sequence counter mode with 64B/66B encoding.
         --------------------------------------------------------------------------------------
         -- Check if not a "pause" cycle
         if (v.txSequence /= 32) then
            v.txHeader := fifoData(65 downto 64);
            -- Check the phase of the 32-bit chucking
            if (v.txSequence(0) = '0') then
               v.txData := fifoData(63 downto 32);
            else
               v.txData   := fifoData(31 downto 0);
               -- Read the FIFO
               v.fifoRead := '1';
            end if;
         end if;

      end if;

      -- Combinatorial outputs before the reset
      fifoRead <= v.fifoRead;

      -- Reset
      if (phyTxRstFast = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      txHeader   <= r.txHeader;
      txData     <= r.txData;
      txSequence <= r.txSequence;

   end process comb;

   seq : process (phyTxClkFast) is
   begin
      if rising_edge(phyTxClkFast) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
