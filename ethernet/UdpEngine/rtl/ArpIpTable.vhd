library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

entity ArpIpTable is

  generic (
    TPD_G     : time     := 1 ns;
    ENTRIES_G : positive := 4);
  port (
    -- Clock and Reset
    clk       : in  sl;
    rst       : in  sl;
    -- Read LUT
    ipAddr    : in  slv(31 downto 0);
    pos       : out slv(31 downto 0);
    found     : out sl;
    macAddr   : out slv(47 downto 0);
    -- Write LUT
    ipWrEn    : in  sl;
    IpWrAddr  : in  slv(31 downto 0);
    macWrEn   : in  sl;
    macWrAddr : in  slv(47 downto 0));
end entity ArpIpTable;

architecture rtl of ArpIpTable is

  type wRegType is record
    ipLutTable  : Slv32Array(ENTRIES_G-1 downto 0);
    macLutTable : Slv48Array(ENTRIES_G-1 downto 0);
    entryCount  : slv(15 downto 0);
  end record wRegType;

  constant W_REG_INIT_C : wRegType := (
    ipLutTable  => (others => (others => '0')),
    -- ipLutTable  => (0 => x"0B02A8C0", 1 => (others => '1')),
    macLutTable => (others => (others => '0')),
    -- macLutTable => (0 => x"020300564400", 1 => (others => '1')),
    entryCount  => (others => '0')
    );

  signal wR   : wRegType := W_REG_INIT_C;
  signal wRin : wRegType;

  signal matchArray : slv(ENTRIES_G-1 downto 0);

begin  -- architecture rtl

  -- Write process comb
  wrComb : process (ipWrAddr, ipWrEn, macWrAddr, macWrEn, rst, wR) is
    variable v        : wRegType;
    variable wrAddInt : integer;
  begin
    -- Latch the current value
    v := wR;

    -- Write IP to LUT
    if ipWrEn = '1' then
      wrAddInt := conv_integer(wR.entryCount);
      if wrAddInt < ENTRIES_G then
        v.ipLutTable(wrAddInt) := ipWrAddr;
      end if;

      -- Update write LUT pointer
      if wr.entryCount < ENTRIES_G - 1 then
        v.entryCount := wr.entryCount + 1;
      else
        v.entryCount := (others => '0');
      end if;
    end if;

    -- Write MAC to LUT
    if macWrEn = '1' then
      wrAddInt := conv_integer(wR.entryCount);
      if wrAddInt < ENTRIES_G then
        v.macLutTable(wrAddInt) := macWrAddr;
      end if;
    end if;

    -- Reset
    if (rst = '1') then
      v := W_REG_INIT_C;
    end if;

    -- Register the variable for next clock cycle
    wRin <= v;

  end process wrComb;

  wrSeq : process (clk) is
  begin
    if rising_edge(clk) then
      wR <= wRin after TPD_G;
    end if;
  end process wrSeq;

  -- Read process
  -- Check for a match
  gen_compare : for i in 0 to ENTRIES_G-1 generate
    matchArray(i) <= '1' when (wR.ipLutTable(i) = ipAddr) else '0';
  end generate;

  -- Encode the position based on the match_array
  process(matchArray, wR.macLutTable)
    variable posI    : integer;
    variable ipFound : sl := '0';
  begin
    ipFound := '0';
    posI    := 0;                       -- Default value if no match is found
    for i in 0 to ENTRIES_G-1 loop
      if matchArray(i) = '1' then
        posI    := i;
        ipFound := '1';
        exit;                           -- Exit as soon as a match is found
      end if;
    end loop;
    found   <= ipFound;
    pos     <= conv_std_logic_vector(posI, 32);
    macAddr <= wR.macLutTable(posI);
  end process;

end architecture rtl;
