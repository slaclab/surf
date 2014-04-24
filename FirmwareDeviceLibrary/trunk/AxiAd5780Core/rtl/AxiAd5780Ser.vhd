-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiAd5780Ser.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AD5780 DAC Module's serializer
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiAd5780Pkg.all;

entity AxiAd5780Ser is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- DAC Ports
      dacIn    : in  AxiAd5780InType;
      dacOut   : out AxiAd5780OutType;
      -- DAC Data Interface (axiClk domain)
      dacValid : in  sl;
      dacData  : in  slv(17 downto 0);  --2's complement
      -- Clocks and Resets
      axiClk   : in  sl;
      axiRst   : in  sl;
      dacClk   : in  sl);               --up to 70 MHz
end AxiAd5780Ser;

architecture rtl of AxiAd5780Ser is

   type StateType is (
      RST_S,
      IDLE_S,
      SCK_HIGH_S,
      SCK_LOW_S,
      MIN_SYNC_HI_S);
   type RegType is record
      csL   : sl;
      sck   : sl;
      sdi   : sl;
      rstL  : sl;
      cnt   : slv(4 downto 0);
      reg   : slv(23 downto 0);
      state : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      '1',
      '1',
      '1',
      '0',
      (others => '0'),
      (others => '0'),
      RST_S); 
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dacValidSync,
      dacRst : sl;
   signal dacDataSync : slv(17 downto 0);

   -- Use I/O PAD's FD register
   attribute IOB      : string;
   attribute IOB of r : signal is "True";     
   
   -- Mark the Vivado Debug Signals
   attribute mark_debug : string;
   attribute mark_debug of
      dacRst,
      dacIn,
      dacOut,
      dacValidSync,
      dacDataSync : signal is "TRUE";
   
begin

   SynchronizerFifo_0 : entity work.SynchronizerFifo
      generic map(
         DATA_WIDTH_G => 18)
      port map (
         -- ASYNC Reset
         rst    => axiRst,
         -- Write Ports
         wr_clk => axiClk,
         wr_en  => dacValid,
         din    => dacData,
         -- Read Ports
         rd_clk => dacClk,
         valid  => dacValidSync,
         dout   => dacDataSync);

   RstSync_0 : entity work.RstSync
      port map (
         clk      => dacClk,
         asyncRst => axiRst,
         syncRst  => dacRst);  

   comb : process (dacDataSync, dacRst, dacValidSync, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      -- *** placeholder ***

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when RST_S =>
            v.cnt := r.cnt + 1;
            if r.cnt = 8 then
               -- release the reset
               v.rstL := '1';
            elsif r.cnt = 31 then
               -- reset the counter
               v.cnt               := (others => '0');
               -- configure the DAC
               v.reg(23 downto 20) := "0010";           -- CTRL_REG: write to control register
               v.reg(19 downto 6)  := (others => '0');  -- Reserved: reserved should be set to zero

               v.reg(5) := '1';         -- SDODIS: disable SDO
               v.reg(4) := '0';         -- BIN/2sC: use 2's complement
               v.reg(3) := '0';         -- DACTRI: put DAC into normal operating mode
               v.reg(2) := '0';         -- OPGND: put DAC into normal operating mode
               v.reg(1) := '1';         -- RBUF: Unity-Gain Configuration 
               v.reg(0) := '0';         -- Reserved: reserved should be set to zero

               -- next state
               v.state := SCK_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when IDLE_S =>
            if dacValidSync = '1' then
               v.reg   := "0001" & dacDataSync & "00";
               v.state := SCK_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when SCK_HIGH_S =>
            v.csL   := '0';
            v.sck   := '1';
            v.sdi   := r.reg(23);
            v.state := SCK_LOW_S;
         ----------------------------------------------------------------------
         when SCK_LOW_S =>
            v.sck := '0';
            v.cnt := r.cnt + 1;
            v.reg := r.reg(22 downto 0) & '0';
            if r.cnt = 23 then
               v.cnt   := (others => '0');
               v.state := MIN_SYNC_HI_S;
            else
               v.state := SCK_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when MIN_SYNC_HI_S =>
            v.csL := '1';
            v.sck := '1';
            v.cnt := r.cnt + 1;
            if r.cnt = 1 then
               v.cnt   := (others => '0');
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if dacRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dacOut.dacSync <= r.csL;
      dacOut.dacSclk <= r.sck;
      dacOut.dacSdi  <= r.sdi;
      dacOut.dacLdac <= '0';
      dacOut.dacClr  <= '1';
      dacOut.dacRst  <= r.rstL;
      
   end process comb;

   seq : process (dacClk) is
   begin
      if rising_edge(dacClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
