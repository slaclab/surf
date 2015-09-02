-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT Core
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SaltCore is
   generic (
      TPD_G               : time                := 1 ns;
      TX_ENABLE_G         : boolean             := true;
      RX_ENABLE_G         : boolean             := true;
      COMMON_TX_CLK_G     : boolean             := false;  -- Set to true if sAxisClk and clk are the same clock
      COMMON_RX_CLK_G     : boolean             := false;  -- Set to true if mAxisClk and clk are the same clock      
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4);
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);
      IODELAY_GROUP_G     : string              := "SALT_IODELAY_GRP";
      RXCLK5X_FREQ_G      : real                := 625.0;  -- In units of MHz
      XIL_DEVICE_G        : string              := "ULTRASCALE");
   port (
      -- TX Serial Stream
      txP           : out sl;
      txN           : out sl;
      -- RX Serial Stream
      rxP           : in  sl;
      rxN           : in  sl;
      -- Reference Signals
      clk           : in  sl;
      clk2p5x       : in  sl;
      clk5x         : in  sl;
      rst           : in  sl;
      iDelayCtrlRdy : in  sl;
      -- Slave Port
      sAxisClk      : in  sl;
      sAxisRst      : in  sl;
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      -- Master Port
      mAxisClk      : in  sl;
      mAxisRst      : in  sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);    
end SaltCore;

architecture mapping of SaltCore is

begin

   TX_ENABLE : if (TX_ENABLE_G = true) generate
      SaltTx_Inst : entity work.SaltTx
         generic map(
            TPD_G              => TPD_G,
            SLAVE_AXI_CONFIG_G => SLAVE_AXI_CONFIG_G,
            COMMON_TX_CLK_G    => COMMON_TX_CLK_G)
         port map(
            -- TX Serial Stream
            txP         => txP,
            txN         => txN,
            -- Reference Signals
            clk         => clk,
            clk2p5x     => clk2p5x,
            clk5x       => clk5x,
            rst         => rst,
            -- Slave Port
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave);         
   end generate;

   TX_DISABLE : if (TX_ENABLE_G = false) generate
      
      U_OBUFTDS : OBUFTDS
         port map (
            I  => '0',
            T  => '1',
            O  => txP,
            OB => txN);      

      sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   end generate;

   RX_ENABLE : if (RX_ENABLE_G = true) generate
      SaltRx_Inst : entity work.SaltRx
         generic map(
            TPD_G               => TPD_G,
            COMMON_RX_CLK_G     => COMMON_RX_CLK_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G,
            XIL_DEVICE_G        => XIL_DEVICE_G,
            RXCLK5X_FREQ_G      => RXCLK5X_FREQ_G,
            IODELAY_GROUP_G     => IODELAY_GROUP_G)
         port map(
            -- TX Serial Stream
            rxP           => rxP,
            rxN           => rxN,
            -- Reference Signals
            clk           => clk,
            clk2p5x       => clk2p5x,
            clk5x         => clk5x,
            rst           => rst,
            iDelayCtrlRdy => iDelayCtrlRdy,
            -- Master Port
            mAxisClk      => mAxisClk,
            mAxisRst      => mAxisRst,
            mAxisMaster   => mAxisMaster,
            mAxisSlave    => mAxisSlave);               

   end generate;

   RX_DISABLE : if (RX_ENABLE_G = false) generate
      
      mAxisMaster <= AXI_STREAM_MASTER_INIT_C;
      
   end generate;

end mapping;
