LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000001"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "XauiGtx7Dcp: Vivado v2014.4 (x86_64) Built Tue Apr  7 14:35:47 PDT 2015 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 12/05/2014 (0x00000001): Initial Build
--
-------------------------------------------------------------------------------

