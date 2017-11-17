-------------------------------------------------------------------------------
-- File       : ClinkDeSerial.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- Block to de-serialize a block of 28 bits packed into 4 7-bit serial streams.
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
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity ClinkDeSerial is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input clock and data
      clkIn    : in  sl;
      dataIn   : in  slv(3 downto 0);
      -- System clock and reset
      sysClk   : in  sl;
      sysRst   : in  sl;
      -- Status
      locked   : out sl;
      -- Data output
      parData  : out slv(27 downto 0);
      parValid : out sl;
      parReady : in  sl := '1');
end ClinkDeSerial;

architecture structure of ClinkDeSerial is

   type RegType is record
      count   : integer range 0 to 99;
      locked  : sl;
      shift   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count   => 0,
      locked  => '0',
      shift   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clkShift      : slv(6  downto 0);
   signal dataShift     : Slv7Array(3 downto 0);
   signal parDataIn     : slv(27 downto 0);
   signal clinkClk      : sl;
   signal clinkRst      : sl;
   signal clinkClk7x    : sl;
   signal clinkClk7xInv : sl;

begin

   --------------------------------------
   -- Clock Generation
   --------------------------------------
   U_ClkGen : entity work.ClockManager7
      generic map (
         TPD_G               => TPD_G,
         INPUT_BUFG_G        => false,
         NUM_CLOCKS_G        => 2,
         BANDWIDTH_G         => "OPTIMIZED",
         CLKIN_PERIOD_G      => 11.765,
         DIVCLK_DIVIDE_G     => 1,
         CLKFBOUT_MULT_F_G   => 14.0,
         CLKOUT0_DIVIDE_F_G  => 14.0,
         CLKOUT1_DIVIDE_G    => 2)
      port map (
         clkIn            => clkIn,
         rstIn            => sysRst,
         clkOut(0)        => clinkClk,
         clkOut(1)        => clinkClk7x,
         rstOut(0)        => clinkRst);

   -- Inverted clock
   clinkClk7xInv <= not clinkClk7x;

   --------------------------------------
   -- Clock alignment detection
   --------------------------------------

   -- Pass clock through a input serdes
   U_ClkShift : ISERDESE2
      generic map (
         DATA_RATE         => "SDR",        -- DDR, SDR
         DATA_WIDTH        => 7,            -- Parallel data width (2-8,10,14)
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
         IOBDELAY          => "NONE",       -- NONE, BOTH, IBUF, IFD
         NUM_CE            => 1,            -- Number of clock enables (1,2)
         OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
         SERDES_MODE       => "MASTER"      -- MASTER, SLAVE
      )
      port map (
         Q1           => clkShift(0),
         Q2           => clkShift(1),
         Q3           => clkShift(2),
         Q4           => clkShift(3),
         Q5           => clkShift(4),
         Q6           => clkShift(5),
         Q7           => clkShift(6),
         BITSLIP      => r.shift,
         CE1          => '1',
         CE2          => '1',
         CLKDIVP      => '0',
         CLK          => clinkClk7x,
         CLKB         => clinkClk7xInv,
         CLKDIV       => clinkClk,
         OCLK         => '0',
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         D            => clkIn,
         DDLY         => '0',
         OFB          => '0',
         OCLKB        => '0',
         RST          => clinkRst,
         SHIFTIN1     => '0',
         SHIFTIN2     => '0'
      );

   -- Data tracking
   comb : process (clinkRst, r, clkShift) is
      variable v  : RegType;
   begin

      v := r;
      v.shift := '0';

      -- Counter
      v.count := r.count + 1;

      -- Check for required bit shift every 100 clocks
      if r.count = 99 then
         v.count := 0;

         if clkShift /= "1100011" then
            v.shift  := '1';
            v.locked := '0';
         else
            v.locked := '1';
         end if;
      end if;

      -- Reset
      if (clinkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -- sync logic
   seq : process (clinkClk) is
   begin
      if (rising_edge(clinkClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   --------------------------------------
   -- Data Shifters
   --------------------------------------
   U_DataGen : for i in 0 to 3 generate
      U_DataShift : ISERDESE2
         generic map (
            DATA_RATE         => "SDR",        -- DDR, SDR
            DATA_WIDTH        => 7,            -- Parallel data width (2-8,10,14)
            DYN_CLKDIV_INV_EN => "FALSE",
            DYN_CLK_INV_EN    => "FALSE",
            INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
            IOBDELAY          => "NONE",       -- NONE, BOTH, IBUF, IFD
            NUM_CE            => 1,            -- Number of clock enables (1,2)
            OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
            SERDES_MODE       => "MASTER"      -- MASTER, SLAVE
         )
         port map (
            Q1           => dataShift(i)(0),
            Q2           => dataShift(i)(1),
            Q3           => dataShift(i)(2),
            Q4           => dataShift(i)(3),
            Q5           => dataShift(i)(4),
            Q6           => dataShift(i)(5),
            Q7           => dataShift(i)(6),
            BITSLIP      => r.shift,
            CE1          => '1',
            CE2          => '1',
            CLKDIVP      => '0',
            CLK          => clinkClk7x,
            CLKB         => clinkClk7xInv,
            CLKDIV       => clinkClk,
            OCLK         => '0',
            DYNCLKDIVSEL => '0',
            DYNCLKSEL    => '0',
            D            => dataIn,
            DDLY         => '0',
            OFB          => '0',
            OCLKB        => '0',
            RST          => clinkRst,
            SHIFTIN1     => '0',
            SHIFTIN2     => '0'
         );
   end generate;

   --------------------------------------
   -- Adjust data bit mappings
   -- From DS90CR288A data sheet
   --------------------------------------
   parDataIn(0)  <= dataShift(0)(6);
   parDataIn(1)  <= dataShift(0)(5);
   parDataIn(2)  <= dataShift(0)(4);
   parDataIn(3)  <= dataShift(0)(3);
   parDataIn(4)  <= dataShift(0)(2);
   parDataIn(5)  <= dataShift(3)(5);
   parDataIn(6)  <= dataShift(0)(1);

   parDataIn(7)  <= dataShift(0)(0);
   parDataIn(8)  <= dataShift(1)(6);
   parDataIn(9)  <= dataShift(1)(5);
   parDataIn(10) <= dataShift(3)(4);
   parDataIn(11) <= dataShift(3)(3);
   parDataIn(12) <= dataShift(1)(4);
   parDataIn(13) <= dataShift(1)(3);

   parDataIn(14) <= dataShift(1)(2);
   parDataIn(15) <= dataShift(1)(1);
   parDataIn(16) <= dataShift(3)(2);
   parDataIn(17) <= dataShift(3)(1);
   parDataIn(18) <= dataShift(1)(0);
   parDataIn(19) <= dataShift(2)(6);
   parDataIn(20) <= dataShift(2)(5);

   parDataIn(21) <= dataShift(2)(4);
   parDataIn(22) <= dataShift(2)(3);
   parDataIn(23) <= dataShift(3)(0);
   parDataIn(24) <= dataShift(2)(2);
   parDataIn(25) <= dataShift(2)(1);
   parDataIn(26) <= dataShift(2)(0);
   parDataIn(27) <= dataShift(3)(6);

   --------------------------------------
   -- Output FIFO and status
   --------------------------------------
   U_DataFifo: entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         BRAM_EN_G       => false,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 28,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => clinkRst,
         wr_clk        => clinkClk,
         wr_en         => '1',
         din           => parDataIn,
         rd_clk        => sysClk,
         rd_en         => parReady,
         dout          => parData,
         valid         => parValid);

   U_Status: entity work.Synchronizer
      generic map ( TPD_G => TPD_G )
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.locked,
         dataOut => locked);

end structure;

