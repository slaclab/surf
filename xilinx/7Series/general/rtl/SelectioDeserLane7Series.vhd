-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SelectioDeser
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

library unisim;
use unisim.vcomponents.all;

entity SelectioDeserLane7Series is
   generic (
      TPD_G           : time                  := 1 ns;
      IODELAY_GROUP_G : string                := "DESER_GROUP";
      REF_FREQ_G      : real                  := 300.0;  -- IDELAYCTRL's REFCLK (in units of Hz)
      DATA_WIDTH_G    : integer range 2 to 14 := 8;
      DATA_RATE_G     : string                := "DDR";
      LSB_FIRST_G     : boolean               := true);
   port (
      -- SELECTIO Ports
      rxP       : in  sl;
      rxN       : in  sl;
      -- Clock and Reset Interface
      bitClk    : in  sl;
      wordClk   : in  sl;
      wordRst   : in  sl;
      slip      : in  sl := '0';
      -- Delay Configuration
      dlyClk    : in  sl;
      dlyLoad   : in  sl;
      dlyCfgIn  : in  slv(4 downto 0);
      dlyCfgOut : out slv(4 downto 0);
      -- Output
      dataOut   : out slv(DATA_WIDTH_G-1 downto 0));
end SelectioDeserLane7Series;

architecture mapping of SelectioDeserLane7Series is

   signal rx         : sl;
   signal rxDly      : sl;
   signal bitClkL    : sl;
   signal dataOutTmp : slv(13 downto 0);
   signal shift1     : sl;
   signal shift2     : sl;

   attribute IODELAY_GROUP            : string;
   attribute IODELAY_GROUP of U_DELAY : label is IODELAY_GROUP_G;

begin

   bitClkL <= not bitClk;

   U_IBUFDS : IBUFDS
      port map (
         I  => rxP,
         IB => rxN,
         O  => rx);

   U_DELAY : IDELAYE2
      generic map (
         REFCLK_FREQUENCY      => REF_FREQ_G,
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_VALUE          => 0,
         DELAY_SRC             => "IDATAIN",
         IDELAY_TYPE           => "VAR_LOAD")
      port map(
         DATAIN      => '0',
         IDATAIN     => rx,
         DATAOUT     => rxDly,
         C           => dlyClk,
         CE          => '0',
         INC         => '0',
         LD          => dlyLoad,
         LDPIPEEN    => '0',
         REGRST      => '0',
         CINVCTRL    => '0',
         CNTVALUEIN  => dlyCfgIn,
         CNTVALUEOUT => dlyCfgOut);

   U_ISERDES_MASTER : ISERDESE2
      generic map (
         DATA_WIDTH     => DATA_WIDTH_G,
         DATA_RATE      => DATA_RATE_G,
         IOBDELAY       => "IFD",
         DYN_CLK_INV_EN => "FALSE",
         INTERFACE_TYPE => "NETWORKING",
         SERDES_MODE    => "MASTER")
      port map (
         D            => '0',
         DDLY         => rxDly,
         CE1          => '1',
         CE2          => '1',
         CLK          => bitClk,
         CLKB         => bitClkL,
         RST          => wordRst,
         CLKDIV       => wordClk,
         CLKDIVP      => '0',
         OCLK         => '0',
         OCLKB        => '0',
         DYNCLKSEL    => '0',
         DYNCLKDIVSEL => '0',
         SHIFTIN1     => '0',
         SHIFTIN2     => '0',
         BITSLIP      => slip,
         O            => open,
         Q8           => dataOutTmp(7),
         Q7           => dataOutTmp(6),
         Q6           => dataOutTmp(5),
         Q5           => dataOutTmp(4),
         Q4           => dataOutTmp(3),
         Q3           => dataOutTmp(2),
         Q2           => dataOutTmp(1),
         Q1           => dataOutTmp(0),
         OFB          => '0',
         SHIFTOUT1    => shift1,
         SHIFTOUT2    => shift2);

   SLAVE_GEN : if (DATA_WIDTH_G = 10 or DATA_WIDTH_G = 14) generate
      U_ISERDES_SLAVE : ISERDESE2
         generic map (
            DATA_WIDTH     => DATA_WIDTH_G,
            DATA_RATE      => DATA_RATE_G,
            IOBDELAY       => "IFD",
            DYN_CLK_INV_EN => "FALSE",
            INTERFACE_TYPE => "NETWORKING",
            SERDES_MODE    => "SLAVE")
         port map (
            D            => '0',
            DDLY         => rxDly,
            CE1          => '1',
            CE2          => '1',
            CLK          => bitClk,
            CLKB         => bitClkL,
            RST          => wordRst,
            CLKDIV       => wordClk,
            CLKDIVP      => '0',
            OCLK         => '0',
            OCLKB        => '0',
            DYNCLKSEL    => '0',
            DYNCLKDIVSEL => '0',
            SHIFTIN1     => shift1,
            SHIFTIN2     => shift2,
            BITSLIP      => slip,
            O            => open,
            Q8           => dataOutTmp(13),
            Q7           => dataOutTmp(12),
            Q6           => dataOutTmp(11),
            Q5           => dataOutTmp(10),
            Q4           => dataOutTmp(9),
            Q3           => dataOutTmp(8),
            Q2           => open,
            Q1           => open,
            OFB          => '0',
            SHIFTOUT1    => open,
            SHIFTOUT2    => open);

   end generate SLAVE_GEN;

   dataOut <= ite(LSB_FIRST_G, bitReverse(dataOutTmp(DATA_WIDTH_G-1 downto 0)), dataOutTmp(DATA_WIDTH_G-1 downto 0));

end mapping;
