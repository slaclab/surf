//
// Verilog description for cell SaciSlave2, 
// Thu Jul 11 11:04:26 2013
//
// LeonardoSpectrum Level 3, 2011a.4 
//


module SaciSlave2 ( rstL, saciClk, saciSelL, saciCmd, saciRsp, rstOutL, rstInL, 
                    exec, ack, readL, cmd, addr, wrData, rdData ) ;

    input rstL ;
    input saciClk ;
    input saciSelL ;
    input saciCmd ;
    output saciRsp ;
    output rstOutL ;
    input rstInL ;
    output exec ;
    input ack ;
    output readL ;
    output [6:0]cmd ;
    output [11:0]addr ;
    output [31:0]wrData ;
    input [31:0]rdData ;

    wire r_shiftReg_0, saciCmdFall, NOT_saciClk, nx24, r_shiftReg_52, nx38, nx46, 
         nx54, nx60, nx72, nx84, nx96, nx108, nx120, nx132, nx144, nx156, nx168, 
         nx180, nx192, nx204, nx216, nx228, nx240, nx252, nx264, nx276, nx288, 
         nx300, nx312, nx324, nx336, nx348, nx360, nx372, nx384, nx396, nx408, 
         nx420, nx432, nx480, nx488, r_shiftReg_53, nx1695, nx1705, nx1715, 
         nx1725, nx1735, nx1745, nx1755, nx1765, nx1775, nx1785, nx1795, nx1805, 
         nx1815, nx1825, nx1835, nx1845, nx1855, nx1865, nx1875, nx1885, nx1895, 
         nx1905, nx1915, nx1925, nx1935, nx1947, nx1992, nx1999, nx2003, nx2014, 
         nx2018, nx2020, nx2024, nx2026, nx2030, nx2032, nx2036, nx2038, nx2042, 
         nx2044, nx2048, nx2050, nx2054, nx2056, nx2060, nx2062, nx2066, nx2068, 
         nx2072, nx2074, nx2078, nx2080, nx2084, nx2086, nx2090, nx2092, nx2096, 
         nx2098, nx2102, nx2104, nx2108, nx2110, nx2114, nx2116, nx2120, nx2122, 
         nx2126, nx2128, nx2132, nx2134, nx2138, nx2140, nx2144, nx2146, nx2150, 
         nx2152, nx2156, nx2158, nx2162, nx2164, nx2168, nx2170, nx2174, nx2176, 
         nx2180, nx2182, nx2186, nx2188, nx2192, nx2194, nx2197, nx2249, nx2250, 
         nx2258, nx2271, nx2273, nx2275, nx2277, nx2279, nx2281, nx2283, nx2285, 
         nx2287, nx2289, nx2291, nx2293, nx2295, nx2297, nx2299, r_state, nx2012, 
         nx8, nx2013, r_state_XX0_XREP7, nx2012_XX0_XREP7, nx8_XX0_XREP9;
    wire [55:0] \$dummy ;




    DFFC reg_r_shiftReg_1 (.Q (wrData[0]), .QB (\$dummy [0]), .D (nx60), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix61 (.OUT (nx60), .A (nx1947), .B (nx2250)) ;
    AOI22 ix1948 (.OUT (nx1947), .A (rdData[0]), .B (nx2297), .C (wrData[0]), .D (
          nx46)) ;
    Nor3 ix55 (.OUT (nx54), .A (r_shiftReg_52), .B (nx2003), .C (
         nx2012_XX0_XREP7)) ;
    DFFC reg_r_shiftReg_52 (.Q (r_shiftReg_52), .QB (nx2249), .D (nx1895), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1896 (.OUT (nx1895), .A (cmd[6]), .B (r_shiftReg_52), .SEL (nx2275)
         ) ;
    DFFC reg_r_shiftReg_51 (.Q (cmd[6]), .QB (\$dummy [1]), .D (nx1885), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1886 (.OUT (nx1885), .A (cmd[5]), .B (cmd[6]), .SEL (nx2275)) ;
    DFFC reg_r_shiftReg_50 (.Q (cmd[5]), .QB (\$dummy [2]), .D (nx1875), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1876 (.OUT (nx1875), .A (cmd[4]), .B (cmd[5]), .SEL (nx2275)) ;
    DFFC reg_r_shiftReg_49 (.Q (cmd[4]), .QB (\$dummy [3]), .D (nx1865), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1866 (.OUT (nx1865), .A (cmd[3]), .B (cmd[4]), .SEL (nx2275)) ;
    DFFC reg_r_shiftReg_48 (.Q (cmd[3]), .QB (\$dummy [4]), .D (nx1855), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1856 (.OUT (nx1855), .A (cmd[2]), .B (cmd[3]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_47 (.Q (cmd[2]), .QB (\$dummy [5]), .D (nx1845), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1846 (.OUT (nx1845), .A (cmd[1]), .B (cmd[2]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_46 (.Q (cmd[1]), .QB (\$dummy [6]), .D (nx1835), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1836 (.OUT (nx1835), .A (cmd[0]), .B (cmd[1]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_45 (.Q (cmd[0]), .QB (\$dummy [7]), .D (nx1825), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1826 (.OUT (nx1825), .A (addr[11]), .B (cmd[0]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_44 (.Q (addr[11]), .QB (\$dummy [8]), .D (nx1815), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1816 (.OUT (nx1815), .A (addr[10]), .B (addr[11]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_43 (.Q (addr[10]), .QB (\$dummy [9]), .D (nx1805), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1806 (.OUT (nx1805), .A (addr[9]), .B (addr[10]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_42 (.Q (addr[9]), .QB (\$dummy [10]), .D (nx1795), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1796 (.OUT (nx1795), .A (addr[8]), .B (addr[9]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_41 (.Q (addr[8]), .QB (\$dummy [11]), .D (nx1785), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1786 (.OUT (nx1785), .A (addr[7]), .B (addr[8]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_40 (.Q (addr[7]), .QB (\$dummy [12]), .D (nx1775), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1776 (.OUT (nx1775), .A (addr[6]), .B (addr[7]), .SEL (nx2273)) ;
    DFFC reg_r_shiftReg_39 (.Q (addr[6]), .QB (\$dummy [13]), .D (nx1765), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1766 (.OUT (nx1765), .A (addr[5]), .B (addr[6]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_38 (.Q (addr[5]), .QB (\$dummy [14]), .D (nx1755), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1756 (.OUT (nx1755), .A (addr[4]), .B (addr[5]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_37 (.Q (addr[4]), .QB (\$dummy [15]), .D (nx1745), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1746 (.OUT (nx1745), .A (addr[3]), .B (addr[4]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_36 (.Q (addr[3]), .QB (\$dummy [16]), .D (nx1735), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1736 (.OUT (nx1735), .A (addr[2]), .B (addr[3]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_35 (.Q (addr[2]), .QB (\$dummy [17]), .D (nx1725), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1726 (.OUT (nx1725), .A (addr[1]), .B (addr[2]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_34 (.Q (addr[1]), .QB (\$dummy [18]), .D (nx1715), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1716 (.OUT (nx1715), .A (addr[0]), .B (addr[1]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_33 (.Q (addr[0]), .QB (\$dummy [19]), .D (nx1705), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1706 (.OUT (nx1705), .A (wrData[31]), .B (addr[0]), .SEL (nx2299)) ;
    DFFC reg_r_shiftReg_32 (.Q (wrData[31]), .QB (\$dummy [20]), .D (nx432), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix433 (.OUT (nx432), .A (nx1992), .B (nx2014)) ;
    AOI22 ix1993 (.OUT (nx1992), .A (rdData[31]), .B (nx2291), .C (wrData[31]), 
          .D (nx2285)) ;
    Nor2 ix47 (.OUT (nx46), .A (ack), .B (nx2299)) ;
    Nor2 ix481 (.OUT (nx480), .A (ack), .B (nx1999)) ;
    Nor2 ix2000 (.OUT (nx1999), .A (exec), .B (r_shiftReg_52)) ;
    Inv ix2004 (.OUT (nx2003), .A (ack)) ;
    DFFC reg_r_shiftReg_0 (.Q (r_shiftReg_0), .QB (\$dummy [21]), .D (nx1695), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1696 (.OUT (nx1695), .A (saciCmdFall), .B (r_shiftReg_0), .SEL (
         nx2299)) ;
    DFFC reg_saciCmdFall (.Q (saciCmdFall), .QB (\$dummy [22]), .D (saciCmd), .CLK (
         NOT_saciClk), .CLR (rstInL)) ;
    Inv ix2009 (.OUT (NOT_saciClk), .A (saciClk)) ;
    Nand2 ix2015 (.OUT (nx2014), .A (wrData[30]), .B (nx2283)) ;
    DFFC reg_r_shiftReg_31 (.Q (wrData[30]), .QB (\$dummy [23]), .D (nx420), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix421 (.OUT (nx420), .A (nx2018), .B (nx2020)) ;
    AOI22 ix2019 (.OUT (nx2018), .A (rdData[30]), .B (nx2291), .C (wrData[30]), 
          .D (nx2285)) ;
    Nand2 ix2021 (.OUT (nx2020), .A (wrData[29]), .B (nx2283)) ;
    DFFC reg_r_shiftReg_30 (.Q (wrData[29]), .QB (\$dummy [24]), .D (nx408), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix409 (.OUT (nx408), .A (nx2024), .B (nx2026)) ;
    AOI22 ix2025 (.OUT (nx2024), .A (rdData[29]), .B (nx2291), .C (wrData[29]), 
          .D (nx2285)) ;
    Nand2 ix2027 (.OUT (nx2026), .A (wrData[28]), .B (nx2283)) ;
    DFFC reg_r_shiftReg_29 (.Q (wrData[28]), .QB (\$dummy [25]), .D (nx396), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix397 (.OUT (nx396), .A (nx2030), .B (nx2032)) ;
    AOI22 ix2031 (.OUT (nx2030), .A (rdData[28]), .B (nx2291), .C (wrData[28]), 
          .D (nx2285)) ;
    Nand2 ix2033 (.OUT (nx2032), .A (wrData[27]), .B (nx2283)) ;
    DFFC reg_r_shiftReg_28 (.Q (wrData[27]), .QB (\$dummy [26]), .D (nx384), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix385 (.OUT (nx384), .A (nx2036), .B (nx2038)) ;
    AOI22 ix2037 (.OUT (nx2036), .A (rdData[27]), .B (nx2291), .C (wrData[27]), 
          .D (nx2285)) ;
    Nand2 ix2039 (.OUT (nx2038), .A (wrData[26]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_27 (.Q (wrData[26]), .QB (\$dummy [27]), .D (nx372), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix373 (.OUT (nx372), .A (nx2042), .B (nx2044)) ;
    AOI22 ix2043 (.OUT (nx2042), .A (rdData[26]), .B (nx2291), .C (wrData[26]), 
          .D (nx2285)) ;
    Nand2 ix2045 (.OUT (nx2044), .A (wrData[25]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_26 (.Q (wrData[25]), .QB (\$dummy [28]), .D (nx360), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix361 (.OUT (nx360), .A (nx2048), .B (nx2050)) ;
    AOI22 ix2049 (.OUT (nx2048), .A (rdData[25]), .B (nx2291), .C (wrData[25]), 
          .D (nx2285)) ;
    Nand2 ix2051 (.OUT (nx2050), .A (wrData[24]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_25 (.Q (wrData[24]), .QB (\$dummy [29]), .D (nx348), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix349 (.OUT (nx348), .A (nx2054), .B (nx2056)) ;
    AOI22 ix2055 (.OUT (nx2054), .A (rdData[24]), .B (nx2291), .C (wrData[24]), 
          .D (nx2285)) ;
    Nand2 ix2057 (.OUT (nx2056), .A (wrData[23]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_24 (.Q (wrData[23]), .QB (\$dummy [30]), .D (nx336), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix337 (.OUT (nx336), .A (nx2060), .B (nx2062)) ;
    AOI22 ix2061 (.OUT (nx2060), .A (rdData[23]), .B (nx2291), .C (wrData[23]), 
          .D (nx2285)) ;
    Nand2 ix2063 (.OUT (nx2062), .A (wrData[22]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_23 (.Q (wrData[22]), .QB (\$dummy [31]), .D (nx324), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix325 (.OUT (nx324), .A (nx2066), .B (nx2068)) ;
    AOI22 ix2067 (.OUT (nx2066), .A (rdData[22]), .B (nx2293), .C (wrData[22]), 
          .D (nx2287)) ;
    Nand2 ix2069 (.OUT (nx2068), .A (wrData[21]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_22 (.Q (wrData[21]), .QB (\$dummy [32]), .D (nx312), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix313 (.OUT (nx312), .A (nx2072), .B (nx2074)) ;
    AOI22 ix2073 (.OUT (nx2072), .A (rdData[21]), .B (nx2293), .C (wrData[21]), 
          .D (nx2287)) ;
    Nand2 ix2075 (.OUT (nx2074), .A (wrData[20]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_21 (.Q (wrData[20]), .QB (\$dummy [33]), .D (nx300), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix301 (.OUT (nx300), .A (nx2078), .B (nx2080)) ;
    AOI22 ix2079 (.OUT (nx2078), .A (rdData[20]), .B (nx2293), .C (wrData[20]), 
          .D (nx2287)) ;
    Nand2 ix2081 (.OUT (nx2080), .A (wrData[19]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_20 (.Q (wrData[19]), .QB (\$dummy [34]), .D (nx288), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix289 (.OUT (nx288), .A (nx2084), .B (nx2086)) ;
    AOI22 ix2085 (.OUT (nx2084), .A (rdData[19]), .B (nx2293), .C (wrData[19]), 
          .D (nx2287)) ;
    Nand2 ix2087 (.OUT (nx2086), .A (wrData[18]), .B (nx2281)) ;
    DFFC reg_r_shiftReg_19 (.Q (wrData[18]), .QB (\$dummy [35]), .D (nx276), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix277 (.OUT (nx276), .A (nx2090), .B (nx2092)) ;
    AOI22 ix2091 (.OUT (nx2090), .A (rdData[18]), .B (nx2293), .C (wrData[18]), 
          .D (nx2287)) ;
    Nand2 ix2093 (.OUT (nx2092), .A (wrData[17]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_18 (.Q (wrData[17]), .QB (\$dummy [36]), .D (nx264), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix265 (.OUT (nx264), .A (nx2096), .B (nx2098)) ;
    AOI22 ix2097 (.OUT (nx2096), .A (rdData[17]), .B (nx2293), .C (wrData[17]), 
          .D (nx2287)) ;
    Nand2 ix2099 (.OUT (nx2098), .A (wrData[16]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_17 (.Q (wrData[16]), .QB (\$dummy [37]), .D (nx252), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix253 (.OUT (nx252), .A (nx2102), .B (nx2104)) ;
    AOI22 ix2103 (.OUT (nx2102), .A (rdData[16]), .B (nx2293), .C (wrData[16]), 
          .D (nx2287)) ;
    Nand2 ix2105 (.OUT (nx2104), .A (wrData[15]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_16 (.Q (wrData[15]), .QB (\$dummy [38]), .D (nx240), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix241 (.OUT (nx240), .A (nx2108), .B (nx2110)) ;
    AOI22 ix2109 (.OUT (nx2108), .A (rdData[15]), .B (nx2293), .C (wrData[15]), 
          .D (nx2287)) ;
    Nand2 ix2111 (.OUT (nx2110), .A (wrData[14]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_15 (.Q (wrData[14]), .QB (\$dummy [39]), .D (nx228), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix229 (.OUT (nx228), .A (nx2114), .B (nx2116)) ;
    AOI22 ix2115 (.OUT (nx2114), .A (rdData[14]), .B (nx2293), .C (wrData[14]), 
          .D (nx2287)) ;
    Nand2 ix2117 (.OUT (nx2116), .A (wrData[13]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_14 (.Q (wrData[13]), .QB (\$dummy [40]), .D (nx216), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix217 (.OUT (nx216), .A (nx2120), .B (nx2122)) ;
    AOI22 ix2121 (.OUT (nx2120), .A (rdData[13]), .B (nx2295), .C (wrData[13]), 
          .D (nx2289)) ;
    Nand2 ix2123 (.OUT (nx2122), .A (wrData[12]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_13 (.Q (wrData[12]), .QB (\$dummy [41]), .D (nx204), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix205 (.OUT (nx204), .A (nx2126), .B (nx2128)) ;
    AOI22 ix2127 (.OUT (nx2126), .A (rdData[12]), .B (nx2295), .C (wrData[12]), 
          .D (nx2289)) ;
    Nand2 ix2129 (.OUT (nx2128), .A (wrData[11]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_12 (.Q (wrData[11]), .QB (\$dummy [42]), .D (nx192), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix193 (.OUT (nx192), .A (nx2132), .B (nx2134)) ;
    AOI22 ix2133 (.OUT (nx2132), .A (rdData[11]), .B (nx2295), .C (wrData[11]), 
          .D (nx2289)) ;
    Nand2 ix2135 (.OUT (nx2134), .A (wrData[10]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_11 (.Q (wrData[10]), .QB (\$dummy [43]), .D (nx180), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix181 (.OUT (nx180), .A (nx2138), .B (nx2140)) ;
    AOI22 ix2139 (.OUT (nx2138), .A (rdData[10]), .B (nx2295), .C (wrData[10]), 
          .D (nx2289)) ;
    Nand2 ix2141 (.OUT (nx2140), .A (wrData[9]), .B (nx2279)) ;
    DFFC reg_r_shiftReg_10 (.Q (wrData[9]), .QB (\$dummy [44]), .D (nx168), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix169 (.OUT (nx168), .A (nx2144), .B (nx2146)) ;
    AOI22 ix2145 (.OUT (nx2144), .A (rdData[9]), .B (nx2295), .C (wrData[9]), .D (
          nx2289)) ;
    Nand2 ix2147 (.OUT (nx2146), .A (wrData[8]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_9 (.Q (wrData[8]), .QB (\$dummy [45]), .D (nx156), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix157 (.OUT (nx156), .A (nx2150), .B (nx2152)) ;
    AOI22 ix2151 (.OUT (nx2150), .A (rdData[8]), .B (nx2295), .C (wrData[8]), .D (
          nx2289)) ;
    Nand2 ix2153 (.OUT (nx2152), .A (wrData[7]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_8 (.Q (wrData[7]), .QB (\$dummy [46]), .D (nx144), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix145 (.OUT (nx144), .A (nx2156), .B (nx2158)) ;
    AOI22 ix2157 (.OUT (nx2156), .A (rdData[7]), .B (nx2295), .C (wrData[7]), .D (
          nx2289)) ;
    Nand2 ix2159 (.OUT (nx2158), .A (wrData[6]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_7 (.Q (wrData[6]), .QB (\$dummy [47]), .D (nx132), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix133 (.OUT (nx132), .A (nx2162), .B (nx2164)) ;
    AOI22 ix2163 (.OUT (nx2162), .A (rdData[6]), .B (nx2295), .C (wrData[6]), .D (
          nx2289)) ;
    Nand2 ix2165 (.OUT (nx2164), .A (wrData[5]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_6 (.Q (wrData[5]), .QB (\$dummy [48]), .D (nx120), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix121 (.OUT (nx120), .A (nx2168), .B (nx2170)) ;
    AOI22 ix2169 (.OUT (nx2168), .A (rdData[5]), .B (nx2295), .C (wrData[5]), .D (
          nx2289)) ;
    Nand2 ix2171 (.OUT (nx2170), .A (wrData[4]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_5 (.Q (wrData[4]), .QB (\$dummy [49]), .D (nx108), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix109 (.OUT (nx108), .A (nx2174), .B (nx2176)) ;
    AOI22 ix2175 (.OUT (nx2174), .A (rdData[4]), .B (nx2297), .C (wrData[4]), .D (
          nx46)) ;
    Nand2 ix2177 (.OUT (nx2176), .A (wrData[3]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_4 (.Q (wrData[3]), .QB (\$dummy [50]), .D (nx96), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix97 (.OUT (nx96), .A (nx2180), .B (nx2182)) ;
    AOI22 ix2181 (.OUT (nx2180), .A (rdData[3]), .B (nx2297), .C (wrData[3]), .D (
          nx46)) ;
    Nand2 ix2183 (.OUT (nx2182), .A (wrData[2]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_3 (.Q (wrData[2]), .QB (\$dummy [51]), .D (nx84), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix85 (.OUT (nx84), .A (nx2186), .B (nx2188)) ;
    AOI22 ix2187 (.OUT (nx2186), .A (rdData[2]), .B (nx2297), .C (wrData[2]), .D (
          nx46)) ;
    Nand2 ix2189 (.OUT (nx2188), .A (wrData[1]), .B (nx2277)) ;
    DFFC reg_r_shiftReg_2 (.Q (wrData[1]), .QB (\$dummy [52]), .D (nx72), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix73 (.OUT (nx72), .A (nx2192), .B (nx2194)) ;
    AOI22 ix2193 (.OUT (nx2192), .A (rdData[1]), .B (nx2297), .C (wrData[1]), .D (
          nx46)) ;
    Nand2 ix2195 (.OUT (nx2194), .A (wrData[0]), .B (nx2277)) ;
    Nand2 ix39 (.OUT (nx38), .A (nx2197), .B (r_state)) ;
    Nand3 ix2198 (.OUT (nx2197), .A (nx2013), .B (nx2003), .C (r_state_XX0_XREP7
          )) ;
    Nand2 ix2251 (.OUT (nx2250), .A (r_shiftReg_0), .B (nx2283)) ;
    DFFC reg_r_readL (.Q (readL), .QB (\$dummy [53]), .D (nx1915), .CLK (saciClk
         ), .CLR (rstInL)) ;
    Mux2 ix1916 (.OUT (nx1915), .A (cmd[6]), .B (readL), .SEL (nx488)) ;
    Nor3 ix489 (.OUT (nx488), .A (exec), .B (nx2012_XX0_XREP7), .C (nx2249)) ;
    Nor2 ix499 (.OUT (rstOutL), .A (nx2258), .B (saciSelL)) ;
    Inv ix2259 (.OUT (nx2258), .A (rstL)) ;
    DFFC reg_r_shiftReg_54 (.Q (saciRsp), .QB (\$dummy [54]), .D (nx1935), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix1936 (.OUT (nx1935), .A (r_shiftReg_53), .B (saciRsp), .SEL (nx2275)
         ) ;
    DFFC reg_r_shiftReg_53 (.Q (r_shiftReg_53), .QB (\$dummy [55]), .D (nx1925)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Mux2 ix1926 (.OUT (nx1925), .A (r_shiftReg_52), .B (r_shiftReg_53), .SEL (
         nx2275)) ;
    Buf1 ix2270 (.OUT (nx2271), .A (nx8)) ;
    Buf1 ix2272 (.OUT (nx2273), .A (nx8_XX0_XREP9)) ;
    Buf1 ix2274 (.OUT (nx2275), .A (nx8)) ;
    Buf1 ix2276 (.OUT (nx2277), .A (nx38)) ;
    Buf1 ix2278 (.OUT (nx2279), .A (nx38)) ;
    Buf1 ix2280 (.OUT (nx2281), .A (nx38)) ;
    Buf1 ix2282 (.OUT (nx2283), .A (nx38)) ;
    Nor2 ix2284 (.OUT (nx2285), .A (ack), .B (nx2271)) ;
    Nor2 ix2286 (.OUT (nx2287), .A (ack), .B (nx2271)) ;
    Nor2 ix2288 (.OUT (nx2289), .A (ack), .B (nx2271)) ;
    Buf1 ix2290 (.OUT (nx2291), .A (nx54)) ;
    Buf1 ix2292 (.OUT (nx2293), .A (nx54)) ;
    Buf1 ix2294 (.OUT (nx2295), .A (nx54)) ;
    Buf1 ix2296 (.OUT (nx2297), .A (nx54)) ;
    Buf1 ix2298 (.OUT (nx2299), .A (nx8_XX0_XREP9)) ;
    Mux2 ix1906 (.OUT (nx1905), .A (exec), .B (nx480), .SEL (nx2012)) ;
    Mux2 ix25 (.OUT (nx24), .A (r_shiftReg_0), .B (nx2003), .SEL (nx2012)) ;
    DFFC reg_r_state (.Q (r_state), .QB (nx2012), .D (nx24), .CLK (saciClk), .CLR (
         rstInL)) ;
    Nand2 ix9 (.OUT (nx8), .A (exec), .B (r_state_XX0_XREP7)) ;
    DFFC reg_r_exec (.Q (exec), .QB (nx2013), .D (nx1905), .CLK (saciClk), .CLR (
         rstInL)) ;
    DFFC reg_r_state_0_XREP7 (.Q (r_state_XX0_XREP7), .QB (nx2012_XX0_XREP7), .D (
         nx24), .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix9_0_XREP9 (.OUT (nx8_XX0_XREP9), .A (exec), .B (r_state_XX0_XREP7)
          ) ;
endmodule

