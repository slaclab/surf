--------------------------------------------------------------------------------
-- File       : SaltUltraScaleCore_rx_rate_adapt.vhd
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
-- Description: This module accepts receiver data from the Ethernet
--              1000BASE-X PCS/PMA or SGMII LogiCORE. At 1 Gbps, this
--              data will be valid on evey clock cycle of the 125MHz
--              reference clock; at 100Mbps, this data will be repeated
--              for a ten clock period duration of the 125MHz reference
--              clock; at 10Mbps, this data will be repeated for a
--              hundred clock period duration of the 125MHz reference
--              clock.
--
--              The Start of Frame Delimiter (SFD) is also detected, and
--              if required, it is realigned across the 8-bit data path.
--              This module will then sample this correctly aligned data
--              synchronously to the 125MHz reference clock. This data
--              will be held constant for the appropriate number of clock
--              cycles so that it can then be sampled by the client MAC
--              attached at the other end of the GMII-style link.



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



--------------------------------------------------------------------------------
-- The entity declaration
--------------------------------------------------------------------------------

entity SaltUltraScaleCore_rx_rate_adapt is

  port(
    reset               : in std_logic;                     -- Synchronous reset.
    clk125m             : in std_logic;                     -- Reference 125MHz clock.
    sgmii_clk_en        : in std_logic;                     -- Clock enable for the receiver logic on clock falling edge (125MHz, 12.5MHz, 1.25MHz).
    gmii_rxd_in         : in std_logic_vector(7 downto 0);  -- Receive data from client MAC.
    gmii_rx_dv_in       : in std_logic;                     -- Receive data valid signal from client MAC.
    gmii_rx_er_in       : in std_logic;                     -- Receive error signal from client MAC.
    gmii_rxd_out        : out std_logic_vector(7 downto 0) := (others => '0'); -- Receive data from client MAC.
    gmii_rx_dv_out      : out std_logic := '0';                    -- Receive data valid signal from client MAC.
    gmii_rx_er_out      : out std_logic := '0'                     -- Receive error signal from client MAC.
    );

end SaltUltraScaleCore_rx_rate_adapt;



architecture rtl of SaltUltraScaleCore_rx_rate_adapt is


  ------------------------------------------------------------------------------
  -- internal signals used in this wrapper.
  ------------------------------------------------------------------------------

  signal rxd_reg1       : std_logic_vector(7 downto 0);      -- gmii_rxd_in delayed by 1 clock cycle
  signal rxd_reg2       : std_logic_vector(7 downto 0);      -- gmii_rxd_in delayed by 2 clock cycles
  signal rx_dv_reg1     : std_logic;                         -- gmii_rx_dv_in delayed by 1 clock cycle
  signal rx_dv_reg2     : std_logic;                         -- gmii_rx_dv_in delayed by 2 clock cycles
  signal rx_er_reg1     : std_logic;                         -- gmii_rx_er_in delayed by 1 clock cycle
  signal rx_er_reg2     : std_logic;                         -- gmii_rx_er_in delayed by 2 clock cycles
  signal sfd_aligned    : std_logic;                         -- 0xD5 (The Start of Frame Delimiter (SFD) ) has been detected on a single 8-bit code group
  signal sfd_misaligned : std_logic;                         -- 0xD5 (SFD) has been detected across two 8-bit code groups
  signal sfd_enable     : std_logic;                         -- Enable the detection of the SFD at the start of a new frame
  signal muxsel         : std_logic;                         -- Used to control the 8-bit SFD based alignment
  signal rxd_aligned    : std_logic_vector(7 downto 0);      -- gmii_rxd_in aligned
  signal rx_dv_aligned  : std_logic;                         -- gmii_rx_dv_in aligned
  signal rx_er_aligned  : std_logic;                         -- gmii_rx_er_in aligned



