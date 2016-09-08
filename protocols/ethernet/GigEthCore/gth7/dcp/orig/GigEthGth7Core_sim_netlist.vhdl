-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.3 (lin64) Build 1368829 Mon Sep 28 20:06:39 MDT 2015
-- Date        : Tue Feb  9 14:39:29 2016
-- Host        : rdusr217.slac.stanford.edu running 64-bit Red Hat Enterprise Linux Server release 6.7 (Santiago)
-- Command     : write_vhdl -force -mode funcsim
--               /u1/ruckman/build/GigEthGth7Dcp/GigEthGth7Dcp_project.srcs/sources_1/ip/GigEthGth7Core/GigEthGth7Core_sim_netlist.vhdl
-- Design      : GigEthGth7Core
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7vx690tffg1761-3
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_cpll_railing is
  port (
    cpll_pd_out : out STD_LOGIC;
    cpllreset_in : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_cpll_railing : entity is "GigEthGth7Core_cpll_railing";
end GigEthGth7Core_GigEthGth7Core_cpll_railing;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_cpll_railing is
  signal cpll_reset_out : STD_LOGIC;
  signal \cpllpd_wait_reg[31]_srl32_n_1\ : STD_LOGIC;
  signal \cpllpd_wait_reg[63]_srl32_n_1\ : STD_LOGIC;
  signal \cpllpd_wait_reg[94]_srl31_n_0\ : STD_LOGIC;
  signal \cpllreset_wait_reg[126]_srl31_n_0\ : STD_LOGIC;
  signal \cpllreset_wait_reg[31]_srl32_n_1\ : STD_LOGIC;
  signal \cpllreset_wait_reg[63]_srl32_n_1\ : STD_LOGIC;
  signal \cpllreset_wait_reg[95]_srl32_n_1\ : STD_LOGIC;
  signal \NLW_cpllpd_wait_reg[31]_srl32_Q_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllpd_wait_reg[63]_srl32_Q_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllpd_wait_reg[94]_srl31_Q31_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllreset_wait_reg[126]_srl31_Q31_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllreset_wait_reg[31]_srl32_Q_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllreset_wait_reg[63]_srl32_Q_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_cpllreset_wait_reg[95]_srl32_Q_UNCONNECTED\ : STD_LOGIC;
  attribute srl_bus_name : string;
  attribute srl_bus_name of \cpllpd_wait_reg[31]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg ";
  attribute srl_name : string;
  attribute srl_name of \cpllpd_wait_reg[31]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[31]_srl32 ";
  attribute srl_bus_name of \cpllpd_wait_reg[63]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg ";
  attribute srl_name of \cpllpd_wait_reg[63]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[63]_srl32 ";
  attribute srl_bus_name of \cpllpd_wait_reg[94]_srl31\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg ";
  attribute srl_name of \cpllpd_wait_reg[94]_srl31\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[94]_srl31 ";
  attribute equivalent_register_removal : string;
  attribute equivalent_register_removal of \cpllpd_wait_reg[95]\ : label is "no";
  attribute srl_bus_name of \cpllreset_wait_reg[126]_srl31\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg ";
  attribute srl_name of \cpllreset_wait_reg[126]_srl31\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[126]_srl31 ";
  attribute equivalent_register_removal of \cpllreset_wait_reg[127]\ : label is "no";
  attribute srl_bus_name of \cpllreset_wait_reg[31]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg ";
  attribute srl_name of \cpllreset_wait_reg[31]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[31]_srl32 ";
  attribute srl_bus_name of \cpllreset_wait_reg[63]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg ";
  attribute srl_name of \cpllreset_wait_reg[63]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[63]_srl32 ";
  attribute srl_bus_name of \cpllreset_wait_reg[95]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg ";
  attribute srl_name of \cpllreset_wait_reg[95]_srl32\ : label is "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[95]_srl32 ";
begin
\cpllpd_wait_reg[31]_srl32\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"FFFFFFFF"
    )
        port map (
      A(4 downto 0) => B"11111",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => '0',
      Q => \NLW_cpllpd_wait_reg[31]_srl32_Q_UNCONNECTED\,
      Q31 => \cpllpd_wait_reg[31]_srl32_n_1\
    );
\cpllpd_wait_reg[63]_srl32\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"FFFFFFFF"
    )
        port map (
      A(4 downto 0) => B"11111",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => \cpllpd_wait_reg[31]_srl32_n_1\,
      Q => \NLW_cpllpd_wait_reg[63]_srl32_Q_UNCONNECTED\,
      Q31 => \cpllpd_wait_reg[63]_srl32_n_1\
    );
\cpllpd_wait_reg[94]_srl31\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"7FFFFFFF"
    )
        port map (
      A(4 downto 0) => B"11110",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => \cpllpd_wait_reg[63]_srl32_n_1\,
      Q => \cpllpd_wait_reg[94]_srl31_n_0\,
      Q31 => \NLW_cpllpd_wait_reg[94]_srl31_Q31_UNCONNECTED\
    );
\cpllpd_wait_reg[95]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => \cpllpd_wait_reg[94]_srl31_n_0\,
      Q => cpll_pd_out,
      R => '0'
    );
\cpllreset_wait_reg[126]_srl31\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"00000000"
    )
        port map (
      A(4 downto 0) => B"11110",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => \cpllreset_wait_reg[95]_srl32_n_1\,
      Q => \cpllreset_wait_reg[126]_srl31_n_0\,
      Q31 => \NLW_cpllreset_wait_reg[126]_srl31_Q31_UNCONNECTED\
    );
\cpllreset_wait_reg[127]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => \cpllreset_wait_reg[126]_srl31_n_0\,
      Q => cpll_reset_out,
      R => '0'
    );
\cpllreset_wait_reg[31]_srl32\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"000000FF"
    )
        port map (
      A(4 downto 0) => B"11111",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => '0',
      Q => \NLW_cpllreset_wait_reg[31]_srl32_Q_UNCONNECTED\,
      Q31 => \cpllreset_wait_reg[31]_srl32_n_1\
    );
\cpllreset_wait_reg[63]_srl32\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"00000000"
    )
        port map (
      A(4 downto 0) => B"11111",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => \cpllreset_wait_reg[31]_srl32_n_1\,
      Q => \NLW_cpllreset_wait_reg[63]_srl32_Q_UNCONNECTED\,
      Q31 => \cpllreset_wait_reg[63]_srl32_n_1\
    );
\cpllreset_wait_reg[95]_srl32\: unisim.vcomponents.SRLC32E
    generic map(
      INIT => X"00000000"
    )
        port map (
      A(4 downto 0) => B"11111",
      CE => '1',
      CLK => gtrefclk_bufg,
      D => \cpllreset_wait_reg[63]_srl32_n_1\,
      Q => \NLW_cpllreset_wait_reg[95]_srl32_Q_UNCONNECTED\,
      Q31 => \cpllreset_wait_reg[95]_srl32_n_1\
    );
gthe2_i_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => cpll_reset_out,
      I1 => CPLL_RESET,
      O => cpllreset_in
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_sync is
  port (
    reset_out : out STD_LOGIC;
    userclk : in STD_LOGIC;
    encommaalign : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_sync : entity is "GigEthGth7Core_reset_sync";
end GigEthGth7Core_GigEthGth7Core_reset_sync;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_sync is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => '0',
      PRE => encommaalign,
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg1,
      PRE => encommaalign,
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg2,
      PRE => encommaalign,
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg3,
      PRE => encommaalign,
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg4,
      PRE => encommaalign,
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_sync_1 is
  port (
    reset_out : out STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\ : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_sync_1 : entity is "GigEthGth7Core_reset_sync";
end GigEthGth7Core_GigEthGth7Core_reset_sync_1;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_sync_1 is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => '0',
      PRE => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg1,
      PRE => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg2,
      PRE => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg3,
      PRE => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg4,
      PRE => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_sync_2 is
  port (
    reset_out : out STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_sync_2 : entity is "GigEthGth7Core_reset_sync";
end GigEthGth7Core_GigEthGth7Core_reset_sync_2;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_sync_2 is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => '0',
      PRE => SR(0),
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg1,
      PRE => SR(0),
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg2,
      PRE => SR(0),
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg3,
      PRE => SR(0),
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg4,
      PRE => SR(0),
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_sync_5 is
  port (
    reset_out : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_sync_5 : entity is "GigEthGth7Core_reset_sync";
end GigEthGth7Core_GigEthGth7Core_reset_sync_5;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_sync_5 is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => '0',
      PRE => SR(0),
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg1,
      PRE => SR(0),
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg2,
      PRE => SR(0),
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg3,
      PRE => SR(0),
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg4,
      PRE => SR(0),
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_sync_6 is
  port (
    reset_out : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_sync_6 : entity is "GigEthGth7Core_reset_sync";
end GigEthGth7Core_GigEthGth7Core_reset_sync_6;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_sync_6 is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => '0',
      PRE => CPLL_RESET,
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg1,
      PRE => CPLL_RESET,
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg2,
      PRE => CPLL_RESET,
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg3,
      PRE => CPLL_RESET,
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg4,
      PRE => CPLL_RESET,
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity \GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7\ is
  port (
    reset_out : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of \GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7\ : entity is "GigEthGth7Core_reset_sync";
end \GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7\;

architecture STRUCTURE of \GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7\ is
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => '0',
      PRE => CPLL_RESET,
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg1,
      PRE => CPLL_RESET,
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg2,
      PRE => CPLL_RESET,
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg3,
      PRE => CPLL_RESET,
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg4,
      PRE => CPLL_RESET,
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_reset_wtd_timer is
  port (
    reset : out STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    data_out : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_reset_wtd_timer : entity is "GigEthGth7Core_reset_wtd_timer";
end GigEthGth7Core_GigEthGth7Core_reset_wtd_timer;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_reset_wtd_timer is
  signal \counter_stg1[5]_i_1_n_0\ : STD_LOGIC;
  signal \counter_stg1_reg__0\ : STD_LOGIC_VECTOR ( 5 to 5 );
  signal \counter_stg1_reg__1\ : STD_LOGIC_VECTOR ( 4 downto 0 );
  signal \counter_stg2[0]_i_1_n_0\ : STD_LOGIC;
  signal \counter_stg2[0]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg2[0]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg2[0]_i_5_n_0\ : STD_LOGIC;
  signal \counter_stg2[0]_i_6_n_0\ : STD_LOGIC;
  signal \counter_stg2[4]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg2[4]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg2[4]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg2[4]_i_5_n_0\ : STD_LOGIC;
  signal \counter_stg2[8]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg2[8]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg2[8]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg2[8]_i_5_n_0\ : STD_LOGIC;
  signal counter_stg2_reg : STD_LOGIC_VECTOR ( 11 downto 0 );
  signal \counter_stg2_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \counter_stg2_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \counter_stg2_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \counter_stg2_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal counter_stg30 : STD_LOGIC;
  signal \counter_stg3[0]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_5_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_6_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_7_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_8_n_0\ : STD_LOGIC;
  signal \counter_stg3[0]_i_9_n_0\ : STD_LOGIC;
  signal \counter_stg3[4]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg3[4]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg3[4]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg3[4]_i_5_n_0\ : STD_LOGIC;
  signal \counter_stg3[8]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg3[8]_i_3_n_0\ : STD_LOGIC;
  signal \counter_stg3[8]_i_4_n_0\ : STD_LOGIC;
  signal \counter_stg3[8]_i_5_n_0\ : STD_LOGIC;
  signal counter_stg3_reg : STD_LOGIC_VECTOR ( 11 downto 0 );
  signal \counter_stg3_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \counter_stg3_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \counter_stg3_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \counter_stg3_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal plusOp : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal reset0 : STD_LOGIC;
  signal reset_i_2_n_0 : STD_LOGIC;
  signal reset_i_3_n_0 : STD_LOGIC;
  signal reset_i_4_n_0 : STD_LOGIC;
  signal reset_i_5_n_0 : STD_LOGIC;
  signal reset_i_6_n_0 : STD_LOGIC;
  signal reset_i_7_n_0 : STD_LOGIC;
  signal reset_i_8_n_0 : STD_LOGIC;
  signal \NLW_counter_stg2_reg[8]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_counter_stg3_reg[8]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \counter_stg1[0]_i_1\ : label is "soft_lutpair69";
  attribute SOFT_HLUTNM of \counter_stg1[1]_i_1\ : label is "soft_lutpair69";
  attribute SOFT_HLUTNM of \counter_stg1[2]_i_1\ : label is "soft_lutpair67";
  attribute SOFT_HLUTNM of \counter_stg1[3]_i_1\ : label is "soft_lutpair67";
  attribute SOFT_HLUTNM of \counter_stg1[4]_i_1\ : label is "soft_lutpair66";
  attribute SOFT_HLUTNM of \counter_stg3[0]_i_4\ : label is "soft_lutpair68";
  attribute SOFT_HLUTNM of \counter_stg3[0]_i_5\ : label is "soft_lutpair66";
  attribute SOFT_HLUTNM of reset_i_5 : label is "soft_lutpair68";
begin
\counter_stg1[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \counter_stg1_reg__1\(0),
      O => plusOp(0)
    );
\counter_stg1[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => \counter_stg1_reg__1\(0),
      I1 => \counter_stg1_reg__1\(1),
      O => plusOp(1)
    );
\counter_stg1[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"6A"
    )
        port map (
      I0 => \counter_stg1_reg__1\(2),
      I1 => \counter_stg1_reg__1\(1),
      I2 => \counter_stg1_reg__1\(0),
      O => plusOp(2)
    );
\counter_stg1[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"6AAA"
    )
        port map (
      I0 => \counter_stg1_reg__1\(3),
      I1 => \counter_stg1_reg__1\(0),
      I2 => \counter_stg1_reg__1\(1),
      I3 => \counter_stg1_reg__1\(2),
      O => plusOp(3)
    );
\counter_stg1[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"7FFF8000"
    )
        port map (
      I0 => \counter_stg1_reg__1\(2),
      I1 => \counter_stg1_reg__1\(1),
      I2 => \counter_stg1_reg__1\(0),
      I3 => \counter_stg1_reg__1\(3),
      I4 => \counter_stg1_reg__1\(4),
      O => plusOp(4)
    );
\counter_stg1[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F4"
    )
        port map (
      I0 => reset_i_2_n_0,
      I1 => \counter_stg2[0]_i_1_n_0\,
      I2 => data_out,
      O => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1[5]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFF80000000"
    )
        port map (
      I0 => \counter_stg1_reg__1\(4),
      I1 => \counter_stg1_reg__1\(3),
      I2 => \counter_stg1_reg__1\(0),
      I3 => \counter_stg1_reg__1\(1),
      I4 => \counter_stg1_reg__1\(2),
      I5 => \counter_stg1_reg__0\(5),
      O => plusOp(5)
    );
\counter_stg1_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(0),
      Q => \counter_stg1_reg__1\(0),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(1),
      Q => \counter_stg1_reg__1\(1),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(2),
      Q => \counter_stg1_reg__1\(2),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(3),
      Q => \counter_stg1_reg__1\(3),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(4),
      Q => \counter_stg1_reg__1\(4),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg1_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => plusOp(5),
      Q => \counter_stg1_reg__0\(5),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8000000000000000"
    )
        port map (
      I0 => \counter_stg1_reg__0\(5),
      I1 => \counter_stg1_reg__1\(4),
      I2 => \counter_stg1_reg__1\(3),
      I3 => \counter_stg1_reg__1\(0),
      I4 => \counter_stg1_reg__1\(1),
      I5 => \counter_stg1_reg__1\(2),
      O => \counter_stg2[0]_i_1_n_0\
    );
\counter_stg2[0]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(3),
      O => \counter_stg2[0]_i_3_n_0\
    );
\counter_stg2[0]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(2),
      O => \counter_stg2[0]_i_4_n_0\
    );
\counter_stg2[0]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(1),
      O => \counter_stg2[0]_i_5_n_0\
    );
\counter_stg2[0]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => counter_stg2_reg(0),
      O => \counter_stg2[0]_i_6_n_0\
    );
\counter_stg2[4]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(7),
      O => \counter_stg2[4]_i_2_n_0\
    );
\counter_stg2[4]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(6),
      O => \counter_stg2[4]_i_3_n_0\
    );
\counter_stg2[4]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(5),
      O => \counter_stg2[4]_i_4_n_0\
    );
\counter_stg2[4]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(4),
      O => \counter_stg2[4]_i_5_n_0\
    );
\counter_stg2[8]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(11),
      O => \counter_stg2[8]_i_2_n_0\
    );
\counter_stg2[8]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(10),
      O => \counter_stg2[8]_i_3_n_0\
    );
\counter_stg2[8]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(9),
      O => \counter_stg2[8]_i_4_n_0\
    );
\counter_stg2[8]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg2_reg(8),
      O => \counter_stg2[8]_i_5_n_0\
    );
\counter_stg2_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[0]_i_2_n_7\,
      Q => counter_stg2_reg(0),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \counter_stg2_reg[0]_i_2_n_0\,
      CO(2) => \counter_stg2_reg[0]_i_2_n_1\,
      CO(1) => \counter_stg2_reg[0]_i_2_n_2\,
      CO(0) => \counter_stg2_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \counter_stg2_reg[0]_i_2_n_4\,
      O(2) => \counter_stg2_reg[0]_i_2_n_5\,
      O(1) => \counter_stg2_reg[0]_i_2_n_6\,
      O(0) => \counter_stg2_reg[0]_i_2_n_7\,
      S(3) => \counter_stg2[0]_i_3_n_0\,
      S(2) => \counter_stg2[0]_i_4_n_0\,
      S(1) => \counter_stg2[0]_i_5_n_0\,
      S(0) => \counter_stg2[0]_i_6_n_0\
    );
\counter_stg2_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[8]_i_1_n_5\,
      Q => counter_stg2_reg(10),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[8]_i_1_n_4\,
      Q => counter_stg2_reg(11),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[0]_i_2_n_6\,
      Q => counter_stg2_reg(1),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[0]_i_2_n_5\,
      Q => counter_stg2_reg(2),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[0]_i_2_n_4\,
      Q => counter_stg2_reg(3),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[4]_i_1_n_7\,
      Q => counter_stg2_reg(4),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \counter_stg2_reg[0]_i_2_n_0\,
      CO(3) => \counter_stg2_reg[4]_i_1_n_0\,
      CO(2) => \counter_stg2_reg[4]_i_1_n_1\,
      CO(1) => \counter_stg2_reg[4]_i_1_n_2\,
      CO(0) => \counter_stg2_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \counter_stg2_reg[4]_i_1_n_4\,
      O(2) => \counter_stg2_reg[4]_i_1_n_5\,
      O(1) => \counter_stg2_reg[4]_i_1_n_6\,
      O(0) => \counter_stg2_reg[4]_i_1_n_7\,
      S(3) => \counter_stg2[4]_i_2_n_0\,
      S(2) => \counter_stg2[4]_i_3_n_0\,
      S(1) => \counter_stg2[4]_i_4_n_0\,
      S(0) => \counter_stg2[4]_i_5_n_0\
    );
\counter_stg2_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[4]_i_1_n_6\,
      Q => counter_stg2_reg(5),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[4]_i_1_n_5\,
      Q => counter_stg2_reg(6),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[4]_i_1_n_4\,
      Q => counter_stg2_reg(7),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[8]_i_1_n_7\,
      Q => counter_stg2_reg(8),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg2_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \counter_stg2_reg[4]_i_1_n_0\,
      CO(3) => \NLW_counter_stg2_reg[8]_i_1_CO_UNCONNECTED\(3),
      CO(2) => \counter_stg2_reg[8]_i_1_n_1\,
      CO(1) => \counter_stg2_reg[8]_i_1_n_2\,
      CO(0) => \counter_stg2_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \counter_stg2_reg[8]_i_1_n_4\,
      O(2) => \counter_stg2_reg[8]_i_1_n_5\,
      O(1) => \counter_stg2_reg[8]_i_1_n_6\,
      O(0) => \counter_stg2_reg[8]_i_1_n_7\,
      S(3) => \counter_stg2[8]_i_2_n_0\,
      S(2) => \counter_stg2[8]_i_3_n_0\,
      S(1) => \counter_stg2[8]_i_4_n_0\,
      S(0) => \counter_stg2[8]_i_5_n_0\
    );
\counter_stg2_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \counter_stg2[0]_i_1_n_0\,
      D => \counter_stg2_reg[8]_i_1_n_6\,
      Q => counter_stg2_reg(9),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000080000000"
    )
        port map (
      I0 => \counter_stg3[0]_i_3_n_0\,
      I1 => \counter_stg1_reg__0\(5),
      I2 => counter_stg2_reg(0),
      I3 => counter_stg2_reg(1),
      I4 => \counter_stg3[0]_i_4_n_0\,
      I5 => \counter_stg3[0]_i_5_n_0\,
      O => counter_stg30
    );
\counter_stg3[0]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8000000000000000"
    )
        port map (
      I0 => counter_stg2_reg(6),
      I1 => counter_stg2_reg(7),
      I2 => counter_stg2_reg(8),
      I3 => counter_stg2_reg(9),
      I4 => counter_stg2_reg(11),
      I5 => counter_stg2_reg(10),
      O => \counter_stg3[0]_i_3_n_0\
    );
\counter_stg3[0]_i_4\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"8000"
    )
        port map (
      I0 => counter_stg2_reg(5),
      I1 => counter_stg2_reg(4),
      I2 => counter_stg2_reg(3),
      I3 => counter_stg2_reg(2),
      O => \counter_stg3[0]_i_4_n_0\
    );
\counter_stg3[0]_i_5\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"7FFFFFFF"
    )
        port map (
      I0 => \counter_stg1_reg__1\(2),
      I1 => \counter_stg1_reg__1\(1),
      I2 => \counter_stg1_reg__1\(0),
      I3 => \counter_stg1_reg__1\(3),
      I4 => \counter_stg1_reg__1\(4),
      O => \counter_stg3[0]_i_5_n_0\
    );
\counter_stg3[0]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(3),
      O => \counter_stg3[0]_i_6_n_0\
    );
\counter_stg3[0]_i_7\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(2),
      O => \counter_stg3[0]_i_7_n_0\
    );
\counter_stg3[0]_i_8\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(1),
      O => \counter_stg3[0]_i_8_n_0\
    );
\counter_stg3[0]_i_9\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => counter_stg3_reg(0),
      O => \counter_stg3[0]_i_9_n_0\
    );
\counter_stg3[4]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(7),
      O => \counter_stg3[4]_i_2_n_0\
    );
\counter_stg3[4]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(6),
      O => \counter_stg3[4]_i_3_n_0\
    );
\counter_stg3[4]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(5),
      O => \counter_stg3[4]_i_4_n_0\
    );
\counter_stg3[4]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(4),
      O => \counter_stg3[4]_i_5_n_0\
    );
\counter_stg3[8]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(11),
      O => \counter_stg3[8]_i_2_n_0\
    );
\counter_stg3[8]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(10),
      O => \counter_stg3[8]_i_3_n_0\
    );
\counter_stg3[8]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(9),
      O => \counter_stg3[8]_i_4_n_0\
    );
\counter_stg3[8]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => counter_stg3_reg(8),
      O => \counter_stg3[8]_i_5_n_0\
    );
\counter_stg3_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[0]_i_2_n_7\,
      Q => counter_stg3_reg(0),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \counter_stg3_reg[0]_i_2_n_0\,
      CO(2) => \counter_stg3_reg[0]_i_2_n_1\,
      CO(1) => \counter_stg3_reg[0]_i_2_n_2\,
      CO(0) => \counter_stg3_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \counter_stg3_reg[0]_i_2_n_4\,
      O(2) => \counter_stg3_reg[0]_i_2_n_5\,
      O(1) => \counter_stg3_reg[0]_i_2_n_6\,
      O(0) => \counter_stg3_reg[0]_i_2_n_7\,
      S(3) => \counter_stg3[0]_i_6_n_0\,
      S(2) => \counter_stg3[0]_i_7_n_0\,
      S(1) => \counter_stg3[0]_i_8_n_0\,
      S(0) => \counter_stg3[0]_i_9_n_0\
    );
\counter_stg3_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[8]_i_1_n_5\,
      Q => counter_stg3_reg(10),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[8]_i_1_n_4\,
      Q => counter_stg3_reg(11),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[0]_i_2_n_6\,
      Q => counter_stg3_reg(1),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[0]_i_2_n_5\,
      Q => counter_stg3_reg(2),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[0]_i_2_n_4\,
      Q => counter_stg3_reg(3),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[4]_i_1_n_7\,
      Q => counter_stg3_reg(4),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \counter_stg3_reg[0]_i_2_n_0\,
      CO(3) => \counter_stg3_reg[4]_i_1_n_0\,
      CO(2) => \counter_stg3_reg[4]_i_1_n_1\,
      CO(1) => \counter_stg3_reg[4]_i_1_n_2\,
      CO(0) => \counter_stg3_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \counter_stg3_reg[4]_i_1_n_4\,
      O(2) => \counter_stg3_reg[4]_i_1_n_5\,
      O(1) => \counter_stg3_reg[4]_i_1_n_6\,
      O(0) => \counter_stg3_reg[4]_i_1_n_7\,
      S(3) => \counter_stg3[4]_i_2_n_0\,
      S(2) => \counter_stg3[4]_i_3_n_0\,
      S(1) => \counter_stg3[4]_i_4_n_0\,
      S(0) => \counter_stg3[4]_i_5_n_0\
    );
\counter_stg3_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[4]_i_1_n_6\,
      Q => counter_stg3_reg(5),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[4]_i_1_n_5\,
      Q => counter_stg3_reg(6),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[4]_i_1_n_4\,
      Q => counter_stg3_reg(7),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[8]_i_1_n_7\,
      Q => counter_stg3_reg(8),
      R => \counter_stg1[5]_i_1_n_0\
    );
\counter_stg3_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \counter_stg3_reg[4]_i_1_n_0\,
      CO(3) => \NLW_counter_stg3_reg[8]_i_1_CO_UNCONNECTED\(3),
      CO(2) => \counter_stg3_reg[8]_i_1_n_1\,
      CO(1) => \counter_stg3_reg[8]_i_1_n_2\,
      CO(0) => \counter_stg3_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \counter_stg3_reg[8]_i_1_n_4\,
      O(2) => \counter_stg3_reg[8]_i_1_n_5\,
      O(1) => \counter_stg3_reg[8]_i_1_n_6\,
      O(0) => \counter_stg3_reg[8]_i_1_n_7\,
      S(3) => \counter_stg3[8]_i_2_n_0\,
      S(2) => \counter_stg3[8]_i_3_n_0\,
      S(1) => \counter_stg3[8]_i_4_n_0\,
      S(0) => \counter_stg3[8]_i_5_n_0\
    );
\counter_stg3_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => counter_stg30,
      D => \counter_stg3_reg[8]_i_1_n_6\,
      Q => counter_stg3_reg(9),
      R => \counter_stg1[5]_i_1_n_0\
    );
reset_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \counter_stg1_reg__0\(5),
      I1 => reset_i_2_n_0,
      O => reset0
    );
reset_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFFFFFE"
    )
        port map (
      I0 => reset_i_3_n_0,
      I1 => reset_i_4_n_0,
      I2 => reset_i_5_n_0,
      I3 => reset_i_6_n_0,
      I4 => reset_i_7_n_0,
      I5 => reset_i_8_n_0,
      O => reset_i_2_n_0
    );
reset_i_3: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFF7"
    )
        port map (
      I0 => counter_stg3_reg(4),
      I1 => counter_stg3_reg(11),
      I2 => counter_stg3_reg(9),
      I3 => counter_stg2_reg(2),
      O => reset_i_3_n_0
    );
reset_i_4: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFF7FFFFFFFFFFFF"
    )
        port map (
      I0 => counter_stg2_reg(4),
      I1 => counter_stg2_reg(8),
      I2 => counter_stg3_reg(0),
      I3 => counter_stg2_reg(7),
      I4 => counter_stg3_reg(5),
      I5 => counter_stg2_reg(10),
      O => reset_i_4_n_0
    );
reset_i_5: unisim.vcomponents.LUT2
    generic map(
      INIT => X"7"
    )
        port map (
      I0 => counter_stg2_reg(3),
      I1 => counter_stg2_reg(11),
      O => reset_i_5_n_0
    );
reset_i_6: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => counter_stg2_reg(1),
      I1 => counter_stg2_reg(0),
      I2 => counter_stg3_reg(2),
      I3 => counter_stg3_reg(8),
      O => reset_i_6_n_0
    );
reset_i_7: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFDF"
    )
        port map (
      I0 => counter_stg3_reg(7),
      I1 => counter_stg3_reg(3),
      I2 => counter_stg3_reg(6),
      I3 => counter_stg3_reg(10),
      O => reset_i_7_n_0
    );
reset_i_8: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => counter_stg2_reg(9),
      I1 => counter_stg2_reg(5),
      I2 => counter_stg3_reg(1),
      I3 => counter_stg2_reg(6),
      O => reset_i_8_n_0
    );
reset_reg: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => '1',
      D => reset0,
      Q => reset,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk2 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_0 is
  port (
    resetdone : out STD_LOGIC;
    data_out : in STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk2 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_0 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_0;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_0 is
  signal data_out0_in : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync5,
      Q => data_out0_in,
      R => '0'
    );
resetdone_INST_0: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => data_out0_in,
      I1 => data_out,
      O => resetdone
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_10 is
  port (
    SR : out STD_LOGIC_VECTOR ( 0 to 0 );
    mmcm_lock_reclocked_reg : out STD_LOGIC;
    mmcm_lock_reclocked : in STD_LOGIC;
    Q : in STD_LOGIC_VECTOR ( 2 downto 0 );
    \mmcm_lock_count_reg[4]\ : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_10 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_10;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_10 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  signal mmcm_lock_i : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => mmcm_locked,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => mmcm_lock_i,
      R => '0'
    );
\mmcm_lock_count[7]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => mmcm_lock_i,
      O => SR(0)
    );
mmcm_lock_reclocked_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"EAAAAAAA00000000"
    )
        port map (
      I0 => mmcm_lock_reclocked,
      I1 => Q(2),
      I2 => Q(1),
      I3 => Q(0),
      I4 => \mmcm_lock_count_reg[4]\,
      I5 => mmcm_lock_i,
      O => mmcm_lock_reclocked_reg
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_11 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_11 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_11;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_11 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_12 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_12 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_12;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_12 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_13 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_13 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_13;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_13 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_14 is
  port (
    data_out : out STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_14 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_14;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_14 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \cpllpd_wait_reg[95]\,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_15 is
  port (
    E : out STD_LOGIC_VECTOR ( 0 to 0 );
    data_out : out STD_LOGIC;
    init_wait_done_reg : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
    \FSM_sequential_rx_state_reg[0]\ : in STD_LOGIC;
    time_out_2ms_reg : in STD_LOGIC;
    time_out_2ms : in STD_LOGIC;
    cplllock : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_15 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_15;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_15 is
  signal \FSM_sequential_rx_state[3]_i_4_n_0\ : STD_LOGIC;
  signal \^data_out\ : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
  data_out <= \^data_out\;
\FSM_sequential_rx_state[3]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFF00CA"
    )
        port map (
      I0 => init_wait_done_reg,
      I1 => \FSM_sequential_rx_state[3]_i_4_n_0\,
      I2 => \out\(0),
      I3 => \out\(3),
      I4 => \FSM_sequential_rx_state_reg[0]\,
      O => E(0)
    );
\FSM_sequential_rx_state[3]_i_4\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"BBB8BBBB"
    )
        port map (
      I0 => time_out_2ms_reg,
      I1 => \out\(2),
      I2 => time_out_2ms,
      I3 => \^data_out\,
      I4 => \out\(1),
      O => \FSM_sequential_rx_state[3]_i_4_n_0\
    );
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => cplllock,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => \^data_out\,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_16 is
  port (
    reset_time_out_reg : out STD_LOGIC;
    rx_fsm_reset_done_int_reg : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 2 downto 0 );
    \FSM_sequential_rx_state_reg[0]\ : out STD_LOGIC;
    reset_time_out_reg_0 : in STD_LOGIC;
    time_out_100us : in STD_LOGIC;
    rxresetdone_s3_reg : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
    gt0_rx_cdrlocked_reg : in STD_LOGIC;
    data_in : in STD_LOGIC;
    cplllock_sync : in STD_LOGIC;
    \FSM_sequential_rx_state_reg[3]\ : in STD_LOGIC;
    time_out_2ms : in STD_LOGIC;
    \FSM_sequential_rx_state_reg[3]_0\ : in STD_LOGIC;
    time_out_1us : in STD_LOGIC;
    time_out_wait_bypass_s3 : in STD_LOGIC;
    \FSM_sequential_rx_state_reg[0]_0\ : in STD_LOGIC;
    time_out_100us_reg : in STD_LOGIC;
    rx_state15_out : in STD_LOGIC;
    data_out : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_16 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_16;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_16 is
  signal \FSM_sequential_rx_state[3]_i_7_n_0\ : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  signal data_valid_sync : STD_LOGIC;
  signal \reset_time_out_i_3__0_n_0\ : STD_LOGIC;
  signal rx_fsm_reset_done_int : STD_LOGIC;
  signal rx_fsm_reset_done_int_i_3_n_0 : STD_LOGIC;
  signal rx_fsm_reset_done_int_i_4_n_0 : STD_LOGIC;
  signal rx_state1 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
\FSM_sequential_rx_state[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000C55550F0F5555"
    )
        port map (
      I0 => \FSM_sequential_rx_state_reg[0]_0\,
      I1 => rx_state1,
      I2 => \out\(2),
      I3 => \out\(1),
      I4 => \out\(3),
      I5 => \out\(0),
      O => D(0)
    );
\FSM_sequential_rx_state[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00050000003FFF00"
    )
        port map (
      I0 => rx_state1,
      I1 => rx_state15_out,
      I2 => \out\(2),
      I3 => \out\(1),
      I4 => \out\(0),
      I5 => \out\(3),
      O => D(1)
    );
\FSM_sequential_rx_state[1]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => reset_time_out_reg_0,
      I1 => time_out_100us,
      I2 => data_valid_sync,
      O => rx_state1
    );
\FSM_sequential_rx_state[3]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFF08080008"
    )
        port map (
      I0 => \out\(1),
      I1 => \out\(2),
      I2 => \FSM_sequential_rx_state_reg[3]\,
      I3 => time_out_2ms,
      I4 => reset_time_out_reg_0,
      I5 => \FSM_sequential_rx_state[3]_i_7_n_0\,
      O => D(2)
    );
\FSM_sequential_rx_state[3]_i_5\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000003000F000B00"
    )
        port map (
      I0 => time_out_100us_reg,
      I1 => \out\(0),
      I2 => \out\(2),
      I3 => \out\(3),
      I4 => data_valid_sync,
      I5 => \out\(1),
      O => \FSM_sequential_rx_state_reg[0]\
    );
\FSM_sequential_rx_state[3]_i_7\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000005000000F300"
    )
        port map (
      I0 => rx_state1,
      I1 => time_out_wait_bypass_s3,
      I2 => \out\(1),
      I3 => \out\(3),
      I4 => \out\(2),
      I5 => \out\(0),
      O => \FSM_sequential_rx_state[3]_i_7_n_0\
    );
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_out,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_valid_sync,
      R => '0'
    );
\reset_time_out_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"F1FFF100"
    )
        port map (
      I0 => rxresetdone_s3_reg,
      I1 => \out\(3),
      I2 => \reset_time_out_i_3__0_n_0\,
      I3 => gt0_rx_cdrlocked_reg,
      I4 => reset_time_out_reg_0,
      O => reset_time_out_reg
    );
\reset_time_out_i_3__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00001B1B0000FF1F"
    )
        port map (
      I0 => data_valid_sync,
      I1 => \out\(0),
      I2 => \out\(1),
      I3 => cplllock_sync,
      I4 => \out\(2),
      I5 => \out\(3),
      O => \reset_time_out_i_3__0_n_0\
    );
rx_fsm_reset_done_int_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"ABA8"
    )
        port map (
      I0 => rx_fsm_reset_done_int,
      I1 => rx_fsm_reset_done_int_i_3_n_0,
      I2 => rx_fsm_reset_done_int_i_4_n_0,
      I3 => data_in,
      O => rx_fsm_reset_done_int_reg
    );
rx_fsm_reset_done_int_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000008"
    )
        port map (
      I0 => time_out_1us,
      I1 => data_valid_sync,
      I2 => reset_time_out_reg_0,
      I3 => \out\(0),
      I4 => \out\(2),
      O => rx_fsm_reset_done_int
    );
rx_fsm_reset_done_int_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000040404000"
    )
        port map (
      I0 => \out\(1),
      I1 => \out\(0),
      I2 => \out\(3),
      I3 => data_valid_sync,
      I4 => time_out_100us_reg,
      I5 => \out\(2),
      O => rx_fsm_reset_done_int_i_3_n_0
    );
rx_fsm_reset_done_int_i_4: unisim.vcomponents.LUT5
    generic map(
      INIT => X"20AA0000"
    )
        port map (
      I0 => \FSM_sequential_rx_state_reg[3]_0\,
      I1 => reset_time_out_reg_0,
      I2 => time_out_1us,
      I3 => data_valid_sync,
      I4 => \out\(1),
      O => rx_fsm_reset_done_int_i_4_n_0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_17 is
  port (
    SR : out STD_LOGIC_VECTOR ( 0 to 0 );
    mmcm_lock_reclocked_reg : out STD_LOGIC;
    mmcm_lock_reclocked : in STD_LOGIC;
    Q : in STD_LOGIC_VECTOR ( 2 downto 0 );
    \mmcm_lock_count_reg[4]\ : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_17 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_17;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_17 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  signal mmcm_lock_i : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => mmcm_locked,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => mmcm_lock_i,
      R => '0'
    );
\mmcm_lock_count[7]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => mmcm_lock_i,
      O => SR(0)
    );
\mmcm_lock_reclocked_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"EAAAAAAA00000000"
    )
        port map (
      I0 => mmcm_lock_reclocked,
      I1 => Q(2),
      I2 => Q(1),
      I3 => Q(0),
      I4 => \mmcm_lock_count_reg[4]\,
      I5 => mmcm_lock_i,
      O => mmcm_lock_reclocked_reg
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_18 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_18 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_18;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_18 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_19 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    userclk : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_19 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_19;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_19 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_20 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_20 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_20;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_20 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_3 is
  port (
    data_out : out STD_LOGIC;
    status_vector : in STD_LOGIC_VECTOR ( 0 to 0 );
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_3 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_3;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_3 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => status_vector(0),
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_4 is
  port (
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    Q : in STD_LOGIC_VECTOR ( 3 downto 0 );
    data_in : in STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_4 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_4;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_4 is
  signal data_out : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
\state[0]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00002EFC000000C0"
    )
        port map (
      I0 => data_out,
      I1 => Q(1),
      I2 => \cpllpd_wait_reg[95]\,
      I3 => Q(0),
      I4 => Q(3),
      I5 => Q(2),
      O => D(0)
    );
\state[1]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00004C7C00003C3C"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => Q(1),
      I2 => Q(0),
      I3 => data_out,
      I4 => Q(3),
      I5 => Q(2),
      O => D(1)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_7 is
  port (
    data_out : out STD_LOGIC;
    data_in : in STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_7 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_7;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_7 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_in,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_8 is
  port (
    data_out : out STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_8 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_8;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_8 is
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \cpllpd_wait_reg[95]\,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_sync_block_9 is
  port (
    reset_time_out_reg : out STD_LOGIC;
    E : out STD_LOGIC_VECTOR ( 0 to 0 );
    \FSM_sequential_tx_state_reg[3]\ : in STD_LOGIC;
    init_wait_done_reg : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
    reset_time_out : in STD_LOGIC;
    pll_reset_asserted_reg : in STD_LOGIC;
    refclk_stable : in STD_LOGIC;
    mmcm_lock_reclocked : in STD_LOGIC;
    txresetdone_s3 : in STD_LOGIC;
    \wait_time_cnt_reg[6]\ : in STD_LOGIC_VECTOR ( 0 to 0 );
    \FSM_sequential_tx_state_reg[2]\ : in STD_LOGIC;
    time_tlock_max_reg : in STD_LOGIC;
    time_out_500us : in STD_LOGIC;
    time_out_2ms : in STD_LOGIC;
    cplllock : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_sync_block_9 : entity is "GigEthGth7Core_sync_block";
end GigEthGth7Core_GigEthGth7Core_sync_block_9;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_sync_block_9 is
  signal \FSM_sequential_tx_state[3]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[3]_i_6_n_0\ : STD_LOGIC;
  signal cplllock_sync : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  signal reset_time_out_i_2_n_0 : STD_LOGIC;
  signal reset_time_out_i_4_n_0 : STD_LOGIC;
  signal tx_state0 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
\FSM_sequential_tx_state[3]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00338BBB00338B88"
    )
        port map (
      I0 => \FSM_sequential_tx_state[3]_i_3_n_0\,
      I1 => \out\(0),
      I2 => \wait_time_cnt_reg[6]\(0),
      I3 => \FSM_sequential_tx_state_reg[2]\,
      I4 => \out\(3),
      I5 => init_wait_done_reg,
      O => E(0)
    );
\FSM_sequential_tx_state[3]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"BBB8BBBBBBB88888"
    )
        port map (
      I0 => \FSM_sequential_tx_state[3]_i_6_n_0\,
      I1 => \out\(1),
      I2 => time_tlock_max_reg,
      I3 => mmcm_lock_reclocked,
      I4 => \out\(2),
      I5 => tx_state0,
      O => \FSM_sequential_tx_state[3]_i_3_n_0\
    );
\FSM_sequential_tx_state[3]_i_6\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F4FFF4FFF4FFF400"
    )
        port map (
      I0 => reset_time_out,
      I1 => time_out_500us,
      I2 => txresetdone_s3,
      I3 => \out\(2),
      I4 => time_out_2ms,
      I5 => cplllock_sync,
      O => \FSM_sequential_tx_state[3]_i_6_n_0\
    );
\FSM_sequential_tx_state[3]_i_8\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => cplllock_sync,
      I1 => pll_reset_asserted_reg,
      I2 => refclk_stable,
      O => tx_state0
    );
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => cplllock,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => data_sync5,
      Q => cplllock_sync,
      R => '0'
    );
reset_time_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"88B8FFFF88B80000"
    )
        port map (
      I0 => reset_time_out_i_2_n_0,
      I1 => \FSM_sequential_tx_state_reg[3]\,
      I2 => init_wait_done_reg,
      I3 => \out\(3),
      I4 => reset_time_out_i_4_n_0,
      I5 => reset_time_out,
      O => reset_time_out_reg
    );
reset_time_out_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F4F4FF0F0404FF0F"
    )
        port map (
      I0 => \out\(3),
      I1 => cplllock_sync,
      I2 => \out\(2),
      I3 => mmcm_lock_reclocked,
      I4 => \out\(1),
      I5 => txresetdone_s3,
      O => reset_time_out_i_2_n_0
    );
reset_time_out_i_4: unisim.vcomponents.LUT6
    generic map(
      INIT => X"03030303FFF30202"
    )
        port map (
      I0 => init_wait_done_reg,
      I1 => \out\(1),
      I2 => \out\(2),
      I3 => cplllock_sync,
      I4 => \out\(0),
      I5 => \out\(3),
      O => reset_time_out_i_4_n_0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_RX is
  port (
    gmii_rx_er : out STD_LOGIC;
    status_vector : out STD_LOGIC_VECTOR ( 2 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    Q : in STD_LOGIC_VECTOR ( 7 downto 0 );
    userclk2 : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 );
    SYNC_STATUS_REG0 : in STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ : in STD_LOGIC;
    D : in STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\ : in STD_LOGIC;
    RXNOTINTABLE_INT : in STD_LOGIC;
    p_40_in : in STD_LOGIC;
    RXEVEN : in STD_LOGIC;
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\ : in STD_LOGIC;
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\ : in STD_LOGIC_VECTOR ( 0 to 0 );
    \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\ : in STD_LOGIC_VECTOR ( 2 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_RX : entity is "RX";
end GigEthGth7Core_RX;

architecture STRUCTURE of GigEthGth7Core_RX is
  signal C : STD_LOGIC;
  signal C0 : STD_LOGIC;
  signal CGBAD : STD_LOGIC;
  signal CGBAD_REG1 : STD_LOGIC;
  signal CGBAD_REG2 : STD_LOGIC;
  signal CGBAD_REG3 : STD_LOGIC;
  signal C_HDR_REMOVED : STD_LOGIC;
  signal C_HDR_REMOVED_REG : STD_LOGIC;
  signal C_REG1 : STD_LOGIC;
  signal C_REG2 : STD_LOGIC;
  signal C_REG3 : STD_LOGIC;
  signal D0p0 : STD_LOGIC;
  signal D0p0_REG : STD_LOGIC;
  signal D0p0_REG_i_2_n_0 : STD_LOGIC;
  signal EOP : STD_LOGIC;
  signal EOP0 : STD_LOGIC;
  signal EOP_REG1 : STD_LOGIC;
  signal EOP_REG10 : STD_LOGIC;
  signal EOP_i_2_n_0 : STD_LOGIC;
  signal EXTEND : STD_LOGIC;
  signal EXTEND_ERR : STD_LOGIC;
  signal EXTEND_ERR0 : STD_LOGIC;
  signal EXTEND_REG1 : STD_LOGIC;
  signal EXTEND_REG2 : STD_LOGIC;
  signal EXTEND_REG3 : STD_LOGIC;
  signal EXTEND_i_1_n_0 : STD_LOGIC;
  signal EXT_ILLEGAL_K : STD_LOGIC;
  signal EXT_ILLEGAL_K0 : STD_LOGIC;
  signal EXT_ILLEGAL_K_REG1 : STD_LOGIC;
  signal EXT_ILLEGAL_K_REG2 : STD_LOGIC;
  signal FALSE_CARRIER : STD_LOGIC;
  signal FALSE_CARRIER_REG1 : STD_LOGIC;
  signal FALSE_CARRIER_REG2 : STD_LOGIC;
  signal FALSE_CARRIER_REG3 : STD_LOGIC;
  signal FALSE_CARRIER_i_1_n_0 : STD_LOGIC;
  signal FALSE_CARRIER_i_2_n_0 : STD_LOGIC;
  signal FALSE_CARRIER_i_3_n_0 : STD_LOGIC;
  signal FALSE_CARRIER_i_4_n_0 : STD_LOGIC;
  signal FALSE_DATA : STD_LOGIC;
  signal FALSE_DATA0 : STD_LOGIC;
  signal FALSE_DATA_i_2_n_0 : STD_LOGIC;
  signal FALSE_DATA_i_3_n_0 : STD_LOGIC;
  signal FALSE_DATA_i_4_n_0 : STD_LOGIC;
  signal FALSE_K : STD_LOGIC;
  signal FALSE_K0 : STD_LOGIC;
  signal FALSE_K_i_2_n_0 : STD_LOGIC;
  signal FALSE_K_i_3_n_0 : STD_LOGIC;
  signal FALSE_NIT : STD_LOGIC;
  signal FALSE_NIT0 : STD_LOGIC;
  signal FALSE_NIT_i_2_n_0 : STD_LOGIC;
  signal FALSE_NIT_i_3_n_0 : STD_LOGIC;
  signal FALSE_NIT_i_4_n_0 : STD_LOGIC;
  signal FROM_IDLE_D : STD_LOGIC;
  signal FROM_IDLE_D0 : STD_LOGIC;
  signal FROM_RX_CX : STD_LOGIC;
  signal FROM_RX_CX0 : STD_LOGIC;
  signal FROM_RX_CX_i_2_n_0 : STD_LOGIC;
  signal FROM_RX_K : STD_LOGIC;
  signal FROM_RX_K0 : STD_LOGIC;
  signal I : STD_LOGIC;
  signal I0 : STD_LOGIC;
  signal I335_in : STD_LOGIC;
  signal \IDLE_REG_reg_n_0_[0]\ : STD_LOGIC;
  signal \IDLE_REG_reg_n_0_[2]\ : STD_LOGIC;
  signal ILLEGAL_K : STD_LOGIC;
  signal ILLEGAL_K0 : STD_LOGIC;
  signal ILLEGAL_K_REG1 : STD_LOGIC;
  signal ILLEGAL_K_REG2 : STD_LOGIC;
  signal I_REG_reg_n_0 : STD_LOGIC;
  signal I_i_2_n_0 : STD_LOGIC;
  signal I_i_4_n_0 : STD_LOGIC;
  signal K23p7 : STD_LOGIC;
  signal K28p5 : STD_LOGIC;
  signal K28p5_REG1 : STD_LOGIC;
  signal K28p5_REG2 : STD_LOGIC;
  signal K29p7 : STD_LOGIC;
  signal R : STD_LOGIC;
  signal RECEIVE : STD_LOGIC;
  signal RECEIVE_i_1_n_0 : STD_LOGIC;
  signal RUDI_C0 : STD_LOGIC;
  signal RUDI_I0 : STD_LOGIC;
  signal RXCHARISK_REG1 : STD_LOGIC;
  signal \RXDATA_REG4_reg[0]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[1]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[2]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[3]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[4]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[5]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[6]_srl4_n_0\ : STD_LOGIC;
  signal \RXDATA_REG4_reg[7]_srl4_n_0\ : STD_LOGIC;
  signal RXDATA_REG5 : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal \RXD[0]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[1]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[2]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[3]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[4]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[5]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[6]_i_1_n_0\ : STD_LOGIC;
  signal \RXD[7]_i_1_n_0\ : STD_LOGIC;
  signal RX_CONFIG_VALID_INT : STD_LOGIC;
  signal RX_CONFIG_VALID_INT0 : STD_LOGIC;
  signal RX_CONFIG_VALID_INT_i_2_n_0 : STD_LOGIC;
  signal \RX_CONFIG_VALID_REG_reg_n_0_[0]\ : STD_LOGIC;
  signal \RX_CONFIG_VALID_REG_reg_n_0_[3]\ : STD_LOGIC;
  signal RX_DATA_ERROR : STD_LOGIC;
  signal RX_DATA_ERROR0 : STD_LOGIC;
  signal RX_DATA_ERROR_i_2_n_0 : STD_LOGIC;
  signal RX_DATA_ERROR_i_3_n_0 : STD_LOGIC;
  signal RX_DV_i_1_n_0 : STD_LOGIC;
  signal RX_DV_i_2_n_0 : STD_LOGIC;
  signal RX_ER0 : STD_LOGIC;
  signal RX_ER_i_2_n_0 : STD_LOGIC;
  signal RX_INVALID_i_2_n_0 : STD_LOGIC;
  signal R_REG1 : STD_LOGIC;
  signal R_i_2_n_0 : STD_LOGIC;
  signal R_i_3_n_0 : STD_LOGIC;
  signal R_i_4_n_0 : STD_LOGIC;
  signal S : STD_LOGIC;
  signal S0 : STD_LOGIC;
  signal S2 : STD_LOGIC;
  signal SOP : STD_LOGIC;
  signal SOP0 : STD_LOGIC;
  signal SOP_REG1 : STD_LOGIC;
  signal SOP_REG2 : STD_LOGIC;
  signal SOP_REG3 : STD_LOGIC;
  signal SYNC_STATUS_REG : STD_LOGIC;
  signal S_i_2_n_0 : STD_LOGIC;
  signal T : STD_LOGIC;
  signal T_REG1 : STD_LOGIC;
  signal T_REG2 : STD_LOGIC;
  signal WAIT_FOR_K : STD_LOGIC;
  signal WAIT_FOR_K_i_1_n_0 : STD_LOGIC;
  signal \^gmii_rx_dv\ : STD_LOGIC;
  signal p_0_in1_in : STD_LOGIC;
  signal p_0_in2_in : STD_LOGIC;
  signal p_1_in : STD_LOGIC;
  signal \^status_vector\ : STD_LOGIC_VECTOR ( 2 downto 0 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of D0p0_REG_i_1 : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of D0p0_REG_i_2 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of EXT_ILLEGAL_K_i_1 : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of FALSE_CARRIER_i_2 : label is "soft_lutpair6";
  attribute SOFT_HLUTNM of FALSE_CARRIER_i_4 : label is "soft_lutpair6";
  attribute SOFT_HLUTNM of FALSE_DATA_i_1 : label is "soft_lutpair4";
  attribute SOFT_HLUTNM of FALSE_DATA_i_2 : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of FALSE_K_i_2 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of FALSE_K_i_3 : label is "soft_lutpair11";
  attribute SOFT_HLUTNM of FALSE_NIT_i_4 : label is "soft_lutpair11";
  attribute SOFT_HLUTNM of FROM_RX_CX_i_2 : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of FROM_RX_K_i_1 : label is "soft_lutpair10";
  attribute srl_bus_name : string;
  attribute srl_bus_name of \RXDATA_REG4_reg[0]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name : string;
  attribute srl_name of \RXDATA_REG4_reg[0]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[0]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[1]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[1]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[1]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[2]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[2]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[2]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[3]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[3]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[3]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[4]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[4]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[4]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[5]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[5]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[5]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[6]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[6]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[6]_srl4 ";
  attribute srl_bus_name of \RXDATA_REG4_reg[7]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg ";
  attribute srl_name of \RXDATA_REG4_reg[7]_srl4\ : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[7]_srl4 ";
  attribute SOFT_HLUTNM of \RXD[1]_i_1\ : label is "soft_lutpair7";
  attribute SOFT_HLUTNM of \RXD[2]_i_1\ : label is "soft_lutpair8";
  attribute SOFT_HLUTNM of \RXD[3]_i_1\ : label is "soft_lutpair7";
  attribute SOFT_HLUTNM of \RXD[4]_i_1\ : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of \RXD[5]_i_1\ : label is "soft_lutpair9";
  attribute SOFT_HLUTNM of \RXD[6]_i_1\ : label is "soft_lutpair8";
  attribute SOFT_HLUTNM of \RXD[7]_i_1\ : label is "soft_lutpair9";
  attribute SOFT_HLUTNM of RX_CONFIG_VALID_INT_i_2 : label is "soft_lutpair10";
  attribute SOFT_HLUTNM of RX_ER_i_2 : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of R_i_2 : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of R_i_3 : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of R_i_4 : label is "soft_lutpair4";
begin
  gmii_rx_dv <= \^gmii_rx_dv\;
  status_vector(2 downto 0) <= \^status_vector\(2 downto 0);
CGBAD_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CGBAD,
      Q => CGBAD_REG1,
      R => '0'
    );
CGBAD_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CGBAD_REG1,
      Q => CGBAD_REG2,
      R => '0'
    );
CGBAD_REG3_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CGBAD_REG2,
      Q => CGBAD_REG3,
      R => SR(0)
    );
CGBAD_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => RXNOTINTABLE_INT,
      I1 => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\,
      I2 => D,
      O => S2
    );
CGBAD_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => S2,
      Q => CGBAD,
      R => SR(0)
    );
C_HDR_REMOVED_REG_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0400"
    )
        port map (
      I0 => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(1),
      I1 => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(0),
      I2 => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(2),
      I3 => C_REG2,
      O => C_HDR_REMOVED
    );
C_HDR_REMOVED_REG_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C_HDR_REMOVED,
      Q => C_HDR_REMOVED_REG,
      R => '0'
    );
C_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C,
      Q => C_REG1,
      R => '0'
    );
C_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C_REG1,
      Q => C_REG2,
      R => '0'
    );
C_REG3_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C_REG2,
      Q => C_REG3,
      R => '0'
    );
C_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => I335_in,
      I1 => K28p5_REG1,
      O => C0
    );
C_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C0,
      Q => C,
      R => '0'
    );
D0p0_REG_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00010000"
    )
        port map (
      I0 => Q(0),
      I1 => Q(1),
      I2 => Q(6),
      I3 => Q(7),
      I4 => D0p0_REG_i_2_n_0,
      O => D0p0
    );
D0p0_REG_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000001"
    )
        port map (
      I0 => Q(5),
      I1 => Q(2),
      I2 => Q(4),
      I3 => Q(3),
      I4 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      O => D0p0_REG_i_2_n_0
    );
D0p0_REG_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => D0p0,
      Q => D0p0_REG,
      R => '0'
    );
EOP_REG1_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F8"
    )
        port map (
      I0 => EXTEND_REG1,
      I1 => EXTEND,
      I2 => EOP,
      O => EOP_REG10
    );
EOP_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EOP_REG10,
      Q => EOP_REG1,
      R => SR(0)
    );
EOP_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFF8888888"
    )
        port map (
      I0 => I_REG_reg_n_0,
      I1 => K28p5_REG1,
      I2 => RXEVEN,
      I3 => C_REG1,
      I4 => D0p0_REG,
      I5 => EOP_i_2_n_0,
      O => EOP0
    );
EOP_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"88888000"
    )
        port map (
      I0 => T_REG2,
      I1 => R_REG1,
      I2 => K28p5_REG1,
      I3 => RXEVEN,
      I4 => R,
      O => EOP_i_2_n_0
    );
EOP_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EOP0,
      Q => EOP,
      R => SR(0)
    );
EXTEND_ERR_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F8"
    )
        port map (
      I0 => EXTEND_REG3,
      I1 => CGBAD_REG3,
      I2 => EXT_ILLEGAL_K_REG2,
      O => EXTEND_ERR0
    );
EXTEND_ERR_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXTEND_ERR0,
      Q => EXTEND_ERR,
      R => SYNC_STATUS_REG0
    );
EXTEND_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXTEND,
      Q => EXTEND_REG1,
      R => '0'
    );
EXTEND_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXTEND_REG1,
      Q => EXTEND_REG2,
      R => '0'
    );
EXTEND_REG3_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXTEND_REG2,
      Q => EXTEND_REG3,
      R => '0'
    );
EXTEND_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F2222222F0000000"
    )
        port map (
      I0 => FROM_RX_CX_i_2_n_0,
      I1 => S,
      I2 => R,
      I3 => RECEIVE,
      I4 => R_REG1,
      I5 => EXTEND,
      O => EXTEND_i_1_n_0
    );
EXTEND_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXTEND_i_1_n_0,
      Q => EXTEND,
      R => SYNC_STATUS_REG0
    );
EXT_ILLEGAL_K_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXT_ILLEGAL_K,
      Q => EXT_ILLEGAL_K_REG1,
      R => SYNC_STATUS_REG0
    );
EXT_ILLEGAL_K_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXT_ILLEGAL_K_REG1,
      Q => EXT_ILLEGAL_K_REG2,
      R => SYNC_STATUS_REG0
    );
EXT_ILLEGAL_K_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000444"
    )
        port map (
      I0 => S,
      I1 => EXTEND_REG1,
      I2 => K28p5_REG1,
      I3 => RXEVEN,
      I4 => R,
      O => EXT_ILLEGAL_K0
    );
EXT_ILLEGAL_K_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EXT_ILLEGAL_K0,
      Q => EXT_ILLEGAL_K,
      R => SYNC_STATUS_REG0
    );
FALSE_CARRIER_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_CARRIER,
      Q => FALSE_CARRIER_REG1,
      R => '0'
    );
FALSE_CARRIER_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_CARRIER_REG1,
      Q => FALSE_CARRIER_REG2,
      R => '0'
    );
FALSE_CARRIER_REG3_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_CARRIER_REG2,
      Q => FALSE_CARRIER_REG3,
      R => SYNC_STATUS_REG0
    );
FALSE_CARRIER_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"22EFEFEF22202020"
    )
        port map (
      I0 => FALSE_CARRIER_i_2_n_0,
      I1 => FALSE_CARRIER_i_3_n_0,
      I2 => FALSE_CARRIER_i_4_n_0,
      I3 => RXEVEN,
      I4 => K28p5_REG1,
      I5 => FALSE_CARRIER,
      O => FALSE_CARRIER_i_1_n_0
    );
FALSE_CARRIER_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0008"
    )
        port map (
      I0 => p_40_in,
      I1 => I_REG_reg_n_0,
      I2 => K28p5_REG1,
      I3 => S,
      O => FALSE_CARRIER_i_2_n_0
    );
FALSE_CARRIER_i_3: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
        port map (
      I0 => FALSE_NIT,
      I1 => FALSE_DATA,
      I2 => FALSE_K,
      O => FALSE_CARRIER_i_3_n_0
    );
FALSE_CARRIER_i_4: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0008"
    )
        port map (
      I0 => p_40_in,
      I1 => I_REG_reg_n_0,
      I2 => K28p5_REG1,
      I3 => S,
      O => FALSE_CARRIER_i_4_n_0
    );
FALSE_CARRIER_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_CARRIER_i_1_n_0,
      Q => FALSE_CARRIER,
      R => SYNC_STATUS_REG0
    );
FALSE_DATA_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"ABBFAAAA"
    )
        port map (
      I0 => FALSE_DATA_i_2_n_0,
      I1 => Q(3),
      I2 => Q(2),
      I3 => Q(4),
      I4 => FALSE_DATA_i_3_n_0,
      O => FALSE_DATA0
    );
FALSE_DATA_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00080000"
    )
        port map (
      I0 => Q(5),
      I1 => Q(7),
      I2 => RXNOTINTABLE_INT,
      I3 => Q(6),
      I4 => FALSE_DATA_i_4_n_0,
      O => FALSE_DATA_i_2_n_0
    );
FALSE_DATA_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000100000"
    )
        port map (
      I0 => Q(7),
      I1 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I2 => R_i_2_n_0,
      I3 => RXNOTINTABLE_INT,
      I4 => Q(6),
      I5 => Q(5),
      O => FALSE_DATA_i_3_n_0
    );
FALSE_DATA_i_4: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000040000C8"
    )
        port map (
      I0 => Q(3),
      I1 => Q(2),
      I2 => Q(4),
      I3 => Q(1),
      I4 => Q(0),
      I5 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      O => FALSE_DATA_i_4_n_0
    );
FALSE_DATA_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_DATA0,
      Q => FALSE_DATA,
      R => SR(0)
    );
FALSE_K_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0800000000000800"
    )
        port map (
      I0 => FALSE_K_i_2_n_0,
      I1 => FALSE_K_i_3_n_0,
      I2 => RXNOTINTABLE_INT,
      I3 => Q(7),
      I4 => Q(5),
      I5 => Q(6),
      O => FALSE_K0
    );
FALSE_K_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"8000"
    )
        port map (
      I0 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I1 => Q(3),
      I2 => Q(2),
      I3 => Q(4),
      O => FALSE_K_i_2_n_0
    );
FALSE_K_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => Q(0),
      I1 => Q(1),
      O => FALSE_K_i_3_n_0
    );
FALSE_K_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_K0,
      Q => FALSE_K,
      R => SR(0)
    );
FALSE_NIT_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF280028002800"
    )
        port map (
      I0 => FALSE_NIT_i_2_n_0,
      I1 => D,
      I2 => Q(7),
      I3 => RXNOTINTABLE_INT,
      I4 => FALSE_NIT_i_3_n_0,
      I5 => FALSE_NIT_i_4_n_0,
      O => FALSE_NIT0
    );
FALSE_NIT_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000088F0000000"
    )
        port map (
      I0 => FALSE_K_i_2_n_0,
      I1 => Q(5),
      I2 => D0p0_REG_i_2_n_0,
      I3 => Q(1),
      I4 => Q(0),
      I5 => Q(6),
      O => FALSE_NIT_i_2_n_0
    );
FALSE_NIT_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00F0000000008800"
    )
        port map (
      I0 => FALSE_K_i_2_n_0,
      I1 => Q(5),
      I2 => D0p0_REG_i_2_n_0,
      I3 => Q(6),
      I4 => Q(7),
      I5 => D,
      O => FALSE_NIT_i_3_n_0
    );
FALSE_NIT_i_4: unisim.vcomponents.LUT3
    generic map(
      INIT => X"60"
    )
        port map (
      I0 => Q(1),
      I1 => Q(0),
      I2 => RXNOTINTABLE_INT,
      O => FALSE_NIT_i_4_n_0
    );
FALSE_NIT_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FALSE_NIT0,
      Q => FALSE_NIT,
      R => SR(0)
    );
FROM_IDLE_D_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0004"
    )
        port map (
      I0 => p_40_in,
      I1 => I_REG_reg_n_0,
      I2 => K28p5_REG1,
      I3 => WAIT_FOR_K,
      O => FROM_IDLE_D0
    );
FROM_IDLE_D_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FROM_IDLE_D0,
      Q => FROM_IDLE_D,
      R => SYNC_STATUS_REG0
    );
FROM_RX_CX_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFECFFECFFECA8A8"
    )
        port map (
      I0 => C_REG3,
      I1 => CGBAD,
      I2 => FROM_RX_CX_i_2_n_0,
      I3 => RXCHARISK_REG1,
      I4 => C_REG2,
      I5 => C_REG1,
      O => FROM_RX_CX0
    );
FROM_RX_CX_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"7"
    )
        port map (
      I0 => K28p5_REG1,
      I1 => RXEVEN,
      O => FROM_RX_CX_i_2_n_0
    );
FROM_RX_CX_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FROM_RX_CX0,
      Q => FROM_RX_CX,
      R => SYNC_STATUS_REG0
    );
FROM_RX_K_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4440"
    )
        port map (
      I0 => p_40_in,
      I1 => K28p5_REG2,
      I2 => RXCHARISK_REG1,
      I3 => CGBAD,
      O => FROM_RX_K0
    );
FROM_RX_K_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => FROM_RX_K0,
      Q => FROM_RX_K,
      R => SYNC_STATUS_REG0
    );
\IDLE_REG_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => I_REG_reg_n_0,
      Q => \IDLE_REG_reg_n_0_[0]\,
      R => SR(0)
    );
\IDLE_REG_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \IDLE_REG_reg_n_0_[0]\,
      Q => p_0_in1_in,
      R => SR(0)
    );
\IDLE_REG_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => p_0_in1_in,
      Q => \IDLE_REG_reg_n_0_[2]\,
      R => SR(0)
    );
ILLEGAL_K_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => ILLEGAL_K,
      Q => ILLEGAL_K_REG1,
      R => SYNC_STATUS_REG0
    );
ILLEGAL_K_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => ILLEGAL_K_REG1,
      Q => ILLEGAL_K_REG2,
      R => SYNC_STATUS_REG0
    );
ILLEGAL_K_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0100"
    )
        port map (
      I0 => R,
      I1 => T,
      I2 => K28p5_REG1,
      I3 => RXCHARISK_REG1,
      O => ILLEGAL_K0
    );
ILLEGAL_K_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => ILLEGAL_K0,
      Q => ILLEGAL_K,
      R => SYNC_STATUS_REG0
    );
I_REG_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => I,
      Q => I_REG_reg_n_0,
      R => '0'
    );
I_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"3323222222222222"
    )
        port map (
      I0 => I_i_2_n_0,
      I1 => I335_in,
      I2 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I3 => p_40_in,
      I4 => RXEVEN,
      I5 => K28p5_REG1,
      O => I0
    );
I_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8080808080808000"
    )
        port map (
      I0 => I_REG_reg_n_0,
      I1 => p_40_in,
      I2 => RXEVEN,
      I3 => FALSE_K,
      I4 => FALSE_DATA,
      I5 => FALSE_NIT,
      O => I_i_2_n_0
    );
I_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000C0000A000A0"
    )
        port map (
      I0 => I_i_4_n_0,
      I1 => D0p0_REG_i_2_n_0,
      I2 => Q(0),
      I3 => Q(1),
      I4 => Q(7),
      I5 => Q(6),
      O => I335_in
    );
I_i_4: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000008000"
    )
        port map (
      I0 => Q(4),
      I1 => Q(2),
      I2 => Q(5),
      I3 => Q(7),
      I4 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I5 => Q(3),
      O => I_i_4_n_0
    );
I_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => I0,
      Q => I,
      R => '0'
    );
K28p5_REG1_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000100000000000"
    )
        port map (
      I0 => Q(0),
      I1 => Q(1),
      I2 => Q(7),
      I3 => Q(5),
      I4 => Q(6),
      I5 => FALSE_K_i_2_n_0,
      O => K28p5
    );
K28p5_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => K28p5,
      Q => K28p5_REG1,
      R => '0'
    );
K28p5_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => K28p5_REG1,
      Q => K28p5_REG2,
      R => '0'
    );
RECEIVE_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"BA"
    )
        port map (
      I0 => SOP_REG2,
      I1 => EOP,
      I2 => RECEIVE,
      O => RECEIVE_i_1_n_0
    );
RECEIVE_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RECEIVE_i_1_n_0,
      Q => RECEIVE,
      R => SYNC_STATUS_REG0
    );
RUDI_C_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => p_1_in,
      I1 => \RX_CONFIG_VALID_REG_reg_n_0_[0]\,
      I2 => \RX_CONFIG_VALID_REG_reg_n_0_[3]\,
      I3 => p_0_in2_in,
      O => RUDI_C0
    );
RUDI_C_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RUDI_C0,
      Q => \^status_vector\(0),
      R => SR(0)
    );
RUDI_I_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \IDLE_REG_reg_n_0_[2]\,
      I1 => p_0_in1_in,
      O => RUDI_I0
    );
RUDI_I_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RUDI_I0,
      Q => \^status_vector\(1),
      R => SR(0)
    );
RXCHARISK_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      Q => RXCHARISK_REG1,
      R => '0'
    );
\RXDATA_REG4_reg[0]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(0),
      Q => \RXDATA_REG4_reg[0]_srl4_n_0\
    );
\RXDATA_REG4_reg[1]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(1),
      Q => \RXDATA_REG4_reg[1]_srl4_n_0\
    );
\RXDATA_REG4_reg[2]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(2),
      Q => \RXDATA_REG4_reg[2]_srl4_n_0\
    );
\RXDATA_REG4_reg[3]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(3),
      Q => \RXDATA_REG4_reg[3]_srl4_n_0\
    );
\RXDATA_REG4_reg[4]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(4),
      Q => \RXDATA_REG4_reg[4]_srl4_n_0\
    );
\RXDATA_REG4_reg[5]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(5),
      Q => \RXDATA_REG4_reg[5]_srl4_n_0\
    );
\RXDATA_REG4_reg[6]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(6),
      Q => \RXDATA_REG4_reg[6]_srl4_n_0\
    );
\RXDATA_REG4_reg[7]_srl4\: unisim.vcomponents.SRL16E
     port map (
      A0 => '1',
      A1 => '1',
      A2 => '0',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => Q(7),
      Q => \RXDATA_REG4_reg[7]_srl4_n_0\
    );
\RXDATA_REG5_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[0]_srl4_n_0\,
      Q => RXDATA_REG5(0),
      R => '0'
    );
\RXDATA_REG5_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[1]_srl4_n_0\,
      Q => RXDATA_REG5(1),
      R => '0'
    );
\RXDATA_REG5_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[2]_srl4_n_0\,
      Q => RXDATA_REG5(2),
      R => '0'
    );
\RXDATA_REG5_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[3]_srl4_n_0\,
      Q => RXDATA_REG5(3),
      R => '0'
    );
\RXDATA_REG5_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[4]_srl4_n_0\,
      Q => RXDATA_REG5(4),
      R => '0'
    );
\RXDATA_REG5_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[5]_srl4_n_0\,
      Q => RXDATA_REG5(5),
      R => '0'
    );
\RXDATA_REG5_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[6]_srl4_n_0\,
      Q => RXDATA_REG5(6),
      R => '0'
    );
\RXDATA_REG5_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXDATA_REG4_reg[7]_srl4_n_0\,
      Q => RXDATA_REG5(7),
      R => '0'
    );
\RXD[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"AFAE"
    )
        port map (
      I0 => SOP_REG3,
      I1 => EXTEND_REG1,
      I2 => FALSE_CARRIER_REG3,
      I3 => RXDATA_REG5(0),
      O => \RXD[0]_i_1_n_0\
    );
\RXD[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0F0E"
    )
        port map (
      I0 => EXTEND_REG1,
      I1 => FALSE_CARRIER_REG3,
      I2 => SOP_REG3,
      I3 => RXDATA_REG5(1),
      O => \RXD[1]_i_1_n_0\
    );
\RXD[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => SOP_REG3,
      I1 => EXTEND_REG1,
      I2 => FALSE_CARRIER_REG3,
      I3 => RXDATA_REG5(2),
      O => \RXD[2]_i_1_n_0\
    );
\RXD[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0F0E"
    )
        port map (
      I0 => EXTEND_REG1,
      I1 => FALSE_CARRIER_REG3,
      I2 => SOP_REG3,
      I3 => RXDATA_REG5(3),
      O => \RXD[3]_i_1_n_0\
    );
\RXD[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"AAAAFAEE"
    )
        port map (
      I0 => SOP_REG3,
      I1 => RXDATA_REG5(4),
      I2 => EXTEND_ERR,
      I3 => EXTEND_REG1,
      I4 => FALSE_CARRIER_REG3,
      O => \RXD[4]_i_1_n_0\
    );
\RXD[5]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => RXDATA_REG5(5),
      I1 => SOP_REG3,
      I2 => EXTEND_REG1,
      I3 => FALSE_CARRIER_REG3,
      O => \RXD[5]_i_1_n_0\
    );
\RXD[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FF10"
    )
        port map (
      I0 => EXTEND_REG1,
      I1 => FALSE_CARRIER_REG3,
      I2 => RXDATA_REG5(6),
      I3 => SOP_REG3,
      O => \RXD[6]_i_1_n_0\
    );
\RXD[7]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0002"
    )
        port map (
      I0 => RXDATA_REG5(7),
      I1 => SOP_REG3,
      I2 => EXTEND_REG1,
      I3 => FALSE_CARRIER_REG3,
      O => \RXD[7]_i_1_n_0\
    );
\RXD_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[0]_i_1_n_0\,
      Q => gmii_rxd(0),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[1]_i_1_n_0\,
      Q => gmii_rxd(1),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[2]_i_1_n_0\,
      Q => gmii_rxd(2),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[3]_i_1_n_0\,
      Q => gmii_rxd(3),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[4]_i_1_n_0\,
      Q => gmii_rxd(4),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[5]_i_1_n_0\,
      Q => gmii_rxd(5),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[6]_i_1_n_0\,
      Q => gmii_rxd(6),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
\RXD_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RXD[7]_i_1_n_0\,
      Q => gmii_rxd(7),
      R => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0)
    );
RX_CONFIG_VALID_INT_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000E00"
    )
        port map (
      I0 => C_HDR_REMOVED_REG,
      I1 => C_REG1,
      I2 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I3 => p_40_in,
      I4 => RX_CONFIG_VALID_INT_i_2_n_0,
      I5 => S2,
      O => RX_CONFIG_VALID_INT0
    );
RX_CONFIG_VALID_INT_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => CGBAD,
      I1 => RXCHARISK_REG1,
      O => RX_CONFIG_VALID_INT_i_2_n_0
    );
RX_CONFIG_VALID_INT_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RX_CONFIG_VALID_INT0,
      Q => RX_CONFIG_VALID_INT,
      R => SR(0)
    );
\RX_CONFIG_VALID_REG_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RX_CONFIG_VALID_INT,
      Q => \RX_CONFIG_VALID_REG_reg_n_0_[0]\,
      R => SR(0)
    );
\RX_CONFIG_VALID_REG_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \RX_CONFIG_VALID_REG_reg_n_0_[0]\,
      Q => p_0_in2_in,
      R => SR(0)
    );
\RX_CONFIG_VALID_REG_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => p_0_in2_in,
      Q => p_1_in,
      R => SR(0)
    );
\RX_CONFIG_VALID_REG_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => p_1_in,
      Q => \RX_CONFIG_VALID_REG_reg_n_0_[3]\,
      R => SR(0)
    );
RX_DATA_ERROR_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FF00FF00FF00BA00"
    )
        port map (
      I0 => RX_DATA_ERROR_i_2_n_0,
      I1 => T_REG1,
      I2 => R,
      I3 => RX_DATA_ERROR_i_3_n_0,
      I4 => T_REG2,
      I5 => K28p5_REG1,
      O => RX_DATA_ERROR0
    );
RX_DATA_ERROR_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => CGBAD_REG3,
      I1 => ILLEGAL_K_REG2,
      I2 => I_REG_reg_n_0,
      I3 => C_REG1,
      O => RX_DATA_ERROR_i_2_n_0
    );
RX_DATA_ERROR_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FF08FFFF00000000"
    )
        port map (
      I0 => T_REG2,
      I1 => FROM_RX_CX_i_2_n_0,
      I2 => R,
      I3 => RX_DATA_ERROR_i_2_n_0,
      I4 => R_REG1,
      I5 => RECEIVE,
      O => RX_DATA_ERROR_i_3_n_0
    );
RX_DATA_ERROR_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RX_DATA_ERROR0,
      Q => RX_DATA_ERROR,
      R => SYNC_STATUS_REG0
    );
RX_DV_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"88FF00F088880000"
    )
        port map (
      I0 => RX_DV_i_2_n_0,
      I1 => SOP_REG3,
      I2 => RECEIVE,
      I3 => EOP_REG1,
      I4 => p_40_in,
      I5 => \^gmii_rx_dv\,
      O => RX_DV_i_1_n_0
    );
RX_DV_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\,
      I1 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => RX_DV_i_2_n_0
    );
RX_DV_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => RX_DV_i_1_n_0,
      Q => \^gmii_rx_dv\,
      R => SR(0)
    );
RX_ER_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000E000E000F0000"
    )
        port map (
      I0 => RX_ER_i_2_n_0,
      I1 => RX_DATA_ERROR,
      I2 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\,
      I3 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      I4 => RECEIVE,
      I5 => p_40_in,
      O => RX_ER0
    );
RX_ER_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => EXTEND_REG1,
      I1 => FALSE_CARRIER_REG3,
      O => RX_ER_i_2_n_0
    );
RX_ER_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => RX_ER0,
      Q => gmii_rx_er,
      R => SR(0)
    );
RX_INVALID_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AAFEFFFFAAFEAAFE"
    )
        port map (
      I0 => FROM_RX_CX,
      I1 => FROM_RX_K,
      I2 => FROM_IDLE_D,
      I3 => p_40_in,
      I4 => K28p5_REG1,
      I5 => \^status_vector\(2),
      O => RX_INVALID_i_2_n_0
    );
RX_INVALID_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => RX_INVALID_i_2_n_0,
      Q => \^status_vector\(2),
      R => SYNC_STATUS_REG0
    );
R_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => R,
      Q => R_REG1,
      R => '0'
    );
R_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0008000000000000"
    )
        port map (
      I0 => R_i_2_n_0,
      I1 => R_i_3_n_0,
      I2 => R_i_4_n_0,
      I3 => Q(3),
      I4 => Q(6),
      I5 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      O => K23p7
    );
R_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => Q(0),
      I1 => Q(1),
      O => R_i_2_n_0
    );
R_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => Q(5),
      I1 => Q(7),
      O => R_i_3_n_0
    );
R_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"7"
    )
        port map (
      I0 => Q(4),
      I1 => Q(2),
      O => R_i_4_n_0
    );
R_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => K23p7,
      Q => R,
      R => '0'
    );
SOP_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SOP,
      Q => SOP_REG1,
      R => '0'
    );
SOP_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SOP_REG1,
      Q => SOP_REG2,
      R => '0'
    );
SOP_REG3_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SOP_REG2,
      Q => SOP_REG3,
      R => '0'
    );
SOP_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"08080800"
    )
        port map (
      I0 => p_40_in,
      I1 => S,
      I2 => WAIT_FOR_K,
      I3 => I_REG_reg_n_0,
      I4 => EXTEND,
      O => SOP0
    );
SOP_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SOP0,
      Q => SOP,
      R => SR(0)
    );
SYNC_STATUS_REG_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => '1',
      Q => SYNC_STATUS_REG,
      R => SYNC_STATUS_REG0
    );
S_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8000000000000000"
    )
        port map (
      I0 => S_i_2_n_0,
      I1 => Q(3),
      I2 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I3 => Q(1),
      I4 => Q(0),
      I5 => R_i_3_n_0,
      O => S0
    );
S_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000040"
    )
        port map (
      I0 => Q(2),
      I1 => Q(4),
      I2 => Q(6),
      I3 => D,
      I4 => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\,
      I5 => RXNOTINTABLE_INT,
      O => S_i_2_n_0
    );
S_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => S0,
      Q => S,
      R => '0'
    );
T_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => T,
      Q => T_REG1,
      R => '0'
    );
T_REG2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => T_REG1,
      Q => T_REG2,
      R => '0'
    );
T_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0800000000000000"
    )
        port map (
      I0 => Q(5),
      I1 => Q(7),
      I2 => Q(1),
      I3 => Q(6),
      I4 => Q(0),
      I5 => FALSE_K_i_2_n_0,
      O => K29p7
    );
T_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => K29p7,
      Q => T,
      R => '0'
    );
WAIT_FOR_K_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7F0F"
    )
        port map (
      I0 => RXEVEN,
      I1 => K28p5_REG1,
      I2 => SYNC_STATUS_REG,
      I3 => WAIT_FOR_K,
      O => WAIT_FOR_K_i_1_n_0
    );
WAIT_FOR_K_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => WAIT_FOR_K_i_1_n_0,
      Q => WAIT_FOR_K,
      R => SYNC_STATUS_REG0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_SYNCHRONISE is
  port (
    RXEVEN : out STD_LOGIC;
    p_40_in : out STD_LOGIC;
    SYNC_STATUS_REG0 : out STD_LOGIC;
    STATUS_VECTOR_0_PRE0 : out STD_LOGIC;
    enablealign : out STD_LOGIC;
    SIGNAL_DETECT_MOD : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 );
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\ : in STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ : in STD_LOGIC;
    CONFIGURATION_VECTOR_REG : in STD_LOGIC_VECTOR ( 0 to 0 );
    D : in STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\ : in STD_LOGIC;
    RXNOTINTABLE_INT : in STD_LOGIC;
    reset_done : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_SYNCHRONISE : entity is "SYNCHRONISE";
end GigEthGth7Core_SYNCHRONISE;

architecture STRUCTURE of GigEthGth7Core_SYNCHRONISE is
  signal CGBAD : STD_LOGIC;
  signal ENCOMMAALIGN_i_1_n_0 : STD_LOGIC;
  signal ENCOMMAALIGN_i_2_n_0 : STD_LOGIC;
  signal EVEN_i_1_n_0 : STD_LOGIC;
  signal \FSM_sequential_STATE[0]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[0]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[1]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[1]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[2]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[2]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[3]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[3]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE[3]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE_reg[0]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE_reg[1]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_STATE_reg[2]_i_1_n_0\ : STD_LOGIC;
  signal GOOD_CGS : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal \GOOD_CGS[0]_i_1_n_0\ : STD_LOGIC;
  signal \GOOD_CGS[1]_i_1_n_0\ : STD_LOGIC;
  signal \GOOD_CGS[1]_i_2_n_0\ : STD_LOGIC;
  signal \^rxeven\ : STD_LOGIC;
  signal SIGNAL_DETECT_REG : STD_LOGIC;
  signal STATE : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of STATE : signal is "yes";
  signal SYNC_STATUS0 : STD_LOGIC;
  signal SYNC_STATUS_i_1_n_0 : STD_LOGIC;
  signal \^enablealign\ : STD_LOGIC;
  signal \^p_40_in\ : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of ENCOMMAALIGN_i_1 : label is "soft_lutpair14";
  attribute SOFT_HLUTNM of EVEN_i_1 : label is "soft_lutpair13";
  attribute KEEP : string;
  attribute KEEP of \FSM_sequential_STATE_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_STATE_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_STATE_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_STATE_reg[3]\ : label is "yes";
  attribute SOFT_HLUTNM of \GOOD_CGS[0]_i_1\ : label is "soft_lutpair12";
  attribute SOFT_HLUTNM of \GOOD_CGS[1]_i_1\ : label is "soft_lutpair12";
  attribute SOFT_HLUTNM of RX_INVALID_i_1 : label is "soft_lutpair13";
  attribute SOFT_HLUTNM of SYNC_STATUS_i_1 : label is "soft_lutpair14";
begin
  RXEVEN <= \^rxeven\;
  enablealign <= \^enablealign\;
  p_40_in <= \^p_40_in\;
ENCOMMAALIGN_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"0E"
    )
        port map (
      I0 => \^enablealign\,
      I1 => ENCOMMAALIGN_i_2_n_0,
      I2 => SYNC_STATUS0,
      O => ENCOMMAALIGN_i_1_n_0
    );
ENCOMMAALIGN_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"14010001"
    )
        port map (
      I0 => STATE(0),
      I1 => STATE(1),
      I2 => STATE(2),
      I3 => STATE(3),
      I4 => CGBAD,
      O => ENCOMMAALIGN_i_2_n_0
    );
ENCOMMAALIGN_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000040"
    )
        port map (
      I0 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I1 => STATE(0),
      I2 => STATE(2),
      I3 => STATE(1),
      I4 => STATE(3),
      I5 => CGBAD,
      O => SYNC_STATUS0
    );
ENCOMMAALIGN_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => ENCOMMAALIGN_i_1_n_0,
      Q => \^enablealign\,
      R => '0'
    );
EVEN_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"4F"
    )
        port map (
      I0 => \^p_40_in\,
      I1 => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\,
      I2 => \^rxeven\,
      O => EVEN_i_1_n_0
    );
EVEN_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => EVEN_i_1_n_0,
      Q => \^rxeven\,
      R => SR(0)
    );
\FSM_sequential_STATE[0]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"61156000"
    )
        port map (
      I0 => STATE(0),
      I1 => CGBAD,
      I2 => STATE(2),
      I3 => STATE(1),
      I4 => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\,
      O => \FSM_sequential_STATE[0]_i_2_n_0\
    );
\FSM_sequential_STATE[0]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000F000DF"
    )
        port map (
      I0 => GOOD_CGS(1),
      I1 => GOOD_CGS(0),
      I2 => STATE(0),
      I3 => STATE(2),
      I4 => STATE(1),
      I5 => CGBAD,
      O => \FSM_sequential_STATE[0]_i_3_n_0\
    );
\FSM_sequential_STATE[1]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"30330044"
    )
        port map (
      I0 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I1 => STATE(0),
      I2 => STATE(2),
      I3 => CGBAD,
      I4 => STATE(1),
      O => \FSM_sequential_STATE[1]_i_2_n_0\
    );
\FSM_sequential_STATE[1]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000FF0004FF"
    )
        port map (
      I0 => CGBAD,
      I1 => GOOD_CGS(1),
      I2 => GOOD_CGS(0),
      I3 => STATE(0),
      I4 => STATE(1),
      I5 => STATE(2),
      O => \FSM_sequential_STATE[1]_i_3_n_0\
    );
\FSM_sequential_STATE[2]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"30370040"
    )
        port map (
      I0 => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\,
      I1 => STATE(0),
      I2 => STATE(1),
      I3 => CGBAD,
      I4 => STATE(2),
      O => \FSM_sequential_STATE[2]_i_2_n_0\
    );
\FSM_sequential_STATE[2]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000140E1414"
    )
        port map (
      I0 => STATE(0),
      I1 => STATE(1),
      I2 => STATE(2),
      I3 => GOOD_CGS(0),
      I4 => GOOD_CGS(1),
      I5 => CGBAD,
      O => \FSM_sequential_STATE[2]_i_3_n_0\
    );
\FSM_sequential_STATE[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F1"
    )
        port map (
      I0 => CONFIGURATION_VECTOR_REG(0),
      I1 => SIGNAL_DETECT_REG,
      I2 => SR(0),
      O => \FSM_sequential_STATE[3]_i_1_n_0\
    );
\FSM_sequential_STATE[3]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0FE000E0003030F0"
    )
        port map (
      I0 => \FSM_sequential_STATE[3]_i_3_n_0\,
      I1 => CGBAD,
      I2 => STATE(3),
      I3 => STATE(2),
      I4 => STATE(1),
      I5 => STATE(0),
      O => \FSM_sequential_STATE[3]_i_2_n_0\
    );
\FSM_sequential_STATE[3]_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => GOOD_CGS(0),
      I1 => GOOD_CGS(1),
      O => \FSM_sequential_STATE[3]_i_3_n_0\
    );
\FSM_sequential_STATE[3]_i_4\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFFFF8"
    )
        port map (
      I0 => \^rxeven\,
      I1 => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\,
      I2 => D,
      I3 => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\,
      I4 => RXNOTINTABLE_INT,
      O => CGBAD
    );
\FSM_sequential_STATE_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_STATE_reg[0]_i_1_n_0\,
      Q => STATE(0),
      R => \FSM_sequential_STATE[3]_i_1_n_0\
    );
\FSM_sequential_STATE_reg[0]_i_1\: unisim.vcomponents.MUXF7
     port map (
      I0 => \FSM_sequential_STATE[0]_i_2_n_0\,
      I1 => \FSM_sequential_STATE[0]_i_3_n_0\,
      O => \FSM_sequential_STATE_reg[0]_i_1_n_0\,
      S => STATE(3)
    );
\FSM_sequential_STATE_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_STATE_reg[1]_i_1_n_0\,
      Q => STATE(1),
      R => \FSM_sequential_STATE[3]_i_1_n_0\
    );
\FSM_sequential_STATE_reg[1]_i_1\: unisim.vcomponents.MUXF7
     port map (
      I0 => \FSM_sequential_STATE[1]_i_2_n_0\,
      I1 => \FSM_sequential_STATE[1]_i_3_n_0\,
      O => \FSM_sequential_STATE_reg[1]_i_1_n_0\,
      S => STATE(3)
    );
\FSM_sequential_STATE_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_STATE_reg[2]_i_1_n_0\,
      Q => STATE(2),
      R => \FSM_sequential_STATE[3]_i_1_n_0\
    );
\FSM_sequential_STATE_reg[2]_i_1\: unisim.vcomponents.MUXF7
     port map (
      I0 => \FSM_sequential_STATE[2]_i_2_n_0\,
      I1 => \FSM_sequential_STATE[2]_i_3_n_0\,
      O => \FSM_sequential_STATE_reg[2]_i_1_n_0\,
      S => STATE(3)
    );
\FSM_sequential_STATE_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_STATE[3]_i_2_n_0\,
      Q => STATE(3),
      R => \FSM_sequential_STATE[3]_i_1_n_0\
    );
\GOOD_CGS[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"09"
    )
        port map (
      I0 => GOOD_CGS(0),
      I1 => CGBAD,
      I2 => \GOOD_CGS[1]_i_2_n_0\,
      O => \GOOD_CGS[0]_i_1_n_0\
    );
\GOOD_CGS[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"009A"
    )
        port map (
      I0 => GOOD_CGS(1),
      I1 => CGBAD,
      I2 => GOOD_CGS(0),
      I3 => \GOOD_CGS[1]_i_2_n_0\,
      O => \GOOD_CGS[1]_i_1_n_0\
    );
\GOOD_CGS[1]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"AABBEAAA"
    )
        port map (
      I0 => SR(0),
      I1 => STATE(0),
      I2 => STATE(1),
      I3 => STATE(2),
      I4 => STATE(3),
      O => \GOOD_CGS[1]_i_2_n_0\
    );
\GOOD_CGS_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \GOOD_CGS[0]_i_1_n_0\,
      Q => GOOD_CGS(0),
      R => '0'
    );
\GOOD_CGS_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \GOOD_CGS[1]_i_1_n_0\,
      Q => GOOD_CGS(1),
      R => '0'
    );
RX_INVALID_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => SR(0),
      I1 => \^p_40_in\,
      O => SYNC_STATUS_REG0
    );
SIGNAL_DETECT_REG_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SIGNAL_DETECT_MOD,
      Q => SIGNAL_DETECT_REG,
      R => '0'
    );
STATUS_VECTOR_0_PRE_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => \^p_40_in\,
      I1 => reset_done,
      O => STATUS_VECTOR_0_PRE0
    );
SYNC_STATUS_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F4"
    )
        port map (
      I0 => ENCOMMAALIGN_i_2_n_0,
      I1 => \^p_40_in\,
      I2 => SYNC_STATUS0,
      O => SYNC_STATUS_i_1_n_0
    );
SYNC_STATUS_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => SYNC_STATUS_i_1_n_0,
      Q => \^p_40_in\,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_TX is
  port (
    \USE_ROCKET_IO.TXCHARDISPMODE_reg\ : out STD_LOGIC;
    \USE_ROCKET_IO.TXDATA_reg[7]\ : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 3 downto 0 );
    \USE_ROCKET_IO.TXDATA_reg[5]\ : out STD_LOGIC;
    \USE_ROCKET_IO.TXDATA_reg[3]\ : out STD_LOGIC;
    \USE_ROCKET_IO.TXDATA_reg[2]\ : out STD_LOGIC;
    \USE_ROCKET_IO.TXCHARISK_reg\ : out STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ : out STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\ : out STD_LOGIC;
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
    \USE_ROCKET_IO.TXDATA_reg[2]_0\ : out STD_LOGIC;
    \USE_ROCKET_IO.TXCHARDISPVAL_reg\ : out STD_LOGIC;
    gmii_tx_en : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\ : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\ : in STD_LOGIC_VECTOR ( 0 to 0 );
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    CONFIGURATION_VECTOR_REG : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxcharisk : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxchariscomma : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxdata : in STD_LOGIC_VECTOR ( 7 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_TX : entity is "TX";
end GigEthGth7Core_TX;

architecture STRUCTURE of GigEthGth7Core_TX is
  signal C1_OR_C2_i_1_n_0 : STD_LOGIC;
  signal C1_OR_C2_reg_n_0 : STD_LOGIC;
  signal CODE_GRPISK : STD_LOGIC;
  signal CODE_GRPISK_i_1_n_0 : STD_LOGIC;
  signal \CODE_GRP[0]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[0]_i_2_n_0\ : STD_LOGIC;
  signal \CODE_GRP[1]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[1]_i_2_n_0\ : STD_LOGIC;
  signal \CODE_GRP[2]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[2]_i_2_n_0\ : STD_LOGIC;
  signal \CODE_GRP[3]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[3]_i_2_n_0\ : STD_LOGIC;
  signal \CODE_GRP[4]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[5]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[6]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[7]_i_1_n_0\ : STD_LOGIC;
  signal \CODE_GRP[7]_i_2_n_0\ : STD_LOGIC;
  signal \CODE_GRP_CNT_reg_n_0_[1]\ : STD_LOGIC;
  signal \CODE_GRP_reg_n_0_[0]\ : STD_LOGIC;
  signal CONFIG_DATA : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal \CONFIG_DATA_reg_n_0_[0]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[1]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[2]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[3]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[4]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[5]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[6]\ : STD_LOGIC;
  signal \CONFIG_DATA_reg_n_0_[7]\ : STD_LOGIC;
  signal CONFIG_K28p5 : STD_LOGIC;
  signal CONFIG_K28p5_0 : STD_LOGIC;
  signal DISPARITY : STD_LOGIC;
  signal INSERT_IDLE_i_1_n_0 : STD_LOGIC;
  signal INSERT_IDLE_reg_n_0 : STD_LOGIC;
  signal K28p5 : STD_LOGIC;
  signal K28p5_i_1_n_0 : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXCHARISK_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[0]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[1]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[2]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[3]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[4]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[5]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[6]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DATA.TXDATA[7]_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DISP.DISPARITY_i_1_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DISP.DISPARITY_i_2_n_0\ : STD_LOGIC;
  signal \NO_QSGMII_DISP.DISPARITY_i_3_n_0\ : STD_LOGIC;
  signal R : STD_LOGIC;
  signal \R_i_1__0_n_0\ : STD_LOGIC;
  signal S : STD_LOGIC;
  signal S0 : STD_LOGIC;
  signal SYNC_DISPARITY_i_1_n_0 : STD_LOGIC;
  signal SYNC_DISPARITY_reg_n_0 : STD_LOGIC;
  signal T : STD_LOGIC;
  signal T0 : STD_LOGIC;
  signal TRIGGER_S : STD_LOGIC;
  signal TRIGGER_S0 : STD_LOGIC;
  signal TRIGGER_T : STD_LOGIC;
  signal TXCHARDISPMODE_INT : STD_LOGIC;
  signal TXCHARDISPVAL : STD_LOGIC;
  signal TXCHARISK_INT : STD_LOGIC;
  signal TXDATA : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal TXD_REG1 : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal TX_EN_REG1 : STD_LOGIC;
  signal TX_ER_REG1 : STD_LOGIC;
  signal TX_EVEN : STD_LOGIC;
  signal TX_PACKET : STD_LOGIC;
  signal TX_PACKET_i_1_n_0 : STD_LOGIC;
  signal V : STD_LOGIC;
  signal V_i_1_n_0 : STD_LOGIC;
  signal V_i_2_n_0 : STD_LOGIC;
  signal V_i_3_n_0 : STD_LOGIC;
  signal V_i_4_n_0 : STD_LOGIC;
  signal V_i_5_n_0 : STD_LOGIC;
  signal XMIT_CONFIG_INT : STD_LOGIC;
  signal XMIT_CONFIG_INT_i_1_n_0 : STD_LOGIC;
  signal XMIT_DATA_INT_i_1_n_0 : STD_LOGIC;
  signal XMIT_DATA_INT_reg_n_0 : STD_LOGIC;
  signal p_0_in : STD_LOGIC;
  signal p_0_in16_in : STD_LOGIC;
  signal p_0_in35_in : STD_LOGIC;
  signal p_10_out : STD_LOGIC;
  signal p_1_in : STD_LOGIC;
  signal p_1_in1_in : STD_LOGIC;
  signal p_1_in34_in : STD_LOGIC;
  signal p_33_in : STD_LOGIC;
  signal p_45_in : STD_LOGIC;
  signal p_8_out : STD_LOGIC;
  signal plusOp : STD_LOGIC_VECTOR ( 1 downto 0 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of C1_OR_C2_i_1 : label is "soft_lutpair20";
  attribute SOFT_HLUTNM of \CODE_GRP[7]_i_2\ : label is "soft_lutpair18";
  attribute SOFT_HLUTNM of \CODE_GRP_CNT[0]_i_1\ : label is "soft_lutpair36";
  attribute SOFT_HLUTNM of \CODE_GRP_CNT[1]_i_1\ : label is "soft_lutpair35";
  attribute SOFT_HLUTNM of \CONFIG_DATA[0]_i_1\ : label is "soft_lutpair20";
  attribute SOFT_HLUTNM of \CONFIG_DATA[1]_i_1\ : label is "soft_lutpair28";
  attribute SOFT_HLUTNM of \CONFIG_DATA[3]_i_1\ : label is "soft_lutpair34";
  attribute SOFT_HLUTNM of \CONFIG_DATA[6]_i_1\ : label is "soft_lutpair34";
  attribute SOFT_HLUTNM of \CONFIG_DATA[7]_i_1\ : label is "soft_lutpair28";
  attribute SOFT_HLUTNM of CONFIG_K28p5_i_1 : label is "soft_lutpair27";
  attribute SOFT_HLUTNM of INSERT_IDLE_i_1 : label is "soft_lutpair21";
  attribute SOFT_HLUTNM of K28p5_i_1 : label is "soft_lutpair21";
  attribute SOFT_HLUTNM of \NO_QSGMII_CHAR.TXCHARDISPMODE_i_1\ : label is "soft_lutpair36";
  attribute SOFT_HLUTNM of \NO_QSGMII_CHAR.TXCHARDISPVAL_i_1\ : label is "soft_lutpair27";
  attribute SOFT_HLUTNM of \NO_QSGMII_DATA.TXDATA[1]_i_1\ : label is "soft_lutpair15";
  attribute SOFT_HLUTNM of \NO_QSGMII_DATA.TXDATA[3]_i_1\ : label is "soft_lutpair17";
  attribute SOFT_HLUTNM of \NO_QSGMII_DATA.TXDATA[5]_i_1\ : label is "soft_lutpair15";
  attribute SOFT_HLUTNM of \NO_QSGMII_DATA.TXDATA[6]_i_1\ : label is "soft_lutpair17";
  attribute SOFT_HLUTNM of TRIGGER_S_i_1 : label is "soft_lutpair19";
  attribute SOFT_HLUTNM of TRIGGER_T_i_1 : label is "soft_lutpair19";
  attribute SOFT_HLUTNM of TX_PACKET_i_1 : label is "soft_lutpair18";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_i_1\ : label is "soft_lutpair22";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_i_1\ : label is "soft_lutpair25";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[0]_i_1\ : label is "soft_lutpair33";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[1]_i_1\ : label is "soft_lutpair33";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[2]_i_1\ : label is "soft_lutpair32";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[3]_i_1\ : label is "soft_lutpair32";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[4]_i_1\ : label is "soft_lutpair31";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[5]_i_1\ : label is "soft_lutpair30";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[6]_i_1\ : label is "soft_lutpair30";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDATA_INT[7]_i_1\ : label is "soft_lutpair29";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXCHARDISPMODE_i_1\ : label is "soft_lutpair24";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXCHARISK_i_1\ : label is "soft_lutpair22";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[0]_i_1\ : label is "soft_lutpair26";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[1]_i_1\ : label is "soft_lutpair29";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[2]_i_1\ : label is "soft_lutpair26";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[3]_i_1\ : label is "soft_lutpair25";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[4]_i_1\ : label is "soft_lutpair31";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[5]_i_1\ : label is "soft_lutpair23";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[6]_i_1\ : label is "soft_lutpair16";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[7]_i_1\ : label is "soft_lutpair16";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.TXDATA[7]_i_2\ : label is "soft_lutpair23";
  attribute SOFT_HLUTNM of XMIT_CONFIG_INT_i_1 : label is "soft_lutpair35";
  attribute SOFT_HLUTNM of XMIT_DATA_INT_i_1 : label is "soft_lutpair24";
begin
C1_OR_C2_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"3F80"
    )
        port map (
      I0 => XMIT_CONFIG_INT,
      I1 => TX_EVEN,
      I2 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I3 => C1_OR_C2_reg_n_0,
      O => C1_OR_C2_i_1_n_0
    );
C1_OR_C2_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => C1_OR_C2_i_1_n_0,
      Q => C1_OR_C2_reg_n_0,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
CODE_GRPISK_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"3030FFFF3030FF55"
    )
        port map (
      I0 => TX_PACKET,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I2 => TX_EVEN,
      I3 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      I4 => XMIT_CONFIG_INT,
      I5 => \CODE_GRP[7]_i_2_n_0\,
      O => CODE_GRPISK_i_1_n_0
    );
CODE_GRPISK_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CODE_GRPISK_i_1_n_0,
      Q => CODE_GRPISK,
      R => '0'
    );
\CODE_GRP[0]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FA00FAFC"
    )
        port map (
      I0 => \CONFIG_DATA_reg_n_0_[0]\,
      I1 => S,
      I2 => \CODE_GRP[0]_i_2_n_0\,
      I3 => XMIT_CONFIG_INT,
      I4 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[0]_i_1_n_0\
    );
\CODE_GRP[0]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"000000000000FFF8"
    )
        port map (
      I0 => TX_PACKET,
      I1 => TXD_REG1(0),
      I2 => R,
      I3 => T,
      I4 => XMIT_CONFIG_INT,
      I5 => V,
      O => \CODE_GRP[0]_i_2_n_0\
    );
\CODE_GRP[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFAA0000FFAAFEFE"
    )
        port map (
      I0 => \CODE_GRP[1]_i_2_n_0\,
      I1 => S,
      I2 => V,
      I3 => \CONFIG_DATA_reg_n_0_[1]\,
      I4 => XMIT_CONFIG_INT,
      I5 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[1]_i_1_n_0\
    );
\CODE_GRP[1]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000F08"
    )
        port map (
      I0 => TX_PACKET,
      I1 => TXD_REG1(1),
      I2 => XMIT_CONFIG_INT,
      I3 => R,
      I4 => T,
      O => \CODE_GRP[1]_i_2_n_0\
    );
\CODE_GRP[2]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"C0FFC044"
    )
        port map (
      I0 => S,
      I1 => \CODE_GRP[2]_i_2_n_0\,
      I2 => \CONFIG_DATA_reg_n_0_[2]\,
      I3 => XMIT_CONFIG_INT,
      I4 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[2]_i_1_n_0\
    );
\CODE_GRP[2]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFEFFFF"
    )
        port map (
      I0 => R,
      I1 => T,
      I2 => V,
      I3 => XMIT_CONFIG_INT,
      I4 => TX_PACKET,
      I5 => TXD_REG1(2),
      O => \CODE_GRP[2]_i_2_n_0\
    );
\CODE_GRP[3]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFF88BB888B"
    )
        port map (
      I0 => \CONFIG_DATA_reg_n_0_[3]\,
      I1 => XMIT_CONFIG_INT,
      I2 => TX_PACKET,
      I3 => R,
      I4 => TXD_REG1(3),
      I5 => \CODE_GRP[3]_i_2_n_0\,
      O => \CODE_GRP[3]_i_1_n_0\
    );
\CODE_GRP[3]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00FF00FE"
    )
        port map (
      I0 => T,
      I1 => S,
      I2 => V,
      I3 => XMIT_CONFIG_INT,
      I4 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[3]_i_2_n_0\
    );
\CODE_GRP[4]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"CFCFCFCFCFCFCACF"
    )
        port map (
      I0 => TXD_REG1(4),
      I1 => \CONFIG_DATA_reg_n_0_[4]\,
      I2 => XMIT_CONFIG_INT,
      I3 => TX_PACKET,
      I4 => \CODE_GRP[7]_i_2_n_0\,
      I5 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[4]_i_1_n_0\
    );
\CODE_GRP[5]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"CFCFCFCFCFCFCACF"
    )
        port map (
      I0 => TXD_REG1(5),
      I1 => \CONFIG_DATA_reg_n_0_[5]\,
      I2 => XMIT_CONFIG_INT,
      I3 => TX_PACKET,
      I4 => \CODE_GRP[7]_i_2_n_0\,
      I5 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[5]_i_1_n_0\
    );
\CODE_GRP[6]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AAAA0000AAAAFFC0"
    )
        port map (
      I0 => \CONFIG_DATA_reg_n_0_[6]\,
      I1 => TX_PACKET,
      I2 => TXD_REG1(6),
      I3 => \CODE_GRP[7]_i_2_n_0\,
      I4 => XMIT_CONFIG_INT,
      I5 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[6]_i_1_n_0\
    );
\CODE_GRP[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"CFCFCFCFCFCFCACF"
    )
        port map (
      I0 => TXD_REG1(7),
      I1 => \CONFIG_DATA_reg_n_0_[7]\,
      I2 => XMIT_CONFIG_INT,
      I3 => TX_PACKET,
      I4 => \CODE_GRP[7]_i_2_n_0\,
      I5 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      O => \CODE_GRP[7]_i_1_n_0\
    );
\CODE_GRP[7]_i_2\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => V,
      I1 => S,
      I2 => T,
      I3 => R,
      O => \CODE_GRP[7]_i_2_n_0\
    );
\CODE_GRP_CNT[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => TX_EVEN,
      O => plusOp(0)
    );
\CODE_GRP_CNT[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => TX_EVEN,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => plusOp(1)
    );
\CODE_GRP_CNT_reg[0]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => plusOp(0),
      Q => TX_EVEN,
      S => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CODE_GRP_CNT_reg[1]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => plusOp(1),
      Q => \CODE_GRP_CNT_reg_n_0_[1]\,
      S => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CODE_GRP_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[0]_i_1_n_0\,
      Q => \CODE_GRP_reg_n_0_[0]\,
      R => '0'
    );
\CODE_GRP_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[1]_i_1_n_0\,
      Q => p_1_in,
      R => '0'
    );
\CODE_GRP_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[2]_i_1_n_0\,
      Q => p_0_in16_in,
      R => '0'
    );
\CODE_GRP_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[3]_i_1_n_0\,
      Q => p_0_in,
      R => '0'
    );
\CODE_GRP_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[4]_i_1_n_0\,
      Q => p_1_in1_in,
      R => '0'
    );
\CODE_GRP_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[5]_i_1_n_0\,
      Q => p_1_in34_in,
      R => '0'
    );
\CODE_GRP_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[6]_i_1_n_0\,
      Q => p_33_in,
      R => '0'
    );
\CODE_GRP_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \CODE_GRP[7]_i_1_n_0\,
      Q => p_0_in35_in,
      R => '0'
    );
\CONFIG_DATA[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I1 => TX_EVEN,
      I2 => C1_OR_C2_reg_n_0,
      O => CONFIG_DATA(0)
    );
\CONFIG_DATA[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => TX_EVEN,
      I1 => C1_OR_C2_reg_n_0,
      I2 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => CONFIG_DATA(1)
    );
\CONFIG_DATA[3]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => TX_EVEN,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => CONFIG_DATA(3)
    );
\CONFIG_DATA[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => TX_EVEN,
      I1 => C1_OR_C2_reg_n_0,
      I2 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => CONFIG_DATA(6)
    );
\CONFIG_DATA[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"07"
    )
        port map (
      I0 => TX_EVEN,
      I1 => C1_OR_C2_reg_n_0,
      I2 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => CONFIG_DATA(2)
    );
\CONFIG_DATA_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(0),
      Q => \CONFIG_DATA_reg_n_0_[0]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(1),
      Q => \CONFIG_DATA_reg_n_0_[1]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(2),
      Q => \CONFIG_DATA_reg_n_0_[2]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(3),
      Q => \CONFIG_DATA_reg_n_0_[3]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(2),
      Q => \CONFIG_DATA_reg_n_0_[4]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(2),
      Q => \CONFIG_DATA_reg_n_0_[5]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(6),
      Q => \CONFIG_DATA_reg_n_0_[6]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\CONFIG_DATA_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_DATA(2),
      Q => \CONFIG_DATA_reg_n_0_[7]\,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
CONFIG_K28p5_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => TX_EVEN,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      O => CONFIG_K28p5_0
    );
CONFIG_K28p5_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => CONFIG_K28p5_0,
      Q => CONFIG_K28p5,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
INSERT_IDLE_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"00AB"
    )
        port map (
      I0 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      I1 => \CODE_GRP[7]_i_2_n_0\,
      I2 => TX_PACKET,
      I3 => XMIT_CONFIG_INT,
      O => INSERT_IDLE_i_1_n_0
    );
INSERT_IDLE_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => INSERT_IDLE_i_1_n_0,
      Q => INSERT_IDLE_reg_n_0,
      R => '0'
    );
K28p5_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => XMIT_CONFIG_INT,
      I1 => CONFIG_K28p5,
      O => K28p5_i_1_n_0
    );
K28p5_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => K28p5_i_1_n_0,
      Q => K28p5,
      R => '0'
    );
\NO_QSGMII_CHAR.TXCHARDISPMODE_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => SYNC_DISPARITY_reg_n_0,
      I1 => TX_EVEN,
      O => p_10_out
    );
\NO_QSGMII_CHAR.TXCHARDISPMODE_reg\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => p_10_out,
      Q => TXCHARDISPMODE_INT,
      S => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\NO_QSGMII_CHAR.TXCHARDISPVAL_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => TX_EVEN,
      I1 => SYNC_DISPARITY_reg_n_0,
      I2 => DISPARITY,
      O => p_8_out
    );
\NO_QSGMII_CHAR.TXCHARDISPVAL_reg\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => p_8_out,
      Q => TXCHARDISPVAL,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\NO_QSGMII_DATA.TXCHARISK_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"002A"
    )
        port map (
      I0 => CODE_GRPISK,
      I1 => TX_EVEN,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      O => \NO_QSGMII_DATA.TXCHARISK_i_1_n_0\
    );
\NO_QSGMII_DATA.TXCHARISK_reg\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXCHARISK_i_1_n_0\,
      Q => TXCHARISK_INT,
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA[0]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"23332000"
    )
        port map (
      I0 => DISPARITY,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => TX_EVEN,
      I4 => \CODE_GRP_reg_n_0_[0]\,
      O => \NO_QSGMII_DATA.TXDATA[0]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"002A"
    )
        port map (
      I0 => p_1_in,
      I1 => TX_EVEN,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      O => \NO_QSGMII_DATA.TXDATA[1]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[2]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"23332000"
    )
        port map (
      I0 => DISPARITY,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => TX_EVEN,
      I4 => p_0_in16_in,
      O => \NO_QSGMII_DATA.TXDATA[2]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"002A"
    )
        port map (
      I0 => p_0_in,
      I1 => TX_EVEN,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      O => \NO_QSGMII_DATA.TXDATA[3]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"13331000"
    )
        port map (
      I0 => DISPARITY,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => TX_EVEN,
      I4 => p_1_in1_in,
      O => \NO_QSGMII_DATA.TXDATA[4]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[5]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"002A"
    )
        port map (
      I0 => p_1_in34_in,
      I1 => TX_EVEN,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      O => \NO_QSGMII_DATA.TXDATA[5]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"3222"
    )
        port map (
      I0 => p_33_in,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => TX_EVEN,
      I3 => INSERT_IDLE_reg_n_0,
      O => \NO_QSGMII_DATA.TXDATA[6]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA[7]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"23332000"
    )
        port map (
      I0 => DISPARITY,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => INSERT_IDLE_reg_n_0,
      I3 => TX_EVEN,
      I4 => p_0_in35_in,
      O => \NO_QSGMII_DATA.TXDATA[7]_i_1_n_0\
    );
\NO_QSGMII_DATA.TXDATA_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[0]_i_1_n_0\,
      Q => TXDATA(0),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[1]_i_1_n_0\,
      Q => TXDATA(1),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[2]_i_1_n_0\,
      Q => TXDATA(2),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[3]_i_1_n_0\,
      Q => TXDATA(3),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[4]_i_1_n_0\,
      Q => TXDATA(4),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[5]_i_1_n_0\,
      Q => TXDATA(5),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[6]_i_1_n_0\,
      Q => TXDATA(6),
      R => '0'
    );
\NO_QSGMII_DATA.TXDATA_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DATA.TXDATA[7]_i_1_n_0\,
      Q => TXDATA(7),
      R => '0'
    );
\NO_QSGMII_DISP.DISPARITY_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0041414100BEBEBE"
    )
        port map (
      I0 => K28p5,
      I1 => \NO_QSGMII_DISP.DISPARITY_i_2_n_0\,
      I2 => \NO_QSGMII_DISP.DISPARITY_i_3_n_0\,
      I3 => INSERT_IDLE_reg_n_0,
      I4 => TX_EVEN,
      I5 => DISPARITY,
      O => \NO_QSGMII_DISP.DISPARITY_i_1_n_0\
    );
\NO_QSGMII_DISP.DISPARITY_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7C"
    )
        port map (
      I0 => p_0_in35_in,
      I1 => p_33_in,
      I2 => p_1_in34_in,
      O => \NO_QSGMII_DISP.DISPARITY_i_2_n_0\
    );
\NO_QSGMII_DISP.DISPARITY_i_3\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"177E7EA8"
    )
        port map (
      I0 => p_0_in16_in,
      I1 => p_1_in1_in,
      I2 => p_0_in,
      I3 => \CODE_GRP_reg_n_0_[0]\,
      I4 => p_1_in,
      O => \NO_QSGMII_DISP.DISPARITY_i_3_n_0\
    );
\NO_QSGMII_DISP.DISPARITY_reg\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => \NO_QSGMII_DISP.DISPARITY_i_1_n_0\,
      Q => DISPARITY,
      S => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\R_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"F0FEF0F0"
    )
        port map (
      I0 => TX_EVEN,
      I1 => TX_ER_REG1,
      I2 => T,
      I3 => S,
      I4 => R,
      O => \R_i_1__0_n_0\
    );
R_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \R_i_1__0_n_0\,
      Q => R,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
SYNC_DISPARITY_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"3030AAAA3030AAFF"
    )
        port map (
      I0 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0),
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I2 => TX_EVEN,
      I3 => \CODE_GRP[7]_i_2_n_0\,
      I4 => XMIT_CONFIG_INT,
      I5 => TX_PACKET,
      O => SYNC_DISPARITY_i_1_n_0
    );
SYNC_DISPARITY_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SYNC_DISPARITY_i_1_n_0,
      Q => SYNC_DISPARITY_reg_n_0,
      R => '0'
    );
\S_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF00000B000000"
    )
        port map (
      I0 => TX_ER_REG1,
      I1 => TX_EVEN,
      I2 => TX_EN_REG1,
      I3 => gmii_tx_en,
      I4 => XMIT_DATA_INT_reg_n_0,
      I5 => TRIGGER_S,
      O => S0
    );
S_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => S0,
      Q => S,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
TRIGGER_S_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0040"
    )
        port map (
      I0 => TX_EN_REG1,
      I1 => gmii_tx_en,
      I2 => TX_EVEN,
      I3 => TX_ER_REG1,
      O => TRIGGER_S0
    );
TRIGGER_S_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRIGGER_S0,
      Q => TRIGGER_S,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
TRIGGER_T_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => TX_EN_REG1,
      I1 => gmii_tx_en,
      O => p_45_in
    );
TRIGGER_T_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => p_45_in,
      Q => TRIGGER_T,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\TXD_REG1_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(0),
      Q => TXD_REG1(0),
      R => '0'
    );
\TXD_REG1_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(1),
      Q => TXD_REG1(1),
      R => '0'
    );
\TXD_REG1_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(2),
      Q => TXD_REG1(2),
      R => '0'
    );
\TXD_REG1_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(3),
      Q => TXD_REG1(3),
      R => '0'
    );
\TXD_REG1_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(4),
      Q => TXD_REG1(4),
      R => '0'
    );
\TXD_REG1_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(5),
      Q => TXD_REG1(5),
      R => '0'
    );
\TXD_REG1_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(6),
      Q => TXD_REG1(6),
      R => '0'
    );
\TXD_REG1_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_txd(7),
      Q => TXD_REG1(7),
      R => '0'
    );
TX_EN_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_tx_en,
      Q => TX_EN_REG1,
      R => '0'
    );
TX_ER_REG1_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => gmii_tx_er,
      Q => TX_ER_REG1,
      R => '0'
    );
TX_PACKET_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"BA"
    )
        port map (
      I0 => S,
      I1 => T,
      I2 => TX_PACKET,
      O => TX_PACKET_i_1_n_0
    );
TX_PACKET_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TX_PACKET_i_1_n_0,
      Q => TX_PACKET,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\T_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF00E000E000E0"
    )
        port map (
      I0 => TX_PACKET,
      I1 => S,
      I2 => TX_EN_REG1,
      I3 => gmii_tx_en,
      I4 => V,
      I5 => TRIGGER_T,
      O => T0
    );
T_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => T0,
      Q => T,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXCHARISK_INT,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxchariscomma(0),
      O => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\
    );
\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXCHARISK_INT,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxcharisk(0),
      O => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(0),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(0),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(0)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(1),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(1),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(1)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(2),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(2),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(2)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(3),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(3),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(3)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[4]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(4),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(4),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(4)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(5),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(5),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(5)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(6),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(6),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(6)
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TXDATA(7),
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => rxdata(7),
      O => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(7)
    );
\USE_ROCKET_IO.TXCHARDISPMODE_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TX_EVEN,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => TXCHARDISPMODE_INT,
      O => \USE_ROCKET_IO.TXCHARDISPMODE_reg\
    );
\USE_ROCKET_IO.TXCHARDISPVAL_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXCHARDISPVAL,
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => \USE_ROCKET_IO.TXCHARDISPVAL_reg\
    );
\USE_ROCKET_IO.TXCHARISK_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => TX_EVEN,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => TXCHARISK_INT,
      O => \USE_ROCKET_IO.TXCHARISK_reg\
    );
\USE_ROCKET_IO.TXDATA[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(0),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => D(0)
    );
\USE_ROCKET_IO.TXDATA[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(1),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => D(1)
    );
\USE_ROCKET_IO.TXDATA[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(2),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => \USE_ROCKET_IO.TXDATA_reg[2]\
    );
\USE_ROCKET_IO.TXDATA[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(3),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => \USE_ROCKET_IO.TXDATA_reg[3]\
    );
\USE_ROCKET_IO.TXDATA[4]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"32"
    )
        port map (
      I0 => TXDATA(4),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => D(2)
    );
\USE_ROCKET_IO.TXDATA[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(5),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => \USE_ROCKET_IO.TXDATA_reg[5]\
    );
\USE_ROCKET_IO.TXDATA[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0704"
    )
        port map (
      I0 => TX_EVEN,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I3 => TXDATA(6),
      O => D(3)
    );
\USE_ROCKET_IO.TXDATA[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I1 => CONFIGURATION_VECTOR_REG(0),
      I2 => TX_EVEN,
      O => \USE_ROCKET_IO.TXDATA_reg[2]_0\
    );
\USE_ROCKET_IO.TXDATA[7]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => TXDATA(7),
      I1 => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\,
      I2 => CONFIGURATION_VECTOR_REG(0),
      O => \USE_ROCKET_IO.TXDATA_reg[7]\
    );
V_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"F888"
    )
        port map (
      I0 => XMIT_DATA_INT_reg_n_0,
      I1 => V_i_2_n_0,
      I2 => S,
      I3 => V,
      O => V_i_1_n_0
    );
V_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"EAEEEAEEEAEEEAAA"
    )
        port map (
      I0 => V_i_3_n_0,
      I1 => gmii_tx_er,
      I2 => TX_PACKET,
      I3 => gmii_tx_en,
      I4 => V_i_4_n_0,
      I5 => V_i_5_n_0,
      O => V_i_2_n_0
    );
V_i_3: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => TX_PACKET,
      I1 => TX_EN_REG1,
      I2 => TX_ER_REG1,
      O => V_i_3_n_0
    );
V_i_4: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
        port map (
      I0 => gmii_txd(5),
      I1 => gmii_txd(7),
      I2 => gmii_txd(6),
      I3 => gmii_txd(4),
      O => V_i_4_n_0
    );
V_i_5: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7FFF"
    )
        port map (
      I0 => gmii_txd(2),
      I1 => gmii_txd(1),
      I2 => gmii_txd(0),
      I3 => gmii_txd(3),
      O => V_i_5_n_0
    );
V_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => V_i_1_n_0,
      Q => V,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
XMIT_CONFIG_INT_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"E0"
    )
        port map (
      I0 => TX_EVEN,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I2 => XMIT_CONFIG_INT,
      O => XMIT_CONFIG_INT_i_1_n_0
    );
XMIT_CONFIG_INT_reg: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => XMIT_CONFIG_INT_i_1_n_0,
      Q => XMIT_CONFIG_INT,
      S => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
XMIT_DATA_INT_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F1"
    )
        port map (
      I0 => TX_EVEN,
      I1 => \CODE_GRP_CNT_reg_n_0_[1]\,
      I2 => XMIT_DATA_INT_reg_n_0,
      O => XMIT_DATA_INT_i_1_n_0
    );
XMIT_DATA_INT_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => XMIT_DATA_INT_i_1_n_0,
      Q => XMIT_DATA_INT_reg_n_0,
      R => \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_reset_sync_block is
  port (
    \MGT_RESET.RESET_INT_PIPE_reg\ : out STD_LOGIC;
    dcm_locked : in STD_LOGIC;
    userclk : in STD_LOGIC;
    reset : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_reset_sync_block : entity is "reset_sync_block";
end GigEthGth7Core_reset_sync_block;

architecture STRUCTURE of GigEthGth7Core_reset_sync_block is
  signal reset_out : STD_LOGIC;
  signal reset_sync_reg1 : STD_LOGIC;
  signal reset_sync_reg2 : STD_LOGIC;
  signal reset_sync_reg3 : STD_LOGIC;
  signal reset_sync_reg4 : STD_LOGIC;
  signal reset_sync_reg5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of reset_sync1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of reset_sync1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of reset_sync1 : label is "FDP";
  attribute box_type : string;
  attribute box_type of reset_sync1 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync2 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync2 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync2 : label is "FDP";
  attribute box_type of reset_sync2 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync3 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync3 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync3 : label is "FDP";
  attribute box_type of reset_sync3 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync4 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync4 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync4 : label is "FDP";
  attribute box_type of reset_sync4 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync5 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync5 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync5 : label is "FDP";
  attribute box_type of reset_sync5 : label is "PRIMITIVE";
  attribute ASYNC_REG of reset_sync6 : label is std.standard.true;
  attribute SHREG_EXTRACT of reset_sync6 : label is "no";
  attribute XILINX_LEGACY_PRIM of reset_sync6 : label is "FDP";
  attribute box_type of reset_sync6 : label is "PRIMITIVE";
begin
\MGT_RESET.RESET_INT_PIPE_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => reset_out,
      I1 => dcm_locked,
      O => \MGT_RESET.RESET_INT_PIPE_reg\
    );
reset_sync1: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => '0',
      PRE => reset,
      Q => reset_sync_reg1
    );
reset_sync2: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg1,
      PRE => reset,
      Q => reset_sync_reg2
    );
reset_sync3: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg2,
      PRE => reset,
      Q => reset_sync_reg3
    );
reset_sync4: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg3,
      PRE => reset,
      Q => reset_sync_reg4
    );
reset_sync5: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg4,
      PRE => reset,
      Q => reset_sync_reg5
    );
reset_sync6: unisim.vcomponents.FDPE
    generic map(
      INIT => '1'
    )
        port map (
      C => userclk,
      CE => '1',
      D => reset_sync_reg5,
      PRE => '0',
      Q => reset_out
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_sync_block is
  port (
    SIGNAL_DETECT_MOD : out STD_LOGIC;
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\ : in STD_LOGIC;
    signal_detect : in STD_LOGIC;
    userclk2 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_sync_block : entity is "sync_block";
end GigEthGth7Core_sync_block;

architecture STRUCTURE of GigEthGth7Core_sync_block is
  signal data_out : STD_LOGIC;
  signal data_sync1 : STD_LOGIC;
  signal data_sync2 : STD_LOGIC;
  signal data_sync3 : STD_LOGIC;
  signal data_sync4 : STD_LOGIC;
  signal data_sync5 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of data_sync_reg1 : label is std.standard.true;
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of data_sync_reg1 : label is "no";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of data_sync_reg1 : label is "FD";
  attribute box_type : string;
  attribute box_type of data_sync_reg1 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg2 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg2 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg2 : label is "FD";
  attribute box_type of data_sync_reg2 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg3 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg3 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg3 : label is "FD";
  attribute box_type of data_sync_reg3 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg4 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg4 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg4 : label is "FD";
  attribute box_type of data_sync_reg4 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg5 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg5 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg5 : label is "FD";
  attribute box_type of data_sync_reg5 : label is "PRIMITIVE";
  attribute ASYNC_REG of data_sync_reg6 : label is std.standard.true;
  attribute SHREG_EXTRACT of data_sync_reg6 : label is "no";
  attribute XILINX_LEGACY_PRIM of data_sync_reg6 : label is "FD";
  attribute box_type of data_sync_reg6 : label is "PRIMITIVE";
begin
SIGNAL_DETECT_REG_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => data_out,
      I1 => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\,
      O => SIGNAL_DETECT_MOD
    );
data_sync_reg1: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => signal_detect,
      Q => data_sync1,
      R => '0'
    );
data_sync_reg2: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync1,
      Q => data_sync2,
      R => '0'
    );
data_sync_reg3: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync2,
      Q => data_sync3,
      R => '0'
    );
data_sync_reg4: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync3,
      Q => data_sync4,
      R => '0'
    );
data_sync_reg5: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync4,
      Q => data_sync5,
      R => '0'
    );
data_sync_reg6: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => data_sync5,
      Q => data_out,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GPCS_PMA_GEN is
  port (
    status_vector : out STD_LOGIC_VECTOR ( 6 downto 0 );
    MGT_TX_RESET : out STD_LOGIC;
    gmii_isolate : out STD_LOGIC;
    rxpowerdown_reg_reg : out STD_LOGIC;
    MGT_RX_RESET : out STD_LOGIC;
    enablealign : out STD_LOGIC;
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_er : out STD_LOGIC;
    txchardispmode : out STD_LOGIC;
    txcharisk : out STD_LOGIC;
    txdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    txchardispval : out STD_LOGIC;
    userclk2 : in STD_LOGIC;
    dcm_locked : in STD_LOGIC;
    signal_detect : in STD_LOGIC;
    userclk : in STD_LOGIC;
    reset : in STD_LOGIC;
    gmii_tx_en : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    configuration_vector : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxbufstatus : in STD_LOGIC_VECTOR ( 0 to 0 );
    txbuferr : in STD_LOGIC;
    rxclkcorcnt : in STD_LOGIC_VECTOR ( 2 downto 0 );
    rxcharisk : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxchariscomma : in STD_LOGIC_VECTOR ( 0 to 0 );
    reset_done : in STD_LOGIC;
    rxdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxdisperr : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxnotintable : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GPCS_PMA_GEN : entity is "GPCS_PMA_GEN";
end GigEthGth7Core_GPCS_PMA_GEN;

architecture STRUCTURE of GigEthGth7Core_GPCS_PMA_GEN is
  signal CONFIGURATION_VECTOR_REG : STD_LOGIC_VECTOR ( 1 to 1 );
  signal D : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0\ : STD_LOGIC;
  signal \MGT_RESET.SYNC_ASYNC_RESET_n_0\ : STD_LOGIC;
  signal \^mgt_rx_reset\ : STD_LOGIC;
  signal MGT_RX_RESET_INT : STD_LOGIC;
  signal \^mgt_tx_reset\ : STD_LOGIC;
  signal MGT_TX_RESET_INT : STD_LOGIC;
  signal \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0\ : STD_LOGIC;
  signal \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0\ : STD_LOGIC;
  signal \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0\ : STD_LOGIC;
  signal RESET_INT : STD_LOGIC;
  attribute async_reg : string;
  attribute async_reg of RESET_INT : signal is "true";
  signal RESET_INT_PIPE : STD_LOGIC;
  attribute async_reg of RESET_INT_PIPE : signal is "true";
  signal RXCLKCORCNT_INT : STD_LOGIC;
  signal RXDISPERR_SRL : STD_LOGIC;
  signal RXEVEN : STD_LOGIC;
  signal RXNOTINTABLE_INT : STD_LOGIC;
  signal RXNOTINTABLE_SRL : STD_LOGIC;
  signal RX_RST_SM : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of RX_RST_SM : signal is "yes";
  signal SIGNAL_DETECT_MOD : STD_LOGIC;
  signal SRESET : STD_LOGIC;
  attribute async_reg of SRESET : signal is "true";
  signal SRESET_PIPE : STD_LOGIC;
  attribute async_reg of SRESET_PIPE : signal is "true";
  signal STATUS_VECTOR_0_PRE : STD_LOGIC;
  signal STATUS_VECTOR_0_PRE0 : STD_LOGIC;
  signal SYNC_STATUS_REG : STD_LOGIC;
  signal SYNC_STATUS_REG0 : STD_LOGIC;
  signal TRANSMITTER_n_0 : STD_LOGIC;
  signal TRANSMITTER_n_1 : STD_LOGIC;
  signal TRANSMITTER_n_10 : STD_LOGIC;
  signal TRANSMITTER_n_11 : STD_LOGIC;
  signal TRANSMITTER_n_12 : STD_LOGIC;
  signal TRANSMITTER_n_13 : STD_LOGIC;
  signal TRANSMITTER_n_14 : STD_LOGIC;
  signal TRANSMITTER_n_15 : STD_LOGIC;
  signal TRANSMITTER_n_16 : STD_LOGIC;
  signal TRANSMITTER_n_17 : STD_LOGIC;
  signal TRANSMITTER_n_18 : STD_LOGIC;
  signal TRANSMITTER_n_19 : STD_LOGIC;
  signal TRANSMITTER_n_2 : STD_LOGIC;
  signal TRANSMITTER_n_20 : STD_LOGIC;
  signal TRANSMITTER_n_21 : STD_LOGIC;
  signal TRANSMITTER_n_3 : STD_LOGIC;
  signal TRANSMITTER_n_4 : STD_LOGIC;
  signal TRANSMITTER_n_5 : STD_LOGIC;
  signal TRANSMITTER_n_6 : STD_LOGIC;
  signal TRANSMITTER_n_7 : STD_LOGIC;
  signal TRANSMITTER_n_8 : STD_LOGIC;
  signal TRANSMITTER_n_9 : STD_LOGIC;
  signal TXBUFERR_INT : STD_LOGIC;
  signal TX_RST_SM : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute RTL_KEEP of TX_RST_SM : signal is "yes";
  signal \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7]\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0\ : STD_LOGIC;
  signal \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0\ : STD_LOGIC;
  signal \^gmii_isolate\ : STD_LOGIC;
  signal p_0_out : STD_LOGIC;
  signal p_1_out : STD_LOGIC;
  signal p_40_in : STD_LOGIC;
  signal \^rxpowerdown_reg_reg\ : STD_LOGIC;
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of DELAY_RXDISPERR : label is "SRL16";
  attribute box_type : string;
  attribute box_type of DELAY_RXDISPERR : label is "PRIMITIVE";
  attribute srl_name : string;
  attribute srl_name of DELAY_RXDISPERR : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/DELAY_RXDISPERR ";
  attribute XILINX_LEGACY_PRIM of DELAY_RXNOTINTABLE : label is "SRL16";
  attribute box_type of DELAY_RXNOTINTABLE : label is "PRIMITIVE";
  attribute srl_name of DELAY_RXNOTINTABLE : label is "\U0/GigEthGth7Core_core /\gpcs_pma_inst/DELAY_RXNOTINTABLE ";
  attribute KEEP : string;
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[3]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[3]\ : label is "yes";
  attribute ASYNC_REG_boolean : boolean;
  attribute ASYNC_REG_boolean of \MGT_RESET.RESET_INT_PIPE_reg\ : label is std.standard.true;
  attribute KEEP of \MGT_RESET.RESET_INT_PIPE_reg\ : label is "yes";
  attribute ASYNC_REG_boolean of \MGT_RESET.RESET_INT_reg\ : label is std.standard.true;
  attribute KEEP of \MGT_RESET.RESET_INT_reg\ : label is "yes";
  attribute ASYNC_REG_boolean of \MGT_RESET.SRESET_PIPE_reg\ : label is std.standard.true;
  attribute KEEP of \MGT_RESET.SRESET_PIPE_reg\ : label is "yes";
  attribute ASYNC_REG_boolean of \MGT_RESET.SRESET_reg\ : label is std.standard.true;
  attribute KEEP of \MGT_RESET.SRESET_reg\ : label is "yes";
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1\ : label is "soft_lutpair37";
  attribute SOFT_HLUTNM of \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1\ : label is "soft_lutpair37";
begin
  MGT_RX_RESET <= \^mgt_rx_reset\;
  MGT_TX_RESET <= \^mgt_tx_reset\;
  gmii_isolate <= \^gmii_isolate\;
  rxpowerdown_reg_reg <= \^rxpowerdown_reg_reg\;
DELAY_RXDISPERR: unisim.vcomponents.SRL16E
    generic map(
      INIT => X"0000"
    )
        port map (
      A0 => '0',
      A1 => '0',
      A2 => '1',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => D,
      Q => RXDISPERR_SRL
    );
DELAY_RXNOTINTABLE: unisim.vcomponents.SRL16E
    generic map(
      INIT => X"0000"
    )
        port map (
      A0 => '0',
      A1 => '0',
      A2 => '1',
      A3 => '0',
      CE => '1',
      CLK => userclk2,
      D => RXNOTINTABLE_INT,
      Q => RXNOTINTABLE_SRL
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"1555"
    )
        port map (
      I0 => RX_RST_SM(0),
      I1 => RX_RST_SM(3),
      I2 => RX_RST_SM(1),
      I3 => RX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"DA5A"
    )
        port map (
      I0 => RX_RST_SM(0),
      I1 => RX_RST_SM(3),
      I2 => RX_RST_SM(1),
      I3 => RX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BFC0"
    )
        port map (
      I0 => RX_RST_SM(3),
      I1 => RX_RST_SM(0),
      I2 => RX_RST_SM(1),
      I3 => RX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"EAAA"
    )
        port map (
      I0 => RX_RST_SM(3),
      I1 => RX_RST_SM(2),
      I2 => RX_RST_SM(0),
      I3 => RX_RST_SM(1),
      O => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0\,
      Q => RX_RST_SM(0),
      R => p_0_out
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0\,
      Q => RX_RST_SM(1),
      R => p_0_out
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0\,
      Q => RX_RST_SM(2),
      R => p_0_out
    );
\FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0\,
      Q => RX_RST_SM(3),
      R => p_0_out
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"1555"
    )
        port map (
      I0 => TX_RST_SM(0),
      I1 => TX_RST_SM(3),
      I2 => TX_RST_SM(1),
      I3 => TX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"DA5A"
    )
        port map (
      I0 => TX_RST_SM(0),
      I1 => TX_RST_SM(3),
      I2 => TX_RST_SM(1),
      I3 => TX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BFC0"
    )
        port map (
      I0 => TX_RST_SM(3),
      I1 => TX_RST_SM(0),
      I2 => TX_RST_SM(1),
      I3 => TX_RST_SM(2),
      O => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"EAAA"
    )
        port map (
      I0 => TX_RST_SM(3),
      I1 => TX_RST_SM(2),
      I2 => TX_RST_SM(0),
      I3 => TX_RST_SM(1),
      O => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0\
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0\,
      Q => TX_RST_SM(0),
      R => p_1_out
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0\,
      Q => TX_RST_SM(1),
      R => p_1_out
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0\,
      Q => TX_RST_SM(2),
      R => p_1_out
    );
\FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0\,
      Q => TX_RST_SM(3),
      R => p_1_out
    );
\MGT_RESET.RESET_INT_PIPE_reg\: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => '0',
      PRE => \MGT_RESET.SYNC_ASYNC_RESET_n_0\,
      Q => RESET_INT_PIPE
    );
\MGT_RESET.RESET_INT_reg\: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => RESET_INT_PIPE,
      PRE => \MGT_RESET.SYNC_ASYNC_RESET_n_0\,
      Q => RESET_INT
    );
\MGT_RESET.SRESET_PIPE_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => RESET_INT,
      Q => SRESET_PIPE,
      R => '0'
    );
\MGT_RESET.SRESET_reg\: unisim.vcomponents.FDSE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => SRESET_PIPE,
      Q => SRESET,
      S => RESET_INT
    );
\MGT_RESET.SYNC_ASYNC_RESET\: entity work.GigEthGth7Core_reset_sync_block
     port map (
      \MGT_RESET.RESET_INT_PIPE_reg\ => \MGT_RESET.SYNC_ASYNC_RESET_n_0\,
      dcm_locked => dcm_locked,
      reset => reset,
      userclk => userclk
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => configuration_vector(0),
      I1 => SRESET,
      O => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0\
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => configuration_vector(1),
      I1 => SRESET,
      O => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0\
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => configuration_vector(2),
      I1 => SRESET,
      O => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0\
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0\,
      Q => CONFIGURATION_VECTOR_REG(1),
      R => '0'
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0\,
      Q => \^rxpowerdown_reg_reg\,
      R => '0'
    );
\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0\,
      Q => \^gmii_isolate\,
      R => '0'
    );
RECEIVER: entity work.GigEthGth7Core_RX
     port map (
      D => D,
      \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\ => \^rxpowerdown_reg_reg\,
      \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0) => \^gmii_isolate\,
      Q(7) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7]\,
      Q(6) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6]\,
      Q(5) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5]\,
      Q(4) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4]\,
      Q(3) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3]\,
      Q(2) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2]\,
      Q(1) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1]\,
      Q(0) => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0]\,
      RXEVEN => RXEVEN,
      RXNOTINTABLE_INT => RXNOTINTABLE_INT,
      SR(0) => \^mgt_rx_reset\,
      SYNC_STATUS_REG0 => SYNC_STATUS_REG0,
      \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\ => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1]\,
      \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0\,
      \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(2) => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2]\,
      \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(1) => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1]\,
      \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\(0) => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0]\,
      gmii_rx_dv => gmii_rx_dv,
      gmii_rx_er => gmii_rx_er,
      gmii_rxd(7 downto 0) => gmii_rxd(7 downto 0),
      p_40_in => p_40_in,
      status_vector(2 downto 0) => status_vector(4 downto 2),
      userclk2 => userclk2
    );
RXDISPERR_REG_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => RXDISPERR_SRL,
      Q => status_vector(5),
      R => '0'
    );
RXNOTINTABLE_REG_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => RXNOTINTABLE_SRL,
      Q => status_vector(6),
      R => '0'
    );
STATUS_VECTOR_0_PRE_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => STATUS_VECTOR_0_PRE0,
      Q => STATUS_VECTOR_0_PRE,
      R => '0'
    );
\STATUS_VECTOR_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => STATUS_VECTOR_0_PRE,
      Q => status_vector(0),
      R => '0'
    );
\STATUS_VECTOR_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => SYNC_STATUS_REG,
      Q => status_vector(1),
      R => '0'
    );
SYNCHRONISATION: entity work.GigEthGth7Core_SYNCHRONISE
     port map (
      CONFIGURATION_VECTOR_REG(0) => CONFIGURATION_VECTOR_REG(1),
      D => D,
      RXEVEN => RXEVEN,
      RXNOTINTABLE_INT => RXNOTINTABLE_INT,
      SIGNAL_DETECT_MOD => SIGNAL_DETECT_MOD,
      SR(0) => \^mgt_rx_reset\,
      STATUS_VECTOR_0_PRE0 => STATUS_VECTOR_0_PRE0,
      SYNC_STATUS_REG0 => SYNC_STATUS_REG0,
      \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\ => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1]\,
      \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\ => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0\,
      \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0\,
      enablealign => enablealign,
      p_40_in => p_40_in,
      reset_done => reset_done,
      userclk2 => userclk2
    );
SYNC_SIGNAL_DETECT: entity work.GigEthGth7Core_sync_block
     port map (
      \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2]\ => \^rxpowerdown_reg_reg\,
      SIGNAL_DETECT_MOD => SIGNAL_DETECT_MOD,
      signal_detect => signal_detect,
      userclk2 => userclk2
    );
SYNC_STATUS_REG_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => p_40_in,
      Q => SYNC_STATUS_REG,
      R => '0'
    );
TRANSMITTER: entity work.GigEthGth7Core_TX
     port map (
      CONFIGURATION_VECTOR_REG(0) => CONFIGURATION_VECTOR_REG(1),
      D(3) => TRANSMITTER_n_2,
      D(2) => TRANSMITTER_n_3,
      D(1) => TRANSMITTER_n_4,
      D(0) => TRANSMITTER_n_5,
      \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3]\(0) => \^gmii_isolate\,
      \USE_ROCKET_IO.MGT_TX_RESET_INT_reg\ => \^mgt_tx_reset\,
      \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\ => TRANSMITTER_n_11,
      \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\ => TRANSMITTER_n_10,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(7) => TRANSMITTER_n_12,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(6) => TRANSMITTER_n_13,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(5) => TRANSMITTER_n_14,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(4) => TRANSMITTER_n_15,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(3) => TRANSMITTER_n_16,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(2) => TRANSMITTER_n_17,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(1) => TRANSMITTER_n_18,
      \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\(0) => TRANSMITTER_n_19,
      \USE_ROCKET_IO.TXCHARDISPMODE_reg\ => TRANSMITTER_n_0,
      \USE_ROCKET_IO.TXCHARDISPVAL_reg\ => TRANSMITTER_n_21,
      \USE_ROCKET_IO.TXCHARISK_reg\ => TRANSMITTER_n_9,
      \USE_ROCKET_IO.TXDATA_reg[2]\ => TRANSMITTER_n_8,
      \USE_ROCKET_IO.TXDATA_reg[2]_0\ => TRANSMITTER_n_20,
      \USE_ROCKET_IO.TXDATA_reg[3]\ => TRANSMITTER_n_7,
      \USE_ROCKET_IO.TXDATA_reg[5]\ => TRANSMITTER_n_6,
      \USE_ROCKET_IO.TXDATA_reg[7]\ => TRANSMITTER_n_1,
      gmii_tx_en => gmii_tx_en,
      gmii_tx_er => gmii_tx_er,
      gmii_txd(7 downto 0) => gmii_txd(7 downto 0),
      rxchariscomma(0) => rxchariscomma(0),
      rxcharisk(0) => rxcharisk(0),
      rxdata(7 downto 0) => rxdata(7 downto 0),
      userclk2 => userclk2
    );
\USE_ROCKET_IO.MGT_RX_RESET_INT_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => RESET_INT,
      I1 => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1]\,
      O => p_0_out
    );
\USE_ROCKET_IO.MGT_RX_RESET_INT_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
        port map (
      I0 => RX_RST_SM(2),
      I1 => RX_RST_SM(1),
      I2 => RX_RST_SM(3),
      O => MGT_RX_RESET_INT
    );
\USE_ROCKET_IO.MGT_RX_RESET_INT_reg\: unisim.vcomponents.FDSE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => MGT_RX_RESET_INT,
      Q => \^mgt_rx_reset\,
      S => p_0_out
    );
\USE_ROCKET_IO.MGT_TX_RESET_INT_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => RESET_INT,
      I1 => TXBUFERR_INT,
      O => p_1_out
    );
\USE_ROCKET_IO.MGT_TX_RESET_INT_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
        port map (
      I0 => TX_RST_SM(2),
      I1 => TX_RST_SM(1),
      I2 => TX_RST_SM(3),
      O => MGT_TX_RESET_INT
    );
\USE_ROCKET_IO.MGT_TX_RESET_INT_reg\: unisim.vcomponents.FDSE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => MGT_TX_RESET_INT,
      Q => \^mgt_tx_reset\,
      S => p_1_out
    );
\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \^mgt_rx_reset\,
      I1 => CONFIGURATION_VECTOR_REG(1),
      O => RXCLKCORCNT_INT
    );
\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => rxbufstatus(0),
      Q => \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1]\,
      R => RXCLKCORCNT_INT
    );
\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_11,
      Q => \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_10,
      Q => \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => rxclkcorcnt(0),
      Q => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0]\,
      R => RXCLKCORCNT_INT
    );
\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => rxclkcorcnt(1),
      Q => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1]\,
      R => RXCLKCORCNT_INT
    );
\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => rxclkcorcnt(2),
      Q => \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2]\,
      R => RXCLKCORCNT_INT
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_19,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_18,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_17,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_16,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_15,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_14,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_13,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_12,
      Q => \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7]\,
      R => \^mgt_rx_reset\
    );
\USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => rxdisperr(0),
      I1 => CONFIGURATION_VECTOR_REG(1),
      I2 => \^mgt_rx_reset\,
      O => \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0\
    );
\USE_ROCKET_IO.NO_1588.RXDISPERR_INT_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0\,
      Q => D,
      R => '0'
    );
\USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => rxnotintable(0),
      I1 => CONFIGURATION_VECTOR_REG(1),
      I2 => \^mgt_rx_reset\,
      O => \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0\
    );
\USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0\,
      Q => RXNOTINTABLE_INT,
      R => '0'
    );
\USE_ROCKET_IO.TXBUFERR_INT_reg\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => txbuferr,
      Q => TXBUFERR_INT,
      R => \^mgt_tx_reset\
    );
\USE_ROCKET_IO.TXCHARDISPMODE_reg\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_0,
      Q => txchardispmode,
      R => \^mgt_tx_reset\
    );
\USE_ROCKET_IO.TXCHARDISPVAL_reg\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_21,
      Q => txchardispval,
      R => '0'
    );
\USE_ROCKET_IO.TXCHARISK_reg\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_9,
      Q => txcharisk,
      R => \^mgt_tx_reset\
    );
\USE_ROCKET_IO.TXDATA_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_5,
      Q => txdata(0),
      R => '0'
    );
\USE_ROCKET_IO.TXDATA_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_4,
      Q => txdata(1),
      R => '0'
    );
\USE_ROCKET_IO.TXDATA_reg[2]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_8,
      Q => txdata(2),
      S => TRANSMITTER_n_20
    );
\USE_ROCKET_IO.TXDATA_reg[3]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_7,
      Q => txdata(3),
      S => TRANSMITTER_n_20
    );
\USE_ROCKET_IO.TXDATA_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_3,
      Q => txdata(4),
      R => '0'
    );
\USE_ROCKET_IO.TXDATA_reg[5]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_6,
      Q => txdata(5),
      S => TRANSMITTER_n_20
    );
\USE_ROCKET_IO.TXDATA_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_2,
      Q => txdata(6),
      R => '0'
    );
\USE_ROCKET_IO.TXDATA_reg[7]\: unisim.vcomponents.FDSE
     port map (
      C => userclk2,
      CE => '1',
      D => TRANSMITTER_n_1,
      Q => txdata(7),
      S => TRANSMITTER_n_20
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM is
  port (
    data_in : out STD_LOGIC;
    RXUSERRDY : out STD_LOGIC;
    gt0_gtrxreset_gt : out STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    userclk : in STD_LOGIC;
    pma_reset : in STD_LOGIC;
    reset_sync6 : in STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    data_out : in STD_LOGIC;
    cplllock : in STD_LOGIC;
    gt0_rx_cdrlocked : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM : entity is "GigEthGth7Core_RX_STARTUP_FSM";
end GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM is
  signal \FSM_sequential_rx_state[0]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_rx_state[2]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_rx_state[3]_i_3_n_0\ : STD_LOGIC;
  signal \FSM_sequential_rx_state[3]_i_6_n_0\ : STD_LOGIC;
  signal \FSM_sequential_rx_state[3]_i_8_n_0\ : STD_LOGIC;
  signal \FSM_sequential_rx_state[3]_i_9_n_0\ : STD_LOGIC;
  signal GTRXRESET : STD_LOGIC;
  signal \^rxuserrdy\ : STD_LOGIC;
  signal RXUSERRDY_i_1_n_0 : STD_LOGIC;
  signal check_tlock_max_i_1_n_0 : STD_LOGIC;
  signal check_tlock_max_reg_n_0 : STD_LOGIC;
  signal cplllock_sync : STD_LOGIC;
  signal \^data_in\ : STD_LOGIC;
  signal gtrxreset_i_i_1_n_0 : STD_LOGIC;
  signal init_wait_count : STD_LOGIC;
  signal \init_wait_count[0]_i_1__0_n_0\ : STD_LOGIC;
  signal \init_wait_count[6]_i_3__0_n_0\ : STD_LOGIC;
  signal \init_wait_count_reg__0\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal \init_wait_done_i_1__0_n_0\ : STD_LOGIC;
  signal init_wait_done_reg_n_0 : STD_LOGIC;
  signal \mmcm_lock_count[7]_i_2__0_n_0\ : STD_LOGIC;
  signal \mmcm_lock_count[7]_i_4__0_n_0\ : STD_LOGIC;
  signal \mmcm_lock_count_reg__0\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal mmcm_lock_reclocked : STD_LOGIC;
  signal \mmcm_lock_reclocked_i_2__0_n_0\ : STD_LOGIC;
  signal \p_0_in__1\ : STD_LOGIC_VECTOR ( 6 downto 1 );
  signal \p_0_in__2\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal \reset_time_out_i_2__0_n_0\ : STD_LOGIC;
  signal \reset_time_out_i_4__0_n_0\ : STD_LOGIC;
  signal reset_time_out_reg_n_0 : STD_LOGIC;
  signal \run_phase_alignment_int_i_1__0_n_0\ : STD_LOGIC;
  signal run_phase_alignment_int_reg_n_0 : STD_LOGIC;
  signal run_phase_alignment_int_s2 : STD_LOGIC;
  signal run_phase_alignment_int_s3_reg_n_0 : STD_LOGIC;
  signal rx_fsm_reset_done_int_i_5_n_0 : STD_LOGIC;
  signal rx_fsm_reset_done_int_s2 : STD_LOGIC;
  signal rx_fsm_reset_done_int_s3 : STD_LOGIC;
  signal rx_state : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of rx_state : signal is "yes";
  signal rx_state15_out : STD_LOGIC;
  signal rxresetdone_s2 : STD_LOGIC;
  signal rxresetdone_s3 : STD_LOGIC;
  signal sync_cplllock_n_0 : STD_LOGIC;
  signal sync_data_valid_n_0 : STD_LOGIC;
  signal sync_data_valid_n_1 : STD_LOGIC;
  signal sync_data_valid_n_2 : STD_LOGIC;
  signal sync_data_valid_n_3 : STD_LOGIC;
  signal sync_data_valid_n_4 : STD_LOGIC;
  signal sync_data_valid_n_5 : STD_LOGIC;
  signal sync_mmcm_lock_reclocked_n_0 : STD_LOGIC;
  signal sync_mmcm_lock_reclocked_n_1 : STD_LOGIC;
  signal time_out_100us : STD_LOGIC;
  signal time_out_100us_i_10_n_0 : STD_LOGIC;
  signal time_out_100us_i_1_n_0 : STD_LOGIC;
  signal time_out_100us_i_4_n_0 : STD_LOGIC;
  signal time_out_100us_i_5_n_0 : STD_LOGIC;
  signal time_out_100us_i_6_n_0 : STD_LOGIC;
  signal time_out_100us_i_7_n_0 : STD_LOGIC;
  signal time_out_100us_i_8_n_0 : STD_LOGIC;
  signal time_out_100us_i_9_n_0 : STD_LOGIC;
  signal time_out_100us_reg_i_2_n_1 : STD_LOGIC;
  signal time_out_100us_reg_i_2_n_2 : STD_LOGIC;
  signal time_out_100us_reg_i_2_n_3 : STD_LOGIC;
  signal time_out_100us_reg_i_3_n_0 : STD_LOGIC;
  signal time_out_100us_reg_i_3_n_1 : STD_LOGIC;
  signal time_out_100us_reg_i_3_n_2 : STD_LOGIC;
  signal time_out_100us_reg_i_3_n_3 : STD_LOGIC;
  signal time_out_1us : STD_LOGIC;
  signal time_out_1us_i_10_n_0 : STD_LOGIC;
  signal time_out_1us_i_1_n_0 : STD_LOGIC;
  signal time_out_1us_i_4_n_0 : STD_LOGIC;
  signal time_out_1us_i_5_n_0 : STD_LOGIC;
  signal time_out_1us_i_6_n_0 : STD_LOGIC;
  signal time_out_1us_i_7_n_0 : STD_LOGIC;
  signal time_out_1us_i_8_n_0 : STD_LOGIC;
  signal time_out_1us_i_9_n_0 : STD_LOGIC;
  signal time_out_1us_reg_i_2_n_1 : STD_LOGIC;
  signal time_out_1us_reg_i_2_n_2 : STD_LOGIC;
  signal time_out_1us_reg_i_2_n_3 : STD_LOGIC;
  signal time_out_1us_reg_i_3_n_0 : STD_LOGIC;
  signal time_out_1us_reg_i_3_n_1 : STD_LOGIC;
  signal time_out_1us_reg_i_3_n_2 : STD_LOGIC;
  signal time_out_1us_reg_i_3_n_3 : STD_LOGIC;
  signal time_out_2ms : STD_LOGIC;
  signal \time_out_2ms_i_1__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_10__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_11__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_12__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_13_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_14__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_15__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_1__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_4__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_5__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_6__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_7_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_9_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_2__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_3__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_4__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_5__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_2__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_3__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_4__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_5_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_2__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_3__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_4__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_5__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_2__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_3__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_4__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_5__0_n_0\ : STD_LOGIC;
  signal time_out_counter_reg : STD_LOGIC_VECTOR ( 19 downto 0 );
  signal \time_out_counter_reg[0]_i_2__0_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2__0_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8__0_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1__0_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1__0_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1__0_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1__0_n_7\ : STD_LOGIC;
  signal \time_out_wait_bypass_i_1__0_n_0\ : STD_LOGIC;
  signal time_out_wait_bypass_reg_n_0 : STD_LOGIC;
  signal time_out_wait_bypass_s2 : STD_LOGIC;
  signal time_out_wait_bypass_s3 : STD_LOGIC;
  signal time_tlock_max : STD_LOGIC;
  signal time_tlock_max1 : STD_LOGIC;
  signal time_tlock_max_i_10_n_0 : STD_LOGIC;
  signal time_tlock_max_i_11_n_0 : STD_LOGIC;
  signal time_tlock_max_i_12_n_0 : STD_LOGIC;
  signal time_tlock_max_i_13_n_0 : STD_LOGIC;
  signal time_tlock_max_i_14_n_0 : STD_LOGIC;
  signal time_tlock_max_i_15_n_0 : STD_LOGIC;
  signal time_tlock_max_i_16_n_0 : STD_LOGIC;
  signal time_tlock_max_i_17_n_0 : STD_LOGIC;
  signal time_tlock_max_i_18_n_0 : STD_LOGIC;
  signal time_tlock_max_i_19_n_0 : STD_LOGIC;
  signal time_tlock_max_i_1_n_0 : STD_LOGIC;
  signal time_tlock_max_i_20_n_0 : STD_LOGIC;
  signal time_tlock_max_i_21_n_0 : STD_LOGIC;
  signal time_tlock_max_i_22_n_0 : STD_LOGIC;
  signal time_tlock_max_i_4_n_0 : STD_LOGIC;
  signal \time_tlock_max_i_5__0_n_0\ : STD_LOGIC;
  signal \time_tlock_max_i_6__0_n_0\ : STD_LOGIC;
  signal \time_tlock_max_i_7__0_n_0\ : STD_LOGIC;
  signal time_tlock_max_i_9_n_0 : STD_LOGIC;
  signal \time_tlock_max_reg_i_2__0_n_3\ : STD_LOGIC;
  signal \time_tlock_max_reg_i_3__0_n_0\ : STD_LOGIC;
  signal \time_tlock_max_reg_i_3__0_n_1\ : STD_LOGIC;
  signal \time_tlock_max_reg_i_3__0_n_2\ : STD_LOGIC;
  signal \time_tlock_max_reg_i_3__0_n_3\ : STD_LOGIC;
  signal time_tlock_max_reg_i_8_n_0 : STD_LOGIC;
  signal time_tlock_max_reg_i_8_n_1 : STD_LOGIC;
  signal time_tlock_max_reg_i_8_n_2 : STD_LOGIC;
  signal time_tlock_max_reg_i_8_n_3 : STD_LOGIC;
  signal wait_bypass_count : STD_LOGIC;
  signal wait_bypass_count1 : STD_LOGIC;
  signal \wait_bypass_count[0]_i_10__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_1__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_5__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_6__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_7__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_8__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_9__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[12]_i_2__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_2__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_3__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_4__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_5__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_2__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_3__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_4__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_5__0_n_0\ : STD_LOGIC;
  signal wait_bypass_count_reg : STD_LOGIC_VECTOR ( 12 downto 0 );
  signal \wait_bypass_count_reg[0]_i_3__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3__0_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1__0_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1__0_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1__0_n_7\ : STD_LOGIC;
  signal \wait_time_cnt0__0\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal \wait_time_cnt[6]_i_1__0_n_0\ : STD_LOGIC;
  signal \wait_time_cnt[6]_i_2__0_n_0\ : STD_LOGIC;
  signal \wait_time_cnt[6]_i_4__0_n_0\ : STD_LOGIC;
  signal \wait_time_cnt_reg__0\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal NLW_time_out_100us_reg_i_2_CO_UNCONNECTED : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_time_out_100us_reg_i_2_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_out_100us_reg_i_3_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_out_1us_reg_i_2_CO_UNCONNECTED : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_time_out_1us_reg_i_2_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_out_1us_reg_i_3_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[0]_i_3__0_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_time_out_counter_reg[0]_i_3__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[0]_i_8__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[16]_i_1__0_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_time_tlock_max_reg_i_2__0_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 2 );
  signal \NLW_time_tlock_max_reg_i_2__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_tlock_max_reg_i_3__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_tlock_max_reg_i_8_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_wait_bypass_count_reg[12]_i_1__0_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_wait_bypass_count_reg[12]_i_1__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 1 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_rx_state[2]_i_2\ : label is "soft_lutpair43";
  attribute SOFT_HLUTNM of \FSM_sequential_rx_state[3]_i_9\ : label is "soft_lutpair47";
  attribute KEEP : string;
  attribute KEEP of \FSM_sequential_rx_state_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_rx_state_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_rx_state_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_rx_state_reg[3]\ : label is "yes";
  attribute SOFT_HLUTNM of \init_wait_count[0]_i_1__0\ : label is "soft_lutpair38";
  attribute SOFT_HLUTNM of \init_wait_count[1]_i_1__0\ : label is "soft_lutpair45";
  attribute SOFT_HLUTNM of \init_wait_count[2]_i_1__0\ : label is "soft_lutpair45";
  attribute SOFT_HLUTNM of \init_wait_count[3]_i_1__0\ : label is "soft_lutpair39";
  attribute SOFT_HLUTNM of \init_wait_count[4]_i_1__0\ : label is "soft_lutpair39";
  attribute SOFT_HLUTNM of \init_wait_count[6]_i_2__0\ : label is "soft_lutpair38";
  attribute SOFT_HLUTNM of \mmcm_lock_count[1]_i_1__0\ : label is "soft_lutpair44";
  attribute SOFT_HLUTNM of \mmcm_lock_count[2]_i_1__0\ : label is "soft_lutpair42";
  attribute SOFT_HLUTNM of \mmcm_lock_count[3]_i_1__0\ : label is "soft_lutpair42";
  attribute SOFT_HLUTNM of \mmcm_lock_count[4]_i_1__0\ : label is "soft_lutpair40";
  attribute SOFT_HLUTNM of \mmcm_lock_count[7]_i_4__0\ : label is "soft_lutpair44";
  attribute SOFT_HLUTNM of \mmcm_lock_reclocked_i_2__0\ : label is "soft_lutpair40";
  attribute SOFT_HLUTNM of time_out_100us_i_1 : label is "soft_lutpair47";
  attribute SOFT_HLUTNM of time_tlock_max_i_1 : label is "soft_lutpair43";
  attribute SOFT_HLUTNM of \wait_time_cnt[0]_i_1__0\ : label is "soft_lutpair46";
  attribute SOFT_HLUTNM of \wait_time_cnt[1]_i_1__0\ : label is "soft_lutpair46";
  attribute SOFT_HLUTNM of \wait_time_cnt[3]_i_1__0\ : label is "soft_lutpair41";
  attribute SOFT_HLUTNM of \wait_time_cnt[4]_i_1__0\ : label is "soft_lutpair41";
begin
  RXUSERRDY <= \^rxuserrdy\;
  data_in <= \^data_in\;
\FSM_sequential_rx_state[0]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AA2A202AAA2A2A2A"
    )
        port map (
      I0 => rx_state(0),
      I1 => time_out_2ms,
      I2 => rx_state(1),
      I3 => rx_state(2),
      I4 => reset_time_out_reg_n_0,
      I5 => time_tlock_max,
      O => \FSM_sequential_rx_state[0]_i_2_n_0\
    );
\FSM_sequential_rx_state[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000110CFF00"
    )
        port map (
      I0 => rx_state15_out,
      I1 => rx_state(1),
      I2 => time_out_2ms,
      I3 => rx_state(2),
      I4 => rx_state(0),
      I5 => rx_state(3),
      O => \FSM_sequential_rx_state[2]_i_1_n_0\
    );
\FSM_sequential_rx_state[2]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_tlock_max,
      I1 => reset_time_out_reg_n_0,
      O => rx_state15_out
    );
\FSM_sequential_rx_state[3]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00CA00CA00CAFFCA"
    )
        port map (
      I0 => init_wait_done_reg_n_0,
      I1 => gt0_rx_cdrlocked,
      I2 => rx_state(2),
      I3 => rx_state(1),
      I4 => \wait_time_cnt_reg__0\(6),
      I5 => \wait_time_cnt[6]_i_4__0_n_0\,
      O => \FSM_sequential_rx_state[3]_i_3_n_0\
    );
\FSM_sequential_rx_state[3]_i_6\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => rx_state(3),
      I1 => rx_state(0),
      O => \FSM_sequential_rx_state[3]_i_6_n_0\
    );
\FSM_sequential_rx_state[3]_i_8\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"CFEFCFEFC0EFC0E0"
    )
        port map (
      I0 => time_out_2ms,
      I1 => rxresetdone_s3,
      I2 => rx_state(1),
      I3 => reset_time_out_reg_n_0,
      I4 => time_tlock_max,
      I5 => mmcm_lock_reclocked,
      O => \FSM_sequential_rx_state[3]_i_8_n_0\
    );
\FSM_sequential_rx_state[3]_i_9\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_100us,
      I1 => reset_time_out_reg_n_0,
      O => \FSM_sequential_rx_state[3]_i_9_n_0\
    );
\FSM_sequential_rx_state_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_0,
      D => sync_data_valid_n_4,
      Q => rx_state(0),
      R => pma_reset
    );
\FSM_sequential_rx_state_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_0,
      D => sync_data_valid_n_3,
      Q => rx_state(1),
      R => pma_reset
    );
\FSM_sequential_rx_state_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_0,
      D => \FSM_sequential_rx_state[2]_i_1_n_0\,
      Q => rx_state(2),
      R => pma_reset
    );
\FSM_sequential_rx_state_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_0,
      D => sync_data_valid_n_2,
      Q => rx_state(3),
      R => pma_reset
    );
RXUSERRDY_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFB4000"
    )
        port map (
      I0 => rx_state(3),
      I1 => rx_state(0),
      I2 => rx_state(2),
      I3 => rx_state(1),
      I4 => \^rxuserrdy\,
      O => RXUSERRDY_i_1_n_0
    );
RXUSERRDY_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => RXUSERRDY_i_1_n_0,
      Q => \^rxuserrdy\,
      R => pma_reset
    );
check_tlock_max_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFEF0020"
    )
        port map (
      I0 => rx_state(2),
      I1 => rx_state(1),
      I2 => rx_state(0),
      I3 => rx_state(3),
      I4 => check_tlock_max_reg_n_0,
      O => check_tlock_max_i_1_n_0
    );
check_tlock_max_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => check_tlock_max_i_1_n_0,
      Q => check_tlock_max_reg_n_0,
      R => pma_reset
    );
gt0_gtrxreset_gt_d1_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"EA"
    )
        port map (
      I0 => GTRXRESET,
      I1 => \^data_in\,
      I2 => reset_sync6,
      O => gt0_gtrxreset_gt
    );
gtrxreset_i_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FEFF0004"
    )
        port map (
      I0 => rx_state(3),
      I1 => rx_state(0),
      I2 => rx_state(1),
      I3 => rx_state(2),
      I4 => GTRXRESET,
      O => gtrxreset_i_i_1_n_0
    );
gtrxreset_i_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => gtrxreset_i_i_1_n_0,
      Q => GTRXRESET,
      R => pma_reset
    );
\init_wait_count[0]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      O => \init_wait_count[0]_i_1__0_n_0\
    );
\init_wait_count[1]_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => \init_wait_count_reg__0\(1),
      I1 => \init_wait_count_reg__0\(0),
      O => \p_0_in__1\(1)
    );
\init_wait_count[2]_i_1__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"78"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      I1 => \init_wait_count_reg__0\(1),
      I2 => \init_wait_count_reg__0\(2),
      O => \p_0_in__1\(2)
    );
\init_wait_count[3]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"6AAA"
    )
        port map (
      I0 => \init_wait_count_reg__0\(3),
      I1 => \init_wait_count_reg__0\(2),
      I2 => \init_wait_count_reg__0\(1),
      I3 => \init_wait_count_reg__0\(0),
      O => \p_0_in__1\(3)
    );
\init_wait_count[4]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"6AAAAAAA"
    )
        port map (
      I0 => \init_wait_count_reg__0\(4),
      I1 => \init_wait_count_reg__0\(1),
      I2 => \init_wait_count_reg__0\(2),
      I3 => \init_wait_count_reg__0\(3),
      I4 => \init_wait_count_reg__0\(0),
      O => \p_0_in__1\(4)
    );
\init_wait_count[5]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFF80000000"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      I1 => \init_wait_count_reg__0\(3),
      I2 => \init_wait_count_reg__0\(2),
      I3 => \init_wait_count_reg__0\(1),
      I4 => \init_wait_count_reg__0\(4),
      I5 => \init_wait_count_reg__0\(5),
      O => \p_0_in__1\(5)
    );
\init_wait_count[6]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFEFFF"
    )
        port map (
      I0 => \init_wait_count[6]_i_3__0_n_0\,
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count_reg__0\(6),
      I3 => \init_wait_count_reg__0\(5),
      I4 => \init_wait_count_reg__0\(0),
      O => init_wait_count
    );
\init_wait_count[6]_i_2__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"F7FF0800"
    )
        port map (
      I0 => \init_wait_count_reg__0\(5),
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count[6]_i_3__0_n_0\,
      I3 => \init_wait_count_reg__0\(0),
      I4 => \init_wait_count_reg__0\(6),
      O => \p_0_in__1\(6)
    );
\init_wait_count[6]_i_3__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
        port map (
      I0 => \init_wait_count_reg__0\(1),
      I1 => \init_wait_count_reg__0\(2),
      I2 => \init_wait_count_reg__0\(3),
      O => \init_wait_count[6]_i_3__0_n_0\
    );
\init_wait_count_reg[0]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \init_wait_count[0]_i_1__0_n_0\,
      Q => \init_wait_count_reg__0\(0)
    );
\init_wait_count_reg[1]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(1),
      Q => \init_wait_count_reg__0\(1)
    );
\init_wait_count_reg[2]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(2),
      Q => \init_wait_count_reg__0\(2)
    );
\init_wait_count_reg[3]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(3),
      Q => \init_wait_count_reg__0\(3)
    );
\init_wait_count_reg[4]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(4),
      Q => \init_wait_count_reg__0\(4)
    );
\init_wait_count_reg[5]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(5),
      Q => \init_wait_count_reg__0\(5)
    );
\init_wait_count_reg[6]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \p_0_in__1\(6),
      Q => \init_wait_count_reg__0\(6)
    );
\init_wait_done_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFF01000000"
    )
        port map (
      I0 => \init_wait_count[6]_i_3__0_n_0\,
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count_reg__0\(0),
      I3 => \init_wait_count_reg__0\(6),
      I4 => \init_wait_count_reg__0\(5),
      I5 => init_wait_done_reg_n_0,
      O => \init_wait_done_i_1__0_n_0\
    );
init_wait_done_reg: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      CLR => pma_reset,
      D => \init_wait_done_i_1__0_n_0\,
      Q => init_wait_done_reg_n_0
    );
\mmcm_lock_count[0]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(0),
      O => \p_0_in__2\(0)
    );
\mmcm_lock_count[1]_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(0),
      I1 => \mmcm_lock_count_reg__0\(1),
      O => \p_0_in__2\(1)
    );
\mmcm_lock_count[2]_i_1__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"6A"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(2),
      I1 => \mmcm_lock_count_reg__0\(1),
      I2 => \mmcm_lock_count_reg__0\(0),
      O => \p_0_in__2\(2)
    );
\mmcm_lock_count[3]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"6AAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(3),
      I1 => \mmcm_lock_count_reg__0\(0),
      I2 => \mmcm_lock_count_reg__0\(1),
      I3 => \mmcm_lock_count_reg__0\(2),
      O => \p_0_in__2\(3)
    );
\mmcm_lock_count[4]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"6AAAAAAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count_reg__0\(0),
      I3 => \mmcm_lock_count_reg__0\(1),
      I4 => \mmcm_lock_count_reg__0\(2),
      O => \p_0_in__2\(4)
    );
\mmcm_lock_count[5]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"6AAAAAAAAAAAAAAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(5),
      I1 => \mmcm_lock_count_reg__0\(2),
      I2 => \mmcm_lock_count_reg__0\(1),
      I3 => \mmcm_lock_count_reg__0\(0),
      I4 => \mmcm_lock_count_reg__0\(3),
      I5 => \mmcm_lock_count_reg__0\(4),
      O => \p_0_in__2\(5)
    );
\mmcm_lock_count[6]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"7FFF8000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count[7]_i_4__0_n_0\,
      I3 => \mmcm_lock_count_reg__0\(5),
      I4 => \mmcm_lock_count_reg__0\(6),
      O => \p_0_in__2\(6)
    );
\mmcm_lock_count[7]_i_2__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFFFFFFFFFF"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count[7]_i_4__0_n_0\,
      I3 => \mmcm_lock_count_reg__0\(5),
      I4 => \mmcm_lock_count_reg__0\(6),
      I5 => \mmcm_lock_count_reg__0\(7),
      O => \mmcm_lock_count[7]_i_2__0_n_0\
    );
\mmcm_lock_count[7]_i_3__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFF80000000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(6),
      I1 => \mmcm_lock_count_reg__0\(5),
      I2 => \mmcm_lock_count[7]_i_4__0_n_0\,
      I3 => \mmcm_lock_count_reg__0\(3),
      I4 => \mmcm_lock_count_reg__0\(4),
      I5 => \mmcm_lock_count_reg__0\(7),
      O => \p_0_in__2\(7)
    );
\mmcm_lock_count[7]_i_4__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(2),
      I1 => \mmcm_lock_count_reg__0\(1),
      I2 => \mmcm_lock_count_reg__0\(0),
      O => \mmcm_lock_count[7]_i_4__0_n_0\
    );
\mmcm_lock_count_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(0),
      Q => \mmcm_lock_count_reg__0\(0),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(1),
      Q => \mmcm_lock_count_reg__0\(1),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(2),
      Q => \mmcm_lock_count_reg__0\(2),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(3),
      Q => \mmcm_lock_count_reg__0\(3),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(4),
      Q => \mmcm_lock_count_reg__0\(4),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(5),
      Q => \mmcm_lock_count_reg__0\(5),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(6),
      Q => \mmcm_lock_count_reg__0\(6),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2__0_n_0\,
      D => \p_0_in__2\(7),
      Q => \mmcm_lock_count_reg__0\(7),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_reclocked_i_2__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"80000000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count_reg__0\(0),
      I3 => \mmcm_lock_count_reg__0\(1),
      I4 => \mmcm_lock_count_reg__0\(2),
      O => \mmcm_lock_reclocked_i_2__0_n_0\
    );
mmcm_lock_reclocked_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => sync_mmcm_lock_reclocked_n_1,
      Q => mmcm_lock_reclocked,
      R => '0'
    );
\reset_time_out_i_2__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"707F7070707F7F7F"
    )
        port map (
      I0 => rxresetdone_s3,
      I1 => rx_state(2),
      I2 => rx_state(1),
      I3 => mmcm_lock_reclocked,
      I4 => rx_state(0),
      I5 => gt0_rx_cdrlocked,
      O => \reset_time_out_i_2__0_n_0\
    );
\reset_time_out_i_4__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"030FCCEC"
    )
        port map (
      I0 => gt0_rx_cdrlocked,
      I1 => rx_state(0),
      I2 => rx_state(2),
      I3 => rx_state(1),
      I4 => rx_state(3),
      O => \reset_time_out_i_4__0_n_0\
    );
reset_time_out_reg: unisim.vcomponents.FDSE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => sync_data_valid_n_0,
      Q => reset_time_out_reg_n_0,
      S => pma_reset
    );
\run_phase_alignment_int_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFD0010"
    )
        port map (
      I0 => rx_state(0),
      I1 => rx_state(2),
      I2 => rx_state(3),
      I3 => rx_state(1),
      I4 => run_phase_alignment_int_reg_n_0,
      O => \run_phase_alignment_int_i_1__0_n_0\
    );
run_phase_alignment_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \run_phase_alignment_int_i_1__0_n_0\,
      Q => run_phase_alignment_int_reg_n_0,
      R => pma_reset
    );
run_phase_alignment_int_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => run_phase_alignment_int_s2,
      Q => run_phase_alignment_int_s3_reg_n_0,
      R => '0'
    );
rx_fsm_reset_done_int_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => rx_state(3),
      I1 => rx_state(2),
      I2 => rx_state(0),
      O => rx_fsm_reset_done_int_i_5_n_0
    );
rx_fsm_reset_done_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => sync_data_valid_n_1,
      Q => \^data_in\,
      R => pma_reset
    );
rx_fsm_reset_done_int_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => rx_fsm_reset_done_int_s2,
      Q => rx_fsm_reset_done_int_s3,
      R => '0'
    );
rxresetdone_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => rxresetdone_s2,
      Q => rxresetdone_s3,
      R => '0'
    );
sync_RXRESETDONE: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_14
     port map (
      \cpllpd_wait_reg[95]\ => \cpllpd_wait_reg[95]\,
      data_out => rxresetdone_s2,
      independent_clock_bufg => independent_clock_bufg
    );
sync_cplllock: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_15
     port map (
      E(0) => sync_cplllock_n_0,
      \FSM_sequential_rx_state_reg[0]\ => sync_data_valid_n_5,
      cplllock => cplllock,
      data_out => cplllock_sync,
      independent_clock_bufg => independent_clock_bufg,
      init_wait_done_reg => \FSM_sequential_rx_state[3]_i_3_n_0\,
      \out\(3 downto 0) => rx_state(3 downto 0),
      time_out_2ms => time_out_2ms,
      time_out_2ms_reg => \FSM_sequential_rx_state[3]_i_8_n_0\
    );
sync_data_valid: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_16
     port map (
      D(2) => sync_data_valid_n_2,
      D(1) => sync_data_valid_n_3,
      D(0) => sync_data_valid_n_4,
      \FSM_sequential_rx_state_reg[0]\ => sync_data_valid_n_5,
      \FSM_sequential_rx_state_reg[0]_0\ => \FSM_sequential_rx_state[0]_i_2_n_0\,
      \FSM_sequential_rx_state_reg[3]\ => \FSM_sequential_rx_state[3]_i_6_n_0\,
      \FSM_sequential_rx_state_reg[3]_0\ => rx_fsm_reset_done_int_i_5_n_0,
      cplllock_sync => cplllock_sync,
      data_in => \^data_in\,
      data_out => data_out,
      gt0_rx_cdrlocked_reg => \reset_time_out_i_4__0_n_0\,
      independent_clock_bufg => independent_clock_bufg,
      \out\(3 downto 0) => rx_state(3 downto 0),
      reset_time_out_reg => sync_data_valid_n_0,
      reset_time_out_reg_0 => reset_time_out_reg_n_0,
      rx_fsm_reset_done_int_reg => sync_data_valid_n_1,
      rx_state15_out => rx_state15_out,
      rxresetdone_s3_reg => \reset_time_out_i_2__0_n_0\,
      time_out_100us => time_out_100us,
      time_out_100us_reg => \FSM_sequential_rx_state[3]_i_9_n_0\,
      time_out_1us => time_out_1us,
      time_out_2ms => time_out_2ms,
      time_out_wait_bypass_s3 => time_out_wait_bypass_s3
    );
sync_mmcm_lock_reclocked: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_17
     port map (
      Q(2 downto 0) => \mmcm_lock_count_reg__0\(7 downto 5),
      SR(0) => sync_mmcm_lock_reclocked_n_0,
      independent_clock_bufg => independent_clock_bufg,
      \mmcm_lock_count_reg[4]\ => \mmcm_lock_reclocked_i_2__0_n_0\,
      mmcm_lock_reclocked => mmcm_lock_reclocked,
      mmcm_lock_reclocked_reg => sync_mmcm_lock_reclocked_n_1,
      mmcm_locked => mmcm_locked
    );
sync_run_phase_alignment_int: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_18
     port map (
      data_in => run_phase_alignment_int_reg_n_0,
      data_out => run_phase_alignment_int_s2,
      userclk => userclk
    );
sync_rx_fsm_reset_done_int: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_19
     port map (
      data_in => \^data_in\,
      data_out => rx_fsm_reset_done_int_s2,
      userclk => userclk
    );
sync_time_out_wait_bypass: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_20
     port map (
      data_in => time_out_wait_bypass_reg_n_0,
      data_out => time_out_wait_bypass_s2,
      independent_clock_bufg => independent_clock_bufg
    );
time_out_100us_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_100us_reg_i_2_n_1,
      I1 => time_out_100us,
      O => time_out_100us_i_1_n_0
    );
time_out_100us_i_10: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(1),
      I1 => time_out_counter_reg(0),
      I2 => time_out_counter_reg(2),
      O => time_out_100us_i_10_n_0
    );
time_out_100us_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(18),
      I1 => time_out_counter_reg(19),
      O => time_out_100us_i_4_n_0
    );
time_out_100us_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      I2 => time_out_counter_reg(15),
      O => time_out_100us_i_5_n_0
    );
time_out_100us_i_6: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => time_out_counter_reg(14),
      I1 => time_out_counter_reg(13),
      I2 => time_out_counter_reg(12),
      O => time_out_100us_i_6_n_0
    );
time_out_100us_i_7: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => time_out_counter_reg(11),
      I1 => time_out_counter_reg(10),
      I2 => time_out_counter_reg(9),
      O => time_out_100us_i_7_n_0
    );
time_out_100us_i_8: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(6),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(8),
      O => time_out_100us_i_8_n_0
    );
time_out_100us_i_9: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(4),
      I1 => time_out_counter_reg(5),
      I2 => time_out_counter_reg(3),
      O => time_out_100us_i_9_n_0
    );
time_out_100us_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_100us_i_1_n_0,
      Q => time_out_100us,
      R => reset_time_out_reg_n_0
    );
time_out_100us_reg_i_2: unisim.vcomponents.CARRY4
     port map (
      CI => time_out_100us_reg_i_3_n_0,
      CO(3) => NLW_time_out_100us_reg_i_2_CO_UNCONNECTED(3),
      CO(2) => time_out_100us_reg_i_2_n_1,
      CO(1) => time_out_100us_reg_i_2_n_2,
      CO(0) => time_out_100us_reg_i_2_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_100us_reg_i_2_O_UNCONNECTED(3 downto 0),
      S(3) => '0',
      S(2) => time_out_100us_i_4_n_0,
      S(1) => time_out_100us_i_5_n_0,
      S(0) => time_out_100us_i_6_n_0
    );
time_out_100us_reg_i_3: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => time_out_100us_reg_i_3_n_0,
      CO(2) => time_out_100us_reg_i_3_n_1,
      CO(1) => time_out_100us_reg_i_3_n_2,
      CO(0) => time_out_100us_reg_i_3_n_3,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_100us_reg_i_3_O_UNCONNECTED(3 downto 0),
      S(3) => time_out_100us_i_7_n_0,
      S(2) => time_out_100us_i_8_n_0,
      S(1) => time_out_100us_i_9_n_0,
      S(0) => time_out_100us_i_10_n_0
    );
time_out_1us_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_1us_reg_i_2_n_1,
      I1 => time_out_1us,
      O => time_out_1us_i_1_n_0
    );
time_out_1us_i_10: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(1),
      I1 => time_out_counter_reg(0),
      I2 => time_out_counter_reg(2),
      O => time_out_1us_i_10_n_0
    );
time_out_1us_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(18),
      I1 => time_out_counter_reg(19),
      O => time_out_1us_i_4_n_0
    );
time_out_1us_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      I2 => time_out_counter_reg(15),
      O => time_out_1us_i_5_n_0
    );
time_out_1us_i_6: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(13),
      I1 => time_out_counter_reg(12),
      I2 => time_out_counter_reg(14),
      O => time_out_1us_i_6_n_0
    );
time_out_1us_i_7: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(11),
      I1 => time_out_counter_reg(10),
      I2 => time_out_counter_reg(9),
      O => time_out_1us_i_7_n_0
    );
time_out_1us_i_8: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(6),
      O => time_out_1us_i_8_n_0
    );
time_out_1us_i_9: unisim.vcomponents.LUT3
    generic map(
      INIT => X"10"
    )
        port map (
      I0 => time_out_counter_reg(5),
      I1 => time_out_counter_reg(4),
      I2 => time_out_counter_reg(3),
      O => time_out_1us_i_9_n_0
    );
time_out_1us_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_1us_i_1_n_0,
      Q => time_out_1us,
      R => reset_time_out_reg_n_0
    );
time_out_1us_reg_i_2: unisim.vcomponents.CARRY4
     port map (
      CI => time_out_1us_reg_i_3_n_0,
      CO(3) => NLW_time_out_1us_reg_i_2_CO_UNCONNECTED(3),
      CO(2) => time_out_1us_reg_i_2_n_1,
      CO(1) => time_out_1us_reg_i_2_n_2,
      CO(0) => time_out_1us_reg_i_2_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_1us_reg_i_2_O_UNCONNECTED(3 downto 0),
      S(3) => '0',
      S(2) => time_out_1us_i_4_n_0,
      S(1) => time_out_1us_i_5_n_0,
      S(0) => time_out_1us_i_6_n_0
    );
time_out_1us_reg_i_3: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => time_out_1us_reg_i_3_n_0,
      CO(2) => time_out_1us_reg_i_3_n_1,
      CO(1) => time_out_1us_reg_i_3_n_2,
      CO(0) => time_out_1us_reg_i_3_n_3,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_1us_reg_i_3_O_UNCONNECTED(3 downto 0),
      S(3) => time_out_1us_i_7_n_0,
      S(2) => time_out_1us_i_8_n_0,
      S(1) => time_out_1us_i_9_n_0,
      S(0) => time_out_1us_i_10_n_0
    );
\time_out_2ms_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \time_out_counter_reg[0]_i_3__0_n_1\,
      I1 => time_out_2ms,
      O => \time_out_2ms_i_1__0_n_0\
    );
time_out_2ms_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \time_out_2ms_i_1__0_n_0\,
      Q => time_out_2ms,
      R => reset_time_out_reg_n_0
    );
\time_out_counter[0]_i_10__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      I2 => time_out_counter_reg(15),
      O => \time_out_counter[0]_i_10__0_n_0\
    );
\time_out_counter[0]_i_11__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(14),
      I1 => time_out_counter_reg(13),
      I2 => time_out_counter_reg(12),
      O => \time_out_counter[0]_i_11__0_n_0\
    );
\time_out_counter[0]_i_12__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => time_out_counter_reg(11),
      I1 => time_out_counter_reg(10),
      I2 => time_out_counter_reg(9),
      O => \time_out_counter[0]_i_12__0_n_0\
    );
\time_out_counter[0]_i_13\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(6),
      O => \time_out_counter[0]_i_13_n_0\
    );
\time_out_counter[0]_i_14__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(5),
      I1 => time_out_counter_reg(4),
      I2 => time_out_counter_reg(3),
      O => \time_out_counter[0]_i_14__0_n_0\
    );
\time_out_counter[0]_i_15__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(1),
      I1 => time_out_counter_reg(0),
      I2 => time_out_counter_reg(2),
      O => \time_out_counter[0]_i_15__0_n_0\
    );
\time_out_counter[0]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \time_out_counter_reg[0]_i_3__0_n_1\,
      O => \time_out_counter[0]_i_1__0_n_0\
    );
\time_out_counter[0]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(3),
      O => \time_out_counter[0]_i_4__0_n_0\
    );
\time_out_counter[0]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(2),
      O => \time_out_counter[0]_i_5__0_n_0\
    );
\time_out_counter[0]_i_6__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(1),
      O => \time_out_counter[0]_i_6__0_n_0\
    );
\time_out_counter[0]_i_7\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(0),
      O => \time_out_counter[0]_i_7_n_0\
    );
\time_out_counter[0]_i_9\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(19),
      I1 => time_out_counter_reg(18),
      O => \time_out_counter[0]_i_9_n_0\
    );
\time_out_counter[12]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(15),
      O => \time_out_counter[12]_i_2__0_n_0\
    );
\time_out_counter[12]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(14),
      O => \time_out_counter[12]_i_3__0_n_0\
    );
\time_out_counter[12]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(13),
      O => \time_out_counter[12]_i_4__0_n_0\
    );
\time_out_counter[12]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(12),
      O => \time_out_counter[12]_i_5__0_n_0\
    );
\time_out_counter[16]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(19),
      O => \time_out_counter[16]_i_2__0_n_0\
    );
\time_out_counter[16]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(18),
      O => \time_out_counter[16]_i_3__0_n_0\
    );
\time_out_counter[16]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(17),
      O => \time_out_counter[16]_i_4__0_n_0\
    );
\time_out_counter[16]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(16),
      O => \time_out_counter[16]_i_5_n_0\
    );
\time_out_counter[4]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(7),
      O => \time_out_counter[4]_i_2__0_n_0\
    );
\time_out_counter[4]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(6),
      O => \time_out_counter[4]_i_3__0_n_0\
    );
\time_out_counter[4]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(5),
      O => \time_out_counter[4]_i_4__0_n_0\
    );
\time_out_counter[4]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(4),
      O => \time_out_counter[4]_i_5__0_n_0\
    );
\time_out_counter[8]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(11),
      O => \time_out_counter[8]_i_2__0_n_0\
    );
\time_out_counter[8]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(10),
      O => \time_out_counter[8]_i_3__0_n_0\
    );
\time_out_counter[8]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(9),
      O => \time_out_counter[8]_i_4__0_n_0\
    );
\time_out_counter[8]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(8),
      O => \time_out_counter[8]_i_5__0_n_0\
    );
\time_out_counter_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[0]_i_2__0_n_7\,
      Q => time_out_counter_reg(0),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[0]_i_2__0\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \time_out_counter_reg[0]_i_2__0_n_0\,
      CO(2) => \time_out_counter_reg[0]_i_2__0_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_2__0_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_2__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \time_out_counter_reg[0]_i_2__0_n_4\,
      O(2) => \time_out_counter_reg[0]_i_2__0_n_5\,
      O(1) => \time_out_counter_reg[0]_i_2__0_n_6\,
      O(0) => \time_out_counter_reg[0]_i_2__0_n_7\,
      S(3) => \time_out_counter[0]_i_4__0_n_0\,
      S(2) => \time_out_counter[0]_i_5__0_n_0\,
      S(1) => \time_out_counter[0]_i_6__0_n_0\,
      S(0) => \time_out_counter[0]_i_7_n_0\
    );
\time_out_counter_reg[0]_i_3__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[0]_i_8__0_n_0\,
      CO(3) => \NLW_time_out_counter_reg[0]_i_3__0_CO_UNCONNECTED\(3),
      CO(2) => \time_out_counter_reg[0]_i_3__0_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_3__0_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_3__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_time_out_counter_reg[0]_i_3__0_O_UNCONNECTED\(3 downto 0),
      S(3) => '0',
      S(2) => \time_out_counter[0]_i_9_n_0\,
      S(1) => \time_out_counter[0]_i_10__0_n_0\,
      S(0) => \time_out_counter[0]_i_11__0_n_0\
    );
\time_out_counter_reg[0]_i_8__0\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \time_out_counter_reg[0]_i_8__0_n_0\,
      CO(2) => \time_out_counter_reg[0]_i_8__0_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_8__0_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_8__0_n_3\,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_time_out_counter_reg[0]_i_8__0_O_UNCONNECTED\(3 downto 0),
      S(3) => \time_out_counter[0]_i_12__0_n_0\,
      S(2) => \time_out_counter[0]_i_13_n_0\,
      S(1) => \time_out_counter[0]_i_14__0_n_0\,
      S(0) => \time_out_counter[0]_i_15__0_n_0\
    );
\time_out_counter_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[8]_i_1__0_n_5\,
      Q => time_out_counter_reg(10),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[8]_i_1__0_n_4\,
      Q => time_out_counter_reg(11),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[12]_i_1__0_n_7\,
      Q => time_out_counter_reg(12),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[12]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[8]_i_1__0_n_0\,
      CO(3) => \time_out_counter_reg[12]_i_1__0_n_0\,
      CO(2) => \time_out_counter_reg[12]_i_1__0_n_1\,
      CO(1) => \time_out_counter_reg[12]_i_1__0_n_2\,
      CO(0) => \time_out_counter_reg[12]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[12]_i_1__0_n_4\,
      O(2) => \time_out_counter_reg[12]_i_1__0_n_5\,
      O(1) => \time_out_counter_reg[12]_i_1__0_n_6\,
      O(0) => \time_out_counter_reg[12]_i_1__0_n_7\,
      S(3) => \time_out_counter[12]_i_2__0_n_0\,
      S(2) => \time_out_counter[12]_i_3__0_n_0\,
      S(1) => \time_out_counter[12]_i_4__0_n_0\,
      S(0) => \time_out_counter[12]_i_5__0_n_0\
    );
\time_out_counter_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[12]_i_1__0_n_6\,
      Q => time_out_counter_reg(13),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[12]_i_1__0_n_5\,
      Q => time_out_counter_reg(14),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[12]_i_1__0_n_4\,
      Q => time_out_counter_reg(15),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[16]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[16]_i_1__0_n_7\,
      Q => time_out_counter_reg(16),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[16]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[12]_i_1__0_n_0\,
      CO(3) => \NLW_time_out_counter_reg[16]_i_1__0_CO_UNCONNECTED\(3),
      CO(2) => \time_out_counter_reg[16]_i_1__0_n_1\,
      CO(1) => \time_out_counter_reg[16]_i_1__0_n_2\,
      CO(0) => \time_out_counter_reg[16]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[16]_i_1__0_n_4\,
      O(2) => \time_out_counter_reg[16]_i_1__0_n_5\,
      O(1) => \time_out_counter_reg[16]_i_1__0_n_6\,
      O(0) => \time_out_counter_reg[16]_i_1__0_n_7\,
      S(3) => \time_out_counter[16]_i_2__0_n_0\,
      S(2) => \time_out_counter[16]_i_3__0_n_0\,
      S(1) => \time_out_counter[16]_i_4__0_n_0\,
      S(0) => \time_out_counter[16]_i_5_n_0\
    );
\time_out_counter_reg[17]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[16]_i_1__0_n_6\,
      Q => time_out_counter_reg(17),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[18]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[16]_i_1__0_n_5\,
      Q => time_out_counter_reg(18),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[19]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[16]_i_1__0_n_4\,
      Q => time_out_counter_reg(19),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[0]_i_2__0_n_6\,
      Q => time_out_counter_reg(1),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[0]_i_2__0_n_5\,
      Q => time_out_counter_reg(2),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[0]_i_2__0_n_4\,
      Q => time_out_counter_reg(3),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[4]_i_1__0_n_7\,
      Q => time_out_counter_reg(4),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[4]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[0]_i_2__0_n_0\,
      CO(3) => \time_out_counter_reg[4]_i_1__0_n_0\,
      CO(2) => \time_out_counter_reg[4]_i_1__0_n_1\,
      CO(1) => \time_out_counter_reg[4]_i_1__0_n_2\,
      CO(0) => \time_out_counter_reg[4]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[4]_i_1__0_n_4\,
      O(2) => \time_out_counter_reg[4]_i_1__0_n_5\,
      O(1) => \time_out_counter_reg[4]_i_1__0_n_6\,
      O(0) => \time_out_counter_reg[4]_i_1__0_n_7\,
      S(3) => \time_out_counter[4]_i_2__0_n_0\,
      S(2) => \time_out_counter[4]_i_3__0_n_0\,
      S(1) => \time_out_counter[4]_i_4__0_n_0\,
      S(0) => \time_out_counter[4]_i_5__0_n_0\
    );
\time_out_counter_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[4]_i_1__0_n_6\,
      Q => time_out_counter_reg(5),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[4]_i_1__0_n_5\,
      Q => time_out_counter_reg(6),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[4]_i_1__0_n_4\,
      Q => time_out_counter_reg(7),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[8]_i_1__0_n_7\,
      Q => time_out_counter_reg(8),
      R => reset_time_out_reg_n_0
    );
\time_out_counter_reg[8]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[4]_i_1__0_n_0\,
      CO(3) => \time_out_counter_reg[8]_i_1__0_n_0\,
      CO(2) => \time_out_counter_reg[8]_i_1__0_n_1\,
      CO(1) => \time_out_counter_reg[8]_i_1__0_n_2\,
      CO(0) => \time_out_counter_reg[8]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[8]_i_1__0_n_4\,
      O(2) => \time_out_counter_reg[8]_i_1__0_n_5\,
      O(1) => \time_out_counter_reg[8]_i_1__0_n_6\,
      O(0) => \time_out_counter_reg[8]_i_1__0_n_7\,
      S(3) => \time_out_counter[8]_i_2__0_n_0\,
      S(2) => \time_out_counter[8]_i_3__0_n_0\,
      S(1) => \time_out_counter[8]_i_4__0_n_0\,
      S(0) => \time_out_counter[8]_i_5__0_n_0\
    );
\time_out_counter_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1__0_n_0\,
      D => \time_out_counter_reg[8]_i_1__0_n_6\,
      Q => time_out_counter_reg(9),
      R => reset_time_out_reg_n_0
    );
\time_out_wait_bypass_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"AE00"
    )
        port map (
      I0 => time_out_wait_bypass_reg_n_0,
      I1 => wait_bypass_count1,
      I2 => rx_fsm_reset_done_int_s3,
      I3 => run_phase_alignment_int_s3_reg_n_0,
      O => \time_out_wait_bypass_i_1__0_n_0\
    );
time_out_wait_bypass_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => \time_out_wait_bypass_i_1__0_n_0\,
      Q => time_out_wait_bypass_reg_n_0,
      R => '0'
    );
time_out_wait_bypass_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_wait_bypass_s2,
      Q => time_out_wait_bypass_s3,
      R => '0'
    );
time_tlock_max_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"F8"
    )
        port map (
      I0 => time_tlock_max1,
      I1 => check_tlock_max_reg_n_0,
      I2 => time_tlock_max,
      O => time_tlock_max_i_1_n_0
    );
time_tlock_max_i_10: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(9),
      O => time_tlock_max_i_10_n_0
    );
time_tlock_max_i_11: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(14),
      I1 => time_out_counter_reg(15),
      O => time_tlock_max_i_11_n_0
    );
time_tlock_max_i_12: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(13),
      I1 => time_out_counter_reg(12),
      O => time_tlock_max_i_12_n_0
    );
time_tlock_max_i_13: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => time_out_counter_reg(10),
      I1 => time_out_counter_reg(11),
      O => time_tlock_max_i_13_n_0
    );
time_tlock_max_i_14: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(9),
      I1 => time_out_counter_reg(8),
      O => time_tlock_max_i_14_n_0
    );
time_tlock_max_i_15: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(7),
      I1 => time_out_counter_reg(6),
      O => time_tlock_max_i_15_n_0
    );
time_tlock_max_i_16: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => time_out_counter_reg(5),
      I1 => time_out_counter_reg(4),
      O => time_tlock_max_i_16_n_0
    );
time_tlock_max_i_17: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(2),
      I1 => time_out_counter_reg(3),
      O => time_tlock_max_i_17_n_0
    );
time_tlock_max_i_18: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(0),
      I1 => time_out_counter_reg(1),
      O => time_tlock_max_i_18_n_0
    );
time_tlock_max_i_19: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(6),
      I1 => time_out_counter_reg(7),
      O => time_tlock_max_i_19_n_0
    );
time_tlock_max_i_20: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(5),
      I1 => time_out_counter_reg(4),
      O => time_tlock_max_i_20_n_0
    );
time_tlock_max_i_21: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(3),
      I1 => time_out_counter_reg(2),
      O => time_tlock_max_i_21_n_0
    );
time_tlock_max_i_22: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(1),
      I1 => time_out_counter_reg(0),
      O => time_tlock_max_i_22_n_0
    );
time_tlock_max_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(19),
      I1 => time_out_counter_reg(18),
      O => time_tlock_max_i_4_n_0
    );
\time_tlock_max_i_5__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(16),
      I1 => time_out_counter_reg(17),
      O => \time_tlock_max_i_5__0_n_0\
    );
\time_tlock_max_i_6__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(18),
      I1 => time_out_counter_reg(19),
      O => \time_tlock_max_i_6__0_n_0\
    );
\time_tlock_max_i_7__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      O => \time_tlock_max_i_7__0_n_0\
    );
time_tlock_max_i_9: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => time_out_counter_reg(12),
      I1 => time_out_counter_reg(13),
      O => time_tlock_max_i_9_n_0
    );
time_tlock_max_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_tlock_max_i_1_n_0,
      Q => time_tlock_max,
      R => reset_time_out_reg_n_0
    );
\time_tlock_max_reg_i_2__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_tlock_max_reg_i_3__0_n_0\,
      CO(3 downto 2) => \NLW_time_tlock_max_reg_i_2__0_CO_UNCONNECTED\(3 downto 2),
      CO(1) => time_tlock_max1,
      CO(0) => \time_tlock_max_reg_i_2__0_n_3\,
      CYINIT => '0',
      DI(3 downto 2) => B"00",
      DI(1) => time_tlock_max_i_4_n_0,
      DI(0) => \time_tlock_max_i_5__0_n_0\,
      O(3 downto 0) => \NLW_time_tlock_max_reg_i_2__0_O_UNCONNECTED\(3 downto 0),
      S(3 downto 2) => B"00",
      S(1) => \time_tlock_max_i_6__0_n_0\,
      S(0) => \time_tlock_max_i_7__0_n_0\
    );
\time_tlock_max_reg_i_3__0\: unisim.vcomponents.CARRY4
     port map (
      CI => time_tlock_max_reg_i_8_n_0,
      CO(3) => \time_tlock_max_reg_i_3__0_n_0\,
      CO(2) => \time_tlock_max_reg_i_3__0_n_1\,
      CO(1) => \time_tlock_max_reg_i_3__0_n_2\,
      CO(0) => \time_tlock_max_reg_i_3__0_n_3\,
      CYINIT => '0',
      DI(3) => time_out_counter_reg(15),
      DI(2) => time_tlock_max_i_9_n_0,
      DI(1) => '0',
      DI(0) => time_tlock_max_i_10_n_0,
      O(3 downto 0) => \NLW_time_tlock_max_reg_i_3__0_O_UNCONNECTED\(3 downto 0),
      S(3) => time_tlock_max_i_11_n_0,
      S(2) => time_tlock_max_i_12_n_0,
      S(1) => time_tlock_max_i_13_n_0,
      S(0) => time_tlock_max_i_14_n_0
    );
time_tlock_max_reg_i_8: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => time_tlock_max_reg_i_8_n_0,
      CO(2) => time_tlock_max_reg_i_8_n_1,
      CO(1) => time_tlock_max_reg_i_8_n_2,
      CO(0) => time_tlock_max_reg_i_8_n_3,
      CYINIT => '0',
      DI(3) => time_tlock_max_i_15_n_0,
      DI(2) => time_tlock_max_i_16_n_0,
      DI(1) => time_tlock_max_i_17_n_0,
      DI(0) => time_tlock_max_i_18_n_0,
      O(3 downto 0) => NLW_time_tlock_max_reg_i_8_O_UNCONNECTED(3 downto 0),
      S(3) => time_tlock_max_i_19_n_0,
      S(2) => time_tlock_max_i_20_n_0,
      S(1) => time_tlock_max_i_21_n_0,
      S(0) => time_tlock_max_i_22_n_0
    );
\wait_bypass_count[0]_i_10__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000008000000000"
    )
        port map (
      I0 => wait_bypass_count_reg(7),
      I1 => wait_bypass_count_reg(8),
      I2 => wait_bypass_count_reg(9),
      I3 => wait_bypass_count_reg(10),
      I4 => wait_bypass_count_reg(11),
      I5 => wait_bypass_count_reg(12),
      O => \wait_bypass_count[0]_i_10__0_n_0\
    );
\wait_bypass_count[0]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => run_phase_alignment_int_s3_reg_n_0,
      O => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count[0]_i_2__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => rx_fsm_reset_done_int_s3,
      I1 => wait_bypass_count1,
      O => wait_bypass_count
    );
\wait_bypass_count[0]_i_4__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"80000000"
    )
        port map (
      I0 => \wait_bypass_count[0]_i_9__0_n_0\,
      I1 => wait_bypass_count_reg(2),
      I2 => wait_bypass_count_reg(1),
      I3 => wait_bypass_count_reg(0),
      I4 => \wait_bypass_count[0]_i_10__0_n_0\,
      O => wait_bypass_count1
    );
\wait_bypass_count[0]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(3),
      O => \wait_bypass_count[0]_i_5__0_n_0\
    );
\wait_bypass_count[0]_i_6__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(2),
      O => \wait_bypass_count[0]_i_6__0_n_0\
    );
\wait_bypass_count[0]_i_7__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(1),
      O => \wait_bypass_count[0]_i_7__0_n_0\
    );
\wait_bypass_count[0]_i_8__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => wait_bypass_count_reg(0),
      O => \wait_bypass_count[0]_i_8__0_n_0\
    );
\wait_bypass_count[0]_i_9__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0001"
    )
        port map (
      I0 => wait_bypass_count_reg(6),
      I1 => wait_bypass_count_reg(5),
      I2 => wait_bypass_count_reg(4),
      I3 => wait_bypass_count_reg(3),
      O => \wait_bypass_count[0]_i_9__0_n_0\
    );
\wait_bypass_count[12]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(12),
      O => \wait_bypass_count[12]_i_2__0_n_0\
    );
\wait_bypass_count[4]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(7),
      O => \wait_bypass_count[4]_i_2__0_n_0\
    );
\wait_bypass_count[4]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(6),
      O => \wait_bypass_count[4]_i_3__0_n_0\
    );
\wait_bypass_count[4]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(5),
      O => \wait_bypass_count[4]_i_4__0_n_0\
    );
\wait_bypass_count[4]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(4),
      O => \wait_bypass_count[4]_i_5__0_n_0\
    );
\wait_bypass_count[8]_i_2__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(11),
      O => \wait_bypass_count[8]_i_2__0_n_0\
    );
\wait_bypass_count[8]_i_3__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(10),
      O => \wait_bypass_count[8]_i_3__0_n_0\
    );
\wait_bypass_count[8]_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(9),
      O => \wait_bypass_count[8]_i_4__0_n_0\
    );
\wait_bypass_count[8]_i_5__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(8),
      O => \wait_bypass_count[8]_i_5__0_n_0\
    );
\wait_bypass_count_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3__0_n_7\,
      Q => wait_bypass_count_reg(0),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[0]_i_3__0\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \wait_bypass_count_reg[0]_i_3__0_n_0\,
      CO(2) => \wait_bypass_count_reg[0]_i_3__0_n_1\,
      CO(1) => \wait_bypass_count_reg[0]_i_3__0_n_2\,
      CO(0) => \wait_bypass_count_reg[0]_i_3__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \wait_bypass_count_reg[0]_i_3__0_n_4\,
      O(2) => \wait_bypass_count_reg[0]_i_3__0_n_5\,
      O(1) => \wait_bypass_count_reg[0]_i_3__0_n_6\,
      O(0) => \wait_bypass_count_reg[0]_i_3__0_n_7\,
      S(3) => \wait_bypass_count[0]_i_5__0_n_0\,
      S(2) => \wait_bypass_count[0]_i_6__0_n_0\,
      S(1) => \wait_bypass_count[0]_i_7__0_n_0\,
      S(0) => \wait_bypass_count[0]_i_8__0_n_0\
    );
\wait_bypass_count_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1__0_n_5\,
      Q => wait_bypass_count_reg(10),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1__0_n_4\,
      Q => wait_bypass_count_reg(11),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[12]_i_1__0_n_7\,
      Q => wait_bypass_count_reg(12),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[12]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[8]_i_1__0_n_0\,
      CO(3 downto 0) => \NLW_wait_bypass_count_reg[12]_i_1__0_CO_UNCONNECTED\(3 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 1) => \NLW_wait_bypass_count_reg[12]_i_1__0_O_UNCONNECTED\(3 downto 1),
      O(0) => \wait_bypass_count_reg[12]_i_1__0_n_7\,
      S(3 downto 1) => B"000",
      S(0) => \wait_bypass_count[12]_i_2__0_n_0\
    );
\wait_bypass_count_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3__0_n_6\,
      Q => wait_bypass_count_reg(1),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3__0_n_5\,
      Q => wait_bypass_count_reg(2),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3__0_n_4\,
      Q => wait_bypass_count_reg(3),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1__0_n_7\,
      Q => wait_bypass_count_reg(4),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[4]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[0]_i_3__0_n_0\,
      CO(3) => \wait_bypass_count_reg[4]_i_1__0_n_0\,
      CO(2) => \wait_bypass_count_reg[4]_i_1__0_n_1\,
      CO(1) => \wait_bypass_count_reg[4]_i_1__0_n_2\,
      CO(0) => \wait_bypass_count_reg[4]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \wait_bypass_count_reg[4]_i_1__0_n_4\,
      O(2) => \wait_bypass_count_reg[4]_i_1__0_n_5\,
      O(1) => \wait_bypass_count_reg[4]_i_1__0_n_6\,
      O(0) => \wait_bypass_count_reg[4]_i_1__0_n_7\,
      S(3) => \wait_bypass_count[4]_i_2__0_n_0\,
      S(2) => \wait_bypass_count[4]_i_3__0_n_0\,
      S(1) => \wait_bypass_count[4]_i_4__0_n_0\,
      S(0) => \wait_bypass_count[4]_i_5__0_n_0\
    );
\wait_bypass_count_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1__0_n_6\,
      Q => wait_bypass_count_reg(5),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1__0_n_5\,
      Q => wait_bypass_count_reg(6),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1__0_n_4\,
      Q => wait_bypass_count_reg(7),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1__0_n_7\,
      Q => wait_bypass_count_reg(8),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_bypass_count_reg[8]_i_1__0\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[4]_i_1__0_n_0\,
      CO(3) => \wait_bypass_count_reg[8]_i_1__0_n_0\,
      CO(2) => \wait_bypass_count_reg[8]_i_1__0_n_1\,
      CO(1) => \wait_bypass_count_reg[8]_i_1__0_n_2\,
      CO(0) => \wait_bypass_count_reg[8]_i_1__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \wait_bypass_count_reg[8]_i_1__0_n_4\,
      O(2) => \wait_bypass_count_reg[8]_i_1__0_n_5\,
      O(1) => \wait_bypass_count_reg[8]_i_1__0_n_6\,
      O(0) => \wait_bypass_count_reg[8]_i_1__0_n_7\,
      S(3) => \wait_bypass_count[8]_i_2__0_n_0\,
      S(2) => \wait_bypass_count[8]_i_3__0_n_0\,
      S(1) => \wait_bypass_count[8]_i_4__0_n_0\,
      S(0) => \wait_bypass_count[8]_i_5__0_n_0\
    );
\wait_bypass_count_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1__0_n_6\,
      Q => wait_bypass_count_reg(9),
      R => \wait_bypass_count[0]_i_1__0_n_0\
    );
\wait_time_cnt[0]_i_1__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(0),
      O => \wait_time_cnt0__0\(0)
    );
\wait_time_cnt[1]_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      O => \wait_time_cnt0__0\(1)
    );
\wait_time_cnt[2]_i_1__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"A9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(2),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(1),
      O => \wait_time_cnt0__0\(2)
    );
\wait_time_cnt[3]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FE01"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      O => \wait_time_cnt0__0\(3)
    );
\wait_time_cnt[4]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFE0001"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      I4 => \wait_time_cnt_reg__0\(4),
      O => \wait_time_cnt0__0\(4)
    );
\wait_time_cnt[5]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFE00000001"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      I4 => \wait_time_cnt_reg__0\(4),
      I5 => \wait_time_cnt_reg__0\(5),
      O => \wait_time_cnt0__0\(5)
    );
\wait_time_cnt[6]_i_1__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"02"
    )
        port map (
      I0 => rx_state(0),
      I1 => rx_state(1),
      I2 => rx_state(3),
      O => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt[6]_i_2__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \wait_time_cnt[6]_i_4__0_n_0\,
      I1 => \wait_time_cnt_reg__0\(6),
      O => \wait_time_cnt[6]_i_2__0_n_0\
    );
\wait_time_cnt[6]_i_3__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(6),
      I1 => \wait_time_cnt[6]_i_4__0_n_0\,
      O => \wait_time_cnt0__0\(6)
    );
\wait_time_cnt[6]_i_4__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFFFFFE"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(5),
      I1 => \wait_time_cnt_reg__0\(4),
      I2 => \wait_time_cnt_reg__0\(3),
      I3 => \wait_time_cnt_reg__0\(2),
      I4 => \wait_time_cnt_reg__0\(0),
      I5 => \wait_time_cnt_reg__0\(1),
      O => \wait_time_cnt[6]_i_4__0_n_0\
    );
\wait_time_cnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(0),
      Q => \wait_time_cnt_reg__0\(0),
      R => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(1),
      Q => \wait_time_cnt_reg__0\(1),
      R => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[2]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(2),
      Q => \wait_time_cnt_reg__0\(2),
      S => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(3),
      Q => \wait_time_cnt_reg__0\(3),
      R => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(4),
      Q => \wait_time_cnt_reg__0\(4),
      R => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[5]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(5),
      Q => \wait_time_cnt_reg__0\(5),
      S => \wait_time_cnt[6]_i_1__0_n_0\
    );
\wait_time_cnt_reg[6]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2__0_n_0\,
      D => \wait_time_cnt0__0\(6),
      Q => \wait_time_cnt_reg__0\(6),
      S => \wait_time_cnt[6]_i_1__0_n_0\
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM is
  port (
    mmcm_reset : out STD_LOGIC;
    CPLL_RESET : out STD_LOGIC;
    data_in : out STD_LOGIC;
    TXUSERRDY : out STD_LOGIC;
    gt0_gttxreset_in0_out : out STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    userclk : in STD_LOGIC;
    pma_reset : in STD_LOGIC;
    reset_sync6 : in STD_LOGIC;
    CPLLREFCLKLOST : in STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    cplllock : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM : entity is "GigEthGth7Core_TX_STARTUP_FSM";
end GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM is
  signal \^cpll_reset\ : STD_LOGIC;
  signal CPLL_RESET0 : STD_LOGIC;
  signal CPLL_RESET_i_1_n_0 : STD_LOGIC;
  signal CPLL_RESET_i_2_n_0 : STD_LOGIC;
  signal \FSM_sequential_tx_state[0]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[0]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[1]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[2]_i_1_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[2]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[3]_i_2_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[3]_i_4_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[3]_i_5_n_0\ : STD_LOGIC;
  signal \FSM_sequential_tx_state[3]_i_7_n_0\ : STD_LOGIC;
  signal GTTXRESET : STD_LOGIC;
  signal MMCM_RESET_i_1_n_0 : STD_LOGIC;
  signal \^txuserrdy\ : STD_LOGIC;
  signal TXUSERRDY_i_1_n_0 : STD_LOGIC;
  signal clear : STD_LOGIC;
  signal \^data_in\ : STD_LOGIC;
  signal data_out : STD_LOGIC;
  signal gttxreset_i_i_1_n_0 : STD_LOGIC;
  signal init_wait_count : STD_LOGIC;
  signal \init_wait_count[0]_i_1_n_0\ : STD_LOGIC;
  signal \init_wait_count[6]_i_3_n_0\ : STD_LOGIC;
  signal \init_wait_count_reg__0\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal init_wait_done_i_1_n_0 : STD_LOGIC;
  signal init_wait_done_reg_n_0 : STD_LOGIC;
  signal \mmcm_lock_count[7]_i_2_n_0\ : STD_LOGIC;
  signal \mmcm_lock_count[7]_i_4_n_0\ : STD_LOGIC;
  signal \mmcm_lock_count_reg__0\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal mmcm_lock_reclocked : STD_LOGIC;
  signal mmcm_lock_reclocked_i_2_n_0 : STD_LOGIC;
  signal \^mmcm_reset\ : STD_LOGIC;
  signal p_0_in : STD_LOGIC_VECTOR ( 6 downto 1 );
  signal \p_0_in__0\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal pll_reset_asserted_i_1_n_0 : STD_LOGIC;
  signal pll_reset_asserted_reg_n_0 : STD_LOGIC;
  signal refclk_stable : STD_LOGIC;
  signal \refclk_stable_count[0]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[0]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[0]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[0]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[0]_i_6_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[12]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[12]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[12]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[12]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[16]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[16]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[16]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[16]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[20]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[20]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[20]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[20]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[24]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[24]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[24]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[24]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[28]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[28]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[28]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[28]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[4]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[4]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[4]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[4]_i_5_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[8]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[8]_i_3_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[8]_i_4_n_0\ : STD_LOGIC;
  signal \refclk_stable_count[8]_i_5_n_0\ : STD_LOGIC;
  signal refclk_stable_count_reg : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal \refclk_stable_count_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[16]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[20]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[24]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[28]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \refclk_stable_count_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal refclk_stable_i_10_n_0 : STD_LOGIC;
  signal refclk_stable_i_11_n_0 : STD_LOGIC;
  signal refclk_stable_i_12_n_0 : STD_LOGIC;
  signal refclk_stable_i_13_n_0 : STD_LOGIC;
  signal refclk_stable_i_14_n_0 : STD_LOGIC;
  signal refclk_stable_i_3_n_0 : STD_LOGIC;
  signal refclk_stable_i_4_n_0 : STD_LOGIC;
  signal refclk_stable_i_5_n_0 : STD_LOGIC;
  signal refclk_stable_i_7_n_0 : STD_LOGIC;
  signal refclk_stable_i_8_n_0 : STD_LOGIC;
  signal refclk_stable_i_9_n_0 : STD_LOGIC;
  signal refclk_stable_reg_i_1_n_1 : STD_LOGIC;
  signal refclk_stable_reg_i_1_n_2 : STD_LOGIC;
  signal refclk_stable_reg_i_1_n_3 : STD_LOGIC;
  signal refclk_stable_reg_i_2_n_0 : STD_LOGIC;
  signal refclk_stable_reg_i_2_n_1 : STD_LOGIC;
  signal refclk_stable_reg_i_2_n_2 : STD_LOGIC;
  signal refclk_stable_reg_i_2_n_3 : STD_LOGIC;
  signal refclk_stable_reg_i_6_n_0 : STD_LOGIC;
  signal refclk_stable_reg_i_6_n_1 : STD_LOGIC;
  signal refclk_stable_reg_i_6_n_2 : STD_LOGIC;
  signal refclk_stable_reg_i_6_n_3 : STD_LOGIC;
  signal reset_time_out : STD_LOGIC;
  signal reset_time_out_i_3_n_0 : STD_LOGIC;
  signal run_phase_alignment_int_i_1_n_0 : STD_LOGIC;
  signal run_phase_alignment_int_reg_n_0 : STD_LOGIC;
  signal run_phase_alignment_int_s3 : STD_LOGIC;
  signal sync_cplllock_n_0 : STD_LOGIC;
  signal sync_cplllock_n_1 : STD_LOGIC;
  signal sync_mmcm_lock_reclocked_n_0 : STD_LOGIC;
  signal sync_mmcm_lock_reclocked_n_1 : STD_LOGIC;
  signal time_out_2ms : STD_LOGIC;
  signal time_out_2ms_i_1_n_0 : STD_LOGIC;
  signal time_out_500us : STD_LOGIC;
  signal time_out_500us_i_10_n_0 : STD_LOGIC;
  signal time_out_500us_i_1_n_0 : STD_LOGIC;
  signal time_out_500us_i_4_n_0 : STD_LOGIC;
  signal time_out_500us_i_5_n_0 : STD_LOGIC;
  signal time_out_500us_i_6_n_0 : STD_LOGIC;
  signal time_out_500us_i_7_n_0 : STD_LOGIC;
  signal time_out_500us_i_8_n_0 : STD_LOGIC;
  signal time_out_500us_i_9_n_0 : STD_LOGIC;
  signal time_out_500us_reg_i_2_n_1 : STD_LOGIC;
  signal time_out_500us_reg_i_2_n_2 : STD_LOGIC;
  signal time_out_500us_reg_i_2_n_3 : STD_LOGIC;
  signal time_out_500us_reg_i_3_n_0 : STD_LOGIC;
  signal time_out_500us_reg_i_3_n_1 : STD_LOGIC;
  signal time_out_500us_reg_i_3_n_2 : STD_LOGIC;
  signal time_out_500us_reg_i_3_n_3 : STD_LOGIC;
  signal \time_out_counter[0]_i_10_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_11_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_12_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_13__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_14_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_15_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_1_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_4_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_5_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_6_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_7__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[0]_i_9__0_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_2_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_3_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_4_n_0\ : STD_LOGIC;
  signal \time_out_counter[12]_i_5_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_2_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_3_n_0\ : STD_LOGIC;
  signal \time_out_counter[16]_i_4_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_2_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_3_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_4_n_0\ : STD_LOGIC;
  signal \time_out_counter[4]_i_5_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_2_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_3_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_4_n_0\ : STD_LOGIC;
  signal \time_out_counter[8]_i_5_n_0\ : STD_LOGIC;
  signal time_out_counter_reg : STD_LOGIC_VECTOR ( 18 downto 0 );
  signal \time_out_counter_reg[0]_i_2_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_2_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_3_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[0]_i_8_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[16]_i_1_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \time_out_counter_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal time_out_wait_bypass_i_1_n_0 : STD_LOGIC;
  signal time_out_wait_bypass_reg_n_0 : STD_LOGIC;
  signal time_out_wait_bypass_s2 : STD_LOGIC;
  signal time_out_wait_bypass_s3 : STD_LOGIC;
  signal time_tlock_max : STD_LOGIC;
  signal \time_tlock_max_i_10__0_n_0\ : STD_LOGIC;
  signal \time_tlock_max_i_1__0_n_0\ : STD_LOGIC;
  signal \time_tlock_max_i_4__0_n_0\ : STD_LOGIC;
  signal time_tlock_max_i_5_n_0 : STD_LOGIC;
  signal time_tlock_max_i_6_n_0 : STD_LOGIC;
  signal time_tlock_max_i_7_n_0 : STD_LOGIC;
  signal time_tlock_max_i_8_n_0 : STD_LOGIC;
  signal \time_tlock_max_i_9__0_n_0\ : STD_LOGIC;
  signal time_tlock_max_reg_i_2_n_1 : STD_LOGIC;
  signal time_tlock_max_reg_i_2_n_2 : STD_LOGIC;
  signal time_tlock_max_reg_i_2_n_3 : STD_LOGIC;
  signal time_tlock_max_reg_i_3_n_0 : STD_LOGIC;
  signal time_tlock_max_reg_i_3_n_1 : STD_LOGIC;
  signal time_tlock_max_reg_i_3_n_2 : STD_LOGIC;
  signal time_tlock_max_reg_i_3_n_3 : STD_LOGIC;
  signal tx_fsm_reset_done_int_i_1_n_0 : STD_LOGIC;
  signal tx_fsm_reset_done_int_s2 : STD_LOGIC;
  signal tx_fsm_reset_done_int_s3 : STD_LOGIC;
  signal tx_state : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of tx_state : signal is "yes";
  signal tx_state13_out : STD_LOGIC;
  signal txresetdone_s2 : STD_LOGIC;
  signal txresetdone_s3 : STD_LOGIC;
  signal wait_bypass_count : STD_LOGIC;
  signal wait_bypass_count1 : STD_LOGIC;
  signal \wait_bypass_count[0]_i_10_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_11_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_5_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_6_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_7_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_8_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[0]_i_9_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[12]_i_2_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[12]_i_3_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[12]_i_4_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[12]_i_5_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[16]_i_2_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_2_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_3_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_4_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[4]_i_5_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_2_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_3_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_4_n_0\ : STD_LOGIC;
  signal \wait_bypass_count[8]_i_5_n_0\ : STD_LOGIC;
  signal wait_bypass_count_reg : STD_LOGIC_VECTOR ( 16 downto 0 );
  signal \wait_bypass_count_reg[0]_i_3_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[0]_i_3_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[12]_i_1_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[16]_i_1_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[4]_i_1_n_7\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_1\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_2\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_3\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_4\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_5\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_6\ : STD_LOGIC;
  signal \wait_bypass_count_reg[8]_i_1_n_7\ : STD_LOGIC;
  signal wait_time_cnt0 : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal wait_time_cnt0_0 : STD_LOGIC;
  signal \wait_time_cnt[6]_i_2_n_0\ : STD_LOGIC;
  signal \wait_time_cnt[6]_i_4_n_0\ : STD_LOGIC;
  signal \wait_time_cnt_reg__0\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal \NLW_refclk_stable_count_reg[28]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_refclk_stable_reg_i_1_CO_UNCONNECTED : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_refclk_stable_reg_i_1_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_refclk_stable_reg_i_2_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_refclk_stable_reg_i_6_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_out_500us_reg_i_2_CO_UNCONNECTED : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_time_out_500us_reg_i_2_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_out_500us_reg_i_3_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[0]_i_3_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_time_out_counter_reg[0]_i_3_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[0]_i_8_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_time_out_counter_reg[16]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 2 );
  signal \NLW_time_out_counter_reg[16]_i_1_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_time_tlock_max_reg_i_2_CO_UNCONNECTED : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_time_tlock_max_reg_i_2_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_time_tlock_max_reg_i_3_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_wait_bypass_count_reg[16]_i_1_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_wait_bypass_count_reg[16]_i_1_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 1 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_tx_state[1]_i_2\ : label is "soft_lutpair55";
  attribute SOFT_HLUTNM of \FSM_sequential_tx_state[3]_i_7\ : label is "soft_lutpair55";
  attribute KEEP : string;
  attribute KEEP of \FSM_sequential_tx_state_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_tx_state_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_tx_state_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_tx_state_reg[3]\ : label is "yes";
  attribute SOFT_HLUTNM of \init_wait_count[0]_i_1\ : label is "soft_lutpair49";
  attribute SOFT_HLUTNM of \init_wait_count[1]_i_1\ : label is "soft_lutpair53";
  attribute SOFT_HLUTNM of \init_wait_count[2]_i_1\ : label is "soft_lutpair53";
  attribute SOFT_HLUTNM of \init_wait_count[3]_i_1\ : label is "soft_lutpair48";
  attribute SOFT_HLUTNM of \init_wait_count[4]_i_1\ : label is "soft_lutpair48";
  attribute SOFT_HLUTNM of \init_wait_count[6]_i_2\ : label is "soft_lutpair49";
  attribute SOFT_HLUTNM of \mmcm_lock_count[1]_i_1\ : label is "soft_lutpair54";
  attribute SOFT_HLUTNM of \mmcm_lock_count[2]_i_1\ : label is "soft_lutpair52";
  attribute SOFT_HLUTNM of \mmcm_lock_count[3]_i_1\ : label is "soft_lutpair52";
  attribute SOFT_HLUTNM of \mmcm_lock_count[4]_i_1\ : label is "soft_lutpair50";
  attribute SOFT_HLUTNM of \mmcm_lock_count[7]_i_4\ : label is "soft_lutpair54";
  attribute SOFT_HLUTNM of mmcm_lock_reclocked_i_2 : label is "soft_lutpair50";
  attribute SOFT_HLUTNM of time_out_2ms_i_1 : label is "soft_lutpair56";
  attribute SOFT_HLUTNM of \time_tlock_max_i_1__0\ : label is "soft_lutpair56";
  attribute SOFT_HLUTNM of \wait_time_cnt[0]_i_1\ : label is "soft_lutpair57";
  attribute SOFT_HLUTNM of \wait_time_cnt[1]_i_1\ : label is "soft_lutpair57";
  attribute SOFT_HLUTNM of \wait_time_cnt[3]_i_1\ : label is "soft_lutpair51";
  attribute SOFT_HLUTNM of \wait_time_cnt[4]_i_1\ : label is "soft_lutpair51";
begin
  CPLL_RESET <= \^cpll_reset\;
  TXUSERRDY <= \^txuserrdy\;
  data_in <= \^data_in\;
  mmcm_reset <= \^mmcm_reset\;
CPLL_RESET_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF57FF00005700"
    )
        port map (
      I0 => refclk_stable,
      I1 => CPLLREFCLKLOST,
      I2 => pll_reset_asserted_reg_n_0,
      I3 => CPLL_RESET_i_2_n_0,
      I4 => \FSM_sequential_tx_state[3]_i_4_n_0\,
      I5 => \^cpll_reset\,
      O => CPLL_RESET_i_1_n_0
    );
CPLL_RESET_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => tx_state(0),
      I1 => tx_state(3),
      O => CPLL_RESET_i_2_n_0
    );
CPLL_RESET_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => CPLL_RESET_i_1_n_0,
      Q => \^cpll_reset\,
      R => pma_reset
    );
\FSM_sequential_tx_state[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"222A222A0000222A"
    )
        port map (
      I0 => \FSM_sequential_tx_state[0]_i_2_n_0\,
      I1 => tx_state(3),
      I2 => tx_state(1),
      I3 => tx_state(2),
      I4 => tx_state(0),
      I5 => \FSM_sequential_tx_state[2]_i_2_n_0\,
      O => \FSM_sequential_tx_state[0]_i_1_n_0\
    );
\FSM_sequential_tx_state[0]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"4F4FFFFFF000FFFF"
    )
        port map (
      I0 => reset_time_out,
      I1 => time_out_500us,
      I2 => tx_state(1),
      I3 => time_out_2ms,
      I4 => tx_state(0),
      I5 => tx_state(2),
      O => \FSM_sequential_tx_state[0]_i_2_n_0\
    );
\FSM_sequential_tx_state[1]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00002666"
    )
        port map (
      I0 => tx_state(1),
      I1 => tx_state(0),
      I2 => tx_state13_out,
      I3 => tx_state(2),
      I4 => tx_state(3),
      O => \FSM_sequential_tx_state[1]_i_1_n_0\
    );
\FSM_sequential_tx_state[1]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => reset_time_out,
      I1 => time_tlock_max,
      I2 => mmcm_lock_reclocked,
      O => tx_state13_out
    );
\FSM_sequential_tx_state[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"1100330011303300"
    )
        port map (
      I0 => \FSM_sequential_tx_state[2]_i_2_n_0\,
      I1 => tx_state(3),
      I2 => tx_state(1),
      I3 => tx_state(2),
      I4 => tx_state(0),
      I5 => time_out_2ms,
      O => \FSM_sequential_tx_state[2]_i_1_n_0\
    );
\FSM_sequential_tx_state[2]_i_2\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"AABA"
    )
        port map (
      I0 => tx_state(1),
      I1 => mmcm_lock_reclocked,
      I2 => time_tlock_max,
      I3 => reset_time_out,
      O => \FSM_sequential_tx_state[2]_i_2_n_0\
    );
\FSM_sequential_tx_state[3]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00073000"
    )
        port map (
      I0 => time_out_wait_bypass_s3,
      I1 => \FSM_sequential_tx_state[3]_i_5_n_0\,
      I2 => tx_state(1),
      I3 => tx_state(2),
      I4 => tx_state(3),
      O => \FSM_sequential_tx_state[3]_i_2_n_0\
    );
\FSM_sequential_tx_state[3]_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => tx_state(2),
      I1 => tx_state(1),
      O => \FSM_sequential_tx_state[3]_i_4_n_0\
    );
\FSM_sequential_tx_state[3]_i_5\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"4F"
    )
        port map (
      I0 => reset_time_out,
      I1 => time_out_500us,
      I2 => tx_state(0),
      O => \FSM_sequential_tx_state[3]_i_5_n_0\
    );
\FSM_sequential_tx_state[3]_i_7\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_tlock_max,
      I1 => reset_time_out,
      O => \FSM_sequential_tx_state[3]_i_7_n_0\
    );
\FSM_sequential_tx_state_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_1,
      D => \FSM_sequential_tx_state[0]_i_1_n_0\,
      Q => tx_state(0),
      R => pma_reset
    );
\FSM_sequential_tx_state_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_1,
      D => \FSM_sequential_tx_state[1]_i_1_n_0\,
      Q => tx_state(1),
      R => pma_reset
    );
\FSM_sequential_tx_state_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_1,
      D => \FSM_sequential_tx_state[2]_i_1_n_0\,
      Q => tx_state(2),
      R => pma_reset
    );
\FSM_sequential_tx_state_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => sync_cplllock_n_1,
      D => \FSM_sequential_tx_state[3]_i_2_n_0\,
      Q => tx_state(3),
      R => pma_reset
    );
MMCM_RESET_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFF70004"
    )
        port map (
      I0 => tx_state(2),
      I1 => tx_state(0),
      I2 => tx_state(1),
      I3 => tx_state(3),
      I4 => \^mmcm_reset\,
      O => MMCM_RESET_i_1_n_0
    );
MMCM_RESET_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => MMCM_RESET_i_1_n_0,
      Q => \^mmcm_reset\,
      R => pma_reset
    );
TXUSERRDY_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFEF0080"
    )
        port map (
      I0 => tx_state(2),
      I1 => tx_state(1),
      I2 => tx_state(0),
      I3 => tx_state(3),
      I4 => \^txuserrdy\,
      O => TXUSERRDY_i_1_n_0
    );
TXUSERRDY_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => TXUSERRDY_i_1_n_0,
      Q => \^txuserrdy\,
      R => pma_reset
    );
gthe2_i_i_4: unisim.vcomponents.LUT3
    generic map(
      INIT => X"EA"
    )
        port map (
      I0 => GTTXRESET,
      I1 => \^data_in\,
      I2 => reset_sync6,
      O => gt0_gttxreset_in0_out
    );
gttxreset_i_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFB0002"
    )
        port map (
      I0 => tx_state(0),
      I1 => tx_state(2),
      I2 => tx_state(1),
      I3 => tx_state(3),
      I4 => GTTXRESET,
      O => gttxreset_i_i_1_n_0
    );
gttxreset_i_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => gttxreset_i_i_1_n_0,
      Q => GTTXRESET,
      R => pma_reset
    );
\init_wait_count[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      O => \init_wait_count[0]_i_1_n_0\
    );
\init_wait_count[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => \init_wait_count_reg__0\(1),
      I1 => \init_wait_count_reg__0\(0),
      O => p_0_in(1)
    );
\init_wait_count[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"78"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      I1 => \init_wait_count_reg__0\(1),
      I2 => \init_wait_count_reg__0\(2),
      O => p_0_in(2)
    );
\init_wait_count[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"6AAA"
    )
        port map (
      I0 => \init_wait_count_reg__0\(3),
      I1 => \init_wait_count_reg__0\(2),
      I2 => \init_wait_count_reg__0\(1),
      I3 => \init_wait_count_reg__0\(0),
      O => p_0_in(3)
    );
\init_wait_count[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"6AAAAAAA"
    )
        port map (
      I0 => \init_wait_count_reg__0\(4),
      I1 => \init_wait_count_reg__0\(1),
      I2 => \init_wait_count_reg__0\(2),
      I3 => \init_wait_count_reg__0\(3),
      I4 => \init_wait_count_reg__0\(0),
      O => p_0_in(4)
    );
\init_wait_count[5]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFF80000000"
    )
        port map (
      I0 => \init_wait_count_reg__0\(0),
      I1 => \init_wait_count_reg__0\(3),
      I2 => \init_wait_count_reg__0\(2),
      I3 => \init_wait_count_reg__0\(1),
      I4 => \init_wait_count_reg__0\(4),
      I5 => \init_wait_count_reg__0\(5),
      O => p_0_in(5)
    );
\init_wait_count[6]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFFEFFF"
    )
        port map (
      I0 => \init_wait_count[6]_i_3_n_0\,
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count_reg__0\(6),
      I3 => \init_wait_count_reg__0\(5),
      I4 => \init_wait_count_reg__0\(0),
      O => init_wait_count
    );
\init_wait_count[6]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"F7FF0800"
    )
        port map (
      I0 => \init_wait_count_reg__0\(5),
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count[6]_i_3_n_0\,
      I3 => \init_wait_count_reg__0\(0),
      I4 => \init_wait_count_reg__0\(6),
      O => p_0_in(6)
    );
\init_wait_count[6]_i_3\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
        port map (
      I0 => \init_wait_count_reg__0\(1),
      I1 => \init_wait_count_reg__0\(2),
      I2 => \init_wait_count_reg__0\(3),
      O => \init_wait_count[6]_i_3_n_0\
    );
\init_wait_count_reg[0]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => \init_wait_count[0]_i_1_n_0\,
      Q => \init_wait_count_reg__0\(0)
    );
\init_wait_count_reg[1]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(1),
      Q => \init_wait_count_reg__0\(1)
    );
\init_wait_count_reg[2]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(2),
      Q => \init_wait_count_reg__0\(2)
    );
\init_wait_count_reg[3]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(3),
      Q => \init_wait_count_reg__0\(3)
    );
\init_wait_count_reg[4]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(4),
      Q => \init_wait_count_reg__0\(4)
    );
\init_wait_count_reg[5]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(5),
      Q => \init_wait_count_reg__0\(5)
    );
\init_wait_count_reg[6]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => init_wait_count,
      CLR => pma_reset,
      D => p_0_in(6),
      Q => \init_wait_count_reg__0\(6)
    );
init_wait_done_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFF01000000"
    )
        port map (
      I0 => \init_wait_count[6]_i_3_n_0\,
      I1 => \init_wait_count_reg__0\(4),
      I2 => \init_wait_count_reg__0\(0),
      I3 => \init_wait_count_reg__0\(6),
      I4 => \init_wait_count_reg__0\(5),
      I5 => init_wait_done_reg_n_0,
      O => init_wait_done_i_1_n_0
    );
init_wait_done_reg: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      CLR => pma_reset,
      D => init_wait_done_i_1_n_0,
      Q => init_wait_done_reg_n_0
    );
\mmcm_lock_count[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(0),
      O => \p_0_in__0\(0)
    );
\mmcm_lock_count[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(0),
      I1 => \mmcm_lock_count_reg__0\(1),
      O => \p_0_in__0\(1)
    );
\mmcm_lock_count[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"6A"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(2),
      I1 => \mmcm_lock_count_reg__0\(1),
      I2 => \mmcm_lock_count_reg__0\(0),
      O => \p_0_in__0\(2)
    );
\mmcm_lock_count[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"6AAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(3),
      I1 => \mmcm_lock_count_reg__0\(0),
      I2 => \mmcm_lock_count_reg__0\(1),
      I3 => \mmcm_lock_count_reg__0\(2),
      O => \p_0_in__0\(3)
    );
\mmcm_lock_count[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"6AAAAAAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count_reg__0\(0),
      I3 => \mmcm_lock_count_reg__0\(1),
      I4 => \mmcm_lock_count_reg__0\(2),
      O => \p_0_in__0\(4)
    );
\mmcm_lock_count[5]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"6AAAAAAAAAAAAAAA"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(5),
      I1 => \mmcm_lock_count_reg__0\(2),
      I2 => \mmcm_lock_count_reg__0\(1),
      I3 => \mmcm_lock_count_reg__0\(0),
      I4 => \mmcm_lock_count_reg__0\(3),
      I5 => \mmcm_lock_count_reg__0\(4),
      O => \p_0_in__0\(5)
    );
\mmcm_lock_count[6]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"7FFF8000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count[7]_i_4_n_0\,
      I3 => \mmcm_lock_count_reg__0\(5),
      I4 => \mmcm_lock_count_reg__0\(6),
      O => \p_0_in__0\(6)
    );
\mmcm_lock_count[7]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFFFFFFFFFF"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count[7]_i_4_n_0\,
      I3 => \mmcm_lock_count_reg__0\(5),
      I4 => \mmcm_lock_count_reg__0\(6),
      I5 => \mmcm_lock_count_reg__0\(7),
      O => \mmcm_lock_count[7]_i_2_n_0\
    );
\mmcm_lock_count[7]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFF80000000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(6),
      I1 => \mmcm_lock_count_reg__0\(5),
      I2 => \mmcm_lock_count[7]_i_4_n_0\,
      I3 => \mmcm_lock_count_reg__0\(3),
      I4 => \mmcm_lock_count_reg__0\(4),
      I5 => \mmcm_lock_count_reg__0\(7),
      O => \p_0_in__0\(7)
    );
\mmcm_lock_count[7]_i_4\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(2),
      I1 => \mmcm_lock_count_reg__0\(1),
      I2 => \mmcm_lock_count_reg__0\(0),
      O => \mmcm_lock_count[7]_i_4_n_0\
    );
\mmcm_lock_count_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(0),
      Q => \mmcm_lock_count_reg__0\(0),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(1),
      Q => \mmcm_lock_count_reg__0\(1),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(2),
      Q => \mmcm_lock_count_reg__0\(2),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(3),
      Q => \mmcm_lock_count_reg__0\(3),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(4),
      Q => \mmcm_lock_count_reg__0\(4),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(5),
      Q => \mmcm_lock_count_reg__0\(5),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(6),
      Q => \mmcm_lock_count_reg__0\(6),
      R => sync_mmcm_lock_reclocked_n_0
    );
\mmcm_lock_count_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \mmcm_lock_count[7]_i_2_n_0\,
      D => \p_0_in__0\(7),
      Q => \mmcm_lock_count_reg__0\(7),
      R => sync_mmcm_lock_reclocked_n_0
    );
mmcm_lock_reclocked_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"80000000"
    )
        port map (
      I0 => \mmcm_lock_count_reg__0\(4),
      I1 => \mmcm_lock_count_reg__0\(3),
      I2 => \mmcm_lock_count_reg__0\(0),
      I3 => \mmcm_lock_count_reg__0\(1),
      I4 => \mmcm_lock_count_reg__0\(2),
      O => mmcm_lock_reclocked_i_2_n_0
    );
mmcm_lock_reclocked_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => sync_mmcm_lock_reclocked_n_1,
      Q => mmcm_lock_reclocked,
      R => '0'
    );
pll_reset_asserted_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"EFFFEFFF00100000"
    )
        port map (
      I0 => tx_state(2),
      I1 => tx_state(3),
      I2 => tx_state(0),
      I3 => tx_state(1),
      I4 => CPLL_RESET0,
      I5 => pll_reset_asserted_reg_n_0,
      O => pll_reset_asserted_i_1_n_0
    );
pll_reset_asserted_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"57"
    )
        port map (
      I0 => refclk_stable,
      I1 => CPLLREFCLKLOST,
      I2 => pll_reset_asserted_reg_n_0,
      O => CPLL_RESET0
    );
pll_reset_asserted_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => pll_reset_asserted_i_1_n_0,
      Q => pll_reset_asserted_reg_n_0,
      R => pma_reset
    );
\refclk_stable_count[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => refclk_stable_reg_i_1_n_1,
      O => \refclk_stable_count[0]_i_1_n_0\
    );
\refclk_stable_count[0]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(3),
      O => \refclk_stable_count[0]_i_3_n_0\
    );
\refclk_stable_count[0]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(2),
      O => \refclk_stable_count[0]_i_4_n_0\
    );
\refclk_stable_count[0]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(1),
      O => \refclk_stable_count[0]_i_5_n_0\
    );
\refclk_stable_count[0]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => refclk_stable_count_reg(0),
      O => \refclk_stable_count[0]_i_6_n_0\
    );
\refclk_stable_count[12]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(15),
      O => \refclk_stable_count[12]_i_2_n_0\
    );
\refclk_stable_count[12]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(14),
      O => \refclk_stable_count[12]_i_3_n_0\
    );
\refclk_stable_count[12]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(13),
      O => \refclk_stable_count[12]_i_4_n_0\
    );
\refclk_stable_count[12]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(12),
      O => \refclk_stable_count[12]_i_5_n_0\
    );
\refclk_stable_count[16]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(19),
      O => \refclk_stable_count[16]_i_2_n_0\
    );
\refclk_stable_count[16]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(18),
      O => \refclk_stable_count[16]_i_3_n_0\
    );
\refclk_stable_count[16]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(17),
      O => \refclk_stable_count[16]_i_4_n_0\
    );
\refclk_stable_count[16]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(16),
      O => \refclk_stable_count[16]_i_5_n_0\
    );
\refclk_stable_count[20]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(23),
      O => \refclk_stable_count[20]_i_2_n_0\
    );
\refclk_stable_count[20]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(22),
      O => \refclk_stable_count[20]_i_3_n_0\
    );
\refclk_stable_count[20]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(21),
      O => \refclk_stable_count[20]_i_4_n_0\
    );
\refclk_stable_count[20]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(20),
      O => \refclk_stable_count[20]_i_5_n_0\
    );
\refclk_stable_count[24]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(27),
      O => \refclk_stable_count[24]_i_2_n_0\
    );
\refclk_stable_count[24]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(26),
      O => \refclk_stable_count[24]_i_3_n_0\
    );
\refclk_stable_count[24]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(25),
      O => \refclk_stable_count[24]_i_4_n_0\
    );
\refclk_stable_count[24]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(24),
      O => \refclk_stable_count[24]_i_5_n_0\
    );
\refclk_stable_count[28]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(31),
      O => \refclk_stable_count[28]_i_2_n_0\
    );
\refclk_stable_count[28]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(30),
      O => \refclk_stable_count[28]_i_3_n_0\
    );
\refclk_stable_count[28]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(29),
      O => \refclk_stable_count[28]_i_4_n_0\
    );
\refclk_stable_count[28]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(28),
      O => \refclk_stable_count[28]_i_5_n_0\
    );
\refclk_stable_count[4]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(7),
      O => \refclk_stable_count[4]_i_2_n_0\
    );
\refclk_stable_count[4]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(6),
      O => \refclk_stable_count[4]_i_3_n_0\
    );
\refclk_stable_count[4]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(5),
      O => \refclk_stable_count[4]_i_4_n_0\
    );
\refclk_stable_count[4]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(4),
      O => \refclk_stable_count[4]_i_5_n_0\
    );
\refclk_stable_count[8]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(11),
      O => \refclk_stable_count[8]_i_2_n_0\
    );
\refclk_stable_count[8]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(10),
      O => \refclk_stable_count[8]_i_3_n_0\
    );
\refclk_stable_count[8]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(9),
      O => \refclk_stable_count[8]_i_4_n_0\
    );
\refclk_stable_count[8]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => refclk_stable_count_reg(8),
      O => \refclk_stable_count[8]_i_5_n_0\
    );
\refclk_stable_count_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[0]_i_2_n_7\,
      Q => refclk_stable_count_reg(0),
      R => '0'
    );
\refclk_stable_count_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \refclk_stable_count_reg[0]_i_2_n_0\,
      CO(2) => \refclk_stable_count_reg[0]_i_2_n_1\,
      CO(1) => \refclk_stable_count_reg[0]_i_2_n_2\,
      CO(0) => \refclk_stable_count_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \refclk_stable_count_reg[0]_i_2_n_4\,
      O(2) => \refclk_stable_count_reg[0]_i_2_n_5\,
      O(1) => \refclk_stable_count_reg[0]_i_2_n_6\,
      O(0) => \refclk_stable_count_reg[0]_i_2_n_7\,
      S(3) => \refclk_stable_count[0]_i_3_n_0\,
      S(2) => \refclk_stable_count[0]_i_4_n_0\,
      S(1) => \refclk_stable_count[0]_i_5_n_0\,
      S(0) => \refclk_stable_count[0]_i_6_n_0\
    );
\refclk_stable_count_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[8]_i_1_n_5\,
      Q => refclk_stable_count_reg(10),
      R => '0'
    );
\refclk_stable_count_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[8]_i_1_n_4\,
      Q => refclk_stable_count_reg(11),
      R => '0'
    );
\refclk_stable_count_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[12]_i_1_n_7\,
      Q => refclk_stable_count_reg(12),
      R => '0'
    );
\refclk_stable_count_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[8]_i_1_n_0\,
      CO(3) => \refclk_stable_count_reg[12]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[12]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[12]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[12]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[12]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[12]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[12]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[12]_i_1_n_7\,
      S(3) => \refclk_stable_count[12]_i_2_n_0\,
      S(2) => \refclk_stable_count[12]_i_3_n_0\,
      S(1) => \refclk_stable_count[12]_i_4_n_0\,
      S(0) => \refclk_stable_count[12]_i_5_n_0\
    );
\refclk_stable_count_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[12]_i_1_n_6\,
      Q => refclk_stable_count_reg(13),
      R => '0'
    );
\refclk_stable_count_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[12]_i_1_n_5\,
      Q => refclk_stable_count_reg(14),
      R => '0'
    );
\refclk_stable_count_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[12]_i_1_n_4\,
      Q => refclk_stable_count_reg(15),
      R => '0'
    );
\refclk_stable_count_reg[16]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[16]_i_1_n_7\,
      Q => refclk_stable_count_reg(16),
      R => '0'
    );
\refclk_stable_count_reg[16]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[12]_i_1_n_0\,
      CO(3) => \refclk_stable_count_reg[16]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[16]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[16]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[16]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[16]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[16]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[16]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[16]_i_1_n_7\,
      S(3) => \refclk_stable_count[16]_i_2_n_0\,
      S(2) => \refclk_stable_count[16]_i_3_n_0\,
      S(1) => \refclk_stable_count[16]_i_4_n_0\,
      S(0) => \refclk_stable_count[16]_i_5_n_0\
    );
\refclk_stable_count_reg[17]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[16]_i_1_n_6\,
      Q => refclk_stable_count_reg(17),
      R => '0'
    );
\refclk_stable_count_reg[18]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[16]_i_1_n_5\,
      Q => refclk_stable_count_reg(18),
      R => '0'
    );
\refclk_stable_count_reg[19]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[16]_i_1_n_4\,
      Q => refclk_stable_count_reg(19),
      R => '0'
    );
\refclk_stable_count_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[0]_i_2_n_6\,
      Q => refclk_stable_count_reg(1),
      R => '0'
    );
\refclk_stable_count_reg[20]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[20]_i_1_n_7\,
      Q => refclk_stable_count_reg(20),
      R => '0'
    );
\refclk_stable_count_reg[20]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[16]_i_1_n_0\,
      CO(3) => \refclk_stable_count_reg[20]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[20]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[20]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[20]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[20]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[20]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[20]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[20]_i_1_n_7\,
      S(3) => \refclk_stable_count[20]_i_2_n_0\,
      S(2) => \refclk_stable_count[20]_i_3_n_0\,
      S(1) => \refclk_stable_count[20]_i_4_n_0\,
      S(0) => \refclk_stable_count[20]_i_5_n_0\
    );
\refclk_stable_count_reg[21]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[20]_i_1_n_6\,
      Q => refclk_stable_count_reg(21),
      R => '0'
    );
\refclk_stable_count_reg[22]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[20]_i_1_n_5\,
      Q => refclk_stable_count_reg(22),
      R => '0'
    );
\refclk_stable_count_reg[23]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[20]_i_1_n_4\,
      Q => refclk_stable_count_reg(23),
      R => '0'
    );
\refclk_stable_count_reg[24]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[24]_i_1_n_7\,
      Q => refclk_stable_count_reg(24),
      R => '0'
    );
\refclk_stable_count_reg[24]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[20]_i_1_n_0\,
      CO(3) => \refclk_stable_count_reg[24]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[24]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[24]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[24]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[24]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[24]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[24]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[24]_i_1_n_7\,
      S(3) => \refclk_stable_count[24]_i_2_n_0\,
      S(2) => \refclk_stable_count[24]_i_3_n_0\,
      S(1) => \refclk_stable_count[24]_i_4_n_0\,
      S(0) => \refclk_stable_count[24]_i_5_n_0\
    );
\refclk_stable_count_reg[25]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[24]_i_1_n_6\,
      Q => refclk_stable_count_reg(25),
      R => '0'
    );
\refclk_stable_count_reg[26]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[24]_i_1_n_5\,
      Q => refclk_stable_count_reg(26),
      R => '0'
    );
\refclk_stable_count_reg[27]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[24]_i_1_n_4\,
      Q => refclk_stable_count_reg(27),
      R => '0'
    );
\refclk_stable_count_reg[28]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[28]_i_1_n_7\,
      Q => refclk_stable_count_reg(28),
      R => '0'
    );
\refclk_stable_count_reg[28]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[24]_i_1_n_0\,
      CO(3) => \NLW_refclk_stable_count_reg[28]_i_1_CO_UNCONNECTED\(3),
      CO(2) => \refclk_stable_count_reg[28]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[28]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[28]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[28]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[28]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[28]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[28]_i_1_n_7\,
      S(3) => \refclk_stable_count[28]_i_2_n_0\,
      S(2) => \refclk_stable_count[28]_i_3_n_0\,
      S(1) => \refclk_stable_count[28]_i_4_n_0\,
      S(0) => \refclk_stable_count[28]_i_5_n_0\
    );
\refclk_stable_count_reg[29]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[28]_i_1_n_6\,
      Q => refclk_stable_count_reg(29),
      R => '0'
    );
\refclk_stable_count_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[0]_i_2_n_5\,
      Q => refclk_stable_count_reg(2),
      R => '0'
    );
\refclk_stable_count_reg[30]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[28]_i_1_n_5\,
      Q => refclk_stable_count_reg(30),
      R => '0'
    );
\refclk_stable_count_reg[31]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[28]_i_1_n_4\,
      Q => refclk_stable_count_reg(31),
      R => '0'
    );
\refclk_stable_count_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[0]_i_2_n_4\,
      Q => refclk_stable_count_reg(3),
      R => '0'
    );
\refclk_stable_count_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[4]_i_1_n_7\,
      Q => refclk_stable_count_reg(4),
      R => '0'
    );
\refclk_stable_count_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[0]_i_2_n_0\,
      CO(3) => \refclk_stable_count_reg[4]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[4]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[4]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[4]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[4]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[4]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[4]_i_1_n_7\,
      S(3) => \refclk_stable_count[4]_i_2_n_0\,
      S(2) => \refclk_stable_count[4]_i_3_n_0\,
      S(1) => \refclk_stable_count[4]_i_4_n_0\,
      S(0) => \refclk_stable_count[4]_i_5_n_0\
    );
\refclk_stable_count_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[4]_i_1_n_6\,
      Q => refclk_stable_count_reg(5),
      R => '0'
    );
\refclk_stable_count_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[4]_i_1_n_5\,
      Q => refclk_stable_count_reg(6),
      R => '0'
    );
\refclk_stable_count_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[4]_i_1_n_4\,
      Q => refclk_stable_count_reg(7),
      R => '0'
    );
\refclk_stable_count_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[8]_i_1_n_7\,
      Q => refclk_stable_count_reg(8),
      R => '0'
    );
\refclk_stable_count_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \refclk_stable_count_reg[4]_i_1_n_0\,
      CO(3) => \refclk_stable_count_reg[8]_i_1_n_0\,
      CO(2) => \refclk_stable_count_reg[8]_i_1_n_1\,
      CO(1) => \refclk_stable_count_reg[8]_i_1_n_2\,
      CO(0) => \refclk_stable_count_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \refclk_stable_count_reg[8]_i_1_n_4\,
      O(2) => \refclk_stable_count_reg[8]_i_1_n_5\,
      O(1) => \refclk_stable_count_reg[8]_i_1_n_6\,
      O(0) => \refclk_stable_count_reg[8]_i_1_n_7\,
      S(3) => \refclk_stable_count[8]_i_2_n_0\,
      S(2) => \refclk_stable_count[8]_i_3_n_0\,
      S(1) => \refclk_stable_count[8]_i_4_n_0\,
      S(0) => \refclk_stable_count[8]_i_5_n_0\
    );
\refclk_stable_count_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \refclk_stable_count[0]_i_1_n_0\,
      D => \refclk_stable_count_reg[8]_i_1_n_6\,
      Q => refclk_stable_count_reg(9),
      R => '0'
    );
refclk_stable_i_10: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => refclk_stable_count_reg(14),
      I1 => refclk_stable_count_reg(13),
      I2 => refclk_stable_count_reg(12),
      O => refclk_stable_i_10_n_0
    );
refclk_stable_i_11: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => refclk_stable_count_reg(11),
      I1 => refclk_stable_count_reg(10),
      I2 => refclk_stable_count_reg(9),
      O => refclk_stable_i_11_n_0
    );
refclk_stable_i_12: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => refclk_stable_count_reg(8),
      I1 => refclk_stable_count_reg(7),
      I2 => refclk_stable_count_reg(6),
      O => refclk_stable_i_12_n_0
    );
refclk_stable_i_13: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => refclk_stable_count_reg(5),
      I1 => refclk_stable_count_reg(4),
      I2 => refclk_stable_count_reg(3),
      O => refclk_stable_i_13_n_0
    );
refclk_stable_i_14: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => refclk_stable_count_reg(2),
      I1 => refclk_stable_count_reg(1),
      I2 => refclk_stable_count_reg(0),
      O => refclk_stable_i_14_n_0
    );
refclk_stable_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => refclk_stable_count_reg(31),
      I1 => refclk_stable_count_reg(30),
      O => refclk_stable_i_3_n_0
    );
refclk_stable_i_4: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => refclk_stable_count_reg(29),
      I1 => refclk_stable_count_reg(28),
      I2 => refclk_stable_count_reg(27),
      O => refclk_stable_i_4_n_0
    );
refclk_stable_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => refclk_stable_count_reg(26),
      I1 => refclk_stable_count_reg(25),
      I2 => refclk_stable_count_reg(24),
      O => refclk_stable_i_5_n_0
    );
refclk_stable_i_7: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => refclk_stable_count_reg(23),
      I1 => refclk_stable_count_reg(22),
      I2 => refclk_stable_count_reg(21),
      O => refclk_stable_i_7_n_0
    );
refclk_stable_i_8: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => refclk_stable_count_reg(20),
      I1 => refclk_stable_count_reg(19),
      I2 => refclk_stable_count_reg(18),
      O => refclk_stable_i_8_n_0
    );
refclk_stable_i_9: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => refclk_stable_count_reg(17),
      I1 => refclk_stable_count_reg(16),
      I2 => refclk_stable_count_reg(15),
      O => refclk_stable_i_9_n_0
    );
refclk_stable_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => refclk_stable_reg_i_1_n_1,
      Q => refclk_stable,
      R => '0'
    );
refclk_stable_reg_i_1: unisim.vcomponents.CARRY4
     port map (
      CI => refclk_stable_reg_i_2_n_0,
      CO(3) => NLW_refclk_stable_reg_i_1_CO_UNCONNECTED(3),
      CO(2) => refclk_stable_reg_i_1_n_1,
      CO(1) => refclk_stable_reg_i_1_n_2,
      CO(0) => refclk_stable_reg_i_1_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_refclk_stable_reg_i_1_O_UNCONNECTED(3 downto 0),
      S(3) => '0',
      S(2) => refclk_stable_i_3_n_0,
      S(1) => refclk_stable_i_4_n_0,
      S(0) => refclk_stable_i_5_n_0
    );
refclk_stable_reg_i_2: unisim.vcomponents.CARRY4
     port map (
      CI => refclk_stable_reg_i_6_n_0,
      CO(3) => refclk_stable_reg_i_2_n_0,
      CO(2) => refclk_stable_reg_i_2_n_1,
      CO(1) => refclk_stable_reg_i_2_n_2,
      CO(0) => refclk_stable_reg_i_2_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_refclk_stable_reg_i_2_O_UNCONNECTED(3 downto 0),
      S(3) => refclk_stable_i_7_n_0,
      S(2) => refclk_stable_i_8_n_0,
      S(1) => refclk_stable_i_9_n_0,
      S(0) => refclk_stable_i_10_n_0
    );
refclk_stable_reg_i_6: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => refclk_stable_reg_i_6_n_0,
      CO(2) => refclk_stable_reg_i_6_n_1,
      CO(1) => refclk_stable_reg_i_6_n_2,
      CO(0) => refclk_stable_reg_i_6_n_3,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_refclk_stable_reg_i_6_O_UNCONNECTED(3 downto 0),
      S(3) => refclk_stable_i_11_n_0,
      S(2) => refclk_stable_i_12_n_0,
      S(1) => refclk_stable_i_13_n_0,
      S(0) => refclk_stable_i_14_n_0
    );
reset_time_out_i_3: unisim.vcomponents.LUT3
    generic map(
      INIT => X"70"
    )
        port map (
      I0 => tx_state(3),
      I1 => tx_state(2),
      I2 => tx_state(0),
      O => reset_time_out_i_3_n_0
    );
reset_time_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => sync_cplllock_n_0,
      Q => reset_time_out,
      R => pma_reset
    );
run_phase_alignment_int_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFD0004"
    )
        port map (
      I0 => tx_state(0),
      I1 => tx_state(3),
      I2 => tx_state(1),
      I3 => tx_state(2),
      I4 => run_phase_alignment_int_reg_n_0,
      O => run_phase_alignment_int_i_1_n_0
    );
run_phase_alignment_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => run_phase_alignment_int_i_1_n_0,
      Q => run_phase_alignment_int_reg_n_0,
      R => pma_reset
    );
run_phase_alignment_int_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => data_out,
      Q => run_phase_alignment_int_s3,
      R => '0'
    );
sync_TXRESETDONE: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_8
     port map (
      \cpllpd_wait_reg[95]\ => \cpllpd_wait_reg[95]\,
      data_out => txresetdone_s2,
      independent_clock_bufg => independent_clock_bufg
    );
sync_cplllock: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_9
     port map (
      E(0) => sync_cplllock_n_1,
      \FSM_sequential_tx_state_reg[2]\ => \FSM_sequential_tx_state[3]_i_4_n_0\,
      \FSM_sequential_tx_state_reg[3]\ => reset_time_out_i_3_n_0,
      cplllock => cplllock,
      independent_clock_bufg => independent_clock_bufg,
      init_wait_done_reg => init_wait_done_reg_n_0,
      mmcm_lock_reclocked => mmcm_lock_reclocked,
      \out\(3 downto 0) => tx_state(3 downto 0),
      pll_reset_asserted_reg => pll_reset_asserted_reg_n_0,
      refclk_stable => refclk_stable,
      reset_time_out => reset_time_out,
      reset_time_out_reg => sync_cplllock_n_0,
      time_out_2ms => time_out_2ms,
      time_out_500us => time_out_500us,
      time_tlock_max_reg => \FSM_sequential_tx_state[3]_i_7_n_0\,
      txresetdone_s3 => txresetdone_s3,
      \wait_time_cnt_reg[6]\(0) => \wait_time_cnt[6]_i_2_n_0\
    );
sync_mmcm_lock_reclocked: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_10
     port map (
      Q(2 downto 0) => \mmcm_lock_count_reg__0\(7 downto 5),
      SR(0) => sync_mmcm_lock_reclocked_n_0,
      independent_clock_bufg => independent_clock_bufg,
      \mmcm_lock_count_reg[4]\ => mmcm_lock_reclocked_i_2_n_0,
      mmcm_lock_reclocked => mmcm_lock_reclocked,
      mmcm_lock_reclocked_reg => sync_mmcm_lock_reclocked_n_1,
      mmcm_locked => mmcm_locked
    );
sync_run_phase_alignment_int: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_11
     port map (
      data_in => run_phase_alignment_int_reg_n_0,
      data_out => data_out,
      userclk => userclk
    );
sync_time_out_wait_bypass: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_12
     port map (
      data_in => time_out_wait_bypass_reg_n_0,
      data_out => time_out_wait_bypass_s2,
      independent_clock_bufg => independent_clock_bufg
    );
sync_tx_fsm_reset_done_int: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_13
     port map (
      data_in => \^data_in\,
      data_out => tx_fsm_reset_done_int_s2,
      userclk => userclk
    );
time_out_2ms_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"0E"
    )
        port map (
      I0 => time_out_2ms,
      I1 => \time_out_counter_reg[0]_i_3_n_1\,
      I2 => reset_time_out,
      O => time_out_2ms_i_1_n_0
    );
time_out_2ms_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_2ms_i_1_n_0,
      Q => time_out_2ms,
      R => '0'
    );
time_out_500us_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"0E"
    )
        port map (
      I0 => time_out_500us,
      I1 => time_out_500us_reg_i_2_n_1,
      I2 => reset_time_out,
      O => time_out_500us_i_1_n_0
    );
time_out_500us_i_10: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(2),
      I1 => time_out_counter_reg(1),
      I2 => time_out_counter_reg(0),
      O => time_out_500us_i_10_n_0
    );
time_out_500us_i_4: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(18),
      O => time_out_500us_i_4_n_0
    );
time_out_500us_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      I2 => time_out_counter_reg(15),
      O => time_out_500us_i_5_n_0
    );
time_out_500us_i_6: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(14),
      I1 => time_out_counter_reg(13),
      I2 => time_out_counter_reg(12),
      O => time_out_500us_i_6_n_0
    );
time_out_500us_i_7: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => time_out_counter_reg(11),
      I1 => time_out_counter_reg(10),
      I2 => time_out_counter_reg(9),
      O => time_out_500us_i_7_n_0
    );
time_out_500us_i_8: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(6),
      O => time_out_500us_i_8_n_0
    );
time_out_500us_i_9: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(4),
      I1 => time_out_counter_reg(5),
      I2 => time_out_counter_reg(3),
      O => time_out_500us_i_9_n_0
    );
time_out_500us_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_500us_i_1_n_0,
      Q => time_out_500us,
      R => '0'
    );
time_out_500us_reg_i_2: unisim.vcomponents.CARRY4
     port map (
      CI => time_out_500us_reg_i_3_n_0,
      CO(3) => NLW_time_out_500us_reg_i_2_CO_UNCONNECTED(3),
      CO(2) => time_out_500us_reg_i_2_n_1,
      CO(1) => time_out_500us_reg_i_2_n_2,
      CO(0) => time_out_500us_reg_i_2_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_500us_reg_i_2_O_UNCONNECTED(3 downto 0),
      S(3) => '0',
      S(2) => time_out_500us_i_4_n_0,
      S(1) => time_out_500us_i_5_n_0,
      S(0) => time_out_500us_i_6_n_0
    );
time_out_500us_reg_i_3: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => time_out_500us_reg_i_3_n_0,
      CO(2) => time_out_500us_reg_i_3_n_1,
      CO(1) => time_out_500us_reg_i_3_n_2,
      CO(0) => time_out_500us_reg_i_3_n_3,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_out_500us_reg_i_3_O_UNCONNECTED(3 downto 0),
      S(3) => time_out_500us_i_7_n_0,
      S(2) => time_out_500us_i_8_n_0,
      S(1) => time_out_500us_i_9_n_0,
      S(0) => time_out_500us_i_10_n_0
    );
\time_out_counter[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \time_out_counter_reg[0]_i_3_n_1\,
      O => \time_out_counter[0]_i_1_n_0\
    );
\time_out_counter[0]_i_10\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(16),
      I1 => time_out_counter_reg(17),
      I2 => time_out_counter_reg(15),
      O => \time_out_counter[0]_i_10_n_0\
    );
\time_out_counter[0]_i_11\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"10"
    )
        port map (
      I0 => time_out_counter_reg(14),
      I1 => time_out_counter_reg(13),
      I2 => time_out_counter_reg(12),
      O => \time_out_counter[0]_i_11_n_0\
    );
\time_out_counter[0]_i_12\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
        port map (
      I0 => time_out_counter_reg(10),
      I1 => time_out_counter_reg(11),
      I2 => time_out_counter_reg(9),
      O => \time_out_counter[0]_i_12_n_0\
    );
\time_out_counter[0]_i_13__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(6),
      O => \time_out_counter[0]_i_13__0_n_0\
    );
\time_out_counter[0]_i_14\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(5),
      I1 => time_out_counter_reg(4),
      I2 => time_out_counter_reg(3),
      O => \time_out_counter[0]_i_14_n_0\
    );
\time_out_counter[0]_i_15\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(2),
      I1 => time_out_counter_reg(1),
      I2 => time_out_counter_reg(0),
      O => \time_out_counter[0]_i_15_n_0\
    );
\time_out_counter[0]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(3),
      O => \time_out_counter[0]_i_4_n_0\
    );
\time_out_counter[0]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(2),
      O => \time_out_counter[0]_i_5_n_0\
    );
\time_out_counter[0]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(1),
      O => \time_out_counter[0]_i_6_n_0\
    );
\time_out_counter[0]_i_7__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(0),
      O => \time_out_counter[0]_i_7__0_n_0\
    );
\time_out_counter[0]_i_9__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(18),
      O => \time_out_counter[0]_i_9__0_n_0\
    );
\time_out_counter[12]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(15),
      O => \time_out_counter[12]_i_2_n_0\
    );
\time_out_counter[12]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(14),
      O => \time_out_counter[12]_i_3_n_0\
    );
\time_out_counter[12]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(13),
      O => \time_out_counter[12]_i_4_n_0\
    );
\time_out_counter[12]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(12),
      O => \time_out_counter[12]_i_5_n_0\
    );
\time_out_counter[16]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(18),
      O => \time_out_counter[16]_i_2_n_0\
    );
\time_out_counter[16]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(17),
      O => \time_out_counter[16]_i_3_n_0\
    );
\time_out_counter[16]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(16),
      O => \time_out_counter[16]_i_4_n_0\
    );
\time_out_counter[4]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(7),
      O => \time_out_counter[4]_i_2_n_0\
    );
\time_out_counter[4]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(6),
      O => \time_out_counter[4]_i_3_n_0\
    );
\time_out_counter[4]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(5),
      O => \time_out_counter[4]_i_4_n_0\
    );
\time_out_counter[4]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(4),
      O => \time_out_counter[4]_i_5_n_0\
    );
\time_out_counter[8]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(11),
      O => \time_out_counter[8]_i_2_n_0\
    );
\time_out_counter[8]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(10),
      O => \time_out_counter[8]_i_3_n_0\
    );
\time_out_counter[8]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(9),
      O => \time_out_counter[8]_i_4_n_0\
    );
\time_out_counter[8]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => time_out_counter_reg(8),
      O => \time_out_counter[8]_i_5_n_0\
    );
\time_out_counter_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[0]_i_2_n_7\,
      Q => time_out_counter_reg(0),
      R => reset_time_out
    );
\time_out_counter_reg[0]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \time_out_counter_reg[0]_i_2_n_0\,
      CO(2) => \time_out_counter_reg[0]_i_2_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_2_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \time_out_counter_reg[0]_i_2_n_4\,
      O(2) => \time_out_counter_reg[0]_i_2_n_5\,
      O(1) => \time_out_counter_reg[0]_i_2_n_6\,
      O(0) => \time_out_counter_reg[0]_i_2_n_7\,
      S(3) => \time_out_counter[0]_i_4_n_0\,
      S(2) => \time_out_counter[0]_i_5_n_0\,
      S(1) => \time_out_counter[0]_i_6_n_0\,
      S(0) => \time_out_counter[0]_i_7__0_n_0\
    );
\time_out_counter_reg[0]_i_3\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[0]_i_8_n_0\,
      CO(3) => \NLW_time_out_counter_reg[0]_i_3_CO_UNCONNECTED\(3),
      CO(2) => \time_out_counter_reg[0]_i_3_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_3_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_3_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_time_out_counter_reg[0]_i_3_O_UNCONNECTED\(3 downto 0),
      S(3) => '0',
      S(2) => \time_out_counter[0]_i_9__0_n_0\,
      S(1) => \time_out_counter[0]_i_10_n_0\,
      S(0) => \time_out_counter[0]_i_11_n_0\
    );
\time_out_counter_reg[0]_i_8\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \time_out_counter_reg[0]_i_8_n_0\,
      CO(2) => \time_out_counter_reg[0]_i_8_n_1\,
      CO(1) => \time_out_counter_reg[0]_i_8_n_2\,
      CO(0) => \time_out_counter_reg[0]_i_8_n_3\,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_time_out_counter_reg[0]_i_8_O_UNCONNECTED\(3 downto 0),
      S(3) => \time_out_counter[0]_i_12_n_0\,
      S(2) => \time_out_counter[0]_i_13__0_n_0\,
      S(1) => \time_out_counter[0]_i_14_n_0\,
      S(0) => \time_out_counter[0]_i_15_n_0\
    );
\time_out_counter_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[8]_i_1_n_5\,
      Q => time_out_counter_reg(10),
      R => reset_time_out
    );
\time_out_counter_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[8]_i_1_n_4\,
      Q => time_out_counter_reg(11),
      R => reset_time_out
    );
\time_out_counter_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[12]_i_1_n_7\,
      Q => time_out_counter_reg(12),
      R => reset_time_out
    );
\time_out_counter_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[8]_i_1_n_0\,
      CO(3) => \time_out_counter_reg[12]_i_1_n_0\,
      CO(2) => \time_out_counter_reg[12]_i_1_n_1\,
      CO(1) => \time_out_counter_reg[12]_i_1_n_2\,
      CO(0) => \time_out_counter_reg[12]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[12]_i_1_n_4\,
      O(2) => \time_out_counter_reg[12]_i_1_n_5\,
      O(1) => \time_out_counter_reg[12]_i_1_n_6\,
      O(0) => \time_out_counter_reg[12]_i_1_n_7\,
      S(3) => \time_out_counter[12]_i_2_n_0\,
      S(2) => \time_out_counter[12]_i_3_n_0\,
      S(1) => \time_out_counter[12]_i_4_n_0\,
      S(0) => \time_out_counter[12]_i_5_n_0\
    );
\time_out_counter_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[12]_i_1_n_6\,
      Q => time_out_counter_reg(13),
      R => reset_time_out
    );
\time_out_counter_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[12]_i_1_n_5\,
      Q => time_out_counter_reg(14),
      R => reset_time_out
    );
\time_out_counter_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[12]_i_1_n_4\,
      Q => time_out_counter_reg(15),
      R => reset_time_out
    );
\time_out_counter_reg[16]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[16]_i_1_n_7\,
      Q => time_out_counter_reg(16),
      R => reset_time_out
    );
\time_out_counter_reg[16]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[12]_i_1_n_0\,
      CO(3 downto 2) => \NLW_time_out_counter_reg[16]_i_1_CO_UNCONNECTED\(3 downto 2),
      CO(1) => \time_out_counter_reg[16]_i_1_n_2\,
      CO(0) => \time_out_counter_reg[16]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \NLW_time_out_counter_reg[16]_i_1_O_UNCONNECTED\(3),
      O(2) => \time_out_counter_reg[16]_i_1_n_5\,
      O(1) => \time_out_counter_reg[16]_i_1_n_6\,
      O(0) => \time_out_counter_reg[16]_i_1_n_7\,
      S(3) => '0',
      S(2) => \time_out_counter[16]_i_2_n_0\,
      S(1) => \time_out_counter[16]_i_3_n_0\,
      S(0) => \time_out_counter[16]_i_4_n_0\
    );
\time_out_counter_reg[17]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[16]_i_1_n_6\,
      Q => time_out_counter_reg(17),
      R => reset_time_out
    );
\time_out_counter_reg[18]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[16]_i_1_n_5\,
      Q => time_out_counter_reg(18),
      R => reset_time_out
    );
\time_out_counter_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[0]_i_2_n_6\,
      Q => time_out_counter_reg(1),
      R => reset_time_out
    );
\time_out_counter_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[0]_i_2_n_5\,
      Q => time_out_counter_reg(2),
      R => reset_time_out
    );
\time_out_counter_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[0]_i_2_n_4\,
      Q => time_out_counter_reg(3),
      R => reset_time_out
    );
\time_out_counter_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[4]_i_1_n_7\,
      Q => time_out_counter_reg(4),
      R => reset_time_out
    );
\time_out_counter_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[0]_i_2_n_0\,
      CO(3) => \time_out_counter_reg[4]_i_1_n_0\,
      CO(2) => \time_out_counter_reg[4]_i_1_n_1\,
      CO(1) => \time_out_counter_reg[4]_i_1_n_2\,
      CO(0) => \time_out_counter_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[4]_i_1_n_4\,
      O(2) => \time_out_counter_reg[4]_i_1_n_5\,
      O(1) => \time_out_counter_reg[4]_i_1_n_6\,
      O(0) => \time_out_counter_reg[4]_i_1_n_7\,
      S(3) => \time_out_counter[4]_i_2_n_0\,
      S(2) => \time_out_counter[4]_i_3_n_0\,
      S(1) => \time_out_counter[4]_i_4_n_0\,
      S(0) => \time_out_counter[4]_i_5_n_0\
    );
\time_out_counter_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[4]_i_1_n_6\,
      Q => time_out_counter_reg(5),
      R => reset_time_out
    );
\time_out_counter_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[4]_i_1_n_5\,
      Q => time_out_counter_reg(6),
      R => reset_time_out
    );
\time_out_counter_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[4]_i_1_n_4\,
      Q => time_out_counter_reg(7),
      R => reset_time_out
    );
\time_out_counter_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[8]_i_1_n_7\,
      Q => time_out_counter_reg(8),
      R => reset_time_out
    );
\time_out_counter_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \time_out_counter_reg[4]_i_1_n_0\,
      CO(3) => \time_out_counter_reg[8]_i_1_n_0\,
      CO(2) => \time_out_counter_reg[8]_i_1_n_1\,
      CO(1) => \time_out_counter_reg[8]_i_1_n_2\,
      CO(0) => \time_out_counter_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \time_out_counter_reg[8]_i_1_n_4\,
      O(2) => \time_out_counter_reg[8]_i_1_n_5\,
      O(1) => \time_out_counter_reg[8]_i_1_n_6\,
      O(0) => \time_out_counter_reg[8]_i_1_n_7\,
      S(3) => \time_out_counter[8]_i_2_n_0\,
      S(2) => \time_out_counter[8]_i_3_n_0\,
      S(1) => \time_out_counter[8]_i_4_n_0\,
      S(0) => \time_out_counter[8]_i_5_n_0\
    );
\time_out_counter_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => \time_out_counter[0]_i_1_n_0\,
      D => \time_out_counter_reg[8]_i_1_n_6\,
      Q => time_out_counter_reg(9),
      R => reset_time_out
    );
time_out_wait_bypass_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"AE00"
    )
        port map (
      I0 => time_out_wait_bypass_reg_n_0,
      I1 => wait_bypass_count1,
      I2 => tx_fsm_reset_done_int_s3,
      I3 => run_phase_alignment_int_s3,
      O => time_out_wait_bypass_i_1_n_0
    );
time_out_wait_bypass_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => time_out_wait_bypass_i_1_n_0,
      Q => time_out_wait_bypass_reg_n_0,
      R => '0'
    );
time_out_wait_bypass_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => time_out_wait_bypass_s2,
      Q => time_out_wait_bypass_s3,
      R => '0'
    );
\time_tlock_max_i_10__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(2),
      I1 => time_out_counter_reg(1),
      I2 => time_out_counter_reg(0),
      O => \time_tlock_max_i_10__0_n_0\
    );
\time_tlock_max_i_1__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"0E"
    )
        port map (
      I0 => time_tlock_max,
      I1 => time_tlock_max_reg_i_2_n_1,
      I2 => reset_time_out,
      O => \time_tlock_max_i_1__0_n_0\
    );
\time_tlock_max_i_4__0\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => time_out_counter_reg(18),
      O => \time_tlock_max_i_4__0_n_0\
    );
time_tlock_max_i_5: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(17),
      I1 => time_out_counter_reg(16),
      I2 => time_out_counter_reg(15),
      O => time_tlock_max_i_5_n_0
    );
time_tlock_max_i_6: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(13),
      I1 => time_out_counter_reg(14),
      I2 => time_out_counter_reg(12),
      O => time_tlock_max_i_6_n_0
    );
time_tlock_max_i_7: unisim.vcomponents.LUT3
    generic map(
      INIT => X"80"
    )
        port map (
      I0 => time_out_counter_reg(11),
      I1 => time_out_counter_reg(10),
      I2 => time_out_counter_reg(9),
      O => time_tlock_max_i_7_n_0
    );
time_tlock_max_i_8: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => time_out_counter_reg(8),
      I1 => time_out_counter_reg(7),
      I2 => time_out_counter_reg(6),
      O => time_tlock_max_i_8_n_0
    );
\time_tlock_max_i_9__0\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => time_out_counter_reg(4),
      I1 => time_out_counter_reg(5),
      I2 => time_out_counter_reg(3),
      O => \time_tlock_max_i_9__0_n_0\
    );
time_tlock_max_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \time_tlock_max_i_1__0_n_0\,
      Q => time_tlock_max,
      R => '0'
    );
time_tlock_max_reg_i_2: unisim.vcomponents.CARRY4
     port map (
      CI => time_tlock_max_reg_i_3_n_0,
      CO(3) => NLW_time_tlock_max_reg_i_2_CO_UNCONNECTED(3),
      CO(2) => time_tlock_max_reg_i_2_n_1,
      CO(1) => time_tlock_max_reg_i_2_n_2,
      CO(0) => time_tlock_max_reg_i_2_n_3,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_tlock_max_reg_i_2_O_UNCONNECTED(3 downto 0),
      S(3) => '0',
      S(2) => \time_tlock_max_i_4__0_n_0\,
      S(1) => time_tlock_max_i_5_n_0,
      S(0) => time_tlock_max_i_6_n_0
    );
time_tlock_max_reg_i_3: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => time_tlock_max_reg_i_3_n_0,
      CO(2) => time_tlock_max_reg_i_3_n_1,
      CO(1) => time_tlock_max_reg_i_3_n_2,
      CO(0) => time_tlock_max_reg_i_3_n_3,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => NLW_time_tlock_max_reg_i_3_O_UNCONNECTED(3 downto 0),
      S(3) => time_tlock_max_i_7_n_0,
      S(2) => time_tlock_max_i_8_n_0,
      S(1) => \time_tlock_max_i_9__0_n_0\,
      S(0) => \time_tlock_max_i_10__0_n_0\
    );
tx_fsm_reset_done_int_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFF0008"
    )
        port map (
      I0 => tx_state(0),
      I1 => tx_state(3),
      I2 => tx_state(1),
      I3 => tx_state(2),
      I4 => \^data_in\,
      O => tx_fsm_reset_done_int_i_1_n_0
    );
tx_fsm_reset_done_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => tx_fsm_reset_done_int_i_1_n_0,
      Q => \^data_in\,
      R => pma_reset
    );
tx_fsm_reset_done_int_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => tx_fsm_reset_done_int_s2,
      Q => tx_fsm_reset_done_int_s3,
      R => '0'
    );
txresetdone_s3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => txresetdone_s2,
      Q => txresetdone_s3,
      R => '0'
    );
\wait_bypass_count[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => run_phase_alignment_int_s3,
      O => clear
    );
\wait_bypass_count[0]_i_10\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0400"
    )
        port map (
      I0 => wait_bypass_count_reg(10),
      I1 => wait_bypass_count_reg(9),
      I2 => wait_bypass_count_reg(8),
      I3 => wait_bypass_count_reg(7),
      O => \wait_bypass_count[0]_i_10_n_0\
    );
\wait_bypass_count[0]_i_11\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000002000000000"
    )
        port map (
      I0 => wait_bypass_count_reg(12),
      I1 => wait_bypass_count_reg(11),
      I2 => wait_bypass_count_reg(14),
      I3 => wait_bypass_count_reg(13),
      I4 => wait_bypass_count_reg(15),
      I5 => wait_bypass_count_reg(16),
      O => \wait_bypass_count[0]_i_11_n_0\
    );
\wait_bypass_count[0]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => tx_fsm_reset_done_int_s3,
      I1 => wait_bypass_count1,
      O => wait_bypass_count
    );
\wait_bypass_count[0]_i_4\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"8000000000000000"
    )
        port map (
      I0 => wait_bypass_count_reg(2),
      I1 => wait_bypass_count_reg(1),
      I2 => wait_bypass_count_reg(0),
      I3 => \wait_bypass_count[0]_i_9_n_0\,
      I4 => \wait_bypass_count[0]_i_10_n_0\,
      I5 => \wait_bypass_count[0]_i_11_n_0\,
      O => wait_bypass_count1
    );
\wait_bypass_count[0]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(3),
      O => \wait_bypass_count[0]_i_5_n_0\
    );
\wait_bypass_count[0]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(2),
      O => \wait_bypass_count[0]_i_6_n_0\
    );
\wait_bypass_count[0]_i_7\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(1),
      O => \wait_bypass_count[0]_i_7_n_0\
    );
\wait_bypass_count[0]_i_8\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => wait_bypass_count_reg(0),
      O => \wait_bypass_count[0]_i_8_n_0\
    );
\wait_bypass_count[0]_i_9\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"8000"
    )
        port map (
      I0 => wait_bypass_count_reg(6),
      I1 => wait_bypass_count_reg(5),
      I2 => wait_bypass_count_reg(4),
      I3 => wait_bypass_count_reg(3),
      O => \wait_bypass_count[0]_i_9_n_0\
    );
\wait_bypass_count[12]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(15),
      O => \wait_bypass_count[12]_i_2_n_0\
    );
\wait_bypass_count[12]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(14),
      O => \wait_bypass_count[12]_i_3_n_0\
    );
\wait_bypass_count[12]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(13),
      O => \wait_bypass_count[12]_i_4_n_0\
    );
\wait_bypass_count[12]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(12),
      O => \wait_bypass_count[12]_i_5_n_0\
    );
\wait_bypass_count[16]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(16),
      O => \wait_bypass_count[16]_i_2_n_0\
    );
\wait_bypass_count[4]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(7),
      O => \wait_bypass_count[4]_i_2_n_0\
    );
\wait_bypass_count[4]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(6),
      O => \wait_bypass_count[4]_i_3_n_0\
    );
\wait_bypass_count[4]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(5),
      O => \wait_bypass_count[4]_i_4_n_0\
    );
\wait_bypass_count[4]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(4),
      O => \wait_bypass_count[4]_i_5_n_0\
    );
\wait_bypass_count[8]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(11),
      O => \wait_bypass_count[8]_i_2_n_0\
    );
\wait_bypass_count[8]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(10),
      O => \wait_bypass_count[8]_i_3_n_0\
    );
\wait_bypass_count[8]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(9),
      O => \wait_bypass_count[8]_i_4_n_0\
    );
\wait_bypass_count[8]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => wait_bypass_count_reg(8),
      O => \wait_bypass_count[8]_i_5_n_0\
    );
\wait_bypass_count_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3_n_7\,
      Q => wait_bypass_count_reg(0),
      R => clear
    );
\wait_bypass_count_reg[0]_i_3\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \wait_bypass_count_reg[0]_i_3_n_0\,
      CO(2) => \wait_bypass_count_reg[0]_i_3_n_1\,
      CO(1) => \wait_bypass_count_reg[0]_i_3_n_2\,
      CO(0) => \wait_bypass_count_reg[0]_i_3_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0001",
      O(3) => \wait_bypass_count_reg[0]_i_3_n_4\,
      O(2) => \wait_bypass_count_reg[0]_i_3_n_5\,
      O(1) => \wait_bypass_count_reg[0]_i_3_n_6\,
      O(0) => \wait_bypass_count_reg[0]_i_3_n_7\,
      S(3) => \wait_bypass_count[0]_i_5_n_0\,
      S(2) => \wait_bypass_count[0]_i_6_n_0\,
      S(1) => \wait_bypass_count[0]_i_7_n_0\,
      S(0) => \wait_bypass_count[0]_i_8_n_0\
    );
\wait_bypass_count_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1_n_5\,
      Q => wait_bypass_count_reg(10),
      R => clear
    );
\wait_bypass_count_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1_n_4\,
      Q => wait_bypass_count_reg(11),
      R => clear
    );
\wait_bypass_count_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[12]_i_1_n_7\,
      Q => wait_bypass_count_reg(12),
      R => clear
    );
\wait_bypass_count_reg[12]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[8]_i_1_n_0\,
      CO(3) => \wait_bypass_count_reg[12]_i_1_n_0\,
      CO(2) => \wait_bypass_count_reg[12]_i_1_n_1\,
      CO(1) => \wait_bypass_count_reg[12]_i_1_n_2\,
      CO(0) => \wait_bypass_count_reg[12]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \wait_bypass_count_reg[12]_i_1_n_4\,
      O(2) => \wait_bypass_count_reg[12]_i_1_n_5\,
      O(1) => \wait_bypass_count_reg[12]_i_1_n_6\,
      O(0) => \wait_bypass_count_reg[12]_i_1_n_7\,
      S(3) => \wait_bypass_count[12]_i_2_n_0\,
      S(2) => \wait_bypass_count[12]_i_3_n_0\,
      S(1) => \wait_bypass_count[12]_i_4_n_0\,
      S(0) => \wait_bypass_count[12]_i_5_n_0\
    );
\wait_bypass_count_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[12]_i_1_n_6\,
      Q => wait_bypass_count_reg(13),
      R => clear
    );
\wait_bypass_count_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[12]_i_1_n_5\,
      Q => wait_bypass_count_reg(14),
      R => clear
    );
\wait_bypass_count_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[12]_i_1_n_4\,
      Q => wait_bypass_count_reg(15),
      R => clear
    );
\wait_bypass_count_reg[16]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[16]_i_1_n_7\,
      Q => wait_bypass_count_reg(16),
      R => clear
    );
\wait_bypass_count_reg[16]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[12]_i_1_n_0\,
      CO(3 downto 0) => \NLW_wait_bypass_count_reg[16]_i_1_CO_UNCONNECTED\(3 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 1) => \NLW_wait_bypass_count_reg[16]_i_1_O_UNCONNECTED\(3 downto 1),
      O(0) => \wait_bypass_count_reg[16]_i_1_n_7\,
      S(3 downto 1) => B"000",
      S(0) => \wait_bypass_count[16]_i_2_n_0\
    );
\wait_bypass_count_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3_n_6\,
      Q => wait_bypass_count_reg(1),
      R => clear
    );
\wait_bypass_count_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3_n_5\,
      Q => wait_bypass_count_reg(2),
      R => clear
    );
\wait_bypass_count_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[0]_i_3_n_4\,
      Q => wait_bypass_count_reg(3),
      R => clear
    );
\wait_bypass_count_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1_n_7\,
      Q => wait_bypass_count_reg(4),
      R => clear
    );
\wait_bypass_count_reg[4]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[0]_i_3_n_0\,
      CO(3) => \wait_bypass_count_reg[4]_i_1_n_0\,
      CO(2) => \wait_bypass_count_reg[4]_i_1_n_1\,
      CO(1) => \wait_bypass_count_reg[4]_i_1_n_2\,
      CO(0) => \wait_bypass_count_reg[4]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \wait_bypass_count_reg[4]_i_1_n_4\,
      O(2) => \wait_bypass_count_reg[4]_i_1_n_5\,
      O(1) => \wait_bypass_count_reg[4]_i_1_n_6\,
      O(0) => \wait_bypass_count_reg[4]_i_1_n_7\,
      S(3) => \wait_bypass_count[4]_i_2_n_0\,
      S(2) => \wait_bypass_count[4]_i_3_n_0\,
      S(1) => \wait_bypass_count[4]_i_4_n_0\,
      S(0) => \wait_bypass_count[4]_i_5_n_0\
    );
\wait_bypass_count_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1_n_6\,
      Q => wait_bypass_count_reg(5),
      R => clear
    );
\wait_bypass_count_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1_n_5\,
      Q => wait_bypass_count_reg(6),
      R => clear
    );
\wait_bypass_count_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[4]_i_1_n_4\,
      Q => wait_bypass_count_reg(7),
      R => clear
    );
\wait_bypass_count_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1_n_7\,
      Q => wait_bypass_count_reg(8),
      R => clear
    );
\wait_bypass_count_reg[8]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \wait_bypass_count_reg[4]_i_1_n_0\,
      CO(3) => \wait_bypass_count_reg[8]_i_1_n_0\,
      CO(2) => \wait_bypass_count_reg[8]_i_1_n_1\,
      CO(1) => \wait_bypass_count_reg[8]_i_1_n_2\,
      CO(0) => \wait_bypass_count_reg[8]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \wait_bypass_count_reg[8]_i_1_n_4\,
      O(2) => \wait_bypass_count_reg[8]_i_1_n_5\,
      O(1) => \wait_bypass_count_reg[8]_i_1_n_6\,
      O(0) => \wait_bypass_count_reg[8]_i_1_n_7\,
      S(3) => \wait_bypass_count[8]_i_2_n_0\,
      S(2) => \wait_bypass_count[8]_i_3_n_0\,
      S(1) => \wait_bypass_count[8]_i_4_n_0\,
      S(0) => \wait_bypass_count[8]_i_5_n_0\
    );
\wait_bypass_count_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => wait_bypass_count,
      D => \wait_bypass_count_reg[8]_i_1_n_6\,
      Q => wait_bypass_count_reg(9),
      R => clear
    );
\wait_time_cnt[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(0),
      O => wait_time_cnt0(0)
    );
\wait_time_cnt[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      O => wait_time_cnt0(1)
    );
\wait_time_cnt[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"A9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(2),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(1),
      O => wait_time_cnt0(2)
    );
\wait_time_cnt[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FE01"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      O => wait_time_cnt0(3)
    );
\wait_time_cnt[4]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFE0001"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      I4 => \wait_time_cnt_reg__0\(4),
      O => wait_time_cnt0(4)
    );
\wait_time_cnt[5]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFE00000001"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(1),
      I1 => \wait_time_cnt_reg__0\(0),
      I2 => \wait_time_cnt_reg__0\(2),
      I3 => \wait_time_cnt_reg__0\(3),
      I4 => \wait_time_cnt_reg__0\(4),
      I5 => \wait_time_cnt_reg__0\(5),
      O => wait_time_cnt0(5)
    );
\wait_time_cnt[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"1500"
    )
        port map (
      I0 => tx_state(3),
      I1 => tx_state(1),
      I2 => tx_state(2),
      I3 => tx_state(0),
      O => wait_time_cnt0_0
    );
\wait_time_cnt[6]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \wait_time_cnt[6]_i_4_n_0\,
      I1 => \wait_time_cnt_reg__0\(6),
      O => \wait_time_cnt[6]_i_2_n_0\
    );
\wait_time_cnt[6]_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"9"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(6),
      I1 => \wait_time_cnt[6]_i_4_n_0\,
      O => wait_time_cnt0(6)
    );
\wait_time_cnt[6]_i_4\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFFFFFE"
    )
        port map (
      I0 => \wait_time_cnt_reg__0\(5),
      I1 => \wait_time_cnt_reg__0\(4),
      I2 => \wait_time_cnt_reg__0\(3),
      I3 => \wait_time_cnt_reg__0\(2),
      I4 => \wait_time_cnt_reg__0\(0),
      I5 => \wait_time_cnt_reg__0\(1),
      O => \wait_time_cnt[6]_i_4_n_0\
    );
\wait_time_cnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(0),
      Q => \wait_time_cnt_reg__0\(0),
      R => wait_time_cnt0_0
    );
\wait_time_cnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(1),
      Q => \wait_time_cnt_reg__0\(1),
      R => wait_time_cnt0_0
    );
\wait_time_cnt_reg[2]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(2),
      Q => \wait_time_cnt_reg__0\(2),
      S => wait_time_cnt0_0
    );
\wait_time_cnt_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(3),
      Q => \wait_time_cnt_reg__0\(3),
      R => wait_time_cnt0_0
    );
\wait_time_cnt_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(4),
      Q => \wait_time_cnt_reg__0\(4),
      R => wait_time_cnt0_0
    );
\wait_time_cnt_reg[5]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(5),
      Q => \wait_time_cnt_reg__0\(5),
      S => wait_time_cnt0_0
    );
\wait_time_cnt_reg[6]\: unisim.vcomponents.FDSE
     port map (
      C => independent_clock_bufg,
      CE => \wait_time_cnt[6]_i_2_n_0\,
      D => wait_time_cnt0(6),
      Q => \wait_time_cnt_reg__0\(6),
      S => wait_time_cnt0_0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq is
  port (
    GTRXRESET : out STD_LOGIC;
    DRP_OP_DONE : out STD_LOGIC;
    DRPDI : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drp_busy_i1_reg : out STD_LOGIC;
    DRPEN : out STD_LOGIC;
    DRPWE : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    \state_reg[0]_0\ : in STD_LOGIC;
    \state_reg[3]\ : in STD_LOGIC;
    \state_reg[2]_0\ : in STD_LOGIC;
    Q : in STD_LOGIC_VECTOR ( 14 downto 0 );
    D : in STD_LOGIC_VECTOR ( 15 downto 0 );
    SR : in STD_LOGIC_VECTOR ( 0 to 0 );
    data_in : in STD_LOGIC;
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq : entity is "GigEthGth7Core_gtwizard_gtrxreset_seq";
end GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq is
  signal \^drp_op_done\ : STD_LOGIC;
  signal data_out : STD_LOGIC;
  signal drp_op_done_o_i_1_n_0 : STD_LOGIC;
  signal flag : STD_LOGIC;
  signal flag_i_1_n_0 : STD_LOGIC;
  signal gthe2_i_i_24_n_0 : STD_LOGIC;
  signal gtrxreset_i : STD_LOGIC;
  signal gtrxreset_s : STD_LOGIC;
  signal gtrxreset_ss : STD_LOGIC;
  signal next_state : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal original_rd_data : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal original_rd_data0 : STD_LOGIC;
  signal rd_data : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \rd_data[0]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[10]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[11]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[12]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[13]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[14]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[15]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[15]_i_2__0_n_0\ : STD_LOGIC;
  signal \rd_data[1]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[2]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[3]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[4]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[5]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[6]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[7]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[8]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[9]_i_1__0_n_0\ : STD_LOGIC;
  signal reset_out : STD_LOGIC;
  signal rxpmaresetdone_s : STD_LOGIC;
  signal rxpmaresetdone_ss : STD_LOGIC;
  signal rxpmaresetdone_sss : STD_LOGIC;
  signal \state[0]_i_2_n_0\ : STD_LOGIC;
  signal \state_reg_n_0_[0]\ : STD_LOGIC;
  signal \state_reg_n_0_[1]\ : STD_LOGIC;
  signal \state_reg_n_0_[2]\ : STD_LOGIC;
  signal sync_rst_sync_n_0 : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of drp_busy_i1_i_1 : label is "soft_lutpair59";
  attribute SOFT_HLUTNM of drp_op_done_o_i_1 : label is "soft_lutpair58";
  attribute SOFT_HLUTNM of gthe2_i_i_24 : label is "soft_lutpair58";
  attribute SOFT_HLUTNM of gthe2_i_i_3 : label is "soft_lutpair59";
  attribute SOFT_HLUTNM of gtrxreset_o_i_1 : label is "soft_lutpair60";
  attribute SOFT_HLUTNM of \state[2]_i_1\ : label is "soft_lutpair60";
begin
  DRP_OP_DONE <= \^drp_op_done\;
drp_busy_i1_i_1: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \^drp_op_done\,
      O => drp_busy_i1_reg
    );
drp_op_done_o_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFF8000"
    )
        port map (
      I0 => \state_reg_n_0_[1]\,
      I1 => \state_reg_n_0_[0]\,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => \state_reg_n_0_[2]\,
      I4 => \^drp_op_done\,
      O => drp_op_done_o_i_1_n_0
    );
drp_op_done_o_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => gtrxreset_ss,
      D => drp_op_done_o_i_1_n_0,
      Q => \^drp_op_done\
    );
flag_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"3FEA"
    )
        port map (
      I0 => flag,
      I1 => \state_reg_n_0_[1]\,
      I2 => \state_reg_n_0_[0]\,
      I3 => \state_reg_n_0_[2]\,
      O => flag_i_1_n_0
    );
flag_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => flag_i_1_n_0,
      Q => flag,
      R => '0'
    );
gthe2_i_i_10: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(10),
      I2 => \state_reg[2]_0\,
      I3 => Q(10),
      O => DRPDI(10)
    );
gthe2_i_i_11: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(9),
      I2 => \state_reg[2]_0\,
      I3 => Q(9),
      O => DRPDI(9)
    );
gthe2_i_i_12: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(8),
      I2 => \state_reg[2]_0\,
      I3 => Q(8),
      O => DRPDI(8)
    );
gthe2_i_i_13: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(7),
      I2 => \state_reg[2]_0\,
      I3 => Q(7),
      O => DRPDI(7)
    );
gthe2_i_i_14: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(6),
      I2 => \state_reg[2]_0\,
      I3 => Q(6),
      O => DRPDI(6)
    );
gthe2_i_i_15: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(5),
      I2 => \state_reg[2]_0\,
      I3 => Q(5),
      O => DRPDI(5)
    );
gthe2_i_i_16: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(4),
      I2 => \state_reg[2]_0\,
      I3 => Q(4),
      O => DRPDI(4)
    );
gthe2_i_i_17: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(3),
      I2 => \state_reg[2]_0\,
      I3 => Q(3),
      O => DRPDI(3)
    );
gthe2_i_i_18: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(2),
      I2 => \state_reg[2]_0\,
      I3 => Q(2),
      O => DRPDI(2)
    );
gthe2_i_i_19: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(1),
      I2 => \state_reg[2]_0\,
      I3 => Q(1),
      O => DRPDI(1)
    );
gthe2_i_i_2: unisim.vcomponents.LUT5
    generic map(
      INIT => X"AABBBAAA"
    )
        port map (
      I0 => \state_reg[3]\,
      I1 => \^drp_op_done\,
      I2 => \state_reg_n_0_[1]\,
      I3 => \state_reg_n_0_[2]\,
      I4 => \state_reg_n_0_[0]\,
      O => DRPEN
    );
gthe2_i_i_20: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(0),
      I2 => \state_reg[2]_0\,
      I3 => Q(0),
      O => DRPDI(0)
    );
gthe2_i_i_24: unisim.vcomponents.LUT4
    generic map(
      INIT => X"EBFF"
    )
        port map (
      I0 => \^drp_op_done\,
      I1 => \state_reg_n_0_[2]\,
      I2 => \state_reg_n_0_[0]\,
      I3 => \state_reg_n_0_[1]\,
      O => gthe2_i_i_24_n_0
    );
gthe2_i_i_3: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0028FFFF"
    )
        port map (
      I0 => \state_reg_n_0_[1]\,
      I1 => \state_reg_n_0_[0]\,
      I2 => \state_reg_n_0_[2]\,
      I3 => \^drp_op_done\,
      I4 => \state_reg[2]_0\,
      O => DRPWE
    );
gthe2_i_i_5: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(15),
      I2 => \state_reg[2]_0\,
      I3 => Q(14),
      O => DRPDI(15)
    );
gthe2_i_i_6: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(14),
      I2 => \state_reg[2]_0\,
      I3 => Q(13),
      O => DRPDI(14)
    );
gthe2_i_i_7: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(13),
      I2 => \state_reg[2]_0\,
      I3 => Q(12),
      O => DRPDI(13)
    );
gthe2_i_i_8: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4F44"
    )
        port map (
      I0 => gthe2_i_i_24_n_0,
      I1 => rd_data(12),
      I2 => \state_reg[2]_0\,
      I3 => Q(11),
      O => DRPDI(12)
    );
gthe2_i_i_9: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AAAAAAAABAAAAAAA"
    )
        port map (
      I0 => \state_reg[0]_0\,
      I1 => \^drp_op_done\,
      I2 => rd_data(11),
      I3 => \state_reg_n_0_[1]\,
      I4 => \state_reg_n_0_[2]\,
      I5 => \state_reg_n_0_[0]\,
      O => DRPDI(11)
    );
gtrxreset_o_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"2F3C"
    )
        port map (
      I0 => gtrxreset_ss,
      I1 => \state_reg_n_0_[1]\,
      I2 => \state_reg_n_0_[2]\,
      I3 => \state_reg_n_0_[0]\,
      O => gtrxreset_i
    );
gtrxreset_o_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => gtrxreset_i,
      Q => GTRXRESET
    );
gtrxreset_s_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => reset_out,
      Q => gtrxreset_s
    );
gtrxreset_ss_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => gtrxreset_s,
      Q => gtrxreset_ss
    );
\original_rd_data[15]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00000020"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => \state_reg_n_0_[0]\,
      I2 => \state_reg_n_0_[1]\,
      I3 => \state_reg_n_0_[2]\,
      I4 => flag,
      O => original_rd_data0
    );
\original_rd_data_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(0),
      Q => original_rd_data(0),
      R => '0'
    );
\original_rd_data_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(10),
      Q => original_rd_data(10),
      R => '0'
    );
\original_rd_data_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(11),
      Q => original_rd_data(11),
      R => '0'
    );
\original_rd_data_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(12),
      Q => original_rd_data(12),
      R => '0'
    );
\original_rd_data_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(13),
      Q => original_rd_data(13),
      R => '0'
    );
\original_rd_data_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(14),
      Q => original_rd_data(14),
      R => '0'
    );
\original_rd_data_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(15),
      Q => original_rd_data(15),
      R => '0'
    );
\original_rd_data_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(1),
      Q => original_rd_data(1),
      R => '0'
    );
\original_rd_data_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(2),
      Q => original_rd_data(2),
      R => '0'
    );
\original_rd_data_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(3),
      Q => original_rd_data(3),
      R => '0'
    );
\original_rd_data_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(4),
      Q => original_rd_data(4),
      R => '0'
    );
\original_rd_data_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(5),
      Q => original_rd_data(5),
      R => '0'
    );
\original_rd_data_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(6),
      Q => original_rd_data(6),
      R => '0'
    );
\original_rd_data_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(7),
      Q => original_rd_data(7),
      R => '0'
    );
\original_rd_data_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(8),
      Q => original_rd_data(8),
      R => '0'
    );
\original_rd_data_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(9),
      Q => original_rd_data(9),
      R => '0'
    );
\rd_data[0]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(0),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(0),
      O => \rd_data[0]_i_1__0_n_0\
    );
\rd_data[10]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(10),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(10),
      O => \rd_data[10]_i_1__0_n_0\
    );
\rd_data[11]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(11),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(11),
      O => \rd_data[11]_i_1__0_n_0\
    );
\rd_data[12]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(12),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(12),
      O => \rd_data[12]_i_1__0_n_0\
    );
\rd_data[13]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(13),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(13),
      O => \rd_data[13]_i_1__0_n_0\
    );
\rd_data[14]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(14),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(14),
      O => \rd_data[14]_i_1__0_n_0\
    );
\rd_data[15]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0400"
    )
        port map (
      I0 => \state_reg_n_0_[2]\,
      I1 => \state_reg_n_0_[1]\,
      I2 => \state_reg_n_0_[0]\,
      I3 => \cpllpd_wait_reg[95]\,
      O => \rd_data[15]_i_1_n_0\
    );
\rd_data[15]_i_2__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(15),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(15),
      O => \rd_data[15]_i_2__0_n_0\
    );
\rd_data[1]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(1),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(1),
      O => \rd_data[1]_i_1__0_n_0\
    );
\rd_data[2]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(2),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(2),
      O => \rd_data[2]_i_1__0_n_0\
    );
\rd_data[3]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(3),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(3),
      O => \rd_data[3]_i_1__0_n_0\
    );
\rd_data[4]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(4),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(4),
      O => \rd_data[4]_i_1__0_n_0\
    );
\rd_data[5]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(5),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(5),
      O => \rd_data[5]_i_1__0_n_0\
    );
\rd_data[6]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(6),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(6),
      O => \rd_data[6]_i_1__0_n_0\
    );
\rd_data[7]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(7),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(7),
      O => \rd_data[7]_i_1__0_n_0\
    );
\rd_data[8]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(8),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(8),
      O => \rd_data[8]_i_1__0_n_0\
    );
\rd_data[9]_i_1__0\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FB08"
    )
        port map (
      I0 => D(9),
      I1 => \cpllpd_wait_reg[95]\,
      I2 => flag,
      I3 => original_rd_data(9),
      O => \rd_data[9]_i_1__0_n_0\
    );
\rd_data_reg[0]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[0]_i_1__0_n_0\,
      Q => rd_data(0)
    );
\rd_data_reg[10]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[10]_i_1__0_n_0\,
      Q => rd_data(10)
    );
\rd_data_reg[11]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[11]_i_1__0_n_0\,
      Q => rd_data(11)
    );
\rd_data_reg[12]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[12]_i_1__0_n_0\,
      Q => rd_data(12)
    );
\rd_data_reg[13]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[13]_i_1__0_n_0\,
      Q => rd_data(13)
    );
\rd_data_reg[14]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[14]_i_1__0_n_0\,
      Q => rd_data(14)
    );
\rd_data_reg[15]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[15]_i_2__0_n_0\,
      Q => rd_data(15)
    );
\rd_data_reg[1]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[1]_i_1__0_n_0\,
      Q => rd_data(1)
    );
\rd_data_reg[2]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[2]_i_1__0_n_0\,
      Q => rd_data(2)
    );
\rd_data_reg[3]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[3]_i_1__0_n_0\,
      Q => rd_data(3)
    );
\rd_data_reg[4]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[4]_i_1__0_n_0\,
      Q => rd_data(4)
    );
\rd_data_reg[5]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[5]_i_1__0_n_0\,
      Q => rd_data(5)
    );
\rd_data_reg[6]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[6]_i_1__0_n_0\,
      Q => rd_data(6)
    );
\rd_data_reg[7]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[7]_i_1__0_n_0\,
      Q => rd_data(7)
    );
\rd_data_reg[8]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[8]_i_1__0_n_0\,
      Q => rd_data(8)
    );
\rd_data_reg[9]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[9]_i_1__0_n_0\,
      Q => rd_data(9)
    );
rxpmaresetdone_s_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => data_out,
      Q => rxpmaresetdone_s
    );
rxpmaresetdone_ss_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => rxpmaresetdone_s,
      Q => rxpmaresetdone_ss
    );
rxpmaresetdone_sss_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => rxpmaresetdone_ss,
      Q => rxpmaresetdone_sss
    );
\state[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0C880C88FCF3FCC0"
    )
        port map (
      I0 => \state[0]_i_2_n_0\,
      I1 => \state_reg_n_0_[2]\,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => \state_reg_n_0_[1]\,
      I4 => gtrxreset_ss,
      I5 => \state_reg_n_0_[0]\,
      O => next_state(0)
    );
\state[0]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"B"
    )
        port map (
      I0 => rxpmaresetdone_ss,
      I1 => rxpmaresetdone_sss,
      O => \state[0]_i_2_n_0\
    );
\state[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"550030FFFFFF0000"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => rxpmaresetdone_ss,
      I2 => rxpmaresetdone_sss,
      I3 => \state_reg_n_0_[2]\,
      I4 => \state_reg_n_0_[1]\,
      I5 => \state_reg_n_0_[0]\,
      O => next_state(1)
    );
\state[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"7CCC"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => \state_reg_n_0_[2]\,
      I2 => \state_reg_n_0_[1]\,
      I3 => \state_reg_n_0_[0]\,
      O => next_state(2)
    );
\state_reg[0]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(0),
      Q => \state_reg_n_0_[0]\
    );
\state_reg[1]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(1),
      Q => \state_reg_n_0_[1]\
    );
\state_reg[2]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(2),
      Q => \state_reg_n_0_[2]\
    );
sync_gtrxreset_in: entity work.GigEthGth7Core_GigEthGth7Core_reset_sync_5
     port map (
      SR(0) => SR(0),
      gtrefclk_bufg => gtrefclk_bufg,
      reset_out => reset_out
    );
sync_rst_sync: entity work.GigEthGth7Core_GigEthGth7Core_reset_sync_6
     port map (
      CPLL_RESET => CPLL_RESET,
      gtrefclk_bufg => gtrefclk_bufg,
      reset_out => sync_rst_sync_n_0
    );
sync_rxpmaresetdone: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_7
     port map (
      data_in => data_in,
      data_out => data_out,
      gtrefclk_bufg => gtrefclk_bufg
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq is
  port (
    RXPMARESET : out STD_LOGIC;
    DRPADDR : out STD_LOGIC_VECTOR ( 0 to 0 );
    data_sync_reg1 : out STD_LOGIC;
    data_sync_reg1_0 : out STD_LOGIC;
    data_sync_reg1_1 : out STD_LOGIC;
    Q : out STD_LOGIC_VECTOR ( 14 downto 0 );
    gtrefclk_bufg : in STD_LOGIC;
    drp_busy_i1 : in STD_LOGIC;
    DRP_OP_DONE : in STD_LOGIC;
    \cpllpd_wait_reg[95]\ : in STD_LOGIC;
    D : in STD_LOGIC_VECTOR ( 15 downto 0 );
    data_in : in STD_LOGIC;
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq : entity is "GigEthGth7Core_gtwizard_rxpmarst_seq";
end GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq is
  signal flag : STD_LOGIC;
  signal \flag_i_1__0_n_0\ : STD_LOGIC;
  signal next_state : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal original_rd_data0 : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[0]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[10]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[11]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[12]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[13]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[14]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[15]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[1]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[2]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[3]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[4]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[5]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[6]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[7]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[8]\ : STD_LOGIC;
  signal \original_rd_data_reg_n_0_[9]\ : STD_LOGIC;
  signal \rd_data[0]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[10]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[11]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[12]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[13]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[14]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[15]_i_1__0_n_0\ : STD_LOGIC;
  signal \rd_data[15]_i_2_n_0\ : STD_LOGIC;
  signal \rd_data[1]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[2]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[3]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[4]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[5]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[6]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[7]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[8]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data[9]_i_1_n_0\ : STD_LOGIC;
  signal \rd_data_reg_n_0_[11]\ : STD_LOGIC;
  signal rxpmareset_i : STD_LOGIC;
  signal state : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal sync_rst_sync_n_0 : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of gthe2_i_i_23 : label is "soft_lutpair62";
  attribute SOFT_HLUTNM of rxpmareset_o_i_1 : label is "soft_lutpair62";
  attribute SOFT_HLUTNM of \state[2]_i_1__0\ : label is "soft_lutpair61";
  attribute SOFT_HLUTNM of \state[3]_i_1\ : label is "soft_lutpair61";
begin
\flag_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"8BBABABA"
    )
        port map (
      I0 => flag,
      I1 => state(3),
      I2 => state(2),
      I3 => state(0),
      I4 => state(1),
      O => \flag_i_1__0_n_0\
    );
flag_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => \flag_i_1__0_n_0\,
      Q => flag,
      R => '0'
    );
gthe2_i_i_21: unisim.vcomponents.LUT6
    generic map(
      INIT => X"55554544FFFFFFFF"
    )
        port map (
      I0 => state(3),
      I1 => state(2),
      I2 => drp_busy_i1,
      I3 => state(0),
      I4 => state(1),
      I5 => DRP_OP_DONE,
      O => DRPADDR(0)
    );
gthe2_i_i_22: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0045440000000000"
    )
        port map (
      I0 => state(3),
      I1 => state(1),
      I2 => drp_busy_i1,
      I3 => state(2),
      I4 => state(0),
      I5 => DRP_OP_DONE,
      O => data_sync_reg1_0
    );
gthe2_i_i_23: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FF9FFFFF"
    )
        port map (
      I0 => state(2),
      I1 => state(0),
      I2 => DRP_OP_DONE,
      I3 => state(3),
      I4 => state(1),
      O => data_sync_reg1_1
    );
gthe2_i_i_25: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000400000000000"
    )
        port map (
      I0 => state(0),
      I1 => state(1),
      I2 => DRP_OP_DONE,
      I3 => \rd_data_reg_n_0_[11]\,
      I4 => state(3),
      I5 => state(2),
      O => data_sync_reg1
    );
\original_rd_data[15]_i_1__0\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000000020"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => state(0),
      I2 => state(1),
      I3 => state(2),
      I4 => state(3),
      I5 => flag,
      O => original_rd_data0
    );
\original_rd_data_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(0),
      Q => \original_rd_data_reg_n_0_[0]\,
      R => '0'
    );
\original_rd_data_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(10),
      Q => \original_rd_data_reg_n_0_[10]\,
      R => '0'
    );
\original_rd_data_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(11),
      Q => \original_rd_data_reg_n_0_[11]\,
      R => '0'
    );
\original_rd_data_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(12),
      Q => \original_rd_data_reg_n_0_[12]\,
      R => '0'
    );
\original_rd_data_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(13),
      Q => \original_rd_data_reg_n_0_[13]\,
      R => '0'
    );
\original_rd_data_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(14),
      Q => \original_rd_data_reg_n_0_[14]\,
      R => '0'
    );
\original_rd_data_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(15),
      Q => \original_rd_data_reg_n_0_[15]\,
      R => '0'
    );
\original_rd_data_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(1),
      Q => \original_rd_data_reg_n_0_[1]\,
      R => '0'
    );
\original_rd_data_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(2),
      Q => \original_rd_data_reg_n_0_[2]\,
      R => '0'
    );
\original_rd_data_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(3),
      Q => \original_rd_data_reg_n_0_[3]\,
      R => '0'
    );
\original_rd_data_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(4),
      Q => \original_rd_data_reg_n_0_[4]\,
      R => '0'
    );
\original_rd_data_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(5),
      Q => \original_rd_data_reg_n_0_[5]\,
      R => '0'
    );
\original_rd_data_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(6),
      Q => \original_rd_data_reg_n_0_[6]\,
      R => '0'
    );
\original_rd_data_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(7),
      Q => \original_rd_data_reg_n_0_[7]\,
      R => '0'
    );
\original_rd_data_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(8),
      Q => \original_rd_data_reg_n_0_[8]\,
      R => '0'
    );
\original_rd_data_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => gtrefclk_bufg,
      CE => original_rd_data0,
      D => D(9),
      Q => \original_rd_data_reg_n_0_[9]\,
      R => '0'
    );
\rd_data[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[0]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(0),
      O => \rd_data[0]_i_1_n_0\
    );
\rd_data[10]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[10]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(10),
      O => \rd_data[10]_i_1_n_0\
    );
\rd_data[11]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[11]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(11),
      O => \rd_data[11]_i_1_n_0\
    );
\rd_data[12]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[12]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(12),
      O => \rd_data[12]_i_1_n_0\
    );
\rd_data[13]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[13]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(13),
      O => \rd_data[13]_i_1_n_0\
    );
\rd_data[14]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[14]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(14),
      O => \rd_data[14]_i_1_n_0\
    );
\rd_data[15]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00100000"
    )
        port map (
      I0 => state(3),
      I1 => state(2),
      I2 => state(1),
      I3 => state(0),
      I4 => \cpllpd_wait_reg[95]\,
      O => \rd_data[15]_i_1__0_n_0\
    );
\rd_data[15]_i_2\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[15]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(15),
      O => \rd_data[15]_i_2_n_0\
    );
\rd_data[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[1]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(1),
      O => \rd_data[1]_i_1_n_0\
    );
\rd_data[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[2]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(2),
      O => \rd_data[2]_i_1_n_0\
    );
\rd_data[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[3]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(3),
      O => \rd_data[3]_i_1_n_0\
    );
\rd_data[4]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[4]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(4),
      O => \rd_data[4]_i_1_n_0\
    );
\rd_data[5]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[5]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(5),
      O => \rd_data[5]_i_1_n_0\
    );
\rd_data[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[6]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(6),
      O => \rd_data[6]_i_1_n_0\
    );
\rd_data[7]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[7]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(7),
      O => \rd_data[7]_i_1_n_0\
    );
\rd_data[8]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[8]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(8),
      O => \rd_data[8]_i_1_n_0\
    );
\rd_data[9]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BA8A"
    )
        port map (
      I0 => \original_rd_data_reg_n_0_[9]\,
      I1 => flag,
      I2 => \cpllpd_wait_reg[95]\,
      I3 => D(9),
      O => \rd_data[9]_i_1_n_0\
    );
\rd_data_reg[0]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[0]_i_1_n_0\,
      Q => Q(0)
    );
\rd_data_reg[10]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[10]_i_1_n_0\,
      Q => Q(10)
    );
\rd_data_reg[11]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[11]_i_1_n_0\,
      Q => \rd_data_reg_n_0_[11]\
    );
\rd_data_reg[12]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[12]_i_1_n_0\,
      Q => Q(11)
    );
\rd_data_reg[13]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[13]_i_1_n_0\,
      Q => Q(12)
    );
\rd_data_reg[14]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[14]_i_1_n_0\,
      Q => Q(13)
    );
\rd_data_reg[15]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[15]_i_2_n_0\,
      Q => Q(14)
    );
\rd_data_reg[1]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[1]_i_1_n_0\,
      Q => Q(1)
    );
\rd_data_reg[2]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[2]_i_1_n_0\,
      Q => Q(2)
    );
\rd_data_reg[3]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[3]_i_1_n_0\,
      Q => Q(3)
    );
\rd_data_reg[4]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[4]_i_1_n_0\,
      Q => Q(4)
    );
\rd_data_reg[5]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[5]_i_1_n_0\,
      Q => Q(5)
    );
\rd_data_reg[6]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[6]_i_1_n_0\,
      Q => Q(6)
    );
\rd_data_reg[7]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[7]_i_1_n_0\,
      Q => Q(7)
    );
\rd_data_reg[8]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[8]_i_1_n_0\,
      Q => Q(8)
    );
\rd_data_reg[9]\: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => \rd_data[15]_i_1__0_n_0\,
      CLR => sync_rst_sync_n_0,
      D => \rd_data[9]_i_1_n_0\,
      Q => Q(9)
    );
rxpmareset_o_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => state(0),
      I1 => state(2),
      I2 => state(3),
      O => rxpmareset_i
    );
rxpmareset_o_reg: unisim.vcomponents.FDCE
     port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => rxpmareset_i,
      Q => RXPMARESET
    );
\state[2]_i_1__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"07080F08"
    )
        port map (
      I0 => state(0),
      I1 => state(1),
      I2 => state(3),
      I3 => state(2),
      I4 => \cpllpd_wait_reg[95]\,
      O => next_state(2)
    );
\state[3]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"00800000"
    )
        port map (
      I0 => \cpllpd_wait_reg[95]\,
      I1 => state(0),
      I2 => state(1),
      I3 => state(3),
      I4 => state(2),
      O => next_state(3)
    );
\state_reg[0]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(0),
      Q => state(0)
    );
\state_reg[1]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(1),
      Q => state(1)
    );
\state_reg[2]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(2),
      Q => state(2)
    );
\state_reg[3]\: unisim.vcomponents.FDCE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      CLR => sync_rst_sync_n_0,
      D => next_state(3),
      Q => state(3)
    );
sync_RXPMARESETDONE: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_4
     port map (
      D(1 downto 0) => next_state(1 downto 0),
      Q(3 downto 0) => state(3 downto 0),
      \cpllpd_wait_reg[95]\ => \cpllpd_wait_reg[95]\,
      data_in => data_in,
      gtrefclk_bufg => gtrefclk_bufg
    );
sync_rst_sync: entity work.\GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7\
     port map (
      CPLL_RESET => CPLL_RESET,
      gtrefclk_bufg => gtrefclk_bufg,
      reset_out => sync_rst_sync_n_0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT is
  port (
    cplllock : out STD_LOGIC;
    CPLLREFCLKLOST : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    data_sync_reg1 : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    data_sync_reg1_0 : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    TXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    RXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    \rxdata_reg_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \rxchariscomma_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxcharisk_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxdisperr_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxnotintable_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    independent_clock_bufg : in STD_LOGIC;
    cpll_pd_out : in STD_LOGIC;
    cpllreset_in : in STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_gttxreset_in0_out : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    reset_out : in STD_LOGIC;
    reset : in STD_LOGIC;
    RXUSERRDY : in STD_LOGIC;
    userclk : in STD_LOGIC;
    TXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    TXUSERRDY : in STD_LOGIC;
    RXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    Q : in STD_LOGIC_VECTOR ( 15 downto 0 );
    \txchardispmode_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txchardispval_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txcharisk_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    SR : in STD_LOGIC_VECTOR ( 0 to 0 );
    CPLL_RESET : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT : entity is "GigEthGth7Core_GTWIZARD_GT";
end GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT is
  signal DRPDI : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal DRPEN : STD_LOGIC;
  signal DRPWE : STD_LOGIC;
  signal DRP_OP_DONE : STD_LOGIC;
  signal GTRXRESET : STD_LOGIC;
  signal RXPMARESET : STD_LOGIC;
  signal drp_busy_i1 : STD_LOGIC;
  signal gthe2_i_n_0 : STD_LOGIC;
  signal gthe2_i_n_10 : STD_LOGIC;
  signal gthe2_i_n_11 : STD_LOGIC;
  signal gthe2_i_n_113 : STD_LOGIC;
  signal gthe2_i_n_115 : STD_LOGIC;
  signal gthe2_i_n_116 : STD_LOGIC;
  signal gthe2_i_n_17 : STD_LOGIC;
  signal gthe2_i_n_205 : STD_LOGIC;
  signal gthe2_i_n_206 : STD_LOGIC;
  signal gthe2_i_n_207 : STD_LOGIC;
  signal gthe2_i_n_208 : STD_LOGIC;
  signal gthe2_i_n_209 : STD_LOGIC;
  signal gthe2_i_n_210 : STD_LOGIC;
  signal gthe2_i_n_211 : STD_LOGIC;
  signal gthe2_i_n_3 : STD_LOGIC;
  signal gthe2_i_n_33 : STD_LOGIC;
  signal gthe2_i_n_34 : STD_LOGIC;
  signal gthe2_i_n_4 : STD_LOGIC;
  signal gthe2_i_n_46 : STD_LOGIC;
  signal gthe2_i_n_47 : STD_LOGIC;
  signal gthe2_i_n_50 : STD_LOGIC;
  signal gthe2_i_n_57 : STD_LOGIC;
  signal gthe2_i_n_58 : STD_LOGIC;
  signal gthe2_i_n_59 : STD_LOGIC;
  signal gthe2_i_n_60 : STD_LOGIC;
  signal gthe2_i_n_61 : STD_LOGIC;
  signal gthe2_i_n_62 : STD_LOGIC;
  signal gthe2_i_n_63 : STD_LOGIC;
  signal gthe2_i_n_64 : STD_LOGIC;
  signal gthe2_i_n_65 : STD_LOGIC;
  signal gthe2_i_n_66 : STD_LOGIC;
  signal gthe2_i_n_67 : STD_LOGIC;
  signal gthe2_i_n_68 : STD_LOGIC;
  signal gthe2_i_n_69 : STD_LOGIC;
  signal gthe2_i_n_70 : STD_LOGIC;
  signal gthe2_i_n_71 : STD_LOGIC;
  signal gthe2_i_n_72 : STD_LOGIC;
  signal gthe2_i_n_73 : STD_LOGIC;
  signal gthe2_i_n_74 : STD_LOGIC;
  signal gthe2_i_n_75 : STD_LOGIC;
  signal gthe2_i_n_76 : STD_LOGIC;
  signal gthe2_i_n_77 : STD_LOGIC;
  signal gthe2_i_n_78 : STD_LOGIC;
  signal gthe2_i_n_79 : STD_LOGIC;
  signal gthe2_i_n_80 : STD_LOGIC;
  signal gthe2_i_n_81 : STD_LOGIC;
  signal gthe2_i_n_82 : STD_LOGIC;
  signal gthe2_i_n_83 : STD_LOGIC;
  signal gthe2_i_n_84 : STD_LOGIC;
  signal gthe2_i_n_85 : STD_LOGIC;
  signal gthe2_i_n_86 : STD_LOGIC;
  signal gthe2_i_n_87 : STD_LOGIC;
  signal gtrxreset_seq_i_n_18 : STD_LOGIC;
  signal rxpmarst_seq_i_n_1 : STD_LOGIC;
  signal rxpmarst_seq_i_n_10 : STD_LOGIC;
  signal rxpmarst_seq_i_n_11 : STD_LOGIC;
  signal rxpmarst_seq_i_n_12 : STD_LOGIC;
  signal rxpmarst_seq_i_n_13 : STD_LOGIC;
  signal rxpmarst_seq_i_n_14 : STD_LOGIC;
  signal rxpmarst_seq_i_n_15 : STD_LOGIC;
  signal rxpmarst_seq_i_n_16 : STD_LOGIC;
  signal rxpmarst_seq_i_n_17 : STD_LOGIC;
  signal rxpmarst_seq_i_n_18 : STD_LOGIC;
  signal rxpmarst_seq_i_n_19 : STD_LOGIC;
  signal rxpmarst_seq_i_n_2 : STD_LOGIC;
  signal rxpmarst_seq_i_n_3 : STD_LOGIC;
  signal rxpmarst_seq_i_n_4 : STD_LOGIC;
  signal rxpmarst_seq_i_n_5 : STD_LOGIC;
  signal rxpmarst_seq_i_n_6 : STD_LOGIC;
  signal rxpmarst_seq_i_n_7 : STD_LOGIC;
  signal rxpmarst_seq_i_n_8 : STD_LOGIC;
  signal rxpmarst_seq_i_n_9 : STD_LOGIC;
  signal NLW_gthe2_i_GTREFCLKMONITOR_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_PHYSTATUS_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RSOSINTDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCDRLOCK_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCHANBONDSEQ_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCHANISALIGNED_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCHANREALIGN_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCOMINITDET_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCOMSASDET_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXCOMWAKEDET_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXDFESLIDETAPSTARTED_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXDFESLIDETAPSTROBEDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXDFESLIDETAPSTROBESTARTED_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXDFESTADAPTDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXDLYSRESETDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXELECIDLE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXOSINTSTARTED_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXOSINTSTROBEDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXOSINTSTROBESTARTED_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXOUTCLKFABRIC_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXOUTCLKPCS_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXPHALIGNDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXQPISENN_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXQPISENP_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXRATEDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXSYNCDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXSYNCOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_RXVALID_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXCOMFINISH_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXDLYSRESETDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXGEARBOXREADY_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXPHALIGNDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXPHINITDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXQPISENN_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXQPISENP_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXRATEDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXSYNCDONE_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_TXSYNCOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_gthe2_i_PCSRSVDOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal NLW_gthe2_i_RXCHARISCOMMA_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 2 );
  signal NLW_gthe2_i_RXCHARISK_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 2 );
  signal NLW_gthe2_i_RXCHBONDO_UNCONNECTED : STD_LOGIC_VECTOR ( 4 downto 0 );
  signal NLW_gthe2_i_RXDATA_UNCONNECTED : STD_LOGIC_VECTOR ( 63 downto 16 );
  signal NLW_gthe2_i_RXDATAVALID_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_gthe2_i_RXDISPERR_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 2 );
  signal NLW_gthe2_i_RXHEADER_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_gthe2_i_RXHEADERVALID_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_gthe2_i_RXNOTINTABLE_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 2 );
  signal NLW_gthe2_i_RXPHMONITOR_UNCONNECTED : STD_LOGIC_VECTOR ( 4 downto 0 );
  signal NLW_gthe2_i_RXPHSLIPMONITOR_UNCONNECTED : STD_LOGIC_VECTOR ( 4 downto 0 );
  signal NLW_gthe2_i_RXSTARTOFSEQ_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_gthe2_i_RXSTATUS_UNCONNECTED : STD_LOGIC_VECTOR ( 2 downto 0 );
  attribute box_type : string;
  attribute box_type of gthe2_i : label is "PRIMITIVE";
begin
drp_busy_i1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => gtrefclk_bufg,
      CE => '1',
      D => gtrxreset_seq_i_n_18,
      Q => drp_busy_i1,
      R => '0'
    );
gthe2_i: unisim.vcomponents.GTHE2_CHANNEL
    generic map(
      ACJTAG_DEBUG_MODE => '0',
      ACJTAG_MODE => '0',
      ACJTAG_RESET => '0',
      ADAPT_CFG0 => X"00C10",
      ALIGN_COMMA_DOUBLE => "FALSE",
      ALIGN_COMMA_ENABLE => B"0001111111",
      ALIGN_COMMA_WORD => 2,
      ALIGN_MCOMMA_DET => "TRUE",
      ALIGN_MCOMMA_VALUE => B"1010000011",
      ALIGN_PCOMMA_DET => "TRUE",
      ALIGN_PCOMMA_VALUE => B"0101111100",
      A_RXOSCALRESET => '0',
      CBCC_DATA_SOURCE_SEL => "DECODED",
      CFOK_CFG => X"24800040E80",
      CFOK_CFG2 => B"100000",
      CFOK_CFG3 => B"100000",
      CHAN_BOND_KEEP_ALIGN => "FALSE",
      CHAN_BOND_MAX_SKEW => 1,
      CHAN_BOND_SEQ_1_1 => B"0000000000",
      CHAN_BOND_SEQ_1_2 => B"0000000000",
      CHAN_BOND_SEQ_1_3 => B"0000000000",
      CHAN_BOND_SEQ_1_4 => B"0000000000",
      CHAN_BOND_SEQ_1_ENABLE => B"1111",
      CHAN_BOND_SEQ_2_1 => B"0000000000",
      CHAN_BOND_SEQ_2_2 => B"0000000000",
      CHAN_BOND_SEQ_2_3 => B"0000000000",
      CHAN_BOND_SEQ_2_4 => B"0000000000",
      CHAN_BOND_SEQ_2_ENABLE => B"1111",
      CHAN_BOND_SEQ_2_USE => "FALSE",
      CHAN_BOND_SEQ_LEN => 1,
      CLK_CORRECT_USE => "TRUE",
      CLK_COR_KEEP_IDLE => "FALSE",
      CLK_COR_MAX_LAT => 36,
      CLK_COR_MIN_LAT => 33,
      CLK_COR_PRECEDENCE => "TRUE",
      CLK_COR_REPEAT_WAIT => 0,
      CLK_COR_SEQ_1_1 => B"0110111100",
      CLK_COR_SEQ_1_2 => B"0001010000",
      CLK_COR_SEQ_1_3 => B"0000000000",
      CLK_COR_SEQ_1_4 => B"0000000000",
      CLK_COR_SEQ_1_ENABLE => B"1111",
      CLK_COR_SEQ_2_1 => B"0110111100",
      CLK_COR_SEQ_2_2 => B"0010110101",
      CLK_COR_SEQ_2_3 => B"0000000000",
      CLK_COR_SEQ_2_4 => B"0000000000",
      CLK_COR_SEQ_2_ENABLE => B"1111",
      CLK_COR_SEQ_2_USE => "TRUE",
      CLK_COR_SEQ_LEN => 2,
      CPLL_CFG => X"00BC07DC",
      CPLL_FBDIV => 4,
      CPLL_FBDIV_45 => 5,
      CPLL_INIT_CFG => X"00001E",
      CPLL_LOCK_CFG => X"01E8",
      CPLL_REFCLK_DIV => 1,
      DEC_MCOMMA_DETECT => "TRUE",
      DEC_PCOMMA_DETECT => "TRUE",
      DEC_VALID_COMMA_ONLY => "FALSE",
      DMONITOR_CFG => X"000A00",
      ES_CLK_PHASE_SEL => '0',
      ES_CONTROL => B"000000",
      ES_ERRDET_EN => "FALSE",
      ES_EYE_SCAN_EN => "TRUE",
      ES_HORZ_OFFSET => X"000",
      ES_PMA_CFG => B"0000000000",
      ES_PRESCALE => B"00000",
      ES_QUALIFIER => X"00000000000000000000",
      ES_QUAL_MASK => X"00000000000000000000",
      ES_SDATA_MASK => X"00000000000000000000",
      ES_VERT_OFFSET => B"000000000",
      FTS_DESKEW_SEQ_ENABLE => B"1111",
      FTS_LANE_DESKEW_CFG => B"1111",
      FTS_LANE_DESKEW_EN => "FALSE",
      GEARBOX_MODE => B"000",
      IS_CLKRSVD0_INVERTED => '0',
      IS_CLKRSVD1_INVERTED => '0',
      IS_CPLLLOCKDETCLK_INVERTED => '0',
      IS_DMONITORCLK_INVERTED => '0',
      IS_DRPCLK_INVERTED => '0',
      IS_GTGREFCLK_INVERTED => '0',
      IS_RXUSRCLK2_INVERTED => '0',
      IS_RXUSRCLK_INVERTED => '0',
      IS_SIGVALIDCLK_INVERTED => '0',
      IS_TXPHDLYTSTCLK_INVERTED => '0',
      IS_TXUSRCLK2_INVERTED => '0',
      IS_TXUSRCLK_INVERTED => '0',
      LOOPBACK_CFG => '0',
      OUTREFCLK_SEL_INV => B"11",
      PCS_PCIE_EN => "FALSE",
      PCS_RSVD_ATTR => X"000000000000",
      PD_TRANS_TIME_FROM_P2 => X"03C",
      PD_TRANS_TIME_NONE_P2 => X"19",
      PD_TRANS_TIME_TO_P2 => X"64",
      PMA_RSV => B"00000000000000000000000010000000",
      PMA_RSV2 => B"00011100000000000000000000001010",
      PMA_RSV3 => B"00",
      PMA_RSV4 => B"000000000001000",
      PMA_RSV5 => B"0000",
      RESET_POWERSAVE_DISABLE => '0',
      RXBUFRESET_TIME => B"00001",
      RXBUF_ADDR_MODE => "FULL",
      RXBUF_EIDLE_HI_CNT => B"1000",
      RXBUF_EIDLE_LO_CNT => B"0000",
      RXBUF_EN => "TRUE",
      RXBUF_RESET_ON_CB_CHANGE => "TRUE",
      RXBUF_RESET_ON_COMMAALIGN => "FALSE",
      RXBUF_RESET_ON_EIDLE => "FALSE",
      RXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      RXBUF_THRESH_OVFLW => 61,
      RXBUF_THRESH_OVRD => "FALSE",
      RXBUF_THRESH_UNDFLW => 8,
      RXCDRFREQRESET_TIME => B"00001",
      RXCDRPHRESET_TIME => B"00001",
      RXCDR_CFG => X"0002007FE0800C2080018",
      RXCDR_FR_RESET_ON_EIDLE => '0',
      RXCDR_HOLD_DURING_EIDLE => '0',
      RXCDR_LOCK_CFG => B"010101",
      RXCDR_PH_RESET_ON_EIDLE => '0',
      RXDFELPMRESET_TIME => B"0001111",
      RXDLY_CFG => X"001F",
      RXDLY_LCFG => X"030",
      RXDLY_TAP_CFG => X"0000",
      RXGEARBOX_EN => "FALSE",
      RXISCANRESET_TIME => B"00001",
      RXLPM_HF_CFG => B"00001000000000",
      RXLPM_LF_CFG => B"001001000000000000",
      RXOOB_CFG => B"0000110",
      RXOOB_CLK_CFG => "PMA",
      RXOSCALRESET_TIME => B"00011",
      RXOSCALRESET_TIMEOUT => B"00000",
      RXOUT_DIV => 4,
      RXPCSRESET_TIME => B"00001",
      RXPHDLY_CFG => X"084020",
      RXPH_CFG => X"C00002",
      RXPH_MONITOR_SEL => B"00000",
      RXPI_CFG0 => B"00",
      RXPI_CFG1 => B"00",
      RXPI_CFG2 => B"00",
      RXPI_CFG3 => B"11",
      RXPI_CFG4 => '1',
      RXPI_CFG5 => '1',
      RXPI_CFG6 => B"001",
      RXPMARESET_TIME => B"00011",
      RXPRBS_ERR_LOOPBACK => '0',
      RXSLIDE_AUTO_WAIT => 7,
      RXSLIDE_MODE => "OFF",
      RXSYNC_MULTILANE => '0',
      RXSYNC_OVRD => '0',
      RXSYNC_SKIP_DA => '0',
      RX_BIAS_CFG => B"000011000000000000010000",
      RX_BUFFER_CFG => B"000000",
      RX_CLK25_DIV => 5,
      RX_CLKMUX_PD => '1',
      RX_CM_SEL => B"11",
      RX_CM_TRIM => B"1010",
      RX_DATA_WIDTH => 20,
      RX_DDI_SEL => B"000000",
      RX_DEBUG_CFG => B"00000000000000",
      RX_DEFER_RESET_BUF_EN => "TRUE",
      RX_DFELPM_CFG0 => B"0110",
      RX_DFELPM_CFG1 => '0',
      RX_DFELPM_KLKH_AGC_STUP_EN => '1',
      RX_DFE_AGC_CFG0 => B"00",
      RX_DFE_AGC_CFG1 => B"010",
      RX_DFE_AGC_CFG2 => B"0000",
      RX_DFE_AGC_OVRDEN => '1',
      RX_DFE_GAIN_CFG => X"0020C0",
      RX_DFE_H2_CFG => B"000000000000",
      RX_DFE_H3_CFG => B"000001000000",
      RX_DFE_H4_CFG => B"00011100000",
      RX_DFE_H5_CFG => B"00011100000",
      RX_DFE_H6_CFG => B"00000100000",
      RX_DFE_H7_CFG => B"00000100000",
      RX_DFE_KL_CFG => B"001000001000000000000001100010000",
      RX_DFE_KL_LPM_KH_CFG0 => B"01",
      RX_DFE_KL_LPM_KH_CFG1 => B"010",
      RX_DFE_KL_LPM_KH_CFG2 => B"0010",
      RX_DFE_KL_LPM_KH_OVRDEN => '1',
      RX_DFE_KL_LPM_KL_CFG0 => B"01",
      RX_DFE_KL_LPM_KL_CFG1 => B"010",
      RX_DFE_KL_LPM_KL_CFG2 => B"0010",
      RX_DFE_KL_LPM_KL_OVRDEN => '1',
      RX_DFE_LPM_CFG => X"0080",
      RX_DFE_LPM_HOLD_DURING_EIDLE => '0',
      RX_DFE_ST_CFG => X"00E100000C003F",
      RX_DFE_UT_CFG => B"00011100000000000",
      RX_DFE_VP_CFG => B"00011101010100011",
      RX_DISPERR_SEQ_MATCH => "TRUE",
      RX_INT_DATAWIDTH => 0,
      RX_OS_CFG => B"0000010000000",
      RX_SIG_VALID_DLY => 10,
      RX_XCLK_SEL => "RXREC",
      SAS_MAX_COM => 64,
      SAS_MIN_COM => 36,
      SATA_BURST_SEQ_LEN => B"0101",
      SATA_BURST_VAL => B"100",
      SATA_CPLL_CFG => "VCO_3000MHZ",
      SATA_EIDLE_VAL => B"100",
      SATA_MAX_BURST => 8,
      SATA_MAX_INIT => 21,
      SATA_MAX_WAKE => 7,
      SATA_MIN_BURST => 4,
      SATA_MIN_INIT => 12,
      SATA_MIN_WAKE => 4,
      SHOW_REALIGN_COMMA => "TRUE",
      SIM_CPLLREFCLK_SEL => B"001",
      SIM_RECEIVER_DETECT_PASS => "TRUE",
      SIM_RESET_SPEEDUP => "FALSE",
      SIM_TX_EIDLE_DRIVE_LEVEL => "X",
      SIM_VERSION => "2.0",
      TERM_RCAL_CFG => B"100001000010000",
      TERM_RCAL_OVRD => B"000",
      TRANS_TIME_RATE => X"0E",
      TST_RSV => X"00000000",
      TXBUF_EN => "TRUE",
      TXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      TXDLY_CFG => X"001F",
      TXDLY_LCFG => X"030",
      TXDLY_TAP_CFG => X"0000",
      TXGEARBOX_EN => "FALSE",
      TXOOB_CFG => '0',
      TXOUT_DIV => 4,
      TXPCSRESET_TIME => B"00001",
      TXPHDLY_CFG => X"084020",
      TXPH_CFG => X"0780",
      TXPH_MONITOR_SEL => B"00000",
      TXPI_CFG0 => B"00",
      TXPI_CFG1 => B"00",
      TXPI_CFG2 => B"00",
      TXPI_CFG3 => '0',
      TXPI_CFG4 => '0',
      TXPI_CFG5 => B"100",
      TXPI_GREY_SEL => '0',
      TXPI_INVSTROBE_SEL => '0',
      TXPI_PPMCLK_SEL => "TXUSRCLK2",
      TXPI_PPM_CFG => B"00000000",
      TXPI_SYNFREQ_PPM => B"001",
      TXPMARESET_TIME => B"00001",
      TXSYNC_MULTILANE => '0',
      TXSYNC_OVRD => '0',
      TXSYNC_SKIP_DA => '0',
      TX_CLK25_DIV => 5,
      TX_CLKMUX_PD => '1',
      TX_DATA_WIDTH => 20,
      TX_DEEMPH0 => B"000000",
      TX_DEEMPH1 => B"000000",
      TX_DRIVE_MODE => "DIRECT",
      TX_EIDLE_ASSERT_DELAY => B"110",
      TX_EIDLE_DEASSERT_DELAY => B"100",
      TX_INT_DATAWIDTH => 0,
      TX_LOOPBACK_DRIVE_HIZ => "FALSE",
      TX_MAINCURSOR_SEL => '0',
      TX_MARGIN_FULL_0 => B"1001110",
      TX_MARGIN_FULL_1 => B"1001001",
      TX_MARGIN_FULL_2 => B"1000101",
      TX_MARGIN_FULL_3 => B"1000010",
      TX_MARGIN_FULL_4 => B"1000000",
      TX_MARGIN_LOW_0 => B"1000110",
      TX_MARGIN_LOW_1 => B"1000100",
      TX_MARGIN_LOW_2 => B"1000010",
      TX_MARGIN_LOW_3 => B"1000000",
      TX_MARGIN_LOW_4 => B"1000000",
      TX_QPI_STATUS_EN => '0',
      TX_RXDETECT_CFG => X"1832",
      TX_RXDETECT_PRECHARGE_TIME => X"155CC",
      TX_RXDETECT_REF => B"100",
      TX_XCLK_SEL => "TXOUT",
      UCODEER_CLR => '0',
      USE_PCS_CLK_PHASE_SEL => '0'
    )
        port map (
      CFGRESET => '0',
      CLKRSVD0 => '0',
      CLKRSVD1 => '0',
      CPLLFBCLKLOST => gthe2_i_n_0,
      CPLLLOCK => cplllock,
      CPLLLOCKDETCLK => independent_clock_bufg,
      CPLLLOCKEN => '1',
      CPLLPD => cpll_pd_out,
      CPLLREFCLKLOST => CPLLREFCLKLOST,
      CPLLREFCLKSEL(2 downto 0) => B"001",
      CPLLRESET => cpllreset_in,
      DMONFIFORESET => '0',
      DMONITORCLK => '0',
      DMONITOROUT(14) => gthe2_i_n_57,
      DMONITOROUT(13) => gthe2_i_n_58,
      DMONITOROUT(12) => gthe2_i_n_59,
      DMONITOROUT(11) => gthe2_i_n_60,
      DMONITOROUT(10) => gthe2_i_n_61,
      DMONITOROUT(9) => gthe2_i_n_62,
      DMONITOROUT(8) => gthe2_i_n_63,
      DMONITOROUT(7) => gthe2_i_n_64,
      DMONITOROUT(6) => gthe2_i_n_65,
      DMONITOROUT(5) => gthe2_i_n_66,
      DMONITOROUT(4) => gthe2_i_n_67,
      DMONITOROUT(3) => gthe2_i_n_68,
      DMONITOROUT(2) => gthe2_i_n_69,
      DMONITOROUT(1) => gthe2_i_n_70,
      DMONITOROUT(0) => gthe2_i_n_71,
      DRPADDR(8 downto 5) => B"0000",
      DRPADDR(4) => rxpmarst_seq_i_n_1,
      DRPADDR(3 downto 1) => B"000",
      DRPADDR(0) => rxpmarst_seq_i_n_1,
      DRPCLK => gtrefclk_bufg,
      DRPDI(15 downto 0) => DRPDI(15 downto 0),
      DRPDO(15) => gthe2_i_n_72,
      DRPDO(14) => gthe2_i_n_73,
      DRPDO(13) => gthe2_i_n_74,
      DRPDO(12) => gthe2_i_n_75,
      DRPDO(11) => gthe2_i_n_76,
      DRPDO(10) => gthe2_i_n_77,
      DRPDO(9) => gthe2_i_n_78,
      DRPDO(8) => gthe2_i_n_79,
      DRPDO(7) => gthe2_i_n_80,
      DRPDO(6) => gthe2_i_n_81,
      DRPDO(5) => gthe2_i_n_82,
      DRPDO(4) => gthe2_i_n_83,
      DRPDO(3) => gthe2_i_n_84,
      DRPDO(2) => gthe2_i_n_85,
      DRPDO(1) => gthe2_i_n_86,
      DRPDO(0) => gthe2_i_n_87,
      DRPEN => DRPEN,
      DRPRDY => gthe2_i_n_3,
      DRPWE => DRPWE,
      EYESCANDATAERROR => gthe2_i_n_4,
      EYESCANMODE => '0',
      EYESCANRESET => '0',
      EYESCANTRIGGER => '0',
      GTGREFCLK => '0',
      GTHRXN => rxn,
      GTHRXP => rxp,
      GTHTXN => txn,
      GTHTXP => txp,
      GTNORTHREFCLK0 => '0',
      GTNORTHREFCLK1 => '0',
      GTREFCLK0 => gtrefclk,
      GTREFCLK1 => '0',
      GTREFCLKMONITOR => NLW_gthe2_i_GTREFCLKMONITOR_UNCONNECTED,
      GTRESETSEL => '0',
      GTRSVD(15 downto 0) => B"0000000000000000",
      GTRXRESET => GTRXRESET,
      GTSOUTHREFCLK0 => '0',
      GTSOUTHREFCLK1 => '0',
      GTTXRESET => gt0_gttxreset_in0_out,
      LOOPBACK(2 downto 0) => B"000",
      PCSRSVDIN(15 downto 0) => B"0000000000000000",
      PCSRSVDIN2(4 downto 0) => B"00000",
      PCSRSVDOUT(15 downto 0) => NLW_gthe2_i_PCSRSVDOUT_UNCONNECTED(15 downto 0),
      PHYSTATUS => NLW_gthe2_i_PHYSTATUS_UNCONNECTED,
      PMARSVDIN(4 downto 0) => B"00000",
      QPLLCLK => gt0_qplloutclk_in,
      QPLLREFCLK => gt0_qplloutrefclk_in,
      RESETOVRD => '0',
      RSOSINTDONE => NLW_gthe2_i_RSOSINTDONE_UNCONNECTED,
      RX8B10BEN => '1',
      RXADAPTSELTEST(13 downto 0) => B"00000000000000",
      RXBUFRESET => '0',
      RXBUFSTATUS(2) => RXBUFSTATUS(0),
      RXBUFSTATUS(1) => gthe2_i_n_115,
      RXBUFSTATUS(0) => gthe2_i_n_116,
      RXBYTEISALIGNED => gthe2_i_n_10,
      RXBYTEREALIGN => gthe2_i_n_11,
      RXCDRFREQRESET => '0',
      RXCDRHOLD => '0',
      RXCDRLOCK => NLW_gthe2_i_RXCDRLOCK_UNCONNECTED,
      RXCDROVRDEN => '0',
      RXCDRRESET => '0',
      RXCDRRESETRSV => '0',
      RXCHANBONDSEQ => NLW_gthe2_i_RXCHANBONDSEQ_UNCONNECTED,
      RXCHANISALIGNED => NLW_gthe2_i_RXCHANISALIGNED_UNCONNECTED,
      RXCHANREALIGN => NLW_gthe2_i_RXCHANREALIGN_UNCONNECTED,
      RXCHARISCOMMA(7 downto 2) => NLW_gthe2_i_RXCHARISCOMMA_UNCONNECTED(7 downto 2),
      RXCHARISCOMMA(1 downto 0) => \rxchariscomma_reg_reg[1]\(1 downto 0),
      RXCHARISK(7 downto 2) => NLW_gthe2_i_RXCHARISK_UNCONNECTED(7 downto 2),
      RXCHARISK(1 downto 0) => \rxcharisk_reg_reg[1]\(1 downto 0),
      RXCHBONDEN => '0',
      RXCHBONDI(4 downto 0) => B"00000",
      RXCHBONDLEVEL(2 downto 0) => B"000",
      RXCHBONDMASTER => '0',
      RXCHBONDO(4 downto 0) => NLW_gthe2_i_RXCHBONDO_UNCONNECTED(4 downto 0),
      RXCHBONDSLAVE => '0',
      RXCLKCORCNT(1 downto 0) => D(1 downto 0),
      RXCOMINITDET => NLW_gthe2_i_RXCOMINITDET_UNCONNECTED,
      RXCOMMADET => gthe2_i_n_17,
      RXCOMMADETEN => '1',
      RXCOMSASDET => NLW_gthe2_i_RXCOMSASDET_UNCONNECTED,
      RXCOMWAKEDET => NLW_gthe2_i_RXCOMWAKEDET_UNCONNECTED,
      RXDATA(63 downto 16) => NLW_gthe2_i_RXDATA_UNCONNECTED(63 downto 16),
      RXDATA(15 downto 0) => \rxdata_reg_reg[15]\(15 downto 0),
      RXDATAVALID(1 downto 0) => NLW_gthe2_i_RXDATAVALID_UNCONNECTED(1 downto 0),
      RXDDIEN => '0',
      RXDFEAGCHOLD => '0',
      RXDFEAGCOVRDEN => '0',
      RXDFEAGCTRL(4 downto 0) => B"10000",
      RXDFECM1EN => '0',
      RXDFELFHOLD => '0',
      RXDFELFOVRDEN => '0',
      RXDFELPMRESET => '0',
      RXDFESLIDETAP(4 downto 0) => B"00000",
      RXDFESLIDETAPADAPTEN => '0',
      RXDFESLIDETAPHOLD => '0',
      RXDFESLIDETAPID(5 downto 0) => B"000000",
      RXDFESLIDETAPINITOVRDEN => '0',
      RXDFESLIDETAPONLYADAPTEN => '0',
      RXDFESLIDETAPOVRDEN => '0',
      RXDFESLIDETAPSTARTED => NLW_gthe2_i_RXDFESLIDETAPSTARTED_UNCONNECTED,
      RXDFESLIDETAPSTROBE => '0',
      RXDFESLIDETAPSTROBEDONE => NLW_gthe2_i_RXDFESLIDETAPSTROBEDONE_UNCONNECTED,
      RXDFESLIDETAPSTROBESTARTED => NLW_gthe2_i_RXDFESLIDETAPSTROBESTARTED_UNCONNECTED,
      RXDFESTADAPTDONE => NLW_gthe2_i_RXDFESTADAPTDONE_UNCONNECTED,
      RXDFETAP2HOLD => '0',
      RXDFETAP2OVRDEN => '0',
      RXDFETAP3HOLD => '0',
      RXDFETAP3OVRDEN => '0',
      RXDFETAP4HOLD => '0',
      RXDFETAP4OVRDEN => '0',
      RXDFETAP5HOLD => '0',
      RXDFETAP5OVRDEN => '0',
      RXDFETAP6HOLD => '0',
      RXDFETAP6OVRDEN => '0',
      RXDFETAP7HOLD => '0',
      RXDFETAP7OVRDEN => '0',
      RXDFEUTHOLD => '0',
      RXDFEUTOVRDEN => '0',
      RXDFEVPHOLD => '0',
      RXDFEVPOVRDEN => '0',
      RXDFEVSEN => '0',
      RXDFEXYDEN => '1',
      RXDISPERR(7 downto 2) => NLW_gthe2_i_RXDISPERR_UNCONNECTED(7 downto 2),
      RXDISPERR(1 downto 0) => \rxdisperr_reg_reg[1]\(1 downto 0),
      RXDLYBYPASS => '1',
      RXDLYEN => '0',
      RXDLYOVRDEN => '0',
      RXDLYSRESET => '0',
      RXDLYSRESETDONE => NLW_gthe2_i_RXDLYSRESETDONE_UNCONNECTED,
      RXELECIDLE => NLW_gthe2_i_RXELECIDLE_UNCONNECTED,
      RXELECIDLEMODE(1 downto 0) => B"11",
      RXGEARBOXSLIP => '0',
      RXHEADER(5 downto 0) => NLW_gthe2_i_RXHEADER_UNCONNECTED(5 downto 0),
      RXHEADERVALID(1 downto 0) => NLW_gthe2_i_RXHEADERVALID_UNCONNECTED(1 downto 0),
      RXLPMEN => '1',
      RXLPMHFHOLD => '0',
      RXLPMHFOVRDEN => '0',
      RXLPMLFHOLD => '0',
      RXLPMLFKLOVRDEN => '0',
      RXMCOMMAALIGNEN => reset_out,
      RXMONITOROUT(6) => gthe2_i_n_205,
      RXMONITOROUT(5) => gthe2_i_n_206,
      RXMONITOROUT(4) => gthe2_i_n_207,
      RXMONITOROUT(3) => gthe2_i_n_208,
      RXMONITOROUT(2) => gthe2_i_n_209,
      RXMONITOROUT(1) => gthe2_i_n_210,
      RXMONITOROUT(0) => gthe2_i_n_211,
      RXMONITORSEL(1 downto 0) => B"00",
      RXNOTINTABLE(7 downto 2) => NLW_gthe2_i_RXNOTINTABLE_UNCONNECTED(7 downto 2),
      RXNOTINTABLE(1 downto 0) => \rxnotintable_reg_reg[1]\(1 downto 0),
      RXOOBRESET => '0',
      RXOSCALRESET => '0',
      RXOSHOLD => '0',
      RXOSINTCFG(3 downto 0) => B"0110",
      RXOSINTEN => '1',
      RXOSINTHOLD => '0',
      RXOSINTID0(3 downto 0) => B"0000",
      RXOSINTNTRLEN => '0',
      RXOSINTOVRDEN => '0',
      RXOSINTSTARTED => NLW_gthe2_i_RXOSINTSTARTED_UNCONNECTED,
      RXOSINTSTROBE => '0',
      RXOSINTSTROBEDONE => NLW_gthe2_i_RXOSINTSTROBEDONE_UNCONNECTED,
      RXOSINTSTROBESTARTED => NLW_gthe2_i_RXOSINTSTROBESTARTED_UNCONNECTED,
      RXOSINTTESTOVRDEN => '0',
      RXOSOVRDEN => '0',
      RXOUTCLK => rxoutclk,
      RXOUTCLKFABRIC => NLW_gthe2_i_RXOUTCLKFABRIC_UNCONNECTED,
      RXOUTCLKPCS => NLW_gthe2_i_RXOUTCLKPCS_UNCONNECTED,
      RXOUTCLKSEL(2 downto 0) => B"010",
      RXPCOMMAALIGNEN => reset_out,
      RXPCSRESET => reset,
      RXPD(1) => RXPD(0),
      RXPD(0) => RXPD(0),
      RXPHALIGN => '0',
      RXPHALIGNDONE => NLW_gthe2_i_RXPHALIGNDONE_UNCONNECTED,
      RXPHALIGNEN => '0',
      RXPHDLYPD => '0',
      RXPHDLYRESET => '0',
      RXPHMONITOR(4 downto 0) => NLW_gthe2_i_RXPHMONITOR_UNCONNECTED(4 downto 0),
      RXPHOVRDEN => '0',
      RXPHSLIPMONITOR(4 downto 0) => NLW_gthe2_i_RXPHSLIPMONITOR_UNCONNECTED(4 downto 0),
      RXPMARESET => RXPMARESET,
      RXPMARESETDONE => gthe2_i_n_33,
      RXPOLARITY => '0',
      RXPRBSCNTRESET => '0',
      RXPRBSERR => gthe2_i_n_34,
      RXPRBSSEL(2 downto 0) => B"000",
      RXQPIEN => '0',
      RXQPISENN => NLW_gthe2_i_RXQPISENN_UNCONNECTED,
      RXQPISENP => NLW_gthe2_i_RXQPISENP_UNCONNECTED,
      RXRATE(2 downto 0) => B"000",
      RXRATEDONE => NLW_gthe2_i_RXRATEDONE_UNCONNECTED,
      RXRATEMODE => '0',
      RXRESETDONE => data_sync_reg1,
      RXSLIDE => '0',
      RXSTARTOFSEQ(1 downto 0) => NLW_gthe2_i_RXSTARTOFSEQ_UNCONNECTED(1 downto 0),
      RXSTATUS(2 downto 0) => NLW_gthe2_i_RXSTATUS_UNCONNECTED(2 downto 0),
      RXSYNCALLIN => '0',
      RXSYNCDONE => NLW_gthe2_i_RXSYNCDONE_UNCONNECTED,
      RXSYNCIN => '0',
      RXSYNCMODE => '0',
      RXSYNCOUT => NLW_gthe2_i_RXSYNCOUT_UNCONNECTED,
      RXSYSCLKSEL(1 downto 0) => B"00",
      RXUSERRDY => RXUSERRDY,
      RXUSRCLK => userclk,
      RXUSRCLK2 => userclk,
      RXVALID => NLW_gthe2_i_RXVALID_UNCONNECTED,
      SETERRSTATUS => '0',
      SIGVALIDCLK => '0',
      TSTIN(19 downto 0) => B"11111111111111111111",
      TX8B10BBYPASS(7 downto 0) => B"00000000",
      TX8B10BEN => '1',
      TXBUFDIFFCTRL(2 downto 0) => B"100",
      TXBUFSTATUS(1) => TXBUFSTATUS(0),
      TXBUFSTATUS(0) => gthe2_i_n_113,
      TXCHARDISPMODE(7 downto 2) => B"000000",
      TXCHARDISPMODE(1 downto 0) => \txchardispmode_int_reg[1]\(1 downto 0),
      TXCHARDISPVAL(7 downto 2) => B"000000",
      TXCHARDISPVAL(1 downto 0) => \txchardispval_int_reg[1]\(1 downto 0),
      TXCHARISK(7 downto 2) => B"000000",
      TXCHARISK(1 downto 0) => \txcharisk_int_reg[1]\(1 downto 0),
      TXCOMFINISH => NLW_gthe2_i_TXCOMFINISH_UNCONNECTED,
      TXCOMINIT => '0',
      TXCOMSAS => '0',
      TXCOMWAKE => '0',
      TXDATA(63 downto 16) => B"000000000000000000000000000000000000000000000000",
      TXDATA(15 downto 0) => Q(15 downto 0),
      TXDEEMPH => '0',
      TXDETECTRX => '0',
      TXDIFFCTRL(3 downto 0) => B"1000",
      TXDIFFPD => '0',
      TXDLYBYPASS => '1',
      TXDLYEN => '0',
      TXDLYHOLD => '0',
      TXDLYOVRDEN => '0',
      TXDLYSRESET => '0',
      TXDLYSRESETDONE => NLW_gthe2_i_TXDLYSRESETDONE_UNCONNECTED,
      TXDLYUPDOWN => '0',
      TXELECIDLE => TXPD(0),
      TXGEARBOXREADY => NLW_gthe2_i_TXGEARBOXREADY_UNCONNECTED,
      TXHEADER(2 downto 0) => B"000",
      TXINHIBIT => '0',
      TXMAINCURSOR(6 downto 0) => B"0000000",
      TXMARGIN(2 downto 0) => B"000",
      TXOUTCLK => txoutclk,
      TXOUTCLKFABRIC => gthe2_i_n_46,
      TXOUTCLKPCS => gthe2_i_n_47,
      TXOUTCLKSEL(2 downto 0) => B"100",
      TXPCSRESET => '0',
      TXPD(1) => TXPD(0),
      TXPD(0) => TXPD(0),
      TXPDELECIDLEMODE => '0',
      TXPHALIGN => '0',
      TXPHALIGNDONE => NLW_gthe2_i_TXPHALIGNDONE_UNCONNECTED,
      TXPHALIGNEN => '0',
      TXPHDLYPD => '0',
      TXPHDLYRESET => '0',
      TXPHDLYTSTCLK => '0',
      TXPHINIT => '0',
      TXPHINITDONE => NLW_gthe2_i_TXPHINITDONE_UNCONNECTED,
      TXPHOVRDEN => '0',
      TXPIPPMEN => '0',
      TXPIPPMOVRDEN => '0',
      TXPIPPMPD => '0',
      TXPIPPMSEL => '1',
      TXPIPPMSTEPSIZE(4 downto 0) => B"00000",
      TXPISOPD => '0',
      TXPMARESET => '0',
      TXPMARESETDONE => gthe2_i_n_50,
      TXPOLARITY => '0',
      TXPOSTCURSOR(4 downto 0) => B"00000",
      TXPOSTCURSORINV => '0',
      TXPRBSFORCEERR => '0',
      TXPRBSSEL(2 downto 0) => B"000",
      TXPRECURSOR(4 downto 0) => B"00000",
      TXPRECURSORINV => '0',
      TXQPIBIASEN => '0',
      TXQPISENN => NLW_gthe2_i_TXQPISENN_UNCONNECTED,
      TXQPISENP => NLW_gthe2_i_TXQPISENP_UNCONNECTED,
      TXQPISTRONGPDOWN => '0',
      TXQPIWEAKPUP => '0',
      TXRATE(2 downto 0) => B"000",
      TXRATEDONE => NLW_gthe2_i_TXRATEDONE_UNCONNECTED,
      TXRATEMODE => '0',
      TXRESETDONE => data_sync_reg1_0,
      TXSEQUENCE(6 downto 0) => B"0000000",
      TXSTARTSEQ => '0',
      TXSWING => '0',
      TXSYNCALLIN => '0',
      TXSYNCDONE => NLW_gthe2_i_TXSYNCDONE_UNCONNECTED,
      TXSYNCIN => '0',
      TXSYNCMODE => '0',
      TXSYNCOUT => NLW_gthe2_i_TXSYNCOUT_UNCONNECTED,
      TXSYSCLKSEL(1 downto 0) => B"00",
      TXUSERRDY => TXUSERRDY,
      TXUSRCLK => userclk,
      TXUSRCLK2 => userclk
    );
gtrxreset_seq_i: entity work.GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq
     port map (
      CPLL_RESET => CPLL_RESET,
      D(15) => gthe2_i_n_72,
      D(14) => gthe2_i_n_73,
      D(13) => gthe2_i_n_74,
      D(12) => gthe2_i_n_75,
      D(11) => gthe2_i_n_76,
      D(10) => gthe2_i_n_77,
      D(9) => gthe2_i_n_78,
      D(8) => gthe2_i_n_79,
      D(7) => gthe2_i_n_80,
      D(6) => gthe2_i_n_81,
      D(5) => gthe2_i_n_82,
      D(4) => gthe2_i_n_83,
      D(3) => gthe2_i_n_84,
      D(2) => gthe2_i_n_85,
      D(1) => gthe2_i_n_86,
      D(0) => gthe2_i_n_87,
      DRPDI(15 downto 0) => DRPDI(15 downto 0),
      DRPEN => DRPEN,
      DRPWE => DRPWE,
      DRP_OP_DONE => DRP_OP_DONE,
      GTRXRESET => GTRXRESET,
      Q(14) => rxpmarst_seq_i_n_5,
      Q(13) => rxpmarst_seq_i_n_6,
      Q(12) => rxpmarst_seq_i_n_7,
      Q(11) => rxpmarst_seq_i_n_8,
      Q(10) => rxpmarst_seq_i_n_9,
      Q(9) => rxpmarst_seq_i_n_10,
      Q(8) => rxpmarst_seq_i_n_11,
      Q(7) => rxpmarst_seq_i_n_12,
      Q(6) => rxpmarst_seq_i_n_13,
      Q(5) => rxpmarst_seq_i_n_14,
      Q(4) => rxpmarst_seq_i_n_15,
      Q(3) => rxpmarst_seq_i_n_16,
      Q(2) => rxpmarst_seq_i_n_17,
      Q(1) => rxpmarst_seq_i_n_18,
      Q(0) => rxpmarst_seq_i_n_19,
      SR(0) => SR(0),
      \cpllpd_wait_reg[95]\ => gthe2_i_n_3,
      data_in => gthe2_i_n_33,
      drp_busy_i1_reg => gtrxreset_seq_i_n_18,
      gtrefclk_bufg => gtrefclk_bufg,
      \state_reg[0]_0\ => rxpmarst_seq_i_n_2,
      \state_reg[2]_0\ => rxpmarst_seq_i_n_4,
      \state_reg[3]\ => rxpmarst_seq_i_n_3
    );
rxpmarst_seq_i: entity work.GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq
     port map (
      CPLL_RESET => CPLL_RESET,
      D(15) => gthe2_i_n_72,
      D(14) => gthe2_i_n_73,
      D(13) => gthe2_i_n_74,
      D(12) => gthe2_i_n_75,
      D(11) => gthe2_i_n_76,
      D(10) => gthe2_i_n_77,
      D(9) => gthe2_i_n_78,
      D(8) => gthe2_i_n_79,
      D(7) => gthe2_i_n_80,
      D(6) => gthe2_i_n_81,
      D(5) => gthe2_i_n_82,
      D(4) => gthe2_i_n_83,
      D(3) => gthe2_i_n_84,
      D(2) => gthe2_i_n_85,
      D(1) => gthe2_i_n_86,
      D(0) => gthe2_i_n_87,
      DRPADDR(0) => rxpmarst_seq_i_n_1,
      DRP_OP_DONE => DRP_OP_DONE,
      Q(14) => rxpmarst_seq_i_n_5,
      Q(13) => rxpmarst_seq_i_n_6,
      Q(12) => rxpmarst_seq_i_n_7,
      Q(11) => rxpmarst_seq_i_n_8,
      Q(10) => rxpmarst_seq_i_n_9,
      Q(9) => rxpmarst_seq_i_n_10,
      Q(8) => rxpmarst_seq_i_n_11,
      Q(7) => rxpmarst_seq_i_n_12,
      Q(6) => rxpmarst_seq_i_n_13,
      Q(5) => rxpmarst_seq_i_n_14,
      Q(4) => rxpmarst_seq_i_n_15,
      Q(3) => rxpmarst_seq_i_n_16,
      Q(2) => rxpmarst_seq_i_n_17,
      Q(1) => rxpmarst_seq_i_n_18,
      Q(0) => rxpmarst_seq_i_n_19,
      RXPMARESET => RXPMARESET,
      \cpllpd_wait_reg[95]\ => gthe2_i_n_3,
      data_in => gthe2_i_n_33,
      data_sync_reg1 => rxpmarst_seq_i_n_2,
      data_sync_reg1_0 => rxpmarst_seq_i_n_3,
      data_sync_reg1_1 => rxpmarst_seq_i_n_4,
      drp_busy_i1 => drp_busy_i1,
      gtrefclk_bufg => gtrefclk_bufg
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 is
  port (
    reset : in STD_LOGIC;
    signal_detect : in STD_LOGIC;
    link_timer_value : in STD_LOGIC_VECTOR ( 9 downto 0 );
    link_timer_basex : in STD_LOGIC_VECTOR ( 9 downto 0 );
    link_timer_sgmii : in STD_LOGIC_VECTOR ( 9 downto 0 );
    mgt_rx_reset : out STD_LOGIC;
    mgt_tx_reset : out STD_LOGIC;
    userclk : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    dcm_locked : in STD_LOGIC;
    rxbufstatus : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchariscomma : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxcharisk : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxclkcorcnt : in STD_LOGIC_VECTOR ( 2 downto 0 );
    rxdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxdisperr : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxnotintable : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxrundisp : in STD_LOGIC_VECTOR ( 0 to 0 );
    txbuferr : in STD_LOGIC;
    powerdown : out STD_LOGIC;
    txchardispmode : out STD_LOGIC;
    txchardispval : out STD_LOGIC;
    txcharisk : out STD_LOGIC;
    txdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    enablealign : out STD_LOGIC;
    gtx_clk : in STD_LOGIC;
    tx_code_group : out STD_LOGIC_VECTOR ( 9 downto 0 );
    loc_ref : out STD_LOGIC;
    ewrap : out STD_LOGIC;
    rx_code_group0 : in STD_LOGIC_VECTOR ( 9 downto 0 );
    rx_code_group1 : in STD_LOGIC_VECTOR ( 9 downto 0 );
    pma_rx_clk0 : in STD_LOGIC;
    pma_rx_clk1 : in STD_LOGIC;
    en_cdet : out STD_LOGIC;
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_tx_en : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    gmii_rx_er : out STD_LOGIC;
    gmii_isolate : out STD_LOGIC;
    an_interrupt : out STD_LOGIC;
    an_enable : out STD_LOGIC;
    speed_selection : out STD_LOGIC_VECTOR ( 1 downto 0 );
    phyad : in STD_LOGIC_VECTOR ( 4 downto 0 );
    mdc : in STD_LOGIC;
    mdio_in : in STD_LOGIC;
    mdio_out : out STD_LOGIC;
    mdio_tri : out STD_LOGIC;
    an_adv_config_vector : in STD_LOGIC_VECTOR ( 15 downto 0 );
    an_adv_config_val : in STD_LOGIC;
    an_restart_config : in STD_LOGIC;
    configuration_vector : in STD_LOGIC_VECTOR ( 4 downto 0 );
    configuration_valid : in STD_LOGIC;
    status_vector : out STD_LOGIC_VECTOR ( 15 downto 0 );
    basex_or_sgmii : in STD_LOGIC;
    drp_dclk : in STD_LOGIC;
    drp_req : out STD_LOGIC;
    drp_gnt : in STD_LOGIC;
    drp_den : out STD_LOGIC;
    drp_dwe : out STD_LOGIC;
    drp_drdy : in STD_LOGIC;
    drp_daddr : out STD_LOGIC_VECTOR ( 8 downto 0 );
    drp_di : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drp_do : in STD_LOGIC_VECTOR ( 15 downto 0 );
    systemtimer_s_field : in STD_LOGIC_VECTOR ( 47 downto 0 );
    systemtimer_ns_field : in STD_LOGIC_VECTOR ( 31 downto 0 );
    correction_timer : in STD_LOGIC_VECTOR ( 63 downto 0 );
    rxrecclk : in STD_LOGIC;
    rxphy_s_field : out STD_LOGIC_VECTOR ( 47 downto 0 );
    rxphy_ns_field : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxphy_correction_timer : out STD_LOGIC_VECTOR ( 63 downto 0 );
    reset_done : in STD_LOGIC
  );
  attribute B_SHIFTER_ADDR : string;
  attribute B_SHIFTER_ADDR of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "8'b01010000";
  attribute C_1588 : integer;
  attribute C_1588 of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is 0;
  attribute C_COMPONENT_NAME : string;
  attribute C_COMPONENT_NAME of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "GigEthGth7Core";
  attribute C_DYNAMIC_SWITCHING : string;
  attribute C_DYNAMIC_SWITCHING of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_ELABORATION_TRANSIENT_DIR : string;
  attribute C_ELABORATION_TRANSIENT_DIR of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "BlankString";
  attribute C_FAMILY : string;
  attribute C_FAMILY of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "virtex7";
  attribute C_HAS_AN : string;
  attribute C_HAS_AN of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_HAS_MDIO : string;
  attribute C_HAS_MDIO of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_HAS_TEMAC : string;
  attribute C_HAS_TEMAC of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "TRUE";
  attribute C_IS_SGMII : string;
  attribute C_IS_SGMII of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_SGMII_FABRIC_BUFFER : string;
  attribute C_SGMII_FABRIC_BUFFER of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "TRUE";
  attribute C_SGMII_PHY_MODE : string;
  attribute C_SGMII_PHY_MODE of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_USE_LVDS : string;
  attribute C_USE_LVDS of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_USE_TBI : string;
  attribute C_USE_TBI of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "FALSE";
  attribute C_USE_TRANSCEIVER : string;
  attribute C_USE_TRANSCEIVER of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "TRUE";
  attribute GT_RX_BYTE_WIDTH : integer;
  attribute GT_RX_BYTE_WIDTH of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is 1;
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "gig_ethernet_pcs_pma_v15_1_0";
  attribute RX_GT_NOMINAL_LATENCY : string;
  attribute RX_GT_NOMINAL_LATENCY of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "16'b0000000011010010";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 : entity is "yes";
end GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0;

architecture STRUCTURE of GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 is
  signal \<const0>\ : STD_LOGIC;
  signal \<const1>\ : STD_LOGIC;
  signal \^status_vector\ : STD_LOGIC_VECTOR ( 6 downto 0 );
begin
  an_enable <= \<const0>\;
  an_interrupt <= \<const0>\;
  drp_daddr(8) <= \<const0>\;
  drp_daddr(7) <= \<const0>\;
  drp_daddr(6) <= \<const0>\;
  drp_daddr(5) <= \<const0>\;
  drp_daddr(4) <= \<const0>\;
  drp_daddr(3) <= \<const0>\;
  drp_daddr(2) <= \<const0>\;
  drp_daddr(1) <= \<const0>\;
  drp_daddr(0) <= \<const0>\;
  drp_den <= \<const0>\;
  drp_di(15) <= \<const0>\;
  drp_di(14) <= \<const0>\;
  drp_di(13) <= \<const0>\;
  drp_di(12) <= \<const0>\;
  drp_di(11) <= \<const0>\;
  drp_di(10) <= \<const0>\;
  drp_di(9) <= \<const0>\;
  drp_di(8) <= \<const0>\;
  drp_di(7) <= \<const0>\;
  drp_di(6) <= \<const0>\;
  drp_di(5) <= \<const0>\;
  drp_di(4) <= \<const0>\;
  drp_di(3) <= \<const0>\;
  drp_di(2) <= \<const0>\;
  drp_di(1) <= \<const0>\;
  drp_di(0) <= \<const0>\;
  drp_dwe <= \<const0>\;
  drp_req <= \<const0>\;
  en_cdet <= \<const0>\;
  ewrap <= \<const0>\;
  loc_ref <= \<const0>\;
  mdio_out <= \<const1>\;
  mdio_tri <= \<const1>\;
  rxphy_correction_timer(63) <= \<const0>\;
  rxphy_correction_timer(62) <= \<const0>\;
  rxphy_correction_timer(61) <= \<const0>\;
  rxphy_correction_timer(60) <= \<const0>\;
  rxphy_correction_timer(59) <= \<const0>\;
  rxphy_correction_timer(58) <= \<const0>\;
  rxphy_correction_timer(57) <= \<const0>\;
  rxphy_correction_timer(56) <= \<const0>\;
  rxphy_correction_timer(55) <= \<const0>\;
  rxphy_correction_timer(54) <= \<const0>\;
  rxphy_correction_timer(53) <= \<const0>\;
  rxphy_correction_timer(52) <= \<const0>\;
  rxphy_correction_timer(51) <= \<const0>\;
  rxphy_correction_timer(50) <= \<const0>\;
  rxphy_correction_timer(49) <= \<const0>\;
  rxphy_correction_timer(48) <= \<const0>\;
  rxphy_correction_timer(47) <= \<const0>\;
  rxphy_correction_timer(46) <= \<const0>\;
  rxphy_correction_timer(45) <= \<const0>\;
  rxphy_correction_timer(44) <= \<const0>\;
  rxphy_correction_timer(43) <= \<const0>\;
  rxphy_correction_timer(42) <= \<const0>\;
  rxphy_correction_timer(41) <= \<const0>\;
  rxphy_correction_timer(40) <= \<const0>\;
  rxphy_correction_timer(39) <= \<const0>\;
  rxphy_correction_timer(38) <= \<const0>\;
  rxphy_correction_timer(37) <= \<const0>\;
  rxphy_correction_timer(36) <= \<const0>\;
  rxphy_correction_timer(35) <= \<const0>\;
  rxphy_correction_timer(34) <= \<const0>\;
  rxphy_correction_timer(33) <= \<const0>\;
  rxphy_correction_timer(32) <= \<const0>\;
  rxphy_correction_timer(31) <= \<const0>\;
  rxphy_correction_timer(30) <= \<const0>\;
  rxphy_correction_timer(29) <= \<const0>\;
  rxphy_correction_timer(28) <= \<const0>\;
  rxphy_correction_timer(27) <= \<const0>\;
  rxphy_correction_timer(26) <= \<const0>\;
  rxphy_correction_timer(25) <= \<const0>\;
  rxphy_correction_timer(24) <= \<const0>\;
  rxphy_correction_timer(23) <= \<const0>\;
  rxphy_correction_timer(22) <= \<const0>\;
  rxphy_correction_timer(21) <= \<const0>\;
  rxphy_correction_timer(20) <= \<const0>\;
  rxphy_correction_timer(19) <= \<const0>\;
  rxphy_correction_timer(18) <= \<const0>\;
  rxphy_correction_timer(17) <= \<const0>\;
  rxphy_correction_timer(16) <= \<const0>\;
  rxphy_correction_timer(15) <= \<const0>\;
  rxphy_correction_timer(14) <= \<const0>\;
  rxphy_correction_timer(13) <= \<const0>\;
  rxphy_correction_timer(12) <= \<const0>\;
  rxphy_correction_timer(11) <= \<const0>\;
  rxphy_correction_timer(10) <= \<const0>\;
  rxphy_correction_timer(9) <= \<const0>\;
  rxphy_correction_timer(8) <= \<const0>\;
  rxphy_correction_timer(7) <= \<const0>\;
  rxphy_correction_timer(6) <= \<const0>\;
  rxphy_correction_timer(5) <= \<const0>\;
  rxphy_correction_timer(4) <= \<const0>\;
  rxphy_correction_timer(3) <= \<const0>\;
  rxphy_correction_timer(2) <= \<const0>\;
  rxphy_correction_timer(1) <= \<const0>\;
  rxphy_correction_timer(0) <= \<const0>\;
  rxphy_ns_field(31) <= \<const0>\;
  rxphy_ns_field(30) <= \<const0>\;
  rxphy_ns_field(29) <= \<const0>\;
  rxphy_ns_field(28) <= \<const0>\;
  rxphy_ns_field(27) <= \<const0>\;
  rxphy_ns_field(26) <= \<const0>\;
  rxphy_ns_field(25) <= \<const0>\;
  rxphy_ns_field(24) <= \<const0>\;
  rxphy_ns_field(23) <= \<const0>\;
  rxphy_ns_field(22) <= \<const0>\;
  rxphy_ns_field(21) <= \<const0>\;
  rxphy_ns_field(20) <= \<const0>\;
  rxphy_ns_field(19) <= \<const0>\;
  rxphy_ns_field(18) <= \<const0>\;
  rxphy_ns_field(17) <= \<const0>\;
  rxphy_ns_field(16) <= \<const0>\;
  rxphy_ns_field(15) <= \<const0>\;
  rxphy_ns_field(14) <= \<const0>\;
  rxphy_ns_field(13) <= \<const0>\;
  rxphy_ns_field(12) <= \<const0>\;
  rxphy_ns_field(11) <= \<const0>\;
  rxphy_ns_field(10) <= \<const0>\;
  rxphy_ns_field(9) <= \<const0>\;
  rxphy_ns_field(8) <= \<const0>\;
  rxphy_ns_field(7) <= \<const0>\;
  rxphy_ns_field(6) <= \<const0>\;
  rxphy_ns_field(5) <= \<const0>\;
  rxphy_ns_field(4) <= \<const0>\;
  rxphy_ns_field(3) <= \<const0>\;
  rxphy_ns_field(2) <= \<const0>\;
  rxphy_ns_field(1) <= \<const0>\;
  rxphy_ns_field(0) <= \<const0>\;
  rxphy_s_field(47) <= \<const0>\;
  rxphy_s_field(46) <= \<const0>\;
  rxphy_s_field(45) <= \<const0>\;
  rxphy_s_field(44) <= \<const0>\;
  rxphy_s_field(43) <= \<const0>\;
  rxphy_s_field(42) <= \<const0>\;
  rxphy_s_field(41) <= \<const0>\;
  rxphy_s_field(40) <= \<const0>\;
  rxphy_s_field(39) <= \<const0>\;
  rxphy_s_field(38) <= \<const0>\;
  rxphy_s_field(37) <= \<const0>\;
  rxphy_s_field(36) <= \<const0>\;
  rxphy_s_field(35) <= \<const0>\;
  rxphy_s_field(34) <= \<const0>\;
  rxphy_s_field(33) <= \<const0>\;
  rxphy_s_field(32) <= \<const0>\;
  rxphy_s_field(31) <= \<const0>\;
  rxphy_s_field(30) <= \<const0>\;
  rxphy_s_field(29) <= \<const0>\;
  rxphy_s_field(28) <= \<const0>\;
  rxphy_s_field(27) <= \<const0>\;
  rxphy_s_field(26) <= \<const0>\;
  rxphy_s_field(25) <= \<const0>\;
  rxphy_s_field(24) <= \<const0>\;
  rxphy_s_field(23) <= \<const0>\;
  rxphy_s_field(22) <= \<const0>\;
  rxphy_s_field(21) <= \<const0>\;
  rxphy_s_field(20) <= \<const0>\;
  rxphy_s_field(19) <= \<const0>\;
  rxphy_s_field(18) <= \<const0>\;
  rxphy_s_field(17) <= \<const0>\;
  rxphy_s_field(16) <= \<const0>\;
  rxphy_s_field(15) <= \<const0>\;
  rxphy_s_field(14) <= \<const0>\;
  rxphy_s_field(13) <= \<const0>\;
  rxphy_s_field(12) <= \<const0>\;
  rxphy_s_field(11) <= \<const0>\;
  rxphy_s_field(10) <= \<const0>\;
  rxphy_s_field(9) <= \<const0>\;
  rxphy_s_field(8) <= \<const0>\;
  rxphy_s_field(7) <= \<const0>\;
  rxphy_s_field(6) <= \<const0>\;
  rxphy_s_field(5) <= \<const0>\;
  rxphy_s_field(4) <= \<const0>\;
  rxphy_s_field(3) <= \<const0>\;
  rxphy_s_field(2) <= \<const0>\;
  rxphy_s_field(1) <= \<const0>\;
  rxphy_s_field(0) <= \<const0>\;
  speed_selection(1) <= \<const1>\;
  speed_selection(0) <= \<const0>\;
  status_vector(15) <= \<const0>\;
  status_vector(14) <= \<const0>\;
  status_vector(13) <= \<const0>\;
  status_vector(12) <= \<const0>\;
  status_vector(11) <= \<const0>\;
  status_vector(10) <= \<const0>\;
  status_vector(9) <= \<const0>\;
  status_vector(8) <= \<const0>\;
  status_vector(7) <= \<const0>\;
  status_vector(6 downto 0) <= \^status_vector\(6 downto 0);
  tx_code_group(9) <= \<const0>\;
  tx_code_group(8) <= \<const0>\;
  tx_code_group(7) <= \<const0>\;
  tx_code_group(6) <= \<const0>\;
  tx_code_group(5) <= \<const0>\;
  tx_code_group(4) <= \<const0>\;
  tx_code_group(3) <= \<const0>\;
  tx_code_group(2) <= \<const0>\;
  tx_code_group(1) <= \<const0>\;
  tx_code_group(0) <= \<const0>\;
GND: unisim.vcomponents.GND
     port map (
      G => \<const0>\
    );
VCC: unisim.vcomponents.VCC
     port map (
      P => \<const1>\
    );
gpcs_pma_inst: entity work.GigEthGth7Core_GPCS_PMA_GEN
     port map (
      MGT_RX_RESET => mgt_rx_reset,
      MGT_TX_RESET => mgt_tx_reset,
      configuration_vector(2 downto 0) => configuration_vector(3 downto 1),
      dcm_locked => dcm_locked,
      enablealign => enablealign,
      gmii_isolate => gmii_isolate,
      gmii_rx_dv => gmii_rx_dv,
      gmii_rx_er => gmii_rx_er,
      gmii_rxd(7 downto 0) => gmii_rxd(7 downto 0),
      gmii_tx_en => gmii_tx_en,
      gmii_tx_er => gmii_tx_er,
      gmii_txd(7 downto 0) => gmii_txd(7 downto 0),
      reset => reset,
      reset_done => reset_done,
      rxbufstatus(0) => rxbufstatus(1),
      rxchariscomma(0) => rxchariscomma(0),
      rxcharisk(0) => rxcharisk(0),
      rxclkcorcnt(2 downto 0) => rxclkcorcnt(2 downto 0),
      rxdata(7 downto 0) => rxdata(7 downto 0),
      rxdisperr(0) => rxdisperr(0),
      rxnotintable(0) => rxnotintable(0),
      rxpowerdown_reg_reg => powerdown,
      signal_detect => signal_detect,
      status_vector(6 downto 0) => \^status_vector\(6 downto 0),
      txbuferr => txbuferr,
      txchardispmode => txchardispmode,
      txchardispval => txchardispval,
      txcharisk => txcharisk,
      txdata(7 downto 0) => txdata(7 downto 0),
      userclk => userclk,
      userclk2 => userclk2
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt is
  port (
    cplllock : out STD_LOGIC;
    CPLLREFCLKLOST : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    data_sync_reg1 : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    data_sync_reg1_0 : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    TXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    RXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    \rxdata_reg_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \rxchariscomma_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxcharisk_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxdisperr_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxnotintable_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk_bufg : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_gttxreset_in0_out : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    reset_out : in STD_LOGIC;
    reset : in STD_LOGIC;
    RXUSERRDY : in STD_LOGIC;
    userclk : in STD_LOGIC;
    TXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    TXUSERRDY : in STD_LOGIC;
    RXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    Q : in STD_LOGIC_VECTOR ( 15 downto 0 );
    \txchardispmode_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txchardispval_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txcharisk_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    CPLL_RESET : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt : entity is "GigEthGth7Core_GTWIZARD_multi_gt";
end GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt is
  signal cpll_pd_out : STD_LOGIC;
  signal cpllreset_in : STD_LOGIC;
begin
cpll_railing0_i: entity work.GigEthGth7Core_GigEthGth7Core_cpll_railing
     port map (
      CPLL_RESET => CPLL_RESET,
      cpll_pd_out => cpll_pd_out,
      cpllreset_in => cpllreset_in,
      gtrefclk_bufg => gtrefclk_bufg
    );
gt0_GTWIZARD_i: entity work.GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT
     port map (
      CPLLREFCLKLOST => CPLLREFCLKLOST,
      CPLL_RESET => CPLL_RESET,
      D(1 downto 0) => D(1 downto 0),
      Q(15 downto 0) => Q(15 downto 0),
      RXBUFSTATUS(0) => RXBUFSTATUS(0),
      RXPD(0) => RXPD(0),
      RXUSERRDY => RXUSERRDY,
      SR(0) => SR(0),
      TXBUFSTATUS(0) => TXBUFSTATUS(0),
      TXPD(0) => TXPD(0),
      TXUSERRDY => TXUSERRDY,
      cpll_pd_out => cpll_pd_out,
      cplllock => cplllock,
      cpllreset_in => cpllreset_in,
      data_sync_reg1 => data_sync_reg1,
      data_sync_reg1_0 => data_sync_reg1_0,
      gt0_gttxreset_in0_out => gt0_gttxreset_in0_out,
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      reset => reset,
      reset_out => reset_out,
      \rxchariscomma_reg_reg[1]\(1 downto 0) => \rxchariscomma_reg_reg[1]\(1 downto 0),
      \rxcharisk_reg_reg[1]\(1 downto 0) => \rxcharisk_reg_reg[1]\(1 downto 0),
      \rxdata_reg_reg[15]\(15 downto 0) => \rxdata_reg_reg[15]\(15 downto 0),
      \rxdisperr_reg_reg[1]\(1 downto 0) => \rxdisperr_reg_reg[1]\(1 downto 0),
      rxn => rxn,
      \rxnotintable_reg_reg[1]\(1 downto 0) => \rxnotintable_reg_reg[1]\(1 downto 0),
      rxoutclk => rxoutclk,
      rxp => rxp,
      \txchardispmode_int_reg[1]\(1 downto 0) => \txchardispmode_int_reg[1]\(1 downto 0),
      \txchardispval_int_reg[1]\(1 downto 0) => \txchardispval_int_reg[1]\(1 downto 0),
      \txcharisk_int_reg[1]\(1 downto 0) => \txcharisk_int_reg[1]\(1 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_GTWIZARD_init is
  port (
    cplllock : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    TXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    RXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    \rxdata_reg_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \rxchariscomma_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxcharisk_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxdisperr_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxnotintable_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    mmcm_reset : out STD_LOGIC;
    data_in : out STD_LOGIC;
    data_sync_reg1 : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    reset_out : in STD_LOGIC;
    reset : in STD_LOGIC;
    userclk : in STD_LOGIC;
    TXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    RXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    Q : in STD_LOGIC_VECTOR ( 15 downto 0 );
    \txchardispmode_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txchardispval_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txcharisk_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pma_reset : in STD_LOGIC;
    reset_sync6 : in STD_LOGIC;
    reset_sync6_0 : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    data_out : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_GTWIZARD_init : entity is "GigEthGth7Core_GTWIZARD_init";
end GigEthGth7Core_GigEthGth7Core_GTWIZARD_init;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_GTWIZARD_init is
  signal CPLLREFCLKLOST : STD_LOGIC;
  signal CPLL_RESET : STD_LOGIC;
  signal RXUSERRDY : STD_LOGIC;
  signal TXUSERRDY : STD_LOGIC;
  signal \^cplllock\ : STD_LOGIC;
  signal gt0_gtrxreset_gt : STD_LOGIC;
  signal gt0_gtrxreset_gt_d1 : STD_LOGIC;
  signal gt0_gttxreset_in0_out : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[10]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[12]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[12]_i_3_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[12]_i_4_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[12]_i_5_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[12]_i_6_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_10_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_4_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_6_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_7_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_8_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[13]_i_9_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[3]_i_2_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[3]_i_3_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[3]_i_4_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[3]_i_5_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[4]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[7]_i_2_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[7]_i_3_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[7]_i_4_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[7]_i_5_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[8]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter[9]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[12]_i_2_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[12]_i_2_n_1\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[12]_i_2_n_2\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[12]_i_2_n_3\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[13]_i_5_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[13]_i_5_n_1\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[13]_i_5_n_2\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[13]_i_5_n_3\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[3]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[3]_i_1_n_1\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[3]_i_1_n_2\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[3]_i_1_n_3\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[7]_i_1_n_0\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[7]_i_1_n_1\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[7]_i_1_n_2\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg[7]_i_1_n_3\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[0]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[10]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[11]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[12]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[13]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[1]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[2]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[3]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[4]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[5]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[6]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[7]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[8]\ : STD_LOGIC;
  signal \gt0_rx_cdrlock_counter_reg_n_0_[9]\ : STD_LOGIC;
  signal gt0_rx_cdrlocked : STD_LOGIC;
  signal gt0_rx_cdrlocked_i_1_n_0 : STD_LOGIC;
  signal gtwizard_i_n_5 : STD_LOGIC;
  signal gtwizard_i_n_7 : STD_LOGIC;
  signal p_2_in : STD_LOGIC_VECTOR ( 13 downto 0 );
  signal \NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 1 );
  signal \NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 1 );
  signal \NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_gt0_rx_cdrlock_counter_reg[13]_i_5_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \gt0_rx_cdrlock_counter[10]_i_1\ : label is "soft_lutpair64";
  attribute SOFT_HLUTNM of \gt0_rx_cdrlock_counter[13]_i_1\ : label is "soft_lutpair63";
  attribute SOFT_HLUTNM of \gt0_rx_cdrlock_counter[4]_i_1\ : label is "soft_lutpair65";
  attribute SOFT_HLUTNM of \gt0_rx_cdrlock_counter[8]_i_1\ : label is "soft_lutpair65";
  attribute SOFT_HLUTNM of \gt0_rx_cdrlock_counter[9]_i_1\ : label is "soft_lutpair64";
  attribute SOFT_HLUTNM of gt0_rx_cdrlocked_i_1 : label is "soft_lutpair63";
begin
  cplllock <= \^cplllock\;
gt0_gtrxreset_gt_d1_reg: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => '1',
      D => gt0_gtrxreset_gt,
      Q => gt0_gtrxreset_gt_d1,
      R => '0'
    );
\gt0_rx_cdrlock_counter[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[0]\,
      O => p_2_in(0)
    );
\gt0_rx_cdrlock_counter[10]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => p_2_in(10),
      I1 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      O => \gt0_rx_cdrlock_counter[10]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter[12]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      I1 => gt0_gtrxreset_gt_d1,
      O => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter[12]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[12]\,
      O => \gt0_rx_cdrlock_counter[12]_i_3_n_0\
    );
\gt0_rx_cdrlock_counter[12]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[11]\,
      O => \gt0_rx_cdrlock_counter[12]_i_4_n_0\
    );
\gt0_rx_cdrlock_counter[12]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[10]\,
      O => \gt0_rx_cdrlock_counter[12]_i_5_n_0\
    );
\gt0_rx_cdrlock_counter[12]_i_6\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[9]\,
      O => \gt0_rx_cdrlock_counter[12]_i_6_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => p_2_in(13),
      I1 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      O => \gt0_rx_cdrlock_counter[13]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_10\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"01"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[2]\,
      I1 => \gt0_rx_cdrlock_counter_reg_n_0_[1]\,
      I2 => \gt0_rx_cdrlock_counter_reg_n_0_[0]\,
      O => \gt0_rx_cdrlock_counter[13]_i_10_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[13]\,
      O => \gt0_rx_cdrlock_counter[13]_i_4_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_6\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[13]\,
      I1 => \gt0_rx_cdrlock_counter_reg_n_0_[12]\,
      O => \gt0_rx_cdrlock_counter[13]_i_6_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_7\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"20"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[9]\,
      I1 => \gt0_rx_cdrlock_counter_reg_n_0_[11]\,
      I2 => \gt0_rx_cdrlock_counter_reg_n_0_[10]\,
      O => \gt0_rx_cdrlock_counter[13]_i_7_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_8\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[7]\,
      I1 => \gt0_rx_cdrlock_counter_reg_n_0_[8]\,
      I2 => \gt0_rx_cdrlock_counter_reg_n_0_[6]\,
      O => \gt0_rx_cdrlock_counter[13]_i_8_n_0\
    );
\gt0_rx_cdrlock_counter[13]_i_9\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[5]\,
      I1 => \gt0_rx_cdrlock_counter_reg_n_0_[4]\,
      I2 => \gt0_rx_cdrlock_counter_reg_n_0_[3]\,
      O => \gt0_rx_cdrlock_counter[13]_i_9_n_0\
    );
\gt0_rx_cdrlock_counter[3]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[4]\,
      O => \gt0_rx_cdrlock_counter[3]_i_2_n_0\
    );
\gt0_rx_cdrlock_counter[3]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[3]\,
      O => \gt0_rx_cdrlock_counter[3]_i_3_n_0\
    );
\gt0_rx_cdrlock_counter[3]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[2]\,
      O => \gt0_rx_cdrlock_counter[3]_i_4_n_0\
    );
\gt0_rx_cdrlock_counter[3]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[1]\,
      O => \gt0_rx_cdrlock_counter[3]_i_5_n_0\
    );
\gt0_rx_cdrlock_counter[4]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => p_2_in(4),
      I1 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      O => \gt0_rx_cdrlock_counter[4]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter[7]_i_2\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[8]\,
      O => \gt0_rx_cdrlock_counter[7]_i_2_n_0\
    );
\gt0_rx_cdrlock_counter[7]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[7]\,
      O => \gt0_rx_cdrlock_counter[7]_i_3_n_0\
    );
\gt0_rx_cdrlock_counter[7]_i_4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[6]\,
      O => \gt0_rx_cdrlock_counter[7]_i_4_n_0\
    );
\gt0_rx_cdrlock_counter[7]_i_5\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg_n_0_[5]\,
      O => \gt0_rx_cdrlock_counter[7]_i_5_n_0\
    );
\gt0_rx_cdrlock_counter[8]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => p_2_in(8),
      I1 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      O => \gt0_rx_cdrlock_counter[8]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter[9]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => p_2_in(9),
      I1 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      O => \gt0_rx_cdrlock_counter[9]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(0),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[0]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \gt0_rx_cdrlock_counter[10]_i_1_n_0\,
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[10]\,
      R => gt0_gtrxreset_gt_d1
    );
\gt0_rx_cdrlock_counter_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(11),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[11]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(12),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[12]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[12]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => \gt0_rx_cdrlock_counter_reg[7]_i_1_n_0\,
      CO(3) => \gt0_rx_cdrlock_counter_reg[12]_i_2_n_0\,
      CO(2) => \gt0_rx_cdrlock_counter_reg[12]_i_2_n_1\,
      CO(1) => \gt0_rx_cdrlock_counter_reg[12]_i_2_n_2\,
      CO(0) => \gt0_rx_cdrlock_counter_reg[12]_i_2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => p_2_in(12 downto 9),
      S(3) => \gt0_rx_cdrlock_counter[12]_i_3_n_0\,
      S(2) => \gt0_rx_cdrlock_counter[12]_i_4_n_0\,
      S(1) => \gt0_rx_cdrlock_counter[12]_i_5_n_0\,
      S(0) => \gt0_rx_cdrlock_counter[12]_i_6_n_0\
    );
\gt0_rx_cdrlock_counter_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \gt0_rx_cdrlock_counter[13]_i_1_n_0\,
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[13]\,
      R => gt0_gtrxreset_gt_d1
    );
\gt0_rx_cdrlock_counter_reg[13]_i_2\: unisim.vcomponents.CARRY4
     port map (
      CI => \gt0_rx_cdrlock_counter_reg[12]_i_2_n_0\,
      CO(3 downto 0) => \NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_CO_UNCONNECTED\(3 downto 0),
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 1) => \NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_O_UNCONNECTED\(3 downto 1),
      O(0) => p_2_in(13),
      S(3 downto 1) => B"000",
      S(0) => \gt0_rx_cdrlock_counter[13]_i_4_n_0\
    );
\gt0_rx_cdrlock_counter_reg[13]_i_3\: unisim.vcomponents.CARRY4
     port map (
      CI => \gt0_rx_cdrlock_counter_reg[13]_i_5_n_0\,
      CO(3 downto 1) => \NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_CO_UNCONNECTED\(3 downto 1),
      CO(0) => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_O_UNCONNECTED\(3 downto 0),
      S(3 downto 1) => B"000",
      S(0) => \gt0_rx_cdrlock_counter[13]_i_6_n_0\
    );
\gt0_rx_cdrlock_counter_reg[13]_i_5\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \gt0_rx_cdrlock_counter_reg[13]_i_5_n_0\,
      CO(2) => \gt0_rx_cdrlock_counter_reg[13]_i_5_n_1\,
      CO(1) => \gt0_rx_cdrlock_counter_reg[13]_i_5_n_2\,
      CO(0) => \gt0_rx_cdrlock_counter_reg[13]_i_5_n_3\,
      CYINIT => '1',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_gt0_rx_cdrlock_counter_reg[13]_i_5_O_UNCONNECTED\(3 downto 0),
      S(3) => \gt0_rx_cdrlock_counter[13]_i_7_n_0\,
      S(2) => \gt0_rx_cdrlock_counter[13]_i_8_n_0\,
      S(1) => \gt0_rx_cdrlock_counter[13]_i_9_n_0\,
      S(0) => \gt0_rx_cdrlock_counter[13]_i_10_n_0\
    );
\gt0_rx_cdrlock_counter_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(1),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[1]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(2),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[2]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(3),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[3]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[3]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => \gt0_rx_cdrlock_counter_reg[3]_i_1_n_0\,
      CO(2) => \gt0_rx_cdrlock_counter_reg[3]_i_1_n_1\,
      CO(1) => \gt0_rx_cdrlock_counter_reg[3]_i_1_n_2\,
      CO(0) => \gt0_rx_cdrlock_counter_reg[3]_i_1_n_3\,
      CYINIT => \gt0_rx_cdrlock_counter_reg_n_0_[0]\,
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => p_2_in(4 downto 1),
      S(3) => \gt0_rx_cdrlock_counter[3]_i_2_n_0\,
      S(2) => \gt0_rx_cdrlock_counter[3]_i_3_n_0\,
      S(1) => \gt0_rx_cdrlock_counter[3]_i_4_n_0\,
      S(0) => \gt0_rx_cdrlock_counter[3]_i_5_n_0\
    );
\gt0_rx_cdrlock_counter_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \gt0_rx_cdrlock_counter[4]_i_1_n_0\,
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[4]\,
      R => gt0_gtrxreset_gt_d1
    );
\gt0_rx_cdrlock_counter_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(5),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[5]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(6),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[6]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => p_2_in(7),
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[7]\,
      R => \gt0_rx_cdrlock_counter[12]_i_1_n_0\
    );
\gt0_rx_cdrlock_counter_reg[7]_i_1\: unisim.vcomponents.CARRY4
     port map (
      CI => \gt0_rx_cdrlock_counter_reg[3]_i_1_n_0\,
      CO(3) => \gt0_rx_cdrlock_counter_reg[7]_i_1_n_0\,
      CO(2) => \gt0_rx_cdrlock_counter_reg[7]_i_1_n_1\,
      CO(1) => \gt0_rx_cdrlock_counter_reg[7]_i_1_n_2\,
      CO(0) => \gt0_rx_cdrlock_counter_reg[7]_i_1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => p_2_in(8 downto 5),
      S(3) => \gt0_rx_cdrlock_counter[7]_i_2_n_0\,
      S(2) => \gt0_rx_cdrlock_counter[7]_i_3_n_0\,
      S(1) => \gt0_rx_cdrlock_counter[7]_i_4_n_0\,
      S(0) => \gt0_rx_cdrlock_counter[7]_i_5_n_0\
    );
\gt0_rx_cdrlock_counter_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \gt0_rx_cdrlock_counter[8]_i_1_n_0\,
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[8]\,
      R => gt0_gtrxreset_gt_d1
    );
\gt0_rx_cdrlock_counter_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => independent_clock_bufg,
      CE => '1',
      D => \gt0_rx_cdrlock_counter[9]_i_1_n_0\,
      Q => \gt0_rx_cdrlock_counter_reg_n_0_[9]\,
      R => gt0_gtrxreset_gt_d1
    );
gt0_rx_cdrlocked_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
        port map (
      I0 => \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3\,
      I1 => gt0_rx_cdrlocked,
      O => gt0_rx_cdrlocked_i_1_n_0
    );
gt0_rx_cdrlocked_reg: unisim.vcomponents.FDRE
     port map (
      C => independent_clock_bufg,
      CE => '1',
      D => gt0_rx_cdrlocked_i_1_n_0,
      Q => gt0_rx_cdrlocked,
      R => gt0_gtrxreset_gt_d1
    );
gt0_rxresetfsm_i: entity work.GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM
     port map (
      RXUSERRDY => RXUSERRDY,
      cplllock => \^cplllock\,
      \cpllpd_wait_reg[95]\ => gtwizard_i_n_5,
      data_in => data_sync_reg1,
      data_out => data_out,
      gt0_gtrxreset_gt => gt0_gtrxreset_gt,
      gt0_rx_cdrlocked => gt0_rx_cdrlocked,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      pma_reset => pma_reset,
      reset_sync6 => reset_sync6,
      userclk => userclk
    );
gt0_txresetfsm_i: entity work.GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM
     port map (
      CPLLREFCLKLOST => CPLLREFCLKLOST,
      CPLL_RESET => CPLL_RESET,
      TXUSERRDY => TXUSERRDY,
      cplllock => \^cplllock\,
      \cpllpd_wait_reg[95]\ => gtwizard_i_n_7,
      data_in => data_in,
      gt0_gttxreset_in0_out => gt0_gttxreset_in0_out,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      mmcm_reset => mmcm_reset,
      pma_reset => pma_reset,
      reset_sync6 => reset_sync6_0,
      userclk => userclk
    );
gtwizard_i: entity work.GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt
     port map (
      CPLLREFCLKLOST => CPLLREFCLKLOST,
      CPLL_RESET => CPLL_RESET,
      D(1 downto 0) => D(1 downto 0),
      Q(15 downto 0) => Q(15 downto 0),
      RXBUFSTATUS(0) => RXBUFSTATUS(0),
      RXPD(0) => RXPD(0),
      RXUSERRDY => RXUSERRDY,
      SR(0) => gt0_gtrxreset_gt_d1,
      TXBUFSTATUS(0) => TXBUFSTATUS(0),
      TXPD(0) => TXPD(0),
      TXUSERRDY => TXUSERRDY,
      cplllock => \^cplllock\,
      data_sync_reg1 => gtwizard_i_n_5,
      data_sync_reg1_0 => gtwizard_i_n_7,
      gt0_gttxreset_in0_out => gt0_gttxreset_in0_out,
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      reset => reset,
      reset_out => reset_out,
      \rxchariscomma_reg_reg[1]\(1 downto 0) => \rxchariscomma_reg_reg[1]\(1 downto 0),
      \rxcharisk_reg_reg[1]\(1 downto 0) => \rxcharisk_reg_reg[1]\(1 downto 0),
      \rxdata_reg_reg[15]\(15 downto 0) => \rxdata_reg_reg[15]\(15 downto 0),
      \rxdisperr_reg_reg[1]\(1 downto 0) => \rxdisperr_reg_reg[1]\(1 downto 0),
      rxn => rxn,
      \rxnotintable_reg_reg[1]\(1 downto 0) => \rxnotintable_reg_reg[1]\(1 downto 0),
      rxoutclk => rxoutclk,
      rxp => rxp,
      \txchardispmode_int_reg[1]\(1 downto 0) => \txchardispmode_int_reg[1]\(1 downto 0),
      \txchardispval_int_reg[1]\(1 downto 0) => \txchardispval_int_reg[1]\(1 downto 0),
      \txcharisk_int_reg[1]\(1 downto 0) => \txcharisk_int_reg[1]\(1 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_GTWIZARD is
  port (
    cplllock : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    TXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    RXBUFSTATUS : out STD_LOGIC_VECTOR ( 0 to 0 );
    \rxdata_reg_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \rxchariscomma_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxcharisk_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxdisperr_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    \rxnotintable_reg_reg[1]\ : out STD_LOGIC_VECTOR ( 1 downto 0 );
    mmcm_reset : out STD_LOGIC;
    data_in : out STD_LOGIC;
    data_sync_reg1 : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    reset_out : in STD_LOGIC;
    reset : in STD_LOGIC;
    userclk : in STD_LOGIC;
    TXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    RXPD : in STD_LOGIC_VECTOR ( 0 to 0 );
    Q : in STD_LOGIC_VECTOR ( 15 downto 0 );
    \txchardispmode_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txchardispval_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    \txcharisk_int_reg[1]\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pma_reset : in STD_LOGIC;
    reset_sync6 : in STD_LOGIC;
    reset_sync6_0 : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    data_out : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_GTWIZARD : entity is "GigEthGth7Core_GTWIZARD";
end GigEthGth7Core_GigEthGth7Core_GTWIZARD;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_GTWIZARD is
begin
U0: entity work.GigEthGth7Core_GigEthGth7Core_GTWIZARD_init
     port map (
      D(1 downto 0) => D(1 downto 0),
      Q(15 downto 0) => Q(15 downto 0),
      RXBUFSTATUS(0) => RXBUFSTATUS(0),
      RXPD(0) => RXPD(0),
      TXBUFSTATUS(0) => TXBUFSTATUS(0),
      TXPD(0) => TXPD(0),
      cplllock => cplllock,
      data_in => data_in,
      data_out => data_out,
      data_sync_reg1 => data_sync_reg1,
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      mmcm_reset => mmcm_reset,
      pma_reset => pma_reset,
      reset => reset,
      reset_out => reset_out,
      reset_sync6 => reset_sync6,
      reset_sync6_0 => reset_sync6_0,
      \rxchariscomma_reg_reg[1]\(1 downto 0) => \rxchariscomma_reg_reg[1]\(1 downto 0),
      \rxcharisk_reg_reg[1]\(1 downto 0) => \rxcharisk_reg_reg[1]\(1 downto 0),
      \rxdata_reg_reg[15]\(15 downto 0) => \rxdata_reg_reg[15]\(15 downto 0),
      \rxdisperr_reg_reg[1]\(1 downto 0) => \rxdisperr_reg_reg[1]\(1 downto 0),
      rxn => rxn,
      \rxnotintable_reg_reg[1]\(1 downto 0) => \rxnotintable_reg_reg[1]\(1 downto 0),
      rxoutclk => rxoutclk,
      rxp => rxp,
      \txchardispmode_int_reg[1]\(1 downto 0) => \txchardispmode_int_reg[1]\(1 downto 0),
      \txchardispval_int_reg[1]\(1 downto 0) => \txchardispval_int_reg[1]\(1 downto 0),
      \txcharisk_int_reg[1]\(1 downto 0) => \txcharisk_int_reg[1]\(1 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_transceiver is
  port (
    cplllock : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    data_in : out STD_LOGIC;
    data_sync_reg1 : out STD_LOGIC;
    rxchariscomma : out STD_LOGIC;
    rxcharisk : out STD_LOGIC;
    rxclkcorcnt : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rxdisperr : out STD_LOGIC;
    rxnotintable : out STD_LOGIC;
    rxbuferr : out STD_LOGIC;
    txbuferr : out STD_LOGIC;
    mmcm_reset : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    status_vector : in STD_LOGIC_VECTOR ( 0 to 0 );
    independent_clock_bufg : in STD_LOGIC;
    userclk : in STD_LOGIC;
    encommaalign : in STD_LOGIC;
    SR : in STD_LOGIC_VECTOR ( 0 to 0 );
    \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\ : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    pma_reset : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    powerdown : in STD_LOGIC;
    txchardispmode : in STD_LOGIC;
    txchardispval : in STD_LOGIC;
    txdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txcharisk : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_transceiver : entity is "GigEthGth7Core_transceiver";
end GigEthGth7Core_GigEthGth7Core_transceiver;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_transceiver is
  signal gt0_rxchariscomma_out : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal gt0_rxcharisk_out : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal gt0_rxclkcorcnt_out : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal gt0_rxdata_out : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal gt0_rxdisperr_out : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal gt0_rxmcommaalignen_in : STD_LOGIC;
  signal gt0_rxnotintable_out : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal gtwizard_inst_n_7 : STD_LOGIC;
  signal gtwizard_inst_n_8 : STD_LOGIC;
  signal reset : STD_LOGIC;
  signal reset_out : STD_LOGIC;
  signal reset_out1_in : STD_LOGIC;
  signal rxbufstatus_reg : STD_LOGIC_VECTOR ( 2 to 2 );
  signal rxchariscomma_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxchariscomma_i_1_n_0 : STD_LOGIC;
  signal \rxchariscomma_reg__0\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxcharisk_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxcharisk_i_1_n_0 : STD_LOGIC;
  signal \rxcharisk_reg__0\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxclkcorcnt_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxclkcorcnt_reg : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal \rxdata[0]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[1]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[2]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[3]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[4]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[5]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[6]_i_1_n_0\ : STD_LOGIC;
  signal \rxdata[7]_i_1_n_0\ : STD_LOGIC;
  signal rxdata_double : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal rxdata_reg : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal rxdisperr_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxdisperr_i_1_n_0 : STD_LOGIC;
  signal \rxdisperr_reg__0\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxnotintable_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxnotintable_i_1_n_0 : STD_LOGIC;
  signal \rxnotintable_reg__0\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxpowerdown : STD_LOGIC;
  signal rxpowerdown_double : STD_LOGIC;
  signal \rxpowerdown_reg__0\ : STD_LOGIC;
  signal sync_block_data_valid_n_0 : STD_LOGIC;
  signal toggle : STD_LOGIC;
  signal toggle_i_1_n_0 : STD_LOGIC;
  signal txbufstatus_reg : STD_LOGIC_VECTOR ( 1 to 1 );
  signal txchardispmode_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txchardispmode_int : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txchardispmode_reg : STD_LOGIC;
  signal txchardispval_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txchardispval_int : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txchardispval_reg : STD_LOGIC;
  signal txcharisk_double : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txcharisk_int : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal txcharisk_reg : STD_LOGIC;
  signal txdata_double : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal txdata_int : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal txdata_reg : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal txpowerdown : STD_LOGIC;
  signal txpowerdown_double : STD_LOGIC;
  signal \txpowerdown_reg__0\ : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of rxchariscomma_i_1 : label is "soft_lutpair74";
  attribute SOFT_HLUTNM of rxcharisk_i_1 : label is "soft_lutpair74";
  attribute SOFT_HLUTNM of \rxdata[0]_i_1\ : label is "soft_lutpair70";
  attribute SOFT_HLUTNM of \rxdata[1]_i_1\ : label is "soft_lutpair70";
  attribute SOFT_HLUTNM of \rxdata[2]_i_1\ : label is "soft_lutpair71";
  attribute SOFT_HLUTNM of \rxdata[3]_i_1\ : label is "soft_lutpair71";
  attribute SOFT_HLUTNM of \rxdata[4]_i_1\ : label is "soft_lutpair72";
  attribute SOFT_HLUTNM of \rxdata[5]_i_1\ : label is "soft_lutpair72";
  attribute SOFT_HLUTNM of \rxdata[6]_i_1\ : label is "soft_lutpair73";
  attribute SOFT_HLUTNM of \rxdata[7]_i_1\ : label is "soft_lutpair73";
  attribute SOFT_HLUTNM of rxdisperr_i_1 : label is "soft_lutpair75";
  attribute SOFT_HLUTNM of rxnotintable_i_1 : label is "soft_lutpair75";
begin
gtwizard_inst: entity work.GigEthGth7Core_GigEthGth7Core_GTWIZARD
     port map (
      D(1 downto 0) => gt0_rxclkcorcnt_out(1 downto 0),
      Q(15 downto 0) => txdata_int(15 downto 0),
      RXBUFSTATUS(0) => gtwizard_inst_n_8,
      RXPD(0) => rxpowerdown,
      TXBUFSTATUS(0) => gtwizard_inst_n_7,
      TXPD(0) => txpowerdown,
      cplllock => cplllock,
      data_in => data_in,
      data_out => sync_block_data_valid_n_0,
      data_sync_reg1 => data_sync_reg1,
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      mmcm_reset => mmcm_reset,
      pma_reset => pma_reset,
      reset => reset,
      reset_out => gt0_rxmcommaalignen_in,
      reset_sync6 => reset_out1_in,
      reset_sync6_0 => reset_out,
      \rxchariscomma_reg_reg[1]\(1 downto 0) => gt0_rxchariscomma_out(1 downto 0),
      \rxcharisk_reg_reg[1]\(1 downto 0) => gt0_rxcharisk_out(1 downto 0),
      \rxdata_reg_reg[15]\(15 downto 0) => gt0_rxdata_out(15 downto 0),
      \rxdisperr_reg_reg[1]\(1 downto 0) => gt0_rxdisperr_out(1 downto 0),
      rxn => rxn,
      \rxnotintable_reg_reg[1]\(1 downto 0) => gt0_rxnotintable_out(1 downto 0),
      rxoutclk => rxoutclk,
      rxp => rxp,
      \txchardispmode_int_reg[1]\(1 downto 0) => txchardispmode_int(1 downto 0),
      \txchardispval_int_reg[1]\(1 downto 0) => txchardispval_int(1 downto 0),
      \txcharisk_int_reg[1]\(1 downto 0) => txcharisk_int(1 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk
    );
reclock_encommaalign: entity work.GigEthGth7Core_GigEthGth7Core_reset_sync
     port map (
      encommaalign => encommaalign,
      reset_out => gt0_rxmcommaalignen_in,
      userclk => userclk
    );
reclock_rxreset: entity work.GigEthGth7Core_GigEthGth7Core_reset_sync_1
     port map (
      \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0) => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0),
      independent_clock_bufg => independent_clock_bufg,
      reset_out => reset_out1_in
    );
reclock_txreset: entity work.GigEthGth7Core_GigEthGth7Core_reset_sync_2
     port map (
      SR(0) => SR(0),
      independent_clock_bufg => independent_clock_bufg,
      reset_out => reset_out
    );
reset_wtd_timer: entity work.GigEthGth7Core_GigEthGth7Core_reset_wtd_timer
     port map (
      data_out => sync_block_data_valid_n_0,
      independent_clock_bufg => independent_clock_bufg,
      reset => reset
    );
rxbuferr_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxbufstatus_reg(2),
      Q => rxbuferr,
      R => '0'
    );
\rxbufstatus_reg_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gtwizard_inst_n_8,
      Q => rxbufstatus_reg(2),
      R => '0'
    );
\rxchariscomma_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxchariscomma_reg__0\(0),
      Q => rxchariscomma_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxchariscomma_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxchariscomma_reg__0\(1),
      Q => rxchariscomma_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
rxchariscomma_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => rxchariscomma_double(1),
      I1 => toggle,
      I2 => rxchariscomma_double(0),
      O => rxchariscomma_i_1_n_0
    );
rxchariscomma_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxchariscomma_i_1_n_0,
      Q => rxchariscomma,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxchariscomma_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxchariscomma_out(0),
      Q => \rxchariscomma_reg__0\(0),
      R => '0'
    );
\rxchariscomma_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxchariscomma_out(1),
      Q => \rxchariscomma_reg__0\(1),
      R => '0'
    );
\rxcharisk_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxcharisk_reg__0\(0),
      Q => rxcharisk_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxcharisk_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxcharisk_reg__0\(1),
      Q => rxcharisk_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
rxcharisk_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => rxcharisk_double(1),
      I1 => toggle,
      I2 => rxcharisk_double(0),
      O => rxcharisk_i_1_n_0
    );
rxcharisk_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxcharisk_i_1_n_0,
      Q => rxcharisk,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxcharisk_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxcharisk_out(0),
      Q => \rxcharisk_reg__0\(0),
      R => '0'
    );
\rxcharisk_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxcharisk_out(1),
      Q => \rxcharisk_reg__0\(1),
      R => '0'
    );
\rxclkcorcnt_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxclkcorcnt_reg(0),
      Q => rxclkcorcnt_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxclkcorcnt_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxclkcorcnt_reg(1),
      Q => rxclkcorcnt_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxclkcorcnt_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxclkcorcnt_double(0),
      Q => rxclkcorcnt(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxclkcorcnt_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxclkcorcnt_double(1),
      Q => rxclkcorcnt(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxclkcorcnt_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxclkcorcnt_out(0),
      Q => rxclkcorcnt_reg(0),
      R => '0'
    );
\rxclkcorcnt_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxclkcorcnt_out(1),
      Q => rxclkcorcnt_reg(1),
      R => '0'
    );
\rxdata[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(8),
      I1 => rxdata_double(0),
      I2 => toggle,
      O => \rxdata[0]_i_1_n_0\
    );
\rxdata[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(9),
      I1 => rxdata_double(1),
      I2 => toggle,
      O => \rxdata[1]_i_1_n_0\
    );
\rxdata[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(10),
      I1 => rxdata_double(2),
      I2 => toggle,
      O => \rxdata[2]_i_1_n_0\
    );
\rxdata[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(11),
      I1 => rxdata_double(3),
      I2 => toggle,
      O => \rxdata[3]_i_1_n_0\
    );
\rxdata[4]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(12),
      I1 => rxdata_double(4),
      I2 => toggle,
      O => \rxdata[4]_i_1_n_0\
    );
\rxdata[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(13),
      I1 => rxdata_double(5),
      I2 => toggle,
      O => \rxdata[5]_i_1_n_0\
    );
\rxdata[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(14),
      I1 => rxdata_double(6),
      I2 => toggle,
      O => \rxdata[6]_i_1_n_0\
    );
\rxdata[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"AC"
    )
        port map (
      I0 => rxdata_double(15),
      I1 => rxdata_double(7),
      I2 => toggle,
      O => \rxdata[7]_i_1_n_0\
    );
\rxdata_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(0),
      Q => rxdata_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(10),
      Q => rxdata_double(10),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(11),
      Q => rxdata_double(11),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(12),
      Q => rxdata_double(12),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(13),
      Q => rxdata_double(13),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(14),
      Q => rxdata_double(14),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(15),
      Q => rxdata_double(15),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(1),
      Q => rxdata_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(2),
      Q => rxdata_double(2),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(3),
      Q => rxdata_double(3),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(4),
      Q => rxdata_double(4),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(5),
      Q => rxdata_double(5),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(6),
      Q => rxdata_double(6),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(7),
      Q => rxdata_double(7),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(8),
      Q => rxdata_double(8),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_double_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => rxdata_reg(9),
      Q => rxdata_double(9),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[0]_i_1_n_0\,
      Q => rxdata(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[1]_i_1_n_0\,
      Q => rxdata(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[2]_i_1_n_0\,
      Q => rxdata(2),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[3]_i_1_n_0\,
      Q => rxdata(3),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[4]_i_1_n_0\,
      Q => rxdata(4),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[5]_i_1_n_0\,
      Q => rxdata(5),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[6]_i_1_n_0\,
      Q => rxdata(6),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => \rxdata[7]_i_1_n_0\,
      Q => rxdata(7),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdata_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(0),
      Q => rxdata_reg(0),
      R => '0'
    );
\rxdata_reg_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(10),
      Q => rxdata_reg(10),
      R => '0'
    );
\rxdata_reg_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(11),
      Q => rxdata_reg(11),
      R => '0'
    );
\rxdata_reg_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(12),
      Q => rxdata_reg(12),
      R => '0'
    );
\rxdata_reg_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(13),
      Q => rxdata_reg(13),
      R => '0'
    );
\rxdata_reg_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(14),
      Q => rxdata_reg(14),
      R => '0'
    );
\rxdata_reg_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(15),
      Q => rxdata_reg(15),
      R => '0'
    );
\rxdata_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(1),
      Q => rxdata_reg(1),
      R => '0'
    );
\rxdata_reg_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(2),
      Q => rxdata_reg(2),
      R => '0'
    );
\rxdata_reg_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(3),
      Q => rxdata_reg(3),
      R => '0'
    );
\rxdata_reg_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(4),
      Q => rxdata_reg(4),
      R => '0'
    );
\rxdata_reg_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(5),
      Q => rxdata_reg(5),
      R => '0'
    );
\rxdata_reg_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(6),
      Q => rxdata_reg(6),
      R => '0'
    );
\rxdata_reg_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(7),
      Q => rxdata_reg(7),
      R => '0'
    );
\rxdata_reg_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(8),
      Q => rxdata_reg(8),
      R => '0'
    );
\rxdata_reg_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdata_out(9),
      Q => rxdata_reg(9),
      R => '0'
    );
\rxdisperr_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxdisperr_reg__0\(0),
      Q => rxdisperr_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdisperr_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxdisperr_reg__0\(1),
      Q => rxdisperr_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
rxdisperr_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => rxdisperr_double(1),
      I1 => toggle,
      I2 => rxdisperr_double(0),
      O => rxdisperr_i_1_n_0
    );
rxdisperr_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxdisperr_i_1_n_0,
      Q => rxdisperr,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxdisperr_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdisperr_out(0),
      Q => \rxdisperr_reg__0\(0),
      R => '0'
    );
\rxdisperr_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxdisperr_out(1),
      Q => \rxdisperr_reg__0\(1),
      R => '0'
    );
\rxnotintable_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxnotintable_reg__0\(0),
      Q => rxnotintable_double(0),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxnotintable_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle,
      D => \rxnotintable_reg__0\(1),
      Q => rxnotintable_double(1),
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
rxnotintable_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => rxnotintable_double(1),
      I1 => toggle,
      I2 => rxnotintable_double(0),
      O => rxnotintable_i_1_n_0
    );
rxnotintable_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => rxnotintable_i_1_n_0,
      Q => rxnotintable,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
\rxnotintable_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxnotintable_out(0),
      Q => \rxnotintable_reg__0\(0),
      R => '0'
    );
\rxnotintable_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gt0_rxnotintable_out(1),
      Q => \rxnotintable_reg__0\(1),
      R => '0'
    );
rxpowerdown_double_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => toggle,
      D => \rxpowerdown_reg__0\,
      Q => rxpowerdown_double,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
rxpowerdown_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => rxpowerdown_double,
      Q => rxpowerdown,
      R => '0'
    );
rxpowerdown_reg_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => powerdown,
      Q => \rxpowerdown_reg__0\,
      R => \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0)
    );
sync_block_data_valid: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_3
     port map (
      data_out => sync_block_data_valid_n_0,
      independent_clock_bufg => independent_clock_bufg,
      status_vector(0) => status_vector(0)
    );
toggle_i_1: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => toggle,
      O => toggle_i_1_n_0
    );
toggle_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => toggle_i_1_n_0,
      Q => toggle,
      R => SR(0)
    );
txbuferr_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txbufstatus_reg(1),
      Q => txbuferr,
      R => '0'
    );
\txbufstatus_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => gtwizard_inst_n_7,
      Q => txbufstatus_reg(1),
      R => '0'
    );
\txchardispmode_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txchardispmode_reg,
      Q => txchardispmode_double(0),
      R => SR(0)
    );
\txchardispmode_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txchardispmode,
      Q => txchardispmode_double(1),
      R => SR(0)
    );
\txchardispmode_int_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txchardispmode_double(0),
      Q => txchardispmode_int(0),
      R => '0'
    );
\txchardispmode_int_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txchardispmode_double(1),
      Q => txchardispmode_int(1),
      R => '0'
    );
txchardispmode_reg_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txchardispmode,
      Q => txchardispmode_reg,
      R => SR(0)
    );
\txchardispval_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txchardispval_reg,
      Q => txchardispval_double(0),
      R => SR(0)
    );
\txchardispval_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txchardispval,
      Q => txchardispval_double(1),
      R => SR(0)
    );
\txchardispval_int_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txchardispval_double(0),
      Q => txchardispval_int(0),
      R => '0'
    );
\txchardispval_int_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txchardispval_double(1),
      Q => txchardispval_int(1),
      R => '0'
    );
txchardispval_reg_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txchardispval,
      Q => txchardispval_reg,
      R => SR(0)
    );
\txcharisk_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txcharisk_reg,
      Q => txcharisk_double(0),
      R => SR(0)
    );
\txcharisk_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txcharisk,
      Q => txcharisk_double(1),
      R => SR(0)
    );
\txcharisk_int_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txcharisk_double(0),
      Q => txcharisk_int(0),
      R => '0'
    );
\txcharisk_int_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txcharisk_double(1),
      Q => txcharisk_int(1),
      R => '0'
    );
txcharisk_reg_reg: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txcharisk,
      Q => txcharisk_reg,
      R => SR(0)
    );
\txdata_double_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(0),
      Q => txdata_double(0),
      R => SR(0)
    );
\txdata_double_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(2),
      Q => txdata_double(10),
      R => SR(0)
    );
\txdata_double_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(3),
      Q => txdata_double(11),
      R => SR(0)
    );
\txdata_double_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(4),
      Q => txdata_double(12),
      R => SR(0)
    );
\txdata_double_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(5),
      Q => txdata_double(13),
      R => SR(0)
    );
\txdata_double_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(6),
      Q => txdata_double(14),
      R => SR(0)
    );
\txdata_double_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(7),
      Q => txdata_double(15),
      R => SR(0)
    );
\txdata_double_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(1),
      Q => txdata_double(1),
      R => SR(0)
    );
\txdata_double_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(2),
      Q => txdata_double(2),
      R => SR(0)
    );
\txdata_double_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(3),
      Q => txdata_double(3),
      R => SR(0)
    );
\txdata_double_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(4),
      Q => txdata_double(4),
      R => SR(0)
    );
\txdata_double_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(5),
      Q => txdata_double(5),
      R => SR(0)
    );
\txdata_double_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(6),
      Q => txdata_double(6),
      R => SR(0)
    );
\txdata_double_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata_reg(7),
      Q => txdata_double(7),
      R => SR(0)
    );
\txdata_double_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(0),
      Q => txdata_double(8),
      R => SR(0)
    );
\txdata_double_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => toggle_i_1_n_0,
      D => txdata(1),
      Q => txdata_double(9),
      R => SR(0)
    );
\txdata_int_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(0),
      Q => txdata_int(0),
      R => '0'
    );
\txdata_int_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(10),
      Q => txdata_int(10),
      R => '0'
    );
\txdata_int_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(11),
      Q => txdata_int(11),
      R => '0'
    );
\txdata_int_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(12),
      Q => txdata_int(12),
      R => '0'
    );
\txdata_int_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(13),
      Q => txdata_int(13),
      R => '0'
    );
\txdata_int_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(14),
      Q => txdata_int(14),
      R => '0'
    );
\txdata_int_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(15),
      Q => txdata_int(15),
      R => '0'
    );
\txdata_int_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(1),
      Q => txdata_int(1),
      R => '0'
    );
\txdata_int_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(2),
      Q => txdata_int(2),
      R => '0'
    );
\txdata_int_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(3),
      Q => txdata_int(3),
      R => '0'
    );
\txdata_int_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(4),
      Q => txdata_int(4),
      R => '0'
    );
\txdata_int_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(5),
      Q => txdata_int(5),
      R => '0'
    );
\txdata_int_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(6),
      Q => txdata_int(6),
      R => '0'
    );
\txdata_int_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(7),
      Q => txdata_int(7),
      R => '0'
    );
\txdata_int_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(8),
      Q => txdata_int(8),
      R => '0'
    );
\txdata_int_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => userclk,
      CE => '1',
      D => txdata_double(9),
      Q => txdata_int(9),
      R => '0'
    );
\txdata_reg_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(0),
      Q => txdata_reg(0),
      R => SR(0)
    );
\txdata_reg_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(1),
      Q => txdata_reg(1),
      R => SR(0)
    );
\txdata_reg_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(2),
      Q => txdata_reg(2),
      R => SR(0)
    );
\txdata_reg_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(3),
      Q => txdata_reg(3),
      R => SR(0)
    );
\txdata_reg_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(4),
      Q => txdata_reg(4),
      R => SR(0)
    );
\txdata_reg_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(5),
      Q => txdata_reg(5),
      R => SR(0)
    );
\txdata_reg_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(6),
      Q => txdata_reg(6),
      R => SR(0)
    );
\txdata_reg_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => userclk2,
      CE => '1',
      D => txdata(7),
      Q => txdata_reg(7),
      R => SR(0)
    );
txpowerdown_double_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => \txpowerdown_reg__0\,
      Q => txpowerdown_double,
      R => SR(0)
    );
txpowerdown_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk,
      CE => '1',
      D => txpowerdown_double,
      Q => txpowerdown,
      R => '0'
    );
txpowerdown_reg_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
        port map (
      C => userclk2,
      CE => '1',
      D => powerdown,
      Q => \txpowerdown_reg__0\,
      R => SR(0)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core_GigEthGth7Core_block is
  port (
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    gmii_rx_er : out STD_LOGIC;
    gmii_isolate : out STD_LOGIC;
    status_vector : out STD_LOGIC_VECTOR ( 15 downto 0 );
    resetdone : out STD_LOGIC;
    cplllock : out STD_LOGIC;
    txn : out STD_LOGIC;
    txp : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    mmcm_reset : out STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    reset : in STD_LOGIC;
    signal_detect : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_tx_en : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    configuration_vector : in STD_LOGIC_VECTOR ( 4 downto 0 );
    independent_clock_bufg : in STD_LOGIC;
    userclk : in STD_LOGIC;
    rxn : in STD_LOGIC;
    rxp : in STD_LOGIC;
    gtrefclk : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC;
    pma_reset : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GigEthGth7Core_GigEthGth7Core_block : entity is "GigEthGth7Core_block";
end GigEthGth7Core_GigEthGth7Core_block;

architecture STRUCTURE of GigEthGth7Core_GigEthGth7Core_block is
  signal data_in : STD_LOGIC;
  signal data_out : STD_LOGIC;
  signal encommaalign : STD_LOGIC;
  signal powerdown : STD_LOGIC;
  signal \^resetdone\ : STD_LOGIC;
  signal rxbuferr : STD_LOGIC;
  signal rxchariscomma : STD_LOGIC;
  signal rxcharisk : STD_LOGIC;
  signal rxclkcorcnt : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal rxdata : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal rxdisperr : STD_LOGIC;
  signal rxnotintable : STD_LOGIC;
  signal rxreset : STD_LOGIC;
  signal \^status_vector\ : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal transceiver_inst_n_6 : STD_LOGIC;
  signal txbuferr : STD_LOGIC;
  signal txchardispmode : STD_LOGIC;
  signal txchardispval : STD_LOGIC;
  signal txcharisk : STD_LOGIC;
  signal txdata : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal txreset : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_an_enable_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_an_interrupt_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_drp_den_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_drp_dwe_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_drp_req_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_en_cdet_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_ewrap_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_loc_ref_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_mdio_out_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_mdio_tri_UNCONNECTED : STD_LOGIC;
  signal NLW_GigEthGth7Core_core_drp_daddr_UNCONNECTED : STD_LOGIC_VECTOR ( 8 downto 0 );
  signal NLW_GigEthGth7Core_core_drp_di_UNCONNECTED : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal NLW_GigEthGth7Core_core_rxphy_correction_timer_UNCONNECTED : STD_LOGIC_VECTOR ( 63 downto 0 );
  signal NLW_GigEthGth7Core_core_rxphy_ns_field_UNCONNECTED : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal NLW_GigEthGth7Core_core_rxphy_s_field_UNCONNECTED : STD_LOGIC_VECTOR ( 47 downto 0 );
  signal NLW_GigEthGth7Core_core_speed_selection_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_GigEthGth7Core_core_tx_code_group_UNCONNECTED : STD_LOGIC_VECTOR ( 9 downto 0 );
  attribute B_SHIFTER_ADDR : string;
  attribute B_SHIFTER_ADDR of GigEthGth7Core_core : label is "8'b01010000";
  attribute C_1588 : integer;
  attribute C_1588 of GigEthGth7Core_core : label is 0;
  attribute C_COMPONENT_NAME : string;
  attribute C_COMPONENT_NAME of GigEthGth7Core_core : label is "GigEthGth7Core";
  attribute C_DYNAMIC_SWITCHING : string;
  attribute C_DYNAMIC_SWITCHING of GigEthGth7Core_core : label is "FALSE";
  attribute C_ELABORATION_TRANSIENT_DIR : string;
  attribute C_ELABORATION_TRANSIENT_DIR of GigEthGth7Core_core : label is "BlankString";
  attribute C_FAMILY : string;
  attribute C_FAMILY of GigEthGth7Core_core : label is "virtex7";
  attribute C_HAS_AN : string;
  attribute C_HAS_AN of GigEthGth7Core_core : label is "FALSE";
  attribute C_HAS_MDIO : string;
  attribute C_HAS_MDIO of GigEthGth7Core_core : label is "FALSE";
  attribute C_HAS_TEMAC : string;
  attribute C_HAS_TEMAC of GigEthGth7Core_core : label is "TRUE";
  attribute C_IS_SGMII : string;
  attribute C_IS_SGMII of GigEthGth7Core_core : label is "FALSE";
  attribute C_SGMII_FABRIC_BUFFER : string;
  attribute C_SGMII_FABRIC_BUFFER of GigEthGth7Core_core : label is "TRUE";
  attribute C_SGMII_PHY_MODE : string;
  attribute C_SGMII_PHY_MODE of GigEthGth7Core_core : label is "FALSE";
  attribute C_USE_LVDS : string;
  attribute C_USE_LVDS of GigEthGth7Core_core : label is "FALSE";
  attribute C_USE_TBI : string;
  attribute C_USE_TBI of GigEthGth7Core_core : label is "FALSE";
  attribute C_USE_TRANSCEIVER : string;
  attribute C_USE_TRANSCEIVER of GigEthGth7Core_core : label is "TRUE";
  attribute DONT_TOUCH : boolean;
  attribute DONT_TOUCH of GigEthGth7Core_core : label is std.standard.true;
  attribute GT_RX_BYTE_WIDTH : integer;
  attribute GT_RX_BYTE_WIDTH of GigEthGth7Core_core : label is 1;
  attribute RX_GT_NOMINAL_LATENCY : string;
  attribute RX_GT_NOMINAL_LATENCY of GigEthGth7Core_core : label is "16'b0000000011010010";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of GigEthGth7Core_core : label is "yes";
begin
  resetdone <= \^resetdone\;
  status_vector(15 downto 0) <= \^status_vector\(15 downto 0);
GigEthGth7Core_core: entity work.GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0
     port map (
      an_adv_config_val => '0',
      an_adv_config_vector(15 downto 0) => B"0000000000000000",
      an_enable => NLW_GigEthGth7Core_core_an_enable_UNCONNECTED,
      an_interrupt => NLW_GigEthGth7Core_core_an_interrupt_UNCONNECTED,
      an_restart_config => '0',
      basex_or_sgmii => '0',
      configuration_valid => '0',
      configuration_vector(4 downto 0) => configuration_vector(4 downto 0),
      correction_timer(63 downto 0) => B"0000000000000000000000000000000000000000000000000000000000000000",
      dcm_locked => mmcm_locked,
      drp_daddr(8 downto 0) => NLW_GigEthGth7Core_core_drp_daddr_UNCONNECTED(8 downto 0),
      drp_dclk => '0',
      drp_den => NLW_GigEthGth7Core_core_drp_den_UNCONNECTED,
      drp_di(15 downto 0) => NLW_GigEthGth7Core_core_drp_di_UNCONNECTED(15 downto 0),
      drp_do(15 downto 0) => B"0000000000000000",
      drp_drdy => '0',
      drp_dwe => NLW_GigEthGth7Core_core_drp_dwe_UNCONNECTED,
      drp_gnt => '0',
      drp_req => NLW_GigEthGth7Core_core_drp_req_UNCONNECTED,
      en_cdet => NLW_GigEthGth7Core_core_en_cdet_UNCONNECTED,
      enablealign => encommaalign,
      ewrap => NLW_GigEthGth7Core_core_ewrap_UNCONNECTED,
      gmii_isolate => gmii_isolate,
      gmii_rx_dv => gmii_rx_dv,
      gmii_rx_er => gmii_rx_er,
      gmii_rxd(7 downto 0) => gmii_rxd(7 downto 0),
      gmii_tx_en => gmii_tx_en,
      gmii_tx_er => gmii_tx_er,
      gmii_txd(7 downto 0) => gmii_txd(7 downto 0),
      gtx_clk => '0',
      link_timer_basex(9 downto 0) => B"0000000000",
      link_timer_sgmii(9 downto 0) => B"0000000000",
      link_timer_value(9 downto 0) => B"0000000000",
      loc_ref => NLW_GigEthGth7Core_core_loc_ref_UNCONNECTED,
      mdc => '0',
      mdio_in => '0',
      mdio_out => NLW_GigEthGth7Core_core_mdio_out_UNCONNECTED,
      mdio_tri => NLW_GigEthGth7Core_core_mdio_tri_UNCONNECTED,
      mgt_rx_reset => rxreset,
      mgt_tx_reset => txreset,
      phyad(4 downto 0) => B"00000",
      pma_rx_clk0 => '0',
      pma_rx_clk1 => '0',
      powerdown => powerdown,
      reset => reset,
      reset_done => \^resetdone\,
      rx_code_group0(9 downto 0) => B"0000000000",
      rx_code_group1(9 downto 0) => B"0000000000",
      rxbufstatus(1) => rxbuferr,
      rxbufstatus(0) => '0',
      rxchariscomma(0) => rxchariscomma,
      rxcharisk(0) => rxcharisk,
      rxclkcorcnt(2) => '0',
      rxclkcorcnt(1 downto 0) => rxclkcorcnt(1 downto 0),
      rxdata(7 downto 0) => rxdata(7 downto 0),
      rxdisperr(0) => rxdisperr,
      rxnotintable(0) => rxnotintable,
      rxphy_correction_timer(63 downto 0) => NLW_GigEthGth7Core_core_rxphy_correction_timer_UNCONNECTED(63 downto 0),
      rxphy_ns_field(31 downto 0) => NLW_GigEthGth7Core_core_rxphy_ns_field_UNCONNECTED(31 downto 0),
      rxphy_s_field(47 downto 0) => NLW_GigEthGth7Core_core_rxphy_s_field_UNCONNECTED(47 downto 0),
      rxrecclk => '0',
      rxrundisp(0) => '0',
      signal_detect => signal_detect,
      speed_selection(1 downto 0) => NLW_GigEthGth7Core_core_speed_selection_UNCONNECTED(1 downto 0),
      status_vector(15 downto 0) => \^status_vector\(15 downto 0),
      systemtimer_ns_field(31 downto 0) => B"00000000000000000000000000000000",
      systemtimer_s_field(47 downto 0) => B"000000000000000000000000000000000000000000000000",
      tx_code_group(9 downto 0) => NLW_GigEthGth7Core_core_tx_code_group_UNCONNECTED(9 downto 0),
      txbuferr => txbuferr,
      txchardispmode => txchardispmode,
      txchardispval => txchardispval,
      txcharisk => txcharisk,
      txdata(7 downto 0) => txdata(7 downto 0),
      userclk => userclk2,
      userclk2 => userclk2
    );
sync_block_rx_reset_done: entity work.GigEthGth7Core_GigEthGth7Core_sync_block
     port map (
      data_in => transceiver_inst_n_6,
      data_out => data_out,
      userclk2 => userclk2
    );
sync_block_tx_reset_done: entity work.GigEthGth7Core_GigEthGth7Core_sync_block_0
     port map (
      data_in => data_in,
      data_out => data_out,
      resetdone => \^resetdone\,
      userclk2 => userclk2
    );
transceiver_inst: entity work.GigEthGth7Core_GigEthGth7Core_transceiver
     port map (
      SR(0) => txreset,
      \USE_ROCKET_IO.MGT_RX_RESET_INT_reg\(0) => rxreset,
      cplllock => cplllock,
      data_in => data_in,
      data_sync_reg1 => transceiver_inst_n_6,
      encommaalign => encommaalign,
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      mmcm_reset => mmcm_reset,
      pma_reset => pma_reset,
      powerdown => powerdown,
      rxbuferr => rxbuferr,
      rxchariscomma => rxchariscomma,
      rxcharisk => rxcharisk,
      rxclkcorcnt(1 downto 0) => rxclkcorcnt(1 downto 0),
      rxdata(7 downto 0) => rxdata(7 downto 0),
      rxdisperr => rxdisperr,
      rxn => rxn,
      rxnotintable => rxnotintable,
      rxoutclk => rxoutclk,
      rxp => rxp,
      status_vector(0) => \^status_vector\(1),
      txbuferr => txbuferr,
      txchardispmode => txchardispmode,
      txchardispval => txchardispval,
      txcharisk => txcharisk,
      txdata(7 downto 0) => txdata(7 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk,
      userclk2 => userclk2
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GigEthGth7Core is
  port (
    gtrefclk : in STD_LOGIC;
    gtrefclk_bufg : in STD_LOGIC;
    txp : out STD_LOGIC;
    txn : out STD_LOGIC;
    rxp : in STD_LOGIC;
    rxn : in STD_LOGIC;
    resetdone : out STD_LOGIC;
    cplllock : out STD_LOGIC;
    mmcm_reset : out STD_LOGIC;
    txoutclk : out STD_LOGIC;
    rxoutclk : out STD_LOGIC;
    userclk : in STD_LOGIC;
    userclk2 : in STD_LOGIC;
    rxuserclk : in STD_LOGIC;
    rxuserclk2 : in STD_LOGIC;
    pma_reset : in STD_LOGIC;
    mmcm_locked : in STD_LOGIC;
    independent_clock_bufg : in STD_LOGIC;
    gmii_txd : in STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_tx_en : in STD_LOGIC;
    gmii_tx_er : in STD_LOGIC;
    gmii_rxd : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gmii_rx_dv : out STD_LOGIC;
    gmii_rx_er : out STD_LOGIC;
    gmii_isolate : out STD_LOGIC;
    configuration_vector : in STD_LOGIC_VECTOR ( 4 downto 0 );
    status_vector : out STD_LOGIC_VECTOR ( 15 downto 0 );
    reset : in STD_LOGIC;
    signal_detect : in STD_LOGIC;
    gt0_qplloutclk_in : in STD_LOGIC;
    gt0_qplloutrefclk_in : in STD_LOGIC
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of GigEthGth7Core : entity is true;
  attribute core_generation_info : string;
  attribute core_generation_info of GigEthGth7Core : entity is "GigEthGth7Core,gig_ethernet_pcs_pma_v15_1_0,{x_ipProduct=Vivado 2015.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gig_ethernet_pcs_pma,x_ipVersion=15.1,x_ipCoreRevision=0,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,c_elaboration_transient_dir=.,c_component_name=GigEthGth7Core,c_family=virtex7,c_is_sgmii=false,c_use_transceiver=true,c_use_tbi=false,c_is_2_5g=false,c_use_lvds=false,c_has_an=false,c_has_mdio=false,c_has_ext_mdio=false,c_sgmii_phy_mode=false,c_dynamic_switching=false,c_sgmii_fabric_buffer=true,c_1588=0,gt_rx_byte_width=1,C_EMAC_IF_TEMAC=true,C_PHYADDR=1,EXAMPLE_SIMULATION=0,c_support_level=false,c_sub_core_name=GigEthGth7Core_gt,c_transceiver_type=GTHE2,c_transceivercontrol=false,c_xdevicefamily=xc7vx690t,c_gt_dmonitorout_width=15,c_gt_drpaddr_width=9,c_gt_txdiffctrl_width=4,c_gt_rxmonitorout_width=7,c_num_of_lanes=1,c_refclkrate=125,c_drpclkrate=50.0}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of GigEthGth7Core : entity is "yes";
  attribute x_core_info : string;
  attribute x_core_info of GigEthGth7Core : entity is "gig_ethernet_pcs_pma_v15_1_0,Vivado 2015.3";
end GigEthGth7Core;

architecture STRUCTURE of GigEthGth7Core is
begin
U0: entity work.GigEthGth7Core_GigEthGth7Core_block
     port map (
      configuration_vector(4 downto 0) => configuration_vector(4 downto 0),
      cplllock => cplllock,
      gmii_isolate => gmii_isolate,
      gmii_rx_dv => gmii_rx_dv,
      gmii_rx_er => gmii_rx_er,
      gmii_rxd(7 downto 0) => gmii_rxd(7 downto 0),
      gmii_tx_en => gmii_tx_en,
      gmii_tx_er => gmii_tx_er,
      gmii_txd(7 downto 0) => gmii_txd(7 downto 0),
      gt0_qplloutclk_in => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in => gt0_qplloutrefclk_in,
      gtrefclk => gtrefclk,
      gtrefclk_bufg => gtrefclk_bufg,
      independent_clock_bufg => independent_clock_bufg,
      mmcm_locked => mmcm_locked,
      mmcm_reset => mmcm_reset,
      pma_reset => pma_reset,
      reset => reset,
      resetdone => resetdone,
      rxn => rxn,
      rxoutclk => rxoutclk,
      rxp => rxp,
      signal_detect => signal_detect,
      status_vector(15 downto 0) => status_vector(15 downto 0),
      txn => txn,
      txoutclk => txoutclk,
      txp => txp,
      userclk => userclk,
      userclk2 => userclk2
    );
end STRUCTURE;
