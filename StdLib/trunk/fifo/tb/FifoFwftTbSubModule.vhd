-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoTbSubModule.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-05
-- Last update: 2014-05-05
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation sub module for testing the FifoFwft modules
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity FifoTbSubModule is
   generic (
      TPD_G           : time                  := 1 ns;
      GEN_SYNC_FIFO_G : boolean               := false;
      BRAM_EN_G       : boolean               := true;
      USE_BUILT_IN_G  : boolean               := false;  --if set to true, this module is only xilinx compatible only!!!
      PIPE_STAGES_G   : natural range 0 to 16 := 0);
   port (
      rst    : in  sl;
      wrClk  : in  sl;
      rdClk  : in  sl;
      passed : out sl := '0';
      failed : out sl := '0');   
end FifoTbSubModule;

architecture mapping of FifoTbSubModule is

   signal wrEn,
      aFull,
      valid,
      rdEn,
      passedDet,
      failedDet,
      ready : sl := '0';
   signal readDelay,
      writeDelay : slv(4 downto 0) := (others => '0');
   signal din,
      dout,
      check : slv(15 downto 0) := (others => '0');
   
begin

   process(wrClk)
   begin
      if rising_edge(wrClk) then
         wrEn <= '0' after TPD_G;
         if rst = '1' then
            din        <= (others => '1') after TPD_G;
            writeDelay <= (others => '0') after TPD_G;
         else
            
            writeDelay    <= writeDelay + 1 after TPD_G;
            if writeDelay <= 3 then
               if aFull = '0' then
                  wrEn <= '1'     after TPD_G;
                  din  <= din + 1 after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

   Fifo_Inst : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         BRAM_EN_G       => BRAM_EN_G,
         USE_BUILT_IN_G  => USE_BUILT_IN_G,
         PIPE_STAGES_G   => PIPE_STAGES_G,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 16,
         ADDR_WIDTH_G    => 10)        
      port map (
         -- Resets
         rst         => rst,
         --Write Ports (wr_clk domain)
         wr_clk      => wrClk,
         wr_en       => wrEn,
         din         => din,
         almost_full => aFull,
         --Read Ports (rd_clk domain)
         rd_clk      => rdClk,
         rd_en       => rdEn,
         dout        => dout,
         valid       => valid); 

   rdEn <= valid and ready;

   process(rdClk)
   begin
      if rising_edge(rdClk) then
         passed <= passedDet after TPD_G;
         failed <= failedDet after TPD_G;
         ready  <= '0'       after TPD_G;
         if rst = '1' then
            check     <= (others => '0') after TPD_G;
            readDelay <= (others => '0') after TPD_G;
         else
            readDelay                           <= readDelay + 1 after TPD_G;
            if (readDelay >= 16) and (readDelay <= 26) then
               ready <= '1' after TPD_G;
            end if;
            if rdEn = '1' then
               check <= check + 1 after TPD_G;
               if dout /= check then
                  failedDet <= '1' after TPD_G;
               end if;
               if check = 1024 then
                  passedDet <= '1' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;


end mapping;
