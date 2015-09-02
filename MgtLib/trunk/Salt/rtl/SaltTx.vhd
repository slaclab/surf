-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT TX Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SaltTx is
   generic (
      TPD_G              : time                := 1 ns;
      COMMON_TX_CLK_G    : boolean             := false;  -- Set to true if sAxisClk and clk are the same clock
      SLAVE_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- TX Serial Stream
      txP         : out sl;
      txN         : out sl;
      -- Reference Signals
      clk         : in  sl;
      clk2p5x     : in  sl;
      clk5x       : in  sl;
      rst         : in  sl;
      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType);
end SaltTx;

architecture mapping of SaltTx is

   signal dataK   : sl;
   signal data8B  : slv(7 downto 0);
   signal data10B : slv(9 downto 0);

   component SaltTxSerdes
      port (
         dataout_p  : out sl;
         dataout_n  : out sl;
         datain     : in  slv(9 downto 0);
         txclk      : in  sl;
         inter_clk  : in  sl;
         system_clk : in  sl;
         reset      : in  sl);
   end component;
   
begin

   SaltTxFifo_Inst : entity work.SaltTxFifo
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => COMMON_TX_CLK_G,
         SLAVE_AXI_CONFIG_G => SLAVE_AXI_CONFIG_G)
      port map (
         -- TX Parallel Stream
         dataK       => dataK,
         data8B      => data8B,
         -- Reference Signals
         clk         => clk,
         rst         => rst,
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave);

   Encoder8b10b_Inst : entity work.Encoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 1)
      port map (
         clk        => clk,
         rst        => rst,
         dataIn     => data8B,
         dataKIn(0) => dataK,
         dataOut    => data10B); 

   SERDES_Inst : SaltTxSerdes
      port map (
         dataout_p  => txP,
         dataout_n  => txN,
         datain     => data10B,
         txclk      => clk5x,           -- 625 MHz
         inter_clk  => clk2p5x,         -- 312.5 MHz
         system_clk => clk,             -- 125 MHz       
         reset      => rst); 

end mapping;
