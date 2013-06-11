--------------------------------------------------------------------------------
--    This file is owned and controlled by Xilinx and must be used solely     --
--    for design, simulation, implementation and creation of design files     --
--    limited to Xilinx devices or technologies. Use with non-Xilinx          --
--    devices or technologies is expressly prohibited and immediately         --
--    terminates your license.                                                --
--                                                                            --
--    XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" SOLELY    --
--    FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY    --
--    PROVIDING THIS DESIGN, CODE, OR INFORMATION AS ONE POSSIBLE             --
--    IMPLEMENTATION OF THIS FEATURE, APPLICATION OR STANDARD, XILINX IS      --
--    MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION IS FREE FROM ANY      --
--    CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE FOR OBTAINING ANY       --
--    RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY       --
--    DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE   --
--    IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR          --
--    REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF         --
--    INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A   --
--    PARTICULAR PURPOSE.                                                     --
--                                                                            --
--    Xilinx products are not intended for use in life support appliances,    --
--    devices, or systems.  Use in such applications are expressly            --
--    prohibited.                                                             --
--                                                                            --
--    (c) Copyright 1995-2013 Xilinx, Inc.                                    --
--    All rights reserved.                                                    --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--    Generated from core with identifier: xilinx.com:ip:fifo_generator:9.3   --
--                                                                            --
--    Rev 1. The FIFO Generator is a parameterizable first-in/first-out       --
--    memory queue generator. Use it to generate resource and performance     --
--    optimized FIFOs with common or independent read/write clock domains,    --
--    and optional fixed or programmable full and empty flags and             --
--    handshaking signals.  Choose from a selection of memory resource        --
--    types for implementation.  Optional Hamming code based error            --
--    detection and correction as well as error injection capability for      --
--    system test help to insure data integrity.  FIFO width and depth are    --
--    parameterizable, and for native interface FIFOs, asymmetric read and    --
--    write port widths are also supported.                                   --
--------------------------------------------------------------------------------

-- Interfaces:
--    AXI4Stream_MASTER_M_AXIS
--    AXI4Stream_SLAVE_S_AXIS
--    AXI4_MASTER_M_AXI
--    AXI4_SLAVE_S_AXI
--    AXI4Lite_MASTER_M_AXI
--    AXI4Lite_SLAVE_S_AXI
--    master_aclk
--    slave_aclk
--    slave_aresetn

-- The following code must appear in the VHDL architecture header:

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT pgp2_s6_afifo_36x512
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(35 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(8 DOWNTO 0)
  );
END COMPONENT;
-- COMP_TAG_END ------ End COMPONENT Declaration ------------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
your_instance_name : pgp2_s6_afifo_36x512
  PORT MAP (
    rst => rst,
    wr_clk => wr_clk,
    rd_clk => rd_clk,
    din => din,
    wr_en => wr_en,
    rd_en => rd_en,
    dout => dout,
    full => full,
    empty => empty,
    wr_data_count => wr_data_count
  );
-- INST_TAG_END ------ End INSTANTIATION Template ------------

-- You must compile the wrapper file pgp2_s6_afifo_36x512.vhd when simulating
-- the core, pgp2_s6_afifo_36x512. When compiling the wrapper file, be sure to
-- reference the XilinxCoreLib VHDL simulation library. For detailed
-- instructions, please refer to the "CORE Generator Help".

