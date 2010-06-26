--------------------------------------------------------------------------------
-- Copyright (c) 1995-2009 Xilinx, Inc.  All rights reserved.
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor: Xilinx
-- \   \   \/     Version: L.68
--  \   \         Application: netgen
--  /   /         Filename: pgp2_v4_icon.vhd
-- /___/   /\     Timestamp: Thu Jun  3 10:09:13 2010
-- \   \  /  \ 
--  \___\/\___\
--             
-- Command	: -w -sim -ofmt vhdl /afs/slac.stanford.edu/u/ey/rherbst/projects/rce/release/rcehw/pgp2/xil_cores/tmp/_cg/pgp2_v4_icon.ngc /afs/slac.stanford.edu/u/ey/rherbst/projects/rce/release/rcehw/pgp2/xil_cores/tmp/_cg/pgp2_v4_icon.vhd 
-- Device	: xc4vfx60-ff672-12
-- Input file	: /afs/slac.stanford.edu/u/ey/rherbst/projects/rce/release/rcehw/pgp2/xil_cores/tmp/_cg/pgp2_v4_icon.ngc
-- Output file	: /afs/slac.stanford.edu/u/ey/rherbst/projects/rce/release/rcehw/pgp2/xil_cores/tmp/_cg/pgp2_v4_icon.vhd
-- # of Entities	: 1
-- Design Name	: pgp2_v4_icon
-- Xilinx	: /afs/slac.stanford.edu/g/reseng/vol8/xilinx/11.4/ISE
--             
-- Purpose:    
--     This VHDL netlist is a verification model and uses simulation 
--     primitives which may not represent the true implementation of the 
--     device, however the netlist is functionally correct and should not 
--     be modified. This file cannot be synthesized and should only be used 
--     with supported simulation tools.
--             
-- Reference:  
--     Command Line Tools User Guide, Chapter 23
--     Synthesis and Simulation Design Guide, Chapter 6
--             
--------------------------------------------------------------------------------


-- synthesis translate_off
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

entity pgp2_v4_icon is
  port (
    CONTROL0 : inout STD_LOGIC_VECTOR ( 35 downto 0 ); 
    CONTROL1 : inout STD_LOGIC_VECTOR ( 35 downto 0 ) 
  );
end pgp2_v4_icon;

