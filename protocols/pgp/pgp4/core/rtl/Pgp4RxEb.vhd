-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 Rx Elastic Buffer
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
use surf.Pgp4Pkg.all;

entity Pgp4RxEb is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      phyRxClk    : in sl;
      phyRxRst    : in sl;
      phyRxValid  : in sl;
      phyRxData   : in slv(63 downto 0);  -- Unscrambled data from the PHY
      phyRxHeader : in slv(1 downto 0);
      -- User Transmit interface
      pgpRxClk    : in  sl;
      pgpRxRst    : in  sl;
      pgpRxValid  : out sl;
      pgpRxData   : out slv(63 downto 0);
      pgpRxHeader : out slv(1 downto 0);
      remLinkData : out slv(47 downto 0);
      overflow    : out sl;
      linkError   : out sl;
      status      : out slv(8 downto 0));
end entity Pgp4RxEb;

architecture rtl of Pgp4RxEb is

   type RegType is record
      linkError   : sl;
      dataValid   : sl;
      remLinkData : slv(47 downto 0);
      fifoIn      : slv(65 downto 0);
      fifoWrEn    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      linkError   => '0',
      dataValid   => '0',
      remLinkData => (others => '0'),
      fifoIn      => (others => '0'),
      fifoWrEn    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal valid : sl;

   signal overflowInt : sl;

begin

   comb : process (phyRxData, phyRxHeader, phyRxRst, phyRxValid, r) is
      variable v        : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.linkError := '0';
      v.dataValid := '0';

      -- Map to FIFO write
      v.fifoIn(63 downto 0)  := phyRxData;
      v.fifoIn(65 downto 64) := phyRxHeader;
      v.fifoWrEn             := phyRxValid;

      -- Check for k-code
      if (phyRxHeader = PGP4_K_HEADER_C) then

         -- Check for invalid K-code CRC
         if (phyRxData(PGP4_K_CODE_CRC_FIELD_C) /= pgp4KCodeCrc(phyRxData)) then

            -- Don't write words into the FIFO
            v.fifoWrEn  := '0';

            -- Set the error flag
            v.linkError := '1';

         elsif (phyRxData(PGP4_BTF_FIELD_C) = PGP4_SKP_C) then

            -- Don't write SKP words into the FIFO
            v.fifoWrEn    := '0';

            -- Save the remote data bus
            v.dataValid   := '1';
            v.remLinkData := phyRxData(PGP4_SKIP_DATA_FIELD_C);

         end if;

      end if;

      -- Reset
      if (RST_ASYNC_G = false and phyRxRst = '1') then
         -- Maintain save behavior before the remLinkData update (not reseting fifoIn or fifoWrEn)
         v.remLinkData := (others => '0');
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (phyRxClk, phyRxRst) is
   begin
      if (RST_ASYNC_G) and (phyRxRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(phyRxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_remLinkData : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         DATA_WIDTH_G => 48)
      port map (
         rst    => phyRxRst,
         wr_clk => phyRxClk,
         wr_en  => r.dataValid,
         din    => r.remLinkData,
         rd_clk => pgpRxClk,
         dout   => remLinkData);

   U_FifoAsync_1 : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         MEMORY_TYPE_G => "block",
         FWFT_EN_G     => true,
         PIPE_STAGES_G => 0,
         DATA_WIDTH_G  => 66,
         ADDR_WIDTH_G  => 9)
      port map (
         rst                => phyRxRst,
         -- Write Interface
         wr_clk             => phyRxClk,
         wr_en              => r.fifoWrEn,
         din                => r.fifoIn,
         overflow           => overflowInt,
         -- Read Interface
         rd_clk             => pgpRxClk,
         rd_en              => valid,
         dout(63 downto 0)  => pgpRxData,
         dout(65 downto 64) => pgpRxHeader,
         rd_data_count      => status,
         valid              => valid);

   pgpRxValid <= valid;

   U_overflow : entity surf.SynchronizerOneShot
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         clk      => pgpRxClk,
         dataIn   => overflowInt,
         dataOut  => overflow);

   U_linkError : entity surf.SynchronizerOneShot
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         clk      => pgpRxClk,
         dataIn   => r.linkError,
         dataOut  => linkError);

end architecture rtl;
