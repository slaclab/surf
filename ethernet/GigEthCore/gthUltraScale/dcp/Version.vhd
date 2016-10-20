LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000002"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "GigEthGthUltraScaleDcp: Vivado v2016.1 (x86_64) Built Fri Jul  1 14:25:53 PDT 2016 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 02/09/2016 (0x00000001): Initial Build
-- 07/01/2016 (0x00000002): Upgraded to Vivado 2016.1 IP core
--
-------------------------------------------------------------------------------