architecture STRUCTURE of pgp2_v4_icon is
  component icon_bscan_bufg
    port (
      DRCK_LOCAL_I : in STD_LOGIC := 'X'; 
      DRCK_LOCAL_O : out STD_LOGIC 
    );
  end component;
  signal N1 : STD_LOGIC; 
  signal N132 : STD_LOGIC; 
  signal N133 : STD_LOGIC; 
  signal N77 : STD_LOGIC; 
  signal U0_U_ICON_I_YES_BSCAN_U_BS_iDRCK_LOCAL : STD_LOGIC; 
  signal U0_U_ICON_U_CMD_iSEL_n : STD_LOGIC; 
  signal U0_U_ICON_U_CMD_iTARGET_CE : STD_LOGIC; 
  signal U0_U_ICON_U_CTRL_OUT_iDATA_VALID : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iCMD_GRP0_SEL : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iDATA_VALID : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iSTATCMD_CE : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iSTATCMD_CE_n : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iSTAT_HIGH : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iSTAT_LOW : STD_LOGIC; 
  signal U0_U_ICON_U_STAT_iTDO_next : STD_LOGIC; 
  signal U0_U_ICON_U_SYNC_iDATA_CMD_n : STD_LOGIC; 
  signal U0_U_ICON_U_SYNC_iGOT_SYNC : STD_LOGIC; 
  signal U0_U_ICON_U_SYNC_iGOT_SYNC_HIGH : STD_LOGIC; 
  signal U0_U_ICON_U_SYNC_iGOT_SYNC_LOW : STD_LOGIC; 
  signal U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_3_128 : STD_LOGIC; 
  signal U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_4_129 : STD_LOGIC; 
  signal U0_U_ICON_iCORE_ID_1_1_150 : STD_LOGIC; 
  signal U0_U_ICON_iCORE_ID_SEL_0_Q : STD_LOGIC; 
  signal U0_U_ICON_iCORE_ID_SEL_15_Q : STD_LOGIC; 
  signal U0_U_ICON_iCORE_ID_SEL_1_Q : STD_LOGIC; 
  signal U0_U_ICON_iDATA_CMD : STD_LOGIC; 
  signal U0_U_ICON_iDATA_CMD_n : STD_LOGIC; 
  signal U0_U_ICON_iSEL : STD_LOGIC; 
  signal U0_U_ICON_iSEL_n : STD_LOGIC; 
  signal U0_U_ICON_iSYNC : STD_LOGIC; 
  signal U0_U_ICON_iTDI : STD_LOGIC; 
  signal U0_U_ICON_iTDO : STD_LOGIC; 
  signal U0_U_ICON_iTDO_next : STD_LOGIC; 
  signal U0_iSHIFT_OUT : STD_LOGIC; 
  signal U0_iUPDATE_OUT : STD_LOGIC; 
  signal NLW_U0_U_ICON_I_YES_BSCAN_U_BS_I_V4_U_BS_CAPTURE_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_I_YES_BSCAN_U_BS_I_V4_U_BS_RESET_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_2_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_3_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_4_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_5_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_6_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_7_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_8_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_9_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_10_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_11_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_12_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_13_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_14_U_LUT_O_UNCONNECTED : STD_LOGIC; 
  signal U0_U_ICON_U_CMD_iTARGET : STD_LOGIC_VECTOR ( 11 downto 8 ); 
  signal U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL : STD_LOGIC_VECTOR ( 1 downto 0 ); 
  signal U0_U_ICON_U_STAT_U_STAT_CNT_CI : STD_LOGIC_VECTOR ( 5 downto 1 ); 
  signal U0_U_ICON_U_STAT_U_STAT_CNT_D : STD_LOGIC_VECTOR ( 5 downto 0 ); 
  signal U0_U_ICON_U_STAT_U_STAT_CNT_S : STD_LOGIC_VECTOR ( 5 downto 0 ); 
  signal U0_U_ICON_U_STAT_iSTAT : STD_LOGIC_VECTOR ( 3 downto 0 ); 
  signal U0_U_ICON_U_STAT_iSTAT_CNT : STD_LOGIC_VECTOR ( 5 downto 0 ); 
  signal U0_U_ICON_U_SYNC_iSYNC_WORD : STD_LOGIC_VECTOR ( 6 downto 0 ); 
  signal U0_U_ICON_iCOMMAND_GRP : STD_LOGIC_VECTOR ( 1 downto 0 ); 
  signal U0_U_ICON_iCOMMAND_SEL : STD_LOGIC_VECTOR ( 15 downto 0 ); 
  signal U0_U_ICON_iCORE_ID : STD_LOGIC_VECTOR ( 3 downto 0 ); 
  signal U0_U_ICON_iTDO_VEC : STD_LOGIC_VECTOR ( 15 downto 15 ); 