begin



  -- Create a pipeline for the gmii receiver signals
  gmii_reg_gen: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        rxd_reg1   <= (others => '0');
        rxd_reg2   <= (others => '0');
        rx_dv_reg1 <= '0';
        rx_dv_reg2 <= '0';
        rx_er_reg1 <= '0';
        rx_er_reg2 <= '0';
      elsif sgmii_clk_en = '1' then
        rxd_reg1   <= gmii_rxd_in;
        rxd_reg2   <= rxd_reg1;
        rx_dv_reg1 <= gmii_rx_dv_in;
        rx_dv_reg2 <= rx_dv_reg1;
        rx_er_reg1 <= gmii_rx_er_in;
        rx_er_reg2 <= rx_er_reg1;
      end if;
    end if;
  end process gmii_reg_gen;



  -- Detect the SDF code across a single 8-bit data code group
  sfd_aligned    <= '1' when rxd_reg1 = "11010101" else '0';



  -- Detect the SDF code across two 8-bit data code groups
  sfd_misaligned <= '1' when (gmii_rxd_in(3 downto 0) = "1101" and
                              rxd_reg1(7 downto 4) = "0101") else '0';



  -- only the 1st 0xD5 at the start of the frame is the genuine SFD (the
  -- value 0xD5 may follow later in the frame data).  Therefore it is
  -- important to only use the first 0xD5 code for alignment.
  -- sfd_enable is therefore created to enable the SFD based alignment.
  -- sfd_enable is asserted at the beginning of every frame and is
  -- unasserted after the detection of the first 0xD5 code.
  sfd_enable_gen: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        sfd_enable <= '0';
      elsif sgmii_clk_en = '1' then
        if gmii_rx_dv_in = '1' and rx_dv_reg1 = '0' then   -- assert at the start of the frame (signified by the rising edge of gmii_rx_dv_in)
          sfd_enable <= '1';
      elsif (sfd_aligned or sfd_misaligned) = '1' then   -- unassert after detecting the 1st 0xD5 value
          sfd_enable <= '0';
        end if;
      end if;
    end if;
  end process sfd_enable_gen;



  -- Create a multiplexer control signals which is used to control the
  -- alignment of the frame across the 8-bit data path
  muxsel_gen: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        muxsel     <= '0';
      elsif sgmii_clk_en = '1' then
        if (sfd_aligned and sfd_enable) = '1' then         -- muxsel is realigned at the start of each frame based on the alignment of the SFD
          muxsel <= '0';
        elsif (sfd_misaligned and sfd_enable) = '1' then
          muxsel <= '1';
        end if;
      end if;
    end if;
  end process muxsel_gen;




  -- Realign the receiver data across the 8-bit data path based on the
  -- alignment of the SFD.
  gmii_realign: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        rxd_aligned   <= (others => '0');
        rx_dv_aligned <= '0';
        rx_er_aligned <= '0';
      elsif sgmii_clk_en = '1' then
        if muxsel = '0' then
          rxd_aligned   <= rxd_reg2;                                    -- preserve alignment
          rx_dv_aligned <= rx_dv_reg2;
          rx_er_aligned <= rx_er_reg2;
        else
          rxd_aligned   <= rxd_reg1(3 downto 0) & rxd_reg2(7 downto 4); -- correct the alignment
          rx_dv_aligned <= rx_dv_reg1 and rx_dv_reg2;
          rx_er_aligned <= rx_er_reg1 or rx_er_reg2;
        end if;
      end if;
    end if;
  end process gmii_realign;



  -- Sample the correctly aligned data
  sample_gmii_rx: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        gmii_rxd_out   <= (others => '0');
        gmii_rx_dv_out <= '0';
        gmii_rx_er_out <= '0';
      elsif sgmii_clk_en = '1' then
         gmii_rxd_out   <= rxd_aligned;
         gmii_rx_dv_out <= rx_dv_aligned;
         gmii_rx_er_out <= rx_er_aligned;
      end if;
    end if;
  end process sample_gmii_rx;




end rtl;

