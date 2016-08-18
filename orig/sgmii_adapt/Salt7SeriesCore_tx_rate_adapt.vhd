--------------------------------------------------------------------------------
-- File       : Salt7SeriesCore_tx_rate_adapt.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2004-2008 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
-- 
-- 
--------------------------------------------------------------------------------
-- Description: This module accepts transmitter data from the GMII style
--              interface from the attached client MAC.  At 1 Gbps, this
--              GMII transmitter data will be valid on evey clock cycle
--              of the 125MHz reference clock; at 100Mbps, this data
--              will be repeated for a ten clock period duration of the
--              125MHz reference clock; at 10Mbps, this data will be
--              repeated for a hundred clock period duration of the
--              125MHz reference clock.
--
--              This module will sample the input transmitter GMII data
--              synchronously to the 125MHz reference clock.  This
--              sampled data can then be connected direcly to the input
--              GMII- style interface of the Ethernet 1000BASE-X PCS/PMA
--              or SGMII LogiCORE.



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;



entity Salt7SeriesCore_tx_rate_adapt is

  port(
    reset               : in std_logic;                     -- Synchronous reset.
    clk125m             : in std_logic;                     -- Reference 125MHz transmitter clock.
    sgmii_clk_en        : in std_logic;                     -- Clock enable pulse for the transmitter logic on clock falling edge (125MHz, 12.5MHz, 1.25MHz).
    gmii_txd_in         : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
    gmii_tx_en_in       : in std_logic;                     -- Transmit data valid signal from client MAC.
    gmii_tx_er_in       : in std_logic;                     -- Transmit error signal from client MAC.
    gmii_txd_out        : out std_logic_vector(7 downto 0) := (others => '0'); -- Transmit data from client MAC.
    gmii_tx_en_out      : out std_logic := '0';                    -- Transmit data valid signal from client MAC.
    gmii_tx_er_out      : out std_logic := '0'                     -- Transmit error signal from client MAC.
    );

end Salt7SeriesCore_tx_rate_adapt;



architecture rtl of Salt7SeriesCore_tx_rate_adapt is



begin



  -- At 1Gbps speeds, sgmii_clk_en is permantly tied to logic 1
  -- and the input data will be sampled on every clock cycle.  At 10Mbs
  -- and 100Mbps speeds, sgmii_clk_en will be at logic 1 only only one clock
  -- cycle in ten, or one clock cycle in a hundred, respectively.

  -- The sampled output GMII transmitter data is sent directly into the
  -- 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE synchronously to the
  -- 125MHz reference clock.

  sample_gmii_tx: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        gmii_txd_out   <= (others => '0');
        gmii_tx_en_out <= '0';
        gmii_tx_er_out <= '0';
      elsif sgmii_clk_en = '1' then
        gmii_txd_out   <= gmii_txd_in;
        gmii_tx_en_out <= gmii_tx_en_in;
        gmii_tx_er_out <= gmii_tx_er_in;
      end if;
    end if;
  end process sample_gmii_tx;



end rtl;