begin
  CONTROL0(2) <= CONTROL1(2);
  CONTROL1(0) <= CONTROL0(0);
  CONTROL1(1) <= CONTROL0(1);
  XST_GND : GND
    port map (
      G => CONTROL1(2)
    );
  XST_VCC : VCC
    port map (
      P => N1
    );
  U0_U_ICON_U_TDI_reg : FDE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_iTDI,
      Q => CONTROL0(1)
    );
  U0_U_ICON_U_TDO_reg : FDE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_iTDO_next,
      Q => U0_U_ICON_iTDO
    );
  U0_U_ICON_U_iDATA_CMD : FDC
    generic map(
      INIT => '0'
    )
    port map (
      C => U0_iUPDATE_OUT,
      CLR => U0_U_ICON_iSEL_n,
      D => U0_U_ICON_iDATA_CMD_n,
      Q => U0_U_ICON_iDATA_CMD
    );
  U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_2_f5 : MUXF5
    port map (
      I0 => U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_4_129,
      I1 => U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_3_128,
      S => U0_U_ICON_iCORE_ID(3),
      O => U0_U_ICON_iTDO_next
    );
  U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_4 : LUT2
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID_1_1_150,
      I1 => U0_U_ICON_iCORE_ID(2),
      O => U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_4_129
    );
  U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_3 : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_iTDO_VEC(15),
      I1 => U0_U_ICON_iCORE_ID(0),
      I2 => U0_U_ICON_iCORE_ID(1),
      I3 => U0_U_ICON_iCORE_ID(2),
      O => U0_U_ICON_U_TDO_MUX_U_CS_MUX_I4_U_MUX16_Mmux_O_3_128
    );
  U0_U_ICON_U_iSEL_n : INV
    port map (
      I => U0_U_ICON_iSEL,
      O => U0_U_ICON_iSEL_n
    );
  U0_U_ICON_U_iDATA_CMD_n : INV
    port map (
      I => U0_U_ICON_iDATA_CMD,
      O => U0_U_ICON_iDATA_CMD_n
    );
  U0_U_ICON_I_YES_BSCAN_U_BS_I_V4_U_BS : BSCAN_VIRTEX4
    generic map(
      JTAG_CHAIN => 1
    )
    port map (
      TDO => U0_U_ICON_iTDO,
      CAPTURE => NLW_U0_U_ICON_I_YES_BSCAN_U_BS_I_V4_U_BS_CAPTURE_UNCONNECTED,
      DRCK => U0_U_ICON_I_YES_BSCAN_U_BS_iDRCK_LOCAL,
      RESET => NLW_U0_U_ICON_I_YES_BSCAN_U_BS_I_V4_U_BS_RESET_UNCONNECTED,
      SEL => U0_U_ICON_iSEL,
      SHIFT => U0_iSHIFT_OUT,
      TDI => U0_U_ICON_iTDI,
      UPDATE => U0_iUPDATE_OUT
    );
  U0_U_ICON_I_YES_BSCAN_U_BS_I_USE_SOFTBSCAN_EQ0_I_USE_XST_TCK_WORKAROUND_EQ1_U_ICON_BSCAN_BUFG : icon_bscan_bufg
    port map (
      DRCK_LOCAL_I => U0_U_ICON_I_YES_BSCAN_U_BS_iDRCK_LOCAL,
      DRCK_LOCAL_O => CONTROL0(0)
    );
  U0_U_ICON_U_SYNC_U_GOT_SYNC : LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => U0_U_ICON_U_SYNC_iGOT_SYNC_LOW,
      I1 => U0_U_ICON_U_SYNC_iGOT_SYNC_HIGH,
      O => U0_U_ICON_U_SYNC_iGOT_SYNC
    );
  U0_U_ICON_U_SYNC_U_GOT_SYNC_L : LUT4
    generic map(
      INIT => X"0200"
    )
    port map (
      I0 => U0_U_ICON_U_SYNC_iSYNC_WORD(0),
      I1 => U0_U_ICON_U_SYNC_iSYNC_WORD(1),
      I2 => U0_U_ICON_U_SYNC_iSYNC_WORD(2),
      I3 => U0_U_ICON_U_SYNC_iSYNC_WORD(3),
      O => U0_U_ICON_U_SYNC_iGOT_SYNC_LOW
    );
  U0_U_ICON_U_SYNC_U_GOT_SYNC_H : LUT4
    generic map(
      INIT => X"0400"
    )
    port map (
      I0 => U0_U_ICON_U_SYNC_iSYNC_WORD(4),
      I1 => U0_U_ICON_U_SYNC_iSYNC_WORD(5),
      I2 => U0_U_ICON_U_SYNC_iSYNC_WORD(6),
      I3 => CONTROL0(1),
      O => U0_U_ICON_U_SYNC_iGOT_SYNC_HIGH
    );
  U0_U_ICON_U_SYNC_U_iDATA_CMD_n : INV
    port map (
      I => U0_U_ICON_iDATA_CMD,
      O => U0_U_ICON_U_SYNC_iDATA_CMD_n
    );
  U0_U_ICON_U_SYNC_U_SYNC : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_SYNC_iGOT_SYNC,
      D => N1,
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_iSYNC
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_0_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(1),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(0)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_1_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(2),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(1)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_2_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(3),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(2)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_3_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(4),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(3)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_4_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(5),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(4)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_5_I_NE0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => U0_U_ICON_U_SYNC_iSYNC_WORD(6),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(5)
    );
  U0_U_ICON_U_SYNC_G_SYNC_WORD_6_I_EQ0_U_FDR : FDR
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      D => CONTROL0(1),
      R => U0_U_ICON_U_SYNC_iDATA_CMD_n,
      Q => U0_U_ICON_U_SYNC_iSYNC_WORD(6)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_0_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(0),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(20)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_0_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(0),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(4)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_1_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(1),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(21)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_1_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(1),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(5)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_2_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(2),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(22)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_2_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(2),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(6)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_3_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(3),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(23)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_3_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(3),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(7)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_4_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(4),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(24)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_4_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(4),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(8)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_5_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(5),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(25)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_5_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(5),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(9)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_6_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(6),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(26)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_6_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(6),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(10)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_7_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(7),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(27)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_7_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(7),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(11)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_8_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(8),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(28)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_8_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(8),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(12)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_9_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(9),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(29)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_9_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(9),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(13)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_10_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(10),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(30)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_10_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(10),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(14)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_11_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(11),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(31)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_11_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(11),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(15)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_12_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(12),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(32)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_12_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(12),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(16)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_13_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(13),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(33)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_13_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(13),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(17)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_14_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(14),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(34)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_14_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(14),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(18)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_15_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(15),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL0(35)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_0_F_CMD_15_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(15),
      I2 => U0_U_ICON_iCORE_ID_SEL_0_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL0(19)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_0_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(0),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(20)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_0_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(0),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(4)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_1_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(1),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(21)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_1_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(1),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(5)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_2_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(2),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(22)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_2_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(2),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(6)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_3_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(3),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(23)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_3_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(3),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(7)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_4_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(4),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(24)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_4_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(4),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(8)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_5_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(5),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(25)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_5_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(5),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(9)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_6_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(6),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(26)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_6_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(6),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(10)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_7_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(7),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(27)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_7_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(7),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(11)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_8_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(8),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(28)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_8_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(8),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(12)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_9_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(9),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(29)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_9_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(9),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(13)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_10_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(10),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(30)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_10_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(10),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(14)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_11_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(11),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(31)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_11_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(11),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(15)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_12_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(12),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(32)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_12_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(12),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(16)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_13_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(13),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(33)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_13_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(13),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(17)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_14_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(14),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(34)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_14_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(14),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(18)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_15_U_HCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(15),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1),
      O => CONTROL1(35)
    );
  U0_U_ICON_U_CTRL_OUT_F_NCP_1_F_CMD_15_U_LCE : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CTRL_OUT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(15),
      I2 => U0_U_ICON_iCORE_ID_SEL_1_Q,
      I3 => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0),
      O => CONTROL1(19)
    );
  U0_U_ICON_U_CTRL_OUT_U_CMDGRP1 : LUT2
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_iCOMMAND_GRP(0),
      I1 => U0_U_ICON_iCOMMAND_GRP(1),
      O => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(1)
    );
  U0_U_ICON_U_CTRL_OUT_U_CMDGRP0 : LUT2
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => U0_U_ICON_iCOMMAND_GRP(0),
      I1 => U0_U_ICON_iCOMMAND_GRP(1),
      O => U0_U_ICON_U_CTRL_OUT_iCOMMAND_GRP_SEL(0)
    );
  U0_U_ICON_U_CTRL_OUT_U_DATA_VALID : LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => U0_U_ICON_iSYNC,
      I1 => U0_iSHIFT_OUT,
      O => U0_U_ICON_U_CTRL_OUT_iDATA_VALID
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_0_U_LUT : LUT4
    generic map(
      INIT => X"0001"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => U0_U_ICON_iCORE_ID_SEL_0_Q
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_1_U_LUT : LUT4
    generic map(
      INIT => X"0002"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => U0_U_ICON_iCORE_ID_SEL_1_Q
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_2_U_LUT : LUT4
    generic map(
      INIT => X"0004"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_2_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_3_U_LUT : LUT4
    generic map(
      INIT => X"0008"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_3_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_4_U_LUT : LUT4
    generic map(
      INIT => X"0010"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_4_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_5_U_LUT : LUT4
    generic map(
      INIT => X"0020"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_5_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_6_U_LUT : LUT4
    generic map(
      INIT => X"0040"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_6_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_7_U_LUT : LUT4
    generic map(
      INIT => X"0080"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_7_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_8_U_LUT : LUT4
    generic map(
      INIT => X"0100"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_8_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_9_U_LUT : LUT4
    generic map(
      INIT => X"0200"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_9_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_10_U_LUT : LUT4
    generic map(
      INIT => X"0400"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_10_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_11_U_LUT : LUT4
    generic map(
      INIT => X"0800"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_11_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_12_U_LUT : LUT4
    generic map(
      INIT => X"1000"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_12_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_13_U_LUT : LUT4
    generic map(
      INIT => X"2000"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_13_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_14_U_LUT : LUT4
    generic map(
      INIT => X"4000"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => NLW_U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_14_U_LUT_O_UNCONNECTED
    );
  U0_U_ICON_U_CMD_U_CORE_ID_SEL_I4_FI_15_U_LUT : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(0),
      I1 => U0_U_ICON_iCORE_ID(1),
      I2 => U0_U_ICON_iCORE_ID(2),
      I3 => U0_U_ICON_iCORE_ID(3),
      O => U0_U_ICON_iCORE_ID_SEL_15_Q
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_0_U_LUT : LUT4
    generic map(
      INIT => X"0001"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(0)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_1_U_LUT : LUT4
    generic map(
      INIT => X"0002"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(1)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_2_U_LUT : LUT4
    generic map(
      INIT => X"0004"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(2)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_3_U_LUT : LUT4
    generic map(
      INIT => X"0008"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(3)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_4_U_LUT : LUT4
    generic map(
      INIT => X"0010"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(4)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_5_U_LUT : LUT4
    generic map(
      INIT => X"0020"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(5)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_6_U_LUT : LUT4
    generic map(
      INIT => X"0040"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(6)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_7_U_LUT : LUT4
    generic map(
      INIT => X"0080"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(7)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_8_U_LUT : LUT4
    generic map(
      INIT => X"0100"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(8)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_9_U_LUT : LUT4
    generic map(
      INIT => X"0200"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(9)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_10_U_LUT : LUT4
    generic map(
      INIT => X"0400"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(10)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_11_U_LUT : LUT4
    generic map(
      INIT => X"0800"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(11)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_12_U_LUT : LUT4
    generic map(
      INIT => X"1000"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(12)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_13_U_LUT : LUT4
    generic map(
      INIT => X"2000"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(13)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_14_U_LUT : LUT4
    generic map(
      INIT => X"4000"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(14)
    );
  U0_U_ICON_U_CMD_U_COMMAND_SEL_I4_FI_15_U_LUT : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_CMD_iTARGET(8),
      I1 => U0_U_ICON_U_CMD_iTARGET(9),
      I2 => U0_U_ICON_U_CMD_iTARGET(10),
      I3 => U0_U_ICON_U_CMD_iTARGET(11),
      O => U0_U_ICON_iCOMMAND_SEL(15)
    );
  U0_U_ICON_U_CMD_U_TARGET_CE : LUT2
    generic map(
      INIT => X"4"
    )
    port map (
      I0 => U0_U_ICON_iDATA_CMD,
      I1 => U0_iSHIFT_OUT,
      O => U0_U_ICON_U_CMD_iTARGET_CE
    );
  U0_U_ICON_U_CMD_U_SEL_n : INV
    port map (
      I => U0_U_ICON_iSEL,
      O => U0_U_ICON_U_CMD_iSEL_n
    );
  U0_U_ICON_U_CMD_G_TARGET_6_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_iCOMMAND_GRP(1),
      Q => U0_U_ICON_iCOMMAND_GRP(0)
    );
  U0_U_ICON_U_CMD_G_TARGET_7_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_U_CMD_iTARGET(8),
      Q => U0_U_ICON_iCOMMAND_GRP(1)
    );
  U0_U_ICON_U_CMD_G_TARGET_8_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_U_CMD_iTARGET(9),
      Q => U0_U_ICON_U_CMD_iTARGET(8)
    );
  U0_U_ICON_U_CMD_G_TARGET_9_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_U_CMD_iTARGET(10),
      Q => U0_U_ICON_U_CMD_iTARGET(9)
    );
  U0_U_ICON_U_CMD_G_TARGET_10_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_U_CMD_iTARGET(11),
      Q => U0_U_ICON_U_CMD_iTARGET(10)
    );
  U0_U_ICON_U_CMD_G_TARGET_11_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_iCORE_ID(0),
      Q => U0_U_ICON_U_CMD_iTARGET(11)
    );
  U0_U_ICON_U_CMD_G_TARGET_12_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_iCORE_ID(1),
      Q => U0_U_ICON_iCORE_ID(0)
    );
  U0_U_ICON_U_CMD_G_TARGET_13_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_iCORE_ID(2),
      Q => U0_U_ICON_iCORE_ID(1)
    );
  U0_U_ICON_U_CMD_G_TARGET_14_I_NE0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => U0_U_ICON_iCORE_ID(3),
      Q => U0_U_ICON_iCORE_ID(2)
    );
  U0_U_ICON_U_CMD_G_TARGET_15_I_EQ0_U_TARGET : FDCE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => U0_U_ICON_U_CMD_iTARGET_CE,
      CLR => U0_U_ICON_U_CMD_iSEL_n,
      D => CONTROL0(1),
      Q => U0_U_ICON_iCORE_ID(3)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_5_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(5),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(5)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_4_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(4),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(4)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_3_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(3),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(3)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_2_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(2),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(2)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_1_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(1),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(1)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_0_U_FDRE : FDRE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_U_STAT_CNT_D(0),
      R => U0_U_ICON_U_STAT_iSTATCMD_CE_n,
      Q => U0_U_ICON_U_STAT_iSTAT_CNT(0)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_5_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(5),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(5)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_5_U_XORCY : XORCY
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(5),
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(5),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(5)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_4_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(4),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(4)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_4_GnH_U_MUXCY : MUXCY_L
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(4),
      DI => CONTROL1(2),
      S => U0_U_ICON_U_STAT_U_STAT_CNT_S(4),
      LO => U0_U_ICON_U_STAT_U_STAT_CNT_CI(5)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_4_U_XORCY : XORCY
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(4),
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(4),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(4)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_3_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(3),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(3)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_3_GnH_U_MUXCY : MUXCY_L
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(3),
      DI => CONTROL1(2),
      S => U0_U_ICON_U_STAT_U_STAT_CNT_S(3),
      LO => U0_U_ICON_U_STAT_U_STAT_CNT_CI(4)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_3_U_XORCY : XORCY
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(3),
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(3),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(3)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_2_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(2),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(2)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_2_GnH_U_MUXCY : MUXCY_L
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(2),
      DI => CONTROL1(2),
      S => U0_U_ICON_U_STAT_U_STAT_CNT_S(2),
      LO => U0_U_ICON_U_STAT_U_STAT_CNT_CI(3)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_2_U_XORCY : XORCY
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(2),
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(2),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(2)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_1_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(1),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(1)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_1_GnH_U_MUXCY : MUXCY_L
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(1),
      DI => CONTROL1(2),
      S => U0_U_ICON_U_STAT_U_STAT_CNT_S(1),
      LO => U0_U_ICON_U_STAT_U_STAT_CNT_CI(2)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_1_U_XORCY : XORCY
    port map (
      CI => U0_U_ICON_U_STAT_U_STAT_CNT_CI(1),
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(1),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(1)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_0_U_LUT : LUT1
    generic map(
      INIT => X"2"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(0),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_S(0)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_0_GnH_U_MUXCY : MUXCY_L
    port map (
      CI => N1,
      DI => CONTROL1(2),
      S => U0_U_ICON_U_STAT_U_STAT_CNT_S(0),
      LO => U0_U_ICON_U_STAT_U_STAT_CNT_CI(1)
    );
  U0_U_ICON_U_STAT_U_STAT_CNT_G_0_U_XORCY : XORCY
    port map (
      CI => N1,
      LI => U0_U_ICON_U_STAT_U_STAT_CNT_S(0),
      O => U0_U_ICON_U_STAT_U_STAT_CNT_D(0)
    );
  U0_U_ICON_U_STAT_U_TDO_next : MUXF6
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_LOW,
      I1 => U0_U_ICON_U_STAT_iSTAT_HIGH,
      S => U0_U_ICON_U_STAT_iSTAT_CNT(5),
      O => U0_U_ICON_U_STAT_iTDO_next
    );
  U0_U_ICON_U_STAT_U_STAT_LOW : MUXF5
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT(0),
      I1 => U0_U_ICON_U_STAT_iSTAT(1),
      S => U0_U_ICON_U_STAT_iSTAT_CNT(4),
      O => U0_U_ICON_U_STAT_iSTAT_LOW
    );
  U0_U_ICON_U_STAT_U_STAT_HIGH : MUXF5
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT(2),
      I1 => U0_U_ICON_U_STAT_iSTAT(3),
      S => U0_U_ICON_U_STAT_iSTAT_CNT(4),
      O => U0_U_ICON_U_STAT_iSTAT_HIGH
    );
  U0_U_ICON_U_STAT_F_STAT_0_U_STAT : LUT4
    generic map(
      INIT => X"0101"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(0),
      I1 => U0_U_ICON_U_STAT_iSTAT_CNT(1),
      I2 => U0_U_ICON_U_STAT_iSTAT_CNT(2),
      I3 => U0_U_ICON_U_STAT_iSTAT_CNT(3),
      O => U0_U_ICON_U_STAT_iSTAT(0)
    );
  U0_U_ICON_U_STAT_F_STAT_1_U_STAT : LUT4
    generic map(
      INIT => X"B401"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(0),
      I1 => U0_U_ICON_U_STAT_iSTAT_CNT(1),
      I2 => U0_U_ICON_U_STAT_iSTAT_CNT(2),
      I3 => U0_U_ICON_U_STAT_iSTAT_CNT(3),
      O => U0_U_ICON_U_STAT_iSTAT(1)
    );
  U0_U_ICON_U_STAT_F_STAT_2_U_STAT : LUT4
    generic map(
      INIT => X"2100"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(0),
      I1 => U0_U_ICON_U_STAT_iSTAT_CNT(1),
      I2 => U0_U_ICON_U_STAT_iSTAT_CNT(2),
      I3 => U0_U_ICON_U_STAT_iSTAT_CNT(3),
      O => U0_U_ICON_U_STAT_iSTAT(2)
    );
  U0_U_ICON_U_STAT_F_STAT_3_U_STAT : LUT4
    generic map(
      INIT => X"2610"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iSTAT_CNT(0),
      I1 => U0_U_ICON_U_STAT_iSTAT_CNT(1),
      I2 => U0_U_ICON_U_STAT_iSTAT_CNT(2),
      I3 => U0_U_ICON_U_STAT_iSTAT_CNT(3),
      O => U0_U_ICON_U_STAT_iSTAT(3)
    );
  U0_U_ICON_U_STAT_U_STATCMD_n : INV
    port map (
      I => U0_U_ICON_U_STAT_iSTATCMD_CE,
      O => U0_U_ICON_U_STAT_iSTATCMD_CE_n
    );
  U0_U_ICON_U_STAT_U_STATCMD : LUT4
    generic map(
      INIT => X"8000"
    )
    port map (
      I0 => U0_U_ICON_U_STAT_iDATA_VALID,
      I1 => U0_U_ICON_iCOMMAND_SEL(0),
      I2 => U0_U_ICON_iCORE_ID_SEL_15_Q,
      I3 => U0_U_ICON_U_STAT_iCMD_GRP0_SEL,
      O => U0_U_ICON_U_STAT_iSTATCMD_CE
    );
  U0_U_ICON_U_STAT_U_CMDGRP0 : LUT2
    generic map(
      INIT => X"1"
    )
    port map (
      I0 => U0_U_ICON_iCOMMAND_GRP(0),
      I1 => U0_U_ICON_iCOMMAND_GRP(1),
      O => U0_U_ICON_U_STAT_iCMD_GRP0_SEL
    );
  U0_U_ICON_U_STAT_U_DATA_VALID : LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => U0_U_ICON_iSYNC,
      I1 => U0_iSHIFT_OUT,
      O => U0_U_ICON_U_STAT_iDATA_VALID
    );
  U0_U_ICON_U_STAT_U_TDO : FDE
    generic map(
      INIT => '0'
    )
    port map (
      C => CONTROL0(0),
      CE => N1,
      D => U0_U_ICON_U_STAT_iTDO_next,
      Q => U0_U_ICON_iTDO_VEC(15)
    );
  U0_U_ICON_iCORE_ID_1_1 : LUT4
    generic map(
      INIT => X"5140"
    )
    port map (
      I0 => U0_U_ICON_iCORE_ID(1),
      I1 => U0_U_ICON_iCORE_ID(0),
      I2 => CONTROL1(3),
      I3 => CONTROL0(3),
      O => U0_U_ICON_iCORE_ID_1_1_150
    );

end STRUCTURE;

-- synthesis translate_on
