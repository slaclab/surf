//
// Verilog description for cell SaciSlave, 
// Fri Aug 22 13:04:53 2014
//
// LeonardoSpectrum Level 3, 2011a.4 
//


module SaciSlave ( rstL, saciClk, saciSelL, saciCmd, saciRsp, rstOutL, rstInL, 
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

    wire r_state_2, r_shiftCount_2, r_shiftCount_1, nx8, saciCmdFall, 
         NOT_saciClk, nx22, nx34, nx46, nx58, nx70, nx82, nx94, nx106, nx118, 
         nx130, nx142, nx154, nx166, nx178, nx190, nx202, nx214, nx226, nx238, 
         nx1448, r_shiftCount_5, r_shiftCount_4, nx1449, nx1450, nx254, nx264, 
         nx272, nx278, nx284, nx286, nx294, nx306, r_shiftCount_0, nx342, nx348, 
         nx352, nx372, nx376, nx386, nx400, nx414, nx430, nx458, nx462, nx466, 
         nx470, r_headerShiftReg_20, r_headerShiftReg_19, nx482, nx494, nx514, 
         nx522, nx536, nx550, nx564, nx578, nx592, nx606, nx620, nx634, nx648, 
         nx662, nx676, nx690, nx704, nx718, nx732, nx746, nx760, nx774, nx788, 
         nx802, nx816, nx830, nx844, nx858, nx872, nx886, nx900, nx914, nx928, 
         nx942, nx956, nx966, nx1460, nx1467, nx1470, nx1474, nx1493, nx1499, 
         nx1502, nx1505, nx1508, nx1511, nx1514, nx1517, nx1520, nx1523, nx1530, 
         nx1536, nx1540, nx1545, nx1550, nx1557, nx1560, nx1601, nx1623, nx1627, 
         nx1630, nx1633, nx1636, nx1645, nx1650, nx1652, nx1657, nx1659, nx1664, 
         nx1666, nx1671, nx1673, nx1678, nx1680, nx1685, nx1687, nx1692, nx1694, 
         nx1699, nx1701, nx1706, nx1708, nx1713, nx1715, nx1720, nx1722, nx1727, 
         nx1729, nx1734, nx1736, nx1741, nx1743, nx1748, nx1750, nx1755, nx1757, 
         nx1762, nx1764, nx1769, nx1771, nx1776, nx1778, nx1783, nx1785, nx1790, 
         nx1792, nx1797, nx1799, nx1804, nx1806, nx1811, nx1813, nx1818, nx1820, 
         nx1825, nx1827, nx1832, nx1834, nx1839, nx1841, nx1846, nx1848, nx1853, 
         nx1855, nx1860, nx1862, nx1864, nx1868, nx1872, nx1874, nx1887, nx1889, 
         nx1891, nx1893, nx1895, nx1897, nx1899, nx1901, nx1903, nx1905, nx1907, 
         nx1909, nx1911, nx1913, nx1444, r_state_0, nx1483, nx246, 
         r_shiftCount_3, nx1496, nx1542, r_state_1, nx1477, nx444, 
         r_state_1__XX0_XREP25, nx1477_XX0_XREP25, nx1974, nx1975, nx1976, 
         nx1977, nx1978, nx1979, nx1980, nx1981, nx1982, nx1983, nx1984, nx1985, 
         nx1986, nx1987, nx324, nx1988, nx1989, nx1990, nx360, nx1480, nx1991, 
         nx1992, nx1993, nx1643, nx1994, nx1995, nx1996, nx1997, nx1640, nx1445, 
         nx1465;
    wire [51:0] \$dummy ;




    DFFC reg_r_dataShiftReg_0 (.Q (wrData[0]), .QB (\$dummy [0]), .D (nx522), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix523 (.OUT (nx522), .A (nx1460), .B (nx1645)) ;
    AOI22 ix1461 (.OUT (nx1460), .A (rdData[0]), .B (nx1901), .C (wrData[0]), .D (
          nx1907)) ;
    Nand2 ix471 (.OUT (nx470), .A (nx1470), .B (nx1640)) ;
    Nand2 ix1471 (.OUT (nx1470), .A (r_state_2), .B (nx466)) ;
    DFFC reg_r_state_2 (.Q (r_state_2), .QB (nx1467), .D (nx470), .CLK (saciClk)
         , .CLR (rstInL)) ;
    Nand2 ix467 (.OUT (nx466), .A (nx1474), .B (nx1480)) ;
    Nand2 ix1475 (.OUT (nx1474), .A (nx1444), .B (nx462)) ;
    Nor3 ix255 (.OUT (nx254), .A (nx1493), .B (nx1450), .C (nx1511)) ;
    Nor2 ix1494 (.OUT (nx1493), .A (nx246), .B (r_shiftCount_4)) ;
    Nor3 ix415 (.OUT (nx414), .A (nx1499), .B (nx246), .C (nx1511)) ;
    Nor2 ix1500 (.OUT (nx1499), .A (nx1449), .B (r_shiftCount_3)) ;
    Nor3 ix401 (.OUT (nx400), .A (nx1505), .B (nx1449), .C (nx1511)) ;
    Nor2 ix1506 (.OUT (nx1505), .A (nx1448), .B (r_shiftCount_2)) ;
    Nor2 ix393 (.OUT (nx1448), .A (nx1508), .B (nx1530)) ;
    Nor3 ix387 (.OUT (nx386), .A (nx1511), .B (nx1448), .C (nx1540)) ;
    Nor3 ix1512 (.OUT (nx1511), .A (nx376), .B (nx372), .C (nx1887)) ;
    Nor2 ix377 (.OUT (nx376), .A (nx1514), .B (nx284)) ;
    Nor2 ix265 (.OUT (nx264), .A (nx1520), .B (nx1511)) ;
    DFFC reg_r_shiftCount_5 (.Q (r_shiftCount_5), .QB (nx1517), .D (nx264), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix1524 (.OUT (nx1523), .A (r_shiftCount_4), .B (nx246)) ;
    DFFC reg_r_shiftCount_1 (.Q (r_shiftCount_1), .QB (nx1508), .D (nx386), .CLK (
         saciClk), .CLR (rstInL)) ;
    DFFC reg_r_shiftCount_0 (.Q (r_shiftCount_0), .QB (nx1530), .D (nx342), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nor2 ix343 (.OUT (nx342), .A (r_shiftCount_0), .B (nx1511)) ;
    DFFC reg_r_shiftCount_2 (.Q (r_shiftCount_2), .QB (nx1502), .D (nx400), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand3 ix285 (.OUT (nx284), .A (nx1477_XX0_XREP25), .B (nx1467), .C (
          r_state_0)) ;
    Nor3 ix373 (.OUT (nx372), .A (nx1536), .B (nx1477), .C (nx1445)) ;
    Nor4 ix1537 (.OUT (nx1536), .A (nx348), .B (nx272), .C (nx1502), .D (
         r_shiftCount_3)) ;
    Nor2 ix1541 (.OUT (nx1540), .A (r_shiftCount_0), .B (r_shiftCount_1)) ;
    DFFC reg_r_shiftCount_4 (.Q (r_shiftCount_4), .QB (nx1545), .D (nx254), .CLK (
         saciClk), .CLR (rstInL)) ;
    DFFC reg_saciCmdFall (.Q (saciCmdFall), .QB (nx1550), .D (saciCmd), .CLK (
         NOT_saciClk), .CLR (rstInL)) ;
    Inv ix1553 (.OUT (NOT_saciClk), .A (saciClk)) ;
    Nand2 ix307 (.OUT (nx306), .A (nx1560), .B (nx1514)) ;
    Mux2 ix239 (.OUT (nx238), .A (cmd[6]), .B (cmd[5]), .SEL (nx1899)) ;
    DFFC reg_r_headerShiftReg_18 (.Q (cmd[6]), .QB (nx1560), .D (nx238), .CLK (
         saciClk), .CLR (rstInL)) ;
    DFFC reg_r_headerShiftReg_17 (.Q (cmd[5]), .QB (\$dummy [1]), .D (nx226), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix227 (.OUT (nx226), .A (cmd[5]), .B (cmd[4]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_16 (.Q (cmd[4]), .QB (\$dummy [2]), .D (nx214), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix215 (.OUT (nx214), .A (cmd[4]), .B (cmd[3]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_15 (.Q (cmd[3]), .QB (\$dummy [3]), .D (nx202), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix203 (.OUT (nx202), .A (cmd[3]), .B (cmd[2]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_14 (.Q (cmd[2]), .QB (\$dummy [4]), .D (nx190), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix191 (.OUT (nx190), .A (cmd[2]), .B (cmd[1]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_13 (.Q (cmd[1]), .QB (\$dummy [5]), .D (nx178), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix179 (.OUT (nx178), .A (cmd[1]), .B (cmd[0]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_12 (.Q (cmd[0]), .QB (\$dummy [6]), .D (nx166), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix167 (.OUT (nx166), .A (cmd[0]), .B (addr[11]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_11 (.Q (addr[11]), .QB (\$dummy [7]), .D (nx154), 
         .CLK (saciClk), .CLR (rstInL)) ;
    Mux2 ix155 (.OUT (nx154), .A (addr[11]), .B (addr[10]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_10 (.Q (addr[10]), .QB (\$dummy [8]), .D (nx142), 
         .CLK (saciClk), .CLR (rstInL)) ;
    Mux2 ix143 (.OUT (nx142), .A (addr[10]), .B (addr[9]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_9 (.Q (addr[9]), .QB (\$dummy [9]), .D (nx130), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix131 (.OUT (nx130), .A (addr[9]), .B (addr[8]), .SEL (nx1897)) ;
    DFFC reg_r_headerShiftReg_8 (.Q (addr[8]), .QB (\$dummy [10]), .D (nx118), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix119 (.OUT (nx118), .A (addr[8]), .B (addr[7]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_7 (.Q (addr[7]), .QB (\$dummy [11]), .D (nx106), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix107 (.OUT (nx106), .A (addr[7]), .B (addr[6]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_6 (.Q (addr[6]), .QB (\$dummy [12]), .D (nx94), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix95 (.OUT (nx94), .A (addr[6]), .B (addr[5]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_5 (.Q (addr[5]), .QB (\$dummy [13]), .D (nx82), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix83 (.OUT (nx82), .A (addr[5]), .B (addr[4]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_4 (.Q (addr[4]), .QB (\$dummy [14]), .D (nx70), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix71 (.OUT (nx70), .A (addr[4]), .B (addr[3]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_3 (.Q (addr[3]), .QB (\$dummy [15]), .D (nx58), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix59 (.OUT (nx58), .A (addr[3]), .B (addr[2]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_2 (.Q (addr[2]), .QB (\$dummy [16]), .D (nx46), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix47 (.OUT (nx46), .A (addr[2]), .B (addr[1]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_1 (.Q (addr[1]), .QB (\$dummy [17]), .D (nx34), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix35 (.OUT (nx34), .A (addr[1]), .B (addr[0]), .SEL (nx1895)) ;
    DFFC reg_r_headerShiftReg_0 (.Q (addr[0]), .QB (\$dummy [18]), .D (nx22), .CLK (
         saciClk), .CLR (rstInL)) ;
    Mux2 ix23 (.OUT (nx22), .A (addr[0]), .B (saciCmdFall), .SEL (nx1895)) ;
    Nand2 ix9 (.OUT (nx8), .A (nx1601), .B (nx1465)) ;
    Mux2 ix295 (.OUT (nx294), .A (cmd[6]), .B (readL), .SEL (nx1627)) ;
    DFFC reg_r_writeFlag (.Q (readL), .QB (nx1623), .D (nx294), .CLK (saciClk), 
         .CLR (rstInL)) ;
    Nor2 ix1628 (.OUT (nx1627), .A (nx284), .B (nx278)) ;
    Nand4 ix279 (.OUT (nx278), .A (nx1630), .B (nx1448), .C (nx1502), .D (nx1496
          )) ;
    Nor2 ix1631 (.OUT (nx1630), .A (nx1545), .B (r_shiftCount_5)) ;
    Nand3 ix353 (.OUT (nx352), .A (nx1540), .B (nx1502), .C (nx1633)) ;
    Nor3 ix1634 (.OUT (nx1633), .A (r_shiftCount_4), .B (nx1517), .C (
         r_shiftCount_3)) ;
    AOI22 ix1637 (.OUT (nx1636), .A (nx1467), .B (r_state_1), .C (nx1444), .D (
          nx430)) ;
    Nand2 ix431 (.OUT (nx430), .A (readL), .B (nx1536)) ;
    Nand2 ix463 (.OUT (nx462), .A (readL), .B (nx1536)) ;
    Nand2 ix515 (.OUT (nx514), .A (nx1643), .B (nx284)) ;
    Nand2 ix1646 (.OUT (nx1645), .A (saciCmdFall), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_1 (.Q (wrData[1]), .QB (\$dummy [19]), .D (nx536), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix537 (.OUT (nx536), .A (nx1650), .B (nx1652)) ;
    AOI22 ix1651 (.OUT (nx1650), .A (rdData[1]), .B (nx1901), .C (wrData[1]), .D (
          nx1907)) ;
    Nand2 ix1653 (.OUT (nx1652), .A (wrData[0]), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_2 (.Q (wrData[2]), .QB (\$dummy [20]), .D (nx550), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix551 (.OUT (nx550), .A (nx1657), .B (nx1659)) ;
    AOI22 ix1658 (.OUT (nx1657), .A (rdData[2]), .B (nx1901), .C (wrData[2]), .D (
          nx1907)) ;
    Nand2 ix1660 (.OUT (nx1659), .A (wrData[1]), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_3 (.Q (wrData[3]), .QB (\$dummy [21]), .D (nx564), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix565 (.OUT (nx564), .A (nx1664), .B (nx1666)) ;
    AOI22 ix1665 (.OUT (nx1664), .A (rdData[3]), .B (nx1901), .C (wrData[3]), .D (
          nx1907)) ;
    Nand2 ix1667 (.OUT (nx1666), .A (wrData[2]), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_4 (.Q (wrData[4]), .QB (\$dummy [22]), .D (nx578), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix579 (.OUT (nx578), .A (nx1671), .B (nx1673)) ;
    AOI22 ix1672 (.OUT (nx1671), .A (rdData[4]), .B (nx1901), .C (wrData[4]), .D (
          nx1907)) ;
    Nand2 ix1674 (.OUT (nx1673), .A (wrData[3]), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_5 (.Q (wrData[5]), .QB (\$dummy [23]), .D (nx592), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix593 (.OUT (nx592), .A (nx1678), .B (nx1680)) ;
    AOI22 ix1679 (.OUT (nx1678), .A (rdData[5]), .B (nx1901), .C (wrData[5]), .D (
          nx1907)) ;
    Nand2 ix1681 (.OUT (nx1680), .A (wrData[4]), .B (nx1887)) ;
    DFFC reg_r_dataShiftReg_6 (.Q (wrData[6]), .QB (\$dummy [24]), .D (nx606), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix607 (.OUT (nx606), .A (nx1685), .B (nx1687)) ;
    AOI22 ix1686 (.OUT (nx1685), .A (rdData[6]), .B (nx1901), .C (wrData[6]), .D (
          nx1907)) ;
    Nand2 ix1688 (.OUT (nx1687), .A (wrData[5]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_7 (.Q (wrData[7]), .QB (\$dummy [25]), .D (nx620), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix621 (.OUT (nx620), .A (nx1692), .B (nx1694)) ;
    AOI22 ix1693 (.OUT (nx1692), .A (rdData[7]), .B (nx1901), .C (wrData[7]), .D (
          nx1907)) ;
    Nand2 ix1695 (.OUT (nx1694), .A (wrData[6]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_8 (.Q (wrData[8]), .QB (\$dummy [26]), .D (nx634), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix635 (.OUT (nx634), .A (nx1699), .B (nx1701)) ;
    AOI22 ix1700 (.OUT (nx1699), .A (rdData[8]), .B (nx1901), .C (wrData[8]), .D (
          nx1907)) ;
    Nand2 ix1702 (.OUT (nx1701), .A (wrData[7]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_9 (.Q (wrData[9]), .QB (\$dummy [27]), .D (nx648), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix649 (.OUT (nx648), .A (nx1706), .B (nx1708)) ;
    AOI22 ix1707 (.OUT (nx1706), .A (rdData[9]), .B (nx1903), .C (wrData[9]), .D (
          nx1909)) ;
    Nand2 ix1709 (.OUT (nx1708), .A (wrData[8]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_10 (.Q (wrData[10]), .QB (\$dummy [28]), .D (nx662)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix663 (.OUT (nx662), .A (nx1713), .B (nx1715)) ;
    AOI22 ix1714 (.OUT (nx1713), .A (rdData[10]), .B (nx1903), .C (wrData[10]), 
          .D (nx1909)) ;
    Nand2 ix1716 (.OUT (nx1715), .A (wrData[9]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_11 (.Q (wrData[11]), .QB (\$dummy [29]), .D (nx676)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix677 (.OUT (nx676), .A (nx1720), .B (nx1722)) ;
    AOI22 ix1721 (.OUT (nx1720), .A (rdData[11]), .B (nx1903), .C (wrData[11]), 
          .D (nx1909)) ;
    Nand2 ix1723 (.OUT (nx1722), .A (wrData[10]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_12 (.Q (wrData[12]), .QB (\$dummy [30]), .D (nx690)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix691 (.OUT (nx690), .A (nx1727), .B (nx1729)) ;
    AOI22 ix1728 (.OUT (nx1727), .A (rdData[12]), .B (nx1903), .C (wrData[12]), 
          .D (nx1909)) ;
    Nand2 ix1730 (.OUT (nx1729), .A (wrData[11]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_13 (.Q (wrData[13]), .QB (\$dummy [31]), .D (nx704)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix705 (.OUT (nx704), .A (nx1734), .B (nx1736)) ;
    AOI22 ix1735 (.OUT (nx1734), .A (rdData[13]), .B (nx1903), .C (wrData[13]), 
          .D (nx1909)) ;
    Nand2 ix1737 (.OUT (nx1736), .A (wrData[12]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_14 (.Q (wrData[14]), .QB (\$dummy [32]), .D (nx718)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix719 (.OUT (nx718), .A (nx1741), .B (nx1743)) ;
    AOI22 ix1742 (.OUT (nx1741), .A (rdData[14]), .B (nx1903), .C (wrData[14]), 
          .D (nx1909)) ;
    Nand2 ix1744 (.OUT (nx1743), .A (wrData[13]), .B (nx1889)) ;
    DFFC reg_r_dataShiftReg_15 (.Q (wrData[15]), .QB (\$dummy [33]), .D (nx732)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix733 (.OUT (nx732), .A (nx1748), .B (nx1750)) ;
    AOI22 ix1749 (.OUT (nx1748), .A (rdData[15]), .B (nx1903), .C (wrData[15]), 
          .D (nx1909)) ;
    Nand2 ix1751 (.OUT (nx1750), .A (wrData[14]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_16 (.Q (wrData[16]), .QB (\$dummy [34]), .D (nx746)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix747 (.OUT (nx746), .A (nx1755), .B (nx1757)) ;
    AOI22 ix1756 (.OUT (nx1755), .A (rdData[16]), .B (nx1903), .C (wrData[16]), 
          .D (nx1909)) ;
    Nand2 ix1758 (.OUT (nx1757), .A (wrData[15]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_17 (.Q (wrData[17]), .QB (\$dummy [35]), .D (nx760)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix761 (.OUT (nx760), .A (nx1762), .B (nx1764)) ;
    AOI22 ix1763 (.OUT (nx1762), .A (rdData[17]), .B (nx1903), .C (wrData[17]), 
          .D (nx1909)) ;
    Nand2 ix1765 (.OUT (nx1764), .A (wrData[16]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_18 (.Q (wrData[18]), .QB (\$dummy [36]), .D (nx774)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix775 (.OUT (nx774), .A (nx1769), .B (nx1771)) ;
    AOI22 ix1770 (.OUT (nx1769), .A (rdData[18]), .B (nx1905), .C (wrData[18]), 
          .D (nx1911)) ;
    Nand2 ix1772 (.OUT (nx1771), .A (wrData[17]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_19 (.Q (wrData[19]), .QB (\$dummy [37]), .D (nx788)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix789 (.OUT (nx788), .A (nx1776), .B (nx1778)) ;
    AOI22 ix1777 (.OUT (nx1776), .A (rdData[19]), .B (nx1905), .C (wrData[19]), 
          .D (nx1911)) ;
    Nand2 ix1779 (.OUT (nx1778), .A (wrData[18]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_20 (.Q (wrData[20]), .QB (\$dummy [38]), .D (nx802)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix803 (.OUT (nx802), .A (nx1783), .B (nx1785)) ;
    AOI22 ix1784 (.OUT (nx1783), .A (rdData[20]), .B (nx1905), .C (wrData[20]), 
          .D (nx1911)) ;
    Nand2 ix1786 (.OUT (nx1785), .A (wrData[19]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_21 (.Q (wrData[21]), .QB (\$dummy [39]), .D (nx816)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix817 (.OUT (nx816), .A (nx1790), .B (nx1792)) ;
    AOI22 ix1791 (.OUT (nx1790), .A (rdData[21]), .B (nx1905), .C (wrData[21]), 
          .D (nx1911)) ;
    Nand2 ix1793 (.OUT (nx1792), .A (wrData[20]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_22 (.Q (wrData[22]), .QB (\$dummy [40]), .D (nx830)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix831 (.OUT (nx830), .A (nx1797), .B (nx1799)) ;
    AOI22 ix1798 (.OUT (nx1797), .A (rdData[22]), .B (nx1905), .C (wrData[22]), 
          .D (nx1911)) ;
    Nand2 ix1800 (.OUT (nx1799), .A (wrData[21]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_23 (.Q (wrData[23]), .QB (\$dummy [41]), .D (nx844)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix845 (.OUT (nx844), .A (nx1804), .B (nx1806)) ;
    AOI22 ix1805 (.OUT (nx1804), .A (rdData[23]), .B (nx1905), .C (wrData[23]), 
          .D (nx1911)) ;
    Nand2 ix1807 (.OUT (nx1806), .A (wrData[22]), .B (nx1891)) ;
    DFFC reg_r_dataShiftReg_24 (.Q (wrData[24]), .QB (\$dummy [42]), .D (nx858)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix859 (.OUT (nx858), .A (nx1811), .B (nx1813)) ;
    AOI22 ix1812 (.OUT (nx1811), .A (rdData[24]), .B (nx1905), .C (wrData[24]), 
          .D (nx1911)) ;
    Nand2 ix1814 (.OUT (nx1813), .A (wrData[23]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_25 (.Q (wrData[25]), .QB (\$dummy [43]), .D (nx872)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix873 (.OUT (nx872), .A (nx1818), .B (nx1820)) ;
    AOI22 ix1819 (.OUT (nx1818), .A (rdData[25]), .B (nx1905), .C (wrData[25]), 
          .D (nx1911)) ;
    Nand2 ix1821 (.OUT (nx1820), .A (wrData[24]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_26 (.Q (wrData[26]), .QB (\$dummy [44]), .D (nx886)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix887 (.OUT (nx886), .A (nx1825), .B (nx1827)) ;
    AOI22 ix1826 (.OUT (nx1825), .A (rdData[26]), .B (nx1905), .C (wrData[26]), 
          .D (nx1911)) ;
    Nand2 ix1828 (.OUT (nx1827), .A (wrData[25]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_27 (.Q (wrData[27]), .QB (\$dummy [45]), .D (nx900)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix901 (.OUT (nx900), .A (nx1832), .B (nx1834)) ;
    AOI22 ix1833 (.OUT (nx1832), .A (rdData[27]), .B (nx458), .C (wrData[27]), .D (
          nx1913)) ;
    Nand2 ix1835 (.OUT (nx1834), .A (wrData[26]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_28 (.Q (wrData[28]), .QB (\$dummy [46]), .D (nx914)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix915 (.OUT (nx914), .A (nx1839), .B (nx1841)) ;
    AOI22 ix1840 (.OUT (nx1839), .A (rdData[28]), .B (nx458), .C (wrData[28]), .D (
          nx1913)) ;
    Nand2 ix1842 (.OUT (nx1841), .A (wrData[27]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_29 (.Q (wrData[29]), .QB (\$dummy [47]), .D (nx928)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix929 (.OUT (nx928), .A (nx1846), .B (nx1848)) ;
    AOI22 ix1847 (.OUT (nx1846), .A (rdData[29]), .B (nx458), .C (wrData[29]), .D (
          nx1913)) ;
    Nand2 ix1849 (.OUT (nx1848), .A (wrData[28]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_30 (.Q (wrData[30]), .QB (\$dummy [48]), .D (nx942)
         , .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix943 (.OUT (nx942), .A (nx1853), .B (nx1855)) ;
    AOI22 ix1854 (.OUT (nx1853), .A (rdData[30]), .B (nx458), .C (wrData[30]), .D (
          nx1913)) ;
    Nand2 ix1856 (.OUT (nx1855), .A (wrData[29]), .B (nx1893)) ;
    DFFC reg_r_dataShiftReg_31 (.Q (wrData[31]), .QB (nx1864), .D (nx956), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix957 (.OUT (nx956), .A (nx1860), .B (nx1862)) ;
    AOI22 ix1861 (.OUT (nx1860), .A (rdData[31]), .B (nx458), .C (wrData[31]), .D (
          nx1913)) ;
    Nand2 ix1863 (.OUT (nx1862), .A (wrData[30]), .B (nx1893)) ;
    DFFC reg_r_exec (.Q (exec), .QB (\$dummy [49]), .D (nx1445), .CLK (saciClk)
         , .CLR (rstInL)) ;
    Nor2 ix979 (.OUT (rstOutL), .A (nx1868), .B (saciSelL)) ;
    Inv ix1869 (.OUT (nx1868), .A (rstL)) ;
    DFFC reg_r_saciRsp (.Q (saciRsp), .QB (\$dummy [50]), .D (nx966), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nor2 ix967 (.OUT (nx966), .A (nx1467), .B (nx1872)) ;
    Mux2 ix495 (.OUT (nx494), .A (r_headerShiftReg_20), .B (r_headerShiftReg_19)
         , .SEL (nx1899)) ;
    DFFC reg_r_headerShiftReg_20 (.Q (r_headerShiftReg_20), .QB (nx1874), .D (
         nx494), .CLK (saciClk), .CLR (rstInL)) ;
    DFFC reg_r_headerShiftReg_19 (.Q (r_headerShiftReg_19), .QB (\$dummy [51]), 
         .D (nx482), .CLK (saciClk), .CLR (rstInL)) ;
    Mux2 ix483 (.OUT (nx482), .A (r_headerShiftReg_19), .B (cmd[6]), .SEL (
         nx1899)) ;
    Inv ix459 (.OUT (nx458), .A (nx1640)) ;
    Inv ix349 (.OUT (nx348), .A (nx1540)) ;
    Inv ix287 (.OUT (nx286), .A (nx1627)) ;
    Inv ix1558 (.OUT (nx1557), .A (nx284)) ;
    Inv ix1515 (.OUT (nx1514), .A (nx278)) ;
    Inv ix273 (.OUT (nx272), .A (nx1630)) ;
    Inv ix261 (.OUT (nx1450), .A (nx1523)) ;
    Inv ix407 (.OUT (nx1449), .A (nx1542)) ;
    Inv ix1886 (.OUT (nx1887), .A (nx1601)) ;
    Inv ix1888 (.OUT (nx1889), .A (nx1601)) ;
    Inv ix1890 (.OUT (nx1891), .A (nx1601)) ;
    Inv ix1892 (.OUT (nx1893), .A (nx1601)) ;
    Buf1 ix1894 (.OUT (nx1895), .A (nx8)) ;
    Buf1 ix1896 (.OUT (nx1897), .A (nx8)) ;
    Buf1 ix1898 (.OUT (nx1899), .A (nx8)) ;
    Inv ix1900 (.OUT (nx1901), .A (nx1640)) ;
    Inv ix1902 (.OUT (nx1903), .A (nx1640)) ;
    Inv ix1904 (.OUT (nx1905), .A (nx1640)) ;
    Buf1 ix1906 (.OUT (nx1907), .A (nx514)) ;
    Buf1 ix1908 (.OUT (nx1909), .A (nx514)) ;
    Buf1 ix1910 (.OUT (nx1911), .A (nx514)) ;
    Buf1 ix1912 (.OUT (nx1913), .A (nx514)) ;
    Nand2 ix367 (.OUT (nx1601), .A (r_state_1__XX0_XREP25), .B (r_state_0)) ;
    Xnor2 ix1521 (.out (nx1520), .A (nx1517), .B (nx1523)) ;
    Mux2 ix1873 (.OUT (nx1872), .A (nx1874), .B (nx1864), .SEL (nx1483)) ;
    Nor2 ix453 (.OUT (nx1444), .A (nx1477_XX0_XREP25), .B (r_state_0)) ;
    DFFC reg_r_state_0 (.Q (r_state_0), .QB (nx1483), .D (nx360), .CLK (saciClk)
         , .CLR (rstInL)) ;
    Nor2 ix247 (.OUT (nx246), .A (nx1496), .B (nx1542)) ;
    DFFC reg_r_shiftCount_3 (.Q (r_shiftCount_3), .QB (nx1496), .D (nx414), .CLK (
         saciClk), .CLR (rstInL)) ;
    Nand2 ix1543 (.OUT (nx1542), .A (r_shiftCount_2), .B (nx1448)) ;
    DFFC reg_r_state_1 (.Q (r_state_1), .QB (nx1477), .D (nx444), .CLK (saciClk)
         , .CLR (rstInL)) ;
    Nand3 ix445 (.OUT (nx444), .A (nx1480), .B (nx286), .C (nx1636)) ;
    DFFC reg_r_state_1__0_XREP25 (.Q (r_state_1__XX0_XREP25), .QB (
         nx1477_XX0_XREP25), .D (nx444), .CLK (saciClk), .CLR (rstInL)) ;
    Nand2 ix1998 (.OUT (nx1974), .A (nx1557), .B (nx306)) ;
    Nand3 ix1999 (.OUT (nx1975), .A (nx1444), .B (r_state_2), .C (nx1623)) ;
    BufI4 ix2000 (.OUT (nx1976), .A (nx1975)) ;
    Nand2 ix2001 (.OUT (nx1977), .A (nx1536), .B (nx1976)) ;
    BufI4 ix2002 (.OUT (nx1978), .A (nx1467)) ;
    Nand3 ix2003 (.OUT (nx1979), .A (nx352), .B (nx1887), .C (nx1978)) ;
    BufI4 ix2004 (.OUT (nx1980), .A (nx1483)) ;
    Nor3 ix2005 (.OUT (nx1981), .A (r_state_1__XX0_XREP25), .B (nx1980), .C (
         nx1550)) ;
    BufI4 ix2006 (.OUT (nx1982), .A (nx1981)) ;
    BufI4 ix2007 (.OUT (nx1983), .A (nx1542)) ;
    BufI4 ix2008 (.OUT (nx1984), .A (nx1517)) ;
    Nor2 ix2009 (.OUT (nx1985), .A (nx1984), .B (nx1496)) ;
    Nand2 ix2010 (.OUT (nx1986), .A (r_shiftCount_4), .B (nx1985)) ;
    BufI4 ix2011 (.OUT (nx1987), .A (nx1986)) ;
    Nand2 reg_nx324 (.OUT (nx324), .A (nx1983), .B (nx1987)) ;
    Nand2 ix2012 (.OUT (nx1988), .A (nx1887), .B (nx324)) ;
    Nand2 ix2013 (.OUT (nx1989), .A (nx1982), .B (nx1988)) ;
    Nand2 ix2014 (.OUT (nx1990), .A (nx1467), .B (nx1989)) ;
    Nand4 reg_nx360 (.OUT (nx360), .A (nx1974), .B (nx1977), .C (nx1979), .D (
          nx1990)) ;
    Nand2 reg_nx1480 (.OUT (nx1480), .A (nx1887), .B (nx352)) ;
    Nand2 ix2015 (.OUT (nx1991), .A (ack), .B (nx1467)) ;
    BufI4 ix2016 (.OUT (nx1992), .A (nx1991)) ;
    Nor3 ix2017 (.OUT (nx1993), .A (r_state_0), .B (nx1992), .C (
         nx1477_XX0_XREP25)) ;
    BufI4 reg_nx1643 (.OUT (nx1643), .A (nx1993)) ;
    BufI4 ix2018 (.OUT (nx1994), .A (r_state_0)) ;
    BufI4 ix2019 (.OUT (nx1995), .A (nx1467)) ;
    BufI4 ix2020 (.OUT (nx1996), .A (ack)) ;
    Nor3 ix2021 (.OUT (nx1997), .A (nx1995), .B (nx1996), .C (nx1477_XX0_XREP25)
         ) ;
    Nand2 reg_nx1640 (.OUT (nx1640), .A (nx1994), .B (nx1997)) ;
    Nor3 reg_nx1445 (.OUT (nx1445), .A (r_state_0), .B (nx1995), .C (
         nx1477_XX0_XREP25)) ;
    BufI4 reg_nx1465 (.OUT (nx1465), .A (nx1445)) ;
endmodule

