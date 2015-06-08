-- Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2014.4 (lin64) Build 1071353 Tue Nov 18 16:48:31 MST 2014
-- Date        : Mon Jun  8 14:33:53 2015
-- Host        : rdusr207 running 64-bit Red Hat Enterprise Linux Server release 5.11 (Tikanga)
-- Command     : write_vhdl -force -mode funcsim
--               /u1/ulegat/jesd204b/build/JesdDacKcu105/JesdDacKcu105_project.srcs/sources_1/ip/GthUltrascaleJesdCoregen/GthUltrascaleJesdCoregen_funcsim.vhdl
-- Design      : GthUltrascaleJesdCoregen
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xcku040-ffva1156-2-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer is
  port (
    E : out STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
    I2 : in STD_LOGIC;
    I3 : in STD_LOGIC;
    sm_reset_all_timer_sat : in STD_LOGIC;
    I4 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer is
  signal gtpowergood_sync : STD_LOGIC;
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[3]_i_2\ : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
\FSM_sequential_sm_reset_all[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"5444"
    )
    port map (
      I0 => \out\(3),
      I1 => \n_0_FSM_sequential_sm_reset_all[3]_i_2\,
      I2 => \out\(1),
      I3 => I2,
      O => E(0)
    );
\FSM_sequential_sm_reset_all[3]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00FF08FF00FF0800"
    )
    port map (
      I0 => I3,
      I1 => sm_reset_all_timer_sat,
      I2 => I4,
      I3 => \out\(2),
      I4 => \out\(0),
      I5 => gtpowergood_sync,
      O => \n_0_FSM_sequential_sm_reset_all[3]_i_2\
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => I1,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtpowergood_sync,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0 is
  port (
    gtwiz_reset_rx_datapath_dly : out STD_LOGIC;
    gtwiz_reset_rx_datapath_sync : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_reset_rx_datapath_sync,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_rx_datapath_dly,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1 is
  port (
    gtwiz_reset_rx_pll_and_datapath_dly : out STD_LOGIC;
    gtwiz_reset_rx_pll_and_datapath_sync : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_reset_rx_pll_and_datapath_sync,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_rx_pll_and_datapath_dly,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10 is
  port (
    p_0_in10_out : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 2 downto 0 );
    O1 : out STD_LOGIC;
    I4 : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    sm_reset_rx_timer_sat : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    I2 : in STD_LOGIC;
    gtwiz_reset_rx_pll_and_datapath_dly : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal rxresetdone_sync : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_sm_reset_rx[2]_i_5\ : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of gtwiz_reset_rx_done_int_i_2 : label is "soft_lutpair2";
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
\FSM_sequential_sm_reset_rx[0]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"4055405555FF55AA"
    )
    port map (
      I0 => \out\(0),
      I1 => rxresetdone_sync,
      I2 => I2,
      I3 => \out\(1),
      I4 => gtwiz_reset_rx_pll_and_datapath_dly,
      I5 => \out\(2),
      O => D(0)
    );
\FSM_sequential_sm_reset_rx[1]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"40AA40AA55AA55FF"
    )
    port map (
      I0 => \out\(0),
      I1 => rxresetdone_sync,
      I2 => I2,
      I3 => \out\(1),
      I4 => gtwiz_reset_rx_pll_and_datapath_dly,
      I5 => \out\(2),
      O => D(1)
    );
\FSM_sequential_sm_reset_rx[2]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AAEAFFFFAAAA0000"
    )
    port map (
      I0 => \out\(0),
      I1 => rxresetdone_sync,
      I2 => sm_reset_rx_timer_sat,
      I3 => I1,
      I4 => \out\(1),
      I5 => \out\(2),
      O => D(2)
    );
\FSM_sequential_sm_reset_rx[2]_i_5\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"00B0"
    )
    port map (
      I0 => rxresetdone_sync,
      I1 => \out\(2),
      I2 => sm_reset_rx_timer_sat,
      I3 => I1,
      O => O1
    );
gtwiz_reset_rx_done_int_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
    port map (
      I0 => I1,
      I1 => sm_reset_rx_timer_sat,
      I2 => rxresetdone_sync,
      O => p_0_in10_out
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => I4,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => rxresetdone_sync,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11 is
  port (
    gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    txusrclk2_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => txusrclk2_in(0),
      CE => '1',
      D => I1,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => txusrclk2_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_tx_done_out(0),
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => txusrclk2_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => txusrclk2_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => txusrclk2_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12 is
  port (
    txresetdone_sync : out STD_LOGIC;
    gtwiz_reset_tx_done_int0 : out STD_LOGIC;
    E : out STD_LOGIC_VECTOR ( 0 to 0 );
    I2 : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    sm_reset_tx_timer_sat : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    I3 : in STD_LOGIC;
    sm_reset_tx_timer_clr0 : in STD_LOGIC;
    plllock_tx_sync : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_tx[2]_i_3\ : STD_LOGIC;
  signal \^txresetdone_sync\ : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
  txresetdone_sync <= \^txresetdone_sync\;
\FSM_sequential_sm_reset_tx[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"B8B8B8B8BBB8B8B8"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_tx[2]_i_3\,
      I1 => \out\(0),
      I2 => I3,
      I3 => sm_reset_tx_timer_clr0,
      I4 => \out\(2),
      I5 => \out\(1),
      O => E(0)
    );
\FSM_sequential_sm_reset_tx[2]_i_3\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0044404400004044"
    )
    port map (
      I0 => I1,
      I1 => sm_reset_tx_timer_sat,
      I2 => \^txresetdone_sync\,
      I3 => \out\(2),
      I4 => \out\(1),
      I5 => plllock_tx_sync,
      O => \n_0_FSM_sequential_sm_reset_tx[2]_i_3\
    );
gtwiz_reset_tx_done_int_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
    port map (
      I0 => I1,
      I1 => sm_reset_tx_timer_sat,
      I2 => \^txresetdone_sync\,
      O => gtwiz_reset_tx_done_int0
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => I2,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => \^txresetdone_sync\,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2 is
  port (
    gtwiz_reset_tx_datapath_dly : out STD_LOGIC;
    gtwiz_reset_tx_datapath_sync : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_reset_tx_datapath_sync,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_tx_datapath_dly,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3 is
  port (
    O1 : out STD_LOGIC;
    D : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_reset_tx_pll_and_datapath_sync : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sm_reset_tx_timer_sat : in STD_LOGIC;
    I1 : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gtwiz_reset_tx_datapath_dly : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3 is
  signal gtwiz_reset_tx_pll_and_datapath_dly : STD_LOGIC;
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_sm_reset_tx[0]_i_1\ : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of \FSM_sequential_sm_reset_tx[1]_i_1\ : label is "soft_lutpair0";
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
\FSM_sequential_sm_reset_tx[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"5756"
    )
    port map (
      I0 => \out\(0),
      I1 => \out\(2),
      I2 => \out\(1),
      I3 => gtwiz_reset_tx_pll_and_datapath_dly,
      O => D(0)
    );
\FSM_sequential_sm_reset_tx[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"4467"
    )
    port map (
      I0 => \out\(1),
      I1 => \out\(0),
      I2 => gtwiz_reset_tx_pll_and_datapath_dly,
      I3 => \out\(2),
      O => D(1)
    );
\FSM_sequential_sm_reset_tx[2]_i_4\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"020F020F020F0200"
    )
    port map (
      I0 => sm_reset_tx_timer_sat,
      I1 => I1,
      I2 => \out\(2),
      I3 => \out\(1),
      I4 => gtwiz_reset_tx_pll_and_datapath_dly,
      I5 => gtwiz_reset_tx_datapath_dly,
      O => O1
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_reset_tx_pll_and_datapath_sync,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_tx_pll_and_datapath_dly,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4 is
  port (
    gtwiz_reset_userclk_rx_active_sync : out STD_LOGIC;
    O1 : out STD_LOGIC;
    O2 : out STD_LOGIC;
    gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gtwiz_reset_rx_any_sync : in STD_LOGIC;
    GTHE3_CHANNEL_RXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    sm_reset_rx_timer_sat : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4 is
  signal \^gtwiz_reset_userclk_rx_active_sync\ : STD_LOGIC;
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal sm_reset_rx_timer_clr0 : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_sm_reset_rx[2]_i_4\ : label is "soft_lutpair1";
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
  attribute SOFT_HLUTNM of rxuserrdy_out_i_2 : label is "soft_lutpair1";
begin
  gtwiz_reset_userclk_rx_active_sync <= \^gtwiz_reset_userclk_rx_active_sync\;
\FSM_sequential_sm_reset_rx[2]_i_4\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"00B0"
    )
    port map (
      I0 => \^gtwiz_reset_userclk_rx_active_sync\,
      I1 => \out\(2),
      I2 => sm_reset_rx_timer_sat,
      I3 => I1,
      O => O2
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_userclk_rx_active_in(0),
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => \^gtwiz_reset_userclk_rx_active_sync\,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
rxuserrdy_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFEBEB00002000"
    )
    port map (
      I0 => \out\(2),
      I1 => \out\(1),
      I2 => \out\(0),
      I3 => sm_reset_rx_timer_clr0,
      I4 => gtwiz_reset_rx_any_sync,
      I5 => GTHE3_CHANNEL_RXUSERRDY(0),
      O => O1
    );
rxuserrdy_out_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
    port map (
      I0 => I1,
      I1 => sm_reset_rx_timer_sat,
      I2 => \^gtwiz_reset_userclk_rx_active_sync\,
      O => sm_reset_rx_timer_clr0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5 is
  port (
    O1 : out STD_LOGIC;
    O2 : out STD_LOGIC;
    sm_reset_tx_timer_clr0 : out STD_LOGIC;
    gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    I1 : in STD_LOGIC;
    I2 : in STD_LOGIC;
    gtwiz_reset_tx_any_sync : in STD_LOGIC;
    GTHE3_CHANNEL_TXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    sm_reset_tx_timer_sat : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5 is
  signal gtwiz_reset_userclk_tx_active_sync : STD_LOGIC;
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal n_0_sm_reset_tx_timer_clr_i_2 : STD_LOGIC;
  signal \^sm_reset_tx_timer_clr0\ : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
  sm_reset_tx_timer_clr0 <= \^sm_reset_tx_timer_clr0\;
\FSM_sequential_sm_reset_tx[2]_i_5\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
    port map (
      I0 => I2,
      I1 => sm_reset_tx_timer_sat,
      I2 => gtwiz_reset_userclk_tx_active_sync,
      O => \^sm_reset_tx_timer_clr0\
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => gtwiz_userclk_tx_active_in(0),
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_userclk_tx_active_sync,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
sm_reset_tx_timer_clr_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFEAEAEA00EAEAEA"
    )
    port map (
      I0 => n_0_sm_reset_tx_timer_clr_i_2,
      I1 => \out\(0),
      I2 => I1,
      I3 => \out\(1),
      I4 => \out\(2),
      I5 => I2,
      O => O1
    );
sm_reset_tx_timer_clr_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000C080C08FF"
    )
    port map (
      I0 => gtwiz_reset_userclk_tx_active_sync,
      I1 => sm_reset_tx_timer_sat,
      I2 => I2,
      I3 => \out\(2),
      I4 => \out\(1),
      I5 => \out\(0),
      O => n_0_sm_reset_tx_timer_clr_i_2
    );
txuserrdy_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFEBEB00000200"
    )
    port map (
      I0 => \out\(2),
      I1 => \out\(1),
      I2 => \out\(0),
      I3 => \^sm_reset_tx_timer_clr0\,
      I4 => gtwiz_reset_tx_any_sync,
      I5 => GTHE3_CHANNEL_TXUSERRDY(0),
      O => O2
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6 is
  port (
    O1 : out STD_LOGIC;
    O2 : out STD_LOGIC;
    O3 : out STD_LOGIC;
    O4 : out STD_LOGIC;
    E : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lock_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    I1 : in STD_LOGIC;
    sm_reset_rx_cdr_to_clr : in STD_LOGIC;
    p_0_in10_out : in STD_LOGIC;
    I2 : in STD_LOGIC;
    gtwiz_reset_rx_any_sync : in STD_LOGIC;
    GTHE3_CHANNEL_GTRXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    I3 : in STD_LOGIC;
    I4 : in STD_LOGIC;
    I5 : in STD_LOGIC;
    I6 : in STD_LOGIC;
    sm_reset_rx_timer_sat : in STD_LOGIC;
    gtwiz_reset_userclk_rx_active_sync : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_rx[2]_i_3\ : STD_LOGIC;
  signal n_0_sm_reset_rx_timer_clr_i_2 : STD_LOGIC;
  signal plllock_rx_sync : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
\FSM_sequential_sm_reset_rx[2]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"AFA0CFCFAFA0C0C0"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_rx[2]_i_3\,
      I1 => I5,
      I2 => \out\(0),
      I3 => I3,
      I4 => \out\(1),
      I5 => I6,
      O => E(0)
    );
\FSM_sequential_sm_reset_rx[2]_i_3\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0008"
    )
    port map (
      I0 => plllock_rx_sync,
      I1 => sm_reset_rx_timer_sat,
      I2 => I4,
      I3 => \out\(2),
      O => \n_0_FSM_sequential_sm_reset_rx[2]_i_3\
    );
gtrxreset_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFF3FFF00001414"
    )
    port map (
      I0 => \out\(2),
      I1 => \out\(1),
      I2 => \out\(0),
      I3 => \n_0_FSM_sequential_sm_reset_rx[2]_i_3\,
      I4 => gtwiz_reset_rx_any_sync,
      I5 => GTHE3_CHANNEL_GTRXRESET(0),
      O => O3
    );
gtwiz_reset_rx_done_int_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"BFBFFFFF30000000"
    )
    port map (
      I0 => plllock_rx_sync,
      I1 => \out\(0),
      I2 => \out\(2),
      I3 => p_0_in10_out,
      I4 => \out\(1),
      I5 => I2,
      O => O2
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => qpll0lock_out(0),
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => plllock_rx_sync,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
sm_reset_rx_cdr_to_clr_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FF7F8F00"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_rx[2]_i_3\,
      I1 => \out\(1),
      I2 => \out\(0),
      I3 => I1,
      I4 => sm_reset_rx_cdr_to_clr,
      O => O1
    );
sm_reset_rx_timer_clr_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FCAFACAF0CA0ACAF"
    )
    port map (
      I0 => n_0_sm_reset_rx_timer_clr_i_2,
      I1 => I3,
      I2 => \out\(0),
      I3 => \out\(1),
      I4 => \out\(2),
      I5 => I4,
      O => O4
    );
sm_reset_rx_timer_clr_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000B8BB0000"
    )
    port map (
      I0 => plllock_rx_sync,
      I1 => \out\(1),
      I2 => gtwiz_reset_userclk_rx_active_sync,
      I3 => \out\(2),
      I4 => sm_reset_rx_timer_sat,
      I5 => I4,
      O => n_0_sm_reset_rx_timer_clr_i_2
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7 is
  port (
    plllock_tx_sync : out STD_LOGIC;
    O1 : out STD_LOGIC;
    O2 : out STD_LOGIC;
    O3 : out STD_LOGIC;
    qpll0lock_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gtwiz_reset_tx_any_sync : in STD_LOGIC;
    GTHE3_CHANNEL_GTTXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_done_int0 : in STD_LOGIC;
    I1 : in STD_LOGIC;
    I2 : in STD_LOGIC;
    sm_reset_tx_timer_sat : in STD_LOGIC;
    txresetdone_sync : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  signal \^plllock_tx_sync\ : STD_LOGIC;
  signal sm_reset_tx_timer_clr011_out : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
  plllock_tx_sync <= \^plllock_tx_sync\;
gttxreset_out_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFBFFF00001414"
    )
    port map (
      I0 => \out\(2),
      I1 => \out\(1),
      I2 => \out\(0),
      I3 => sm_reset_tx_timer_clr011_out,
      I4 => gtwiz_reset_tx_any_sync,
      I5 => GTHE3_CHANNEL_GTTXRESET(0),
      O => O1
    );
gttxreset_out_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"40"
    )
    port map (
      I0 => I2,
      I1 => sm_reset_tx_timer_sat,
      I2 => \^plllock_tx_sync\,
      O => sm_reset_tx_timer_clr011_out
    );
gtwiz_reset_tx_done_int_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFBFFFBF0C000000"
    )
    port map (
      I0 => \^plllock_tx_sync\,
      I1 => \out\(2),
      I2 => \out\(1),
      I3 => \out\(0),
      I4 => gtwiz_reset_tx_done_int0,
      I5 => I1,
      O => O2
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => qpll0lock_out(0),
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => \^plllock_tx_sync\,
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
sm_reset_tx_timer_clr_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000038080000"
    )
    port map (
      I0 => \^plllock_tx_sync\,
      I1 => \out\(1),
      I2 => \out\(2),
      I3 => txresetdone_sync,
      I4 => sm_reset_tx_timer_sat,
      I5 => I2,
      O => O3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8 is
  port (
    gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8 is
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => rxusrclk2_in(0),
      CE => '1',
      D => I1,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => rxusrclk2_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => gtwiz_reset_rx_done_out(0),
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => rxusrclk2_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => rxusrclk2_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => rxusrclk2_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9 is
  port (
    gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    O1 : out STD_LOGIC;
    O2 : out STD_LOGIC;
    I3 : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sm_reset_rx_cdr_to_sat : in STD_LOGIC;
    \out\ : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_reset_rx_pll_and_datapath_dly : in STD_LOGIC;
    gtwiz_reset_rx_datapath_dly : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9 : entity is "gtwizard_ultrascale_v1_4_bit_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9 is
  signal \^gtwiz_reset_rx_cdr_stable_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal i_in_meta : STD_LOGIC;
  signal i_in_sync1 : STD_LOGIC;
  signal i_in_sync2 : STD_LOGIC;
  signal i_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of i_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of i_in_meta_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync1_reg : label is std.standard.true;
  attribute KEEP of i_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync2_reg : label is std.standard.true;
  attribute KEEP of i_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of i_in_sync3_reg : label is std.standard.true;
  attribute KEEP of i_in_sync3_reg : label is "yes";
begin
  gtwiz_reset_rx_cdr_stable_out(0) <= \^gtwiz_reset_rx_cdr_stable_out\(0);
\FSM_sequential_sm_reset_rx[2]_i_6\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"EFEFEFE0"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_sat,
      I1 => \^gtwiz_reset_rx_cdr_stable_out\(0),
      I2 => \out\(1),
      I3 => gtwiz_reset_rx_pll_and_datapath_dly,
      I4 => gtwiz_reset_rx_datapath_dly,
      O => O1
    );
i_in_meta_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => I3,
      Q => i_in_meta,
      R => '0'
    );
i_in_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync3,
      Q => \^gtwiz_reset_rx_cdr_stable_out\(0),
      R => '0'
    );
i_in_sync1_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_meta,
      Q => i_in_sync1,
      R => '0'
    );
i_in_sync2_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync1,
      Q => i_in_sync2,
      R => '0'
    );
i_in_sync3_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => i_in_sync2,
      Q => i_in_sync3,
      R => '0'
    );
sm_reset_rx_cdr_to_clr_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"00FD"
    )
    port map (
      I0 => \out\(1),
      I1 => sm_reset_rx_cdr_to_sat,
      I2 => \^gtwiz_reset_rx_cdr_stable_out\(0),
      I3 => \out\(0),
      O => O2
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel is
  port (
    O1 : out STD_LOGIC;
    gtpowergood_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O2 : out STD_LOGIC;
    txresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O3 : out STD_LOGIC;
    rxcdrlock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O4 : out STD_LOGIC;
    rxresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllfbclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllrefclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    drprdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescandataerror_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclkmonitor_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierategen3_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierateidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pciesynctxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieusergen3rdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserphystatusrst_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratestart_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    phystatus_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    resetexception_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyterealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrphdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanbondseq_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanrealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcominitdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomsasdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomwakedet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxelecidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobestarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignerr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbserr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbslocked_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclkout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsliderdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclkrdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippmardy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxvalid_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomfinish_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinitdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcsrsvdout_out : out STD_LOGIC_VECTOR ( 23 downto 0 );
    rxdata_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
    drpdo_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl0_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl1_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    dmonitorout_out : out STD_LOGIC_VECTOR ( 33 downto 0 );
    pcierateqpllpd_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pcierateqpllreset_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxclkcorcnt_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxdatavalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxheadervalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxstartofseq_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    txbufstatus_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    bufgtce_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtcemask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtreset_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtrstmask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxbufstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondo_out : out STD_LOGIC_VECTOR ( 9 downto 0 );
    rxheader_out : out STD_LOGIC_VECTOR ( 11 downto 0 );
    rxmonitorout_out : out STD_LOGIC_VECTOR ( 13 downto 0 );
    pinrsrvdas_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl2_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl3_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxdataextendrsvd_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    bufgtdiv_out : out STD_LOGIC_VECTOR ( 17 downto 0 );
    cfgreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllockdetclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllocken_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonfiforeset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonitorclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpwe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicaldone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicalstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescantrigger_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtgrefclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxn_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxp_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtresetsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_GTRXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_GTTXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    lpbkrxtxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    lpbktxrxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieeqrxeqadaptdone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierstidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pciersttxsyncstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratedone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll0outclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    resetovrd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rstclkentx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbufreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrfreqreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrresetrsv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbonden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondmaster_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondslave_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadeten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelpmreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeuthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeutovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevphold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevpovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevsen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfexyden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxgearboxslip_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfklovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoobreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoscalreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinttestovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbscntreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_RXPROGDIVRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxqpien_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslide_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippma_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_RXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    sigvalidclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    tx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcominit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomsas_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomwake_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdeemph_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdetectrx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdiffpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyupdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txelecidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txinhibit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpdelecidlemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlytstclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpisopd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpostcursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprbsforceerr_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprecursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_TXPROGDIVRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    txqpibiasen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpistrongpdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpiweakpup_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txswing_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_TXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    txusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
    drpdi_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    gtrsvd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    pcsrsvdin_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl0_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl1_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    rxdfeagcctrl_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxelecidlemode_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxmonitorsel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    cpllrefclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    loopback_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondlevel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txbufdiffctrl_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txmargin_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxosintcfg_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txdiffctrl_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pcsrsvdin2_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    pmarsvdin_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    rxchbondi_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpippmstepsize_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpostcursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txprecursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txheader_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
    txmaincursor_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    txsequence_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    tx8b10bbypass_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txctrl2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txdataextendrsvd_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drpaddr_in : in STD_LOGIC_VECTOR ( 17 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel : entity is "gtwizard_ultrascale_v1_4_gthe3_channel";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel is
  signal \^gtpowergood_out\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal \^rxcdrlock_out\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal \^rxresetdone_out\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal \^txresetdone_out\ : STD_LOGIC_VECTOR ( 1 downto 0 );
  attribute BOX_TYPE : string;
  attribute BOX_TYPE of \gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST\ : label is "PRIMITIVE";
  attribute BOX_TYPE of \gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST\ : label is "PRIMITIVE";
begin
  gtpowergood_out(1 downto 0) <= \^gtpowergood_out\(1 downto 0);
  rxcdrlock_out(1 downto 0) <= \^rxcdrlock_out\(1 downto 0);
  rxresetdone_out(1 downto 0) <= \^rxresetdone_out\(1 downto 0);
  txresetdone_out(1 downto 0) <= \^txresetdone_out\(1 downto 0);
\gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST\: unisim.vcomponents.GTHE3_CHANNEL
    generic map(
      ACJTAG_DEBUG_MODE => '0',
      ACJTAG_MODE => '0',
      ACJTAG_RESET => '0',
      ADAPT_CFG0 => X"F800",
      ADAPT_CFG1 => X"0000",
      ALIGN_COMMA_DOUBLE => "FALSE",
      ALIGN_COMMA_ENABLE => B"1111111111",
      ALIGN_COMMA_WORD => 1,
      ALIGN_MCOMMA_DET => "TRUE",
      ALIGN_MCOMMA_VALUE => B"1010000011",
      ALIGN_PCOMMA_DET => "TRUE",
      ALIGN_PCOMMA_VALUE => B"0101111100",
      A_RXOSCALRESET => '0',
      A_RXPROGDIVRESET => '0',
      A_TXPROGDIVRESET => '0',
      CBCC_DATA_SOURCE_SEL => "DECODED",
      CDR_SWAP_MODE_EN => '0',
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
      CLK_CORRECT_USE => "FALSE",
      CLK_COR_KEEP_IDLE => "FALSE",
      CLK_COR_MAX_LAT => 12,
      CLK_COR_MIN_LAT => 8,
      CLK_COR_PRECEDENCE => "TRUE",
      CLK_COR_REPEAT_WAIT => 0,
      CLK_COR_SEQ_1_1 => B"0100000000",
      CLK_COR_SEQ_1_2 => B"0100000000",
      CLK_COR_SEQ_1_3 => B"0100000000",
      CLK_COR_SEQ_1_4 => B"0100000000",
      CLK_COR_SEQ_1_ENABLE => B"1111",
      CLK_COR_SEQ_2_1 => B"0100000000",
      CLK_COR_SEQ_2_2 => B"0100000000",
      CLK_COR_SEQ_2_3 => B"0100000000",
      CLK_COR_SEQ_2_4 => B"0100000000",
      CLK_COR_SEQ_2_ENABLE => B"1111",
      CLK_COR_SEQ_2_USE => "FALSE",
      CLK_COR_SEQ_LEN => 1,
      CPLL_CFG0 => X"67FA",
      CPLL_CFG1 => X"A494",
      CPLL_CFG2 => X"F007",
      CPLL_CFG3 => B"00" & X"0",
      CPLL_FBDIV => 2,
      CPLL_FBDIV_45 => 5,
      CPLL_INIT_CFG0 => X"001E",
      CPLL_INIT_CFG1 => X"00",
      CPLL_LOCK_CFG => X"01E8",
      CPLL_REFCLK_DIV => 1,
      DDI_CTRL => B"00",
      DDI_REALIGN_WAIT => 15,
      DEC_MCOMMA_DETECT => "TRUE",
      DEC_PCOMMA_DETECT => "TRUE",
      DEC_VALID_COMMA_ONLY => "FALSE",
      DFE_D_X_REL_POS => '0',
      DFE_VCM_COMP_EN => '0',
      DMONITOR_CFG0 => B"00" & X"00",
      DMONITOR_CFG1 => X"00",
      ES_CLK_PHASE_SEL => '0',
      ES_CONTROL => B"000000",
      ES_ERRDET_EN => "FALSE",
      ES_EYE_SCAN_EN => "FALSE",
      ES_HORZ_OFFSET => X"000",
      ES_PMA_CFG => B"0000000000",
      ES_PRESCALE => B"00000",
      ES_QUALIFIER0 => X"0000",
      ES_QUALIFIER1 => X"0000",
      ES_QUALIFIER2 => X"0000",
      ES_QUALIFIER3 => X"0000",
      ES_QUALIFIER4 => X"0000",
      ES_QUAL_MASK0 => X"0000",
      ES_QUAL_MASK1 => X"0000",
      ES_QUAL_MASK2 => X"0000",
      ES_QUAL_MASK3 => X"0000",
      ES_QUAL_MASK4 => X"0000",
      ES_SDATA_MASK0 => X"0000",
      ES_SDATA_MASK1 => X"0000",
      ES_SDATA_MASK2 => X"0000",
      ES_SDATA_MASK3 => X"0000",
      ES_SDATA_MASK4 => X"0000",
      EVODD_PHI_CFG => B"00000000000",
      EYE_SCAN_SWAP_EN => '0',
      FTS_DESKEW_SEQ_ENABLE => B"1111",
      FTS_LANE_DESKEW_CFG => B"1111",
      FTS_LANE_DESKEW_EN => "FALSE",
      GEARBOX_MODE => B"00000",
      GM_BIAS_SELECT => '0',
      LOCAL_MASTER => '1',
      OOBDIVCTL => B"00",
      OOB_PWRUP => '0',
      PCI3_AUTO_REALIGN => "OVR_1K_BLK",
      PCI3_PIPE_RX_ELECIDLE => '0',
      PCI3_RX_ASYNC_EBUF_BYPASS => B"00",
      PCI3_RX_ELECIDLE_EI2_ENABLE => '0',
      PCI3_RX_ELECIDLE_H2L_COUNT => B"000000",
      PCI3_RX_ELECIDLE_H2L_DISABLE => B"000",
      PCI3_RX_ELECIDLE_HI_COUNT => B"000000",
      PCI3_RX_ELECIDLE_LP4_DISABLE => '0',
      PCI3_RX_FIFO_DISABLE => '0',
      PCIE_BUFG_DIV_CTRL => X"1000",
      PCIE_RXPCS_CFG_GEN3 => X"02A4",
      PCIE_RXPMA_CFG => X"000A",
      PCIE_TXPCS_CFG_GEN3 => X"24A0",
      PCIE_TXPMA_CFG => X"000A",
      PCS_PCIE_EN => "FALSE",
      PCS_RSVD0 => B"0000000000000000",
      PCS_RSVD1 => B"000",
      PD_TRANS_TIME_FROM_P2 => X"03C",
      PD_TRANS_TIME_NONE_P2 => X"19",
      PD_TRANS_TIME_TO_P2 => X"64",
      PLL_SEL_MODE_GEN12 => B"00",
      PLL_SEL_MODE_GEN3 => B"11",
      PMA_RSV1 => X"1800",
      PROCESS_PAR => B"010",
      RATE_SW_USE_DRP => '0',
      RESET_POWERSAVE_DISABLE => '0',
      RXBUFRESET_TIME => B"00011",
      RXBUF_ADDR_MODE => "FAST",
      RXBUF_EIDLE_HI_CNT => B"1000",
      RXBUF_EIDLE_LO_CNT => B"0000",
      RXBUF_EN => "TRUE",
      RXBUF_RESET_ON_CB_CHANGE => "TRUE",
      RXBUF_RESET_ON_COMMAALIGN => "FALSE",
      RXBUF_RESET_ON_EIDLE => "FALSE",
      RXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      RXBUF_THRESH_OVFLW => 57,
      RXBUF_THRESH_OVRD => "TRUE",
      RXBUF_THRESH_UNDFLW => 3,
      RXCDRFREQRESET_TIME => B"00001",
      RXCDRPHRESET_TIME => B"00001",
      RXCDR_CFG0 => X"0000",
      RXCDR_CFG0_GEN3 => X"0000",
      RXCDR_CFG1 => X"0000",
      RXCDR_CFG1_GEN3 => X"0000",
      RXCDR_CFG2 => X"0756",
      RXCDR_CFG2_GEN3 => X"0756",
      RXCDR_CFG3 => X"0000",
      RXCDR_CFG3_GEN3 => X"0000",
      RXCDR_CFG4 => X"0000",
      RXCDR_CFG4_GEN3 => X"0000",
      RXCDR_CFG5 => X"0000",
      RXCDR_CFG5_GEN3 => X"0000",
      RXCDR_FR_RESET_ON_EIDLE => '0',
      RXCDR_HOLD_DURING_EIDLE => '0',
      RXCDR_LOCK_CFG0 => X"4480",
      RXCDR_LOCK_CFG1 => X"5FFF",
      RXCDR_LOCK_CFG2 => X"77C3",
      RXCDR_PH_RESET_ON_EIDLE => '0',
      RXCFOK_CFG0 => X"4000",
      RXCFOK_CFG1 => X"0065",
      RXCFOK_CFG2 => X"002E",
      RXDFELPMRESET_TIME => B"0001111",
      RXDFELPM_KL_CFG0 => X"0000",
      RXDFELPM_KL_CFG1 => X"0002",
      RXDFELPM_KL_CFG2 => X"0000",
      RXDFE_CFG0 => X"0A00",
      RXDFE_CFG1 => X"0000",
      RXDFE_GC_CFG0 => X"0000",
      RXDFE_GC_CFG1 => X"7870",
      RXDFE_GC_CFG2 => X"0000",
      RXDFE_H2_CFG0 => X"0000",
      RXDFE_H2_CFG1 => X"0000",
      RXDFE_H3_CFG0 => X"4000",
      RXDFE_H3_CFG1 => X"0000",
      RXDFE_H4_CFG0 => X"2000",
      RXDFE_H4_CFG1 => X"0003",
      RXDFE_H5_CFG0 => X"2000",
      RXDFE_H5_CFG1 => X"0003",
      RXDFE_H6_CFG0 => X"2000",
      RXDFE_H6_CFG1 => X"0000",
      RXDFE_H7_CFG0 => X"2000",
      RXDFE_H7_CFG1 => X"0000",
      RXDFE_H8_CFG0 => X"2000",
      RXDFE_H8_CFG1 => X"0000",
      RXDFE_H9_CFG0 => X"2000",
      RXDFE_H9_CFG1 => X"0000",
      RXDFE_HA_CFG0 => X"2000",
      RXDFE_HA_CFG1 => X"0000",
      RXDFE_HB_CFG0 => X"2000",
      RXDFE_HB_CFG1 => X"0000",
      RXDFE_HC_CFG0 => X"0000",
      RXDFE_HC_CFG1 => X"0000",
      RXDFE_HD_CFG0 => X"0000",
      RXDFE_HD_CFG1 => X"0000",
      RXDFE_HE_CFG0 => X"0000",
      RXDFE_HE_CFG1 => X"0000",
      RXDFE_HF_CFG0 => X"0000",
      RXDFE_HF_CFG1 => X"0000",
      RXDFE_OS_CFG0 => X"8000",
      RXDFE_OS_CFG1 => X"0000",
      RXDFE_UT_CFG0 => X"8000",
      RXDFE_UT_CFG1 => X"0003",
      RXDFE_VP_CFG0 => X"AA00",
      RXDFE_VP_CFG1 => X"0033",
      RXDLY_CFG => X"001F",
      RXDLY_LCFG => X"0030",
      RXELECIDLE_CFG => "Sigcfg_4",
      RXGBOX_FIFO_INIT_RD_ADDR => 4,
      RXGEARBOX_EN => "FALSE",
      RXISCANRESET_TIME => B"00001",
      RXLPM_CFG => X"0000",
      RXLPM_GC_CFG => X"0000",
      RXLPM_KH_CFG0 => X"0000",
      RXLPM_KH_CFG1 => X"0002",
      RXLPM_OS_CFG0 => X"8000",
      RXLPM_OS_CFG1 => X"0002",
      RXOOB_CFG => B"000000110",
      RXOOB_CLK_CFG => "PMA",
      RXOSCALRESET_TIME => B"00011",
      RXOUT_DIV => 2,
      RXPCSRESET_TIME => B"00011",
      RXPHBEACON_CFG => X"0000",
      RXPHDLY_CFG => X"2020",
      RXPHSAMP_CFG => X"2100",
      RXPHSLIP_CFG => X"6622",
      RXPH_MONITOR_SEL => B"00000",
      RXPI_CFG0 => B"00",
      RXPI_CFG1 => B"00",
      RXPI_CFG2 => B"00",
      RXPI_CFG3 => B"00",
      RXPI_CFG4 => '0',
      RXPI_CFG5 => '0',
      RXPI_CFG6 => B"000",
      RXPI_LPM => '0',
      RXPI_VREFSEL => '0',
      RXPMACLK_SEL => "DATA",
      RXPMARESET_TIME => B"00011",
      RXPRBS_ERR_LOOPBACK => '0',
      RXPRBS_LINKACQ_CNT => 15,
      RXSLIDE_AUTO_WAIT => 7,
      RXSLIDE_MODE => "OFF",
      RXSYNC_MULTILANE => '1',
      RXSYNC_OVRD => '0',
      RXSYNC_SKIP_DA => '0',
      RX_AFE_CM_EN => '0',
      RX_BIAS_CFG0 => X"0AB4",
      RX_BUFFER_CFG => B"000000",
      RX_CAPFF_SARC_ENB => '0',
      RX_CLK25_DIV => 15,
      RX_CLKMUX_EN => '1',
      RX_CLK_SLIP_OVRD => B"00000",
      RX_CM_BUF_CFG => B"1010",
      RX_CM_BUF_PD => '0',
      RX_CM_SEL => B"11",
      RX_CM_TRIM => B"1010",
      RX_CTLE3_LPF => B"00000001",
      RX_DATA_WIDTH => 40,
      RX_DDI_SEL => B"000000",
      RX_DEFER_RESET_BUF_EN => "TRUE",
      RX_DFELPM_CFG0 => B"0110",
      RX_DFELPM_CFG1 => '1',
      RX_DFELPM_KLKH_AGC_STUP_EN => '1',
      RX_DFE_AGC_CFG0 => B"10",
      RX_DFE_AGC_CFG1 => B"100",
      RX_DFE_KL_LPM_KH_CFG0 => B"01",
      RX_DFE_KL_LPM_KH_CFG1 => B"100",
      RX_DFE_KL_LPM_KL_CFG0 => B"01",
      RX_DFE_KL_LPM_KL_CFG1 => B"100",
      RX_DFE_LPM_HOLD_DURING_EIDLE => '0',
      RX_DISPERR_SEQ_MATCH => "TRUE",
      RX_DIVRESET_TIME => B"00001",
      RX_EN_HI_LR => '0',
      RX_EYESCAN_VS_CODE => B"0000000",
      RX_EYESCAN_VS_NEG_DIR => '0',
      RX_EYESCAN_VS_RANGE => B"00",
      RX_EYESCAN_VS_UT_SIGN => '0',
      RX_FABINT_USRCLK_FLOP => '0',
      RX_INT_DATAWIDTH => 1,
      RX_PMA_POWER_SAVE => '0',
      RX_PROGDIV_CFG => 40.000000,
      RX_SAMPLE_PERIOD => B"111",
      RX_SIG_VALID_DLY => 11,
      RX_SUM_DFETAPREP_EN => '0',
      RX_SUM_IREF_TUNE => B"0000",
      RX_SUM_RES_CTRL => B"00",
      RX_SUM_VCMTUNE => B"0000",
      RX_SUM_VCM_OVWR => '0',
      RX_SUM_VREF_TUNE => B"000",
      RX_TUNE_AFE_OS => B"10",
      RX_WIDEMODE_CDR => '0',
      RX_XCLK_SEL => "RXDES",
      SAS_MAX_COM => 64,
      SAS_MIN_COM => 36,
      SATA_BURST_SEQ_LEN => B"1111",
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
      SIM_RECEIVER_DETECT_PASS => "TRUE",
      SIM_RESET_SPEEDUP => "TRUE",
      SIM_TX_EIDLE_DRIVE_LEVEL => '0',
      SIM_VERSION => 2,
      TAPDLY_SET_TX => B"00",
      TEMPERATUR_PAR => B"0010",
      TERM_RCAL_CFG => B"100001000010000",
      TERM_RCAL_OVRD => B"000",
      TRANS_TIME_RATE => X"0E",
      TST_RSV0 => X"00",
      TST_RSV1 => X"00",
      TXBUF_EN => "TRUE",
      TXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      TXDLY_CFG => X"0009",
      TXDLY_LCFG => X"0050",
      TXDRVBIAS_N => B"1010",
      TXDRVBIAS_P => B"1010",
      TXFIFO_ADDR_CFG => "LOW",
      TXGBOX_FIFO_INIT_RD_ADDR => 4,
      TXGEARBOX_EN => "FALSE",
      TXOUT_DIV => 2,
      TXPCSRESET_TIME => B"00011",
      TXPHDLY_CFG0 => X"2020",
      TXPHDLY_CFG1 => X"00D5",
      TXPH_CFG => X"0980",
      TXPH_MONITOR_SEL => B"00000",
      TXPI_CFG0 => B"00",
      TXPI_CFG1 => B"00",
      TXPI_CFG2 => B"00",
      TXPI_CFG3 => '0',
      TXPI_CFG4 => '0',
      TXPI_CFG5 => B"000",
      TXPI_GRAY_SEL => '0',
      TXPI_INVSTROBE_SEL => '0',
      TXPI_LPM => '0',
      TXPI_PPMCLK_SEL => "TXUSRCLK2",
      TXPI_PPM_CFG => B"00000000",
      TXPI_SYNFREQ_PPM => B"001",
      TXPI_VREFSEL => '0',
      TXPMARESET_TIME => B"00011",
      TXSYNC_MULTILANE => '1',
      TXSYNC_OVRD => '0',
      TXSYNC_SKIP_DA => '0',
      TX_CLK25_DIV => 15,
      TX_CLKMUX_EN => '1',
      TX_DATA_WIDTH => 40,
      TX_DCD_CFG => B"000010",
      TX_DCD_EN => '0',
      TX_DEEMPH0 => B"000000",
      TX_DEEMPH1 => B"000000",
      TX_DIVRESET_TIME => B"00001",
      TX_DRIVE_MODE => "DIRECT",
      TX_EIDLE_ASSERT_DELAY => B"100",
      TX_EIDLE_DEASSERT_DELAY => B"011",
      TX_EML_PHI_TUNE => '0',
      TX_FABINT_USRCLK_FLOP => '0',
      TX_IDLE_DATA_ZERO => '0',
      TX_INT_DATAWIDTH => 1,
      TX_LOOPBACK_DRIVE_HIZ => "FALSE",
      TX_MAINCURSOR_SEL => '0',
      TX_MARGIN_FULL_0 => B"1001111",
      TX_MARGIN_FULL_1 => B"1001110",
      TX_MARGIN_FULL_2 => B"1001100",
      TX_MARGIN_FULL_3 => B"1001010",
      TX_MARGIN_FULL_4 => B"1001000",
      TX_MARGIN_LOW_0 => B"1000110",
      TX_MARGIN_LOW_1 => B"1000101",
      TX_MARGIN_LOW_2 => B"1000011",
      TX_MARGIN_LOW_3 => B"1000010",
      TX_MARGIN_LOW_4 => B"1000000",
      TX_MODE_SEL => B"000",
      TX_PMADATA_OPT => '0',
      TX_PMA_POWER_SAVE => '0',
      TX_PROGCLK_SEL => "PREPI",
      TX_PROGDIV_CFG => 40.000000,
      TX_QPI_STATUS_EN => '0',
      TX_RXDETECT_CFG => B"00" & X"032",
      TX_RXDETECT_REF => B"100",
      TX_SAMPLE_PERIOD => B"111",
      TX_SARC_LPBK_ENB => '0',
      TX_XCLK_SEL => "TXOUT",
      USE_PCS_CLK_PHASE_SEL => '0',
      WB_MODE => B"00"
    )
    port map (
      BUFGTCE(2 downto 0) => bufgtce_out(2 downto 0),
      BUFGTCEMASK(2 downto 0) => bufgtcemask_out(2 downto 0),
      BUFGTDIV(8 downto 0) => bufgtdiv_out(8 downto 0),
      BUFGTRESET(2 downto 0) => bufgtreset_out(2 downto 0),
      BUFGTRSTMASK(2 downto 0) => bufgtrstmask_out(2 downto 0),
      CFGRESET => cfgreset_in(0),
      CLKRSVD0 => clkrsvd0_in(0),
      CLKRSVD1 => clkrsvd1_in(0),
      CPLLFBCLKLOST => cpllfbclklost_out(0),
      CPLLLOCK => cplllock_out(0),
      CPLLLOCKDETCLK => cplllockdetclk_in(0),
      CPLLLOCKEN => cplllocken_in(0),
      CPLLPD => cpllpd_in(0),
      CPLLREFCLKLOST => cpllrefclklost_out(0),
      CPLLREFCLKSEL(2 downto 0) => cpllrefclksel_in(2 downto 0),
      CPLLRESET => cpllreset_in(0),
      DMONFIFORESET => dmonfiforeset_in(0),
      DMONITORCLK => dmonitorclk_in(0),
      DMONITOROUT(16 downto 0) => dmonitorout_out(16 downto 0),
      DRPADDR(8 downto 0) => drpaddr_in(8 downto 0),
      DRPCLK => drpclk_in(0),
      DRPDI(15 downto 0) => drpdi_in(15 downto 0),
      DRPDO(15 downto 0) => drpdo_out(15 downto 0),
      DRPEN => drpen_in(0),
      DRPRDY => drprdy_out(0),
      DRPWE => drpwe_in(0),
      EVODDPHICALDONE => evoddphicaldone_in(0),
      EVODDPHICALSTART => evoddphicalstart_in(0),
      EVODDPHIDRDEN => evoddphidrden_in(0),
      EVODDPHIDWREN => evoddphidwren_in(0),
      EVODDPHIXRDEN => evoddphixrden_in(0),
      EVODDPHIXWREN => evoddphixwren_in(0),
      EYESCANDATAERROR => eyescandataerror_out(0),
      EYESCANMODE => eyescanmode_in(0),
      EYESCANRESET => eyescanreset_in(0),
      EYESCANTRIGGER => eyescantrigger_in(0),
      GTGREFCLK => gtgrefclk_in(0),
      GTHRXN => gthrxn_in(0),
      GTHRXP => gthrxp_in(0),
      GTHTXN => gthtxn_out(0),
      GTHTXP => gthtxp_out(0),
      GTNORTHREFCLK0 => gtnorthrefclk0_in(0),
      GTNORTHREFCLK1 => gtnorthrefclk1_in(0),
      GTPOWERGOOD => \^gtpowergood_out\(0),
      GTREFCLK0 => gtrefclk0_in(0),
      GTREFCLK1 => gtrefclk1_in(0),
      GTREFCLKMONITOR => gtrefclkmonitor_out(0),
      GTRESETSEL => gtresetsel_in(0),
      GTRSVD(15 downto 0) => gtrsvd_in(15 downto 0),
      GTRXRESET => GTHE3_CHANNEL_GTRXRESET(0),
      GTSOUTHREFCLK0 => gtsouthrefclk0_in(0),
      GTSOUTHREFCLK1 => gtsouthrefclk1_in(0),
      GTTXRESET => GTHE3_CHANNEL_GTTXRESET(0),
      LOOPBACK(2 downto 0) => loopback_in(2 downto 0),
      LPBKRXTXSEREN => lpbkrxtxseren_in(0),
      LPBKTXRXSEREN => lpbktxrxseren_in(0),
      PCIEEQRXEQADAPTDONE => pcieeqrxeqadaptdone_in(0),
      PCIERATEGEN3 => pcierategen3_out(0),
      PCIERATEIDLE => pcierateidle_out(0),
      PCIERATEQPLLPD(1 downto 0) => pcierateqpllpd_out(1 downto 0),
      PCIERATEQPLLRESET(1 downto 0) => pcierateqpllreset_out(1 downto 0),
      PCIERSTIDLE => pcierstidle_in(0),
      PCIERSTTXSYNCSTART => pciersttxsyncstart_in(0),
      PCIESYNCTXSYNCDONE => pciesynctxsyncdone_out(0),
      PCIEUSERGEN3RDY => pcieusergen3rdy_out(0),
      PCIEUSERPHYSTATUSRST => pcieuserphystatusrst_out(0),
      PCIEUSERRATEDONE => pcieuserratedone_in(0),
      PCIEUSERRATESTART => pcieuserratestart_out(0),
      PCSRSVDIN(15 downto 0) => pcsrsvdin_in(15 downto 0),
      PCSRSVDIN2(4 downto 0) => pcsrsvdin2_in(4 downto 0),
      PCSRSVDOUT(11 downto 0) => pcsrsvdout_out(11 downto 0),
      PHYSTATUS => phystatus_out(0),
      PINRSRVDAS(7 downto 0) => pinrsrvdas_out(7 downto 0),
      PMARSVDIN(4 downto 0) => pmarsvdin_in(4 downto 0),
      QPLL0CLK => qpll0outclk_out(0),
      QPLL0REFCLK => qpll0outrefclk_out(0),
      QPLL1CLK => qpll1outclk_out(0),
      QPLL1REFCLK => qpll1outrefclk_out(0),
      RESETEXCEPTION => resetexception_out(0),
      RESETOVRD => resetovrd_in(0),
      RSTCLKENTX => rstclkentx_in(0),
      RX8B10BEN => rx8b10ben_in(0),
      RXBUFRESET => rxbufreset_in(0),
      RXBUFSTATUS(2 downto 0) => rxbufstatus_out(2 downto 0),
      RXBYTEISALIGNED => rxbyteisaligned_out(0),
      RXBYTEREALIGN => rxbyterealign_out(0),
      RXCDRFREQRESET => rxcdrfreqreset_in(0),
      RXCDRHOLD => rxcdrhold_in(0),
      RXCDRLOCK => \^rxcdrlock_out\(0),
      RXCDROVRDEN => rxcdrovrden_in(0),
      RXCDRPHDONE => rxcdrphdone_out(0),
      RXCDRRESET => rxcdrreset_in(0),
      RXCDRRESETRSV => rxcdrresetrsv_in(0),
      RXCHANBONDSEQ => rxchanbondseq_out(0),
      RXCHANISALIGNED => rxchanisaligned_out(0),
      RXCHANREALIGN => rxchanrealign_out(0),
      RXCHBONDEN => rxchbonden_in(0),
      RXCHBONDI(4 downto 0) => rxchbondi_in(4 downto 0),
      RXCHBONDLEVEL(2 downto 0) => rxchbondlevel_in(2 downto 0),
      RXCHBONDMASTER => rxchbondmaster_in(0),
      RXCHBONDO(4 downto 0) => rxchbondo_out(4 downto 0),
      RXCHBONDSLAVE => rxchbondslave_in(0),
      RXCLKCORCNT(1 downto 0) => rxclkcorcnt_out(1 downto 0),
      RXCOMINITDET => rxcominitdet_out(0),
      RXCOMMADET => rxcommadet_out(0),
      RXCOMMADETEN => rxcommadeten_in(0),
      RXCOMSASDET => rxcomsasdet_out(0),
      RXCOMWAKEDET => rxcomwakedet_out(0),
      RXCTRL0(15 downto 0) => rxctrl0_out(15 downto 0),
      RXCTRL1(15 downto 0) => rxctrl1_out(15 downto 0),
      RXCTRL2(7 downto 0) => rxctrl2_out(7 downto 0),
      RXCTRL3(7 downto 0) => rxctrl3_out(7 downto 0),
      RXDATA(127 downto 0) => rxdata_out(127 downto 0),
      RXDATAEXTENDRSVD(7 downto 0) => rxdataextendrsvd_out(7 downto 0),
      RXDATAVALID(1 downto 0) => rxdatavalid_out(1 downto 0),
      RXDFEAGCCTRL(1 downto 0) => rxdfeagcctrl_in(1 downto 0),
      RXDFEAGCHOLD => rxdfeagchold_in(0),
      RXDFEAGCOVRDEN => rxdfeagcovrden_in(0),
      RXDFELFHOLD => rxdfelfhold_in(0),
      RXDFELFOVRDEN => rxdfelfovrden_in(0),
      RXDFELPMRESET => rxdfelpmreset_in(0),
      RXDFETAP10HOLD => rxdfetap10hold_in(0),
      RXDFETAP10OVRDEN => rxdfetap10ovrden_in(0),
      RXDFETAP11HOLD => rxdfetap11hold_in(0),
      RXDFETAP11OVRDEN => rxdfetap11ovrden_in(0),
      RXDFETAP12HOLD => rxdfetap12hold_in(0),
      RXDFETAP12OVRDEN => rxdfetap12ovrden_in(0),
      RXDFETAP13HOLD => rxdfetap13hold_in(0),
      RXDFETAP13OVRDEN => rxdfetap13ovrden_in(0),
      RXDFETAP14HOLD => rxdfetap14hold_in(0),
      RXDFETAP14OVRDEN => rxdfetap14ovrden_in(0),
      RXDFETAP15HOLD => rxdfetap15hold_in(0),
      RXDFETAP15OVRDEN => rxdfetap15ovrden_in(0),
      RXDFETAP2HOLD => rxdfetap2hold_in(0),
      RXDFETAP2OVRDEN => rxdfetap2ovrden_in(0),
      RXDFETAP3HOLD => rxdfetap3hold_in(0),
      RXDFETAP3OVRDEN => rxdfetap3ovrden_in(0),
      RXDFETAP4HOLD => rxdfetap4hold_in(0),
      RXDFETAP4OVRDEN => rxdfetap4ovrden_in(0),
      RXDFETAP5HOLD => rxdfetap5hold_in(0),
      RXDFETAP5OVRDEN => rxdfetap5ovrden_in(0),
      RXDFETAP6HOLD => rxdfetap6hold_in(0),
      RXDFETAP6OVRDEN => rxdfetap6ovrden_in(0),
      RXDFETAP7HOLD => rxdfetap7hold_in(0),
      RXDFETAP7OVRDEN => rxdfetap7ovrden_in(0),
      RXDFETAP8HOLD => rxdfetap8hold_in(0),
      RXDFETAP8OVRDEN => rxdfetap8ovrden_in(0),
      RXDFETAP9HOLD => rxdfetap9hold_in(0),
      RXDFETAP9OVRDEN => rxdfetap9ovrden_in(0),
      RXDFEUTHOLD => rxdfeuthold_in(0),
      RXDFEUTOVRDEN => rxdfeutovrden_in(0),
      RXDFEVPHOLD => rxdfevphold_in(0),
      RXDFEVPOVRDEN => rxdfevpovrden_in(0),
      RXDFEVSEN => rxdfevsen_in(0),
      RXDFEXYDEN => rxdfexyden_in(0),
      RXDLYBYPASS => rxdlybypass_in(0),
      RXDLYEN => rxdlyen_in(0),
      RXDLYOVRDEN => rxdlyovrden_in(0),
      RXDLYSRESET => rxdlysreset_in(0),
      RXDLYSRESETDONE => rxdlysresetdone_out(0),
      RXELECIDLE => rxelecidle_out(0),
      RXELECIDLEMODE(1 downto 0) => rxelecidlemode_in(1 downto 0),
      RXGEARBOXSLIP => rxgearboxslip_in(0),
      RXHEADER(5 downto 0) => rxheader_out(5 downto 0),
      RXHEADERVALID(1 downto 0) => rxheadervalid_out(1 downto 0),
      RXLATCLK => rxlatclk_in(0),
      RXLPMEN => rxlpmen_in(0),
      RXLPMGCHOLD => rxlpmgchold_in(0),
      RXLPMGCOVRDEN => rxlpmgcovrden_in(0),
      RXLPMHFHOLD => rxlpmhfhold_in(0),
      RXLPMHFOVRDEN => rxlpmhfovrden_in(0),
      RXLPMLFHOLD => rxlpmlfhold_in(0),
      RXLPMLFKLOVRDEN => rxlpmlfklovrden_in(0),
      RXLPMOSHOLD => rxlpmoshold_in(0),
      RXLPMOSOVRDEN => rxlpmosovrden_in(0),
      RXMCOMMAALIGNEN => rxmcommaalignen_in(0),
      RXMONITOROUT(6 downto 0) => rxmonitorout_out(6 downto 0),
      RXMONITORSEL(1 downto 0) => rxmonitorsel_in(1 downto 0),
      RXOOBRESET => rxoobreset_in(0),
      RXOSCALRESET => rxoscalreset_in(0),
      RXOSHOLD => rxoshold_in(0),
      RXOSINTCFG(3 downto 0) => rxosintcfg_in(3 downto 0),
      RXOSINTDONE => rxosintdone_out(0),
      RXOSINTEN => rxosinten_in(0),
      RXOSINTHOLD => rxosinthold_in(0),
      RXOSINTOVRDEN => rxosintovrden_in(0),
      RXOSINTSTARTED => rxosintstarted_out(0),
      RXOSINTSTROBE => rxosintstrobe_in(0),
      RXOSINTSTROBEDONE => rxosintstrobedone_out(0),
      RXOSINTSTROBESTARTED => rxosintstrobestarted_out(0),
      RXOSINTTESTOVRDEN => rxosinttestovrden_in(0),
      RXOSOVRDEN => rxosovrden_in(0),
      RXOUTCLK => rxoutclk_out(0),
      RXOUTCLKFABRIC => rxoutclkfabric_out(0),
      RXOUTCLKPCS => rxoutclkpcs_out(0),
      RXOUTCLKSEL(2 downto 0) => rxoutclksel_in(2 downto 0),
      RXPCOMMAALIGNEN => rxpcommaalignen_in(0),
      RXPCSRESET => rxpcsreset_in(0),
      RXPD(1 downto 0) => rxpd_in(1 downto 0),
      RXPHALIGN => rxphalign_in(0),
      RXPHALIGNDONE => rxphaligndone_out(0),
      RXPHALIGNEN => rxphalignen_in(0),
      RXPHALIGNERR => rxphalignerr_out(0),
      RXPHDLYPD => rxphdlypd_in(0),
      RXPHDLYRESET => rxphdlyreset_in(0),
      RXPHOVRDEN => rxphovrden_in(0),
      RXPLLCLKSEL(1 downto 0) => rxpllclksel_in(1 downto 0),
      RXPMARESET => rxpmareset_in(0),
      RXPMARESETDONE => rxpmaresetdone_out(0),
      RXPOLARITY => rxpolarity_in(0),
      RXPRBSCNTRESET => rxprbscntreset_in(0),
      RXPRBSERR => rxprbserr_out(0),
      RXPRBSLOCKED => rxprbslocked_out(0),
      RXPRBSSEL(3 downto 0) => rxprbssel_in(3 downto 0),
      RXPRGDIVRESETDONE => rxprgdivresetdone_out(0),
      RXPROGDIVRESET => GTHE3_CHANNEL_RXPROGDIVRESET(0),
      RXQPIEN => rxqpien_in(0),
      RXQPISENN => rxqpisenn_out(0),
      RXQPISENP => rxqpisenp_out(0),
      RXRATE(2 downto 0) => rxrate_in(2 downto 0),
      RXRATEDONE => rxratedone_out(0),
      RXRATEMODE => rxratemode_in(0),
      RXRECCLKOUT => rxrecclkout_out(0),
      RXRESETDONE => \^rxresetdone_out\(0),
      RXSLIDE => rxslide_in(0),
      RXSLIDERDY => rxsliderdy_out(0),
      RXSLIPDONE => rxslipdone_out(0),
      RXSLIPOUTCLK => rxslipoutclk_in(0),
      RXSLIPOUTCLKRDY => rxslipoutclkrdy_out(0),
      RXSLIPPMA => rxslippma_in(0),
      RXSLIPPMARDY => rxslippmardy_out(0),
      RXSTARTOFSEQ(1 downto 0) => rxstartofseq_out(1 downto 0),
      RXSTATUS(2 downto 0) => rxstatus_out(2 downto 0),
      RXSYNCALLIN => rxsyncallin_in(0),
      RXSYNCDONE => rxsyncdone_out(0),
      RXSYNCIN => rxsyncin_in(0),
      RXSYNCMODE => rxsyncmode_in(0),
      RXSYNCOUT => rxsyncout_out(0),
      RXSYSCLKSEL(1 downto 0) => rxsysclksel_in(1 downto 0),
      RXUSERRDY => GTHE3_CHANNEL_RXUSERRDY(0),
      RXUSRCLK => rxusrclk_in(0),
      RXUSRCLK2 => rxusrclk2_in(0),
      RXVALID => rxvalid_out(0),
      SIGVALIDCLK => sigvalidclk_in(0),
      TSTIN(19) => '0',
      TSTIN(18) => '0',
      TSTIN(17) => '0',
      TSTIN(16) => '0',
      TSTIN(15) => '0',
      TSTIN(14) => '0',
      TSTIN(13) => '0',
      TSTIN(12) => '0',
      TSTIN(11) => '0',
      TSTIN(10) => '0',
      TSTIN(9) => '0',
      TSTIN(8) => '0',
      TSTIN(7) => '0',
      TSTIN(6) => '0',
      TSTIN(5) => '0',
      TSTIN(4) => '0',
      TSTIN(3) => '0',
      TSTIN(2) => '0',
      TSTIN(1) => '0',
      TSTIN(0) => '0',
      TX8B10BBYPASS(7 downto 0) => tx8b10bbypass_in(7 downto 0),
      TX8B10BEN => tx8b10ben_in(0),
      TXBUFDIFFCTRL(2 downto 0) => txbufdiffctrl_in(2 downto 0),
      TXBUFSTATUS(1 downto 0) => txbufstatus_out(1 downto 0),
      TXCOMFINISH => txcomfinish_out(0),
      TXCOMINIT => txcominit_in(0),
      TXCOMSAS => txcomsas_in(0),
      TXCOMWAKE => txcomwake_in(0),
      TXCTRL0(15 downto 0) => txctrl0_in(15 downto 0),
      TXCTRL1(15 downto 0) => txctrl1_in(15 downto 0),
      TXCTRL2(7 downto 0) => txctrl2_in(7 downto 0),
      TXDATA(127) => '0',
      TXDATA(126) => '0',
      TXDATA(125) => '0',
      TXDATA(124) => '0',
      TXDATA(123) => '0',
      TXDATA(122) => '0',
      TXDATA(121) => '0',
      TXDATA(120) => '0',
      TXDATA(119) => '0',
      TXDATA(118) => '0',
      TXDATA(117) => '0',
      TXDATA(116) => '0',
      TXDATA(115) => '0',
      TXDATA(114) => '0',
      TXDATA(113) => '0',
      TXDATA(112) => '0',
      TXDATA(111) => '0',
      TXDATA(110) => '0',
      TXDATA(109) => '0',
      TXDATA(108) => '0',
      TXDATA(107) => '0',
      TXDATA(106) => '0',
      TXDATA(105) => '0',
      TXDATA(104) => '0',
      TXDATA(103) => '0',
      TXDATA(102) => '0',
      TXDATA(101) => '0',
      TXDATA(100) => '0',
      TXDATA(99) => '0',
      TXDATA(98) => '0',
      TXDATA(97) => '0',
      TXDATA(96) => '0',
      TXDATA(95) => '0',
      TXDATA(94) => '0',
      TXDATA(93) => '0',
      TXDATA(92) => '0',
      TXDATA(91) => '0',
      TXDATA(90) => '0',
      TXDATA(89) => '0',
      TXDATA(88) => '0',
      TXDATA(87) => '0',
      TXDATA(86) => '0',
      TXDATA(85) => '0',
      TXDATA(84) => '0',
      TXDATA(83) => '0',
      TXDATA(82) => '0',
      TXDATA(81) => '0',
      TXDATA(80) => '0',
      TXDATA(79) => '0',
      TXDATA(78) => '0',
      TXDATA(77) => '0',
      TXDATA(76) => '0',
      TXDATA(75) => '0',
      TXDATA(74) => '0',
      TXDATA(73) => '0',
      TXDATA(72) => '0',
      TXDATA(71) => '0',
      TXDATA(70) => '0',
      TXDATA(69) => '0',
      TXDATA(68) => '0',
      TXDATA(67) => '0',
      TXDATA(66) => '0',
      TXDATA(65) => '0',
      TXDATA(64) => '0',
      TXDATA(63) => '0',
      TXDATA(62) => '0',
      TXDATA(61) => '0',
      TXDATA(60) => '0',
      TXDATA(59) => '0',
      TXDATA(58) => '0',
      TXDATA(57) => '0',
      TXDATA(56) => '0',
      TXDATA(55) => '0',
      TXDATA(54) => '0',
      TXDATA(53) => '0',
      TXDATA(52) => '0',
      TXDATA(51) => '0',
      TXDATA(50) => '0',
      TXDATA(49) => '0',
      TXDATA(48) => '0',
      TXDATA(47) => '0',
      TXDATA(46) => '0',
      TXDATA(45) => '0',
      TXDATA(44) => '0',
      TXDATA(43) => '0',
      TXDATA(42) => '0',
      TXDATA(41) => '0',
      TXDATA(40) => '0',
      TXDATA(39) => '0',
      TXDATA(38) => '0',
      TXDATA(37) => '0',
      TXDATA(36) => '0',
      TXDATA(35) => '0',
      TXDATA(34) => '0',
      TXDATA(33) => '0',
      TXDATA(32) => '0',
      TXDATA(31 downto 0) => gtwiz_userdata_tx_in(31 downto 0),
      TXDATAEXTENDRSVD(7 downto 0) => txdataextendrsvd_in(7 downto 0),
      TXDEEMPH => txdeemph_in(0),
      TXDETECTRX => txdetectrx_in(0),
      TXDIFFCTRL(3 downto 0) => txdiffctrl_in(3 downto 0),
      TXDIFFPD => txdiffpd_in(0),
      TXDLYBYPASS => txdlybypass_in(0),
      TXDLYEN => txdlyen_in(0),
      TXDLYHOLD => txdlyhold_in(0),
      TXDLYOVRDEN => txdlyovrden_in(0),
      TXDLYSRESET => txdlysreset_in(0),
      TXDLYSRESETDONE => txdlysresetdone_out(0),
      TXDLYUPDOWN => txdlyupdown_in(0),
      TXELECIDLE => txelecidle_in(0),
      TXHEADER(5 downto 0) => txheader_in(5 downto 0),
      TXINHIBIT => txinhibit_in(0),
      TXLATCLK => txlatclk_in(0),
      TXMAINCURSOR(6 downto 0) => txmaincursor_in(6 downto 0),
      TXMARGIN(2 downto 0) => txmargin_in(2 downto 0),
      TXOUTCLK => txoutclk_out(0),
      TXOUTCLKFABRIC => txoutclkfabric_out(0),
      TXOUTCLKPCS => txoutclkpcs_out(0),
      TXOUTCLKSEL(2 downto 0) => txoutclksel_in(2 downto 0),
      TXPCSRESET => txpcsreset_in(0),
      TXPD(1 downto 0) => txpd_in(1 downto 0),
      TXPDELECIDLEMODE => txpdelecidlemode_in(0),
      TXPHALIGN => txphalign_in(0),
      TXPHALIGNDONE => txphaligndone_out(0),
      TXPHALIGNEN => txphalignen_in(0),
      TXPHDLYPD => txphdlypd_in(0),
      TXPHDLYRESET => txphdlyreset_in(0),
      TXPHDLYTSTCLK => txphdlytstclk_in(0),
      TXPHINIT => txphinit_in(0),
      TXPHINITDONE => txphinitdone_out(0),
      TXPHOVRDEN => txphovrden_in(0),
      TXPIPPMEN => txpippmen_in(0),
      TXPIPPMOVRDEN => txpippmovrden_in(0),
      TXPIPPMPD => txpippmpd_in(0),
      TXPIPPMSEL => txpippmsel_in(0),
      TXPIPPMSTEPSIZE(4 downto 0) => txpippmstepsize_in(4 downto 0),
      TXPISOPD => txpisopd_in(0),
      TXPLLCLKSEL(1 downto 0) => txpllclksel_in(1 downto 0),
      TXPMARESET => txpmareset_in(0),
      TXPMARESETDONE => txpmaresetdone_out(0),
      TXPOLARITY => txpolarity_in(0),
      TXPOSTCURSOR(4 downto 0) => txpostcursor_in(4 downto 0),
      TXPOSTCURSORINV => txpostcursorinv_in(0),
      TXPRBSFORCEERR => txprbsforceerr_in(0),
      TXPRBSSEL(3 downto 0) => txprbssel_in(3 downto 0),
      TXPRECURSOR(4 downto 0) => txprecursor_in(4 downto 0),
      TXPRECURSORINV => txprecursorinv_in(0),
      TXPRGDIVRESETDONE => txprgdivresetdone_out(0),
      TXPROGDIVRESET => GTHE3_CHANNEL_TXPROGDIVRESET(0),
      TXQPIBIASEN => txqpibiasen_in(0),
      TXQPISENN => txqpisenn_out(0),
      TXQPISENP => txqpisenp_out(0),
      TXQPISTRONGPDOWN => txqpistrongpdown_in(0),
      TXQPIWEAKPUP => txqpiweakpup_in(0),
      TXRATE(2 downto 0) => txrate_in(2 downto 0),
      TXRATEDONE => txratedone_out(0),
      TXRATEMODE => txratemode_in(0),
      TXRESETDONE => \^txresetdone_out\(0),
      TXSEQUENCE(6 downto 0) => txsequence_in(6 downto 0),
      TXSWING => txswing_in(0),
      TXSYNCALLIN => txsyncallin_in(0),
      TXSYNCDONE => txsyncdone_out(0),
      TXSYNCIN => txsyncin_in(0),
      TXSYNCMODE => txsyncmode_in(0),
      TXSYNCOUT => txsyncout_out(0),
      TXSYSCLKSEL(1 downto 0) => txsysclksel_in(1 downto 0),
      TXUSERRDY => GTHE3_CHANNEL_TXUSERRDY(0),
      TXUSRCLK => txusrclk_in(0),
      TXUSRCLK2 => txusrclk2_in(0)
    );
\gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST\: unisim.vcomponents.GTHE3_CHANNEL
    generic map(
      ACJTAG_DEBUG_MODE => '0',
      ACJTAG_MODE => '0',
      ACJTAG_RESET => '0',
      ADAPT_CFG0 => X"F800",
      ADAPT_CFG1 => X"0000",
      ALIGN_COMMA_DOUBLE => "FALSE",
      ALIGN_COMMA_ENABLE => B"1111111111",
      ALIGN_COMMA_WORD => 1,
      ALIGN_MCOMMA_DET => "TRUE",
      ALIGN_MCOMMA_VALUE => B"1010000011",
      ALIGN_PCOMMA_DET => "TRUE",
      ALIGN_PCOMMA_VALUE => B"0101111100",
      A_RXOSCALRESET => '0',
      A_RXPROGDIVRESET => '0',
      A_TXPROGDIVRESET => '0',
      CBCC_DATA_SOURCE_SEL => "DECODED",
      CDR_SWAP_MODE_EN => '0',
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
      CLK_CORRECT_USE => "FALSE",
      CLK_COR_KEEP_IDLE => "FALSE",
      CLK_COR_MAX_LAT => 12,
      CLK_COR_MIN_LAT => 8,
      CLK_COR_PRECEDENCE => "TRUE",
      CLK_COR_REPEAT_WAIT => 0,
      CLK_COR_SEQ_1_1 => B"0100000000",
      CLK_COR_SEQ_1_2 => B"0100000000",
      CLK_COR_SEQ_1_3 => B"0100000000",
      CLK_COR_SEQ_1_4 => B"0100000000",
      CLK_COR_SEQ_1_ENABLE => B"1111",
      CLK_COR_SEQ_2_1 => B"0100000000",
      CLK_COR_SEQ_2_2 => B"0100000000",
      CLK_COR_SEQ_2_3 => B"0100000000",
      CLK_COR_SEQ_2_4 => B"0100000000",
      CLK_COR_SEQ_2_ENABLE => B"1111",
      CLK_COR_SEQ_2_USE => "FALSE",
      CLK_COR_SEQ_LEN => 1,
      CPLL_CFG0 => X"67FA",
      CPLL_CFG1 => X"A494",
      CPLL_CFG2 => X"F007",
      CPLL_CFG3 => B"00" & X"0",
      CPLL_FBDIV => 2,
      CPLL_FBDIV_45 => 5,
      CPLL_INIT_CFG0 => X"001E",
      CPLL_INIT_CFG1 => X"00",
      CPLL_LOCK_CFG => X"01E8",
      CPLL_REFCLK_DIV => 1,
      DDI_CTRL => B"00",
      DDI_REALIGN_WAIT => 15,
      DEC_MCOMMA_DETECT => "TRUE",
      DEC_PCOMMA_DETECT => "TRUE",
      DEC_VALID_COMMA_ONLY => "FALSE",
      DFE_D_X_REL_POS => '0',
      DFE_VCM_COMP_EN => '0',
      DMONITOR_CFG0 => B"00" & X"00",
      DMONITOR_CFG1 => X"00",
      ES_CLK_PHASE_SEL => '0',
      ES_CONTROL => B"000000",
      ES_ERRDET_EN => "FALSE",
      ES_EYE_SCAN_EN => "FALSE",
      ES_HORZ_OFFSET => X"000",
      ES_PMA_CFG => B"0000000000",
      ES_PRESCALE => B"00000",
      ES_QUALIFIER0 => X"0000",
      ES_QUALIFIER1 => X"0000",
      ES_QUALIFIER2 => X"0000",
      ES_QUALIFIER3 => X"0000",
      ES_QUALIFIER4 => X"0000",
      ES_QUAL_MASK0 => X"0000",
      ES_QUAL_MASK1 => X"0000",
      ES_QUAL_MASK2 => X"0000",
      ES_QUAL_MASK3 => X"0000",
      ES_QUAL_MASK4 => X"0000",
      ES_SDATA_MASK0 => X"0000",
      ES_SDATA_MASK1 => X"0000",
      ES_SDATA_MASK2 => X"0000",
      ES_SDATA_MASK3 => X"0000",
      ES_SDATA_MASK4 => X"0000",
      EVODD_PHI_CFG => B"00000000000",
      EYE_SCAN_SWAP_EN => '0',
      FTS_DESKEW_SEQ_ENABLE => B"1111",
      FTS_LANE_DESKEW_CFG => B"1111",
      FTS_LANE_DESKEW_EN => "FALSE",
      GEARBOX_MODE => B"00000",
      GM_BIAS_SELECT => '0',
      LOCAL_MASTER => '1',
      OOBDIVCTL => B"00",
      OOB_PWRUP => '0',
      PCI3_AUTO_REALIGN => "OVR_1K_BLK",
      PCI3_PIPE_RX_ELECIDLE => '0',
      PCI3_RX_ASYNC_EBUF_BYPASS => B"00",
      PCI3_RX_ELECIDLE_EI2_ENABLE => '0',
      PCI3_RX_ELECIDLE_H2L_COUNT => B"000000",
      PCI3_RX_ELECIDLE_H2L_DISABLE => B"000",
      PCI3_RX_ELECIDLE_HI_COUNT => B"000000",
      PCI3_RX_ELECIDLE_LP4_DISABLE => '0',
      PCI3_RX_FIFO_DISABLE => '0',
      PCIE_BUFG_DIV_CTRL => X"1000",
      PCIE_RXPCS_CFG_GEN3 => X"02A4",
      PCIE_RXPMA_CFG => X"000A",
      PCIE_TXPCS_CFG_GEN3 => X"24A0",
      PCIE_TXPMA_CFG => X"000A",
      PCS_PCIE_EN => "FALSE",
      PCS_RSVD0 => B"0000000000000000",
      PCS_RSVD1 => B"000",
      PD_TRANS_TIME_FROM_P2 => X"03C",
      PD_TRANS_TIME_NONE_P2 => X"19",
      PD_TRANS_TIME_TO_P2 => X"64",
      PLL_SEL_MODE_GEN12 => B"00",
      PLL_SEL_MODE_GEN3 => B"11",
      PMA_RSV1 => X"1800",
      PROCESS_PAR => B"010",
      RATE_SW_USE_DRP => '0',
      RESET_POWERSAVE_DISABLE => '0',
      RXBUFRESET_TIME => B"00011",
      RXBUF_ADDR_MODE => "FAST",
      RXBUF_EIDLE_HI_CNT => B"1000",
      RXBUF_EIDLE_LO_CNT => B"0000",
      RXBUF_EN => "TRUE",
      RXBUF_RESET_ON_CB_CHANGE => "TRUE",
      RXBUF_RESET_ON_COMMAALIGN => "FALSE",
      RXBUF_RESET_ON_EIDLE => "FALSE",
      RXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      RXBUF_THRESH_OVFLW => 57,
      RXBUF_THRESH_OVRD => "TRUE",
      RXBUF_THRESH_UNDFLW => 3,
      RXCDRFREQRESET_TIME => B"00001",
      RXCDRPHRESET_TIME => B"00001",
      RXCDR_CFG0 => X"0000",
      RXCDR_CFG0_GEN3 => X"0000",
      RXCDR_CFG1 => X"0000",
      RXCDR_CFG1_GEN3 => X"0000",
      RXCDR_CFG2 => X"0756",
      RXCDR_CFG2_GEN3 => X"0756",
      RXCDR_CFG3 => X"0000",
      RXCDR_CFG3_GEN3 => X"0000",
      RXCDR_CFG4 => X"0000",
      RXCDR_CFG4_GEN3 => X"0000",
      RXCDR_CFG5 => X"0000",
      RXCDR_CFG5_GEN3 => X"0000",
      RXCDR_FR_RESET_ON_EIDLE => '0',
      RXCDR_HOLD_DURING_EIDLE => '0',
      RXCDR_LOCK_CFG0 => X"4480",
      RXCDR_LOCK_CFG1 => X"5FFF",
      RXCDR_LOCK_CFG2 => X"77C3",
      RXCDR_PH_RESET_ON_EIDLE => '0',
      RXCFOK_CFG0 => X"4000",
      RXCFOK_CFG1 => X"0065",
      RXCFOK_CFG2 => X"002E",
      RXDFELPMRESET_TIME => B"0001111",
      RXDFELPM_KL_CFG0 => X"0000",
      RXDFELPM_KL_CFG1 => X"0002",
      RXDFELPM_KL_CFG2 => X"0000",
      RXDFE_CFG0 => X"0A00",
      RXDFE_CFG1 => X"0000",
      RXDFE_GC_CFG0 => X"0000",
      RXDFE_GC_CFG1 => X"7870",
      RXDFE_GC_CFG2 => X"0000",
      RXDFE_H2_CFG0 => X"0000",
      RXDFE_H2_CFG1 => X"0000",
      RXDFE_H3_CFG0 => X"4000",
      RXDFE_H3_CFG1 => X"0000",
      RXDFE_H4_CFG0 => X"2000",
      RXDFE_H4_CFG1 => X"0003",
      RXDFE_H5_CFG0 => X"2000",
      RXDFE_H5_CFG1 => X"0003",
      RXDFE_H6_CFG0 => X"2000",
      RXDFE_H6_CFG1 => X"0000",
      RXDFE_H7_CFG0 => X"2000",
      RXDFE_H7_CFG1 => X"0000",
      RXDFE_H8_CFG0 => X"2000",
      RXDFE_H8_CFG1 => X"0000",
      RXDFE_H9_CFG0 => X"2000",
      RXDFE_H9_CFG1 => X"0000",
      RXDFE_HA_CFG0 => X"2000",
      RXDFE_HA_CFG1 => X"0000",
      RXDFE_HB_CFG0 => X"2000",
      RXDFE_HB_CFG1 => X"0000",
      RXDFE_HC_CFG0 => X"0000",
      RXDFE_HC_CFG1 => X"0000",
      RXDFE_HD_CFG0 => X"0000",
      RXDFE_HD_CFG1 => X"0000",
      RXDFE_HE_CFG0 => X"0000",
      RXDFE_HE_CFG1 => X"0000",
      RXDFE_HF_CFG0 => X"0000",
      RXDFE_HF_CFG1 => X"0000",
      RXDFE_OS_CFG0 => X"8000",
      RXDFE_OS_CFG1 => X"0000",
      RXDFE_UT_CFG0 => X"8000",
      RXDFE_UT_CFG1 => X"0003",
      RXDFE_VP_CFG0 => X"AA00",
      RXDFE_VP_CFG1 => X"0033",
      RXDLY_CFG => X"001F",
      RXDLY_LCFG => X"0030",
      RXELECIDLE_CFG => "Sigcfg_4",
      RXGBOX_FIFO_INIT_RD_ADDR => 4,
      RXGEARBOX_EN => "FALSE",
      RXISCANRESET_TIME => B"00001",
      RXLPM_CFG => X"0000",
      RXLPM_GC_CFG => X"0000",
      RXLPM_KH_CFG0 => X"0000",
      RXLPM_KH_CFG1 => X"0002",
      RXLPM_OS_CFG0 => X"8000",
      RXLPM_OS_CFG1 => X"0002",
      RXOOB_CFG => B"000000110",
      RXOOB_CLK_CFG => "PMA",
      RXOSCALRESET_TIME => B"00011",
      RXOUT_DIV => 2,
      RXPCSRESET_TIME => B"00011",
      RXPHBEACON_CFG => X"0000",
      RXPHDLY_CFG => X"2020",
      RXPHSAMP_CFG => X"2100",
      RXPHSLIP_CFG => X"6622",
      RXPH_MONITOR_SEL => B"00000",
      RXPI_CFG0 => B"00",
      RXPI_CFG1 => B"00",
      RXPI_CFG2 => B"00",
      RXPI_CFG3 => B"00",
      RXPI_CFG4 => '0',
      RXPI_CFG5 => '0',
      RXPI_CFG6 => B"000",
      RXPI_LPM => '0',
      RXPI_VREFSEL => '0',
      RXPMACLK_SEL => "DATA",
      RXPMARESET_TIME => B"00011",
      RXPRBS_ERR_LOOPBACK => '0',
      RXPRBS_LINKACQ_CNT => 15,
      RXSLIDE_AUTO_WAIT => 7,
      RXSLIDE_MODE => "OFF",
      RXSYNC_MULTILANE => '1',
      RXSYNC_OVRD => '0',
      RXSYNC_SKIP_DA => '0',
      RX_AFE_CM_EN => '0',
      RX_BIAS_CFG0 => X"0AB4",
      RX_BUFFER_CFG => B"000000",
      RX_CAPFF_SARC_ENB => '0',
      RX_CLK25_DIV => 15,
      RX_CLKMUX_EN => '1',
      RX_CLK_SLIP_OVRD => B"00000",
      RX_CM_BUF_CFG => B"1010",
      RX_CM_BUF_PD => '0',
      RX_CM_SEL => B"11",
      RX_CM_TRIM => B"1010",
      RX_CTLE3_LPF => B"00000001",
      RX_DATA_WIDTH => 40,
      RX_DDI_SEL => B"000000",
      RX_DEFER_RESET_BUF_EN => "TRUE",
      RX_DFELPM_CFG0 => B"0110",
      RX_DFELPM_CFG1 => '1',
      RX_DFELPM_KLKH_AGC_STUP_EN => '1',
      RX_DFE_AGC_CFG0 => B"10",
      RX_DFE_AGC_CFG1 => B"100",
      RX_DFE_KL_LPM_KH_CFG0 => B"01",
      RX_DFE_KL_LPM_KH_CFG1 => B"100",
      RX_DFE_KL_LPM_KL_CFG0 => B"01",
      RX_DFE_KL_LPM_KL_CFG1 => B"100",
      RX_DFE_LPM_HOLD_DURING_EIDLE => '0',
      RX_DISPERR_SEQ_MATCH => "TRUE",
      RX_DIVRESET_TIME => B"00001",
      RX_EN_HI_LR => '0',
      RX_EYESCAN_VS_CODE => B"0000000",
      RX_EYESCAN_VS_NEG_DIR => '0',
      RX_EYESCAN_VS_RANGE => B"00",
      RX_EYESCAN_VS_UT_SIGN => '0',
      RX_FABINT_USRCLK_FLOP => '0',
      RX_INT_DATAWIDTH => 1,
      RX_PMA_POWER_SAVE => '0',
      RX_PROGDIV_CFG => 40.000000,
      RX_SAMPLE_PERIOD => B"111",
      RX_SIG_VALID_DLY => 11,
      RX_SUM_DFETAPREP_EN => '0',
      RX_SUM_IREF_TUNE => B"0000",
      RX_SUM_RES_CTRL => B"00",
      RX_SUM_VCMTUNE => B"0000",
      RX_SUM_VCM_OVWR => '0',
      RX_SUM_VREF_TUNE => B"000",
      RX_TUNE_AFE_OS => B"10",
      RX_WIDEMODE_CDR => '0',
      RX_XCLK_SEL => "RXDES",
      SAS_MAX_COM => 64,
      SAS_MIN_COM => 36,
      SATA_BURST_SEQ_LEN => B"1111",
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
      SIM_RECEIVER_DETECT_PASS => "TRUE",
      SIM_RESET_SPEEDUP => "TRUE",
      SIM_TX_EIDLE_DRIVE_LEVEL => '0',
      SIM_VERSION => 2,
      TAPDLY_SET_TX => B"00",
      TEMPERATUR_PAR => B"0010",
      TERM_RCAL_CFG => B"100001000010000",
      TERM_RCAL_OVRD => B"000",
      TRANS_TIME_RATE => X"0E",
      TST_RSV0 => X"00",
      TST_RSV1 => X"00",
      TXBUF_EN => "TRUE",
      TXBUF_RESET_ON_RATE_CHANGE => "TRUE",
      TXDLY_CFG => X"0009",
      TXDLY_LCFG => X"0050",
      TXDRVBIAS_N => B"1010",
      TXDRVBIAS_P => B"1010",
      TXFIFO_ADDR_CFG => "LOW",
      TXGBOX_FIFO_INIT_RD_ADDR => 4,
      TXGEARBOX_EN => "FALSE",
      TXOUT_DIV => 2,
      TXPCSRESET_TIME => B"00011",
      TXPHDLY_CFG0 => X"2020",
      TXPHDLY_CFG1 => X"00D5",
      TXPH_CFG => X"0980",
      TXPH_MONITOR_SEL => B"00000",
      TXPI_CFG0 => B"00",
      TXPI_CFG1 => B"00",
      TXPI_CFG2 => B"00",
      TXPI_CFG3 => '0',
      TXPI_CFG4 => '0',
      TXPI_CFG5 => B"000",
      TXPI_GRAY_SEL => '0',
      TXPI_INVSTROBE_SEL => '0',
      TXPI_LPM => '0',
      TXPI_PPMCLK_SEL => "TXUSRCLK2",
      TXPI_PPM_CFG => B"00000000",
      TXPI_SYNFREQ_PPM => B"001",
      TXPI_VREFSEL => '0',
      TXPMARESET_TIME => B"00011",
      TXSYNC_MULTILANE => '1',
      TXSYNC_OVRD => '0',
      TXSYNC_SKIP_DA => '0',
      TX_CLK25_DIV => 15,
      TX_CLKMUX_EN => '1',
      TX_DATA_WIDTH => 40,
      TX_DCD_CFG => B"000010",
      TX_DCD_EN => '0',
      TX_DEEMPH0 => B"000000",
      TX_DEEMPH1 => B"000000",
      TX_DIVRESET_TIME => B"00001",
      TX_DRIVE_MODE => "DIRECT",
      TX_EIDLE_ASSERT_DELAY => B"100",
      TX_EIDLE_DEASSERT_DELAY => B"011",
      TX_EML_PHI_TUNE => '0',
      TX_FABINT_USRCLK_FLOP => '0',
      TX_IDLE_DATA_ZERO => '0',
      TX_INT_DATAWIDTH => 1,
      TX_LOOPBACK_DRIVE_HIZ => "FALSE",
      TX_MAINCURSOR_SEL => '0',
      TX_MARGIN_FULL_0 => B"1001111",
      TX_MARGIN_FULL_1 => B"1001110",
      TX_MARGIN_FULL_2 => B"1001100",
      TX_MARGIN_FULL_3 => B"1001010",
      TX_MARGIN_FULL_4 => B"1001000",
      TX_MARGIN_LOW_0 => B"1000110",
      TX_MARGIN_LOW_1 => B"1000101",
      TX_MARGIN_LOW_2 => B"1000011",
      TX_MARGIN_LOW_3 => B"1000010",
      TX_MARGIN_LOW_4 => B"1000000",
      TX_MODE_SEL => B"000",
      TX_PMADATA_OPT => '0',
      TX_PMA_POWER_SAVE => '0',
      TX_PROGCLK_SEL => "PREPI",
      TX_PROGDIV_CFG => 40.000000,
      TX_QPI_STATUS_EN => '0',
      TX_RXDETECT_CFG => B"00" & X"032",
      TX_RXDETECT_REF => B"100",
      TX_SAMPLE_PERIOD => B"111",
      TX_SARC_LPBK_ENB => '0',
      TX_XCLK_SEL => "TXOUT",
      USE_PCS_CLK_PHASE_SEL => '0',
      WB_MODE => B"00"
    )
    port map (
      BUFGTCE(2 downto 0) => bufgtce_out(5 downto 3),
      BUFGTCEMASK(2 downto 0) => bufgtcemask_out(5 downto 3),
      BUFGTDIV(8 downto 0) => bufgtdiv_out(17 downto 9),
      BUFGTRESET(2 downto 0) => bufgtreset_out(5 downto 3),
      BUFGTRSTMASK(2 downto 0) => bufgtrstmask_out(5 downto 3),
      CFGRESET => cfgreset_in(1),
      CLKRSVD0 => clkrsvd0_in(1),
      CLKRSVD1 => clkrsvd1_in(1),
      CPLLFBCLKLOST => cpllfbclklost_out(1),
      CPLLLOCK => cplllock_out(1),
      CPLLLOCKDETCLK => cplllockdetclk_in(1),
      CPLLLOCKEN => cplllocken_in(1),
      CPLLPD => cpllpd_in(1),
      CPLLREFCLKLOST => cpllrefclklost_out(1),
      CPLLREFCLKSEL(2 downto 0) => cpllrefclksel_in(5 downto 3),
      CPLLRESET => cpllreset_in(1),
      DMONFIFORESET => dmonfiforeset_in(1),
      DMONITORCLK => dmonitorclk_in(1),
      DMONITOROUT(16 downto 0) => dmonitorout_out(33 downto 17),
      DRPADDR(8 downto 0) => drpaddr_in(17 downto 9),
      DRPCLK => drpclk_in(1),
      DRPDI(15 downto 0) => drpdi_in(31 downto 16),
      DRPDO(15 downto 0) => drpdo_out(31 downto 16),
      DRPEN => drpen_in(1),
      DRPRDY => drprdy_out(1),
      DRPWE => drpwe_in(1),
      EVODDPHICALDONE => evoddphicaldone_in(1),
      EVODDPHICALSTART => evoddphicalstart_in(1),
      EVODDPHIDRDEN => evoddphidrden_in(1),
      EVODDPHIDWREN => evoddphidwren_in(1),
      EVODDPHIXRDEN => evoddphixrden_in(1),
      EVODDPHIXWREN => evoddphixwren_in(1),
      EYESCANDATAERROR => eyescandataerror_out(1),
      EYESCANMODE => eyescanmode_in(1),
      EYESCANRESET => eyescanreset_in(1),
      EYESCANTRIGGER => eyescantrigger_in(1),
      GTGREFCLK => gtgrefclk_in(1),
      GTHRXN => gthrxn_in(1),
      GTHRXP => gthrxp_in(1),
      GTHTXN => gthtxn_out(1),
      GTHTXP => gthtxp_out(1),
      GTNORTHREFCLK0 => gtnorthrefclk0_in(1),
      GTNORTHREFCLK1 => gtnorthrefclk1_in(1),
      GTPOWERGOOD => \^gtpowergood_out\(1),
      GTREFCLK0 => gtrefclk0_in(1),
      GTREFCLK1 => gtrefclk1_in(1),
      GTREFCLKMONITOR => gtrefclkmonitor_out(1),
      GTRESETSEL => gtresetsel_in(1),
      GTRSVD(15 downto 0) => gtrsvd_in(31 downto 16),
      GTRXRESET => GTHE3_CHANNEL_GTRXRESET(0),
      GTSOUTHREFCLK0 => gtsouthrefclk0_in(1),
      GTSOUTHREFCLK1 => gtsouthrefclk1_in(1),
      GTTXRESET => GTHE3_CHANNEL_GTTXRESET(0),
      LOOPBACK(2 downto 0) => loopback_in(5 downto 3),
      LPBKRXTXSEREN => lpbkrxtxseren_in(1),
      LPBKTXRXSEREN => lpbktxrxseren_in(1),
      PCIEEQRXEQADAPTDONE => pcieeqrxeqadaptdone_in(1),
      PCIERATEGEN3 => pcierategen3_out(1),
      PCIERATEIDLE => pcierateidle_out(1),
      PCIERATEQPLLPD(1 downto 0) => pcierateqpllpd_out(3 downto 2),
      PCIERATEQPLLRESET(1 downto 0) => pcierateqpllreset_out(3 downto 2),
      PCIERSTIDLE => pcierstidle_in(1),
      PCIERSTTXSYNCSTART => pciersttxsyncstart_in(1),
      PCIESYNCTXSYNCDONE => pciesynctxsyncdone_out(1),
      PCIEUSERGEN3RDY => pcieusergen3rdy_out(1),
      PCIEUSERPHYSTATUSRST => pcieuserphystatusrst_out(1),
      PCIEUSERRATEDONE => pcieuserratedone_in(1),
      PCIEUSERRATESTART => pcieuserratestart_out(1),
      PCSRSVDIN(15 downto 0) => pcsrsvdin_in(31 downto 16),
      PCSRSVDIN2(4 downto 0) => pcsrsvdin2_in(9 downto 5),
      PCSRSVDOUT(11 downto 0) => pcsrsvdout_out(23 downto 12),
      PHYSTATUS => phystatus_out(1),
      PINRSRVDAS(7 downto 0) => pinrsrvdas_out(15 downto 8),
      PMARSVDIN(4 downto 0) => pmarsvdin_in(9 downto 5),
      QPLL0CLK => qpll0outclk_out(0),
      QPLL0REFCLK => qpll0outrefclk_out(0),
      QPLL1CLK => qpll1outclk_out(0),
      QPLL1REFCLK => qpll1outrefclk_out(0),
      RESETEXCEPTION => resetexception_out(1),
      RESETOVRD => resetovrd_in(1),
      RSTCLKENTX => rstclkentx_in(1),
      RX8B10BEN => rx8b10ben_in(1),
      RXBUFRESET => rxbufreset_in(1),
      RXBUFSTATUS(2 downto 0) => rxbufstatus_out(5 downto 3),
      RXBYTEISALIGNED => rxbyteisaligned_out(1),
      RXBYTEREALIGN => rxbyterealign_out(1),
      RXCDRFREQRESET => rxcdrfreqreset_in(1),
      RXCDRHOLD => rxcdrhold_in(1),
      RXCDRLOCK => \^rxcdrlock_out\(1),
      RXCDROVRDEN => rxcdrovrden_in(1),
      RXCDRPHDONE => rxcdrphdone_out(1),
      RXCDRRESET => rxcdrreset_in(1),
      RXCDRRESETRSV => rxcdrresetrsv_in(1),
      RXCHANBONDSEQ => rxchanbondseq_out(1),
      RXCHANISALIGNED => rxchanisaligned_out(1),
      RXCHANREALIGN => rxchanrealign_out(1),
      RXCHBONDEN => rxchbonden_in(1),
      RXCHBONDI(4 downto 0) => rxchbondi_in(9 downto 5),
      RXCHBONDLEVEL(2 downto 0) => rxchbondlevel_in(5 downto 3),
      RXCHBONDMASTER => rxchbondmaster_in(1),
      RXCHBONDO(4 downto 0) => rxchbondo_out(9 downto 5),
      RXCHBONDSLAVE => rxchbondslave_in(1),
      RXCLKCORCNT(1 downto 0) => rxclkcorcnt_out(3 downto 2),
      RXCOMINITDET => rxcominitdet_out(1),
      RXCOMMADET => rxcommadet_out(1),
      RXCOMMADETEN => rxcommadeten_in(1),
      RXCOMSASDET => rxcomsasdet_out(1),
      RXCOMWAKEDET => rxcomwakedet_out(1),
      RXCTRL0(15 downto 0) => rxctrl0_out(31 downto 16),
      RXCTRL1(15 downto 0) => rxctrl1_out(31 downto 16),
      RXCTRL2(7 downto 0) => rxctrl2_out(15 downto 8),
      RXCTRL3(7 downto 0) => rxctrl3_out(15 downto 8),
      RXDATA(127 downto 0) => rxdata_out(255 downto 128),
      RXDATAEXTENDRSVD(7 downto 0) => rxdataextendrsvd_out(15 downto 8),
      RXDATAVALID(1 downto 0) => rxdatavalid_out(3 downto 2),
      RXDFEAGCCTRL(1 downto 0) => rxdfeagcctrl_in(3 downto 2),
      RXDFEAGCHOLD => rxdfeagchold_in(1),
      RXDFEAGCOVRDEN => rxdfeagcovrden_in(1),
      RXDFELFHOLD => rxdfelfhold_in(1),
      RXDFELFOVRDEN => rxdfelfovrden_in(1),
      RXDFELPMRESET => rxdfelpmreset_in(1),
      RXDFETAP10HOLD => rxdfetap10hold_in(1),
      RXDFETAP10OVRDEN => rxdfetap10ovrden_in(1),
      RXDFETAP11HOLD => rxdfetap11hold_in(1),
      RXDFETAP11OVRDEN => rxdfetap11ovrden_in(1),
      RXDFETAP12HOLD => rxdfetap12hold_in(1),
      RXDFETAP12OVRDEN => rxdfetap12ovrden_in(1),
      RXDFETAP13HOLD => rxdfetap13hold_in(1),
      RXDFETAP13OVRDEN => rxdfetap13ovrden_in(1),
      RXDFETAP14HOLD => rxdfetap14hold_in(1),
      RXDFETAP14OVRDEN => rxdfetap14ovrden_in(1),
      RXDFETAP15HOLD => rxdfetap15hold_in(1),
      RXDFETAP15OVRDEN => rxdfetap15ovrden_in(1),
      RXDFETAP2HOLD => rxdfetap2hold_in(1),
      RXDFETAP2OVRDEN => rxdfetap2ovrden_in(1),
      RXDFETAP3HOLD => rxdfetap3hold_in(1),
      RXDFETAP3OVRDEN => rxdfetap3ovrden_in(1),
      RXDFETAP4HOLD => rxdfetap4hold_in(1),
      RXDFETAP4OVRDEN => rxdfetap4ovrden_in(1),
      RXDFETAP5HOLD => rxdfetap5hold_in(1),
      RXDFETAP5OVRDEN => rxdfetap5ovrden_in(1),
      RXDFETAP6HOLD => rxdfetap6hold_in(1),
      RXDFETAP6OVRDEN => rxdfetap6ovrden_in(1),
      RXDFETAP7HOLD => rxdfetap7hold_in(1),
      RXDFETAP7OVRDEN => rxdfetap7ovrden_in(1),
      RXDFETAP8HOLD => rxdfetap8hold_in(1),
      RXDFETAP8OVRDEN => rxdfetap8ovrden_in(1),
      RXDFETAP9HOLD => rxdfetap9hold_in(1),
      RXDFETAP9OVRDEN => rxdfetap9ovrden_in(1),
      RXDFEUTHOLD => rxdfeuthold_in(1),
      RXDFEUTOVRDEN => rxdfeutovrden_in(1),
      RXDFEVPHOLD => rxdfevphold_in(1),
      RXDFEVPOVRDEN => rxdfevpovrden_in(1),
      RXDFEVSEN => rxdfevsen_in(1),
      RXDFEXYDEN => rxdfexyden_in(1),
      RXDLYBYPASS => rxdlybypass_in(1),
      RXDLYEN => rxdlyen_in(1),
      RXDLYOVRDEN => rxdlyovrden_in(1),
      RXDLYSRESET => rxdlysreset_in(1),
      RXDLYSRESETDONE => rxdlysresetdone_out(1),
      RXELECIDLE => rxelecidle_out(1),
      RXELECIDLEMODE(1 downto 0) => rxelecidlemode_in(3 downto 2),
      RXGEARBOXSLIP => rxgearboxslip_in(1),
      RXHEADER(5 downto 0) => rxheader_out(11 downto 6),
      RXHEADERVALID(1 downto 0) => rxheadervalid_out(3 downto 2),
      RXLATCLK => rxlatclk_in(1),
      RXLPMEN => rxlpmen_in(1),
      RXLPMGCHOLD => rxlpmgchold_in(1),
      RXLPMGCOVRDEN => rxlpmgcovrden_in(1),
      RXLPMHFHOLD => rxlpmhfhold_in(1),
      RXLPMHFOVRDEN => rxlpmhfovrden_in(1),
      RXLPMLFHOLD => rxlpmlfhold_in(1),
      RXLPMLFKLOVRDEN => rxlpmlfklovrden_in(1),
      RXLPMOSHOLD => rxlpmoshold_in(1),
      RXLPMOSOVRDEN => rxlpmosovrden_in(1),
      RXMCOMMAALIGNEN => rxmcommaalignen_in(1),
      RXMONITOROUT(6 downto 0) => rxmonitorout_out(13 downto 7),
      RXMONITORSEL(1 downto 0) => rxmonitorsel_in(3 downto 2),
      RXOOBRESET => rxoobreset_in(1),
      RXOSCALRESET => rxoscalreset_in(1),
      RXOSHOLD => rxoshold_in(1),
      RXOSINTCFG(3 downto 0) => rxosintcfg_in(7 downto 4),
      RXOSINTDONE => rxosintdone_out(1),
      RXOSINTEN => rxosinten_in(1),
      RXOSINTHOLD => rxosinthold_in(1),
      RXOSINTOVRDEN => rxosintovrden_in(1),
      RXOSINTSTARTED => rxosintstarted_out(1),
      RXOSINTSTROBE => rxosintstrobe_in(1),
      RXOSINTSTROBEDONE => rxosintstrobedone_out(1),
      RXOSINTSTROBESTARTED => rxosintstrobestarted_out(1),
      RXOSINTTESTOVRDEN => rxosinttestovrden_in(1),
      RXOSOVRDEN => rxosovrden_in(1),
      RXOUTCLK => rxoutclk_out(1),
      RXOUTCLKFABRIC => rxoutclkfabric_out(1),
      RXOUTCLKPCS => rxoutclkpcs_out(1),
      RXOUTCLKSEL(2 downto 0) => rxoutclksel_in(5 downto 3),
      RXPCOMMAALIGNEN => rxpcommaalignen_in(1),
      RXPCSRESET => rxpcsreset_in(1),
      RXPD(1 downto 0) => rxpd_in(3 downto 2),
      RXPHALIGN => rxphalign_in(1),
      RXPHALIGNDONE => rxphaligndone_out(1),
      RXPHALIGNEN => rxphalignen_in(1),
      RXPHALIGNERR => rxphalignerr_out(1),
      RXPHDLYPD => rxphdlypd_in(1),
      RXPHDLYRESET => rxphdlyreset_in(1),
      RXPHOVRDEN => rxphovrden_in(1),
      RXPLLCLKSEL(1 downto 0) => rxpllclksel_in(3 downto 2),
      RXPMARESET => rxpmareset_in(1),
      RXPMARESETDONE => rxpmaresetdone_out(1),
      RXPOLARITY => rxpolarity_in(1),
      RXPRBSCNTRESET => rxprbscntreset_in(1),
      RXPRBSERR => rxprbserr_out(1),
      RXPRBSLOCKED => rxprbslocked_out(1),
      RXPRBSSEL(3 downto 0) => rxprbssel_in(7 downto 4),
      RXPRGDIVRESETDONE => rxprgdivresetdone_out(1),
      RXPROGDIVRESET => GTHE3_CHANNEL_RXPROGDIVRESET(0),
      RXQPIEN => rxqpien_in(1),
      RXQPISENN => rxqpisenn_out(1),
      RXQPISENP => rxqpisenp_out(1),
      RXRATE(2 downto 0) => rxrate_in(5 downto 3),
      RXRATEDONE => rxratedone_out(1),
      RXRATEMODE => rxratemode_in(1),
      RXRECCLKOUT => rxrecclkout_out(1),
      RXRESETDONE => \^rxresetdone_out\(1),
      RXSLIDE => rxslide_in(1),
      RXSLIDERDY => rxsliderdy_out(1),
      RXSLIPDONE => rxslipdone_out(1),
      RXSLIPOUTCLK => rxslipoutclk_in(1),
      RXSLIPOUTCLKRDY => rxslipoutclkrdy_out(1),
      RXSLIPPMA => rxslippma_in(1),
      RXSLIPPMARDY => rxslippmardy_out(1),
      RXSTARTOFSEQ(1 downto 0) => rxstartofseq_out(3 downto 2),
      RXSTATUS(2 downto 0) => rxstatus_out(5 downto 3),
      RXSYNCALLIN => rxsyncallin_in(1),
      RXSYNCDONE => rxsyncdone_out(1),
      RXSYNCIN => rxsyncin_in(1),
      RXSYNCMODE => rxsyncmode_in(1),
      RXSYNCOUT => rxsyncout_out(1),
      RXSYSCLKSEL(1 downto 0) => rxsysclksel_in(3 downto 2),
      RXUSERRDY => GTHE3_CHANNEL_RXUSERRDY(0),
      RXUSRCLK => rxusrclk_in(1),
      RXUSRCLK2 => rxusrclk2_in(1),
      RXVALID => rxvalid_out(1),
      SIGVALIDCLK => sigvalidclk_in(1),
      TSTIN(19) => '0',
      TSTIN(18) => '0',
      TSTIN(17) => '0',
      TSTIN(16) => '0',
      TSTIN(15) => '0',
      TSTIN(14) => '0',
      TSTIN(13) => '0',
      TSTIN(12) => '0',
      TSTIN(11) => '0',
      TSTIN(10) => '0',
      TSTIN(9) => '0',
      TSTIN(8) => '0',
      TSTIN(7) => '0',
      TSTIN(6) => '0',
      TSTIN(5) => '0',
      TSTIN(4) => '0',
      TSTIN(3) => '0',
      TSTIN(2) => '0',
      TSTIN(1) => '0',
      TSTIN(0) => '0',
      TX8B10BBYPASS(7 downto 0) => tx8b10bbypass_in(15 downto 8),
      TX8B10BEN => tx8b10ben_in(1),
      TXBUFDIFFCTRL(2 downto 0) => txbufdiffctrl_in(5 downto 3),
      TXBUFSTATUS(1 downto 0) => txbufstatus_out(3 downto 2),
      TXCOMFINISH => txcomfinish_out(1),
      TXCOMINIT => txcominit_in(1),
      TXCOMSAS => txcomsas_in(1),
      TXCOMWAKE => txcomwake_in(1),
      TXCTRL0(15 downto 0) => txctrl0_in(31 downto 16),
      TXCTRL1(15 downto 0) => txctrl1_in(31 downto 16),
      TXCTRL2(7 downto 0) => txctrl2_in(15 downto 8),
      TXDATA(127) => '0',
      TXDATA(126) => '0',
      TXDATA(125) => '0',
      TXDATA(124) => '0',
      TXDATA(123) => '0',
      TXDATA(122) => '0',
      TXDATA(121) => '0',
      TXDATA(120) => '0',
      TXDATA(119) => '0',
      TXDATA(118) => '0',
      TXDATA(117) => '0',
      TXDATA(116) => '0',
      TXDATA(115) => '0',
      TXDATA(114) => '0',
      TXDATA(113) => '0',
      TXDATA(112) => '0',
      TXDATA(111) => '0',
      TXDATA(110) => '0',
      TXDATA(109) => '0',
      TXDATA(108) => '0',
      TXDATA(107) => '0',
      TXDATA(106) => '0',
      TXDATA(105) => '0',
      TXDATA(104) => '0',
      TXDATA(103) => '0',
      TXDATA(102) => '0',
      TXDATA(101) => '0',
      TXDATA(100) => '0',
      TXDATA(99) => '0',
      TXDATA(98) => '0',
      TXDATA(97) => '0',
      TXDATA(96) => '0',
      TXDATA(95) => '0',
      TXDATA(94) => '0',
      TXDATA(93) => '0',
      TXDATA(92) => '0',
      TXDATA(91) => '0',
      TXDATA(90) => '0',
      TXDATA(89) => '0',
      TXDATA(88) => '0',
      TXDATA(87) => '0',
      TXDATA(86) => '0',
      TXDATA(85) => '0',
      TXDATA(84) => '0',
      TXDATA(83) => '0',
      TXDATA(82) => '0',
      TXDATA(81) => '0',
      TXDATA(80) => '0',
      TXDATA(79) => '0',
      TXDATA(78) => '0',
      TXDATA(77) => '0',
      TXDATA(76) => '0',
      TXDATA(75) => '0',
      TXDATA(74) => '0',
      TXDATA(73) => '0',
      TXDATA(72) => '0',
      TXDATA(71) => '0',
      TXDATA(70) => '0',
      TXDATA(69) => '0',
      TXDATA(68) => '0',
      TXDATA(67) => '0',
      TXDATA(66) => '0',
      TXDATA(65) => '0',
      TXDATA(64) => '0',
      TXDATA(63) => '0',
      TXDATA(62) => '0',
      TXDATA(61) => '0',
      TXDATA(60) => '0',
      TXDATA(59) => '0',
      TXDATA(58) => '0',
      TXDATA(57) => '0',
      TXDATA(56) => '0',
      TXDATA(55) => '0',
      TXDATA(54) => '0',
      TXDATA(53) => '0',
      TXDATA(52) => '0',
      TXDATA(51) => '0',
      TXDATA(50) => '0',
      TXDATA(49) => '0',
      TXDATA(48) => '0',
      TXDATA(47) => '0',
      TXDATA(46) => '0',
      TXDATA(45) => '0',
      TXDATA(44) => '0',
      TXDATA(43) => '0',
      TXDATA(42) => '0',
      TXDATA(41) => '0',
      TXDATA(40) => '0',
      TXDATA(39) => '0',
      TXDATA(38) => '0',
      TXDATA(37) => '0',
      TXDATA(36) => '0',
      TXDATA(35) => '0',
      TXDATA(34) => '0',
      TXDATA(33) => '0',
      TXDATA(32) => '0',
      TXDATA(31 downto 0) => gtwiz_userdata_tx_in(63 downto 32),
      TXDATAEXTENDRSVD(7 downto 0) => txdataextendrsvd_in(15 downto 8),
      TXDEEMPH => txdeemph_in(1),
      TXDETECTRX => txdetectrx_in(1),
      TXDIFFCTRL(3 downto 0) => txdiffctrl_in(7 downto 4),
      TXDIFFPD => txdiffpd_in(1),
      TXDLYBYPASS => txdlybypass_in(1),
      TXDLYEN => txdlyen_in(1),
      TXDLYHOLD => txdlyhold_in(1),
      TXDLYOVRDEN => txdlyovrden_in(1),
      TXDLYSRESET => txdlysreset_in(1),
      TXDLYSRESETDONE => txdlysresetdone_out(1),
      TXDLYUPDOWN => txdlyupdown_in(1),
      TXELECIDLE => txelecidle_in(1),
      TXHEADER(5 downto 0) => txheader_in(11 downto 6),
      TXINHIBIT => txinhibit_in(1),
      TXLATCLK => txlatclk_in(1),
      TXMAINCURSOR(6 downto 0) => txmaincursor_in(13 downto 7),
      TXMARGIN(2 downto 0) => txmargin_in(5 downto 3),
      TXOUTCLK => txoutclk_out(1),
      TXOUTCLKFABRIC => txoutclkfabric_out(1),
      TXOUTCLKPCS => txoutclkpcs_out(1),
      TXOUTCLKSEL(2 downto 0) => txoutclksel_in(5 downto 3),
      TXPCSRESET => txpcsreset_in(1),
      TXPD(1 downto 0) => txpd_in(3 downto 2),
      TXPDELECIDLEMODE => txpdelecidlemode_in(1),
      TXPHALIGN => txphalign_in(1),
      TXPHALIGNDONE => txphaligndone_out(1),
      TXPHALIGNEN => txphalignen_in(1),
      TXPHDLYPD => txphdlypd_in(1),
      TXPHDLYRESET => txphdlyreset_in(1),
      TXPHDLYTSTCLK => txphdlytstclk_in(1),
      TXPHINIT => txphinit_in(1),
      TXPHINITDONE => txphinitdone_out(1),
      TXPHOVRDEN => txphovrden_in(1),
      TXPIPPMEN => txpippmen_in(1),
      TXPIPPMOVRDEN => txpippmovrden_in(1),
      TXPIPPMPD => txpippmpd_in(1),
      TXPIPPMSEL => txpippmsel_in(1),
      TXPIPPMSTEPSIZE(4 downto 0) => txpippmstepsize_in(9 downto 5),
      TXPISOPD => txpisopd_in(1),
      TXPLLCLKSEL(1 downto 0) => txpllclksel_in(3 downto 2),
      TXPMARESET => txpmareset_in(1),
      TXPMARESETDONE => txpmaresetdone_out(1),
      TXPOLARITY => txpolarity_in(1),
      TXPOSTCURSOR(4 downto 0) => txpostcursor_in(9 downto 5),
      TXPOSTCURSORINV => txpostcursorinv_in(1),
      TXPRBSFORCEERR => txprbsforceerr_in(1),
      TXPRBSSEL(3 downto 0) => txprbssel_in(7 downto 4),
      TXPRECURSOR(4 downto 0) => txprecursor_in(9 downto 5),
      TXPRECURSORINV => txprecursorinv_in(1),
      TXPRGDIVRESETDONE => txprgdivresetdone_out(1),
      TXPROGDIVRESET => GTHE3_CHANNEL_TXPROGDIVRESET(0),
      TXQPIBIASEN => txqpibiasen_in(1),
      TXQPISENN => txqpisenn_out(1),
      TXQPISENP => txqpisenp_out(1),
      TXQPISTRONGPDOWN => txqpistrongpdown_in(1),
      TXQPIWEAKPUP => txqpiweakpup_in(1),
      TXRATE(2 downto 0) => txrate_in(5 downto 3),
      TXRATEDONE => txratedone_out(1),
      TXRATEMODE => txratemode_in(1),
      TXRESETDONE => \^txresetdone_out\(1),
      TXSEQUENCE(6 downto 0) => txsequence_in(13 downto 7),
      TXSWING => txswing_in(1),
      TXSYNCALLIN => txsyncallin_in(1),
      TXSYNCDONE => txsyncdone_out(1),
      TXSYNCIN => txsyncin_in(1),
      TXSYNCMODE => txsyncmode_in(1),
      TXSYNCOUT => txsyncout_out(1),
      TXSYSCLKSEL(1 downto 0) => txsysclksel_in(3 downto 2),
      TXUSERRDY => GTHE3_CHANNEL_TXUSERRDY(0),
      TXUSRCLK => txusrclk_in(1),
      TXUSRCLK2 => txusrclk2_in(1)
    );
i_in_inferred_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => \^gtpowergood_out\(0),
      I1 => \^gtpowergood_out\(1),
      O => O1
    );
\i_in_inferred_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => \^txresetdone_out\(0),
      I1 => \^txresetdone_out\(1),
      O => O2
    );
\i_in_inferred_i_1__1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => \^rxcdrlock_out\(0),
      I1 => \^rxcdrlock_out\(1),
      O => O3
    );
\i_in_inferred_i_1__2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => \^rxresetdone_out\(0),
      I1 => \^rxresetdone_out\(1),
      O => O4
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common is
  port (
    drprdy_common_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    O1 : out STD_LOGIC;
    qpll0outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor0_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor1_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    drpdo_common_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxrecclk0_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclk1_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pmarsvdout0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pmarsvdout1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rst_in0 : out STD_LOGIC;
    drpclk_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpen_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpwe_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll0reset_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpdi_common_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    qpll0refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpll1refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpllrsvd2_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd3_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd1_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    qpllrsvd4_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    drpaddr_common_in : in STD_LOGIC_VECTOR ( 8 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common : entity is "gtwizard_ultrascale_v1_4_gthe3_common";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common is
  signal \^o1\ : STD_LOGIC;
  attribute BOX_TYPE : string;
  attribute BOX_TYPE of \gthe3_common_gen.GTHE3_COMMON_PRIM_INST\ : label is "PRIMITIVE";
begin
  O1 <= \^o1\;
\gthe3_common_gen.GTHE3_COMMON_PRIM_INST\: unisim.vcomponents.GTHE3_COMMON
    generic map(
      BIAS_CFG0 => X"0000",
      BIAS_CFG1 => X"0000",
      BIAS_CFG2 => X"0000",
      BIAS_CFG3 => X"0040",
      BIAS_CFG4 => X"0000",
      BIAS_CFG_RSVD => B"0000000000",
      COMMON_CFG0 => X"0000",
      COMMON_CFG1 => X"0000",
      POR_CFG => X"0004",
      QPLL0_CFG0 => X"301C",
      QPLL0_CFG1 => X"0018",
      QPLL0_CFG1_G3 => X"0018",
      QPLL0_CFG2 => X"0048",
      QPLL0_CFG2_G3 => X"0048",
      QPLL0_CFG3 => X"0120",
      QPLL0_CFG4 => X"001B",
      QPLL0_CP => B"0000011111",
      QPLL0_CP_G3 => B"1111111111",
      QPLL0_FBDIV => 40,
      QPLL0_FBDIV_G3 => 80,
      QPLL0_INIT_CFG0 => X"0000",
      QPLL0_INIT_CFG1 => X"00",
      QPLL0_LOCK_CFG => X"25E8",
      QPLL0_LOCK_CFG_G3 => X"25E8",
      QPLL0_LPF => B"1111111111",
      QPLL0_LPF_G3 => B"0000010101",
      QPLL0_REFCLK_DIV => 1,
      QPLL0_SDM_CFG0 => B"0000000000000000",
      QPLL0_SDM_CFG1 => B"0000000000000000",
      QPLL0_SDM_CFG2 => B"0000000000000000",
      QPLL1_CFG0 => X"301C",
      QPLL1_CFG1 => X"0018",
      QPLL1_CFG1_G3 => X"0018",
      QPLL1_CFG2 => X"0040",
      QPLL1_CFG2_G3 => X"0040",
      QPLL1_CFG3 => X"0120",
      QPLL1_CFG4 => X"0009",
      QPLL1_CP => B"0000011111",
      QPLL1_CP_G3 => B"1111111111",
      QPLL1_FBDIV => 66,
      QPLL1_FBDIV_G3 => 80,
      QPLL1_INIT_CFG0 => X"0000",
      QPLL1_INIT_CFG1 => X"00",
      QPLL1_LOCK_CFG => X"25E8",
      QPLL1_LOCK_CFG_G3 => X"25E8",
      QPLL1_LPF => B"1111111111",
      QPLL1_LPF_G3 => B"0000010101",
      QPLL1_REFCLK_DIV => 1,
      QPLL1_SDM_CFG0 => B"0000000000000000",
      QPLL1_SDM_CFG1 => B"0000000000000000",
      QPLL1_SDM_CFG2 => B"0000000000000000",
      RSVD_ATTR0 => X"0000",
      RSVD_ATTR1 => X"0000",
      RSVD_ATTR2 => X"0000",
      RSVD_ATTR3 => X"0000",
      RXRECCLKOUT0_SEL => B"00",
      RXRECCLKOUT1_SEL => B"00",
      SARC_EN => '1',
      SARC_SEL => '0',
      SDM0DATA1_0 => B"0000000000000000",
      SDM0DATA1_1 => B"000000000",
      SDM0INITSEED0_0 => B"0000000000000000",
      SDM0INITSEED0_1 => B"000000000",
      SDM0_DATA_PIN_SEL => '0',
      SDM0_WIDTH_PIN_SEL => '0',
      SDM1DATA1_0 => B"0000000000000000",
      SDM1DATA1_1 => B"000000000",
      SDM1INITSEED0_0 => B"0000000000000000",
      SDM1INITSEED0_1 => B"000000000",
      SDM1_DATA_PIN_SEL => '0',
      SDM1_WIDTH_PIN_SEL => '0',
      SIM_RESET_SPEEDUP => "TRUE",
      SIM_VERSION => 2
    )
    port map (
      BGBYPASSB => '1',
      BGMONITORENB => '1',
      BGPDB => '1',
      BGRCALOVRD(4) => '1',
      BGRCALOVRD(3) => '1',
      BGRCALOVRD(2) => '1',
      BGRCALOVRD(1) => '1',
      BGRCALOVRD(0) => '1',
      BGRCALOVRDENB => '1',
      DRPADDR(8 downto 0) => drpaddr_common_in(8 downto 0),
      DRPCLK => drpclk_common_in(0),
      DRPDI(15 downto 0) => drpdi_common_in(15 downto 0),
      DRPDO(15 downto 0) => drpdo_common_out(15 downto 0),
      DRPEN => drpen_common_in(0),
      DRPRDY => drprdy_common_out(0),
      DRPWE => drpwe_common_in(0),
      GTGREFCLK0 => gtgrefclk0_in(0),
      GTGREFCLK1 => gtgrefclk1_in(0),
      GTNORTHREFCLK00 => gtnorthrefclk00_in(0),
      GTNORTHREFCLK01 => gtnorthrefclk01_in(0),
      GTNORTHREFCLK10 => gtnorthrefclk10_in(0),
      GTNORTHREFCLK11 => gtnorthrefclk11_in(0),
      GTREFCLK00 => gtrefclk00_in(0),
      GTREFCLK01 => gtrefclk01_in(0),
      GTREFCLK10 => gtrefclk10_in(0),
      GTREFCLK11 => gtrefclk11_in(0),
      GTSOUTHREFCLK00 => gtsouthrefclk00_in(0),
      GTSOUTHREFCLK01 => gtsouthrefclk01_in(0),
      GTSOUTHREFCLK10 => gtsouthrefclk10_in(0),
      GTSOUTHREFCLK11 => gtsouthrefclk11_in(0),
      PMARSVD0(7) => '0',
      PMARSVD0(6) => '0',
      PMARSVD0(5) => '0',
      PMARSVD0(4) => '0',
      PMARSVD0(3) => '0',
      PMARSVD0(2) => '0',
      PMARSVD0(1) => '0',
      PMARSVD0(0) => '0',
      PMARSVD1(7) => '0',
      PMARSVD1(6) => '0',
      PMARSVD1(5) => '0',
      PMARSVD1(4) => '0',
      PMARSVD1(3) => '0',
      PMARSVD1(2) => '0',
      PMARSVD1(1) => '0',
      PMARSVD1(0) => '0',
      PMARSVDOUT0(7 downto 0) => pmarsvdout0_out(7 downto 0),
      PMARSVDOUT1(7 downto 0) => pmarsvdout1_out(7 downto 0),
      QPLL0CLKRSVD0 => qpll0clkrsvd0_in(0),
      QPLL0CLKRSVD1 => qpll0clkrsvd1_in(0),
      QPLL0FBCLKLOST => qpll0fbclklost_out(0),
      QPLL0LOCK => \^o1\,
      QPLL0LOCKDETCLK => qpll0lockdetclk_in(0),
      QPLL0LOCKEN => qpll0locken_in(0),
      QPLL0OUTCLK => qpll0outclk_out(0),
      QPLL0OUTREFCLK => qpll0outrefclk_out(0),
      QPLL0PD => qpll0pd_in(0),
      QPLL0REFCLKLOST => qpll0refclklost_out(0),
      QPLL0REFCLKSEL(2 downto 0) => qpll0refclksel_in(2 downto 0),
      QPLL0RESET => gtwiz_reset_qpll0reset_out(0),
      QPLL1CLKRSVD0 => qpll1clkrsvd0_in(0),
      QPLL1CLKRSVD1 => qpll1clkrsvd1_in(0),
      QPLL1FBCLKLOST => qpll1fbclklost_out(0),
      QPLL1LOCK => qpll1lock_out(0),
      QPLL1LOCKDETCLK => qpll1lockdetclk_in(0),
      QPLL1LOCKEN => qpll1locken_in(0),
      QPLL1OUTCLK => qpll1outclk_out(0),
      QPLL1OUTREFCLK => qpll1outrefclk_out(0),
      QPLL1PD => qpll1pd_in(0),
      QPLL1REFCLKLOST => qpll1refclklost_out(0),
      QPLL1REFCLKSEL(2 downto 0) => qpll1refclksel_in(2 downto 0),
      QPLL1RESET => qpll1reset_in(0),
      QPLLDMONITOR0(7 downto 0) => qplldmonitor0_out(7 downto 0),
      QPLLDMONITOR1(7 downto 0) => qplldmonitor1_out(7 downto 0),
      QPLLRSVD1(7 downto 0) => qpllrsvd1_in(7 downto 0),
      QPLLRSVD2(4 downto 0) => qpllrsvd2_in(4 downto 0),
      QPLLRSVD3(4 downto 0) => qpllrsvd3_in(4 downto 0),
      QPLLRSVD4(7 downto 0) => qpllrsvd4_in(7 downto 0),
      RCALENB => '1',
      REFCLKOUTMONITOR0 => refclkoutmonitor0_out(0),
      REFCLKOUTMONITOR1 => refclkoutmonitor1_out(0),
      RXRECCLK0_SEL(1 downto 0) => rxrecclk0_sel_out(1 downto 0),
      RXRECCLK1_SEL(1 downto 0) => rxrecclk1_sel_out(1 downto 0)
    );
\rst_in_meta_i_1__4\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => \^o1\,
      O => rst_in0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer is
  port (
    SR : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer is
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => gtwiz_reset_all_in(0),
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => gtwiz_reset_all_in(0),
      Q => SR(0)
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => gtwiz_reset_all_in(0),
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => gtwiz_reset_all_in(0),
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => gtwiz_reset_all_in(0),
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13 is
  port (
    gtwiz_reset_rx_any_sync : out STD_LOGIC;
    O1 : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gtwiz_reset_pllreset_rx_int : in STD_LOGIC;
    I1 : in STD_LOGIC;
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I2 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13 is
  signal gtwiz_reset_rx_any : STD_LOGIC;
  signal \^gtwiz_reset_rx_any_sync\ : STD_LOGIC;
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
  gtwiz_reset_rx_any_sync <= \^gtwiz_reset_rx_any_sync\;
pllreset_rx_out_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFDF0010"
    )
    port map (
      I0 => \out\(1),
      I1 => \out\(2),
      I2 => \out\(0),
      I3 => \^gtwiz_reset_rx_any_sync\,
      I4 => gtwiz_reset_pllreset_rx_int,
      O => O1
    );
\rst_in_meta_i_1__1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
    port map (
      I0 => I1,
      I1 => gtwiz_reset_rx_datapath_in(0),
      I2 => gtwiz_reset_rx_pll_and_datapath_in(0),
      I3 => I2,
      O => gtwiz_reset_rx_any
    );
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => gtwiz_reset_rx_any,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => gtwiz_reset_rx_any,
      Q => \^gtwiz_reset_rx_any_sync\
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => gtwiz_reset_rx_any,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => gtwiz_reset_rx_any,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => gtwiz_reset_rx_any,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14 is
  port (
    gtwiz_reset_rx_datapath_sync : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14 is
  signal rst_in0_1 : STD_LOGIC;
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
\rst_in_meta_i_1__3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
    port map (
      I0 => gtwiz_reset_rx_datapath_in(0),
      I1 => I1,
      O => rst_in0_1
    );
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => rst_in0_1,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => rst_in0_1,
      Q => gtwiz_reset_rx_datapath_sync
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => rst_in0_1,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => rst_in0_1,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => rst_in0_1,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15 is
  port (
    gtwiz_reset_rx_pll_and_datapath_sync : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15 is
  signal p_0_in : STD_LOGIC;
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
\rst_in_meta_i_1__2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
    port map (
      I0 => I1,
      I1 => gtwiz_reset_rx_pll_and_datapath_in(0),
      O => p_0_in
    );
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => p_0_in,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => p_0_in,
      Q => gtwiz_reset_rx_pll_and_datapath_sync
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => p_0_in,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => p_0_in,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => p_0_in,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16 is
  port (
    gtwiz_reset_tx_any_sync : out STD_LOGIC;
    O1 : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    \out\ : in STD_LOGIC_VECTOR ( 2 downto 0 );
    gtwiz_reset_pllreset_tx_int : in STD_LOGIC;
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16 is
  signal gtwiz_reset_tx_any : STD_LOGIC;
  signal \^gtwiz_reset_tx_any_sync\ : STD_LOGIC;
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
  gtwiz_reset_tx_any_sync <= \^gtwiz_reset_tx_any_sync\;
pllreset_tx_out_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFDF0010"
    )
    port map (
      I0 => \out\(1),
      I1 => \out\(2),
      I2 => \out\(0),
      I3 => \^gtwiz_reset_tx_any_sync\,
      I4 => gtwiz_reset_pllreset_tx_int,
      O => O1
    );
rst_in_meta_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"FE"
    )
    port map (
      I0 => gtwiz_reset_tx_datapath_in(0),
      I1 => gtwiz_reset_tx_pll_and_datapath_in(0),
      I2 => I1,
      O => gtwiz_reset_tx_any
    );
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => gtwiz_reset_tx_any,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => gtwiz_reset_tx_any,
      Q => \^gtwiz_reset_tx_any_sync\
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => gtwiz_reset_tx_any,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => gtwiz_reset_tx_any,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => gtwiz_reset_tx_any,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17 is
  port (
    gtwiz_reset_tx_datapath_sync : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17 is
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => gtwiz_reset_tx_datapath_in(0),
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => gtwiz_reset_tx_datapath_in(0),
      Q => gtwiz_reset_tx_datapath_sync
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => gtwiz_reset_tx_datapath_in(0),
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => gtwiz_reset_tx_datapath_in(0),
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => gtwiz_reset_tx_datapath_in(0),
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18 is
  port (
    gtwiz_reset_tx_pll_and_datapath_sync : out STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18 is
  signal p_1_in_0 : STD_LOGIC;
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
\rst_in_meta_i_1__0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
    port map (
      I0 => I1,
      I1 => gtwiz_reset_tx_pll_and_datapath_in(0),
      O => p_1_in_0
    );
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => p_1_in_0,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => p_1_in_0,
      Q => gtwiz_reset_tx_pll_and_datapath_sync
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => p_1_in_0,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => p_1_in_0,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => p_1_in_0,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19 is
  port (
    GTHE3_CHANNEL_RXPROGDIVRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rst_in0 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19 is
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => rst_in0,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => rst_in0,
      Q => GTHE3_CHANNEL_RXPROGDIVRESET(0)
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => rst_in0,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => rst_in0,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => rst_in0,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20 is
  port (
    GTHE3_CHANNEL_TXPROGDIVRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rst_in0 : in STD_LOGIC
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20 : entity is "gtwizard_ultrascale_v1_4_reset_synchronizer";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20 is
  signal rst_in_meta : STD_LOGIC;
  signal rst_in_sync1 : STD_LOGIC;
  signal rst_in_sync2 : STD_LOGIC;
  signal rst_in_sync3 : STD_LOGIC;
  attribute ASYNC_REG : boolean;
  attribute ASYNC_REG of rst_in_meta_reg : label is std.standard.true;
  attribute KEEP : string;
  attribute KEEP of rst_in_meta_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync1_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync1_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync2_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync2_reg : label is "yes";
  attribute ASYNC_REG of rst_in_sync3_reg : label is std.standard.true;
  attribute KEEP of rst_in_sync3_reg : label is "yes";
begin
rst_in_meta_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => '0',
      PRE => rst_in0,
      Q => rst_in_meta
    );
rst_in_out_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync3,
      PRE => rst_in0,
      Q => GTHE3_CHANNEL_TXPROGDIVRESET(0)
    );
rst_in_sync1_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_meta,
      PRE => rst_in0,
      Q => rst_in_sync1
    );
rst_in_sync2_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync1,
      PRE => rst_in0,
      Q => rst_in_sync2
    );
rst_in_sync3_reg: unisim.vcomponents.FDPE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => rst_in_sync2,
      PRE => rst_in0,
      Q => rst_in_sync3
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper is
  port (
    O1 : out STD_LOGIC;
    gtpowergood_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O2 : out STD_LOGIC;
    txresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O3 : out STD_LOGIC;
    rxcdrlock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    O4 : out STD_LOGIC;
    rxresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllfbclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllrefclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    drprdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescandataerror_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclkmonitor_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierategen3_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierateidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pciesynctxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieusergen3rdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserphystatusrst_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratestart_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    phystatus_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    resetexception_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyterealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrphdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanbondseq_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanrealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcominitdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomsasdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomwakedet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxelecidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobestarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignerr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbserr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbslocked_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclkout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsliderdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclkrdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippmardy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxvalid_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomfinish_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinitdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcsrsvdout_out : out STD_LOGIC_VECTOR ( 23 downto 0 );
    rxdata_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
    drpdo_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl0_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl1_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    dmonitorout_out : out STD_LOGIC_VECTOR ( 33 downto 0 );
    pcierateqpllpd_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pcierateqpllreset_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxclkcorcnt_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxdatavalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxheadervalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxstartofseq_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    txbufstatus_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    bufgtce_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtcemask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtreset_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtrstmask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxbufstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondo_out : out STD_LOGIC_VECTOR ( 9 downto 0 );
    rxheader_out : out STD_LOGIC_VECTOR ( 11 downto 0 );
    rxmonitorout_out : out STD_LOGIC_VECTOR ( 13 downto 0 );
    pinrsrvdas_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl2_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl3_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxdataextendrsvd_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    bufgtdiv_out : out STD_LOGIC_VECTOR ( 17 downto 0 );
    cfgreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllockdetclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllocken_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonfiforeset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonitorclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpwe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicaldone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicalstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescantrigger_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtgrefclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxn_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxp_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtresetsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_GTRXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_GTTXRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    lpbkrxtxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    lpbktxrxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieeqrxeqadaptdone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierstidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pciersttxsyncstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratedone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll0outclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    resetovrd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rstclkentx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbufreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrfreqreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrresetrsv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbonden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondmaster_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondslave_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadeten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelpmreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeuthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeutovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevphold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevpovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevsen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfexyden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxgearboxslip_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfklovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoobreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoscalreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinttestovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbscntreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_RXPROGDIVRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxqpien_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslide_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippma_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_RXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    sigvalidclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    tx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcominit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomsas_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomwake_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdeemph_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdetectrx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdiffpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyupdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txelecidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txinhibit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpdelecidlemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlytstclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpisopd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpostcursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprbsforceerr_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprecursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_TXPROGDIVRESET : in STD_LOGIC_VECTOR ( 0 to 0 );
    txqpibiasen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpistrongpdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpiweakpup_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txswing_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    GTHE3_CHANNEL_TXUSERRDY : in STD_LOGIC_VECTOR ( 0 to 0 );
    txusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
    drpdi_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    gtrsvd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    pcsrsvdin_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl0_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl1_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    rxdfeagcctrl_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxelecidlemode_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxmonitorsel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    cpllrefclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    loopback_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondlevel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txbufdiffctrl_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txmargin_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxosintcfg_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txdiffctrl_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pcsrsvdin2_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    pmarsvdin_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    rxchbondi_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpippmstepsize_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpostcursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txprecursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txheader_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
    txmaincursor_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    txsequence_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    tx8b10bbypass_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txctrl2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txdataextendrsvd_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drpaddr_in : in STD_LOGIC_VECTOR ( 17 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper : entity is "GthUltrascaleJesdCoregen_gthe3_channel_wrapper";
end GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper;

architecture STRUCTURE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper is
begin
channel_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel
    port map (
      GTHE3_CHANNEL_GTRXRESET(0) => GTHE3_CHANNEL_GTRXRESET(0),
      GTHE3_CHANNEL_GTTXRESET(0) => GTHE3_CHANNEL_GTTXRESET(0),
      GTHE3_CHANNEL_RXPROGDIVRESET(0) => GTHE3_CHANNEL_RXPROGDIVRESET(0),
      GTHE3_CHANNEL_RXUSERRDY(0) => GTHE3_CHANNEL_RXUSERRDY(0),
      GTHE3_CHANNEL_TXPROGDIVRESET(0) => GTHE3_CHANNEL_TXPROGDIVRESET(0),
      GTHE3_CHANNEL_TXUSERRDY(0) => GTHE3_CHANNEL_TXUSERRDY(0),
      O1 => O1,
      O2 => O2,
      O3 => O3,
      O4 => O4,
      bufgtce_out(5 downto 0) => bufgtce_out(5 downto 0),
      bufgtcemask_out(5 downto 0) => bufgtcemask_out(5 downto 0),
      bufgtdiv_out(17 downto 0) => bufgtdiv_out(17 downto 0),
      bufgtreset_out(5 downto 0) => bufgtreset_out(5 downto 0),
      bufgtrstmask_out(5 downto 0) => bufgtrstmask_out(5 downto 0),
      cfgreset_in(1 downto 0) => cfgreset_in(1 downto 0),
      clkrsvd0_in(1 downto 0) => clkrsvd0_in(1 downto 0),
      clkrsvd1_in(1 downto 0) => clkrsvd1_in(1 downto 0),
      cpllfbclklost_out(1 downto 0) => cpllfbclklost_out(1 downto 0),
      cplllock_out(1 downto 0) => cplllock_out(1 downto 0),
      cplllockdetclk_in(1 downto 0) => cplllockdetclk_in(1 downto 0),
      cplllocken_in(1 downto 0) => cplllocken_in(1 downto 0),
      cpllpd_in(1 downto 0) => cpllpd_in(1 downto 0),
      cpllrefclklost_out(1 downto 0) => cpllrefclklost_out(1 downto 0),
      cpllrefclksel_in(5 downto 0) => cpllrefclksel_in(5 downto 0),
      cpllreset_in(1 downto 0) => cpllreset_in(1 downto 0),
      dmonfiforeset_in(1 downto 0) => dmonfiforeset_in(1 downto 0),
      dmonitorclk_in(1 downto 0) => dmonitorclk_in(1 downto 0),
      dmonitorout_out(33 downto 0) => dmonitorout_out(33 downto 0),
      drpaddr_in(17 downto 0) => drpaddr_in(17 downto 0),
      drpclk_in(1 downto 0) => drpclk_in(1 downto 0),
      drpdi_in(31 downto 0) => drpdi_in(31 downto 0),
      drpdo_out(31 downto 0) => drpdo_out(31 downto 0),
      drpen_in(1 downto 0) => drpen_in(1 downto 0),
      drprdy_out(1 downto 0) => drprdy_out(1 downto 0),
      drpwe_in(1 downto 0) => drpwe_in(1 downto 0),
      evoddphicaldone_in(1 downto 0) => evoddphicaldone_in(1 downto 0),
      evoddphicalstart_in(1 downto 0) => evoddphicalstart_in(1 downto 0),
      evoddphidrden_in(1 downto 0) => evoddphidrden_in(1 downto 0),
      evoddphidwren_in(1 downto 0) => evoddphidwren_in(1 downto 0),
      evoddphixrden_in(1 downto 0) => evoddphixrden_in(1 downto 0),
      evoddphixwren_in(1 downto 0) => evoddphixwren_in(1 downto 0),
      eyescandataerror_out(1 downto 0) => eyescandataerror_out(1 downto 0),
      eyescanmode_in(1 downto 0) => eyescanmode_in(1 downto 0),
      eyescanreset_in(1 downto 0) => eyescanreset_in(1 downto 0),
      eyescantrigger_in(1 downto 0) => eyescantrigger_in(1 downto 0),
      gtgrefclk_in(1 downto 0) => gtgrefclk_in(1 downto 0),
      gthrxn_in(1 downto 0) => gthrxn_in(1 downto 0),
      gthrxp_in(1 downto 0) => gthrxp_in(1 downto 0),
      gthtxn_out(1 downto 0) => gthtxn_out(1 downto 0),
      gthtxp_out(1 downto 0) => gthtxp_out(1 downto 0),
      gtnorthrefclk0_in(1 downto 0) => gtnorthrefclk0_in(1 downto 0),
      gtnorthrefclk1_in(1 downto 0) => gtnorthrefclk1_in(1 downto 0),
      gtpowergood_out(1 downto 0) => gtpowergood_out(1 downto 0),
      gtrefclk0_in(1 downto 0) => gtrefclk0_in(1 downto 0),
      gtrefclk1_in(1 downto 0) => gtrefclk1_in(1 downto 0),
      gtrefclkmonitor_out(1 downto 0) => gtrefclkmonitor_out(1 downto 0),
      gtresetsel_in(1 downto 0) => gtresetsel_in(1 downto 0),
      gtrsvd_in(31 downto 0) => gtrsvd_in(31 downto 0),
      gtsouthrefclk0_in(1 downto 0) => gtsouthrefclk0_in(1 downto 0),
      gtsouthrefclk1_in(1 downto 0) => gtsouthrefclk1_in(1 downto 0),
      gtwiz_userdata_tx_in(63 downto 0) => gtwiz_userdata_tx_in(63 downto 0),
      loopback_in(5 downto 0) => loopback_in(5 downto 0),
      lpbkrxtxseren_in(1 downto 0) => lpbkrxtxseren_in(1 downto 0),
      lpbktxrxseren_in(1 downto 0) => lpbktxrxseren_in(1 downto 0),
      pcieeqrxeqadaptdone_in(1 downto 0) => pcieeqrxeqadaptdone_in(1 downto 0),
      pcierategen3_out(1 downto 0) => pcierategen3_out(1 downto 0),
      pcierateidle_out(1 downto 0) => pcierateidle_out(1 downto 0),
      pcierateqpllpd_out(3 downto 0) => pcierateqpllpd_out(3 downto 0),
      pcierateqpllreset_out(3 downto 0) => pcierateqpllreset_out(3 downto 0),
      pcierstidle_in(1 downto 0) => pcierstidle_in(1 downto 0),
      pciersttxsyncstart_in(1 downto 0) => pciersttxsyncstart_in(1 downto 0),
      pciesynctxsyncdone_out(1 downto 0) => pciesynctxsyncdone_out(1 downto 0),
      pcieusergen3rdy_out(1 downto 0) => pcieusergen3rdy_out(1 downto 0),
      pcieuserphystatusrst_out(1 downto 0) => pcieuserphystatusrst_out(1 downto 0),
      pcieuserratedone_in(1 downto 0) => pcieuserratedone_in(1 downto 0),
      pcieuserratestart_out(1 downto 0) => pcieuserratestart_out(1 downto 0),
      pcsrsvdin2_in(9 downto 0) => pcsrsvdin2_in(9 downto 0),
      pcsrsvdin_in(31 downto 0) => pcsrsvdin_in(31 downto 0),
      pcsrsvdout_out(23 downto 0) => pcsrsvdout_out(23 downto 0),
      phystatus_out(1 downto 0) => phystatus_out(1 downto 0),
      pinrsrvdas_out(15 downto 0) => pinrsrvdas_out(15 downto 0),
      pmarsvdin_in(9 downto 0) => pmarsvdin_in(9 downto 0),
      qpll0outclk_out(0) => qpll0outclk_out(0),
      qpll0outrefclk_out(0) => qpll0outrefclk_out(0),
      qpll1outclk_out(0) => qpll1outclk_out(0),
      qpll1outrefclk_out(0) => qpll1outrefclk_out(0),
      resetexception_out(1 downto 0) => resetexception_out(1 downto 0),
      resetovrd_in(1 downto 0) => resetovrd_in(1 downto 0),
      rstclkentx_in(1 downto 0) => rstclkentx_in(1 downto 0),
      rx8b10ben_in(1 downto 0) => rx8b10ben_in(1 downto 0),
      rxbufreset_in(1 downto 0) => rxbufreset_in(1 downto 0),
      rxbufstatus_out(5 downto 0) => rxbufstatus_out(5 downto 0),
      rxbyteisaligned_out(1 downto 0) => rxbyteisaligned_out(1 downto 0),
      rxbyterealign_out(1 downto 0) => rxbyterealign_out(1 downto 0),
      rxcdrfreqreset_in(1 downto 0) => rxcdrfreqreset_in(1 downto 0),
      rxcdrhold_in(1 downto 0) => rxcdrhold_in(1 downto 0),
      rxcdrlock_out(1 downto 0) => rxcdrlock_out(1 downto 0),
      rxcdrovrden_in(1 downto 0) => rxcdrovrden_in(1 downto 0),
      rxcdrphdone_out(1 downto 0) => rxcdrphdone_out(1 downto 0),
      rxcdrreset_in(1 downto 0) => rxcdrreset_in(1 downto 0),
      rxcdrresetrsv_in(1 downto 0) => rxcdrresetrsv_in(1 downto 0),
      rxchanbondseq_out(1 downto 0) => rxchanbondseq_out(1 downto 0),
      rxchanisaligned_out(1 downto 0) => rxchanisaligned_out(1 downto 0),
      rxchanrealign_out(1 downto 0) => rxchanrealign_out(1 downto 0),
      rxchbonden_in(1 downto 0) => rxchbonden_in(1 downto 0),
      rxchbondi_in(9 downto 0) => rxchbondi_in(9 downto 0),
      rxchbondlevel_in(5 downto 0) => rxchbondlevel_in(5 downto 0),
      rxchbondmaster_in(1 downto 0) => rxchbondmaster_in(1 downto 0),
      rxchbondo_out(9 downto 0) => rxchbondo_out(9 downto 0),
      rxchbondslave_in(1 downto 0) => rxchbondslave_in(1 downto 0),
      rxclkcorcnt_out(3 downto 0) => rxclkcorcnt_out(3 downto 0),
      rxcominitdet_out(1 downto 0) => rxcominitdet_out(1 downto 0),
      rxcommadet_out(1 downto 0) => rxcommadet_out(1 downto 0),
      rxcommadeten_in(1 downto 0) => rxcommadeten_in(1 downto 0),
      rxcomsasdet_out(1 downto 0) => rxcomsasdet_out(1 downto 0),
      rxcomwakedet_out(1 downto 0) => rxcomwakedet_out(1 downto 0),
      rxctrl0_out(31 downto 0) => rxctrl0_out(31 downto 0),
      rxctrl1_out(31 downto 0) => rxctrl1_out(31 downto 0),
      rxctrl2_out(15 downto 0) => rxctrl2_out(15 downto 0),
      rxctrl3_out(15 downto 0) => rxctrl3_out(15 downto 0),
      rxdata_out(255 downto 0) => rxdata_out(255 downto 0),
      rxdataextendrsvd_out(15 downto 0) => rxdataextendrsvd_out(15 downto 0),
      rxdatavalid_out(3 downto 0) => rxdatavalid_out(3 downto 0),
      rxdfeagcctrl_in(3 downto 0) => rxdfeagcctrl_in(3 downto 0),
      rxdfeagchold_in(1 downto 0) => rxdfeagchold_in(1 downto 0),
      rxdfeagcovrden_in(1 downto 0) => rxdfeagcovrden_in(1 downto 0),
      rxdfelfhold_in(1 downto 0) => rxdfelfhold_in(1 downto 0),
      rxdfelfovrden_in(1 downto 0) => rxdfelfovrden_in(1 downto 0),
      rxdfelpmreset_in(1 downto 0) => rxdfelpmreset_in(1 downto 0),
      rxdfetap10hold_in(1 downto 0) => rxdfetap10hold_in(1 downto 0),
      rxdfetap10ovrden_in(1 downto 0) => rxdfetap10ovrden_in(1 downto 0),
      rxdfetap11hold_in(1 downto 0) => rxdfetap11hold_in(1 downto 0),
      rxdfetap11ovrden_in(1 downto 0) => rxdfetap11ovrden_in(1 downto 0),
      rxdfetap12hold_in(1 downto 0) => rxdfetap12hold_in(1 downto 0),
      rxdfetap12ovrden_in(1 downto 0) => rxdfetap12ovrden_in(1 downto 0),
      rxdfetap13hold_in(1 downto 0) => rxdfetap13hold_in(1 downto 0),
      rxdfetap13ovrden_in(1 downto 0) => rxdfetap13ovrden_in(1 downto 0),
      rxdfetap14hold_in(1 downto 0) => rxdfetap14hold_in(1 downto 0),
      rxdfetap14ovrden_in(1 downto 0) => rxdfetap14ovrden_in(1 downto 0),
      rxdfetap15hold_in(1 downto 0) => rxdfetap15hold_in(1 downto 0),
      rxdfetap15ovrden_in(1 downto 0) => rxdfetap15ovrden_in(1 downto 0),
      rxdfetap2hold_in(1 downto 0) => rxdfetap2hold_in(1 downto 0),
      rxdfetap2ovrden_in(1 downto 0) => rxdfetap2ovrden_in(1 downto 0),
      rxdfetap3hold_in(1 downto 0) => rxdfetap3hold_in(1 downto 0),
      rxdfetap3ovrden_in(1 downto 0) => rxdfetap3ovrden_in(1 downto 0),
      rxdfetap4hold_in(1 downto 0) => rxdfetap4hold_in(1 downto 0),
      rxdfetap4ovrden_in(1 downto 0) => rxdfetap4ovrden_in(1 downto 0),
      rxdfetap5hold_in(1 downto 0) => rxdfetap5hold_in(1 downto 0),
      rxdfetap5ovrden_in(1 downto 0) => rxdfetap5ovrden_in(1 downto 0),
      rxdfetap6hold_in(1 downto 0) => rxdfetap6hold_in(1 downto 0),
      rxdfetap6ovrden_in(1 downto 0) => rxdfetap6ovrden_in(1 downto 0),
      rxdfetap7hold_in(1 downto 0) => rxdfetap7hold_in(1 downto 0),
      rxdfetap7ovrden_in(1 downto 0) => rxdfetap7ovrden_in(1 downto 0),
      rxdfetap8hold_in(1 downto 0) => rxdfetap8hold_in(1 downto 0),
      rxdfetap8ovrden_in(1 downto 0) => rxdfetap8ovrden_in(1 downto 0),
      rxdfetap9hold_in(1 downto 0) => rxdfetap9hold_in(1 downto 0),
      rxdfetap9ovrden_in(1 downto 0) => rxdfetap9ovrden_in(1 downto 0),
      rxdfeuthold_in(1 downto 0) => rxdfeuthold_in(1 downto 0),
      rxdfeutovrden_in(1 downto 0) => rxdfeutovrden_in(1 downto 0),
      rxdfevphold_in(1 downto 0) => rxdfevphold_in(1 downto 0),
      rxdfevpovrden_in(1 downto 0) => rxdfevpovrden_in(1 downto 0),
      rxdfevsen_in(1 downto 0) => rxdfevsen_in(1 downto 0),
      rxdfexyden_in(1 downto 0) => rxdfexyden_in(1 downto 0),
      rxdlybypass_in(1 downto 0) => rxdlybypass_in(1 downto 0),
      rxdlyen_in(1 downto 0) => rxdlyen_in(1 downto 0),
      rxdlyovrden_in(1 downto 0) => rxdlyovrden_in(1 downto 0),
      rxdlysreset_in(1 downto 0) => rxdlysreset_in(1 downto 0),
      rxdlysresetdone_out(1 downto 0) => rxdlysresetdone_out(1 downto 0),
      rxelecidle_out(1 downto 0) => rxelecidle_out(1 downto 0),
      rxelecidlemode_in(3 downto 0) => rxelecidlemode_in(3 downto 0),
      rxgearboxslip_in(1 downto 0) => rxgearboxslip_in(1 downto 0),
      rxheader_out(11 downto 0) => rxheader_out(11 downto 0),
      rxheadervalid_out(3 downto 0) => rxheadervalid_out(3 downto 0),
      rxlatclk_in(1 downto 0) => rxlatclk_in(1 downto 0),
      rxlpmen_in(1 downto 0) => rxlpmen_in(1 downto 0),
      rxlpmgchold_in(1 downto 0) => rxlpmgchold_in(1 downto 0),
      rxlpmgcovrden_in(1 downto 0) => rxlpmgcovrden_in(1 downto 0),
      rxlpmhfhold_in(1 downto 0) => rxlpmhfhold_in(1 downto 0),
      rxlpmhfovrden_in(1 downto 0) => rxlpmhfovrden_in(1 downto 0),
      rxlpmlfhold_in(1 downto 0) => rxlpmlfhold_in(1 downto 0),
      rxlpmlfklovrden_in(1 downto 0) => rxlpmlfklovrden_in(1 downto 0),
      rxlpmoshold_in(1 downto 0) => rxlpmoshold_in(1 downto 0),
      rxlpmosovrden_in(1 downto 0) => rxlpmosovrden_in(1 downto 0),
      rxmcommaalignen_in(1 downto 0) => rxmcommaalignen_in(1 downto 0),
      rxmonitorout_out(13 downto 0) => rxmonitorout_out(13 downto 0),
      rxmonitorsel_in(3 downto 0) => rxmonitorsel_in(3 downto 0),
      rxoobreset_in(1 downto 0) => rxoobreset_in(1 downto 0),
      rxoscalreset_in(1 downto 0) => rxoscalreset_in(1 downto 0),
      rxoshold_in(1 downto 0) => rxoshold_in(1 downto 0),
      rxosintcfg_in(7 downto 0) => rxosintcfg_in(7 downto 0),
      rxosintdone_out(1 downto 0) => rxosintdone_out(1 downto 0),
      rxosinten_in(1 downto 0) => rxosinten_in(1 downto 0),
      rxosinthold_in(1 downto 0) => rxosinthold_in(1 downto 0),
      rxosintovrden_in(1 downto 0) => rxosintovrden_in(1 downto 0),
      rxosintstarted_out(1 downto 0) => rxosintstarted_out(1 downto 0),
      rxosintstrobe_in(1 downto 0) => rxosintstrobe_in(1 downto 0),
      rxosintstrobedone_out(1 downto 0) => rxosintstrobedone_out(1 downto 0),
      rxosintstrobestarted_out(1 downto 0) => rxosintstrobestarted_out(1 downto 0),
      rxosinttestovrden_in(1 downto 0) => rxosinttestovrden_in(1 downto 0),
      rxosovrden_in(1 downto 0) => rxosovrden_in(1 downto 0),
      rxoutclk_out(1 downto 0) => rxoutclk_out(1 downto 0),
      rxoutclkfabric_out(1 downto 0) => rxoutclkfabric_out(1 downto 0),
      rxoutclkpcs_out(1 downto 0) => rxoutclkpcs_out(1 downto 0),
      rxoutclksel_in(5 downto 0) => rxoutclksel_in(5 downto 0),
      rxpcommaalignen_in(1 downto 0) => rxpcommaalignen_in(1 downto 0),
      rxpcsreset_in(1 downto 0) => rxpcsreset_in(1 downto 0),
      rxpd_in(3 downto 0) => rxpd_in(3 downto 0),
      rxphalign_in(1 downto 0) => rxphalign_in(1 downto 0),
      rxphaligndone_out(1 downto 0) => rxphaligndone_out(1 downto 0),
      rxphalignen_in(1 downto 0) => rxphalignen_in(1 downto 0),
      rxphalignerr_out(1 downto 0) => rxphalignerr_out(1 downto 0),
      rxphdlypd_in(1 downto 0) => rxphdlypd_in(1 downto 0),
      rxphdlyreset_in(1 downto 0) => rxphdlyreset_in(1 downto 0),
      rxphovrden_in(1 downto 0) => rxphovrden_in(1 downto 0),
      rxpllclksel_in(3 downto 0) => rxpllclksel_in(3 downto 0),
      rxpmareset_in(1 downto 0) => rxpmareset_in(1 downto 0),
      rxpmaresetdone_out(1 downto 0) => rxpmaresetdone_out(1 downto 0),
      rxpolarity_in(1 downto 0) => rxpolarity_in(1 downto 0),
      rxprbscntreset_in(1 downto 0) => rxprbscntreset_in(1 downto 0),
      rxprbserr_out(1 downto 0) => rxprbserr_out(1 downto 0),
      rxprbslocked_out(1 downto 0) => rxprbslocked_out(1 downto 0),
      rxprbssel_in(7 downto 0) => rxprbssel_in(7 downto 0),
      rxprgdivresetdone_out(1 downto 0) => rxprgdivresetdone_out(1 downto 0),
      rxqpien_in(1 downto 0) => rxqpien_in(1 downto 0),
      rxqpisenn_out(1 downto 0) => rxqpisenn_out(1 downto 0),
      rxqpisenp_out(1 downto 0) => rxqpisenp_out(1 downto 0),
      rxrate_in(5 downto 0) => rxrate_in(5 downto 0),
      rxratedone_out(1 downto 0) => rxratedone_out(1 downto 0),
      rxratemode_in(1 downto 0) => rxratemode_in(1 downto 0),
      rxrecclkout_out(1 downto 0) => rxrecclkout_out(1 downto 0),
      rxresetdone_out(1 downto 0) => rxresetdone_out(1 downto 0),
      rxslide_in(1 downto 0) => rxslide_in(1 downto 0),
      rxsliderdy_out(1 downto 0) => rxsliderdy_out(1 downto 0),
      rxslipdone_out(1 downto 0) => rxslipdone_out(1 downto 0),
      rxslipoutclk_in(1 downto 0) => rxslipoutclk_in(1 downto 0),
      rxslipoutclkrdy_out(1 downto 0) => rxslipoutclkrdy_out(1 downto 0),
      rxslippma_in(1 downto 0) => rxslippma_in(1 downto 0),
      rxslippmardy_out(1 downto 0) => rxslippmardy_out(1 downto 0),
      rxstartofseq_out(3 downto 0) => rxstartofseq_out(3 downto 0),
      rxstatus_out(5 downto 0) => rxstatus_out(5 downto 0),
      rxsyncallin_in(1 downto 0) => rxsyncallin_in(1 downto 0),
      rxsyncdone_out(1 downto 0) => rxsyncdone_out(1 downto 0),
      rxsyncin_in(1 downto 0) => rxsyncin_in(1 downto 0),
      rxsyncmode_in(1 downto 0) => rxsyncmode_in(1 downto 0),
      rxsyncout_out(1 downto 0) => rxsyncout_out(1 downto 0),
      rxsysclksel_in(3 downto 0) => rxsysclksel_in(3 downto 0),
      rxusrclk2_in(1 downto 0) => rxusrclk2_in(1 downto 0),
      rxusrclk_in(1 downto 0) => rxusrclk_in(1 downto 0),
      rxvalid_out(1 downto 0) => rxvalid_out(1 downto 0),
      sigvalidclk_in(1 downto 0) => sigvalidclk_in(1 downto 0),
      tx8b10bbypass_in(15 downto 0) => tx8b10bbypass_in(15 downto 0),
      tx8b10ben_in(1 downto 0) => tx8b10ben_in(1 downto 0),
      txbufdiffctrl_in(5 downto 0) => txbufdiffctrl_in(5 downto 0),
      txbufstatus_out(3 downto 0) => txbufstatus_out(3 downto 0),
      txcomfinish_out(1 downto 0) => txcomfinish_out(1 downto 0),
      txcominit_in(1 downto 0) => txcominit_in(1 downto 0),
      txcomsas_in(1 downto 0) => txcomsas_in(1 downto 0),
      txcomwake_in(1 downto 0) => txcomwake_in(1 downto 0),
      txctrl0_in(31 downto 0) => txctrl0_in(31 downto 0),
      txctrl1_in(31 downto 0) => txctrl1_in(31 downto 0),
      txctrl2_in(15 downto 0) => txctrl2_in(15 downto 0),
      txdataextendrsvd_in(15 downto 0) => txdataextendrsvd_in(15 downto 0),
      txdeemph_in(1 downto 0) => txdeemph_in(1 downto 0),
      txdetectrx_in(1 downto 0) => txdetectrx_in(1 downto 0),
      txdiffctrl_in(7 downto 0) => txdiffctrl_in(7 downto 0),
      txdiffpd_in(1 downto 0) => txdiffpd_in(1 downto 0),
      txdlybypass_in(1 downto 0) => txdlybypass_in(1 downto 0),
      txdlyen_in(1 downto 0) => txdlyen_in(1 downto 0),
      txdlyhold_in(1 downto 0) => txdlyhold_in(1 downto 0),
      txdlyovrden_in(1 downto 0) => txdlyovrden_in(1 downto 0),
      txdlysreset_in(1 downto 0) => txdlysreset_in(1 downto 0),
      txdlysresetdone_out(1 downto 0) => txdlysresetdone_out(1 downto 0),
      txdlyupdown_in(1 downto 0) => txdlyupdown_in(1 downto 0),
      txelecidle_in(1 downto 0) => txelecidle_in(1 downto 0),
      txheader_in(11 downto 0) => txheader_in(11 downto 0),
      txinhibit_in(1 downto 0) => txinhibit_in(1 downto 0),
      txlatclk_in(1 downto 0) => txlatclk_in(1 downto 0),
      txmaincursor_in(13 downto 0) => txmaincursor_in(13 downto 0),
      txmargin_in(5 downto 0) => txmargin_in(5 downto 0),
      txoutclk_out(1 downto 0) => txoutclk_out(1 downto 0),
      txoutclkfabric_out(1 downto 0) => txoutclkfabric_out(1 downto 0),
      txoutclkpcs_out(1 downto 0) => txoutclkpcs_out(1 downto 0),
      txoutclksel_in(5 downto 0) => txoutclksel_in(5 downto 0),
      txpcsreset_in(1 downto 0) => txpcsreset_in(1 downto 0),
      txpd_in(3 downto 0) => txpd_in(3 downto 0),
      txpdelecidlemode_in(1 downto 0) => txpdelecidlemode_in(1 downto 0),
      txphalign_in(1 downto 0) => txphalign_in(1 downto 0),
      txphaligndone_out(1 downto 0) => txphaligndone_out(1 downto 0),
      txphalignen_in(1 downto 0) => txphalignen_in(1 downto 0),
      txphdlypd_in(1 downto 0) => txphdlypd_in(1 downto 0),
      txphdlyreset_in(1 downto 0) => txphdlyreset_in(1 downto 0),
      txphdlytstclk_in(1 downto 0) => txphdlytstclk_in(1 downto 0),
      txphinit_in(1 downto 0) => txphinit_in(1 downto 0),
      txphinitdone_out(1 downto 0) => txphinitdone_out(1 downto 0),
      txphovrden_in(1 downto 0) => txphovrden_in(1 downto 0),
      txpippmen_in(1 downto 0) => txpippmen_in(1 downto 0),
      txpippmovrden_in(1 downto 0) => txpippmovrden_in(1 downto 0),
      txpippmpd_in(1 downto 0) => txpippmpd_in(1 downto 0),
      txpippmsel_in(1 downto 0) => txpippmsel_in(1 downto 0),
      txpippmstepsize_in(9 downto 0) => txpippmstepsize_in(9 downto 0),
      txpisopd_in(1 downto 0) => txpisopd_in(1 downto 0),
      txpllclksel_in(3 downto 0) => txpllclksel_in(3 downto 0),
      txpmareset_in(1 downto 0) => txpmareset_in(1 downto 0),
      txpmaresetdone_out(1 downto 0) => txpmaresetdone_out(1 downto 0),
      txpolarity_in(1 downto 0) => txpolarity_in(1 downto 0),
      txpostcursor_in(9 downto 0) => txpostcursor_in(9 downto 0),
      txpostcursorinv_in(1 downto 0) => txpostcursorinv_in(1 downto 0),
      txprbsforceerr_in(1 downto 0) => txprbsforceerr_in(1 downto 0),
      txprbssel_in(7 downto 0) => txprbssel_in(7 downto 0),
      txprecursor_in(9 downto 0) => txprecursor_in(9 downto 0),
      txprecursorinv_in(1 downto 0) => txprecursorinv_in(1 downto 0),
      txprgdivresetdone_out(1 downto 0) => txprgdivresetdone_out(1 downto 0),
      txqpibiasen_in(1 downto 0) => txqpibiasen_in(1 downto 0),
      txqpisenn_out(1 downto 0) => txqpisenn_out(1 downto 0),
      txqpisenp_out(1 downto 0) => txqpisenp_out(1 downto 0),
      txqpistrongpdown_in(1 downto 0) => txqpistrongpdown_in(1 downto 0),
      txqpiweakpup_in(1 downto 0) => txqpiweakpup_in(1 downto 0),
      txrate_in(5 downto 0) => txrate_in(5 downto 0),
      txratedone_out(1 downto 0) => txratedone_out(1 downto 0),
      txratemode_in(1 downto 0) => txratemode_in(1 downto 0),
      txresetdone_out(1 downto 0) => txresetdone_out(1 downto 0),
      txsequence_in(13 downto 0) => txsequence_in(13 downto 0),
      txswing_in(1 downto 0) => txswing_in(1 downto 0),
      txsyncallin_in(1 downto 0) => txsyncallin_in(1 downto 0),
      txsyncdone_out(1 downto 0) => txsyncdone_out(1 downto 0),
      txsyncin_in(1 downto 0) => txsyncin_in(1 downto 0),
      txsyncmode_in(1 downto 0) => txsyncmode_in(1 downto 0),
      txsyncout_out(1 downto 0) => txsyncout_out(1 downto 0),
      txsysclksel_in(3 downto 0) => txsysclksel_in(3 downto 0),
      txusrclk2_in(1 downto 0) => txusrclk2_in(1 downto 0),
      txusrclk_in(1 downto 0) => txusrclk_in(1 downto 0)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper is
  port (
    drprdy_common_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    O1 : out STD_LOGIC;
    qpll0outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor0_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor1_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    drpdo_common_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxrecclk0_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclk1_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pmarsvdout0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pmarsvdout1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rst_in0 : out STD_LOGIC;
    drpclk_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpen_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpwe_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll0reset_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpdi_common_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    qpll0refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpll1refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpllrsvd2_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd3_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd1_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    qpllrsvd4_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    drpaddr_common_in : in STD_LOGIC_VECTOR ( 8 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper : entity is "GthUltrascaleJesdCoregen_gthe3_common_wrapper";
end GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper;

architecture STRUCTURE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper is
begin
common_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common
    port map (
      O1 => O1,
      drpaddr_common_in(8 downto 0) => drpaddr_common_in(8 downto 0),
      drpclk_common_in(0) => drpclk_common_in(0),
      drpdi_common_in(15 downto 0) => drpdi_common_in(15 downto 0),
      drpdo_common_out(15 downto 0) => drpdo_common_out(15 downto 0),
      drpen_common_in(0) => drpen_common_in(0),
      drprdy_common_out(0) => drprdy_common_out(0),
      drpwe_common_in(0) => drpwe_common_in(0),
      gtgrefclk0_in(0) => gtgrefclk0_in(0),
      gtgrefclk1_in(0) => gtgrefclk1_in(0),
      gtnorthrefclk00_in(0) => gtnorthrefclk00_in(0),
      gtnorthrefclk01_in(0) => gtnorthrefclk01_in(0),
      gtnorthrefclk10_in(0) => gtnorthrefclk10_in(0),
      gtnorthrefclk11_in(0) => gtnorthrefclk11_in(0),
      gtrefclk00_in(0) => gtrefclk00_in(0),
      gtrefclk01_in(0) => gtrefclk01_in(0),
      gtrefclk10_in(0) => gtrefclk10_in(0),
      gtrefclk11_in(0) => gtrefclk11_in(0),
      gtsouthrefclk00_in(0) => gtsouthrefclk00_in(0),
      gtsouthrefclk01_in(0) => gtsouthrefclk01_in(0),
      gtsouthrefclk10_in(0) => gtsouthrefclk10_in(0),
      gtsouthrefclk11_in(0) => gtsouthrefclk11_in(0),
      gtwiz_reset_qpll0reset_out(0) => gtwiz_reset_qpll0reset_out(0),
      pmarsvdout0_out(7 downto 0) => pmarsvdout0_out(7 downto 0),
      pmarsvdout1_out(7 downto 0) => pmarsvdout1_out(7 downto 0),
      qpll0clkrsvd0_in(0) => qpll0clkrsvd0_in(0),
      qpll0clkrsvd1_in(0) => qpll0clkrsvd1_in(0),
      qpll0fbclklost_out(0) => qpll0fbclklost_out(0),
      qpll0lockdetclk_in(0) => qpll0lockdetclk_in(0),
      qpll0locken_in(0) => qpll0locken_in(0),
      qpll0outclk_out(0) => qpll0outclk_out(0),
      qpll0outrefclk_out(0) => qpll0outrefclk_out(0),
      qpll0pd_in(0) => qpll0pd_in(0),
      qpll0refclklost_out(0) => qpll0refclklost_out(0),
      qpll0refclksel_in(2 downto 0) => qpll0refclksel_in(2 downto 0),
      qpll1clkrsvd0_in(0) => qpll1clkrsvd0_in(0),
      qpll1clkrsvd1_in(0) => qpll1clkrsvd1_in(0),
      qpll1fbclklost_out(0) => qpll1fbclklost_out(0),
      qpll1lock_out(0) => qpll1lock_out(0),
      qpll1lockdetclk_in(0) => qpll1lockdetclk_in(0),
      qpll1locken_in(0) => qpll1locken_in(0),
      qpll1outclk_out(0) => qpll1outclk_out(0),
      qpll1outrefclk_out(0) => qpll1outrefclk_out(0),
      qpll1pd_in(0) => qpll1pd_in(0),
      qpll1refclklost_out(0) => qpll1refclklost_out(0),
      qpll1refclksel_in(2 downto 0) => qpll1refclksel_in(2 downto 0),
      qpll1reset_in(0) => qpll1reset_in(0),
      qplldmonitor0_out(7 downto 0) => qplldmonitor0_out(7 downto 0),
      qplldmonitor1_out(7 downto 0) => qplldmonitor1_out(7 downto 0),
      qpllrsvd1_in(7 downto 0) => qpllrsvd1_in(7 downto 0),
      qpllrsvd2_in(4 downto 0) => qpllrsvd2_in(4 downto 0),
      qpllrsvd3_in(4 downto 0) => qpllrsvd3_in(4 downto 0),
      qpllrsvd4_in(7 downto 0) => qpllrsvd4_in(7 downto 0),
      refclkoutmonitor0_out(0) => refclkoutmonitor0_out(0),
      refclkoutmonitor1_out(0) => refclkoutmonitor1_out(0),
      rst_in0 => rst_in0,
      rxrecclk0_sel_out(1 downto 0) => rxrecclk0_sel_out(1 downto 0),
      rxrecclk1_sel_out(1 downto 0) => rxrecclk1_sel_out(1 downto 0)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset is
  port (
    GTHE3_CHANNEL_TXPROGDIVRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    GTHE3_CHANNEL_RXPROGDIVRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    GTHE3_CHANNEL_TXUSERRDY : out STD_LOGIC_VECTOR ( 0 to 0 );
    GTHE3_CHANNEL_RXUSERRDY : out STD_LOGIC_VECTOR ( 0 to 0 );
    GTHE3_CHANNEL_GTTXRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    GTHE3_CHANNEL_GTRXRESET : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll0reset_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    I1 : in STD_LOGIC;
    gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lock_out : in STD_LOGIC_VECTOR ( 0 to 0 );
    I2 : in STD_LOGIC;
    gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    I3 : in STD_LOGIC;
    I4 : in STD_LOGIC;
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rst_in0 : in STD_LOGIC;
    txusrclk2_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset : entity is "gtwizard_ultrascale_v1_4_gtwiz_reset";
end GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset;

architecture STRUCTURE of GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset is
  signal \^gthe3_channel_gtrxreset\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^gthe3_channel_gttxreset\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^gthe3_channel_rxuserrdy\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^gthe3_channel_txuserrdy\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal gtwiz_reset_all_sync : STD_LOGIC;
  signal gtwiz_reset_pllreset_rx_int : STD_LOGIC;
  signal gtwiz_reset_pllreset_tx_int : STD_LOGIC;
  signal gtwiz_reset_rx_any_sync : STD_LOGIC;
  signal gtwiz_reset_rx_datapath_dly : STD_LOGIC;
  signal gtwiz_reset_rx_datapath_sync : STD_LOGIC;
  signal gtwiz_reset_rx_pll_and_datapath_dly : STD_LOGIC;
  signal gtwiz_reset_rx_pll_and_datapath_sync : STD_LOGIC;
  signal gtwiz_reset_tx_any_sync : STD_LOGIC;
  signal gtwiz_reset_tx_datapath_dly : STD_LOGIC;
  signal gtwiz_reset_tx_datapath_sync : STD_LOGIC;
  signal gtwiz_reset_tx_done_int0 : STD_LOGIC;
  signal gtwiz_reset_tx_pll_and_datapath_sync : STD_LOGIC;
  signal gtwiz_reset_userclk_rx_active_sync : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[0]_i_1\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[1]_i_1\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[2]_i_1\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[2]_i_2\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all[3]_i_3\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_all_reg[0]\ : STD_LOGIC;
  attribute RTL_KEEP : string;
  attribute RTL_KEEP of \n_0_FSM_sequential_sm_reset_all_reg[0]\ : signal is "yes";
  signal \n_0_FSM_sequential_sm_reset_all_reg[1]\ : STD_LOGIC;
  attribute RTL_KEEP of \n_0_FSM_sequential_sm_reset_all_reg[1]\ : signal is "yes";
  signal \n_0_FSM_sequential_sm_reset_all_reg[2]\ : STD_LOGIC;
  attribute RTL_KEEP of \n_0_FSM_sequential_sm_reset_all_reg[2]\ : signal is "yes";
  signal \n_0_FSM_sequential_sm_reset_all_reg[3]\ : STD_LOGIC;
  attribute RTL_KEEP of \n_0_FSM_sequential_sm_reset_all_reg[3]\ : signal is "yes";
  signal \n_0_FSM_sequential_sm_reset_rx[1]_i_2\ : STD_LOGIC;
  signal \n_0_FSM_sequential_sm_reset_tx[2]_i_2\ : STD_LOGIC;
  signal n_0_bit_synchronizer_gtpowergood_inst : STD_LOGIC;
  signal n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst : STD_LOGIC;
  signal n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst : STD_LOGIC;
  signal n_0_bit_synchronizer_plllock_rx_inst : STD_LOGIC;
  signal n_0_gtwiz_reset_rx_datapath_int_i_1 : STD_LOGIC;
  signal n_0_gtwiz_reset_rx_datapath_int_reg : STD_LOGIC;
  signal n_0_gtwiz_reset_rx_done_int_reg : STD_LOGIC;
  signal n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1 : STD_LOGIC;
  signal n_0_gtwiz_reset_rx_pll_and_datapath_int_reg : STD_LOGIC;
  signal n_0_gtwiz_reset_tx_done_int_reg : STD_LOGIC;
  signal n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1 : STD_LOGIC;
  signal n_0_gtwiz_reset_tx_pll_and_datapath_int_reg : STD_LOGIC;
  signal n_0_sm_reset_all_timer_clr_i_1 : STD_LOGIC;
  signal n_0_sm_reset_all_timer_clr_i_2 : STD_LOGIC;
  signal n_0_sm_reset_all_timer_clr_reg : STD_LOGIC;
  signal \n_0_sm_reset_all_timer_ctr[0]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_all_timer_ctr[1]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_all_timer_ctr[2]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_all_timer_ctr[2]_i_2\ : STD_LOGIC;
  signal n_0_sm_reset_all_timer_sat_i_1 : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr[0]_i_3\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1\ : STD_LOGIC;
  signal n_0_sm_reset_rx_cdr_to_sat_i_1 : STD_LOGIC;
  signal n_0_sm_reset_rx_cdr_to_sat_i_2 : STD_LOGIC;
  signal n_0_sm_reset_rx_cdr_to_sat_i_3 : STD_LOGIC;
  signal n_0_sm_reset_rx_cdr_to_sat_i_4 : STD_LOGIC;
  signal n_0_sm_reset_rx_cdr_to_sat_i_5 : STD_LOGIC;
  signal n_0_sm_reset_rx_timer_clr_reg : STD_LOGIC;
  signal \n_0_sm_reset_rx_timer_ctr[0]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_timer_ctr[1]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_timer_ctr[2]_i_1\ : STD_LOGIC;
  signal \n_0_sm_reset_rx_timer_ctr[2]_i_2\ : STD_LOGIC;
  signal n_0_sm_reset_rx_timer_sat_i_1 : STD_LOGIC;
  signal n_0_sm_reset_tx_timer_clr_reg : STD_LOGIC;
  signal \n_0_sm_reset_tx_timer_ctr[2]_i_1\ : STD_LOGIC;
  signal n_0_sm_reset_tx_timer_sat_i_1 : STD_LOGIC;
  signal n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_plllock_rx_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_plllock_tx_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_rxcdrlock_inst : STD_LOGIC;
  signal n_1_bit_synchronizer_rxresetdone_inst : STD_LOGIC;
  signal n_1_reset_synchronizer_gtwiz_reset_rx_any_inst : STD_LOGIC;
  signal n_1_reset_synchronizer_gtwiz_reset_tx_any_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_plllock_rx_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_plllock_tx_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_rxcdrlock_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_rxresetdone_inst : STD_LOGIC;
  signal n_2_bit_synchronizer_txresetdone_inst : STD_LOGIC;
  signal n_3_bit_synchronizer_plllock_rx_inst : STD_LOGIC;
  signal n_3_bit_synchronizer_plllock_tx_inst : STD_LOGIC;
  signal n_3_bit_synchronizer_rxresetdone_inst : STD_LOGIC;
  signal n_4_bit_synchronizer_plllock_rx_inst : STD_LOGIC;
  signal n_4_bit_synchronizer_rxresetdone_inst : STD_LOGIC;
  signal p_0_in10_out : STD_LOGIC;
  signal p_1_in : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal plllock_tx_sync : STD_LOGIC;
  signal sel : STD_LOGIC;
  signal sm_reset_all_timer_ctr : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal sm_reset_all_timer_sat : STD_LOGIC;
  signal sm_reset_rx : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal sm_reset_rx_cdr_to_clr : STD_LOGIC;
  signal sm_reset_rx_cdr_to_ctr_reg : STD_LOGIC_VECTOR ( 21 downto 0 );
  signal sm_reset_rx_cdr_to_sat : STD_LOGIC;
  signal sm_reset_rx_timer_ctr : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal sm_reset_rx_timer_sat : STD_LOGIC;
  signal sm_reset_tx : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal sm_reset_tx_timer_clr0 : STD_LOGIC;
  signal sm_reset_tx_timer_ctr : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal sm_reset_tx_timer_sat : STD_LOGIC;
  signal txresetdone_sync : STD_LOGIC;
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_DI_UNCONNECTED\ : STD_LOGIC_VECTOR ( 7 downto 5 );
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 7 downto 6 );
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_S_UNCONNECTED\ : STD_LOGIC_VECTOR ( 7 downto 6 );
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 6 downto 0 );
  attribute KEEP : string;
  attribute KEEP of \FSM_sequential_sm_reset_all_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_all_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_all_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_all_reg[3]\ : label is "yes";
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of \FSM_sequential_sm_reset_rx[1]_i_2\ : label is "soft_lutpair3";
  attribute KEEP of \FSM_sequential_sm_reset_rx_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_rx_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_rx_reg[2]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_tx_reg[0]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_tx_reg[1]\ : label is "yes";
  attribute KEEP of \FSM_sequential_sm_reset_tx_reg[2]\ : label is "yes";
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of pllreset_rx_out_reg : label is "FDE";
  attribute XILINX_LEGACY_PRIM of rxuserrdy_out_reg : label is "FDE";
  attribute SOFT_HLUTNM of \sm_reset_all_timer_ctr[1]_i_1\ : label is "soft_lutpair4";
  attribute SOFT_HLUTNM of \sm_reset_all_timer_ctr[2]_i_2\ : label is "soft_lutpair4";
  attribute XILINX_LEGACY_PRIM of \sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8\ : label is "(CARRY4)";
  attribute XILINX_TRANSFORM_PINMAP : string;
  attribute XILINX_TRANSFORM_PINMAP of \sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8\ : label is "LO:O";
  attribute XILINX_LEGACY_PRIM of \sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8\ : label is "(CARRY4)";
  attribute XILINX_TRANSFORM_PINMAP of \sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8\ : label is "LO:O";
  attribute XILINX_LEGACY_PRIM of \sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8\ : label is "(CARRY4)";
  attribute XILINX_TRANSFORM_PINMAP of \sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8\ : label is "LO:O";
  attribute SOFT_HLUTNM of \sm_reset_rx_timer_ctr[1]_i_1\ : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of \sm_reset_rx_timer_ctr[2]_i_2\ : label is "soft_lutpair5";
  attribute SOFT_HLUTNM of sm_reset_rx_timer_sat_i_1 : label is "soft_lutpair3";
  attribute SOFT_HLUTNM of \sm_reset_tx_timer_ctr[1]_i_1\ : label is "soft_lutpair6";
  attribute SOFT_HLUTNM of \sm_reset_tx_timer_ctr[2]_i_2\ : label is "soft_lutpair6";
  attribute XILINX_LEGACY_PRIM of txuserrdy_out_reg : label is "FDE";
begin
  GTHE3_CHANNEL_GTRXRESET(0) <= \^gthe3_channel_gtrxreset\(0);
  GTHE3_CHANNEL_GTTXRESET(0) <= \^gthe3_channel_gttxreset\(0);
  GTHE3_CHANNEL_RXUSERRDY(0) <= \^gthe3_channel_rxuserrdy\(0);
  GTHE3_CHANNEL_TXUSERRDY(0) <= \^gthe3_channel_txuserrdy\(0);
\FSM_sequential_sm_reset_all[0]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0000A803"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all[2]_i_2\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I4 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      O => \n_0_FSM_sequential_sm_reset_all[0]_i_1\
    );
\FSM_sequential_sm_reset_all[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"06"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      O => \n_0_FSM_sequential_sm_reset_all[1]_i_1\
    );
\FSM_sequential_sm_reset_all[2]_i_1\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0000F200"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I3 => \n_0_FSM_sequential_sm_reset_all[2]_i_2\,
      I4 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      O => \n_0_FSM_sequential_sm_reset_all[2]_i_1\
    );
\FSM_sequential_sm_reset_all[2]_i_2\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"7555FFFF"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I1 => n_0_sm_reset_all_timer_clr_reg,
      I2 => sm_reset_all_timer_sat,
      I3 => n_0_gtwiz_reset_rx_done_int_reg,
      I4 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      O => \n_0_FSM_sequential_sm_reset_all[2]_i_2\
    );
\FSM_sequential_sm_reset_all[3]_i_3\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"08FF"
    )
    port map (
      I0 => n_0_gtwiz_reset_rx_done_int_reg,
      I1 => sm_reset_all_timer_sat,
      I2 => n_0_sm_reset_all_timer_clr_reg,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      O => \n_0_FSM_sequential_sm_reset_all[3]_i_3\
    );
\FSM_sequential_sm_reset_all_reg[0]\: unisim.vcomponents.FDSE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_0_bit_synchronizer_gtpowergood_inst,
      D => \n_0_FSM_sequential_sm_reset_all[0]_i_1\,
      Q => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      S => gtwiz_reset_all_sync
    );
\FSM_sequential_sm_reset_all_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_0_bit_synchronizer_gtpowergood_inst,
      D => \n_0_FSM_sequential_sm_reset_all[1]_i_1\,
      Q => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      R => gtwiz_reset_all_sync
    );
\FSM_sequential_sm_reset_all_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_0_bit_synchronizer_gtpowergood_inst,
      D => \n_0_FSM_sequential_sm_reset_all[2]_i_1\,
      Q => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      R => gtwiz_reset_all_sync
    );
\FSM_sequential_sm_reset_all_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_0_bit_synchronizer_gtpowergood_inst,
      D => '0',
      Q => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      R => gtwiz_reset_all_sync
    );
\FSM_sequential_sm_reset_rx[1]_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => sm_reset_rx_timer_sat,
      I1 => n_0_sm_reset_rx_timer_clr_reg,
      O => \n_0_FSM_sequential_sm_reset_rx[1]_i_2\
    );
\FSM_sequential_sm_reset_rx_reg[0]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_4_bit_synchronizer_plllock_rx_inst,
      D => n_3_bit_synchronizer_rxresetdone_inst,
      Q => sm_reset_rx(0),
      R => gtwiz_reset_rx_any_sync
    );
\FSM_sequential_sm_reset_rx_reg[1]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_4_bit_synchronizer_plllock_rx_inst,
      D => n_2_bit_synchronizer_rxresetdone_inst,
      Q => sm_reset_rx(1),
      R => gtwiz_reset_rx_any_sync
    );
\FSM_sequential_sm_reset_rx_reg[2]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_4_bit_synchronizer_plllock_rx_inst,
      D => n_1_bit_synchronizer_rxresetdone_inst,
      Q => sm_reset_rx(2),
      R => gtwiz_reset_rx_any_sync
    );
\FSM_sequential_sm_reset_tx[2]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"38"
    )
    port map (
      I0 => sm_reset_tx(0),
      I1 => sm_reset_tx(1),
      I2 => sm_reset_tx(2),
      O => \n_0_FSM_sequential_sm_reset_tx[2]_i_2\
    );
\FSM_sequential_sm_reset_tx_reg[0]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_2_bit_synchronizer_txresetdone_inst,
      D => n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      Q => sm_reset_tx(0),
      R => gtwiz_reset_tx_any_sync
    );
\FSM_sequential_sm_reset_tx_reg[1]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_2_bit_synchronizer_txresetdone_inst,
      D => n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      Q => sm_reset_tx(1),
      R => gtwiz_reset_tx_any_sync
    );
\FSM_sequential_sm_reset_tx_reg[2]\: unisim.vcomponents.FDRE
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => n_2_bit_synchronizer_txresetdone_inst,
      D => \n_0_FSM_sequential_sm_reset_tx[2]_i_2\,
      Q => sm_reset_tx(2),
      R => gtwiz_reset_tx_any_sync
    );
bit_synchronizer_gtpowergood_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer
    port map (
      E(0) => n_0_bit_synchronizer_gtpowergood_inst,
      I1 => I1,
      I2 => \n_0_FSM_sequential_sm_reset_all[3]_i_3\,
      I3 => n_0_gtwiz_reset_tx_done_int_reg,
      I4 => n_0_sm_reset_all_timer_clr_reg,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      \out\(3) => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      \out\(2) => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      \out\(1) => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      \out\(0) => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      sm_reset_all_timer_sat => sm_reset_all_timer_sat
    );
bit_synchronizer_gtwiz_reset_rx_datapath_dly_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0
    port map (
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_datapath_dly => gtwiz_reset_rx_datapath_dly,
      gtwiz_reset_rx_datapath_sync => gtwiz_reset_rx_datapath_sync
    );
bit_synchronizer_gtwiz_reset_rx_pll_and_datapath_dly_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1
    port map (
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_pll_and_datapath_dly => gtwiz_reset_rx_pll_and_datapath_dly,
      gtwiz_reset_rx_pll_and_datapath_sync => gtwiz_reset_rx_pll_and_datapath_sync
    );
bit_synchronizer_gtwiz_reset_tx_datapath_dly_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2
    port map (
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_datapath_dly => gtwiz_reset_tx_datapath_dly,
      gtwiz_reset_tx_datapath_sync => gtwiz_reset_tx_datapath_sync
    );
bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3
    port map (
      D(1) => n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      D(0) => n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      I1 => n_0_sm_reset_tx_timer_clr_reg,
      O1 => n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_datapath_dly => gtwiz_reset_tx_datapath_dly,
      gtwiz_reset_tx_pll_and_datapath_sync => gtwiz_reset_tx_pll_and_datapath_sync,
      \out\(2 downto 0) => sm_reset_tx(2 downto 0),
      sm_reset_tx_timer_sat => sm_reset_tx_timer_sat
    );
bit_synchronizer_gtwiz_reset_userclk_rx_active_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4
    port map (
      GTHE3_CHANNEL_RXUSERRDY(0) => \^gthe3_channel_rxuserrdy\(0),
      I1 => n_0_sm_reset_rx_timer_clr_reg,
      O1 => n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst,
      O2 => n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_any_sync => gtwiz_reset_rx_any_sync,
      gtwiz_reset_userclk_rx_active_sync => gtwiz_reset_userclk_rx_active_sync,
      gtwiz_userclk_rx_active_in(0) => gtwiz_userclk_rx_active_in(0),
      \out\(2 downto 0) => sm_reset_rx(2 downto 0),
      sm_reset_rx_timer_sat => sm_reset_rx_timer_sat
    );
bit_synchronizer_gtwiz_reset_userclk_tx_active_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5
    port map (
      GTHE3_CHANNEL_TXUSERRDY(0) => \^gthe3_channel_txuserrdy\(0),
      I1 => n_3_bit_synchronizer_plllock_tx_inst,
      I2 => n_0_sm_reset_tx_timer_clr_reg,
      O1 => n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst,
      O2 => n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_any_sync => gtwiz_reset_tx_any_sync,
      gtwiz_userclk_tx_active_in(0) => gtwiz_userclk_tx_active_in(0),
      \out\(2 downto 0) => sm_reset_tx(2 downto 0),
      sm_reset_tx_timer_clr0 => sm_reset_tx_timer_clr0,
      sm_reset_tx_timer_sat => sm_reset_tx_timer_sat
    );
bit_synchronizer_plllock_rx_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6
    port map (
      E(0) => n_4_bit_synchronizer_plllock_rx_inst,
      GTHE3_CHANNEL_GTRXRESET(0) => \^gthe3_channel_gtrxreset\(0),
      I1 => n_2_bit_synchronizer_rxcdrlock_inst,
      I2 => n_0_gtwiz_reset_rx_done_int_reg,
      I3 => n_4_bit_synchronizer_rxresetdone_inst,
      I4 => n_0_sm_reset_rx_timer_clr_reg,
      I5 => n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst,
      I6 => n_1_bit_synchronizer_rxcdrlock_inst,
      O1 => n_0_bit_synchronizer_plllock_rx_inst,
      O2 => n_1_bit_synchronizer_plllock_rx_inst,
      O3 => n_2_bit_synchronizer_plllock_rx_inst,
      O4 => n_3_bit_synchronizer_plllock_rx_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_any_sync => gtwiz_reset_rx_any_sync,
      gtwiz_reset_userclk_rx_active_sync => gtwiz_reset_userclk_rx_active_sync,
      \out\(2 downto 0) => sm_reset_rx(2 downto 0),
      p_0_in10_out => p_0_in10_out,
      qpll0lock_out(0) => qpll0lock_out(0),
      sm_reset_rx_cdr_to_clr => sm_reset_rx_cdr_to_clr,
      sm_reset_rx_timer_sat => sm_reset_rx_timer_sat
    );
bit_synchronizer_plllock_tx_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7
    port map (
      GTHE3_CHANNEL_GTTXRESET(0) => \^gthe3_channel_gttxreset\(0),
      I1 => n_0_gtwiz_reset_tx_done_int_reg,
      I2 => n_0_sm_reset_tx_timer_clr_reg,
      O1 => n_1_bit_synchronizer_plllock_tx_inst,
      O2 => n_2_bit_synchronizer_plllock_tx_inst,
      O3 => n_3_bit_synchronizer_plllock_tx_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_any_sync => gtwiz_reset_tx_any_sync,
      gtwiz_reset_tx_done_int0 => gtwiz_reset_tx_done_int0,
      \out\(2 downto 0) => sm_reset_tx(2 downto 0),
      plllock_tx_sync => plllock_tx_sync,
      qpll0lock_out(0) => qpll0lock_out(0),
      sm_reset_tx_timer_sat => sm_reset_tx_timer_sat,
      txresetdone_sync => txresetdone_sync
    );
bit_synchronizer_rx_done_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8
    port map (
      I1 => n_0_gtwiz_reset_rx_done_int_reg,
      gtwiz_reset_rx_done_out(0) => gtwiz_reset_rx_done_out(0),
      rxusrclk2_in(0) => rxusrclk2_in(0)
    );
bit_synchronizer_rxcdrlock_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9
    port map (
      I3 => I3,
      O1 => n_1_bit_synchronizer_rxcdrlock_inst,
      O2 => n_2_bit_synchronizer_rxcdrlock_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_cdr_stable_out(0) => gtwiz_reset_rx_cdr_stable_out(0),
      gtwiz_reset_rx_datapath_dly => gtwiz_reset_rx_datapath_dly,
      gtwiz_reset_rx_pll_and_datapath_dly => gtwiz_reset_rx_pll_and_datapath_dly,
      \out\(1 downto 0) => sm_reset_rx(2 downto 1),
      sm_reset_rx_cdr_to_sat => sm_reset_rx_cdr_to_sat
    );
bit_synchronizer_rxresetdone_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10
    port map (
      D(2) => n_1_bit_synchronizer_rxresetdone_inst,
      D(1) => n_2_bit_synchronizer_rxresetdone_inst,
      D(0) => n_3_bit_synchronizer_rxresetdone_inst,
      I1 => n_0_sm_reset_rx_timer_clr_reg,
      I2 => \n_0_FSM_sequential_sm_reset_rx[1]_i_2\,
      I4 => I4,
      O1 => n_4_bit_synchronizer_rxresetdone_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_pll_and_datapath_dly => gtwiz_reset_rx_pll_and_datapath_dly,
      \out\(2 downto 0) => sm_reset_rx(2 downto 0),
      p_0_in10_out => p_0_in10_out,
      sm_reset_rx_timer_sat => sm_reset_rx_timer_sat
    );
bit_synchronizer_tx_done_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11
    port map (
      I1 => n_0_gtwiz_reset_tx_done_int_reg,
      gtwiz_reset_tx_done_out(0) => gtwiz_reset_tx_done_out(0),
      txusrclk2_in(0) => txusrclk2_in(0)
    );
bit_synchronizer_txresetdone_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12
    port map (
      E(0) => n_2_bit_synchronizer_txresetdone_inst,
      I1 => n_0_sm_reset_tx_timer_clr_reg,
      I2 => I2,
      I3 => n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_done_int0 => gtwiz_reset_tx_done_int0,
      \out\(2 downto 0) => sm_reset_tx(2 downto 0),
      plllock_tx_sync => plllock_tx_sync,
      sm_reset_tx_timer_clr0 => sm_reset_tx_timer_clr0,
      sm_reset_tx_timer_sat => sm_reset_tx_timer_sat,
      txresetdone_sync => txresetdone_sync
    );
gtrxreset_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_2_bit_synchronizer_plllock_rx_inst,
      Q => \^gthe3_channel_gtrxreset\(0),
      R => '0'
    );
gttxreset_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_bit_synchronizer_plllock_tx_inst,
      Q => \^gthe3_channel_gttxreset\(0),
      R => '0'
    );
\gtwiz_reset_qpll0reset_out[0]_INST_0\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"E"
    )
    port map (
      I0 => gtwiz_reset_pllreset_tx_int,
      I1 => gtwiz_reset_pllreset_rx_int,
      O => gtwiz_reset_qpll0reset_out(0)
    );
gtwiz_reset_rx_datapath_int_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FF7F0040"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      I4 => n_0_gtwiz_reset_rx_datapath_int_reg,
      O => n_0_gtwiz_reset_rx_datapath_int_i_1
    );
gtwiz_reset_rx_datapath_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_gtwiz_reset_rx_datapath_int_i_1,
      Q => n_0_gtwiz_reset_rx_datapath_int_reg,
      R => gtwiz_reset_all_sync
    );
gtwiz_reset_rx_done_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_bit_synchronizer_plllock_rx_inst,
      Q => n_0_gtwiz_reset_rx_done_int_reg,
      R => gtwiz_reset_rx_any_sync
    );
gtwiz_reset_rx_pll_and_datapath_int_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FF7F0040"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      I4 => n_0_gtwiz_reset_rx_pll_and_datapath_int_reg,
      O => n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1
    );
gtwiz_reset_rx_pll_and_datapath_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1,
      Q => n_0_gtwiz_reset_rx_pll_and_datapath_int_reg,
      R => gtwiz_reset_all_sync
    );
gtwiz_reset_tx_done_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_2_bit_synchronizer_plllock_tx_inst,
      Q => n_0_gtwiz_reset_tx_done_int_reg,
      R => gtwiz_reset_tx_any_sync
    );
gtwiz_reset_tx_pll_and_datapath_int_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"FFFB0002"
    )
    port map (
      I0 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I4 => n_0_gtwiz_reset_tx_pll_and_datapath_int_reg,
      O => n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1
    );
gtwiz_reset_tx_pll_and_datapath_int_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1,
      Q => n_0_gtwiz_reset_tx_pll_and_datapath_int_reg,
      R => gtwiz_reset_all_sync
    );
pllreset_rx_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_reset_synchronizer_gtwiz_reset_rx_any_inst,
      Q => gtwiz_reset_pllreset_rx_int,
      R => '0'
    );
pllreset_tx_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_reset_synchronizer_gtwiz_reset_tx_any_inst,
      Q => gtwiz_reset_pllreset_tx_int,
      R => '0'
    );
reset_synchronizer_gtwiz_reset_all_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer
    port map (
      SR(0) => gtwiz_reset_all_sync,
      gtwiz_reset_all_in(0) => gtwiz_reset_all_in(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0)
    );
reset_synchronizer_gtwiz_reset_rx_any_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13
    port map (
      I1 => n_0_gtwiz_reset_rx_datapath_int_reg,
      I2 => n_0_gtwiz_reset_rx_pll_and_datapath_int_reg,
      O1 => n_1_reset_synchronizer_gtwiz_reset_rx_any_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_pllreset_rx_int => gtwiz_reset_pllreset_rx_int,
      gtwiz_reset_rx_any_sync => gtwiz_reset_rx_any_sync,
      gtwiz_reset_rx_datapath_in(0) => gtwiz_reset_rx_datapath_in(0),
      gtwiz_reset_rx_pll_and_datapath_in(0) => gtwiz_reset_rx_pll_and_datapath_in(0),
      \out\(2 downto 0) => sm_reset_rx(2 downto 0)
    );
reset_synchronizer_gtwiz_reset_rx_datapath_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14
    port map (
      I1 => n_0_gtwiz_reset_rx_datapath_int_reg,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_datapath_in(0) => gtwiz_reset_rx_datapath_in(0),
      gtwiz_reset_rx_datapath_sync => gtwiz_reset_rx_datapath_sync
    );
reset_synchronizer_gtwiz_reset_rx_pll_and_datapath_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15
    port map (
      I1 => n_0_gtwiz_reset_rx_pll_and_datapath_int_reg,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_rx_pll_and_datapath_in(0) => gtwiz_reset_rx_pll_and_datapath_in(0),
      gtwiz_reset_rx_pll_and_datapath_sync => gtwiz_reset_rx_pll_and_datapath_sync
    );
reset_synchronizer_gtwiz_reset_tx_any_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16
    port map (
      I1 => n_0_gtwiz_reset_tx_pll_and_datapath_int_reg,
      O1 => n_1_reset_synchronizer_gtwiz_reset_tx_any_inst,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_pllreset_tx_int => gtwiz_reset_pllreset_tx_int,
      gtwiz_reset_tx_any_sync => gtwiz_reset_tx_any_sync,
      gtwiz_reset_tx_datapath_in(0) => gtwiz_reset_tx_datapath_in(0),
      gtwiz_reset_tx_pll_and_datapath_in(0) => gtwiz_reset_tx_pll_and_datapath_in(0),
      \out\(2 downto 0) => sm_reset_tx(2 downto 0)
    );
reset_synchronizer_gtwiz_reset_tx_datapath_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17
    port map (
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_datapath_in(0) => gtwiz_reset_tx_datapath_in(0),
      gtwiz_reset_tx_datapath_sync => gtwiz_reset_tx_datapath_sync
    );
reset_synchronizer_gtwiz_reset_tx_pll_and_datapath_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18
    port map (
      I1 => n_0_gtwiz_reset_tx_pll_and_datapath_int_reg,
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_tx_pll_and_datapath_in(0) => gtwiz_reset_tx_pll_and_datapath_in(0),
      gtwiz_reset_tx_pll_and_datapath_sync => gtwiz_reset_tx_pll_and_datapath_sync
    );
reset_synchronizer_rxprogdivreset_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19
    port map (
      GTHE3_CHANNEL_RXPROGDIVRESET(0) => GTHE3_CHANNEL_RXPROGDIVRESET(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      rst_in0 => rst_in0
    );
reset_synchronizer_txprogdivreset_inst: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20
    port map (
      GTHE3_CHANNEL_TXPROGDIVRESET(0) => GTHE3_CHANNEL_TXPROGDIVRESET(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      rst_in0 => rst_in0
    );
rxuserrdy_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst,
      Q => \^gthe3_channel_rxuserrdy\(0),
      R => '0'
    );
sm_reset_all_timer_clr_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"EFFFFEEF20000220"
    )
    port map (
      I0 => n_0_sm_reset_all_timer_clr_i_2,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[3]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I3 => \n_0_FSM_sequential_sm_reset_all_reg[2]\,
      I4 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I5 => n_0_sm_reset_all_timer_clr_reg,
      O => n_0_sm_reset_all_timer_clr_i_1
    );
sm_reset_all_timer_clr_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"30BF303030B03030"
    )
    port map (
      I0 => n_0_gtwiz_reset_rx_done_int_reg,
      I1 => \n_0_FSM_sequential_sm_reset_all_reg[1]\,
      I2 => \n_0_FSM_sequential_sm_reset_all_reg[0]\,
      I3 => n_0_sm_reset_all_timer_clr_reg,
      I4 => sm_reset_all_timer_sat,
      I5 => n_0_gtwiz_reset_tx_done_int_reg,
      O => n_0_sm_reset_all_timer_clr_i_2
    );
sm_reset_all_timer_clr_reg: unisim.vcomponents.FDSE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_sm_reset_all_timer_clr_i_1,
      Q => n_0_sm_reset_all_timer_clr_reg,
      S => gtwiz_reset_all_sync
    );
\sm_reset_all_timer_ctr[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => sm_reset_all_timer_ctr(0),
      O => \n_0_sm_reset_all_timer_ctr[0]_i_1\
    );
\sm_reset_all_timer_ctr[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => sm_reset_all_timer_ctr(0),
      I1 => sm_reset_all_timer_ctr(1),
      O => \n_0_sm_reset_all_timer_ctr[1]_i_1\
    );
\sm_reset_all_timer_ctr[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
    port map (
      I0 => sm_reset_all_timer_ctr(2),
      I1 => sm_reset_all_timer_ctr(0),
      I2 => sm_reset_all_timer_ctr(1),
      O => \n_0_sm_reset_all_timer_ctr[2]_i_1\
    );
\sm_reset_all_timer_ctr[2]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"78"
    )
    port map (
      I0 => sm_reset_all_timer_ctr(0),
      I1 => sm_reset_all_timer_ctr(1),
      I2 => sm_reset_all_timer_ctr(2),
      O => \n_0_sm_reset_all_timer_ctr[2]_i_2\
    );
\sm_reset_all_timer_ctr_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_all_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_all_timer_ctr[0]_i_1\,
      Q => sm_reset_all_timer_ctr(0),
      R => n_0_sm_reset_all_timer_clr_reg
    );
\sm_reset_all_timer_ctr_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_all_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_all_timer_ctr[1]_i_1\,
      Q => sm_reset_all_timer_ctr(1),
      R => n_0_sm_reset_all_timer_clr_reg
    );
\sm_reset_all_timer_ctr_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_all_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_all_timer_ctr[2]_i_2\,
      Q => sm_reset_all_timer_ctr(2),
      R => n_0_sm_reset_all_timer_clr_reg
    );
sm_reset_all_timer_sat_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0000FF80"
    )
    port map (
      I0 => sm_reset_all_timer_ctr(1),
      I1 => sm_reset_all_timer_ctr(0),
      I2 => sm_reset_all_timer_ctr(2),
      I3 => sm_reset_all_timer_sat,
      I4 => n_0_sm_reset_all_timer_clr_reg,
      O => n_0_sm_reset_all_timer_sat_i_1
    );
sm_reset_all_timer_sat_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_sm_reset_all_timer_sat_i_1,
      Q => sm_reset_all_timer_sat,
      R => '0'
    );
sm_reset_rx_cdr_to_clr_reg: unisim.vcomponents.FDSE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_bit_synchronizer_plllock_rx_inst,
      Q => sm_reset_rx_cdr_to_clr,
      S => gtwiz_reset_rx_any_sync
    );
\sm_reset_rx_cdr_to_ctr[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"FFFE"
    )
    port map (
      I0 => n_0_sm_reset_rx_cdr_to_sat_i_5,
      I1 => n_0_sm_reset_rx_cdr_to_sat_i_4,
      I2 => n_0_sm_reset_rx_cdr_to_sat_i_3,
      I3 => n_0_sm_reset_rx_cdr_to_sat_i_2,
      O => sel
    );
\sm_reset_rx_cdr_to_ctr[0]_i_3\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_ctr_reg(0),
      O => \n_0_sm_reset_rx_cdr_to_ctr[0]_i_3\
    );
\sm_reset_rx_cdr_to_ctr_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2\,
      Q => sm_reset_rx_cdr_to_ctr_reg(0),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[10]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(10),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[11]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(11),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[12]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(12),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[13]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(13),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[14]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(14),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[15]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(15),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[16]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(16),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[17]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(17),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8\: unisim.vcomponents.CARRY8
    port map (
      CI => \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2\,
      CI_TOP => \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\,
      CO(7 downto 0) => \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\(7 downto 0),
      DI(7 downto 5) => \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_DI_UNCONNECTED\(7 downto 5),
      DI(4) => '0',
      DI(3) => '0',
      DI(2) => '0',
      DI(1) => '0',
      DI(0) => '0',
      O(7 downto 6) => \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_O_UNCONNECTED\(7 downto 6),
      O(5) => \n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1\,
      O(4) => \n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1\,
      O(3) => \n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1\,
      O(2) => \n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1\,
      O(1) => \n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1\,
      O(0) => \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1\,
      S(7 downto 6) => \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_S_UNCONNECTED\(7 downto 6),
      S(5 downto 0) => sm_reset_rx_cdr_to_ctr_reg(21 downto 16)
    );
\sm_reset_rx_cdr_to_ctr_reg[18]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(18),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[19]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(19),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(1),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8\: unisim.vcomponents.CARRY8
    port map (
      CI => '0',
      CI_TOP => \NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\,
      CO(7) => \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2\,
      CO(6 downto 0) => \NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\(6 downto 0),
      DI(7) => '0',
      DI(6) => '0',
      DI(5) => '0',
      DI(4) => '0',
      DI(3) => '0',
      DI(2) => '0',
      DI(1) => '0',
      DI(0) => '1',
      O(7) => \n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1\,
      O(6) => \n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1\,
      O(5) => \n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1\,
      O(4) => \n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1\,
      O(3) => \n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1\,
      O(2) => \n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1\,
      O(1) => \n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1\,
      O(0) => \n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2\,
      S(7 downto 1) => sm_reset_rx_cdr_to_ctr_reg(7 downto 1),
      S(0) => \n_0_sm_reset_rx_cdr_to_ctr[0]_i_3\
    );
\sm_reset_rx_cdr_to_ctr_reg[20]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(20),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[21]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(21),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(2),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[3]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(3),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[4]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(4),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[5]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(5),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[6]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(6),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[7]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(7),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[8]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(8),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[9]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => sel,
      D => \n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1\,
      Q => sm_reset_rx_cdr_to_ctr_reg(9),
      R => sm_reset_rx_cdr_to_clr
    );
\sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8\: unisim.vcomponents.CARRY8
    port map (
      CI => \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2\,
      CI_TOP => \NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED\,
      CO(7) => \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2\,
      CO(6 downto 0) => \NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CO_UNCONNECTED\(6 downto 0),
      DI(7) => '0',
      DI(6) => '0',
      DI(5) => '0',
      DI(4) => '0',
      DI(3) => '0',
      DI(2) => '0',
      DI(1) => '0',
      DI(0) => '0',
      O(7) => \n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1\,
      O(6) => \n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1\,
      O(5) => \n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1\,
      O(4) => \n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1\,
      O(3) => \n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1\,
      O(2) => \n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1\,
      O(1) => \n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1\,
      O(0) => \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1\,
      S(7 downto 0) => sm_reset_rx_cdr_to_ctr_reg(15 downto 8)
    );
sm_reset_rx_cdr_to_sat_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"00000000FFFF0001"
    )
    port map (
      I0 => n_0_sm_reset_rx_cdr_to_sat_i_2,
      I1 => n_0_sm_reset_rx_cdr_to_sat_i_3,
      I2 => n_0_sm_reset_rx_cdr_to_sat_i_4,
      I3 => n_0_sm_reset_rx_cdr_to_sat_i_5,
      I4 => sm_reset_rx_cdr_to_sat,
      I5 => sm_reset_rx_cdr_to_clr,
      O => n_0_sm_reset_rx_cdr_to_sat_i_1
    );
sm_reset_rx_cdr_to_sat_i_2: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFFFFFD"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_ctr_reg(11),
      I1 => sm_reset_rx_cdr_to_ctr_reg(21),
      I2 => sm_reset_rx_cdr_to_ctr_reg(14),
      I3 => sm_reset_rx_cdr_to_ctr_reg(15),
      I4 => sm_reset_rx_cdr_to_ctr_reg(20),
      I5 => sm_reset_rx_cdr_to_ctr_reg(16),
      O => n_0_sm_reset_rx_cdr_to_sat_i_2
    );
sm_reset_rx_cdr_to_sat_i_3: unisim.vcomponents.LUT6
    generic map(
      INIT => X"FFFFFFFFFFFFFFFE"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_ctr_reg(4),
      I1 => sm_reset_rx_cdr_to_ctr_reg(2),
      I2 => sm_reset_rx_cdr_to_ctr_reg(9),
      I3 => sm_reset_rx_cdr_to_ctr_reg(13),
      I4 => sm_reset_rx_cdr_to_ctr_reg(5),
      I5 => sm_reset_rx_cdr_to_ctr_reg(7),
      O => n_0_sm_reset_rx_cdr_to_sat_i_3
    );
sm_reset_rx_cdr_to_sat_i_4: unisim.vcomponents.LUT4
    generic map(
      INIT => X"EFFF"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_ctr_reg(1),
      I1 => sm_reset_rx_cdr_to_ctr_reg(0),
      I2 => sm_reset_rx_cdr_to_ctr_reg(18),
      I3 => sm_reset_rx_cdr_to_ctr_reg(17),
      O => n_0_sm_reset_rx_cdr_to_sat_i_4
    );
sm_reset_rx_cdr_to_sat_i_5: unisim.vcomponents.LUT6
    generic map(
      INIT => X"7FFFFFFFFFFFFFFF"
    )
    port map (
      I0 => sm_reset_rx_cdr_to_ctr_reg(8),
      I1 => sm_reset_rx_cdr_to_ctr_reg(19),
      I2 => sm_reset_rx_cdr_to_ctr_reg(12),
      I3 => sm_reset_rx_cdr_to_ctr_reg(10),
      I4 => sm_reset_rx_cdr_to_ctr_reg(3),
      I5 => sm_reset_rx_cdr_to_ctr_reg(6),
      O => n_0_sm_reset_rx_cdr_to_sat_i_5
    );
sm_reset_rx_cdr_to_sat_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_sm_reset_rx_cdr_to_sat_i_1,
      Q => sm_reset_rx_cdr_to_sat,
      R => '0'
    );
sm_reset_rx_timer_clr_reg: unisim.vcomponents.FDSE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_3_bit_synchronizer_plllock_rx_inst,
      Q => n_0_sm_reset_rx_timer_clr_reg,
      S => gtwiz_reset_rx_any_sync
    );
\sm_reset_rx_timer_ctr[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => sm_reset_rx_timer_ctr(0),
      O => \n_0_sm_reset_rx_timer_ctr[0]_i_1\
    );
\sm_reset_rx_timer_ctr[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => sm_reset_rx_timer_ctr(0),
      I1 => sm_reset_rx_timer_ctr(1),
      O => \n_0_sm_reset_rx_timer_ctr[1]_i_1\
    );
\sm_reset_rx_timer_ctr[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
    port map (
      I0 => sm_reset_rx_timer_ctr(2),
      I1 => sm_reset_rx_timer_ctr(0),
      I2 => sm_reset_rx_timer_ctr(1),
      O => \n_0_sm_reset_rx_timer_ctr[2]_i_1\
    );
\sm_reset_rx_timer_ctr[2]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"78"
    )
    port map (
      I0 => sm_reset_rx_timer_ctr(0),
      I1 => sm_reset_rx_timer_ctr(1),
      I2 => sm_reset_rx_timer_ctr(2),
      O => \n_0_sm_reset_rx_timer_ctr[2]_i_2\
    );
\sm_reset_rx_timer_ctr_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_rx_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_rx_timer_ctr[0]_i_1\,
      Q => sm_reset_rx_timer_ctr(0),
      R => n_0_sm_reset_rx_timer_clr_reg
    );
\sm_reset_rx_timer_ctr_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_rx_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_rx_timer_ctr[1]_i_1\,
      Q => sm_reset_rx_timer_ctr(1),
      R => n_0_sm_reset_rx_timer_clr_reg
    );
\sm_reset_rx_timer_ctr_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_rx_timer_ctr[2]_i_1\,
      D => \n_0_sm_reset_rx_timer_ctr[2]_i_2\,
      Q => sm_reset_rx_timer_ctr(2),
      R => n_0_sm_reset_rx_timer_clr_reg
    );
sm_reset_rx_timer_sat_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0000FF80"
    )
    port map (
      I0 => sm_reset_rx_timer_ctr(1),
      I1 => sm_reset_rx_timer_ctr(0),
      I2 => sm_reset_rx_timer_ctr(2),
      I3 => sm_reset_rx_timer_sat,
      I4 => n_0_sm_reset_rx_timer_clr_reg,
      O => n_0_sm_reset_rx_timer_sat_i_1
    );
sm_reset_rx_timer_sat_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_sm_reset_rx_timer_sat_i_1,
      Q => sm_reset_rx_timer_sat,
      R => '0'
    );
sm_reset_tx_timer_clr_reg: unisim.vcomponents.FDSE
    generic map(
      INIT => '1'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst,
      Q => n_0_sm_reset_tx_timer_clr_reg,
      S => gtwiz_reset_tx_any_sync
    );
\sm_reset_tx_timer_ctr[0]_i_1\: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => sm_reset_tx_timer_ctr(0),
      O => p_1_in(0)
    );
\sm_reset_tx_timer_ctr[1]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => sm_reset_tx_timer_ctr(0),
      I1 => sm_reset_tx_timer_ctr(1),
      O => p_1_in(1)
    );
\sm_reset_tx_timer_ctr[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"7F"
    )
    port map (
      I0 => sm_reset_tx_timer_ctr(2),
      I1 => sm_reset_tx_timer_ctr(0),
      I2 => sm_reset_tx_timer_ctr(1),
      O => \n_0_sm_reset_tx_timer_ctr[2]_i_1\
    );
\sm_reset_tx_timer_ctr[2]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"78"
    )
    port map (
      I0 => sm_reset_tx_timer_ctr(0),
      I1 => sm_reset_tx_timer_ctr(1),
      I2 => sm_reset_tx_timer_ctr(2),
      O => p_1_in(2)
    );
\sm_reset_tx_timer_ctr_reg[0]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_tx_timer_ctr[2]_i_1\,
      D => p_1_in(0),
      Q => sm_reset_tx_timer_ctr(0),
      R => n_0_sm_reset_tx_timer_clr_reg
    );
\sm_reset_tx_timer_ctr_reg[1]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_tx_timer_ctr[2]_i_1\,
      D => p_1_in(1),
      Q => sm_reset_tx_timer_ctr(1),
      R => n_0_sm_reset_tx_timer_clr_reg
    );
\sm_reset_tx_timer_ctr_reg[2]\: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => \n_0_sm_reset_tx_timer_ctr[2]_i_1\,
      D => p_1_in(2),
      Q => sm_reset_tx_timer_ctr(2),
      R => n_0_sm_reset_tx_timer_clr_reg
    );
sm_reset_tx_timer_sat_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"0000FF80"
    )
    port map (
      I0 => sm_reset_tx_timer_ctr(1),
      I1 => sm_reset_tx_timer_ctr(0),
      I2 => sm_reset_tx_timer_ctr(2),
      I3 => sm_reset_tx_timer_sat,
      I4 => n_0_sm_reset_tx_timer_clr_reg,
      O => n_0_sm_reset_tx_timer_sat_i_1
    );
sm_reset_tx_timer_sat_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_0_sm_reset_tx_timer_sat_i_1,
      Q => sm_reset_tx_timer_sat,
      R => '0'
    );
txuserrdy_out_reg: unisim.vcomponents.FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => gtwiz_reset_clk_freerun_in(0),
      CE => '1',
      D => n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst,
      Q => \^gthe3_channel_txuserrdy\(0),
      R => '0'
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3 is
  port (
    gtpowergood_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrlock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll0lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    drprdy_common_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor0_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor1_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    drpdo_common_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxrecclk0_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclk1_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pmarsvdout0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pmarsvdout1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    gtwiz_reset_qpll0reset_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    cpllfbclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllrefclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    drprdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescandataerror_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclkmonitor_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierategen3_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierateidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pciesynctxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieusergen3rdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserphystatusrst_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratestart_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    phystatus_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    resetexception_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyterealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrphdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanbondseq_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanrealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcominitdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomsasdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomwakedet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxelecidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobestarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignerr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbserr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbslocked_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclkout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsliderdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclkrdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippmardy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxvalid_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomfinish_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinitdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcsrsvdout_out : out STD_LOGIC_VECTOR ( 23 downto 0 );
    rxdata_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
    drpdo_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl0_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl1_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    dmonitorout_out : out STD_LOGIC_VECTOR ( 33 downto 0 );
    pcierateqpllpd_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pcierateqpllreset_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxclkcorcnt_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxdatavalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxheadervalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxstartofseq_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    txbufstatus_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    bufgtce_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtcemask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtreset_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtrstmask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxbufstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondo_out : out STD_LOGIC_VECTOR ( 9 downto 0 );
    rxheader_out : out STD_LOGIC_VECTOR ( 11 downto 0 );
    rxmonitorout_out : out STD_LOGIC_VECTOR ( 13 downto 0 );
    pinrsrvdas_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl2_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl3_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxdataextendrsvd_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    bufgtdiv_out : out STD_LOGIC_VECTOR ( 17 downto 0 );
    gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpclk_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpen_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpwe_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpdi_common_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    qpll0refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpll1refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpllrsvd2_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd3_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd1_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    qpllrsvd4_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    drpaddr_common_in : in STD_LOGIC_VECTOR ( 8 downto 0 );
    cfgreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllockdetclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllocken_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonfiforeset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonitorclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpwe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicaldone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicalstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescantrigger_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtgrefclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxn_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxp_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtresetsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    lpbkrxtxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    lpbktxrxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieeqrxeqadaptdone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierstidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pciersttxsyncstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratedone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    resetovrd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rstclkentx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbufreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrfreqreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrresetrsv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbonden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondmaster_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondslave_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadeten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelpmreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeuthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeutovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevphold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevpovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevsen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfexyden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxgearboxslip_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfklovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoobreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoscalreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinttestovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbscntreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpien_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslide_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippma_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    sigvalidclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    tx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcominit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomsas_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomwake_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdeemph_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdetectrx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdiffpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyupdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txelecidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txinhibit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpdelecidlemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlytstclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpisopd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpostcursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprbsforceerr_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprecursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpibiasen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpistrongpdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpiweakpup_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txswing_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
    drpdi_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    gtrsvd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    pcsrsvdin_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl0_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl1_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    rxdfeagcctrl_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxelecidlemode_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxmonitorsel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    cpllrefclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    loopback_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondlevel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txbufdiffctrl_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txmargin_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxosintcfg_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txdiffctrl_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pcsrsvdin2_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    pmarsvdin_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    rxchbondi_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpippmstepsize_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpostcursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txprecursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txheader_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
    txmaincursor_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    txsequence_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    tx8b10bbypass_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txctrl2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txdataextendrsvd_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drpaddr_in : in STD_LOGIC_VECTOR ( 17 downto 0 );
    gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3 : entity is "GthUltrascaleJesdCoregen_gtwizard_gthe3";
end GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3;

architecture STRUCTURE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3 is
  signal gtwiz_reset_gtrxreset_int : STD_LOGIC;
  signal gtwiz_reset_gttxreset_int : STD_LOGIC;
  signal \^gtwiz_reset_qpll0reset_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal gtwiz_reset_rxprogdivreset_int : STD_LOGIC;
  signal gtwiz_reset_rxuserrdy_int : STD_LOGIC;
  signal gtwiz_reset_txprogdivreset_int : STD_LOGIC;
  signal gtwiz_reset_txuserrdy_int : STD_LOGIC;
  signal \n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\ : STD_LOGIC;
  signal \n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\ : STD_LOGIC;
  signal \n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\ : STD_LOGIC;
  signal \n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\ : STD_LOGIC;
  signal \^qpll0lock_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^qpll0outclk_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^qpll0outrefclk_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^qpll1outclk_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^qpll1outrefclk_out\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal rst_in0 : STD_LOGIC;
begin
  gtwiz_reset_qpll0reset_out(0) <= \^gtwiz_reset_qpll0reset_out\(0);
  qpll0lock_out(0) <= \^qpll0lock_out\(0);
  qpll0outclk_out(0) <= \^qpll0outclk_out\(0);
  qpll0outrefclk_out(0) <= \^qpll0outrefclk_out\(0);
  qpll1outclk_out(0) <= \^qpll1outclk_out\(0);
  qpll1outrefclk_out(0) <= \^qpll1outrefclk_out\(0);
\gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\: entity work.GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper
    port map (
      GTHE3_CHANNEL_GTRXRESET(0) => gtwiz_reset_gtrxreset_int,
      GTHE3_CHANNEL_GTTXRESET(0) => gtwiz_reset_gttxreset_int,
      GTHE3_CHANNEL_RXPROGDIVRESET(0) => gtwiz_reset_rxprogdivreset_int,
      GTHE3_CHANNEL_RXUSERRDY(0) => gtwiz_reset_rxuserrdy_int,
      GTHE3_CHANNEL_TXPROGDIVRESET(0) => gtwiz_reset_txprogdivreset_int,
      GTHE3_CHANNEL_TXUSERRDY(0) => gtwiz_reset_txuserrdy_int,
      O1 => \n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      O2 => \n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      O3 => \n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      O4 => \n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      bufgtce_out(5 downto 0) => bufgtce_out(5 downto 0),
      bufgtcemask_out(5 downto 0) => bufgtcemask_out(5 downto 0),
      bufgtdiv_out(17 downto 0) => bufgtdiv_out(17 downto 0),
      bufgtreset_out(5 downto 0) => bufgtreset_out(5 downto 0),
      bufgtrstmask_out(5 downto 0) => bufgtrstmask_out(5 downto 0),
      cfgreset_in(1 downto 0) => cfgreset_in(1 downto 0),
      clkrsvd0_in(1 downto 0) => clkrsvd0_in(1 downto 0),
      clkrsvd1_in(1 downto 0) => clkrsvd1_in(1 downto 0),
      cpllfbclklost_out(1 downto 0) => cpllfbclklost_out(1 downto 0),
      cplllock_out(1 downto 0) => cplllock_out(1 downto 0),
      cplllockdetclk_in(1 downto 0) => cplllockdetclk_in(1 downto 0),
      cplllocken_in(1 downto 0) => cplllocken_in(1 downto 0),
      cpllpd_in(1 downto 0) => cpllpd_in(1 downto 0),
      cpllrefclklost_out(1 downto 0) => cpllrefclklost_out(1 downto 0),
      cpllrefclksel_in(5 downto 0) => cpllrefclksel_in(5 downto 0),
      cpllreset_in(1 downto 0) => cpllreset_in(1 downto 0),
      dmonfiforeset_in(1 downto 0) => dmonfiforeset_in(1 downto 0),
      dmonitorclk_in(1 downto 0) => dmonitorclk_in(1 downto 0),
      dmonitorout_out(33 downto 0) => dmonitorout_out(33 downto 0),
      drpaddr_in(17 downto 0) => drpaddr_in(17 downto 0),
      drpclk_in(1 downto 0) => drpclk_in(1 downto 0),
      drpdi_in(31 downto 0) => drpdi_in(31 downto 0),
      drpdo_out(31 downto 0) => drpdo_out(31 downto 0),
      drpen_in(1 downto 0) => drpen_in(1 downto 0),
      drprdy_out(1 downto 0) => drprdy_out(1 downto 0),
      drpwe_in(1 downto 0) => drpwe_in(1 downto 0),
      evoddphicaldone_in(1 downto 0) => evoddphicaldone_in(1 downto 0),
      evoddphicalstart_in(1 downto 0) => evoddphicalstart_in(1 downto 0),
      evoddphidrden_in(1 downto 0) => evoddphidrden_in(1 downto 0),
      evoddphidwren_in(1 downto 0) => evoddphidwren_in(1 downto 0),
      evoddphixrden_in(1 downto 0) => evoddphixrden_in(1 downto 0),
      evoddphixwren_in(1 downto 0) => evoddphixwren_in(1 downto 0),
      eyescandataerror_out(1 downto 0) => eyescandataerror_out(1 downto 0),
      eyescanmode_in(1 downto 0) => eyescanmode_in(1 downto 0),
      eyescanreset_in(1 downto 0) => eyescanreset_in(1 downto 0),
      eyescantrigger_in(1 downto 0) => eyescantrigger_in(1 downto 0),
      gtgrefclk_in(1 downto 0) => gtgrefclk_in(1 downto 0),
      gthrxn_in(1 downto 0) => gthrxn_in(1 downto 0),
      gthrxp_in(1 downto 0) => gthrxp_in(1 downto 0),
      gthtxn_out(1 downto 0) => gthtxn_out(1 downto 0),
      gthtxp_out(1 downto 0) => gthtxp_out(1 downto 0),
      gtnorthrefclk0_in(1 downto 0) => gtnorthrefclk0_in(1 downto 0),
      gtnorthrefclk1_in(1 downto 0) => gtnorthrefclk1_in(1 downto 0),
      gtpowergood_out(1 downto 0) => gtpowergood_out(1 downto 0),
      gtrefclk0_in(1 downto 0) => gtrefclk0_in(1 downto 0),
      gtrefclk1_in(1 downto 0) => gtrefclk1_in(1 downto 0),
      gtrefclkmonitor_out(1 downto 0) => gtrefclkmonitor_out(1 downto 0),
      gtresetsel_in(1 downto 0) => gtresetsel_in(1 downto 0),
      gtrsvd_in(31 downto 0) => gtrsvd_in(31 downto 0),
      gtsouthrefclk0_in(1 downto 0) => gtsouthrefclk0_in(1 downto 0),
      gtsouthrefclk1_in(1 downto 0) => gtsouthrefclk1_in(1 downto 0),
      gtwiz_userdata_tx_in(63 downto 0) => gtwiz_userdata_tx_in(63 downto 0),
      loopback_in(5 downto 0) => loopback_in(5 downto 0),
      lpbkrxtxseren_in(1 downto 0) => lpbkrxtxseren_in(1 downto 0),
      lpbktxrxseren_in(1 downto 0) => lpbktxrxseren_in(1 downto 0),
      pcieeqrxeqadaptdone_in(1 downto 0) => pcieeqrxeqadaptdone_in(1 downto 0),
      pcierategen3_out(1 downto 0) => pcierategen3_out(1 downto 0),
      pcierateidle_out(1 downto 0) => pcierateidle_out(1 downto 0),
      pcierateqpllpd_out(3 downto 0) => pcierateqpllpd_out(3 downto 0),
      pcierateqpllreset_out(3 downto 0) => pcierateqpllreset_out(3 downto 0),
      pcierstidle_in(1 downto 0) => pcierstidle_in(1 downto 0),
      pciersttxsyncstart_in(1 downto 0) => pciersttxsyncstart_in(1 downto 0),
      pciesynctxsyncdone_out(1 downto 0) => pciesynctxsyncdone_out(1 downto 0),
      pcieusergen3rdy_out(1 downto 0) => pcieusergen3rdy_out(1 downto 0),
      pcieuserphystatusrst_out(1 downto 0) => pcieuserphystatusrst_out(1 downto 0),
      pcieuserratedone_in(1 downto 0) => pcieuserratedone_in(1 downto 0),
      pcieuserratestart_out(1 downto 0) => pcieuserratestart_out(1 downto 0),
      pcsrsvdin2_in(9 downto 0) => pcsrsvdin2_in(9 downto 0),
      pcsrsvdin_in(31 downto 0) => pcsrsvdin_in(31 downto 0),
      pcsrsvdout_out(23 downto 0) => pcsrsvdout_out(23 downto 0),
      phystatus_out(1 downto 0) => phystatus_out(1 downto 0),
      pinrsrvdas_out(15 downto 0) => pinrsrvdas_out(15 downto 0),
      pmarsvdin_in(9 downto 0) => pmarsvdin_in(9 downto 0),
      qpll0outclk_out(0) => \^qpll0outclk_out\(0),
      qpll0outrefclk_out(0) => \^qpll0outrefclk_out\(0),
      qpll1outclk_out(0) => \^qpll1outclk_out\(0),
      qpll1outrefclk_out(0) => \^qpll1outrefclk_out\(0),
      resetexception_out(1 downto 0) => resetexception_out(1 downto 0),
      resetovrd_in(1 downto 0) => resetovrd_in(1 downto 0),
      rstclkentx_in(1 downto 0) => rstclkentx_in(1 downto 0),
      rx8b10ben_in(1 downto 0) => rx8b10ben_in(1 downto 0),
      rxbufreset_in(1 downto 0) => rxbufreset_in(1 downto 0),
      rxbufstatus_out(5 downto 0) => rxbufstatus_out(5 downto 0),
      rxbyteisaligned_out(1 downto 0) => rxbyteisaligned_out(1 downto 0),
      rxbyterealign_out(1 downto 0) => rxbyterealign_out(1 downto 0),
      rxcdrfreqreset_in(1 downto 0) => rxcdrfreqreset_in(1 downto 0),
      rxcdrhold_in(1 downto 0) => rxcdrhold_in(1 downto 0),
      rxcdrlock_out(1 downto 0) => rxcdrlock_out(1 downto 0),
      rxcdrovrden_in(1 downto 0) => rxcdrovrden_in(1 downto 0),
      rxcdrphdone_out(1 downto 0) => rxcdrphdone_out(1 downto 0),
      rxcdrreset_in(1 downto 0) => rxcdrreset_in(1 downto 0),
      rxcdrresetrsv_in(1 downto 0) => rxcdrresetrsv_in(1 downto 0),
      rxchanbondseq_out(1 downto 0) => rxchanbondseq_out(1 downto 0),
      rxchanisaligned_out(1 downto 0) => rxchanisaligned_out(1 downto 0),
      rxchanrealign_out(1 downto 0) => rxchanrealign_out(1 downto 0),
      rxchbonden_in(1 downto 0) => rxchbonden_in(1 downto 0),
      rxchbondi_in(9 downto 0) => rxchbondi_in(9 downto 0),
      rxchbondlevel_in(5 downto 0) => rxchbondlevel_in(5 downto 0),
      rxchbondmaster_in(1 downto 0) => rxchbondmaster_in(1 downto 0),
      rxchbondo_out(9 downto 0) => rxchbondo_out(9 downto 0),
      rxchbondslave_in(1 downto 0) => rxchbondslave_in(1 downto 0),
      rxclkcorcnt_out(3 downto 0) => rxclkcorcnt_out(3 downto 0),
      rxcominitdet_out(1 downto 0) => rxcominitdet_out(1 downto 0),
      rxcommadet_out(1 downto 0) => rxcommadet_out(1 downto 0),
      rxcommadeten_in(1 downto 0) => rxcommadeten_in(1 downto 0),
      rxcomsasdet_out(1 downto 0) => rxcomsasdet_out(1 downto 0),
      rxcomwakedet_out(1 downto 0) => rxcomwakedet_out(1 downto 0),
      rxctrl0_out(31 downto 0) => rxctrl0_out(31 downto 0),
      rxctrl1_out(31 downto 0) => rxctrl1_out(31 downto 0),
      rxctrl2_out(15 downto 0) => rxctrl2_out(15 downto 0),
      rxctrl3_out(15 downto 0) => rxctrl3_out(15 downto 0),
      rxdata_out(255 downto 0) => rxdata_out(255 downto 0),
      rxdataextendrsvd_out(15 downto 0) => rxdataextendrsvd_out(15 downto 0),
      rxdatavalid_out(3 downto 0) => rxdatavalid_out(3 downto 0),
      rxdfeagcctrl_in(3 downto 0) => rxdfeagcctrl_in(3 downto 0),
      rxdfeagchold_in(1 downto 0) => rxdfeagchold_in(1 downto 0),
      rxdfeagcovrden_in(1 downto 0) => rxdfeagcovrden_in(1 downto 0),
      rxdfelfhold_in(1 downto 0) => rxdfelfhold_in(1 downto 0),
      rxdfelfovrden_in(1 downto 0) => rxdfelfovrden_in(1 downto 0),
      rxdfelpmreset_in(1 downto 0) => rxdfelpmreset_in(1 downto 0),
      rxdfetap10hold_in(1 downto 0) => rxdfetap10hold_in(1 downto 0),
      rxdfetap10ovrden_in(1 downto 0) => rxdfetap10ovrden_in(1 downto 0),
      rxdfetap11hold_in(1 downto 0) => rxdfetap11hold_in(1 downto 0),
      rxdfetap11ovrden_in(1 downto 0) => rxdfetap11ovrden_in(1 downto 0),
      rxdfetap12hold_in(1 downto 0) => rxdfetap12hold_in(1 downto 0),
      rxdfetap12ovrden_in(1 downto 0) => rxdfetap12ovrden_in(1 downto 0),
      rxdfetap13hold_in(1 downto 0) => rxdfetap13hold_in(1 downto 0),
      rxdfetap13ovrden_in(1 downto 0) => rxdfetap13ovrden_in(1 downto 0),
      rxdfetap14hold_in(1 downto 0) => rxdfetap14hold_in(1 downto 0),
      rxdfetap14ovrden_in(1 downto 0) => rxdfetap14ovrden_in(1 downto 0),
      rxdfetap15hold_in(1 downto 0) => rxdfetap15hold_in(1 downto 0),
      rxdfetap15ovrden_in(1 downto 0) => rxdfetap15ovrden_in(1 downto 0),
      rxdfetap2hold_in(1 downto 0) => rxdfetap2hold_in(1 downto 0),
      rxdfetap2ovrden_in(1 downto 0) => rxdfetap2ovrden_in(1 downto 0),
      rxdfetap3hold_in(1 downto 0) => rxdfetap3hold_in(1 downto 0),
      rxdfetap3ovrden_in(1 downto 0) => rxdfetap3ovrden_in(1 downto 0),
      rxdfetap4hold_in(1 downto 0) => rxdfetap4hold_in(1 downto 0),
      rxdfetap4ovrden_in(1 downto 0) => rxdfetap4ovrden_in(1 downto 0),
      rxdfetap5hold_in(1 downto 0) => rxdfetap5hold_in(1 downto 0),
      rxdfetap5ovrden_in(1 downto 0) => rxdfetap5ovrden_in(1 downto 0),
      rxdfetap6hold_in(1 downto 0) => rxdfetap6hold_in(1 downto 0),
      rxdfetap6ovrden_in(1 downto 0) => rxdfetap6ovrden_in(1 downto 0),
      rxdfetap7hold_in(1 downto 0) => rxdfetap7hold_in(1 downto 0),
      rxdfetap7ovrden_in(1 downto 0) => rxdfetap7ovrden_in(1 downto 0),
      rxdfetap8hold_in(1 downto 0) => rxdfetap8hold_in(1 downto 0),
      rxdfetap8ovrden_in(1 downto 0) => rxdfetap8ovrden_in(1 downto 0),
      rxdfetap9hold_in(1 downto 0) => rxdfetap9hold_in(1 downto 0),
      rxdfetap9ovrden_in(1 downto 0) => rxdfetap9ovrden_in(1 downto 0),
      rxdfeuthold_in(1 downto 0) => rxdfeuthold_in(1 downto 0),
      rxdfeutovrden_in(1 downto 0) => rxdfeutovrden_in(1 downto 0),
      rxdfevphold_in(1 downto 0) => rxdfevphold_in(1 downto 0),
      rxdfevpovrden_in(1 downto 0) => rxdfevpovrden_in(1 downto 0),
      rxdfevsen_in(1 downto 0) => rxdfevsen_in(1 downto 0),
      rxdfexyden_in(1 downto 0) => rxdfexyden_in(1 downto 0),
      rxdlybypass_in(1 downto 0) => rxdlybypass_in(1 downto 0),
      rxdlyen_in(1 downto 0) => rxdlyen_in(1 downto 0),
      rxdlyovrden_in(1 downto 0) => rxdlyovrden_in(1 downto 0),
      rxdlysreset_in(1 downto 0) => rxdlysreset_in(1 downto 0),
      rxdlysresetdone_out(1 downto 0) => rxdlysresetdone_out(1 downto 0),
      rxelecidle_out(1 downto 0) => rxelecidle_out(1 downto 0),
      rxelecidlemode_in(3 downto 0) => rxelecidlemode_in(3 downto 0),
      rxgearboxslip_in(1 downto 0) => rxgearboxslip_in(1 downto 0),
      rxheader_out(11 downto 0) => rxheader_out(11 downto 0),
      rxheadervalid_out(3 downto 0) => rxheadervalid_out(3 downto 0),
      rxlatclk_in(1 downto 0) => rxlatclk_in(1 downto 0),
      rxlpmen_in(1 downto 0) => rxlpmen_in(1 downto 0),
      rxlpmgchold_in(1 downto 0) => rxlpmgchold_in(1 downto 0),
      rxlpmgcovrden_in(1 downto 0) => rxlpmgcovrden_in(1 downto 0),
      rxlpmhfhold_in(1 downto 0) => rxlpmhfhold_in(1 downto 0),
      rxlpmhfovrden_in(1 downto 0) => rxlpmhfovrden_in(1 downto 0),
      rxlpmlfhold_in(1 downto 0) => rxlpmlfhold_in(1 downto 0),
      rxlpmlfklovrden_in(1 downto 0) => rxlpmlfklovrden_in(1 downto 0),
      rxlpmoshold_in(1 downto 0) => rxlpmoshold_in(1 downto 0),
      rxlpmosovrden_in(1 downto 0) => rxlpmosovrden_in(1 downto 0),
      rxmcommaalignen_in(1 downto 0) => rxmcommaalignen_in(1 downto 0),
      rxmonitorout_out(13 downto 0) => rxmonitorout_out(13 downto 0),
      rxmonitorsel_in(3 downto 0) => rxmonitorsel_in(3 downto 0),
      rxoobreset_in(1 downto 0) => rxoobreset_in(1 downto 0),
      rxoscalreset_in(1 downto 0) => rxoscalreset_in(1 downto 0),
      rxoshold_in(1 downto 0) => rxoshold_in(1 downto 0),
      rxosintcfg_in(7 downto 0) => rxosintcfg_in(7 downto 0),
      rxosintdone_out(1 downto 0) => rxosintdone_out(1 downto 0),
      rxosinten_in(1 downto 0) => rxosinten_in(1 downto 0),
      rxosinthold_in(1 downto 0) => rxosinthold_in(1 downto 0),
      rxosintovrden_in(1 downto 0) => rxosintovrden_in(1 downto 0),
      rxosintstarted_out(1 downto 0) => rxosintstarted_out(1 downto 0),
      rxosintstrobe_in(1 downto 0) => rxosintstrobe_in(1 downto 0),
      rxosintstrobedone_out(1 downto 0) => rxosintstrobedone_out(1 downto 0),
      rxosintstrobestarted_out(1 downto 0) => rxosintstrobestarted_out(1 downto 0),
      rxosinttestovrden_in(1 downto 0) => rxosinttestovrden_in(1 downto 0),
      rxosovrden_in(1 downto 0) => rxosovrden_in(1 downto 0),
      rxoutclk_out(1 downto 0) => rxoutclk_out(1 downto 0),
      rxoutclkfabric_out(1 downto 0) => rxoutclkfabric_out(1 downto 0),
      rxoutclkpcs_out(1 downto 0) => rxoutclkpcs_out(1 downto 0),
      rxoutclksel_in(5 downto 0) => rxoutclksel_in(5 downto 0),
      rxpcommaalignen_in(1 downto 0) => rxpcommaalignen_in(1 downto 0),
      rxpcsreset_in(1 downto 0) => rxpcsreset_in(1 downto 0),
      rxpd_in(3 downto 0) => rxpd_in(3 downto 0),
      rxphalign_in(1 downto 0) => rxphalign_in(1 downto 0),
      rxphaligndone_out(1 downto 0) => rxphaligndone_out(1 downto 0),
      rxphalignen_in(1 downto 0) => rxphalignen_in(1 downto 0),
      rxphalignerr_out(1 downto 0) => rxphalignerr_out(1 downto 0),
      rxphdlypd_in(1 downto 0) => rxphdlypd_in(1 downto 0),
      rxphdlyreset_in(1 downto 0) => rxphdlyreset_in(1 downto 0),
      rxphovrden_in(1 downto 0) => rxphovrden_in(1 downto 0),
      rxpllclksel_in(3 downto 0) => rxpllclksel_in(3 downto 0),
      rxpmareset_in(1 downto 0) => rxpmareset_in(1 downto 0),
      rxpmaresetdone_out(1 downto 0) => rxpmaresetdone_out(1 downto 0),
      rxpolarity_in(1 downto 0) => rxpolarity_in(1 downto 0),
      rxprbscntreset_in(1 downto 0) => rxprbscntreset_in(1 downto 0),
      rxprbserr_out(1 downto 0) => rxprbserr_out(1 downto 0),
      rxprbslocked_out(1 downto 0) => rxprbslocked_out(1 downto 0),
      rxprbssel_in(7 downto 0) => rxprbssel_in(7 downto 0),
      rxprgdivresetdone_out(1 downto 0) => rxprgdivresetdone_out(1 downto 0),
      rxqpien_in(1 downto 0) => rxqpien_in(1 downto 0),
      rxqpisenn_out(1 downto 0) => rxqpisenn_out(1 downto 0),
      rxqpisenp_out(1 downto 0) => rxqpisenp_out(1 downto 0),
      rxrate_in(5 downto 0) => rxrate_in(5 downto 0),
      rxratedone_out(1 downto 0) => rxratedone_out(1 downto 0),
      rxratemode_in(1 downto 0) => rxratemode_in(1 downto 0),
      rxrecclkout_out(1 downto 0) => rxrecclkout_out(1 downto 0),
      rxresetdone_out(1 downto 0) => rxresetdone_out(1 downto 0),
      rxslide_in(1 downto 0) => rxslide_in(1 downto 0),
      rxsliderdy_out(1 downto 0) => rxsliderdy_out(1 downto 0),
      rxslipdone_out(1 downto 0) => rxslipdone_out(1 downto 0),
      rxslipoutclk_in(1 downto 0) => rxslipoutclk_in(1 downto 0),
      rxslipoutclkrdy_out(1 downto 0) => rxslipoutclkrdy_out(1 downto 0),
      rxslippma_in(1 downto 0) => rxslippma_in(1 downto 0),
      rxslippmardy_out(1 downto 0) => rxslippmardy_out(1 downto 0),
      rxstartofseq_out(3 downto 0) => rxstartofseq_out(3 downto 0),
      rxstatus_out(5 downto 0) => rxstatus_out(5 downto 0),
      rxsyncallin_in(1 downto 0) => rxsyncallin_in(1 downto 0),
      rxsyncdone_out(1 downto 0) => rxsyncdone_out(1 downto 0),
      rxsyncin_in(1 downto 0) => rxsyncin_in(1 downto 0),
      rxsyncmode_in(1 downto 0) => rxsyncmode_in(1 downto 0),
      rxsyncout_out(1 downto 0) => rxsyncout_out(1 downto 0),
      rxsysclksel_in(3 downto 0) => rxsysclksel_in(3 downto 0),
      rxusrclk2_in(1 downto 0) => rxusrclk2_in(1 downto 0),
      rxusrclk_in(1 downto 0) => rxusrclk_in(1 downto 0),
      rxvalid_out(1 downto 0) => rxvalid_out(1 downto 0),
      sigvalidclk_in(1 downto 0) => sigvalidclk_in(1 downto 0),
      tx8b10bbypass_in(15 downto 0) => tx8b10bbypass_in(15 downto 0),
      tx8b10ben_in(1 downto 0) => tx8b10ben_in(1 downto 0),
      txbufdiffctrl_in(5 downto 0) => txbufdiffctrl_in(5 downto 0),
      txbufstatus_out(3 downto 0) => txbufstatus_out(3 downto 0),
      txcomfinish_out(1 downto 0) => txcomfinish_out(1 downto 0),
      txcominit_in(1 downto 0) => txcominit_in(1 downto 0),
      txcomsas_in(1 downto 0) => txcomsas_in(1 downto 0),
      txcomwake_in(1 downto 0) => txcomwake_in(1 downto 0),
      txctrl0_in(31 downto 0) => txctrl0_in(31 downto 0),
      txctrl1_in(31 downto 0) => txctrl1_in(31 downto 0),
      txctrl2_in(15 downto 0) => txctrl2_in(15 downto 0),
      txdataextendrsvd_in(15 downto 0) => txdataextendrsvd_in(15 downto 0),
      txdeemph_in(1 downto 0) => txdeemph_in(1 downto 0),
      txdetectrx_in(1 downto 0) => txdetectrx_in(1 downto 0),
      txdiffctrl_in(7 downto 0) => txdiffctrl_in(7 downto 0),
      txdiffpd_in(1 downto 0) => txdiffpd_in(1 downto 0),
      txdlybypass_in(1 downto 0) => txdlybypass_in(1 downto 0),
      txdlyen_in(1 downto 0) => txdlyen_in(1 downto 0),
      txdlyhold_in(1 downto 0) => txdlyhold_in(1 downto 0),
      txdlyovrden_in(1 downto 0) => txdlyovrden_in(1 downto 0),
      txdlysreset_in(1 downto 0) => txdlysreset_in(1 downto 0),
      txdlysresetdone_out(1 downto 0) => txdlysresetdone_out(1 downto 0),
      txdlyupdown_in(1 downto 0) => txdlyupdown_in(1 downto 0),
      txelecidle_in(1 downto 0) => txelecidle_in(1 downto 0),
      txheader_in(11 downto 0) => txheader_in(11 downto 0),
      txinhibit_in(1 downto 0) => txinhibit_in(1 downto 0),
      txlatclk_in(1 downto 0) => txlatclk_in(1 downto 0),
      txmaincursor_in(13 downto 0) => txmaincursor_in(13 downto 0),
      txmargin_in(5 downto 0) => txmargin_in(5 downto 0),
      txoutclk_out(1 downto 0) => txoutclk_out(1 downto 0),
      txoutclkfabric_out(1 downto 0) => txoutclkfabric_out(1 downto 0),
      txoutclkpcs_out(1 downto 0) => txoutclkpcs_out(1 downto 0),
      txoutclksel_in(5 downto 0) => txoutclksel_in(5 downto 0),
      txpcsreset_in(1 downto 0) => txpcsreset_in(1 downto 0),
      txpd_in(3 downto 0) => txpd_in(3 downto 0),
      txpdelecidlemode_in(1 downto 0) => txpdelecidlemode_in(1 downto 0),
      txphalign_in(1 downto 0) => txphalign_in(1 downto 0),
      txphaligndone_out(1 downto 0) => txphaligndone_out(1 downto 0),
      txphalignen_in(1 downto 0) => txphalignen_in(1 downto 0),
      txphdlypd_in(1 downto 0) => txphdlypd_in(1 downto 0),
      txphdlyreset_in(1 downto 0) => txphdlyreset_in(1 downto 0),
      txphdlytstclk_in(1 downto 0) => txphdlytstclk_in(1 downto 0),
      txphinit_in(1 downto 0) => txphinit_in(1 downto 0),
      txphinitdone_out(1 downto 0) => txphinitdone_out(1 downto 0),
      txphovrden_in(1 downto 0) => txphovrden_in(1 downto 0),
      txpippmen_in(1 downto 0) => txpippmen_in(1 downto 0),
      txpippmovrden_in(1 downto 0) => txpippmovrden_in(1 downto 0),
      txpippmpd_in(1 downto 0) => txpippmpd_in(1 downto 0),
      txpippmsel_in(1 downto 0) => txpippmsel_in(1 downto 0),
      txpippmstepsize_in(9 downto 0) => txpippmstepsize_in(9 downto 0),
      txpisopd_in(1 downto 0) => txpisopd_in(1 downto 0),
      txpllclksel_in(3 downto 0) => txpllclksel_in(3 downto 0),
      txpmareset_in(1 downto 0) => txpmareset_in(1 downto 0),
      txpmaresetdone_out(1 downto 0) => txpmaresetdone_out(1 downto 0),
      txpolarity_in(1 downto 0) => txpolarity_in(1 downto 0),
      txpostcursor_in(9 downto 0) => txpostcursor_in(9 downto 0),
      txpostcursorinv_in(1 downto 0) => txpostcursorinv_in(1 downto 0),
      txprbsforceerr_in(1 downto 0) => txprbsforceerr_in(1 downto 0),
      txprbssel_in(7 downto 0) => txprbssel_in(7 downto 0),
      txprecursor_in(9 downto 0) => txprecursor_in(9 downto 0),
      txprecursorinv_in(1 downto 0) => txprecursorinv_in(1 downto 0),
      txprgdivresetdone_out(1 downto 0) => txprgdivresetdone_out(1 downto 0),
      txqpibiasen_in(1 downto 0) => txqpibiasen_in(1 downto 0),
      txqpisenn_out(1 downto 0) => txqpisenn_out(1 downto 0),
      txqpisenp_out(1 downto 0) => txqpisenp_out(1 downto 0),
      txqpistrongpdown_in(1 downto 0) => txqpistrongpdown_in(1 downto 0),
      txqpiweakpup_in(1 downto 0) => txqpiweakpup_in(1 downto 0),
      txrate_in(5 downto 0) => txrate_in(5 downto 0),
      txratedone_out(1 downto 0) => txratedone_out(1 downto 0),
      txratemode_in(1 downto 0) => txratemode_in(1 downto 0),
      txresetdone_out(1 downto 0) => txresetdone_out(1 downto 0),
      txsequence_in(13 downto 0) => txsequence_in(13 downto 0),
      txswing_in(1 downto 0) => txswing_in(1 downto 0),
      txsyncallin_in(1 downto 0) => txsyncallin_in(1 downto 0),
      txsyncdone_out(1 downto 0) => txsyncdone_out(1 downto 0),
      txsyncin_in(1 downto 0) => txsyncin_in(1 downto 0),
      txsyncmode_in(1 downto 0) => txsyncmode_in(1 downto 0),
      txsyncout_out(1 downto 0) => txsyncout_out(1 downto 0),
      txsysclksel_in(3 downto 0) => txsysclksel_in(3 downto 0),
      txusrclk2_in(1 downto 0) => txusrclk2_in(1 downto 0),
      txusrclk_in(1 downto 0) => txusrclk_in(1 downto 0)
    );
\gen_gtwizard_gthe3.gen_common.gen_common_container[4].gen_enabled_common.gthe3_common_wrapper_inst\: entity work.GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper
    port map (
      O1 => \^qpll0lock_out\(0),
      drpaddr_common_in(8 downto 0) => drpaddr_common_in(8 downto 0),
      drpclk_common_in(0) => drpclk_common_in(0),
      drpdi_common_in(15 downto 0) => drpdi_common_in(15 downto 0),
      drpdo_common_out(15 downto 0) => drpdo_common_out(15 downto 0),
      drpen_common_in(0) => drpen_common_in(0),
      drprdy_common_out(0) => drprdy_common_out(0),
      drpwe_common_in(0) => drpwe_common_in(0),
      gtgrefclk0_in(0) => gtgrefclk0_in(0),
      gtgrefclk1_in(0) => gtgrefclk1_in(0),
      gtnorthrefclk00_in(0) => gtnorthrefclk00_in(0),
      gtnorthrefclk01_in(0) => gtnorthrefclk01_in(0),
      gtnorthrefclk10_in(0) => gtnorthrefclk10_in(0),
      gtnorthrefclk11_in(0) => gtnorthrefclk11_in(0),
      gtrefclk00_in(0) => gtrefclk00_in(0),
      gtrefclk01_in(0) => gtrefclk01_in(0),
      gtrefclk10_in(0) => gtrefclk10_in(0),
      gtrefclk11_in(0) => gtrefclk11_in(0),
      gtsouthrefclk00_in(0) => gtsouthrefclk00_in(0),
      gtsouthrefclk01_in(0) => gtsouthrefclk01_in(0),
      gtsouthrefclk10_in(0) => gtsouthrefclk10_in(0),
      gtsouthrefclk11_in(0) => gtsouthrefclk11_in(0),
      gtwiz_reset_qpll0reset_out(0) => \^gtwiz_reset_qpll0reset_out\(0),
      pmarsvdout0_out(7 downto 0) => pmarsvdout0_out(7 downto 0),
      pmarsvdout1_out(7 downto 0) => pmarsvdout1_out(7 downto 0),
      qpll0clkrsvd0_in(0) => qpll0clkrsvd0_in(0),
      qpll0clkrsvd1_in(0) => qpll0clkrsvd1_in(0),
      qpll0fbclklost_out(0) => qpll0fbclklost_out(0),
      qpll0lockdetclk_in(0) => qpll0lockdetclk_in(0),
      qpll0locken_in(0) => qpll0locken_in(0),
      qpll0outclk_out(0) => \^qpll0outclk_out\(0),
      qpll0outrefclk_out(0) => \^qpll0outrefclk_out\(0),
      qpll0pd_in(0) => qpll0pd_in(0),
      qpll0refclklost_out(0) => qpll0refclklost_out(0),
      qpll0refclksel_in(2 downto 0) => qpll0refclksel_in(2 downto 0),
      qpll1clkrsvd0_in(0) => qpll1clkrsvd0_in(0),
      qpll1clkrsvd1_in(0) => qpll1clkrsvd1_in(0),
      qpll1fbclklost_out(0) => qpll1fbclklost_out(0),
      qpll1lock_out(0) => qpll1lock_out(0),
      qpll1lockdetclk_in(0) => qpll1lockdetclk_in(0),
      qpll1locken_in(0) => qpll1locken_in(0),
      qpll1outclk_out(0) => \^qpll1outclk_out\(0),
      qpll1outrefclk_out(0) => \^qpll1outrefclk_out\(0),
      qpll1pd_in(0) => qpll1pd_in(0),
      qpll1refclklost_out(0) => qpll1refclklost_out(0),
      qpll1refclksel_in(2 downto 0) => qpll1refclksel_in(2 downto 0),
      qpll1reset_in(0) => qpll1reset_in(0),
      qplldmonitor0_out(7 downto 0) => qplldmonitor0_out(7 downto 0),
      qplldmonitor1_out(7 downto 0) => qplldmonitor1_out(7 downto 0),
      qpllrsvd1_in(7 downto 0) => qpllrsvd1_in(7 downto 0),
      qpllrsvd2_in(4 downto 0) => qpllrsvd2_in(4 downto 0),
      qpllrsvd3_in(4 downto 0) => qpllrsvd3_in(4 downto 0),
      qpllrsvd4_in(7 downto 0) => qpllrsvd4_in(7 downto 0),
      refclkoutmonitor0_out(0) => refclkoutmonitor0_out(0),
      refclkoutmonitor1_out(0) => refclkoutmonitor1_out(0),
      rst_in0 => rst_in0,
      rxrecclk0_sel_out(1 downto 0) => rxrecclk0_sel_out(1 downto 0),
      rxrecclk1_sel_out(1 downto 0) => rxrecclk1_sel_out(1 downto 0)
    );
\gen_gtwizard_gthe3.gen_reset_controller_internal.gen_single_instance.gtwiz_reset_inst\: entity work.GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset
    port map (
      GTHE3_CHANNEL_GTRXRESET(0) => gtwiz_reset_gtrxreset_int,
      GTHE3_CHANNEL_GTTXRESET(0) => gtwiz_reset_gttxreset_int,
      GTHE3_CHANNEL_RXPROGDIVRESET(0) => gtwiz_reset_rxprogdivreset_int,
      GTHE3_CHANNEL_RXUSERRDY(0) => gtwiz_reset_rxuserrdy_int,
      GTHE3_CHANNEL_TXPROGDIVRESET(0) => gtwiz_reset_txprogdivreset_int,
      GTHE3_CHANNEL_TXUSERRDY(0) => gtwiz_reset_txuserrdy_int,
      I1 => \n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      I2 => \n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      I3 => \n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      I4 => \n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst\,
      gtwiz_reset_all_in(0) => gtwiz_reset_all_in(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_qpll0reset_out(0) => \^gtwiz_reset_qpll0reset_out\(0),
      gtwiz_reset_rx_cdr_stable_out(0) => gtwiz_reset_rx_cdr_stable_out(0),
      gtwiz_reset_rx_datapath_in(0) => gtwiz_reset_rx_datapath_in(0),
      gtwiz_reset_rx_done_out(0) => gtwiz_reset_rx_done_out(0),
      gtwiz_reset_rx_pll_and_datapath_in(0) => gtwiz_reset_rx_pll_and_datapath_in(0),
      gtwiz_reset_tx_datapath_in(0) => gtwiz_reset_tx_datapath_in(0),
      gtwiz_reset_tx_done_out(0) => gtwiz_reset_tx_done_out(0),
      gtwiz_reset_tx_pll_and_datapath_in(0) => gtwiz_reset_tx_pll_and_datapath_in(0),
      gtwiz_userclk_rx_active_in(0) => gtwiz_userclk_rx_active_in(0),
      gtwiz_userclk_tx_active_in(0) => gtwiz_userclk_tx_active_in(0),
      qpll0lock_out(0) => \^qpll0lock_out\(0),
      rst_in0 => rst_in0,
      rxusrclk2_in(0) => rxusrclk2_in(0),
      txusrclk2_in(0) => txusrclk2_in(0)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top is
  port (
    gtwiz_userclk_tx_reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_srcclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_usrclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_usrclk2_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_tx_active_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_srcclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_usrclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_usrclk2_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_active_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_tx_reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_tx_start_user_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_tx_error_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_rx_reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_rx_start_user_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_buffbypass_rx_error_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_done_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_done_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll0lock_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll1lock_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll0reset_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_qpll1reset_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_gthe3_cpll_cal_txoutclk_period_in : in STD_LOGIC_VECTOR ( 35 downto 0 );
    gtwiz_gthe3_cpll_cal_cnt_tol_in : in STD_LOGIC_VECTOR ( 35 downto 0 );
    gtwiz_gthe3_cpll_cal_bufg_ce_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
    gtwiz_userdata_rx_out : out STD_LOGIC_VECTOR ( 63 downto 0 );
    bgbypassb_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    bgmonitorenb_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    bgpdb_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    bgrcalovrd_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    bgrcalovrdenb_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpaddr_common_in : in STD_LOGIC_VECTOR ( 8 downto 0 );
    drpclk_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpdi_common_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drpen_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpwe_common_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtgrefclk1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtnorthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk01_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk10_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtsouthrefclk11_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    pmarsvd0_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    pmarsvd1_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    qpll0clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpll0reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd0_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1clkrsvd1_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lockdetclk_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1locken_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1pd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1refclksel_in : in STD_LOGIC_VECTOR ( 2 downto 0 );
    qpll1reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpllrsvd1_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    qpllrsvd2_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd3_in : in STD_LOGIC_VECTOR ( 4 downto 0 );
    qpllrsvd4_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rcalenb_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm0data_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm0reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm0width_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm1data_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm1reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    sdm1width_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    drpdo_common_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drprdy_common_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    pmarsvdout0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pmarsvdout1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qpll0fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1fbclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll1refclklost_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qplldmonitor0_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    qplldmonitor1_out : out STD_LOGIC_VECTOR ( 7 downto 0 );
    refclkoutmonitor0_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    refclkoutmonitor1_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    rxrecclk0_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclk1_sel_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    sdm0finalout_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    sdm0testdata_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    sdm1finalout_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    sdm1testdata_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    cdrstepdir_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    cdrstepsq_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    cdrstepsx_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    cfgreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    clkrsvd1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllockdetclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllocken_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllrefclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    cpllreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonfiforeset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonitorclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpaddr_in : in STD_LOGIC_VECTOR ( 17 downto 0 );
    drpclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpdi_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    drpen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    drpwe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    elpcaldvorwren_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    elpcalpaorwren_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    evoddphicaldone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphicalstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphidwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    evoddphixwren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescanreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescantrigger_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtgrefclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxn_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxp_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtnorthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtresetsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrsvd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    gtrxreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk0_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtsouthrefclk1_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gttxreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gtyrxn_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtyrxp_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    loopback_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    looprsvd_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    lpbkrxtxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    lpbktxrxseren_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieeqrxeqadaptdone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierstidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pciersttxsyncstart_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratedone_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    pcsrsvdin_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    pcsrsvdin2_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    pmarsvdin_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    qpll0clk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll0refclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll1clk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    qpll1refclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    resetovrd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rstclkentx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbufreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrfreqreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrresetrsv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbonden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondi_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    rxchbondlevel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxchbondmaster_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondslave_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxckcalreset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxcommadeten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagcctrl_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxdccforcestart_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    rxdfeagchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeagcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfelpmreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap10ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap11ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap12ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap13ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap14ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap15ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap2ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap3ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap4ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap5ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap6ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap7ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap8ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9hold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfetap9ovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeuthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfeutovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevphold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevpovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfevsen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdfexyden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxelecidlemode_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxgearboxslip_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgchold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmgcovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmhfovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmlfklovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxlpmosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmonitorsel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxoobreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoscalreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoshold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintcfg_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxosinten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinthold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobe_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosinttestovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbscntreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    rxprogdivreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpien_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rxratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslide_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippma_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    rxuserrdy_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    sigvalidclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    tstin_in : in STD_LOGIC_VECTOR ( 39 downto 0 );
    tx8b10bbypass_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    tx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txbufdiffctrl_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txcominit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomsas_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txcomwake_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txctrl0_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl1_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txdata_in : in STD_LOGIC_VECTOR ( 255 downto 0 );
    txdataextendrsvd_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txdccforcestart_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    txdccreset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    txdeemph_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdetectrx_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdiffctrl_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txdiffpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlybypass_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyhold_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlysreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txdlyupdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txelecidle_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txelforcestart_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    txheader_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
    txinhibit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txlatclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txmaincursor_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    txmargin_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txoutclksel_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txpcsreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpd_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpdelecidlemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalign_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlypd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlyreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphdlytstclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinit_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txphovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmovrden_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmpd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmsel_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpippmstepsize_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpisopd_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpllclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txpmareset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txpostcursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txpostcursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprbsforceerr_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprbssel_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
    txprecursor_in : in STD_LOGIC_VECTOR ( 9 downto 0 );
    txprecursorinv_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txprogdivreset_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpibiasen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpistrongpdown_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpiweakpup_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txrate_in : in STD_LOGIC_VECTOR ( 5 downto 0 );
    txratemode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsequence_in : in STD_LOGIC_VECTOR ( 13 downto 0 );
    txswing_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncallin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncin_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncmode_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txsysclksel_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    txuserrdy_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    bufgtce_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtcemask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtdiv_out : out STD_LOGIC_VECTOR ( 17 downto 0 );
    bufgtreset_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    bufgtrstmask_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    cpllfbclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cplllock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    cpllrefclklost_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    dmonitorout_out : out STD_LOGIC_VECTOR ( 33 downto 0 );
    drpdo_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    drprdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    eyescandataerror_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtpowergood_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtrefclkmonitor_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gtytxn_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtytxp_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    pcierategen3_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierateidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcierateqpllpd_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pcierateqpllreset_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pciesynctxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieusergen3rdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserphystatusrst_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcieuserratestart_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pcsrsvdout_out : out STD_LOGIC_VECTOR ( 23 downto 0 );
    phystatus_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pinrsrvdas_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    resetexception_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbufstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyterealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrlock_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcdrphdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanbondseq_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchanrealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxchbondo_out : out STD_LOGIC_VECTOR ( 9 downto 0 );
    rxckcaldone_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    rxclkcorcnt_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxcominitdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomsasdet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcomwakedet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxctrl0_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl1_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl2_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl3_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxdata_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
    rxdataextendrsvd_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxdatavalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxelecidle_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxheader_out : out STD_LOGIC_VECTOR ( 11 downto 0 );
    rxheadervalid_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxmonitorout_out : out STD_LOGIC_VECTOR ( 13 downto 0 );
    rxosintdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxosintstrobestarted_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxphalignerr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbserr_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprbslocked_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxrecclkout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsliderdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslipoutclkrdy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxslippmardy_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxstartofseq_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    rxstatus_out : out STD_LOGIC_VECTOR ( 5 downto 0 );
    rxsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxvalid_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txbufstatus_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    txcomfinish_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txdccdone_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    txdlysresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkfabric_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclkpcs_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphaligndone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txphinitdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txprgdivresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txqpisenp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txratedone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txsyncout_out : out STD_LOGIC_VECTOR ( 1 downto 0 )
  );
  attribute C_CHANNEL_ENABLE : string;
  attribute C_CHANNEL_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000";
  attribute C_COMMON_SCALING_FACTOR : integer;
  attribute C_COMMON_SCALING_FACTOR of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_CPLL_VCO_FREQUENCY : string;
  attribute C_CPLL_VCO_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "2578.125000";
  attribute C_FORCE_COMMONS : integer;
  attribute C_FORCE_COMMONS of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_FREERUN_FREQUENCY : string;
  attribute C_FREERUN_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_GT_TYPE : integer;
  attribute C_GT_TYPE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_GT_REV : integer;
  attribute C_GT_REV of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_INCLUDE_CPLL_CAL : integer;
  attribute C_INCLUDE_CPLL_CAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 2;
  attribute C_LOCATE_COMMON : integer;
  attribute C_LOCATE_COMMON of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_LOCATE_RESET_CONTROLLER : integer;
  attribute C_LOCATE_RESET_CONTROLLER of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_LOCATE_USER_DATA_WIDTH_SIZING : integer;
  attribute C_LOCATE_USER_DATA_WIDTH_SIZING of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER : integer;
  attribute C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_LOCATE_RX_USER_CLOCKING : integer;
  attribute C_LOCATE_RX_USER_CLOCKING of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER : integer;
  attribute C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_LOCATE_TX_USER_CLOCKING : integer;
  attribute C_LOCATE_TX_USER_CLOCKING of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RESET_CONTROLLER_INSTANCE_CTRL : integer;
  attribute C_RESET_CONTROLLER_INSTANCE_CTRL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_BUFFBYPASS_MODE : integer;
  attribute C_RX_BUFFBYPASS_MODE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_BUFFER_BYPASS_INSTANCE_CTRL : integer;
  attribute C_RX_BUFFER_BYPASS_INSTANCE_CTRL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_BUFFER_MODE : integer;
  attribute C_RX_BUFFER_MODE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_CB_DISP : string;
  attribute C_RX_CB_DISP of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "8'b00000000";
  attribute C_RX_CB_K : string;
  attribute C_RX_CB_K of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "8'b00000000";
  attribute C_RX_CB_MAX_LEVEL : integer;
  attribute C_RX_CB_MAX_LEVEL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_CB_LEN_SEQ : integer;
  attribute C_RX_CB_LEN_SEQ of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_CB_NUM_SEQ : integer;
  attribute C_RX_CB_NUM_SEQ of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_CB_VAL : string;
  attribute C_RX_CB_VAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_CC_DISP : string;
  attribute C_RX_CC_DISP of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "8'b00000000";
  attribute C_RX_CC_ENABLE : integer;
  attribute C_RX_CC_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_CC_K : string;
  attribute C_RX_CC_K of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "8'b00000000";
  attribute C_RX_CC_LEN_SEQ : integer;
  attribute C_RX_CC_LEN_SEQ of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_CC_NUM_SEQ : integer;
  attribute C_RX_CC_NUM_SEQ of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_CC_PERIODICITY : integer;
  attribute C_RX_CC_PERIODICITY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 5000;
  attribute C_RX_CC_VAL : string;
  attribute C_RX_CC_VAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_COMMA_M_ENABLE : integer;
  attribute C_RX_COMMA_M_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_COMMA_M_VAL : string;
  attribute C_RX_COMMA_M_VAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "10'b1010000011";
  attribute C_RX_COMMA_P_ENABLE : integer;
  attribute C_RX_COMMA_P_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_COMMA_P_VAL : string;
  attribute C_RX_COMMA_P_VAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "10'b0101111100";
  attribute C_RX_DATA_DECODING : integer;
  attribute C_RX_DATA_DECODING of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_ENABLE : integer;
  attribute C_RX_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_INT_DATA_WIDTH : integer;
  attribute C_RX_INT_DATA_WIDTH of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 40;
  attribute C_RX_LINE_RATE : string;
  attribute C_RX_LINE_RATE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "7.400000";
  attribute C_RX_MASTER_CHANNEL_IDX : integer;
  attribute C_RX_MASTER_CHANNEL_IDX of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 18;
  attribute C_RX_OUTCLK_BUFG_GT_DIV : integer;
  attribute C_RX_OUTCLK_BUFG_GT_DIV of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_OUTCLK_FREQUENCY : string;
  attribute C_RX_OUTCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_RX_OUTCLK_SOURCE : integer;
  attribute C_RX_OUTCLK_SOURCE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_PLL_TYPE : integer;
  attribute C_RX_PLL_TYPE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_RECCLK_OUTPUT : string;
  attribute C_RX_RECCLK_OUTPUT of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_REFCLK_FREQUENCY : string;
  attribute C_RX_REFCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "370.000000";
  attribute C_RX_SLIDE_MODE : integer;
  attribute C_RX_SLIDE_MODE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_USER_CLOCKING_CONTENTS : integer;
  attribute C_RX_USER_CLOCKING_CONTENTS of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_USER_CLOCKING_INSTANCE_CTRL : integer;
  attribute C_RX_USER_CLOCKING_INSTANCE_CTRL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK : integer;
  attribute C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 : integer;
  attribute C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_RX_USER_CLOCKING_SOURCE : integer;
  attribute C_RX_USER_CLOCKING_SOURCE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_RX_USER_DATA_WIDTH : integer;
  attribute C_RX_USER_DATA_WIDTH of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 32;
  attribute C_RX_USRCLK_FREQUENCY : string;
  attribute C_RX_USRCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_RX_USRCLK2_FREQUENCY : string;
  attribute C_RX_USRCLK2_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_SECONDARY_QPLL_ENABLE : integer;
  attribute C_SECONDARY_QPLL_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_SECONDARY_QPLL_REFCLK_FREQUENCY : string;
  attribute C_SECONDARY_QPLL_REFCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "257.812500";
  attribute C_TOTAL_NUM_CHANNELS : integer;
  attribute C_TOTAL_NUM_CHANNELS of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 2;
  attribute C_TOTAL_NUM_COMMONS : integer;
  attribute C_TOTAL_NUM_COMMONS of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TOTAL_NUM_COMMONS_EXAMPLE : integer;
  attribute C_TOTAL_NUM_COMMONS_EXAMPLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TXPROGDIV_FREQ_ENABLE : integer;
  attribute C_TXPROGDIV_FREQ_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TXPROGDIV_FREQ_SOURCE : integer;
  attribute C_TXPROGDIV_FREQ_SOURCE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TXPROGDIV_FREQ_VAL : string;
  attribute C_TXPROGDIV_FREQ_VAL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_TX_BUFFBYPASS_MODE : integer;
  attribute C_TX_BUFFBYPASS_MODE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_BUFFER_BYPASS_INSTANCE_CTRL : integer;
  attribute C_TX_BUFFER_BYPASS_INSTANCE_CTRL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_BUFFER_MODE : integer;
  attribute C_TX_BUFFER_MODE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_DATA_ENCODING : integer;
  attribute C_TX_DATA_ENCODING of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_ENABLE : integer;
  attribute C_TX_ENABLE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_INT_DATA_WIDTH : integer;
  attribute C_TX_INT_DATA_WIDTH of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 40;
  attribute C_TX_LINE_RATE : string;
  attribute C_TX_LINE_RATE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "7.400000";
  attribute C_TX_MASTER_CHANNEL_IDX : integer;
  attribute C_TX_MASTER_CHANNEL_IDX of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 18;
  attribute C_TX_OUTCLK_BUFG_GT_DIV : integer;
  attribute C_TX_OUTCLK_BUFG_GT_DIV of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_OUTCLK_FREQUENCY : string;
  attribute C_TX_OUTCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_TX_OUTCLK_SOURCE : integer;
  attribute C_TX_OUTCLK_SOURCE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_PLL_TYPE : integer;
  attribute C_TX_PLL_TYPE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_REFCLK_FREQUENCY : string;
  attribute C_TX_REFCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "370.000000";
  attribute C_TX_USER_CLOCKING_CONTENTS : integer;
  attribute C_TX_USER_CLOCKING_CONTENTS of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_USER_CLOCKING_INSTANCE_CTRL : integer;
  attribute C_TX_USER_CLOCKING_INSTANCE_CTRL of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK : integer;
  attribute C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 : integer;
  attribute C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 1;
  attribute C_TX_USER_CLOCKING_SOURCE : integer;
  attribute C_TX_USER_CLOCKING_SOURCE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 0;
  attribute C_TX_USER_DATA_WIDTH : integer;
  attribute C_TX_USER_DATA_WIDTH of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is 32;
  attribute C_TX_USRCLK_FREQUENCY : string;
  attribute C_TX_USRCLK_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute C_TX_USRCLK2_FREQUENCY : string;
  attribute C_TX_USRCLK2_FREQUENCY of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "185.000000";
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top : entity is "GthUltrascaleJesdCoregen_gtwizard_top";
end GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top;

architecture STRUCTURE of GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top is
  signal \<const0>\ : STD_LOGIC;
  signal \^gtwiz_userclk_rx_active_in\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^gtwiz_userclk_tx_active_in\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^qpll1reset_in\ : STD_LOGIC_VECTOR ( 0 to 0 );
  signal \^rxdata_out\ : STD_LOGIC_VECTOR ( 255 downto 0 );
begin
  \^gtwiz_userclk_rx_active_in\(0) <= gtwiz_userclk_rx_active_in(0);
  \^gtwiz_userclk_tx_active_in\(0) <= gtwiz_userclk_tx_active_in(0);
  \^qpll1reset_in\(0) <= qpll1reset_in(0);
  gtwiz_buffbypass_rx_done_out(0) <= \<const0>\;
  gtwiz_buffbypass_rx_error_out(0) <= \<const0>\;
  gtwiz_buffbypass_tx_done_out(0) <= \<const0>\;
  gtwiz_buffbypass_tx_error_out(0) <= \<const0>\;
  gtwiz_reset_qpll1reset_out(0) <= \^qpll1reset_in\(0);
  gtwiz_userclk_rx_active_out(0) <= \^gtwiz_userclk_rx_active_in\(0);
  gtwiz_userclk_rx_srcclk_out(0) <= \<const0>\;
  gtwiz_userclk_rx_usrclk2_out(0) <= \<const0>\;
  gtwiz_userclk_rx_usrclk_out(0) <= \<const0>\;
  gtwiz_userclk_tx_active_out(0) <= \^gtwiz_userclk_tx_active_in\(0);
  gtwiz_userclk_tx_srcclk_out(0) <= \<const0>\;
  gtwiz_userclk_tx_usrclk2_out(0) <= \<const0>\;
  gtwiz_userclk_tx_usrclk_out(0) <= \<const0>\;
  gtwiz_userdata_rx_out(63 downto 32) <= \^rxdata_out\(159 downto 128);
  gtwiz_userdata_rx_out(31 downto 0) <= \^rxdata_out\(31 downto 0);
  gtytxn_out(0) <= \<const0>\;
  gtytxp_out(0) <= \<const0>\;
  rxckcaldone_out(0) <= \<const0>\;
  rxdata_out(255 downto 0) <= \^rxdata_out\(255 downto 0);
  sdm0finalout_out(0) <= \<const0>\;
  sdm0testdata_out(0) <= \<const0>\;
  sdm1finalout_out(0) <= \<const0>\;
  sdm1testdata_out(0) <= \<const0>\;
  txdccdone_out(0) <= \<const0>\;
GND: unisim.vcomponents.GND
    port map (
      G => \<const0>\
    );
\gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst\: entity work.GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3
    port map (
      bufgtce_out(5 downto 0) => bufgtce_out(5 downto 0),
      bufgtcemask_out(5 downto 0) => bufgtcemask_out(5 downto 0),
      bufgtdiv_out(17 downto 0) => bufgtdiv_out(17 downto 0),
      bufgtreset_out(5 downto 0) => bufgtreset_out(5 downto 0),
      bufgtrstmask_out(5 downto 0) => bufgtrstmask_out(5 downto 0),
      cfgreset_in(1 downto 0) => cfgreset_in(1 downto 0),
      clkrsvd0_in(1 downto 0) => clkrsvd0_in(1 downto 0),
      clkrsvd1_in(1 downto 0) => clkrsvd1_in(1 downto 0),
      cpllfbclklost_out(1 downto 0) => cpllfbclklost_out(1 downto 0),
      cplllock_out(1 downto 0) => cplllock_out(1 downto 0),
      cplllockdetclk_in(1 downto 0) => cplllockdetclk_in(1 downto 0),
      cplllocken_in(1 downto 0) => cplllocken_in(1 downto 0),
      cpllpd_in(1 downto 0) => cpllpd_in(1 downto 0),
      cpllrefclklost_out(1 downto 0) => cpllrefclklost_out(1 downto 0),
      cpllrefclksel_in(5 downto 0) => cpllrefclksel_in(5 downto 0),
      cpllreset_in(1 downto 0) => cpllreset_in(1 downto 0),
      dmonfiforeset_in(1 downto 0) => dmonfiforeset_in(1 downto 0),
      dmonitorclk_in(1 downto 0) => dmonitorclk_in(1 downto 0),
      dmonitorout_out(33 downto 0) => dmonitorout_out(33 downto 0),
      drpaddr_common_in(8 downto 0) => drpaddr_common_in(8 downto 0),
      drpaddr_in(17 downto 0) => drpaddr_in(17 downto 0),
      drpclk_common_in(0) => drpclk_common_in(0),
      drpclk_in(1 downto 0) => drpclk_in(1 downto 0),
      drpdi_common_in(15 downto 0) => drpdi_common_in(15 downto 0),
      drpdi_in(31 downto 0) => drpdi_in(31 downto 0),
      drpdo_common_out(15 downto 0) => drpdo_common_out(15 downto 0),
      drpdo_out(31 downto 0) => drpdo_out(31 downto 0),
      drpen_common_in(0) => drpen_common_in(0),
      drpen_in(1 downto 0) => drpen_in(1 downto 0),
      drprdy_common_out(0) => drprdy_common_out(0),
      drprdy_out(1 downto 0) => drprdy_out(1 downto 0),
      drpwe_common_in(0) => drpwe_common_in(0),
      drpwe_in(1 downto 0) => drpwe_in(1 downto 0),
      evoddphicaldone_in(1 downto 0) => evoddphicaldone_in(1 downto 0),
      evoddphicalstart_in(1 downto 0) => evoddphicalstart_in(1 downto 0),
      evoddphidrden_in(1 downto 0) => evoddphidrden_in(1 downto 0),
      evoddphidwren_in(1 downto 0) => evoddphidwren_in(1 downto 0),
      evoddphixrden_in(1 downto 0) => evoddphixrden_in(1 downto 0),
      evoddphixwren_in(1 downto 0) => evoddphixwren_in(1 downto 0),
      eyescandataerror_out(1 downto 0) => eyescandataerror_out(1 downto 0),
      eyescanmode_in(1 downto 0) => eyescanmode_in(1 downto 0),
      eyescanreset_in(1 downto 0) => eyescanreset_in(1 downto 0),
      eyescantrigger_in(1 downto 0) => eyescantrigger_in(1 downto 0),
      gtgrefclk0_in(0) => gtgrefclk0_in(0),
      gtgrefclk1_in(0) => gtgrefclk1_in(0),
      gtgrefclk_in(1 downto 0) => gtgrefclk_in(1 downto 0),
      gthrxn_in(1 downto 0) => gthrxn_in(1 downto 0),
      gthrxp_in(1 downto 0) => gthrxp_in(1 downto 0),
      gthtxn_out(1 downto 0) => gthtxn_out(1 downto 0),
      gthtxp_out(1 downto 0) => gthtxp_out(1 downto 0),
      gtnorthrefclk00_in(0) => gtnorthrefclk00_in(0),
      gtnorthrefclk01_in(0) => gtnorthrefclk01_in(0),
      gtnorthrefclk0_in(1 downto 0) => gtnorthrefclk0_in(1 downto 0),
      gtnorthrefclk10_in(0) => gtnorthrefclk10_in(0),
      gtnorthrefclk11_in(0) => gtnorthrefclk11_in(0),
      gtnorthrefclk1_in(1 downto 0) => gtnorthrefclk1_in(1 downto 0),
      gtpowergood_out(1 downto 0) => gtpowergood_out(1 downto 0),
      gtrefclk00_in(0) => gtrefclk00_in(0),
      gtrefclk01_in(0) => gtrefclk01_in(0),
      gtrefclk0_in(1 downto 0) => gtrefclk0_in(1 downto 0),
      gtrefclk10_in(0) => gtrefclk10_in(0),
      gtrefclk11_in(0) => gtrefclk11_in(0),
      gtrefclk1_in(1 downto 0) => gtrefclk1_in(1 downto 0),
      gtrefclkmonitor_out(1 downto 0) => gtrefclkmonitor_out(1 downto 0),
      gtresetsel_in(1 downto 0) => gtresetsel_in(1 downto 0),
      gtrsvd_in(31 downto 0) => gtrsvd_in(31 downto 0),
      gtsouthrefclk00_in(0) => gtsouthrefclk00_in(0),
      gtsouthrefclk01_in(0) => gtsouthrefclk01_in(0),
      gtsouthrefclk0_in(1 downto 0) => gtsouthrefclk0_in(1 downto 0),
      gtsouthrefclk10_in(0) => gtsouthrefclk10_in(0),
      gtsouthrefclk11_in(0) => gtsouthrefclk11_in(0),
      gtsouthrefclk1_in(1 downto 0) => gtsouthrefclk1_in(1 downto 0),
      gtwiz_reset_all_in(0) => gtwiz_reset_all_in(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_qpll0reset_out(0) => gtwiz_reset_qpll0reset_out(0),
      gtwiz_reset_rx_cdr_stable_out(0) => gtwiz_reset_rx_cdr_stable_out(0),
      gtwiz_reset_rx_datapath_in(0) => gtwiz_reset_rx_datapath_in(0),
      gtwiz_reset_rx_done_out(0) => gtwiz_reset_rx_done_out(0),
      gtwiz_reset_rx_pll_and_datapath_in(0) => gtwiz_reset_rx_pll_and_datapath_in(0),
      gtwiz_reset_tx_datapath_in(0) => gtwiz_reset_tx_datapath_in(0),
      gtwiz_reset_tx_done_out(0) => gtwiz_reset_tx_done_out(0),
      gtwiz_reset_tx_pll_and_datapath_in(0) => gtwiz_reset_tx_pll_and_datapath_in(0),
      gtwiz_userclk_rx_active_in(0) => \^gtwiz_userclk_rx_active_in\(0),
      gtwiz_userclk_tx_active_in(0) => \^gtwiz_userclk_tx_active_in\(0),
      gtwiz_userdata_tx_in(63 downto 0) => gtwiz_userdata_tx_in(63 downto 0),
      loopback_in(5 downto 0) => loopback_in(5 downto 0),
      lpbkrxtxseren_in(1 downto 0) => lpbkrxtxseren_in(1 downto 0),
      lpbktxrxseren_in(1 downto 0) => lpbktxrxseren_in(1 downto 0),
      pcieeqrxeqadaptdone_in(1 downto 0) => pcieeqrxeqadaptdone_in(1 downto 0),
      pcierategen3_out(1 downto 0) => pcierategen3_out(1 downto 0),
      pcierateidle_out(1 downto 0) => pcierateidle_out(1 downto 0),
      pcierateqpllpd_out(3 downto 0) => pcierateqpllpd_out(3 downto 0),
      pcierateqpllreset_out(3 downto 0) => pcierateqpllreset_out(3 downto 0),
      pcierstidle_in(1 downto 0) => pcierstidle_in(1 downto 0),
      pciersttxsyncstart_in(1 downto 0) => pciersttxsyncstart_in(1 downto 0),
      pciesynctxsyncdone_out(1 downto 0) => pciesynctxsyncdone_out(1 downto 0),
      pcieusergen3rdy_out(1 downto 0) => pcieusergen3rdy_out(1 downto 0),
      pcieuserphystatusrst_out(1 downto 0) => pcieuserphystatusrst_out(1 downto 0),
      pcieuserratedone_in(1 downto 0) => pcieuserratedone_in(1 downto 0),
      pcieuserratestart_out(1 downto 0) => pcieuserratestart_out(1 downto 0),
      pcsrsvdin2_in(9 downto 0) => pcsrsvdin2_in(9 downto 0),
      pcsrsvdin_in(31 downto 0) => pcsrsvdin_in(31 downto 0),
      pcsrsvdout_out(23 downto 0) => pcsrsvdout_out(23 downto 0),
      phystatus_out(1 downto 0) => phystatus_out(1 downto 0),
      pinrsrvdas_out(15 downto 0) => pinrsrvdas_out(15 downto 0),
      pmarsvdin_in(9 downto 0) => pmarsvdin_in(9 downto 0),
      pmarsvdout0_out(7 downto 0) => pmarsvdout0_out(7 downto 0),
      pmarsvdout1_out(7 downto 0) => pmarsvdout1_out(7 downto 0),
      qpll0clkrsvd0_in(0) => qpll0clkrsvd0_in(0),
      qpll0clkrsvd1_in(0) => qpll0clkrsvd1_in(0),
      qpll0fbclklost_out(0) => qpll0fbclklost_out(0),
      qpll0lock_out(0) => qpll0lock_out(0),
      qpll0lockdetclk_in(0) => qpll0lockdetclk_in(0),
      qpll0locken_in(0) => qpll0locken_in(0),
      qpll0outclk_out(0) => qpll0outclk_out(0),
      qpll0outrefclk_out(0) => qpll0outrefclk_out(0),
      qpll0pd_in(0) => qpll0pd_in(0),
      qpll0refclklost_out(0) => qpll0refclklost_out(0),
      qpll0refclksel_in(2 downto 0) => qpll0refclksel_in(2 downto 0),
      qpll1clkrsvd0_in(0) => qpll1clkrsvd0_in(0),
      qpll1clkrsvd1_in(0) => qpll1clkrsvd1_in(0),
      qpll1fbclklost_out(0) => qpll1fbclklost_out(0),
      qpll1lock_out(0) => qpll1lock_out(0),
      qpll1lockdetclk_in(0) => qpll1lockdetclk_in(0),
      qpll1locken_in(0) => qpll1locken_in(0),
      qpll1outclk_out(0) => qpll1outclk_out(0),
      qpll1outrefclk_out(0) => qpll1outrefclk_out(0),
      qpll1pd_in(0) => qpll1pd_in(0),
      qpll1refclklost_out(0) => qpll1refclklost_out(0),
      qpll1refclksel_in(2 downto 0) => qpll1refclksel_in(2 downto 0),
      qpll1reset_in(0) => \^qpll1reset_in\(0),
      qplldmonitor0_out(7 downto 0) => qplldmonitor0_out(7 downto 0),
      qplldmonitor1_out(7 downto 0) => qplldmonitor1_out(7 downto 0),
      qpllrsvd1_in(7 downto 0) => qpllrsvd1_in(7 downto 0),
      qpllrsvd2_in(4 downto 0) => qpllrsvd2_in(4 downto 0),
      qpllrsvd3_in(4 downto 0) => qpllrsvd3_in(4 downto 0),
      qpllrsvd4_in(7 downto 0) => qpllrsvd4_in(7 downto 0),
      refclkoutmonitor0_out(0) => refclkoutmonitor0_out(0),
      refclkoutmonitor1_out(0) => refclkoutmonitor1_out(0),
      resetexception_out(1 downto 0) => resetexception_out(1 downto 0),
      resetovrd_in(1 downto 0) => resetovrd_in(1 downto 0),
      rstclkentx_in(1 downto 0) => rstclkentx_in(1 downto 0),
      rx8b10ben_in(1 downto 0) => rx8b10ben_in(1 downto 0),
      rxbufreset_in(1 downto 0) => rxbufreset_in(1 downto 0),
      rxbufstatus_out(5 downto 0) => rxbufstatus_out(5 downto 0),
      rxbyteisaligned_out(1 downto 0) => rxbyteisaligned_out(1 downto 0),
      rxbyterealign_out(1 downto 0) => rxbyterealign_out(1 downto 0),
      rxcdrfreqreset_in(1 downto 0) => rxcdrfreqreset_in(1 downto 0),
      rxcdrhold_in(1 downto 0) => rxcdrhold_in(1 downto 0),
      rxcdrlock_out(1 downto 0) => rxcdrlock_out(1 downto 0),
      rxcdrovrden_in(1 downto 0) => rxcdrovrden_in(1 downto 0),
      rxcdrphdone_out(1 downto 0) => rxcdrphdone_out(1 downto 0),
      rxcdrreset_in(1 downto 0) => rxcdrreset_in(1 downto 0),
      rxcdrresetrsv_in(1 downto 0) => rxcdrresetrsv_in(1 downto 0),
      rxchanbondseq_out(1 downto 0) => rxchanbondseq_out(1 downto 0),
      rxchanisaligned_out(1 downto 0) => rxchanisaligned_out(1 downto 0),
      rxchanrealign_out(1 downto 0) => rxchanrealign_out(1 downto 0),
      rxchbonden_in(1 downto 0) => rxchbonden_in(1 downto 0),
      rxchbondi_in(9 downto 0) => rxchbondi_in(9 downto 0),
      rxchbondlevel_in(5 downto 0) => rxchbondlevel_in(5 downto 0),
      rxchbondmaster_in(1 downto 0) => rxchbondmaster_in(1 downto 0),
      rxchbondo_out(9 downto 0) => rxchbondo_out(9 downto 0),
      rxchbondslave_in(1 downto 0) => rxchbondslave_in(1 downto 0),
      rxclkcorcnt_out(3 downto 0) => rxclkcorcnt_out(3 downto 0),
      rxcominitdet_out(1 downto 0) => rxcominitdet_out(1 downto 0),
      rxcommadet_out(1 downto 0) => rxcommadet_out(1 downto 0),
      rxcommadeten_in(1 downto 0) => rxcommadeten_in(1 downto 0),
      rxcomsasdet_out(1 downto 0) => rxcomsasdet_out(1 downto 0),
      rxcomwakedet_out(1 downto 0) => rxcomwakedet_out(1 downto 0),
      rxctrl0_out(31 downto 0) => rxctrl0_out(31 downto 0),
      rxctrl1_out(31 downto 0) => rxctrl1_out(31 downto 0),
      rxctrl2_out(15 downto 0) => rxctrl2_out(15 downto 0),
      rxctrl3_out(15 downto 0) => rxctrl3_out(15 downto 0),
      rxdata_out(255 downto 0) => \^rxdata_out\(255 downto 0),
      rxdataextendrsvd_out(15 downto 0) => rxdataextendrsvd_out(15 downto 0),
      rxdatavalid_out(3 downto 0) => rxdatavalid_out(3 downto 0),
      rxdfeagcctrl_in(3 downto 0) => rxdfeagcctrl_in(3 downto 0),
      rxdfeagchold_in(1 downto 0) => rxdfeagchold_in(1 downto 0),
      rxdfeagcovrden_in(1 downto 0) => rxdfeagcovrden_in(1 downto 0),
      rxdfelfhold_in(1 downto 0) => rxdfelfhold_in(1 downto 0),
      rxdfelfovrden_in(1 downto 0) => rxdfelfovrden_in(1 downto 0),
      rxdfelpmreset_in(1 downto 0) => rxdfelpmreset_in(1 downto 0),
      rxdfetap10hold_in(1 downto 0) => rxdfetap10hold_in(1 downto 0),
      rxdfetap10ovrden_in(1 downto 0) => rxdfetap10ovrden_in(1 downto 0),
      rxdfetap11hold_in(1 downto 0) => rxdfetap11hold_in(1 downto 0),
      rxdfetap11ovrden_in(1 downto 0) => rxdfetap11ovrden_in(1 downto 0),
      rxdfetap12hold_in(1 downto 0) => rxdfetap12hold_in(1 downto 0),
      rxdfetap12ovrden_in(1 downto 0) => rxdfetap12ovrden_in(1 downto 0),
      rxdfetap13hold_in(1 downto 0) => rxdfetap13hold_in(1 downto 0),
      rxdfetap13ovrden_in(1 downto 0) => rxdfetap13ovrden_in(1 downto 0),
      rxdfetap14hold_in(1 downto 0) => rxdfetap14hold_in(1 downto 0),
      rxdfetap14ovrden_in(1 downto 0) => rxdfetap14ovrden_in(1 downto 0),
      rxdfetap15hold_in(1 downto 0) => rxdfetap15hold_in(1 downto 0),
      rxdfetap15ovrden_in(1 downto 0) => rxdfetap15ovrden_in(1 downto 0),
      rxdfetap2hold_in(1 downto 0) => rxdfetap2hold_in(1 downto 0),
      rxdfetap2ovrden_in(1 downto 0) => rxdfetap2ovrden_in(1 downto 0),
      rxdfetap3hold_in(1 downto 0) => rxdfetap3hold_in(1 downto 0),
      rxdfetap3ovrden_in(1 downto 0) => rxdfetap3ovrden_in(1 downto 0),
      rxdfetap4hold_in(1 downto 0) => rxdfetap4hold_in(1 downto 0),
      rxdfetap4ovrden_in(1 downto 0) => rxdfetap4ovrden_in(1 downto 0),
      rxdfetap5hold_in(1 downto 0) => rxdfetap5hold_in(1 downto 0),
      rxdfetap5ovrden_in(1 downto 0) => rxdfetap5ovrden_in(1 downto 0),
      rxdfetap6hold_in(1 downto 0) => rxdfetap6hold_in(1 downto 0),
      rxdfetap6ovrden_in(1 downto 0) => rxdfetap6ovrden_in(1 downto 0),
      rxdfetap7hold_in(1 downto 0) => rxdfetap7hold_in(1 downto 0),
      rxdfetap7ovrden_in(1 downto 0) => rxdfetap7ovrden_in(1 downto 0),
      rxdfetap8hold_in(1 downto 0) => rxdfetap8hold_in(1 downto 0),
      rxdfetap8ovrden_in(1 downto 0) => rxdfetap8ovrden_in(1 downto 0),
      rxdfetap9hold_in(1 downto 0) => rxdfetap9hold_in(1 downto 0),
      rxdfetap9ovrden_in(1 downto 0) => rxdfetap9ovrden_in(1 downto 0),
      rxdfeuthold_in(1 downto 0) => rxdfeuthold_in(1 downto 0),
      rxdfeutovrden_in(1 downto 0) => rxdfeutovrden_in(1 downto 0),
      rxdfevphold_in(1 downto 0) => rxdfevphold_in(1 downto 0),
      rxdfevpovrden_in(1 downto 0) => rxdfevpovrden_in(1 downto 0),
      rxdfevsen_in(1 downto 0) => rxdfevsen_in(1 downto 0),
      rxdfexyden_in(1 downto 0) => rxdfexyden_in(1 downto 0),
      rxdlybypass_in(1 downto 0) => rxdlybypass_in(1 downto 0),
      rxdlyen_in(1 downto 0) => rxdlyen_in(1 downto 0),
      rxdlyovrden_in(1 downto 0) => rxdlyovrden_in(1 downto 0),
      rxdlysreset_in(1 downto 0) => rxdlysreset_in(1 downto 0),
      rxdlysresetdone_out(1 downto 0) => rxdlysresetdone_out(1 downto 0),
      rxelecidle_out(1 downto 0) => rxelecidle_out(1 downto 0),
      rxelecidlemode_in(3 downto 0) => rxelecidlemode_in(3 downto 0),
      rxgearboxslip_in(1 downto 0) => rxgearboxslip_in(1 downto 0),
      rxheader_out(11 downto 0) => rxheader_out(11 downto 0),
      rxheadervalid_out(3 downto 0) => rxheadervalid_out(3 downto 0),
      rxlatclk_in(1 downto 0) => rxlatclk_in(1 downto 0),
      rxlpmen_in(1 downto 0) => rxlpmen_in(1 downto 0),
      rxlpmgchold_in(1 downto 0) => rxlpmgchold_in(1 downto 0),
      rxlpmgcovrden_in(1 downto 0) => rxlpmgcovrden_in(1 downto 0),
      rxlpmhfhold_in(1 downto 0) => rxlpmhfhold_in(1 downto 0),
      rxlpmhfovrden_in(1 downto 0) => rxlpmhfovrden_in(1 downto 0),
      rxlpmlfhold_in(1 downto 0) => rxlpmlfhold_in(1 downto 0),
      rxlpmlfklovrden_in(1 downto 0) => rxlpmlfklovrden_in(1 downto 0),
      rxlpmoshold_in(1 downto 0) => rxlpmoshold_in(1 downto 0),
      rxlpmosovrden_in(1 downto 0) => rxlpmosovrden_in(1 downto 0),
      rxmcommaalignen_in(1 downto 0) => rxmcommaalignen_in(1 downto 0),
      rxmonitorout_out(13 downto 0) => rxmonitorout_out(13 downto 0),
      rxmonitorsel_in(3 downto 0) => rxmonitorsel_in(3 downto 0),
      rxoobreset_in(1 downto 0) => rxoobreset_in(1 downto 0),
      rxoscalreset_in(1 downto 0) => rxoscalreset_in(1 downto 0),
      rxoshold_in(1 downto 0) => rxoshold_in(1 downto 0),
      rxosintcfg_in(7 downto 0) => rxosintcfg_in(7 downto 0),
      rxosintdone_out(1 downto 0) => rxosintdone_out(1 downto 0),
      rxosinten_in(1 downto 0) => rxosinten_in(1 downto 0),
      rxosinthold_in(1 downto 0) => rxosinthold_in(1 downto 0),
      rxosintovrden_in(1 downto 0) => rxosintovrden_in(1 downto 0),
      rxosintstarted_out(1 downto 0) => rxosintstarted_out(1 downto 0),
      rxosintstrobe_in(1 downto 0) => rxosintstrobe_in(1 downto 0),
      rxosintstrobedone_out(1 downto 0) => rxosintstrobedone_out(1 downto 0),
      rxosintstrobestarted_out(1 downto 0) => rxosintstrobestarted_out(1 downto 0),
      rxosinttestovrden_in(1 downto 0) => rxosinttestovrden_in(1 downto 0),
      rxosovrden_in(1 downto 0) => rxosovrden_in(1 downto 0),
      rxoutclk_out(1 downto 0) => rxoutclk_out(1 downto 0),
      rxoutclkfabric_out(1 downto 0) => rxoutclkfabric_out(1 downto 0),
      rxoutclkpcs_out(1 downto 0) => rxoutclkpcs_out(1 downto 0),
      rxoutclksel_in(5 downto 0) => rxoutclksel_in(5 downto 0),
      rxpcommaalignen_in(1 downto 0) => rxpcommaalignen_in(1 downto 0),
      rxpcsreset_in(1 downto 0) => rxpcsreset_in(1 downto 0),
      rxpd_in(3 downto 0) => rxpd_in(3 downto 0),
      rxphalign_in(1 downto 0) => rxphalign_in(1 downto 0),
      rxphaligndone_out(1 downto 0) => rxphaligndone_out(1 downto 0),
      rxphalignen_in(1 downto 0) => rxphalignen_in(1 downto 0),
      rxphalignerr_out(1 downto 0) => rxphalignerr_out(1 downto 0),
      rxphdlypd_in(1 downto 0) => rxphdlypd_in(1 downto 0),
      rxphdlyreset_in(1 downto 0) => rxphdlyreset_in(1 downto 0),
      rxphovrden_in(1 downto 0) => rxphovrden_in(1 downto 0),
      rxpllclksel_in(3 downto 0) => rxpllclksel_in(3 downto 0),
      rxpmareset_in(1 downto 0) => rxpmareset_in(1 downto 0),
      rxpmaresetdone_out(1 downto 0) => rxpmaresetdone_out(1 downto 0),
      rxpolarity_in(1 downto 0) => rxpolarity_in(1 downto 0),
      rxprbscntreset_in(1 downto 0) => rxprbscntreset_in(1 downto 0),
      rxprbserr_out(1 downto 0) => rxprbserr_out(1 downto 0),
      rxprbslocked_out(1 downto 0) => rxprbslocked_out(1 downto 0),
      rxprbssel_in(7 downto 0) => rxprbssel_in(7 downto 0),
      rxprgdivresetdone_out(1 downto 0) => rxprgdivresetdone_out(1 downto 0),
      rxqpien_in(1 downto 0) => rxqpien_in(1 downto 0),
      rxqpisenn_out(1 downto 0) => rxqpisenn_out(1 downto 0),
      rxqpisenp_out(1 downto 0) => rxqpisenp_out(1 downto 0),
      rxrate_in(5 downto 0) => rxrate_in(5 downto 0),
      rxratedone_out(1 downto 0) => rxratedone_out(1 downto 0),
      rxratemode_in(1 downto 0) => rxratemode_in(1 downto 0),
      rxrecclk0_sel_out(1 downto 0) => rxrecclk0_sel_out(1 downto 0),
      rxrecclk1_sel_out(1 downto 0) => rxrecclk1_sel_out(1 downto 0),
      rxrecclkout_out(1 downto 0) => rxrecclkout_out(1 downto 0),
      rxresetdone_out(1 downto 0) => rxresetdone_out(1 downto 0),
      rxslide_in(1 downto 0) => rxslide_in(1 downto 0),
      rxsliderdy_out(1 downto 0) => rxsliderdy_out(1 downto 0),
      rxslipdone_out(1 downto 0) => rxslipdone_out(1 downto 0),
      rxslipoutclk_in(1 downto 0) => rxslipoutclk_in(1 downto 0),
      rxslipoutclkrdy_out(1 downto 0) => rxslipoutclkrdy_out(1 downto 0),
      rxslippma_in(1 downto 0) => rxslippma_in(1 downto 0),
      rxslippmardy_out(1 downto 0) => rxslippmardy_out(1 downto 0),
      rxstartofseq_out(3 downto 0) => rxstartofseq_out(3 downto 0),
      rxstatus_out(5 downto 0) => rxstatus_out(5 downto 0),
      rxsyncallin_in(1 downto 0) => rxsyncallin_in(1 downto 0),
      rxsyncdone_out(1 downto 0) => rxsyncdone_out(1 downto 0),
      rxsyncin_in(1 downto 0) => rxsyncin_in(1 downto 0),
      rxsyncmode_in(1 downto 0) => rxsyncmode_in(1 downto 0),
      rxsyncout_out(1 downto 0) => rxsyncout_out(1 downto 0),
      rxsysclksel_in(3 downto 0) => rxsysclksel_in(3 downto 0),
      rxusrclk2_in(1 downto 0) => rxusrclk2_in(1 downto 0),
      rxusrclk_in(1 downto 0) => rxusrclk_in(1 downto 0),
      rxvalid_out(1 downto 0) => rxvalid_out(1 downto 0),
      sigvalidclk_in(1 downto 0) => sigvalidclk_in(1 downto 0),
      tx8b10bbypass_in(15 downto 0) => tx8b10bbypass_in(15 downto 0),
      tx8b10ben_in(1 downto 0) => tx8b10ben_in(1 downto 0),
      txbufdiffctrl_in(5 downto 0) => txbufdiffctrl_in(5 downto 0),
      txbufstatus_out(3 downto 0) => txbufstatus_out(3 downto 0),
      txcomfinish_out(1 downto 0) => txcomfinish_out(1 downto 0),
      txcominit_in(1 downto 0) => txcominit_in(1 downto 0),
      txcomsas_in(1 downto 0) => txcomsas_in(1 downto 0),
      txcomwake_in(1 downto 0) => txcomwake_in(1 downto 0),
      txctrl0_in(31 downto 0) => txctrl0_in(31 downto 0),
      txctrl1_in(31 downto 0) => txctrl1_in(31 downto 0),
      txctrl2_in(15 downto 0) => txctrl2_in(15 downto 0),
      txdataextendrsvd_in(15 downto 0) => txdataextendrsvd_in(15 downto 0),
      txdeemph_in(1 downto 0) => txdeemph_in(1 downto 0),
      txdetectrx_in(1 downto 0) => txdetectrx_in(1 downto 0),
      txdiffctrl_in(7 downto 0) => txdiffctrl_in(7 downto 0),
      txdiffpd_in(1 downto 0) => txdiffpd_in(1 downto 0),
      txdlybypass_in(1 downto 0) => txdlybypass_in(1 downto 0),
      txdlyen_in(1 downto 0) => txdlyen_in(1 downto 0),
      txdlyhold_in(1 downto 0) => txdlyhold_in(1 downto 0),
      txdlyovrden_in(1 downto 0) => txdlyovrden_in(1 downto 0),
      txdlysreset_in(1 downto 0) => txdlysreset_in(1 downto 0),
      txdlysresetdone_out(1 downto 0) => txdlysresetdone_out(1 downto 0),
      txdlyupdown_in(1 downto 0) => txdlyupdown_in(1 downto 0),
      txelecidle_in(1 downto 0) => txelecidle_in(1 downto 0),
      txheader_in(11 downto 0) => txheader_in(11 downto 0),
      txinhibit_in(1 downto 0) => txinhibit_in(1 downto 0),
      txlatclk_in(1 downto 0) => txlatclk_in(1 downto 0),
      txmaincursor_in(13 downto 0) => txmaincursor_in(13 downto 0),
      txmargin_in(5 downto 0) => txmargin_in(5 downto 0),
      txoutclk_out(1 downto 0) => txoutclk_out(1 downto 0),
      txoutclkfabric_out(1 downto 0) => txoutclkfabric_out(1 downto 0),
      txoutclkpcs_out(1 downto 0) => txoutclkpcs_out(1 downto 0),
      txoutclksel_in(5 downto 0) => txoutclksel_in(5 downto 0),
      txpcsreset_in(1 downto 0) => txpcsreset_in(1 downto 0),
      txpd_in(3 downto 0) => txpd_in(3 downto 0),
      txpdelecidlemode_in(1 downto 0) => txpdelecidlemode_in(1 downto 0),
      txphalign_in(1 downto 0) => txphalign_in(1 downto 0),
      txphaligndone_out(1 downto 0) => txphaligndone_out(1 downto 0),
      txphalignen_in(1 downto 0) => txphalignen_in(1 downto 0),
      txphdlypd_in(1 downto 0) => txphdlypd_in(1 downto 0),
      txphdlyreset_in(1 downto 0) => txphdlyreset_in(1 downto 0),
      txphdlytstclk_in(1 downto 0) => txphdlytstclk_in(1 downto 0),
      txphinit_in(1 downto 0) => txphinit_in(1 downto 0),
      txphinitdone_out(1 downto 0) => txphinitdone_out(1 downto 0),
      txphovrden_in(1 downto 0) => txphovrden_in(1 downto 0),
      txpippmen_in(1 downto 0) => txpippmen_in(1 downto 0),
      txpippmovrden_in(1 downto 0) => txpippmovrden_in(1 downto 0),
      txpippmpd_in(1 downto 0) => txpippmpd_in(1 downto 0),
      txpippmsel_in(1 downto 0) => txpippmsel_in(1 downto 0),
      txpippmstepsize_in(9 downto 0) => txpippmstepsize_in(9 downto 0),
      txpisopd_in(1 downto 0) => txpisopd_in(1 downto 0),
      txpllclksel_in(3 downto 0) => txpllclksel_in(3 downto 0),
      txpmareset_in(1 downto 0) => txpmareset_in(1 downto 0),
      txpmaresetdone_out(1 downto 0) => txpmaresetdone_out(1 downto 0),
      txpolarity_in(1 downto 0) => txpolarity_in(1 downto 0),
      txpostcursor_in(9 downto 0) => txpostcursor_in(9 downto 0),
      txpostcursorinv_in(1 downto 0) => txpostcursorinv_in(1 downto 0),
      txprbsforceerr_in(1 downto 0) => txprbsforceerr_in(1 downto 0),
      txprbssel_in(7 downto 0) => txprbssel_in(7 downto 0),
      txprecursor_in(9 downto 0) => txprecursor_in(9 downto 0),
      txprecursorinv_in(1 downto 0) => txprecursorinv_in(1 downto 0),
      txprgdivresetdone_out(1 downto 0) => txprgdivresetdone_out(1 downto 0),
      txqpibiasen_in(1 downto 0) => txqpibiasen_in(1 downto 0),
      txqpisenn_out(1 downto 0) => txqpisenn_out(1 downto 0),
      txqpisenp_out(1 downto 0) => txqpisenp_out(1 downto 0),
      txqpistrongpdown_in(1 downto 0) => txqpistrongpdown_in(1 downto 0),
      txqpiweakpup_in(1 downto 0) => txqpiweakpup_in(1 downto 0),
      txrate_in(5 downto 0) => txrate_in(5 downto 0),
      txratedone_out(1 downto 0) => txratedone_out(1 downto 0),
      txratemode_in(1 downto 0) => txratemode_in(1 downto 0),
      txresetdone_out(1 downto 0) => txresetdone_out(1 downto 0),
      txsequence_in(13 downto 0) => txsequence_in(13 downto 0),
      txswing_in(1 downto 0) => txswing_in(1 downto 0),
      txsyncallin_in(1 downto 0) => txsyncallin_in(1 downto 0),
      txsyncdone_out(1 downto 0) => txsyncdone_out(1 downto 0),
      txsyncin_in(1 downto 0) => txsyncin_in(1 downto 0),
      txsyncmode_in(1 downto 0) => txsyncmode_in(1 downto 0),
      txsyncout_out(1 downto 0) => txsyncout_out(1 downto 0),
      txsysclksel_in(3 downto 0) => txsysclksel_in(3 downto 0),
      txusrclk2_in(1 downto 0) => txusrclk2_in(1 downto 0),
      txusrclk_in(1 downto 0) => txusrclk_in(1 downto 0)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity GthUltrascaleJesdCoregen is
  port (
    gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
    gtwiz_userdata_rx_out : out STD_LOGIC_VECTOR ( 63 downto 0 );
    gtrefclk00_in : in STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0lock_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    qpll0outrefclk_out : out STD_LOGIC_VECTOR ( 0 to 0 );
    gthrxn_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthrxp_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadeten_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    rxusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    tx8b10ben_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txctrl0_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl1_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
    txctrl2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    txpolarity_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    txusrclk2_in : in STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxn_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    gthtxp_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxbyterealign_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxcommadet_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxctrl0_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl1_out : out STD_LOGIC_VECTOR ( 31 downto 0 );
    rxctrl2_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxctrl3_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    rxoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txoutclk_out : out STD_LOGIC_VECTOR ( 1 downto 0 );
    txpmaresetdone_out : out STD_LOGIC_VECTOR ( 1 downto 0 )
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of GthUltrascaleJesdCoregen : entity is true;
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of GthUltrascaleJesdCoregen : entity is "GthUltrascaleJesdCoregen_gtwizard_top,Vivado 2014.4";
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of GthUltrascaleJesdCoregen : entity is "GthUltrascaleJesdCoregen,GthUltrascaleJesdCoregen_gtwizard_top,{}";
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of GthUltrascaleJesdCoregen : entity is "GthUltrascaleJesdCoregen,GthUltrascaleJesdCoregen_gtwizard_top,{x_ipProduct=Vivado 2014.4,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gtwizard_ultrascale,x_ipVersion=1.4,x_ipCoreRevision=1,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_CHANNEL_ENABLE=000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000,C_COMMON_SCALING_FACTOR=1,C_CPLL_VCO_FREQUENCY=2578.125,C_FORCE_COMMONS=0,C_FREERUN_FREQUENCY=185,C_GT_TYPE=0,C_GT_REV=0,C_INCLUDE_CPLL_CAL=2,C_LOCATE_COMMON=0,C_LOCATE_RESET_CONTROLLER=0,C_LOCATE_USER_DATA_WIDTH_SIZING=0,C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER=0,C_LOCATE_RX_USER_CLOCKING=1,C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER=0,C_LOCATE_TX_USER_CLOCKING=1,C_RESET_CONTROLLER_INSTANCE_CTRL=0,C_RX_BUFFBYPASS_MODE=0,C_RX_BUFFER_BYPASS_INSTANCE_CTRL=0,C_RX_BUFFER_MODE=1,C_RX_CB_DISP=00000000,C_RX_CB_K=00000000,C_RX_CB_MAX_LEVEL=1,C_RX_CB_LEN_SEQ=1,C_RX_CB_NUM_SEQ=0,C_RX_CB_VAL=00000000000000000000000000000000000000000000000000000000000000000000000000000000,C_RX_CC_DISP=00000000,C_RX_CC_ENABLE=0,C_RX_CC_K=00000000,C_RX_CC_LEN_SEQ=1,C_RX_CC_NUM_SEQ=0,C_RX_CC_PERIODICITY=5000,C_RX_CC_VAL=00000000000000000000000000000000000000000000000000000000000000000000000000000000,C_RX_COMMA_M_ENABLE=1,C_RX_COMMA_M_VAL=1010000011,C_RX_COMMA_P_ENABLE=1,C_RX_COMMA_P_VAL=0101111100,C_RX_DATA_DECODING=1,C_RX_ENABLE=1,C_RX_INT_DATA_WIDTH=40,C_RX_LINE_RATE=7.4,C_RX_MASTER_CHANNEL_IDX=18,C_RX_OUTCLK_BUFG_GT_DIV=1,C_RX_OUTCLK_FREQUENCY=185.0000000,C_RX_OUTCLK_SOURCE=1,C_RX_PLL_TYPE=0,C_RX_RECCLK_OUTPUT=0x000000000000000000000000000000000000000000000000,C_RX_REFCLK_FREQUENCY=370,C_RX_SLIDE_MODE=0,C_RX_USER_CLOCKING_CONTENTS=0,C_RX_USER_CLOCKING_INSTANCE_CTRL=0,C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK=1,C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2=1,C_RX_USER_CLOCKING_SOURCE=0,C_RX_USER_DATA_WIDTH=32,C_RX_USRCLK_FREQUENCY=185.0000000,C_RX_USRCLK2_FREQUENCY=185.0000000,C_SECONDARY_QPLL_ENABLE=0,C_SECONDARY_QPLL_REFCLK_FREQUENCY=257.8125,C_TOTAL_NUM_CHANNELS=2,C_TOTAL_NUM_COMMONS=1,C_TOTAL_NUM_COMMONS_EXAMPLE=0,C_TXPROGDIV_FREQ_ENABLE=0,C_TXPROGDIV_FREQ_SOURCE=0,C_TXPROGDIV_FREQ_VAL=185,C_TX_BUFFBYPASS_MODE=0,C_TX_BUFFER_BYPASS_INSTANCE_CTRL=0,C_TX_BUFFER_MODE=1,C_TX_DATA_ENCODING=1,C_TX_ENABLE=1,C_TX_INT_DATA_WIDTH=40,C_TX_LINE_RATE=7.4,C_TX_MASTER_CHANNEL_IDX=18,C_TX_OUTCLK_BUFG_GT_DIV=1,C_TX_OUTCLK_FREQUENCY=185.0000000,C_TX_OUTCLK_SOURCE=1,C_TX_PLL_TYPE=0,C_TX_REFCLK_FREQUENCY=370,C_TX_USER_CLOCKING_CONTENTS=0,C_TX_USER_CLOCKING_INSTANCE_CTRL=0,C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK=1,C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2=1,C_TX_USER_CLOCKING_SOURCE=0,C_TX_USER_DATA_WIDTH=32,C_TX_USRCLK_FREQUENCY=185.0000000,C_TX_USRCLK2_FREQUENCY=185.0000000}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of GthUltrascaleJesdCoregen : entity is "yes";
end GthUltrascaleJesdCoregen;

architecture STRUCTURE of GthUltrascaleJesdCoregen is
  signal NLW_inst_bufgtce_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_bufgtcemask_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_bufgtdiv_out_UNCONNECTED : STD_LOGIC_VECTOR ( 17 downto 0 );
  signal NLW_inst_bufgtreset_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_bufgtrstmask_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_cpllfbclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_cplllock_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_cpllrefclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_dmonitorout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 33 downto 0 );
  signal NLW_inst_drpdo_common_out_UNCONNECTED : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal NLW_inst_drpdo_out_UNCONNECTED : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal NLW_inst_drprdy_common_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_drprdy_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_eyescandataerror_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_gtpowergood_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_gtrefclkmonitor_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_gtwiz_buffbypass_rx_done_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_buffbypass_rx_error_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_buffbypass_tx_done_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_buffbypass_tx_error_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_reset_qpll0reset_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_reset_qpll1reset_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_rx_active_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_rx_srcclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_rx_usrclk2_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_rx_usrclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_tx_active_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_tx_srcclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_tx_usrclk2_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtwiz_userclk_tx_usrclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtytxn_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_gtytxp_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_pcierategen3_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcierateidle_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcierateqpllpd_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_pcierateqpllreset_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_pciesynctxsyncdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcieusergen3rdy_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcieuserphystatusrst_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcieuserratestart_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pcsrsvdout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 23 downto 0 );
  signal NLW_inst_phystatus_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_pinrsrvdas_out_UNCONNECTED : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal NLW_inst_pmarsvdout0_out_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal NLW_inst_pmarsvdout1_out_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal NLW_inst_qpll0fbclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll0refclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll1fbclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll1lock_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll1outclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll1outrefclk_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qpll1refclklost_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_qplldmonitor0_out_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal NLW_inst_qplldmonitor1_out_UNCONNECTED : STD_LOGIC_VECTOR ( 7 downto 0 );
  signal NLW_inst_refclkoutmonitor0_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_refclkoutmonitor1_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_resetexception_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxbufstatus_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_rxcdrlock_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxcdrphdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxchanbondseq_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxchanisaligned_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxchanrealign_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxchbondo_out_UNCONNECTED : STD_LOGIC_VECTOR ( 9 downto 0 );
  signal NLW_inst_rxckcaldone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_rxclkcorcnt_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_rxcominitdet_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxcomsasdet_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxcomwakedet_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxdata_out_UNCONNECTED : STD_LOGIC_VECTOR ( 255 downto 0 );
  signal NLW_inst_rxdataextendrsvd_out_UNCONNECTED : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal NLW_inst_rxdatavalid_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_rxdlysresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxelecidle_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxheader_out_UNCONNECTED : STD_LOGIC_VECTOR ( 11 downto 0 );
  signal NLW_inst_rxheadervalid_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_rxmonitorout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 13 downto 0 );
  signal NLW_inst_rxosintdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxosintstarted_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxosintstrobedone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxosintstrobestarted_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxoutclkfabric_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxoutclkpcs_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxphaligndone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxphalignerr_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxprbserr_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxprbslocked_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxprgdivresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxqpisenn_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxqpisenp_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxratedone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxrecclk0_sel_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxrecclk1_sel_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxrecclkout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxsliderdy_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxslipdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxslipoutclkrdy_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxslippmardy_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxstartofseq_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_rxstatus_out_UNCONNECTED : STD_LOGIC_VECTOR ( 5 downto 0 );
  signal NLW_inst_rxsyncdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxsyncout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_rxvalid_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_sdm0finalout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_sdm0testdata_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_sdm1finalout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_sdm1testdata_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_txbufstatus_out_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_inst_txcomfinish_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txdccdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_inst_txdlysresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txoutclkfabric_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txoutclkpcs_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txphaligndone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txphinitdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txprgdivresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txqpisenn_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txqpisenp_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txratedone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txresetdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txsyncdone_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal NLW_inst_txsyncout_out_UNCONNECTED : STD_LOGIC_VECTOR ( 1 downto 0 );
  attribute C_CHANNEL_ENABLE : string;
  attribute C_CHANNEL_ENABLE of inst : label is "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000";
  attribute C_COMMON_SCALING_FACTOR : integer;
  attribute C_COMMON_SCALING_FACTOR of inst : label is 1;
  attribute C_CPLL_VCO_FREQUENCY : string;
  attribute C_CPLL_VCO_FREQUENCY of inst : label is "2578.125000";
  attribute C_FORCE_COMMONS : integer;
  attribute C_FORCE_COMMONS of inst : label is 0;
  attribute C_FREERUN_FREQUENCY : string;
  attribute C_FREERUN_FREQUENCY of inst : label is "185.000000";
  attribute C_GT_REV : integer;
  attribute C_GT_REV of inst : label is 0;
  attribute C_GT_TYPE : integer;
  attribute C_GT_TYPE of inst : label is 0;
  attribute C_INCLUDE_CPLL_CAL : integer;
  attribute C_INCLUDE_CPLL_CAL of inst : label is 2;
  attribute C_LOCATE_COMMON : integer;
  attribute C_LOCATE_COMMON of inst : label is 0;
  attribute C_LOCATE_RESET_CONTROLLER : integer;
  attribute C_LOCATE_RESET_CONTROLLER of inst : label is 0;
  attribute C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER : integer;
  attribute C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER of inst : label is 0;
  attribute C_LOCATE_RX_USER_CLOCKING : integer;
  attribute C_LOCATE_RX_USER_CLOCKING of inst : label is 1;
  attribute C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER : integer;
  attribute C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER of inst : label is 0;
  attribute C_LOCATE_TX_USER_CLOCKING : integer;
  attribute C_LOCATE_TX_USER_CLOCKING of inst : label is 1;
  attribute C_LOCATE_USER_DATA_WIDTH_SIZING : integer;
  attribute C_LOCATE_USER_DATA_WIDTH_SIZING of inst : label is 0;
  attribute C_RESET_CONTROLLER_INSTANCE_CTRL : integer;
  attribute C_RESET_CONTROLLER_INSTANCE_CTRL of inst : label is 0;
  attribute C_RX_BUFFBYPASS_MODE : integer;
  attribute C_RX_BUFFBYPASS_MODE of inst : label is 0;
  attribute C_RX_BUFFER_BYPASS_INSTANCE_CTRL : integer;
  attribute C_RX_BUFFER_BYPASS_INSTANCE_CTRL of inst : label is 0;
  attribute C_RX_BUFFER_MODE : integer;
  attribute C_RX_BUFFER_MODE of inst : label is 1;
  attribute C_RX_CB_DISP : string;
  attribute C_RX_CB_DISP of inst : label is "8'b00000000";
  attribute C_RX_CB_K : string;
  attribute C_RX_CB_K of inst : label is "8'b00000000";
  attribute C_RX_CB_LEN_SEQ : integer;
  attribute C_RX_CB_LEN_SEQ of inst : label is 1;
  attribute C_RX_CB_MAX_LEVEL : integer;
  attribute C_RX_CB_MAX_LEVEL of inst : label is 1;
  attribute C_RX_CB_NUM_SEQ : integer;
  attribute C_RX_CB_NUM_SEQ of inst : label is 0;
  attribute C_RX_CB_VAL : string;
  attribute C_RX_CB_VAL of inst : label is "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_CC_DISP : string;
  attribute C_RX_CC_DISP of inst : label is "8'b00000000";
  attribute C_RX_CC_ENABLE : integer;
  attribute C_RX_CC_ENABLE of inst : label is 0;
  attribute C_RX_CC_K : string;
  attribute C_RX_CC_K of inst : label is "8'b00000000";
  attribute C_RX_CC_LEN_SEQ : integer;
  attribute C_RX_CC_LEN_SEQ of inst : label is 1;
  attribute C_RX_CC_NUM_SEQ : integer;
  attribute C_RX_CC_NUM_SEQ of inst : label is 0;
  attribute C_RX_CC_PERIODICITY : integer;
  attribute C_RX_CC_PERIODICITY of inst : label is 5000;
  attribute C_RX_CC_VAL : string;
  attribute C_RX_CC_VAL of inst : label is "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_COMMA_M_ENABLE : integer;
  attribute C_RX_COMMA_M_ENABLE of inst : label is 1;
  attribute C_RX_COMMA_M_VAL : string;
  attribute C_RX_COMMA_M_VAL of inst : label is "10'b1010000011";
  attribute C_RX_COMMA_P_ENABLE : integer;
  attribute C_RX_COMMA_P_ENABLE of inst : label is 1;
  attribute C_RX_COMMA_P_VAL : string;
  attribute C_RX_COMMA_P_VAL of inst : label is "10'b0101111100";
  attribute C_RX_DATA_DECODING : integer;
  attribute C_RX_DATA_DECODING of inst : label is 1;
  attribute C_RX_ENABLE : integer;
  attribute C_RX_ENABLE of inst : label is 1;
  attribute C_RX_INT_DATA_WIDTH : integer;
  attribute C_RX_INT_DATA_WIDTH of inst : label is 40;
  attribute C_RX_LINE_RATE : string;
  attribute C_RX_LINE_RATE of inst : label is "7.400000";
  attribute C_RX_MASTER_CHANNEL_IDX : integer;
  attribute C_RX_MASTER_CHANNEL_IDX of inst : label is 18;
  attribute C_RX_OUTCLK_BUFG_GT_DIV : integer;
  attribute C_RX_OUTCLK_BUFG_GT_DIV of inst : label is 1;
  attribute C_RX_OUTCLK_FREQUENCY : string;
  attribute C_RX_OUTCLK_FREQUENCY of inst : label is "185.000000";
  attribute C_RX_OUTCLK_SOURCE : integer;
  attribute C_RX_OUTCLK_SOURCE of inst : label is 1;
  attribute C_RX_PLL_TYPE : integer;
  attribute C_RX_PLL_TYPE of inst : label is 0;
  attribute C_RX_RECCLK_OUTPUT : string;
  attribute C_RX_RECCLK_OUTPUT of inst : label is "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  attribute C_RX_REFCLK_FREQUENCY : string;
  attribute C_RX_REFCLK_FREQUENCY of inst : label is "370.000000";
  attribute C_RX_SLIDE_MODE : integer;
  attribute C_RX_SLIDE_MODE of inst : label is 0;
  attribute C_RX_USER_CLOCKING_CONTENTS : integer;
  attribute C_RX_USER_CLOCKING_CONTENTS of inst : label is 0;
  attribute C_RX_USER_CLOCKING_INSTANCE_CTRL : integer;
  attribute C_RX_USER_CLOCKING_INSTANCE_CTRL of inst : label is 0;
  attribute C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK : integer;
  attribute C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK of inst : label is 1;
  attribute C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 : integer;
  attribute C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 of inst : label is 1;
  attribute C_RX_USER_CLOCKING_SOURCE : integer;
  attribute C_RX_USER_CLOCKING_SOURCE of inst : label is 0;
  attribute C_RX_USER_DATA_WIDTH : integer;
  attribute C_RX_USER_DATA_WIDTH of inst : label is 32;
  attribute C_RX_USRCLK2_FREQUENCY : string;
  attribute C_RX_USRCLK2_FREQUENCY of inst : label is "185.000000";
  attribute C_RX_USRCLK_FREQUENCY : string;
  attribute C_RX_USRCLK_FREQUENCY of inst : label is "185.000000";
  attribute C_SECONDARY_QPLL_ENABLE : integer;
  attribute C_SECONDARY_QPLL_ENABLE of inst : label is 0;
  attribute C_SECONDARY_QPLL_REFCLK_FREQUENCY : string;
  attribute C_SECONDARY_QPLL_REFCLK_FREQUENCY of inst : label is "257.812500";
  attribute C_TOTAL_NUM_CHANNELS : integer;
  attribute C_TOTAL_NUM_CHANNELS of inst : label is 2;
  attribute C_TOTAL_NUM_COMMONS : integer;
  attribute C_TOTAL_NUM_COMMONS of inst : label is 1;
  attribute C_TOTAL_NUM_COMMONS_EXAMPLE : integer;
  attribute C_TOTAL_NUM_COMMONS_EXAMPLE of inst : label is 0;
  attribute C_TXPROGDIV_FREQ_ENABLE : integer;
  attribute C_TXPROGDIV_FREQ_ENABLE of inst : label is 0;
  attribute C_TXPROGDIV_FREQ_SOURCE : integer;
  attribute C_TXPROGDIV_FREQ_SOURCE of inst : label is 0;
  attribute C_TXPROGDIV_FREQ_VAL : string;
  attribute C_TXPROGDIV_FREQ_VAL of inst : label is "185.000000";
  attribute C_TX_BUFFBYPASS_MODE : integer;
  attribute C_TX_BUFFBYPASS_MODE of inst : label is 0;
  attribute C_TX_BUFFER_BYPASS_INSTANCE_CTRL : integer;
  attribute C_TX_BUFFER_BYPASS_INSTANCE_CTRL of inst : label is 0;
  attribute C_TX_BUFFER_MODE : integer;
  attribute C_TX_BUFFER_MODE of inst : label is 1;
  attribute C_TX_DATA_ENCODING : integer;
  attribute C_TX_DATA_ENCODING of inst : label is 1;
  attribute C_TX_ENABLE : integer;
  attribute C_TX_ENABLE of inst : label is 1;
  attribute C_TX_INT_DATA_WIDTH : integer;
  attribute C_TX_INT_DATA_WIDTH of inst : label is 40;
  attribute C_TX_LINE_RATE : string;
  attribute C_TX_LINE_RATE of inst : label is "7.400000";
  attribute C_TX_MASTER_CHANNEL_IDX : integer;
  attribute C_TX_MASTER_CHANNEL_IDX of inst : label is 18;
  attribute C_TX_OUTCLK_BUFG_GT_DIV : integer;
  attribute C_TX_OUTCLK_BUFG_GT_DIV of inst : label is 1;
  attribute C_TX_OUTCLK_FREQUENCY : string;
  attribute C_TX_OUTCLK_FREQUENCY of inst : label is "185.000000";
  attribute C_TX_OUTCLK_SOURCE : integer;
  attribute C_TX_OUTCLK_SOURCE of inst : label is 1;
  attribute C_TX_PLL_TYPE : integer;
  attribute C_TX_PLL_TYPE of inst : label is 0;
  attribute C_TX_REFCLK_FREQUENCY : string;
  attribute C_TX_REFCLK_FREQUENCY of inst : label is "370.000000";
  attribute C_TX_USER_CLOCKING_CONTENTS : integer;
  attribute C_TX_USER_CLOCKING_CONTENTS of inst : label is 0;
  attribute C_TX_USER_CLOCKING_INSTANCE_CTRL : integer;
  attribute C_TX_USER_CLOCKING_INSTANCE_CTRL of inst : label is 0;
  attribute C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK : integer;
  attribute C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK of inst : label is 1;
  attribute C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 : integer;
  attribute C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 of inst : label is 1;
  attribute C_TX_USER_CLOCKING_SOURCE : integer;
  attribute C_TX_USER_CLOCKING_SOURCE of inst : label is 0;
  attribute C_TX_USER_DATA_WIDTH : integer;
  attribute C_TX_USER_DATA_WIDTH of inst : label is 32;
  attribute C_TX_USRCLK2_FREQUENCY : string;
  attribute C_TX_USRCLK2_FREQUENCY of inst : label is "185.000000";
  attribute C_TX_USRCLK_FREQUENCY : string;
  attribute C_TX_USRCLK_FREQUENCY of inst : label is "185.000000";
begin
inst: entity work.GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top
    port map (
      bgbypassb_in(0) => '1',
      bgmonitorenb_in(0) => '1',
      bgpdb_in(0) => '1',
      bgrcalovrd_in(4) => '1',
      bgrcalovrd_in(3) => '1',
      bgrcalovrd_in(2) => '1',
      bgrcalovrd_in(1) => '1',
      bgrcalovrd_in(0) => '1',
      bgrcalovrdenb_in(0) => '1',
      bufgtce_out(5 downto 0) => NLW_inst_bufgtce_out_UNCONNECTED(5 downto 0),
      bufgtcemask_out(5 downto 0) => NLW_inst_bufgtcemask_out_UNCONNECTED(5 downto 0),
      bufgtdiv_out(17 downto 0) => NLW_inst_bufgtdiv_out_UNCONNECTED(17 downto 0),
      bufgtreset_out(5 downto 0) => NLW_inst_bufgtreset_out_UNCONNECTED(5 downto 0),
      bufgtrstmask_out(5 downto 0) => NLW_inst_bufgtrstmask_out_UNCONNECTED(5 downto 0),
      cdrstepdir_in(0) => '0',
      cdrstepsq_in(0) => '0',
      cdrstepsx_in(0) => '0',
      cfgreset_in(1) => '0',
      cfgreset_in(0) => '0',
      clkrsvd0_in(1) => '0',
      clkrsvd0_in(0) => '0',
      clkrsvd1_in(1) => '0',
      clkrsvd1_in(0) => '0',
      cpllfbclklost_out(1 downto 0) => NLW_inst_cpllfbclklost_out_UNCONNECTED(1 downto 0),
      cplllock_out(1 downto 0) => NLW_inst_cplllock_out_UNCONNECTED(1 downto 0),
      cplllockdetclk_in(1) => '0',
      cplllockdetclk_in(0) => '0',
      cplllocken_in(1) => '0',
      cplllocken_in(0) => '0',
      cpllpd_in(1) => '1',
      cpllpd_in(0) => '1',
      cpllrefclklost_out(1 downto 0) => NLW_inst_cpllrefclklost_out_UNCONNECTED(1 downto 0),
      cpllrefclksel_in(5) => '0',
      cpllrefclksel_in(4) => '0',
      cpllrefclksel_in(3) => '1',
      cpllrefclksel_in(2) => '0',
      cpllrefclksel_in(1) => '0',
      cpllrefclksel_in(0) => '1',
      cpllreset_in(1) => '1',
      cpllreset_in(0) => '1',
      dmonfiforeset_in(1) => '0',
      dmonfiforeset_in(0) => '0',
      dmonitorclk_in(1) => '0',
      dmonitorclk_in(0) => '0',
      dmonitorout_out(33 downto 0) => NLW_inst_dmonitorout_out_UNCONNECTED(33 downto 0),
      drpaddr_common_in(8) => '0',
      drpaddr_common_in(7) => '0',
      drpaddr_common_in(6) => '0',
      drpaddr_common_in(5) => '0',
      drpaddr_common_in(4) => '0',
      drpaddr_common_in(3) => '0',
      drpaddr_common_in(2) => '0',
      drpaddr_common_in(1) => '0',
      drpaddr_common_in(0) => '0',
      drpaddr_in(17) => '0',
      drpaddr_in(16) => '0',
      drpaddr_in(15) => '0',
      drpaddr_in(14) => '0',
      drpaddr_in(13) => '0',
      drpaddr_in(12) => '0',
      drpaddr_in(11) => '0',
      drpaddr_in(10) => '0',
      drpaddr_in(9) => '0',
      drpaddr_in(8) => '0',
      drpaddr_in(7) => '0',
      drpaddr_in(6) => '0',
      drpaddr_in(5) => '0',
      drpaddr_in(4) => '0',
      drpaddr_in(3) => '0',
      drpaddr_in(2) => '0',
      drpaddr_in(1) => '0',
      drpaddr_in(0) => '0',
      drpclk_common_in(0) => '0',
      drpclk_in(1) => '0',
      drpclk_in(0) => '0',
      drpdi_common_in(15) => '0',
      drpdi_common_in(14) => '0',
      drpdi_common_in(13) => '0',
      drpdi_common_in(12) => '0',
      drpdi_common_in(11) => '0',
      drpdi_common_in(10) => '0',
      drpdi_common_in(9) => '0',
      drpdi_common_in(8) => '0',
      drpdi_common_in(7) => '0',
      drpdi_common_in(6) => '0',
      drpdi_common_in(5) => '0',
      drpdi_common_in(4) => '0',
      drpdi_common_in(3) => '0',
      drpdi_common_in(2) => '0',
      drpdi_common_in(1) => '0',
      drpdi_common_in(0) => '0',
      drpdi_in(31) => '0',
      drpdi_in(30) => '0',
      drpdi_in(29) => '0',
      drpdi_in(28) => '0',
      drpdi_in(27) => '0',
      drpdi_in(26) => '0',
      drpdi_in(25) => '0',
      drpdi_in(24) => '0',
      drpdi_in(23) => '0',
      drpdi_in(22) => '0',
      drpdi_in(21) => '0',
      drpdi_in(20) => '0',
      drpdi_in(19) => '0',
      drpdi_in(18) => '0',
      drpdi_in(17) => '0',
      drpdi_in(16) => '0',
      drpdi_in(15) => '0',
      drpdi_in(14) => '0',
      drpdi_in(13) => '0',
      drpdi_in(12) => '0',
      drpdi_in(11) => '0',
      drpdi_in(10) => '0',
      drpdi_in(9) => '0',
      drpdi_in(8) => '0',
      drpdi_in(7) => '0',
      drpdi_in(6) => '0',
      drpdi_in(5) => '0',
      drpdi_in(4) => '0',
      drpdi_in(3) => '0',
      drpdi_in(2) => '0',
      drpdi_in(1) => '0',
      drpdi_in(0) => '0',
      drpdo_common_out(15 downto 0) => NLW_inst_drpdo_common_out_UNCONNECTED(15 downto 0),
      drpdo_out(31 downto 0) => NLW_inst_drpdo_out_UNCONNECTED(31 downto 0),
      drpen_common_in(0) => '0',
      drpen_in(1) => '0',
      drpen_in(0) => '0',
      drprdy_common_out(0) => NLW_inst_drprdy_common_out_UNCONNECTED(0),
      drprdy_out(1 downto 0) => NLW_inst_drprdy_out_UNCONNECTED(1 downto 0),
      drpwe_common_in(0) => '0',
      drpwe_in(1) => '0',
      drpwe_in(0) => '0',
      elpcaldvorwren_in(0) => '0',
      elpcalpaorwren_in(0) => '0',
      evoddphicaldone_in(1) => '0',
      evoddphicaldone_in(0) => '0',
      evoddphicalstart_in(1) => '0',
      evoddphicalstart_in(0) => '0',
      evoddphidrden_in(1) => '0',
      evoddphidrden_in(0) => '0',
      evoddphidwren_in(1) => '0',
      evoddphidwren_in(0) => '0',
      evoddphixrden_in(1) => '0',
      evoddphixrden_in(0) => '0',
      evoddphixwren_in(1) => '0',
      evoddphixwren_in(0) => '0',
      eyescandataerror_out(1 downto 0) => NLW_inst_eyescandataerror_out_UNCONNECTED(1 downto 0),
      eyescanmode_in(1) => '0',
      eyescanmode_in(0) => '0',
      eyescanreset_in(1) => '0',
      eyescanreset_in(0) => '0',
      eyescantrigger_in(1) => '0',
      eyescantrigger_in(0) => '0',
      gtgrefclk0_in(0) => '0',
      gtgrefclk1_in(0) => '0',
      gtgrefclk_in(1) => '0',
      gtgrefclk_in(0) => '0',
      gthrxn_in(1 downto 0) => gthrxn_in(1 downto 0),
      gthrxp_in(1 downto 0) => gthrxp_in(1 downto 0),
      gthtxn_out(1 downto 0) => gthtxn_out(1 downto 0),
      gthtxp_out(1 downto 0) => gthtxp_out(1 downto 0),
      gtnorthrefclk00_in(0) => '0',
      gtnorthrefclk01_in(0) => '0',
      gtnorthrefclk0_in(1) => '0',
      gtnorthrefclk0_in(0) => '0',
      gtnorthrefclk10_in(0) => '0',
      gtnorthrefclk11_in(0) => '0',
      gtnorthrefclk1_in(1) => '0',
      gtnorthrefclk1_in(0) => '0',
      gtpowergood_out(1 downto 0) => NLW_inst_gtpowergood_out_UNCONNECTED(1 downto 0),
      gtrefclk00_in(0) => gtrefclk00_in(0),
      gtrefclk01_in(0) => '0',
      gtrefclk0_in(1) => '0',
      gtrefclk0_in(0) => '0',
      gtrefclk10_in(0) => '0',
      gtrefclk11_in(0) => '0',
      gtrefclk1_in(1) => '0',
      gtrefclk1_in(0) => '0',
      gtrefclkmonitor_out(1 downto 0) => NLW_inst_gtrefclkmonitor_out_UNCONNECTED(1 downto 0),
      gtresetsel_in(1) => '0',
      gtresetsel_in(0) => '0',
      gtrsvd_in(31) => '0',
      gtrsvd_in(30) => '0',
      gtrsvd_in(29) => '0',
      gtrsvd_in(28) => '0',
      gtrsvd_in(27) => '0',
      gtrsvd_in(26) => '0',
      gtrsvd_in(25) => '0',
      gtrsvd_in(24) => '0',
      gtrsvd_in(23) => '0',
      gtrsvd_in(22) => '0',
      gtrsvd_in(21) => '0',
      gtrsvd_in(20) => '0',
      gtrsvd_in(19) => '0',
      gtrsvd_in(18) => '0',
      gtrsvd_in(17) => '0',
      gtrsvd_in(16) => '0',
      gtrsvd_in(15) => '0',
      gtrsvd_in(14) => '0',
      gtrsvd_in(13) => '0',
      gtrsvd_in(12) => '0',
      gtrsvd_in(11) => '0',
      gtrsvd_in(10) => '0',
      gtrsvd_in(9) => '0',
      gtrsvd_in(8) => '0',
      gtrsvd_in(7) => '0',
      gtrsvd_in(6) => '0',
      gtrsvd_in(5) => '0',
      gtrsvd_in(4) => '0',
      gtrsvd_in(3) => '0',
      gtrsvd_in(2) => '0',
      gtrsvd_in(1) => '0',
      gtrsvd_in(0) => '0',
      gtrxreset_in(1) => '0',
      gtrxreset_in(0) => '0',
      gtsouthrefclk00_in(0) => '0',
      gtsouthrefclk01_in(0) => '0',
      gtsouthrefclk0_in(1) => '0',
      gtsouthrefclk0_in(0) => '0',
      gtsouthrefclk10_in(0) => '0',
      gtsouthrefclk11_in(0) => '0',
      gtsouthrefclk1_in(1) => '0',
      gtsouthrefclk1_in(0) => '0',
      gttxreset_in(1) => '0',
      gttxreset_in(0) => '0',
      gtwiz_buffbypass_rx_done_out(0) => NLW_inst_gtwiz_buffbypass_rx_done_out_UNCONNECTED(0),
      gtwiz_buffbypass_rx_error_out(0) => NLW_inst_gtwiz_buffbypass_rx_error_out_UNCONNECTED(0),
      gtwiz_buffbypass_rx_reset_in(0) => '0',
      gtwiz_buffbypass_rx_start_user_in(0) => '0',
      gtwiz_buffbypass_tx_done_out(0) => NLW_inst_gtwiz_buffbypass_tx_done_out_UNCONNECTED(0),
      gtwiz_buffbypass_tx_error_out(0) => NLW_inst_gtwiz_buffbypass_tx_error_out_UNCONNECTED(0),
      gtwiz_buffbypass_tx_reset_in(0) => '0',
      gtwiz_buffbypass_tx_start_user_in(0) => '0',
      gtwiz_gthe3_cpll_cal_bufg_ce_in(1) => '0',
      gtwiz_gthe3_cpll_cal_bufg_ce_in(0) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(35) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(34) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(33) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(32) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(31) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(30) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(29) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(28) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(27) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(26) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(25) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(24) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(23) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(22) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(21) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(20) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(19) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(18) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(17) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(16) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(15) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(14) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(13) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(12) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(11) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(10) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(9) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(8) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(7) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(6) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(5) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(4) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(3) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(2) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(1) => '0',
      gtwiz_gthe3_cpll_cal_cnt_tol_in(0) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(35) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(34) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(33) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(32) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(31) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(30) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(29) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(28) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(27) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(26) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(25) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(24) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(23) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(22) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(21) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(20) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(19) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(18) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(17) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(16) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(15) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(14) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(13) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(12) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(11) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(10) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(9) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(8) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(7) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(6) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(5) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(4) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(3) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(2) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(1) => '0',
      gtwiz_gthe3_cpll_cal_txoutclk_period_in(0) => '0',
      gtwiz_reset_all_in(0) => gtwiz_reset_all_in(0),
      gtwiz_reset_clk_freerun_in(0) => gtwiz_reset_clk_freerun_in(0),
      gtwiz_reset_qpll0lock_in(0) => '0',
      gtwiz_reset_qpll0reset_out(0) => NLW_inst_gtwiz_reset_qpll0reset_out_UNCONNECTED(0),
      gtwiz_reset_qpll1lock_in(0) => '0',
      gtwiz_reset_qpll1reset_out(0) => NLW_inst_gtwiz_reset_qpll1reset_out_UNCONNECTED(0),
      gtwiz_reset_rx_cdr_stable_out(0) => gtwiz_reset_rx_cdr_stable_out(0),
      gtwiz_reset_rx_datapath_in(0) => gtwiz_reset_rx_datapath_in(0),
      gtwiz_reset_rx_done_in(0) => '0',
      gtwiz_reset_rx_done_out(0) => gtwiz_reset_rx_done_out(0),
      gtwiz_reset_rx_pll_and_datapath_in(0) => gtwiz_reset_rx_pll_and_datapath_in(0),
      gtwiz_reset_tx_datapath_in(0) => gtwiz_reset_tx_datapath_in(0),
      gtwiz_reset_tx_done_in(0) => '0',
      gtwiz_reset_tx_done_out(0) => gtwiz_reset_tx_done_out(0),
      gtwiz_reset_tx_pll_and_datapath_in(0) => gtwiz_reset_tx_pll_and_datapath_in(0),
      gtwiz_userclk_rx_active_in(0) => gtwiz_userclk_rx_active_in(0),
      gtwiz_userclk_rx_active_out(0) => NLW_inst_gtwiz_userclk_rx_active_out_UNCONNECTED(0),
      gtwiz_userclk_rx_reset_in(0) => '0',
      gtwiz_userclk_rx_srcclk_out(0) => NLW_inst_gtwiz_userclk_rx_srcclk_out_UNCONNECTED(0),
      gtwiz_userclk_rx_usrclk2_out(0) => NLW_inst_gtwiz_userclk_rx_usrclk2_out_UNCONNECTED(0),
      gtwiz_userclk_rx_usrclk_out(0) => NLW_inst_gtwiz_userclk_rx_usrclk_out_UNCONNECTED(0),
      gtwiz_userclk_tx_active_in(0) => gtwiz_userclk_tx_active_in(0),
      gtwiz_userclk_tx_active_out(0) => NLW_inst_gtwiz_userclk_tx_active_out_UNCONNECTED(0),
      gtwiz_userclk_tx_reset_in(0) => '0',
      gtwiz_userclk_tx_srcclk_out(0) => NLW_inst_gtwiz_userclk_tx_srcclk_out_UNCONNECTED(0),
      gtwiz_userclk_tx_usrclk2_out(0) => NLW_inst_gtwiz_userclk_tx_usrclk2_out_UNCONNECTED(0),
      gtwiz_userclk_tx_usrclk_out(0) => NLW_inst_gtwiz_userclk_tx_usrclk_out_UNCONNECTED(0),
      gtwiz_userdata_rx_out(63 downto 0) => gtwiz_userdata_rx_out(63 downto 0),
      gtwiz_userdata_tx_in(63 downto 0) => gtwiz_userdata_tx_in(63 downto 0),
      gtyrxn_in(0) => '0',
      gtyrxp_in(0) => '0',
      gtytxn_out(0) => NLW_inst_gtytxn_out_UNCONNECTED(0),
      gtytxp_out(0) => NLW_inst_gtytxp_out_UNCONNECTED(0),
      loopback_in(5) => '0',
      loopback_in(4) => '0',
      loopback_in(3) => '0',
      loopback_in(2) => '0',
      loopback_in(1) => '0',
      loopback_in(0) => '0',
      looprsvd_in(0) => '0',
      lpbkrxtxseren_in(1) => '0',
      lpbkrxtxseren_in(0) => '0',
      lpbktxrxseren_in(1) => '0',
      lpbktxrxseren_in(0) => '0',
      pcieeqrxeqadaptdone_in(1) => '0',
      pcieeqrxeqadaptdone_in(0) => '0',
      pcierategen3_out(1 downto 0) => NLW_inst_pcierategen3_out_UNCONNECTED(1 downto 0),
      pcierateidle_out(1 downto 0) => NLW_inst_pcierateidle_out_UNCONNECTED(1 downto 0),
      pcierateqpllpd_out(3 downto 0) => NLW_inst_pcierateqpllpd_out_UNCONNECTED(3 downto 0),
      pcierateqpllreset_out(3 downto 0) => NLW_inst_pcierateqpllreset_out_UNCONNECTED(3 downto 0),
      pcierstidle_in(1) => '0',
      pcierstidle_in(0) => '0',
      pciersttxsyncstart_in(1) => '0',
      pciersttxsyncstart_in(0) => '0',
      pciesynctxsyncdone_out(1 downto 0) => NLW_inst_pciesynctxsyncdone_out_UNCONNECTED(1 downto 0),
      pcieusergen3rdy_out(1 downto 0) => NLW_inst_pcieusergen3rdy_out_UNCONNECTED(1 downto 0),
      pcieuserphystatusrst_out(1 downto 0) => NLW_inst_pcieuserphystatusrst_out_UNCONNECTED(1 downto 0),
      pcieuserratedone_in(1) => '0',
      pcieuserratedone_in(0) => '0',
      pcieuserratestart_out(1 downto 0) => NLW_inst_pcieuserratestart_out_UNCONNECTED(1 downto 0),
      pcsrsvdin2_in(9) => '0',
      pcsrsvdin2_in(8) => '0',
      pcsrsvdin2_in(7) => '0',
      pcsrsvdin2_in(6) => '0',
      pcsrsvdin2_in(5) => '0',
      pcsrsvdin2_in(4) => '0',
      pcsrsvdin2_in(3) => '0',
      pcsrsvdin2_in(2) => '0',
      pcsrsvdin2_in(1) => '0',
      pcsrsvdin2_in(0) => '0',
      pcsrsvdin_in(31) => '0',
      pcsrsvdin_in(30) => '0',
      pcsrsvdin_in(29) => '0',
      pcsrsvdin_in(28) => '0',
      pcsrsvdin_in(27) => '0',
      pcsrsvdin_in(26) => '0',
      pcsrsvdin_in(25) => '0',
      pcsrsvdin_in(24) => '0',
      pcsrsvdin_in(23) => '0',
      pcsrsvdin_in(22) => '0',
      pcsrsvdin_in(21) => '0',
      pcsrsvdin_in(20) => '0',
      pcsrsvdin_in(19) => '0',
      pcsrsvdin_in(18) => '0',
      pcsrsvdin_in(17) => '0',
      pcsrsvdin_in(16) => '0',
      pcsrsvdin_in(15) => '0',
      pcsrsvdin_in(14) => '0',
      pcsrsvdin_in(13) => '0',
      pcsrsvdin_in(12) => '0',
      pcsrsvdin_in(11) => '0',
      pcsrsvdin_in(10) => '0',
      pcsrsvdin_in(9) => '0',
      pcsrsvdin_in(8) => '0',
      pcsrsvdin_in(7) => '0',
      pcsrsvdin_in(6) => '0',
      pcsrsvdin_in(5) => '0',
      pcsrsvdin_in(4) => '0',
      pcsrsvdin_in(3) => '0',
      pcsrsvdin_in(2) => '0',
      pcsrsvdin_in(1) => '0',
      pcsrsvdin_in(0) => '0',
      pcsrsvdout_out(23 downto 0) => NLW_inst_pcsrsvdout_out_UNCONNECTED(23 downto 0),
      phystatus_out(1 downto 0) => NLW_inst_phystatus_out_UNCONNECTED(1 downto 0),
      pinrsrvdas_out(15 downto 0) => NLW_inst_pinrsrvdas_out_UNCONNECTED(15 downto 0),
      pmarsvd0_in(7) => '0',
      pmarsvd0_in(6) => '0',
      pmarsvd0_in(5) => '0',
      pmarsvd0_in(4) => '0',
      pmarsvd0_in(3) => '0',
      pmarsvd0_in(2) => '0',
      pmarsvd0_in(1) => '0',
      pmarsvd0_in(0) => '0',
      pmarsvd1_in(7) => '0',
      pmarsvd1_in(6) => '0',
      pmarsvd1_in(5) => '0',
      pmarsvd1_in(4) => '0',
      pmarsvd1_in(3) => '0',
      pmarsvd1_in(2) => '0',
      pmarsvd1_in(1) => '0',
      pmarsvd1_in(0) => '0',
      pmarsvdin_in(9) => '0',
      pmarsvdin_in(8) => '0',
      pmarsvdin_in(7) => '0',
      pmarsvdin_in(6) => '0',
      pmarsvdin_in(5) => '0',
      pmarsvdin_in(4) => '0',
      pmarsvdin_in(3) => '0',
      pmarsvdin_in(2) => '0',
      pmarsvdin_in(1) => '0',
      pmarsvdin_in(0) => '0',
      pmarsvdout0_out(7 downto 0) => NLW_inst_pmarsvdout0_out_UNCONNECTED(7 downto 0),
      pmarsvdout1_out(7 downto 0) => NLW_inst_pmarsvdout1_out_UNCONNECTED(7 downto 0),
      qpll0clk_in(1) => '0',
      qpll0clk_in(0) => '0',
      qpll0clkrsvd0_in(0) => '0',
      qpll0clkrsvd1_in(0) => '0',
      qpll0fbclklost_out(0) => NLW_inst_qpll0fbclklost_out_UNCONNECTED(0),
      qpll0lock_out(0) => qpll0lock_out(0),
      qpll0lockdetclk_in(0) => '0',
      qpll0locken_in(0) => '1',
      qpll0outclk_out(0) => qpll0outclk_out(0),
      qpll0outrefclk_out(0) => qpll0outrefclk_out(0),
      qpll0pd_in(0) => '0',
      qpll0refclk_in(1) => '0',
      qpll0refclk_in(0) => '0',
      qpll0refclklost_out(0) => NLW_inst_qpll0refclklost_out_UNCONNECTED(0),
      qpll0refclksel_in(2) => '0',
      qpll0refclksel_in(1) => '0',
      qpll0refclksel_in(0) => '1',
      qpll0reset_in(0) => '0',
      qpll1clk_in(1) => '0',
      qpll1clk_in(0) => '0',
      qpll1clkrsvd0_in(0) => '0',
      qpll1clkrsvd1_in(0) => '0',
      qpll1fbclklost_out(0) => NLW_inst_qpll1fbclklost_out_UNCONNECTED(0),
      qpll1lock_out(0) => NLW_inst_qpll1lock_out_UNCONNECTED(0),
      qpll1lockdetclk_in(0) => '0',
      qpll1locken_in(0) => '0',
      qpll1outclk_out(0) => NLW_inst_qpll1outclk_out_UNCONNECTED(0),
      qpll1outrefclk_out(0) => NLW_inst_qpll1outrefclk_out_UNCONNECTED(0),
      qpll1pd_in(0) => '1',
      qpll1refclk_in(1) => '0',
      qpll1refclk_in(0) => '0',
      qpll1refclklost_out(0) => NLW_inst_qpll1refclklost_out_UNCONNECTED(0),
      qpll1refclksel_in(2) => '0',
      qpll1refclksel_in(1) => '0',
      qpll1refclksel_in(0) => '1',
      qpll1reset_in(0) => '1',
      qplldmonitor0_out(7 downto 0) => NLW_inst_qplldmonitor0_out_UNCONNECTED(7 downto 0),
      qplldmonitor1_out(7 downto 0) => NLW_inst_qplldmonitor1_out_UNCONNECTED(7 downto 0),
      qpllrsvd1_in(7) => '0',
      qpllrsvd1_in(6) => '0',
      qpllrsvd1_in(5) => '0',
      qpllrsvd1_in(4) => '0',
      qpllrsvd1_in(3) => '0',
      qpllrsvd1_in(2) => '0',
      qpllrsvd1_in(1) => '0',
      qpllrsvd1_in(0) => '0',
      qpllrsvd2_in(4) => '0',
      qpllrsvd2_in(3) => '0',
      qpllrsvd2_in(2) => '0',
      qpllrsvd2_in(1) => '0',
      qpllrsvd2_in(0) => '0',
      qpllrsvd3_in(4) => '0',
      qpllrsvd3_in(3) => '0',
      qpllrsvd3_in(2) => '0',
      qpllrsvd3_in(1) => '0',
      qpllrsvd3_in(0) => '0',
      qpllrsvd4_in(7) => '0',
      qpllrsvd4_in(6) => '0',
      qpllrsvd4_in(5) => '0',
      qpllrsvd4_in(4) => '0',
      qpllrsvd4_in(3) => '0',
      qpllrsvd4_in(2) => '0',
      qpllrsvd4_in(1) => '0',
      qpllrsvd4_in(0) => '0',
      rcalenb_in(0) => '1',
      refclkoutmonitor0_out(0) => NLW_inst_refclkoutmonitor0_out_UNCONNECTED(0),
      refclkoutmonitor1_out(0) => NLW_inst_refclkoutmonitor1_out_UNCONNECTED(0),
      resetexception_out(1 downto 0) => NLW_inst_resetexception_out_UNCONNECTED(1 downto 0),
      resetovrd_in(1) => '0',
      resetovrd_in(0) => '0',
      rstclkentx_in(1) => '0',
      rstclkentx_in(0) => '0',
      rx8b10ben_in(1 downto 0) => rx8b10ben_in(1 downto 0),
      rxbufreset_in(1) => '0',
      rxbufreset_in(0) => '0',
      rxbufstatus_out(5 downto 0) => NLW_inst_rxbufstatus_out_UNCONNECTED(5 downto 0),
      rxbyteisaligned_out(1 downto 0) => rxbyteisaligned_out(1 downto 0),
      rxbyterealign_out(1 downto 0) => rxbyterealign_out(1 downto 0),
      rxcdrfreqreset_in(1) => '0',
      rxcdrfreqreset_in(0) => '0',
      rxcdrhold_in(1) => '0',
      rxcdrhold_in(0) => '0',
      rxcdrlock_out(1 downto 0) => NLW_inst_rxcdrlock_out_UNCONNECTED(1 downto 0),
      rxcdrovrden_in(1) => '0',
      rxcdrovrden_in(0) => '0',
      rxcdrphdone_out(1 downto 0) => NLW_inst_rxcdrphdone_out_UNCONNECTED(1 downto 0),
      rxcdrreset_in(1) => '0',
      rxcdrreset_in(0) => '0',
      rxcdrresetrsv_in(1) => '0',
      rxcdrresetrsv_in(0) => '0',
      rxchanbondseq_out(1 downto 0) => NLW_inst_rxchanbondseq_out_UNCONNECTED(1 downto 0),
      rxchanisaligned_out(1 downto 0) => NLW_inst_rxchanisaligned_out_UNCONNECTED(1 downto 0),
      rxchanrealign_out(1 downto 0) => NLW_inst_rxchanrealign_out_UNCONNECTED(1 downto 0),
      rxchbonden_in(1) => '0',
      rxchbonden_in(0) => '0',
      rxchbondi_in(9) => '0',
      rxchbondi_in(8) => '0',
      rxchbondi_in(7) => '0',
      rxchbondi_in(6) => '0',
      rxchbondi_in(5) => '0',
      rxchbondi_in(4) => '0',
      rxchbondi_in(3) => '0',
      rxchbondi_in(2) => '0',
      rxchbondi_in(1) => '0',
      rxchbondi_in(0) => '0',
      rxchbondlevel_in(5) => '0',
      rxchbondlevel_in(4) => '0',
      rxchbondlevel_in(3) => '0',
      rxchbondlevel_in(2) => '0',
      rxchbondlevel_in(1) => '0',
      rxchbondlevel_in(0) => '0',
      rxchbondmaster_in(1) => '0',
      rxchbondmaster_in(0) => '0',
      rxchbondo_out(9 downto 0) => NLW_inst_rxchbondo_out_UNCONNECTED(9 downto 0),
      rxchbondslave_in(1) => '0',
      rxchbondslave_in(0) => '0',
      rxckcaldone_out(0) => NLW_inst_rxckcaldone_out_UNCONNECTED(0),
      rxckcalreset_in(0) => '0',
      rxclkcorcnt_out(3 downto 0) => NLW_inst_rxclkcorcnt_out_UNCONNECTED(3 downto 0),
      rxcominitdet_out(1 downto 0) => NLW_inst_rxcominitdet_out_UNCONNECTED(1 downto 0),
      rxcommadet_out(1 downto 0) => rxcommadet_out(1 downto 0),
      rxcommadeten_in(1 downto 0) => rxcommadeten_in(1 downto 0),
      rxcomsasdet_out(1 downto 0) => NLW_inst_rxcomsasdet_out_UNCONNECTED(1 downto 0),
      rxcomwakedet_out(1 downto 0) => NLW_inst_rxcomwakedet_out_UNCONNECTED(1 downto 0),
      rxctrl0_out(31 downto 0) => rxctrl0_out(31 downto 0),
      rxctrl1_out(31 downto 0) => rxctrl1_out(31 downto 0),
      rxctrl2_out(15 downto 0) => rxctrl2_out(15 downto 0),
      rxctrl3_out(15 downto 0) => rxctrl3_out(15 downto 0),
      rxdata_out(255 downto 0) => NLW_inst_rxdata_out_UNCONNECTED(255 downto 0),
      rxdataextendrsvd_out(15 downto 0) => NLW_inst_rxdataextendrsvd_out_UNCONNECTED(15 downto 0),
      rxdatavalid_out(3 downto 0) => NLW_inst_rxdatavalid_out_UNCONNECTED(3 downto 0),
      rxdccforcestart_in(0) => '0',
      rxdfeagcctrl_in(3) => '0',
      rxdfeagcctrl_in(2) => '1',
      rxdfeagcctrl_in(1) => '0',
      rxdfeagcctrl_in(0) => '1',
      rxdfeagchold_in(1) => '0',
      rxdfeagchold_in(0) => '0',
      rxdfeagcovrden_in(1) => '0',
      rxdfeagcovrden_in(0) => '0',
      rxdfelfhold_in(1) => '0',
      rxdfelfhold_in(0) => '0',
      rxdfelfovrden_in(1) => '0',
      rxdfelfovrden_in(0) => '0',
      rxdfelpmreset_in(1) => '0',
      rxdfelpmreset_in(0) => '0',
      rxdfetap10hold_in(1) => '0',
      rxdfetap10hold_in(0) => '0',
      rxdfetap10ovrden_in(1) => '0',
      rxdfetap10ovrden_in(0) => '0',
      rxdfetap11hold_in(1) => '0',
      rxdfetap11hold_in(0) => '0',
      rxdfetap11ovrden_in(1) => '0',
      rxdfetap11ovrden_in(0) => '0',
      rxdfetap12hold_in(1) => '0',
      rxdfetap12hold_in(0) => '0',
      rxdfetap12ovrden_in(1) => '0',
      rxdfetap12ovrden_in(0) => '0',
      rxdfetap13hold_in(1) => '0',
      rxdfetap13hold_in(0) => '0',
      rxdfetap13ovrden_in(1) => '0',
      rxdfetap13ovrden_in(0) => '0',
      rxdfetap14hold_in(1) => '0',
      rxdfetap14hold_in(0) => '0',
      rxdfetap14ovrden_in(1) => '0',
      rxdfetap14ovrden_in(0) => '0',
      rxdfetap15hold_in(1) => '0',
      rxdfetap15hold_in(0) => '0',
      rxdfetap15ovrden_in(1) => '0',
      rxdfetap15ovrden_in(0) => '0',
      rxdfetap2hold_in(1) => '0',
      rxdfetap2hold_in(0) => '0',
      rxdfetap2ovrden_in(1) => '0',
      rxdfetap2ovrden_in(0) => '0',
      rxdfetap3hold_in(1) => '0',
      rxdfetap3hold_in(0) => '0',
      rxdfetap3ovrden_in(1) => '0',
      rxdfetap3ovrden_in(0) => '0',
      rxdfetap4hold_in(1) => '0',
      rxdfetap4hold_in(0) => '0',
      rxdfetap4ovrden_in(1) => '0',
      rxdfetap4ovrden_in(0) => '0',
      rxdfetap5hold_in(1) => '0',
      rxdfetap5hold_in(0) => '0',
      rxdfetap5ovrden_in(1) => '0',
      rxdfetap5ovrden_in(0) => '0',
      rxdfetap6hold_in(1) => '0',
      rxdfetap6hold_in(0) => '0',
      rxdfetap6ovrden_in(1) => '0',
      rxdfetap6ovrden_in(0) => '0',
      rxdfetap7hold_in(1) => '0',
      rxdfetap7hold_in(0) => '0',
      rxdfetap7ovrden_in(1) => '0',
      rxdfetap7ovrden_in(0) => '0',
      rxdfetap8hold_in(1) => '0',
      rxdfetap8hold_in(0) => '0',
      rxdfetap8ovrden_in(1) => '0',
      rxdfetap8ovrden_in(0) => '0',
      rxdfetap9hold_in(1) => '0',
      rxdfetap9hold_in(0) => '0',
      rxdfetap9ovrden_in(1) => '0',
      rxdfetap9ovrden_in(0) => '0',
      rxdfeuthold_in(1) => '0',
      rxdfeuthold_in(0) => '0',
      rxdfeutovrden_in(1) => '0',
      rxdfeutovrden_in(0) => '0',
      rxdfevphold_in(1) => '0',
      rxdfevphold_in(0) => '0',
      rxdfevpovrden_in(1) => '0',
      rxdfevpovrden_in(0) => '0',
      rxdfevsen_in(1) => '0',
      rxdfevsen_in(0) => '0',
      rxdfexyden_in(1) => '1',
      rxdfexyden_in(0) => '1',
      rxdlybypass_in(1) => '1',
      rxdlybypass_in(0) => '1',
      rxdlyen_in(1) => '0',
      rxdlyen_in(0) => '0',
      rxdlyovrden_in(1) => '0',
      rxdlyovrden_in(0) => '0',
      rxdlysreset_in(1) => '0',
      rxdlysreset_in(0) => '0',
      rxdlysresetdone_out(1 downto 0) => NLW_inst_rxdlysresetdone_out_UNCONNECTED(1 downto 0),
      rxelecidle_out(1 downto 0) => NLW_inst_rxelecidle_out_UNCONNECTED(1 downto 0),
      rxelecidlemode_in(3) => '1',
      rxelecidlemode_in(2) => '1',
      rxelecidlemode_in(1) => '1',
      rxelecidlemode_in(0) => '1',
      rxgearboxslip_in(1) => '0',
      rxgearboxslip_in(0) => '0',
      rxheader_out(11 downto 0) => NLW_inst_rxheader_out_UNCONNECTED(11 downto 0),
      rxheadervalid_out(3 downto 0) => NLW_inst_rxheadervalid_out_UNCONNECTED(3 downto 0),
      rxlatclk_in(1) => '0',
      rxlatclk_in(0) => '0',
      rxlpmen_in(1) => '0',
      rxlpmen_in(0) => '0',
      rxlpmgchold_in(1) => '0',
      rxlpmgchold_in(0) => '0',
      rxlpmgcovrden_in(1) => '0',
      rxlpmgcovrden_in(0) => '0',
      rxlpmhfhold_in(1) => '0',
      rxlpmhfhold_in(0) => '0',
      rxlpmhfovrden_in(1) => '0',
      rxlpmhfovrden_in(0) => '0',
      rxlpmlfhold_in(1) => '0',
      rxlpmlfhold_in(0) => '0',
      rxlpmlfklovrden_in(1) => '0',
      rxlpmlfklovrden_in(0) => '0',
      rxlpmoshold_in(1) => '0',
      rxlpmoshold_in(0) => '0',
      rxlpmosovrden_in(1) => '0',
      rxlpmosovrden_in(0) => '0',
      rxmcommaalignen_in(1 downto 0) => rxmcommaalignen_in(1 downto 0),
      rxmonitorout_out(13 downto 0) => NLW_inst_rxmonitorout_out_UNCONNECTED(13 downto 0),
      rxmonitorsel_in(3) => '0',
      rxmonitorsel_in(2) => '0',
      rxmonitorsel_in(1) => '0',
      rxmonitorsel_in(0) => '0',
      rxoobreset_in(1) => '0',
      rxoobreset_in(0) => '0',
      rxoscalreset_in(1) => '0',
      rxoscalreset_in(0) => '0',
      rxoshold_in(1) => '0',
      rxoshold_in(0) => '0',
      rxosintcfg_in(7) => '1',
      rxosintcfg_in(6) => '1',
      rxosintcfg_in(5) => '0',
      rxosintcfg_in(4) => '1',
      rxosintcfg_in(3) => '1',
      rxosintcfg_in(2) => '1',
      rxosintcfg_in(1) => '0',
      rxosintcfg_in(0) => '1',
      rxosintdone_out(1 downto 0) => NLW_inst_rxosintdone_out_UNCONNECTED(1 downto 0),
      rxosinten_in(1) => '1',
      rxosinten_in(0) => '1',
      rxosinthold_in(1) => '0',
      rxosinthold_in(0) => '0',
      rxosintovrden_in(1) => '0',
      rxosintovrden_in(0) => '0',
      rxosintstarted_out(1 downto 0) => NLW_inst_rxosintstarted_out_UNCONNECTED(1 downto 0),
      rxosintstrobe_in(1) => '0',
      rxosintstrobe_in(0) => '0',
      rxosintstrobedone_out(1 downto 0) => NLW_inst_rxosintstrobedone_out_UNCONNECTED(1 downto 0),
      rxosintstrobestarted_out(1 downto 0) => NLW_inst_rxosintstrobestarted_out_UNCONNECTED(1 downto 0),
      rxosinttestovrden_in(1) => '0',
      rxosinttestovrden_in(0) => '0',
      rxosovrden_in(1) => '0',
      rxosovrden_in(0) => '0',
      rxoutclk_out(1 downto 0) => rxoutclk_out(1 downto 0),
      rxoutclkfabric_out(1 downto 0) => NLW_inst_rxoutclkfabric_out_UNCONNECTED(1 downto 0),
      rxoutclkpcs_out(1 downto 0) => NLW_inst_rxoutclkpcs_out_UNCONNECTED(1 downto 0),
      rxoutclksel_in(5) => '0',
      rxoutclksel_in(4) => '1',
      rxoutclksel_in(3) => '0',
      rxoutclksel_in(2) => '0',
      rxoutclksel_in(1) => '1',
      rxoutclksel_in(0) => '0',
      rxpcommaalignen_in(1 downto 0) => rxpcommaalignen_in(1 downto 0),
      rxpcsreset_in(1) => '0',
      rxpcsreset_in(0) => '0',
      rxpd_in(3) => '0',
      rxpd_in(2) => '0',
      rxpd_in(1) => '0',
      rxpd_in(0) => '0',
      rxphalign_in(1) => '0',
      rxphalign_in(0) => '0',
      rxphaligndone_out(1 downto 0) => NLW_inst_rxphaligndone_out_UNCONNECTED(1 downto 0),
      rxphalignen_in(1) => '0',
      rxphalignen_in(0) => '0',
      rxphalignerr_out(1 downto 0) => NLW_inst_rxphalignerr_out_UNCONNECTED(1 downto 0),
      rxphdlypd_in(1) => '1',
      rxphdlypd_in(0) => '1',
      rxphdlyreset_in(1) => '0',
      rxphdlyreset_in(0) => '0',
      rxphovrden_in(1) => '0',
      rxphovrden_in(0) => '0',
      rxpllclksel_in(3) => '1',
      rxpllclksel_in(2) => '1',
      rxpllclksel_in(1) => '1',
      rxpllclksel_in(0) => '1',
      rxpmareset_in(1) => '0',
      rxpmareset_in(0) => '0',
      rxpmaresetdone_out(1 downto 0) => rxpmaresetdone_out(1 downto 0),
      rxpolarity_in(1 downto 0) => rxpolarity_in(1 downto 0),
      rxprbscntreset_in(1) => '0',
      rxprbscntreset_in(0) => '0',
      rxprbserr_out(1 downto 0) => NLW_inst_rxprbserr_out_UNCONNECTED(1 downto 0),
      rxprbslocked_out(1 downto 0) => NLW_inst_rxprbslocked_out_UNCONNECTED(1 downto 0),
      rxprbssel_in(7) => '0',
      rxprbssel_in(6) => '0',
      rxprbssel_in(5) => '0',
      rxprbssel_in(4) => '0',
      rxprbssel_in(3) => '0',
      rxprbssel_in(2) => '0',
      rxprbssel_in(1) => '0',
      rxprbssel_in(0) => '0',
      rxprgdivresetdone_out(1 downto 0) => NLW_inst_rxprgdivresetdone_out_UNCONNECTED(1 downto 0),
      rxprogdivreset_in(1) => '0',
      rxprogdivreset_in(0) => '0',
      rxqpien_in(1) => '0',
      rxqpien_in(0) => '0',
      rxqpisenn_out(1 downto 0) => NLW_inst_rxqpisenn_out_UNCONNECTED(1 downto 0),
      rxqpisenp_out(1 downto 0) => NLW_inst_rxqpisenp_out_UNCONNECTED(1 downto 0),
      rxrate_in(5) => '0',
      rxrate_in(4) => '0',
      rxrate_in(3) => '0',
      rxrate_in(2) => '0',
      rxrate_in(1) => '0',
      rxrate_in(0) => '0',
      rxratedone_out(1 downto 0) => NLW_inst_rxratedone_out_UNCONNECTED(1 downto 0),
      rxratemode_in(1) => '0',
      rxratemode_in(0) => '0',
      rxrecclk0_sel_out(1 downto 0) => NLW_inst_rxrecclk0_sel_out_UNCONNECTED(1 downto 0),
      rxrecclk1_sel_out(1 downto 0) => NLW_inst_rxrecclk1_sel_out_UNCONNECTED(1 downto 0),
      rxrecclkout_out(1 downto 0) => NLW_inst_rxrecclkout_out_UNCONNECTED(1 downto 0),
      rxresetdone_out(1 downto 0) => NLW_inst_rxresetdone_out_UNCONNECTED(1 downto 0),
      rxslide_in(1) => '0',
      rxslide_in(0) => '0',
      rxsliderdy_out(1 downto 0) => NLW_inst_rxsliderdy_out_UNCONNECTED(1 downto 0),
      rxslipdone_out(1 downto 0) => NLW_inst_rxslipdone_out_UNCONNECTED(1 downto 0),
      rxslipoutclk_in(1) => '0',
      rxslipoutclk_in(0) => '0',
      rxslipoutclkrdy_out(1 downto 0) => NLW_inst_rxslipoutclkrdy_out_UNCONNECTED(1 downto 0),
      rxslippma_in(1) => '0',
      rxslippma_in(0) => '0',
      rxslippmardy_out(1 downto 0) => NLW_inst_rxslippmardy_out_UNCONNECTED(1 downto 0),
      rxstartofseq_out(3 downto 0) => NLW_inst_rxstartofseq_out_UNCONNECTED(3 downto 0),
      rxstatus_out(5 downto 0) => NLW_inst_rxstatus_out_UNCONNECTED(5 downto 0),
      rxsyncallin_in(1) => '0',
      rxsyncallin_in(0) => '0',
      rxsyncdone_out(1 downto 0) => NLW_inst_rxsyncdone_out_UNCONNECTED(1 downto 0),
      rxsyncin_in(1) => '0',
      rxsyncin_in(0) => '0',
      rxsyncmode_in(1) => '0',
      rxsyncmode_in(0) => '0',
      rxsyncout_out(1 downto 0) => NLW_inst_rxsyncout_out_UNCONNECTED(1 downto 0),
      rxsysclksel_in(3) => '1',
      rxsysclksel_in(2) => '0',
      rxsysclksel_in(1) => '1',
      rxsysclksel_in(0) => '0',
      rxuserrdy_in(1) => '1',
      rxuserrdy_in(0) => '1',
      rxusrclk2_in(1 downto 0) => rxusrclk2_in(1 downto 0),
      rxusrclk_in(1 downto 0) => rxusrclk_in(1 downto 0),
      rxvalid_out(1 downto 0) => NLW_inst_rxvalid_out_UNCONNECTED(1 downto 0),
      sdm0data_in(0) => '0',
      sdm0finalout_out(0) => NLW_inst_sdm0finalout_out_UNCONNECTED(0),
      sdm0reset_in(0) => '0',
      sdm0testdata_out(0) => NLW_inst_sdm0testdata_out_UNCONNECTED(0),
      sdm0width_in(0) => '0',
      sdm1data_in(0) => '0',
      sdm1finalout_out(0) => NLW_inst_sdm1finalout_out_UNCONNECTED(0),
      sdm1reset_in(0) => '0',
      sdm1testdata_out(0) => NLW_inst_sdm1testdata_out_UNCONNECTED(0),
      sdm1width_in(0) => '0',
      sigvalidclk_in(1) => '0',
      sigvalidclk_in(0) => '0',
      tstin_in(39) => '0',
      tstin_in(38) => '0',
      tstin_in(37) => '0',
      tstin_in(36) => '0',
      tstin_in(35) => '0',
      tstin_in(34) => '0',
      tstin_in(33) => '0',
      tstin_in(32) => '0',
      tstin_in(31) => '0',
      tstin_in(30) => '0',
      tstin_in(29) => '0',
      tstin_in(28) => '0',
      tstin_in(27) => '0',
      tstin_in(26) => '0',
      tstin_in(25) => '0',
      tstin_in(24) => '0',
      tstin_in(23) => '0',
      tstin_in(22) => '0',
      tstin_in(21) => '0',
      tstin_in(20) => '0',
      tstin_in(19) => '0',
      tstin_in(18) => '0',
      tstin_in(17) => '0',
      tstin_in(16) => '0',
      tstin_in(15) => '0',
      tstin_in(14) => '0',
      tstin_in(13) => '0',
      tstin_in(12) => '0',
      tstin_in(11) => '0',
      tstin_in(10) => '0',
      tstin_in(9) => '0',
      tstin_in(8) => '0',
      tstin_in(7) => '0',
      tstin_in(6) => '0',
      tstin_in(5) => '0',
      tstin_in(4) => '0',
      tstin_in(3) => '0',
      tstin_in(2) => '0',
      tstin_in(1) => '0',
      tstin_in(0) => '0',
      tx8b10bbypass_in(15) => '0',
      tx8b10bbypass_in(14) => '0',
      tx8b10bbypass_in(13) => '0',
      tx8b10bbypass_in(12) => '0',
      tx8b10bbypass_in(11) => '0',
      tx8b10bbypass_in(10) => '0',
      tx8b10bbypass_in(9) => '0',
      tx8b10bbypass_in(8) => '0',
      tx8b10bbypass_in(7) => '0',
      tx8b10bbypass_in(6) => '0',
      tx8b10bbypass_in(5) => '0',
      tx8b10bbypass_in(4) => '0',
      tx8b10bbypass_in(3) => '0',
      tx8b10bbypass_in(2) => '0',
      tx8b10bbypass_in(1) => '0',
      tx8b10bbypass_in(0) => '0',
      tx8b10ben_in(1 downto 0) => tx8b10ben_in(1 downto 0),
      txbufdiffctrl_in(5) => '0',
      txbufdiffctrl_in(4) => '0',
      txbufdiffctrl_in(3) => '0',
      txbufdiffctrl_in(2) => '0',
      txbufdiffctrl_in(1) => '0',
      txbufdiffctrl_in(0) => '0',
      txbufstatus_out(3 downto 0) => NLW_inst_txbufstatus_out_UNCONNECTED(3 downto 0),
      txcomfinish_out(1 downto 0) => NLW_inst_txcomfinish_out_UNCONNECTED(1 downto 0),
      txcominit_in(1) => '0',
      txcominit_in(0) => '0',
      txcomsas_in(1) => '0',
      txcomsas_in(0) => '0',
      txcomwake_in(1) => '0',
      txcomwake_in(0) => '0',
      txctrl0_in(31 downto 0) => txctrl0_in(31 downto 0),
      txctrl1_in(31 downto 0) => txctrl1_in(31 downto 0),
      txctrl2_in(15 downto 0) => txctrl2_in(15 downto 0),
      txdata_in(255) => '0',
      txdata_in(254) => '0',
      txdata_in(253) => '0',
      txdata_in(252) => '0',
      txdata_in(251) => '0',
      txdata_in(250) => '0',
      txdata_in(249) => '0',
      txdata_in(248) => '0',
      txdata_in(247) => '0',
      txdata_in(246) => '0',
      txdata_in(245) => '0',
      txdata_in(244) => '0',
      txdata_in(243) => '0',
      txdata_in(242) => '0',
      txdata_in(241) => '0',
      txdata_in(240) => '0',
      txdata_in(239) => '0',
      txdata_in(238) => '0',
      txdata_in(237) => '0',
      txdata_in(236) => '0',
      txdata_in(235) => '0',
      txdata_in(234) => '0',
      txdata_in(233) => '0',
      txdata_in(232) => '0',
      txdata_in(231) => '0',
      txdata_in(230) => '0',
      txdata_in(229) => '0',
      txdata_in(228) => '0',
      txdata_in(227) => '0',
      txdata_in(226) => '0',
      txdata_in(225) => '0',
      txdata_in(224) => '0',
      txdata_in(223) => '0',
      txdata_in(222) => '0',
      txdata_in(221) => '0',
      txdata_in(220) => '0',
      txdata_in(219) => '0',
      txdata_in(218) => '0',
      txdata_in(217) => '0',
      txdata_in(216) => '0',
      txdata_in(215) => '0',
      txdata_in(214) => '0',
      txdata_in(213) => '0',
      txdata_in(212) => '0',
      txdata_in(211) => '0',
      txdata_in(210) => '0',
      txdata_in(209) => '0',
      txdata_in(208) => '0',
      txdata_in(207) => '0',
      txdata_in(206) => '0',
      txdata_in(205) => '0',
      txdata_in(204) => '0',
      txdata_in(203) => '0',
      txdata_in(202) => '0',
      txdata_in(201) => '0',
      txdata_in(200) => '0',
      txdata_in(199) => '0',
      txdata_in(198) => '0',
      txdata_in(197) => '0',
      txdata_in(196) => '0',
      txdata_in(195) => '0',
      txdata_in(194) => '0',
      txdata_in(193) => '0',
      txdata_in(192) => '0',
      txdata_in(191) => '0',
      txdata_in(190) => '0',
      txdata_in(189) => '0',
      txdata_in(188) => '0',
      txdata_in(187) => '0',
      txdata_in(186) => '0',
      txdata_in(185) => '0',
      txdata_in(184) => '0',
      txdata_in(183) => '0',
      txdata_in(182) => '0',
      txdata_in(181) => '0',
      txdata_in(180) => '0',
      txdata_in(179) => '0',
      txdata_in(178) => '0',
      txdata_in(177) => '0',
      txdata_in(176) => '0',
      txdata_in(175) => '0',
      txdata_in(174) => '0',
      txdata_in(173) => '0',
      txdata_in(172) => '0',
      txdata_in(171) => '0',
      txdata_in(170) => '0',
      txdata_in(169) => '0',
      txdata_in(168) => '0',
      txdata_in(167) => '0',
      txdata_in(166) => '0',
      txdata_in(165) => '0',
      txdata_in(164) => '0',
      txdata_in(163) => '0',
      txdata_in(162) => '0',
      txdata_in(161) => '0',
      txdata_in(160) => '0',
      txdata_in(159) => '0',
      txdata_in(158) => '0',
      txdata_in(157) => '0',
      txdata_in(156) => '0',
      txdata_in(155) => '0',
      txdata_in(154) => '0',
      txdata_in(153) => '0',
      txdata_in(152) => '0',
      txdata_in(151) => '0',
      txdata_in(150) => '0',
      txdata_in(149) => '0',
      txdata_in(148) => '0',
      txdata_in(147) => '0',
      txdata_in(146) => '0',
      txdata_in(145) => '0',
      txdata_in(144) => '0',
      txdata_in(143) => '0',
      txdata_in(142) => '0',
      txdata_in(141) => '0',
      txdata_in(140) => '0',
      txdata_in(139) => '0',
      txdata_in(138) => '0',
      txdata_in(137) => '0',
      txdata_in(136) => '0',
      txdata_in(135) => '0',
      txdata_in(134) => '0',
      txdata_in(133) => '0',
      txdata_in(132) => '0',
      txdata_in(131) => '0',
      txdata_in(130) => '0',
      txdata_in(129) => '0',
      txdata_in(128) => '0',
      txdata_in(127) => '0',
      txdata_in(126) => '0',
      txdata_in(125) => '0',
      txdata_in(124) => '0',
      txdata_in(123) => '0',
      txdata_in(122) => '0',
      txdata_in(121) => '0',
      txdata_in(120) => '0',
      txdata_in(119) => '0',
      txdata_in(118) => '0',
      txdata_in(117) => '0',
      txdata_in(116) => '0',
      txdata_in(115) => '0',
      txdata_in(114) => '0',
      txdata_in(113) => '0',
      txdata_in(112) => '0',
      txdata_in(111) => '0',
      txdata_in(110) => '0',
      txdata_in(109) => '0',
      txdata_in(108) => '0',
      txdata_in(107) => '0',
      txdata_in(106) => '0',
      txdata_in(105) => '0',
      txdata_in(104) => '0',
      txdata_in(103) => '0',
      txdata_in(102) => '0',
      txdata_in(101) => '0',
      txdata_in(100) => '0',
      txdata_in(99) => '0',
      txdata_in(98) => '0',
      txdata_in(97) => '0',
      txdata_in(96) => '0',
      txdata_in(95) => '0',
      txdata_in(94) => '0',
      txdata_in(93) => '0',
      txdata_in(92) => '0',
      txdata_in(91) => '0',
      txdata_in(90) => '0',
      txdata_in(89) => '0',
      txdata_in(88) => '0',
      txdata_in(87) => '0',
      txdata_in(86) => '0',
      txdata_in(85) => '0',
      txdata_in(84) => '0',
      txdata_in(83) => '0',
      txdata_in(82) => '0',
      txdata_in(81) => '0',
      txdata_in(80) => '0',
      txdata_in(79) => '0',
      txdata_in(78) => '0',
      txdata_in(77) => '0',
      txdata_in(76) => '0',
      txdata_in(75) => '0',
      txdata_in(74) => '0',
      txdata_in(73) => '0',
      txdata_in(72) => '0',
      txdata_in(71) => '0',
      txdata_in(70) => '0',
      txdata_in(69) => '0',
      txdata_in(68) => '0',
      txdata_in(67) => '0',
      txdata_in(66) => '0',
      txdata_in(65) => '0',
      txdata_in(64) => '0',
      txdata_in(63) => '0',
      txdata_in(62) => '0',
      txdata_in(61) => '0',
      txdata_in(60) => '0',
      txdata_in(59) => '0',
      txdata_in(58) => '0',
      txdata_in(57) => '0',
      txdata_in(56) => '0',
      txdata_in(55) => '0',
      txdata_in(54) => '0',
      txdata_in(53) => '0',
      txdata_in(52) => '0',
      txdata_in(51) => '0',
      txdata_in(50) => '0',
      txdata_in(49) => '0',
      txdata_in(48) => '0',
      txdata_in(47) => '0',
      txdata_in(46) => '0',
      txdata_in(45) => '0',
      txdata_in(44) => '0',
      txdata_in(43) => '0',
      txdata_in(42) => '0',
      txdata_in(41) => '0',
      txdata_in(40) => '0',
      txdata_in(39) => '0',
      txdata_in(38) => '0',
      txdata_in(37) => '0',
      txdata_in(36) => '0',
      txdata_in(35) => '0',
      txdata_in(34) => '0',
      txdata_in(33) => '0',
      txdata_in(32) => '0',
      txdata_in(31) => '0',
      txdata_in(30) => '0',
      txdata_in(29) => '0',
      txdata_in(28) => '0',
      txdata_in(27) => '0',
      txdata_in(26) => '0',
      txdata_in(25) => '0',
      txdata_in(24) => '0',
      txdata_in(23) => '0',
      txdata_in(22) => '0',
      txdata_in(21) => '0',
      txdata_in(20) => '0',
      txdata_in(19) => '0',
      txdata_in(18) => '0',
      txdata_in(17) => '0',
      txdata_in(16) => '0',
      txdata_in(15) => '0',
      txdata_in(14) => '0',
      txdata_in(13) => '0',
      txdata_in(12) => '0',
      txdata_in(11) => '0',
      txdata_in(10) => '0',
      txdata_in(9) => '0',
      txdata_in(8) => '0',
      txdata_in(7) => '0',
      txdata_in(6) => '0',
      txdata_in(5) => '0',
      txdata_in(4) => '0',
      txdata_in(3) => '0',
      txdata_in(2) => '0',
      txdata_in(1) => '0',
      txdata_in(0) => '0',
      txdataextendrsvd_in(15) => '0',
      txdataextendrsvd_in(14) => '0',
      txdataextendrsvd_in(13) => '0',
      txdataextendrsvd_in(12) => '0',
      txdataextendrsvd_in(11) => '0',
      txdataextendrsvd_in(10) => '0',
      txdataextendrsvd_in(9) => '0',
      txdataextendrsvd_in(8) => '0',
      txdataextendrsvd_in(7) => '0',
      txdataextendrsvd_in(6) => '0',
      txdataextendrsvd_in(5) => '0',
      txdataextendrsvd_in(4) => '0',
      txdataextendrsvd_in(3) => '0',
      txdataextendrsvd_in(2) => '0',
      txdataextendrsvd_in(1) => '0',
      txdataextendrsvd_in(0) => '0',
      txdccdone_out(0) => NLW_inst_txdccdone_out_UNCONNECTED(0),
      txdccforcestart_in(0) => '0',
      txdccreset_in(0) => '0',
      txdeemph_in(1) => '0',
      txdeemph_in(0) => '0',
      txdetectrx_in(1) => '0',
      txdetectrx_in(0) => '0',
      txdiffctrl_in(7) => '1',
      txdiffctrl_in(6) => '1',
      txdiffctrl_in(5) => '0',
      txdiffctrl_in(4) => '0',
      txdiffctrl_in(3) => '1',
      txdiffctrl_in(2) => '1',
      txdiffctrl_in(1) => '0',
      txdiffctrl_in(0) => '0',
      txdiffpd_in(1) => '0',
      txdiffpd_in(0) => '0',
      txdlybypass_in(1) => '1',
      txdlybypass_in(0) => '1',
      txdlyen_in(1) => '0',
      txdlyen_in(0) => '0',
      txdlyhold_in(1) => '0',
      txdlyhold_in(0) => '0',
      txdlyovrden_in(1) => '0',
      txdlyovrden_in(0) => '0',
      txdlysreset_in(1) => '0',
      txdlysreset_in(0) => '0',
      txdlysresetdone_out(1 downto 0) => NLW_inst_txdlysresetdone_out_UNCONNECTED(1 downto 0),
      txdlyupdown_in(1) => '0',
      txdlyupdown_in(0) => '0',
      txelecidle_in(1) => '0',
      txelecidle_in(0) => '0',
      txelforcestart_in(0) => '0',
      txheader_in(11) => '0',
      txheader_in(10) => '0',
      txheader_in(9) => '0',
      txheader_in(8) => '0',
      txheader_in(7) => '0',
      txheader_in(6) => '0',
      txheader_in(5) => '0',
      txheader_in(4) => '0',
      txheader_in(3) => '0',
      txheader_in(2) => '0',
      txheader_in(1) => '0',
      txheader_in(0) => '0',
      txinhibit_in(1) => '0',
      txinhibit_in(0) => '0',
      txlatclk_in(1) => '0',
      txlatclk_in(0) => '0',
      txmaincursor_in(13) => '1',
      txmaincursor_in(12) => '0',
      txmaincursor_in(11) => '0',
      txmaincursor_in(10) => '0',
      txmaincursor_in(9) => '0',
      txmaincursor_in(8) => '0',
      txmaincursor_in(7) => '0',
      txmaincursor_in(6) => '1',
      txmaincursor_in(5) => '0',
      txmaincursor_in(4) => '0',
      txmaincursor_in(3) => '0',
      txmaincursor_in(2) => '0',
      txmaincursor_in(1) => '0',
      txmaincursor_in(0) => '0',
      txmargin_in(5) => '0',
      txmargin_in(4) => '0',
      txmargin_in(3) => '0',
      txmargin_in(2) => '0',
      txmargin_in(1) => '0',
      txmargin_in(0) => '0',
      txoutclk_out(1 downto 0) => txoutclk_out(1 downto 0),
      txoutclkfabric_out(1 downto 0) => NLW_inst_txoutclkfabric_out_UNCONNECTED(1 downto 0),
      txoutclkpcs_out(1 downto 0) => NLW_inst_txoutclkpcs_out_UNCONNECTED(1 downto 0),
      txoutclksel_in(5) => '0',
      txoutclksel_in(4) => '1',
      txoutclksel_in(3) => '0',
      txoutclksel_in(2) => '0',
      txoutclksel_in(1) => '1',
      txoutclksel_in(0) => '0',
      txpcsreset_in(1) => '0',
      txpcsreset_in(0) => '0',
      txpd_in(3) => '0',
      txpd_in(2) => '0',
      txpd_in(1) => '0',
      txpd_in(0) => '0',
      txpdelecidlemode_in(1) => '0',
      txpdelecidlemode_in(0) => '0',
      txphalign_in(1) => '0',
      txphalign_in(0) => '0',
      txphaligndone_out(1 downto 0) => NLW_inst_txphaligndone_out_UNCONNECTED(1 downto 0),
      txphalignen_in(1) => '0',
      txphalignen_in(0) => '0',
      txphdlypd_in(1) => '1',
      txphdlypd_in(0) => '1',
      txphdlyreset_in(1) => '0',
      txphdlyreset_in(0) => '0',
      txphdlytstclk_in(1) => '0',
      txphdlytstclk_in(0) => '0',
      txphinit_in(1) => '0',
      txphinit_in(0) => '0',
      txphinitdone_out(1 downto 0) => NLW_inst_txphinitdone_out_UNCONNECTED(1 downto 0),
      txphovrden_in(1) => '0',
      txphovrden_in(0) => '0',
      txpippmen_in(1) => '0',
      txpippmen_in(0) => '0',
      txpippmovrden_in(1) => '0',
      txpippmovrden_in(0) => '0',
      txpippmpd_in(1) => '0',
      txpippmpd_in(0) => '0',
      txpippmsel_in(1) => '0',
      txpippmsel_in(0) => '0',
      txpippmstepsize_in(9) => '0',
      txpippmstepsize_in(8) => '0',
      txpippmstepsize_in(7) => '0',
      txpippmstepsize_in(6) => '0',
      txpippmstepsize_in(5) => '0',
      txpippmstepsize_in(4) => '0',
      txpippmstepsize_in(3) => '0',
      txpippmstepsize_in(2) => '0',
      txpippmstepsize_in(1) => '0',
      txpippmstepsize_in(0) => '0',
      txpisopd_in(1) => '0',
      txpisopd_in(0) => '0',
      txpllclksel_in(3) => '1',
      txpllclksel_in(2) => '1',
      txpllclksel_in(1) => '1',
      txpllclksel_in(0) => '1',
      txpmareset_in(1) => '0',
      txpmareset_in(0) => '0',
      txpmaresetdone_out(1 downto 0) => txpmaresetdone_out(1 downto 0),
      txpolarity_in(1 downto 0) => txpolarity_in(1 downto 0),
      txpostcursor_in(9) => '0',
      txpostcursor_in(8) => '0',
      txpostcursor_in(7) => '0',
      txpostcursor_in(6) => '0',
      txpostcursor_in(5) => '0',
      txpostcursor_in(4) => '0',
      txpostcursor_in(3) => '0',
      txpostcursor_in(2) => '0',
      txpostcursor_in(1) => '0',
      txpostcursor_in(0) => '0',
      txpostcursorinv_in(1) => '0',
      txpostcursorinv_in(0) => '0',
      txprbsforceerr_in(1) => '0',
      txprbsforceerr_in(0) => '0',
      txprbssel_in(7) => '0',
      txprbssel_in(6) => '0',
      txprbssel_in(5) => '0',
      txprbssel_in(4) => '0',
      txprbssel_in(3) => '0',
      txprbssel_in(2) => '0',
      txprbssel_in(1) => '0',
      txprbssel_in(0) => '0',
      txprecursor_in(9) => '0',
      txprecursor_in(8) => '0',
      txprecursor_in(7) => '0',
      txprecursor_in(6) => '0',
      txprecursor_in(5) => '0',
      txprecursor_in(4) => '0',
      txprecursor_in(3) => '0',
      txprecursor_in(2) => '0',
      txprecursor_in(1) => '0',
      txprecursor_in(0) => '0',
      txprecursorinv_in(1) => '0',
      txprecursorinv_in(0) => '0',
      txprgdivresetdone_out(1 downto 0) => NLW_inst_txprgdivresetdone_out_UNCONNECTED(1 downto 0),
      txprogdivreset_in(1) => '0',
      txprogdivreset_in(0) => '0',
      txqpibiasen_in(1) => '0',
      txqpibiasen_in(0) => '0',
      txqpisenn_out(1 downto 0) => NLW_inst_txqpisenn_out_UNCONNECTED(1 downto 0),
      txqpisenp_out(1 downto 0) => NLW_inst_txqpisenp_out_UNCONNECTED(1 downto 0),
      txqpistrongpdown_in(1) => '0',
      txqpistrongpdown_in(0) => '0',
      txqpiweakpup_in(1) => '0',
      txqpiweakpup_in(0) => '0',
      txrate_in(5) => '0',
      txrate_in(4) => '0',
      txrate_in(3) => '0',
      txrate_in(2) => '0',
      txrate_in(1) => '0',
      txrate_in(0) => '0',
      txratedone_out(1 downto 0) => NLW_inst_txratedone_out_UNCONNECTED(1 downto 0),
      txratemode_in(1) => '0',
      txratemode_in(0) => '0',
      txresetdone_out(1 downto 0) => NLW_inst_txresetdone_out_UNCONNECTED(1 downto 0),
      txsequence_in(13) => '0',
      txsequence_in(12) => '0',
      txsequence_in(11) => '0',
      txsequence_in(10) => '0',
      txsequence_in(9) => '0',
      txsequence_in(8) => '0',
      txsequence_in(7) => '0',
      txsequence_in(6) => '0',
      txsequence_in(5) => '0',
      txsequence_in(4) => '0',
      txsequence_in(3) => '0',
      txsequence_in(2) => '0',
      txsequence_in(1) => '0',
      txsequence_in(0) => '0',
      txswing_in(1) => '0',
      txswing_in(0) => '0',
      txsyncallin_in(1) => '0',
      txsyncallin_in(0) => '0',
      txsyncdone_out(1 downto 0) => NLW_inst_txsyncdone_out_UNCONNECTED(1 downto 0),
      txsyncin_in(1) => '0',
      txsyncin_in(0) => '0',
      txsyncmode_in(1) => '0',
      txsyncmode_in(0) => '0',
      txsyncout_out(1 downto 0) => NLW_inst_txsyncout_out_UNCONNECTED(1 downto 0),
      txsysclksel_in(3) => '1',
      txsysclksel_in(2) => '0',
      txsysclksel_in(1) => '1',
      txsysclksel_in(0) => '0',
      txuserrdy_in(1) => '1',
      txuserrdy_in(0) => '1',
      txusrclk2_in(1 downto 0) => txusrclk2_in(1 downto 0),
      txusrclk_in(1 downto 0) => txusrclk_in(1 downto 0)
    );
end STRUCTURE;
