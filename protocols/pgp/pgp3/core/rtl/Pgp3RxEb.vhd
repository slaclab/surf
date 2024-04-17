-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Rx Elastic Buffer
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.Pgp3Pkg.all;

entity Pgp3RxEb is

   generic (
      TPD_G : time := 1 ns);
   port (
      phyRxClk    : in sl;
      phyRxRst    : in sl;
      phyRxValid  : in sl;
      phyRxData   : in slv(63 downto 0);  -- Unscrabled data from the phy
      phyRxHeader : in slv(1 downto 0);

      -- User Transmit interface
      pgpRxClk    : in  sl;
      pgpRxRst    : in  sl;
      pgpRxValid  : out sl;
      pgpRxData   : out slv(63 downto 0);
      pgpRxHeader : out slv(1 downto 0);
      remLinkData : out slv(55 downto 0);
      overflow    : out sl;
      status      : out slv(8 downto 0));

end entity Pgp3RxEb;

architecture rtl of Pgp3RxEb is

   type RegType is record
      remLinkData : slv(55 downto 0);
      fifoIn      : slv(65 downto 0);
      fifoWrEn    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      remLinkData => (others => '0'),
      fifoIn      => (others => '0'),
      fifoWrEn    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal valid : sl;

   signal overflowInt : sl;

begin

   comb : process (phyRxData, phyRxHeader, phyRxRst, phyRxValid, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Map to FIFO write
      v.fifoIn(63 downto 0)  := phyRxData;
      v.fifoIn(65 downto 64) := phyRxHeader;
      v.fifoWrEn             := phyRxValid;

      -- Check for SKIP code
      if (phyRxHeader = PGP3_K_HEADER_C) and (phyRxData(PGP3_BTF_FIELD_C) = PGP3_SKP_C) then
         -- Don't write SKP words into the FIFO
         v.fifoWrEn    := '0';
         -- Save the remote data bus
         v.remLinkData := phyRxData(PGP3_SKIP_DATA_FIELD_C);
      end if;

      -- Reset
      if (phyRxRst = '1') then
         -- Maintain save behavior before the remLinkData update (not reseting fifoIn or fifoWrEn)
         v.remLinkData := (others => '0');
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (phyRxClk) is
   begin
      if (rising_edge(phyRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_remLinkData : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 56)
      port map (
         rst    => phyRxRst,
         wr_clk => phyRxClk,
         din    => r.remLinkData,
         rd_clk => pgpRxClk,
         dout   => remLinkData);

   U_FifoAsync_1 : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "block",
         FWFT_EN_G     => true,
         PIPE_STAGES_G => 0,
         DATA_WIDTH_G  => 66,
         ADDR_WIDTH_G  => 9)
      port map (
         rst                => phyRxRst,     -- [in]
         wr_clk             => phyRxClk,     -- [in]
         wr_en              => r.fifoWrEn,   -- [in]
         din                => r.fifoIn,     -- [in]
         wr_data_count      => open,         -- [out]
         wr_ack             => open,         -- [out]
         overflow           => overflowInt,  -- [out]
         prog_full          => open,         -- [out]
         almost_full        => open,         -- [out]
         full               => open,         -- [out]
         not_full           => open,         -- [out]
         rd_clk             => pgpRxClk,     -- [in]
         rd_en              => valid,        -- [in]
         dout(63 downto 0)  => pgpRxData,    -- [out]
         dout(65 downto 64) => pgpRxHeader,  -- [out]
         rd_data_count      => status,       -- [out]
         valid              => valid,        -- [out]
         underflow          => open,         -- [out]
         prog_empty         => open,         -- [out]
         almost_empty       => open,         -- [out]
         empty              => open);        -- [out]

   U_RstSync_1 : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => pgpRxClk,          -- [in]
         asyncRst => overflowInt,       -- [in]
         syncRst  => overflow);         -- [out]

   pgpRxValid <= valid;

end architecture rtl;
