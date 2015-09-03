-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT RX Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SaltPkg.all;

entity SaltRx is
   generic (
      TPD_G               : time                := 1 ns;
      COMMON_RX_CLK_G     : boolean             := false;  -- Set to true if mAxisClk and clk are the same clock      
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);
      IODELAY_GROUP_G     : string              := "SALT_IODELAY_GRP";
      RXCLK5X_FREQ_G      : real                := 625.0;  -- In units of MHz
      XIL_DEVICE_G        : string              := "ULTRASCALE");
   port (
      -- RX Serial Stream
      rxP           : in  sl;
      rxN           : in  sl;
      -- Reference Signals
      clk           : in  sl;
      clk2p5x       : in  sl;
      clk5x         : in  sl;
      rst           : in  sl;
      iDelayCtrlRdy : in  sl;
      -- Master Port
      mAxisClk      : in  sl;
      mAxisRst      : in  sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);      
end SaltRx;

architecture mapping of SaltRx is

   constant RXCLK10X_FREQ_C : real    := getRealMult(RXCLK5X_FREQ_G, 2.0);
   constant BIT_TIME_C      : natural := getTimeRatio(1.0E+6, RXCLK10X_FREQ_C);

   component SaltRxSerdes
      generic (
         XIL_DEVICE_G    : string  := "ULTRASCALE";
         IODELAY_GROUP_G : string  := "SALT_IODELAY_GRP";
         REF_FREQ        : real    := 625.0;
         BIT_TIME        : natural := 800);
      port (
         datain_p     : in  sl;
         datain_n     : in  sl;
         rxclk        : in  sl;
         rxclk_div4   : in  sl;
         rxclk_div10  : in  sl;
         idelay_rdy   : in  sl;
         reset        : in  sl;
         rx_data      : out slv(9 downto 0);
         comma        : out sl;
         al_rx_data   : out slv(9 downto 0);
         debug_in     : in  slv(6 downto 0);
         debug        : out slv(45 downto 0);
         dummy_out    : out sl;
         results      : out slv(127 downto 0);
         m_delay_1hot : out slv(127 downto 0));        
   end component;

   signal comma     : sl;
   signal commaDly  : sl;
   signal data10B   : slv(9 downto 0);
   signal data8B    : slv(7 downto 0);
   signal dataK     : sl;
   signal codeErr   : sl;
   signal dispErr   : sl;
   signal rxData8B  : slv(7 downto 0);
   signal rxDataK   : sl;
   signal rxCodeErr : sl;
   signal rxDispErr : sl;
   
begin

   SERDES_Inst : SaltRxSerdes
      generic map (
         XIL_DEVICE_G    => XIL_DEVICE_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         REF_FREQ        => RXCLK5X_FREQ_G,  -- 625 MHz = 1.25 Gbps DDR
         BIT_TIME        => BIT_TIME_C)      -- 800 ps = 1.25 Gbps 
      port map (
         datain_p     => rxP,
         datain_n     => rxN,
         rxclk        => clk5x,              -- 625 MHz
         rxclk_div4   => clk2p5x,            -- 312.5 MHz
         rxclk_div10  => clk,                -- 125 MHz
         idelay_rdy   => iDelayCtrlRdy,
         reset        => rst,
         rx_data      => open,
         comma        => comma,
         al_rx_data   => data10B,
         debug_in     => "0010000",
         debug        => open,
         dummy_out    => open,
         results      => open,
         m_delay_1hot => open); 

   process (clk) is
   begin
      if rising_edge(clk) then
         commaDly <= comma after TPD_G;
      end if;
   end process;

   Decoder8b10b_Inst : entity work.Decoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 1)
      port map (
         clk         => clk,
         rst         => rst,
         dataIn      => data10B,
         dataOut     => data8B,
         dataKOut(0) => dataK,
         codeErr(0)  => codeErr,
         dispErr(0)  => dispErr);   

   rxData8B  <= data8B  when (commaDly = '0') else K_COM_C;
   rxDataK   <= dataK   when (commaDly = '0') else '1';
   rxCodeErr <= codeErr when (commaDly = '0') else '0';
   rxDispErr <= dispErr when (commaDly = '0') else '0';

   SaltRxFifo_Inst : entity work.SaltRxFifo
      generic map (
         TPD_G               => TPD_G,
         COMMON_RX_CLK_G     => COMMON_RX_CLK_G,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
      port map (
         -- RX Parallel Stream
         data8B      => rxData8B,
         dataK       => rxDataK,
         codeErr     => rxCodeErr,
         dispErr     => rxDispErr,
         -- Reference Signals
         clk         => clk,
         rst         => rst,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);   

end mapping;
