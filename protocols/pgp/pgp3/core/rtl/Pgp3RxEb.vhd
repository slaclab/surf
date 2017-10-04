-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Pgp3 Rx Elastic Buffer
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Pgp3Pkg.all;

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
      overflow    : out sl;
      status      : out slv(8 downto 0));

end entity Pgp3RxEb;

architecture rtl of Pgp3RxEb is

   type RegType is record
      fifoIn   : slv(65 downto 0);
      fifoWrEn : sl;
   end record RegType;

   signal r   : RegType := (fifoIn => (others => '0'), fifoWrEn => '0');
   signal rin : RegType;

   signal valid : sl;

   signal overflowInt : sl;

begin

   comb : process (phyRxData, phyRxHeader, phyRxValid, r) is
      variable v : RegType;
   begin
      v := r;

      v.fifoIn(63 downto 0)  := phyRxData;
      v.fifoIn(65 downto 64) := phyRxHeader;
      v.fifoWrEn             := phyRxValid;

      -- Don't write SKP words into the FIFO
      if (phyRxHeader = K_HEADER_C and phyRxData(63 downto 56) = SKP_C) then
         v.fifoWrEn := '0';
      end if;

      rin <= v;

   end process comb;

   seq : process (phyRxClk) is
   begin
      if (rising_edge(phyRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_FifoAsync_1 : entity work.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         BRAM_EN_G     => true,
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
         overflow           => overflowInt,     -- [out]
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

   U_RstSync_1 : entity work.RstSync
      generic map (
         TPD_G           => TPD_G)
      port map (
         clk      => pgpRxClk,          -- [in]
         asyncRst => overflowInt,          -- [in]
         syncRst  => overflow);     -- [out]

   pgpRxValid <= valid;

end architecture rtl;
