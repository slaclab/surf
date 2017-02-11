LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000001"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "SaltUltraScaleTxOnly: Vivado v2015.3 (x86_64) Built Fri Feb 10 18:02:49 PST 2017 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 12/05/2014 (0x00000001): Initial Build
--
-------------------------------------------------------------------------------

