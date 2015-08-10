-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT TX Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SaltTx is
   generic (
      TPD_G       : time     := 1 ns;
      NUM_BYTES_G : positive := 2);
   port (
      -- TX Serial Stream
      txP        : out sl;
      txN        : out sl;
      txInv      : in  sl := '0';
      -- TX Parallel 8B/10B data bus
      txDataIn   : in  slv(NUM_BYTES_G*8-1 downto 0);
      txDataKIn  : in  slv(NUM_BYTES_G-1 downto 0);
      txPhyReady : out sl;
      -- Clock and Reset
      txClkEn    : out sl;
      txClk      : in  sl;
      txRst      : in  sl);
end SaltTx;

architecture rtl of SaltTx is
   constant MAX_CNT_C : natural := NUM_BYTES_G*10-1;

   type RegType is record
      txPhyReady : sl;
      txClkEn    : sl;
      tx         : sl;
      cnt        : natural range 0 to MAX_CNT_C;
      txData     : slv(MAX_CNT_C downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      txPhyReady => '0',
      txClkEn    => '0',
      tx         => '0',
      cnt        => 0,
      txData     => (others => '0'));

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;
   signal txData : slv(MAX_CNT_C downto 0);
   
begin

   OBUFDS_Inst : OBUFDS
      port map (
         I  => r.tx,
         O  => txP,
         OB => txN);

   Encoder8b10b_Inst : entity work.Encoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => NUM_BYTES_G)
      port map (
         clkEn   => r.txClkEn,
         clk     => txClk,
         rst     => txRst,
         dataIn  => txDataIn,
         dataKIn => txDataKIn,
         dataOut => txData); 

   comb : process (r, txData, txInv, txRst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.txClkEn := '0';

      -- Increment the counter
      v.cnt := r.cnt + 1;

      -- Check the counter
      if r.cnt = MAX_CNT_C then
         -- Set the flag
         v.txClkEn := '1';
         -- Reset the counter
         v.cnt     := 0;
         -- Check for Synchronous Reset      
         if txRst = '1' then
            v.txPhyReady := '0';
            -- Generate clock pattern (DC balancing during reset)
            for i in MAX_CNT_C downto 0 loop
               if ((i mod 2) = 0) then
                  v.txData(i) := '0';
               else
                  v.txData(i) := '1';
               end if;
            end loop;
         else
            v.txPhyReady := '1';
            v.txData     := txData;
         end if;
      end if;

      -- Serialize the data (LSB first)
      if txInv = '0' then
         v.tx := r.txData(r.cnt);
      else
         v.tx := not(r.txData(r.cnt));
      end if;

      -- Synchronous Reset      
      if txRst = '1' then
         v.txPhyReady := '0';
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      txPhyReady <= r.txPhyReady;
      txClkEn    <= r.txClkEn;
      
   end process comb;

   seq : process (txClk) is
   begin
      if rising_edge(txClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
