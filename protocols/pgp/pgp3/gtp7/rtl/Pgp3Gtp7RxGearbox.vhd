-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTP7 32B33B to 64B66B RX Gearbox
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

entity Pgp3Gtp7RxGearbox is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Slave Interface
      phyRxClkFast  : in  sl;
      phyRxRstFast  : in  sl;
      rxHeaderValid : in  sl;
      rxHeader      : in  slv(1 downto 0);
      rxDataValid   : in  sl;
      rxData        : in  slv(31 downto 0);
      -- Master Interface
      phyRxClkSlow  : in  sl;
      phyRxRstSlow  : in  sl;
      phyRxValid    : out sl;
      phyRxHeader   : out slv(1 downto 0);
      phyRxData     : out slv(63 downto 0));
end Pgp3Gtp7RxGearbox;

architecture rtl of Pgp3Gtp7RxGearbox is

   type RegType is record
      fifoWrite : sl;
      fifoData  : slv(65 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      fifoWrite => '0',
      fifoData  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (phyRxRstFast, r, rxData, rxDataValid, rxHeader,
                   rxHeaderValid) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.fifoWrite := '0';

      -- Check for valid data
      if (rxDataValid = '1') then
         if (rxHeaderValid = '1') then
            v.fifoData(65 downto 64) := rxHeader;
            v.fifoData(63 downto 32) := rxData;
         else
            v.fifoWrite              := '1';
            v.fifoData(31 downto 0)  := rxData;
         end if;
      end if;

      -- Reset
      if (phyRxRstFast = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (phyRxClkFast) is
   begin
      if rising_edge(phyRxClkFast) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_FifoAsync : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => 66,
         MEMORY_TYPE_G => "distributed",
         ADDR_WIDTH_G  => 4)
      port map (
         rst                => phyRxRstFast,
         -- Write Ports
         wr_clk             => phyRxClkFast,
         wr_en              => r.fifoWrite,
         din                => r.fifoData,
         -- Read Ports
         rd_clk             => phyRxClkSlow,
         rd_en              => '1',
         dout(65 downto 64) => phyRxHeader,
         dout(63 downto 0)  => phyRxData,
         valid              => phyRxValid);

end rtl;
