//
// Verilog description for cell SaciSlave, 
// Thu May  2 14:10:05 2013
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

    wire nx1350, NOT_rstInL, r_state_2, r_state_1, nx1444, r_shiftCount_3, 
         r_shiftCount_2, r_shiftCount_1, r_state_0, nx8, saciCmdFall, 
         NOT_saciClk, nx22, nx34, nx46, nx58, nx70, nx82, nx94, nx106, nx118, 
         nx130, nx142, nx154, nx166, nx178, nx190, nx202, nx214, nx226, nx238, 
         nx1448, r_shiftCount_5, r_shiftCount_4, nx1449, nx246, nx1450, nx254, 
         nx264, nx272, nx278, nx284, nx286, nx294, nx306, nx316, nx324, 
         r_shiftCount_0, nx342, nx348, nx352, nx360, nx372, nx376, nx386, nx400, 
         nx414, nx430, nx444, nx458, nx462, nx466, nx470, r_headerShiftReg_20, 
         r_headerShiftReg_19, nx482, nx494, nx514, nx522, nx536, nx550, nx564, 
         nx578, nx592, nx606, nx620, nx634, nx648, nx662, nx676, nx690, nx704, 
         nx718, nx732, nx746, nx760, nx774, nx788, nx802, nx816, nx830, nx844, 
         nx858, nx872, nx886, nx900, nx914, nx928, nx942, nx956, nx966, nx1458, 
         nx1460, nx1462, nx1464, nx1467, nx1472, nx1475, nx1478, nx1484, nx1487, 
         nx1490, nx1492, nx1495, nx1497, nx1500, nx1502, nx1505, nx1507, nx1510, 
         nx1512, nx1515, nx1517, nx1520, nx1522, nx1525, nx1527, nx1530, nx1532, 
         nx1535, nx1537, nx1540, nx1542, nx1545, nx1547, nx1550, nx1552, nx1555, 
         nx1557, nx1560, nx1562, nx1565, nx1567, nx1570, nx1572, nx1575, nx1577, 
         nx1580, nx1582, nx1585, nx1587, nx1590, nx1592, nx1595, nx1597, nx1600, 
         nx1602, nx1605, nx1607, nx1610, nx1612, nx1615, nx1617, nx1620, nx1622, 
         nx1625, nx1627, nx1630, nx1632, nx1635, nx1637, nx1640, nx1642, nx1646, 
         nx1650, nx1653, nx1656, nx1659, nx1661, nx1664, nx1666, nx1668, nx1671, 
         nx1673, nx1677, nx1679, nx1683, nx1687, nx1691, nx1693, nx1696, nx1701, 
         nx1705, nx1707, nx1711, nx1713, nx1716, nx1718, nx1720, nx1724, nx1727, 
         nx1729, nx1732, nx1734, nx1737, nx1765, nx1774, nx1776, nx1778, nx1780, 
         nx1782, nx1784, nx1786, nx1788, nx1790, nx1792, nx1794, nx1796, nx1798, 
         nx1800, nx1480, nx1445, nx1480_XX0_XREP17;



    DFFRS reg_saciCmdFall (.set (nx1350), .reset (NOT_rstInL), .in (saciCmd), .clk (
          NOT_saciClk), .out (saciCmdFall)) ;
    DFFRS reg_r_headerShiftReg_0 (.set (nx1350), .reset (NOT_rstInL), .in (nx22)
          , .clk (saciClk), .out (addr[0])) ;
    DFFRS reg_r_headerShiftReg_1 (.set (nx1350), .reset (NOT_rstInL), .in (nx34)
          , .clk (saciClk), .out (addr[1])) ;
    DFFRS reg_r_headerShiftReg_2 (.set (nx1350), .reset (NOT_rstInL), .in (nx46)
          , .clk (saciClk), .out (addr[2])) ;
    DFFRS reg_r_headerShiftReg_3 (.set (nx1350), .reset (NOT_rstInL), .in (nx58)
          , .clk (saciClk), .out (addr[3])) ;
    DFFRS reg_r_headerShiftReg_4 (.set (nx1350), .reset (NOT_rstInL), .in (nx70)
          , .clk (saciClk), .out (addr[4])) ;
    DFFRS reg_r_headerShiftReg_5 (.set (nx1350), .reset (NOT_rstInL), .in (nx82)
          , .clk (saciClk), .out (addr[5])) ;
    DFFRS reg_r_headerShiftReg_6 (.set (nx1350), .reset (NOT_rstInL), .in (nx94)
          , .clk (saciClk), .out (addr[6])) ;
    DFFRS reg_r_headerShiftReg_7 (.set (nx1350), .reset (NOT_rstInL), .in (nx106
          ), .clk (saciClk), .out (addr[7])) ;
    DFFRS reg_r_headerShiftReg_8 (.set (nx1350), .reset (NOT_rstInL), .in (nx118
          ), .clk (saciClk), .out (addr[8])) ;
    DFFRS reg_r_headerShiftReg_9 (.set (nx1350), .reset (NOT_rstInL), .in (nx130
          ), .clk (saciClk), .out (addr[9])) ;
    DFFRS reg_r_headerShiftReg_10 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx142), .clk (saciClk), .out (addr[10])) ;
    DFFRS reg_r_headerShiftReg_11 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx154), .clk (saciClk), .out (addr[11])) ;
    DFFRS reg_r_headerShiftReg_12 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx166), .clk (saciClk), .out (cmd[0])) ;
    DFFRS reg_r_headerShiftReg_13 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx178), .clk (saciClk), .out (cmd[1])) ;
    DFFRS reg_r_headerShiftReg_14 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx190), .clk (saciClk), .out (cmd[2])) ;
    DFFRS reg_r_headerShiftReg_15 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx202), .clk (saciClk), .out (cmd[3])) ;
    DFFRS reg_r_headerShiftReg_16 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx214), .clk (saciClk), .out (cmd[4])) ;
    DFFRS reg_r_headerShiftReg_17 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx226), .clk (saciClk), .out (cmd[5])) ;
    DFFRS reg_r_headerShiftReg_18 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx238), .clk (saciClk), .out (cmd[6])) ;
    DFFRS reg_r_shiftCount_4 (.set (nx1350), .reset (NOT_rstInL), .in (nx254), .clk (
          saciClk), .out (r_shiftCount_4)) ;
    DFFRS reg_r_shiftCount_5 (.set (nx1350), .reset (NOT_rstInL), .in (nx264), .clk (
          saciClk), .out (r_shiftCount_5)) ;
    DFFRS reg_r_writeFlag (.set (nx1350), .reset (NOT_rstInL), .in (nx294), .clk (
          saciClk), .out (readL)) ;
    DFFRS reg_r_shiftCount_0 (.set (nx1350), .reset (NOT_rstInL), .in (nx342), .clk (
          saciClk), .out (r_shiftCount_0)) ;
    DFFRS reg_r_state_0 (.set (nx1350), .reset (NOT_rstInL), .in (nx360), .clk (
          saciClk), .out (r_state_0)) ;
    DFFRS reg_r_shiftCount_1 (.set (nx1350), .reset (NOT_rstInL), .in (nx386), .clk (
          saciClk), .out (r_shiftCount_1)) ;
    DFFRS reg_r_shiftCount_2 (.set (nx1350), .reset (NOT_rstInL), .in (nx400), .clk (
          saciClk), .out (r_shiftCount_2)) ;
    DFFRS reg_r_shiftCount_3 (.set (nx1350), .reset (NOT_rstInL), .in (nx414), .clk (
          saciClk), .out (r_shiftCount_3)) ;
    DFFRS reg_r_state_1 (.set (nx1350), .reset (NOT_rstInL), .in (nx444), .clk (
          saciClk), .out (r_state_1)) ;
    DFFRS reg_r_state_2 (.set (nx1350), .reset (NOT_rstInL), .in (nx470), .clk (
          saciClk), .out (r_state_2)) ;
    DFFRS reg_r_headerShiftReg_19 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx482), .clk (saciClk), .out (r_headerShiftReg_19)) ;
    DFFRS reg_r_headerShiftReg_20 (.set (nx1350), .reset (NOT_rstInL), .in (
          nx494), .clk (saciClk), .out (r_headerShiftReg_20)) ;
    DFFRS reg_r_dataShiftReg_0 (.set (nx1350), .reset (NOT_rstInL), .in (nx522)
          , .clk (saciClk), .out (wrData[0])) ;
    DFFRS reg_r_dataShiftReg_1 (.set (nx1350), .reset (NOT_rstInL), .in (nx536)
          , .clk (saciClk), .out (wrData[1])) ;
    DFFRS reg_r_dataShiftReg_2 (.set (nx1350), .reset (NOT_rstInL), .in (nx550)
          , .clk (saciClk), .out (wrData[2])) ;
    DFFRS reg_r_dataShiftReg_3 (.set (nx1350), .reset (NOT_rstInL), .in (nx564)
          , .clk (saciClk), .out (wrData[3])) ;
    DFFRS reg_r_dataShiftReg_4 (.set (nx1350), .reset (NOT_rstInL), .in (nx578)
          , .clk (saciClk), .out (wrData[4])) ;
    DFFRS reg_r_dataShiftReg_5 (.set (nx1350), .reset (NOT_rstInL), .in (nx592)
          , .clk (saciClk), .out (wrData[5])) ;
    DFFRS reg_r_dataShiftReg_6 (.set (nx1350), .reset (NOT_rstInL), .in (nx606)
          , .clk (saciClk), .out (wrData[6])) ;
    DFFRS reg_r_dataShiftReg_7 (.set (nx1350), .reset (NOT_rstInL), .in (nx620)
          , .clk (saciClk), .out (wrData[7])) ;
    DFFRS reg_r_dataShiftReg_8 (.set (nx1350), .reset (NOT_rstInL), .in (nx634)
          , .clk (saciClk), .out (wrData[8])) ;
    DFFRS reg_r_dataShiftReg_9 (.set (nx1350), .reset (NOT_rstInL), .in (nx648)
          , .clk (saciClk), .out (wrData[9])) ;
    DFFRS reg_r_dataShiftReg_10 (.set (nx1350), .reset (NOT_rstInL), .in (nx662)
          , .clk (saciClk), .out (wrData[10])) ;
    DFFRS reg_r_dataShiftReg_11 (.set (nx1350), .reset (NOT_rstInL), .in (nx676)
          , .clk (saciClk), .out (wrData[11])) ;
    DFFRS reg_r_dataShiftReg_12 (.set (nx1350), .reset (NOT_rstInL), .in (nx690)
          , .clk (saciClk), .out (wrData[12])) ;
    DFFRS reg_r_dataShiftReg_13 (.set (nx1350), .reset (NOT_rstInL), .in (nx704)
          , .clk (saciClk), .out (wrData[13])) ;
    DFFRS reg_r_dataShiftReg_14 (.set (nx1350), .reset (NOT_rstInL), .in (nx718)
          , .clk (saciClk), .out (wrData[14])) ;
    DFFRS reg_r_dataShiftReg_15 (.set (nx1350), .reset (NOT_rstInL), .in (nx732)
          , .clk (saciClk), .out (wrData[15])) ;
    DFFRS reg_r_dataShiftReg_16 (.set (nx1350), .reset (NOT_rstInL), .in (nx746)
          , .clk (saciClk), .out (wrData[16])) ;
    DFFRS reg_r_dataShiftReg_17 (.set (nx1350), .reset (NOT_rstInL), .in (nx760)
          , .clk (saciClk), .out (wrData[17])) ;
    DFFRS reg_r_dataShiftReg_18 (.set (nx1350), .reset (NOT_rstInL), .in (nx774)
          , .clk (saciClk), .out (wrData[18])) ;
    DFFRS reg_r_dataShiftReg_19 (.set (nx1350), .reset (NOT_rstInL), .in (nx788)
          , .clk (saciClk), .out (wrData[19])) ;
    DFFRS reg_r_dataShiftReg_20 (.set (nx1350), .reset (NOT_rstInL), .in (nx802)
          , .clk (saciClk), .out (wrData[20])) ;
    DFFRS reg_r_dataShiftReg_21 (.set (nx1350), .reset (NOT_rstInL), .in (nx816)
          , .clk (saciClk), .out (wrData[21])) ;
    DFFRS reg_r_dataShiftReg_22 (.set (nx1350), .reset (NOT_rstInL), .in (nx830)
          , .clk (saciClk), .out (wrData[22])) ;
    DFFRS reg_r_dataShiftReg_23 (.set (nx1350), .reset (NOT_rstInL), .in (nx844)
          , .clk (saciClk), .out (wrData[23])) ;
    DFFRS reg_r_dataShiftReg_24 (.set (nx1350), .reset (NOT_rstInL), .in (nx858)
          , .clk (saciClk), .out (wrData[24])) ;
    DFFRS reg_r_dataShiftReg_25 (.set (nx1350), .reset (NOT_rstInL), .in (nx872)
          , .clk (saciClk), .out (wrData[25])) ;
    DFFRS reg_r_dataShiftReg_26 (.set (nx1350), .reset (NOT_rstInL), .in (nx886)
          , .clk (saciClk), .out (wrData[26])) ;
    DFFRS reg_r_dataShiftReg_27 (.set (nx1350), .reset (NOT_rstInL), .in (nx900)
          , .clk (saciClk), .out (wrData[27])) ;
    DFFRS reg_r_dataShiftReg_28 (.set (nx1350), .reset (NOT_rstInL), .in (nx914)
          , .clk (saciClk), .out (wrData[28])) ;
    DFFRS reg_r_dataShiftReg_29 (.set (nx1350), .reset (NOT_rstInL), .in (nx928)
          , .clk (saciClk), .out (wrData[29])) ;
    DFFRS reg_r_dataShiftReg_30 (.set (nx1350), .reset (NOT_rstInL), .in (nx942)
          , .clk (saciClk), .out (wrData[30])) ;
    DFFRS reg_r_dataShiftReg_31 (.set (nx1350), .reset (NOT_rstInL), .in (nx956)
          , .clk (saciClk), .out (wrData[31])) ;
    DFFRS reg_r_saciRsp (.set (nx1350), .reset (NOT_rstInL), .in (nx966), .clk (
          saciClk), .out (saciRsp)) ;
    DFFRS reg_r_exec (.set (nx1350), .reset (NOT_rstInL), .in (nx1445), .clk (
          saciClk), .out (exec)) ;
    Nor2 ix967 (.OUT (nx966), .A (nx1458), .B (nx1460)) ;
    Inv ix1459 (.OUT (nx1458), .A (r_state_2)) ;
    Mux2 ix1461 (.OUT (nx1460), .A (nx1462), .B (nx1464), .SEL (r_state_0)) ;
    Inv ix1463 (.OUT (nx1462), .A (wrData[31])) ;
    Inv ix1465 (.OUT (nx1464), .A (r_headerShiftReg_20)) ;
    Nand2 ix957 (.OUT (nx956), .A (nx1467), .B (nx1484)) ;
    AOI22 ix1468 (.OUT (nx1467), .A (rdData[31]), .B (nx1788), .C (wrData[31]), 
          .D (nx1794)) ;
    Nand2 ix1473 (.OUT (nx1472), .A (nx1458), .B (nx1444)) ;
    Nor2 ix453 (.OUT (nx1444), .A (nx1475), .B (r_state_0)) ;
    Inv ix1476 (.OUT (nx1475), .A (r_state_1)) ;
    Nand2 ix515 (.OUT (nx514), .A (nx1478), .B (nx284)) ;
    Nand2 ix1479 (.OUT (nx1478), .A (nx1480_XX0_XREP17), .B (nx1444)) ;
    Nand3 ix285 (.OUT (nx284), .A (nx1475), .B (nx1458), .C (r_state_0)) ;
    Nand2 ix1485 (.OUT (nx1484), .A (wrData[30]), .B (nx1774)) ;
    Inv ix1488 (.OUT (nx1487), .A (r_state_0)) ;
    Nand2 ix943 (.OUT (nx942), .A (nx1490), .B (nx1492)) ;
    AOI22 ix1491 (.OUT (nx1490), .A (rdData[30]), .B (nx1788), .C (wrData[30]), 
          .D (nx1794)) ;
    Nand2 ix1493 (.OUT (nx1492), .A (wrData[29]), .B (nx1774)) ;
    Nand2 ix929 (.OUT (nx928), .A (nx1495), .B (nx1497)) ;
    AOI22 ix1496 (.OUT (nx1495), .A (rdData[29]), .B (nx1788), .C (wrData[29]), 
          .D (nx1794)) ;
    Nand2 ix1498 (.OUT (nx1497), .A (wrData[28]), .B (nx1774)) ;
    Nand2 ix915 (.OUT (nx914), .A (nx1500), .B (nx1502)) ;
    AOI22 ix1501 (.OUT (nx1500), .A (rdData[28]), .B (nx1788), .C (wrData[28]), 
          .D (nx1794)) ;
    Nand2 ix1503 (.OUT (nx1502), .A (wrData[27]), .B (nx1774)) ;
    Nand2 ix901 (.OUT (nx900), .A (nx1505), .B (nx1507)) ;
    AOI22 ix1506 (.OUT (nx1505), .A (rdData[27]), .B (nx1788), .C (wrData[27]), 
          .D (nx1794)) ;
    Nand2 ix1508 (.OUT (nx1507), .A (wrData[26]), .B (nx1774)) ;
    Nand2 ix887 (.OUT (nx886), .A (nx1510), .B (nx1512)) ;
    AOI22 ix1511 (.OUT (nx1510), .A (rdData[26]), .B (nx1788), .C (wrData[26]), 
          .D (nx1794)) ;
    Nand2 ix1513 (.OUT (nx1512), .A (wrData[25]), .B (nx1774)) ;
    Nand2 ix873 (.OUT (nx872), .A (nx1515), .B (nx1517)) ;
    AOI22 ix1516 (.OUT (nx1515), .A (rdData[25]), .B (nx1788), .C (wrData[25]), 
          .D (nx1794)) ;
    Nand2 ix1518 (.OUT (nx1517), .A (wrData[24]), .B (nx1774)) ;
    Nand2 ix859 (.OUT (nx858), .A (nx1520), .B (nx1522)) ;
    AOI22 ix1521 (.OUT (nx1520), .A (rdData[24]), .B (nx1788), .C (wrData[24]), 
          .D (nx1794)) ;
    Nand2 ix1523 (.OUT (nx1522), .A (wrData[23]), .B (nx1774)) ;
    Nand2 ix845 (.OUT (nx844), .A (nx1525), .B (nx1527)) ;
    AOI22 ix1526 (.OUT (nx1525), .A (rdData[23]), .B (nx1788), .C (wrData[23]), 
          .D (nx1794)) ;
    Nand2 ix1528 (.OUT (nx1527), .A (wrData[22]), .B (nx1774)) ;
    Nand2 ix831 (.OUT (nx830), .A (nx1530), .B (nx1532)) ;
    AOI22 ix1531 (.OUT (nx1530), .A (rdData[22]), .B (nx1790), .C (wrData[22]), 
          .D (nx1796)) ;
    Nand2 ix1533 (.OUT (nx1532), .A (wrData[21]), .B (nx1776)) ;
    Nand2 ix817 (.OUT (nx816), .A (nx1535), .B (nx1537)) ;
    AOI22 ix1536 (.OUT (nx1535), .A (rdData[21]), .B (nx1790), .C (wrData[21]), 
          .D (nx1796)) ;
    Nand2 ix1538 (.OUT (nx1537), .A (wrData[20]), .B (nx1776)) ;
    Nand2 ix803 (.OUT (nx802), .A (nx1540), .B (nx1542)) ;
    AOI22 ix1541 (.OUT (nx1540), .A (rdData[20]), .B (nx1790), .C (wrData[20]), 
          .D (nx1796)) ;
    Nand2 ix1543 (.OUT (nx1542), .A (wrData[19]), .B (nx1776)) ;
    Nand2 ix789 (.OUT (nx788), .A (nx1545), .B (nx1547)) ;
    AOI22 ix1546 (.OUT (nx1545), .A (rdData[19]), .B (nx1790), .C (wrData[19]), 
          .D (nx1796)) ;
    Nand2 ix1548 (.OUT (nx1547), .A (wrData[18]), .B (nx1776)) ;
    Nand2 ix775 (.OUT (nx774), .A (nx1550), .B (nx1552)) ;
    AOI22 ix1551 (.OUT (nx1550), .A (rdData[18]), .B (nx1790), .C (wrData[18]), 
          .D (nx1796)) ;
    Nand2 ix1553 (.OUT (nx1552), .A (wrData[17]), .B (nx1776)) ;
    Nand2 ix761 (.OUT (nx760), .A (nx1555), .B (nx1557)) ;
    AOI22 ix1556 (.OUT (nx1555), .A (rdData[17]), .B (nx1790), .C (wrData[17]), 
          .D (nx1796)) ;
    Nand2 ix1558 (.OUT (nx1557), .A (wrData[16]), .B (nx1776)) ;
    Nand2 ix747 (.OUT (nx746), .A (nx1560), .B (nx1562)) ;
    AOI22 ix1561 (.OUT (nx1560), .A (rdData[16]), .B (nx1790), .C (wrData[16]), 
          .D (nx1796)) ;
    Nand2 ix1563 (.OUT (nx1562), .A (wrData[15]), .B (nx1776)) ;
    Nand2 ix733 (.OUT (nx732), .A (nx1565), .B (nx1567)) ;
    AOI22 ix1566 (.OUT (nx1565), .A (rdData[15]), .B (nx1790), .C (wrData[15]), 
          .D (nx1796)) ;
    Nand2 ix1568 (.OUT (nx1567), .A (wrData[14]), .B (nx1776)) ;
    Nand2 ix719 (.OUT (nx718), .A (nx1570), .B (nx1572)) ;
    AOI22 ix1571 (.OUT (nx1570), .A (rdData[14]), .B (nx1790), .C (wrData[14]), 
          .D (nx1796)) ;
    Nand2 ix1573 (.OUT (nx1572), .A (wrData[13]), .B (nx1776)) ;
    Nand2 ix705 (.OUT (nx704), .A (nx1575), .B (nx1577)) ;
    AOI22 ix1576 (.OUT (nx1575), .A (rdData[13]), .B (nx1792), .C (wrData[13]), 
          .D (nx1798)) ;
    Nand2 ix1578 (.OUT (nx1577), .A (wrData[12]), .B (nx1778)) ;
    Nand2 ix691 (.OUT (nx690), .A (nx1580), .B (nx1582)) ;
    AOI22 ix1581 (.OUT (nx1580), .A (rdData[12]), .B (nx1792), .C (wrData[12]), 
          .D (nx1798)) ;
    Nand2 ix1583 (.OUT (nx1582), .A (wrData[11]), .B (nx1778)) ;
    Nand2 ix677 (.OUT (nx676), .A (nx1585), .B (nx1587)) ;
    AOI22 ix1586 (.OUT (nx1585), .A (rdData[11]), .B (nx1792), .C (wrData[11]), 
          .D (nx1798)) ;
    Nand2 ix1588 (.OUT (nx1587), .A (wrData[10]), .B (nx1778)) ;
    Nand2 ix663 (.OUT (nx662), .A (nx1590), .B (nx1592)) ;
    AOI22 ix1591 (.OUT (nx1590), .A (rdData[10]), .B (nx1792), .C (wrData[10]), 
          .D (nx1798)) ;
    Nand2 ix1593 (.OUT (nx1592), .A (wrData[9]), .B (nx1778)) ;
    Nand2 ix649 (.OUT (nx648), .A (nx1595), .B (nx1597)) ;
    AOI22 ix1596 (.OUT (nx1595), .A (rdData[9]), .B (nx1792), .C (wrData[9]), .D (
          nx1798)) ;
    Nand2 ix1598 (.OUT (nx1597), .A (wrData[8]), .B (nx1778)) ;
    Nand2 ix635 (.OUT (nx634), .A (nx1600), .B (nx1602)) ;
    AOI22 ix1601 (.OUT (nx1600), .A (rdData[8]), .B (nx1792), .C (wrData[8]), .D (
          nx1798)) ;
    Nand2 ix1603 (.OUT (nx1602), .A (wrData[7]), .B (nx1778)) ;
    Nand2 ix621 (.OUT (nx620), .A (nx1605), .B (nx1607)) ;
    AOI22 ix1606 (.OUT (nx1605), .A (rdData[7]), .B (nx1792), .C (wrData[7]), .D (
          nx1798)) ;
    Nand2 ix1608 (.OUT (nx1607), .A (wrData[6]), .B (nx1778)) ;
    Nand2 ix607 (.OUT (nx606), .A (nx1610), .B (nx1612)) ;
    AOI22 ix1611 (.OUT (nx1610), .A (rdData[6]), .B (nx1792), .C (wrData[6]), .D (
          nx1798)) ;
    Nand2 ix1613 (.OUT (nx1612), .A (wrData[5]), .B (nx1778)) ;
    Nand2 ix593 (.OUT (nx592), .A (nx1615), .B (nx1617)) ;
    AOI22 ix1616 (.OUT (nx1615), .A (rdData[5]), .B (nx1792), .C (wrData[5]), .D (
          nx1798)) ;
    Nand2 ix1618 (.OUT (nx1617), .A (wrData[4]), .B (nx1778)) ;
    Nand2 ix579 (.OUT (nx578), .A (nx1620), .B (nx1622)) ;
    AOI22 ix1621 (.OUT (nx1620), .A (rdData[4]), .B (nx458), .C (wrData[4]), .D (
          nx1800)) ;
    Nand2 ix1623 (.OUT (nx1622), .A (wrData[3]), .B (nx1780)) ;
    Nand2 ix565 (.OUT (nx564), .A (nx1625), .B (nx1627)) ;
    AOI22 ix1626 (.OUT (nx1625), .A (rdData[3]), .B (nx458), .C (wrData[3]), .D (
          nx1800)) ;
    Nand2 ix1628 (.OUT (nx1627), .A (wrData[2]), .B (nx1780)) ;
    Nand2 ix551 (.OUT (nx550), .A (nx1630), .B (nx1632)) ;
    AOI22 ix1631 (.OUT (nx1630), .A (rdData[2]), .B (nx458), .C (wrData[2]), .D (
          nx1800)) ;
    Nand2 ix1633 (.OUT (nx1632), .A (wrData[1]), .B (nx1780)) ;
    Nand2 ix537 (.OUT (nx536), .A (nx1635), .B (nx1637)) ;
    AOI22 ix1636 (.OUT (nx1635), .A (rdData[1]), .B (nx458), .C (wrData[1]), .D (
          nx1800)) ;
    Nand2 ix1638 (.OUT (nx1637), .A (wrData[0]), .B (nx1780)) ;
    Nand2 ix523 (.OUT (nx522), .A (nx1640), .B (nx1642)) ;
    AOI22 ix1641 (.OUT (nx1640), .A (rdData[0]), .B (nx458), .C (wrData[0]), .D (
          nx1800)) ;
    Nand2 ix1643 (.OUT (nx1642), .A (saciCmdFall), .B (nx1780)) ;
    Mux2 ix495 (.OUT (nx494), .A (r_headerShiftReg_20), .B (r_headerShiftReg_19)
         , .SEL (nx1782)) ;
    Nand2 ix9 (.OUT (nx8), .A (nx1646), .B (nx1472)) ;
    Mux2 ix483 (.OUT (nx482), .A (r_headerShiftReg_19), .B (cmd[6]), .SEL (
         nx1782)) ;
    Nand2 ix471 (.OUT (nx470), .A (nx1650), .B (nx1480)) ;
    Nand2 ix1651 (.OUT (nx1650), .A (r_state_2), .B (nx466)) ;
    Nand2 ix467 (.OUT (nx466), .A (nx1653), .B (nx1668)) ;
    Nand2 ix1654 (.OUT (nx1653), .A (nx1444), .B (nx462)) ;
    Nand2 ix463 (.OUT (nx462), .A (readL), .B (nx1656)) ;
    Nor4 ix1657 (.OUT (nx1656), .A (nx348), .B (nx272), .C (nx1666), .D (
         r_shiftCount_3)) ;
    Inv ix1660 (.OUT (nx1659), .A (r_shiftCount_0)) ;
    Inv ix1662 (.OUT (nx1661), .A (r_shiftCount_1)) ;
    Inv ix1665 (.OUT (nx1664), .A (r_shiftCount_5)) ;
    Inv ix1667 (.OUT (nx1666), .A (r_shiftCount_2)) ;
    Nand2 ix1669 (.OUT (nx1668), .A (nx1780), .B (nx352)) ;
    Nand3 ix353 (.OUT (nx352), .A (nx1671), .B (nx1666), .C (nx1673)) ;
    Nor2 ix1672 (.OUT (nx1671), .A (r_shiftCount_0), .B (r_shiftCount_1)) ;
    Nor3 ix1674 (.OUT (nx1673), .A (r_shiftCount_4), .B (nx1664), .C (
         r_shiftCount_3)) ;
    Nand3 ix445 (.OUT (nx444), .A (nx1668), .B (nx286), .C (nx1683)) ;
    AOI22 ix1684 (.OUT (nx1683), .A (nx1458), .B (r_state_1), .C (nx1444), .D (
          nx430)) ;
    Nand2 ix431 (.OUT (nx430), .A (readL), .B (nx1656)) ;
    Nor3 ix415 (.OUT (nx414), .A (nx1687), .B (nx246), .C (nx1696)) ;
    Nor2 ix1688 (.OUT (nx1687), .A (nx1449), .B (r_shiftCount_3)) ;
    Nor2 ix247 (.OUT (nx246), .A (nx1691), .B (nx1693)) ;
    Inv ix1692 (.OUT (nx1691), .A (r_shiftCount_3)) ;
    Nand2 ix1694 (.OUT (nx1693), .A (r_shiftCount_2), .B (nx1448)) ;
    Nor2 ix393 (.OUT (nx1448), .A (nx1661), .B (nx1659)) ;
    Nor3 ix1697 (.OUT (nx1696), .A (nx376), .B (nx372), .C (nx1780)) ;
    Nor2 ix377 (.OUT (nx376), .A (nx1679), .B (nx284)) ;
    Nor3 ix373 (.OUT (nx372), .A (nx1656), .B (nx1475), .C (nx1445)) ;
    Nor3 ix401 (.OUT (nx400), .A (nx1701), .B (nx1449), .C (nx1696)) ;
    Nor2 ix1702 (.OUT (nx1701), .A (nx1448), .B (r_shiftCount_2)) ;
    Nor3 ix387 (.OUT (nx386), .A (nx1696), .B (nx1448), .C (nx1671)) ;
    Nand3 ix361 (.OUT (nx360), .A (nx1705), .B (nx1713), .C (nx1718)) ;
    Mux2 ix1706 (.OUT (nx1705), .A (nx1668), .B (nx1707), .SEL (r_state_2)) ;
    AOI22 ix1708 (.OUT (nx1707), .A (nx1780), .B (nx324), .C (nx1487), .D (nx316
          )) ;
    Nand3 ix325 (.OUT (nx324), .A (r_shiftCount_4), .B (nx1664), .C (nx246)) ;
    Nor2 ix317 (.OUT (nx316), .A (nx1711), .B (r_state_1)) ;
    Inv ix1712 (.OUT (nx1711), .A (saciCmdFall)) ;
    Nand2 ix1714 (.OUT (nx1713), .A (nx1677), .B (nx306)) ;
    Nand2 ix307 (.OUT (nx306), .A (nx1716), .B (nx1679)) ;
    Inv ix1717 (.OUT (nx1716), .A (cmd[6])) ;
    Nand4 ix1719 (.OUT (nx1718), .A (r_state_2), .B (nx1444), .C (nx1656), .D (
          nx1720)) ;
    Inv ix1721 (.OUT (nx1720), .A (readL)) ;
    Nor2 ix343 (.OUT (nx342), .A (r_shiftCount_0), .B (nx1696)) ;
    Mux2 ix295 (.OUT (nx294), .A (cmd[6]), .B (readL), .SEL (nx1724)) ;
    Nor2 ix1725 (.OUT (nx1724), .A (nx284), .B (nx278)) ;
    Nand4 ix279 (.OUT (nx278), .A (nx1727), .B (nx1448), .C (nx1666), .D (nx1691
          )) ;
    Nor2 ix1728 (.OUT (nx1727), .A (nx1729), .B (r_shiftCount_5)) ;
    Inv ix1730 (.OUT (nx1729), .A (r_shiftCount_4)) ;
    Nor2 ix265 (.OUT (nx264), .A (nx1732), .B (nx1696)) ;
    Xor2 ix1733 (.out (nx1732), .A (r_shiftCount_5), .B (nx1734)) ;
    Nand2 ix1735 (.OUT (nx1734), .A (r_shiftCount_4), .B (nx246)) ;
    Nor3 ix255 (.OUT (nx254), .A (nx1737), .B (nx1450), .C (nx1696)) ;
    Nor2 ix1738 (.OUT (nx1737), .A (nx246), .B (r_shiftCount_4)) ;
    Mux2 ix239 (.OUT (nx238), .A (cmd[6]), .B (cmd[5]), .SEL (nx1782)) ;
    Mux2 ix227 (.OUT (nx226), .A (cmd[5]), .B (cmd[4]), .SEL (nx1782)) ;
    Mux2 ix215 (.OUT (nx214), .A (cmd[4]), .B (cmd[3]), .SEL (nx1782)) ;
    Mux2 ix203 (.OUT (nx202), .A (cmd[3]), .B (cmd[2]), .SEL (nx1782)) ;
    Mux2 ix191 (.OUT (nx190), .A (cmd[2]), .B (cmd[1]), .SEL (nx1782)) ;
    Mux2 ix179 (.OUT (nx178), .A (cmd[1]), .B (cmd[0]), .SEL (nx1782)) ;
    Mux2 ix167 (.OUT (nx166), .A (cmd[0]), .B (addr[11]), .SEL (nx1782)) ;
    Mux2 ix155 (.OUT (nx154), .A (addr[11]), .B (addr[10]), .SEL (nx1784)) ;
    Mux2 ix143 (.OUT (nx142), .A (addr[10]), .B (addr[9]), .SEL (nx1784)) ;
    Mux2 ix131 (.OUT (nx130), .A (addr[9]), .B (addr[8]), .SEL (nx1784)) ;
    Mux2 ix119 (.OUT (nx118), .A (addr[8]), .B (addr[7]), .SEL (nx1784)) ;
    Mux2 ix107 (.OUT (nx106), .A (addr[7]), .B (addr[6]), .SEL (nx1784)) ;
    Mux2 ix95 (.OUT (nx94), .A (addr[6]), .B (addr[5]), .SEL (nx1784)) ;
    Mux2 ix83 (.OUT (nx82), .A (addr[5]), .B (addr[4]), .SEL (nx1784)) ;
    Mux2 ix71 (.OUT (nx70), .A (addr[4]), .B (addr[3]), .SEL (nx1784)) ;
    Mux2 ix59 (.OUT (nx58), .A (addr[3]), .B (addr[2]), .SEL (nx1784)) ;
    Mux2 ix47 (.OUT (nx46), .A (addr[2]), .B (addr[1]), .SEL (nx1786)) ;
    Mux2 ix35 (.OUT (nx34), .A (addr[1]), .B (addr[0]), .SEL (nx1786)) ;
    Mux2 ix23 (.OUT (nx22), .A (addr[0]), .B (saciCmdFall), .SEL (nx1786)) ;
    GND ix1351 (.Y (nx1350)) ;
    Inv ix1763 (.OUT (NOT_rstInL), .A (rstInL)) ;
    Nor2 ix979 (.OUT (rstOutL), .A (nx1765), .B (saciSelL)) ;
    Inv ix1766 (.OUT (nx1765), .A (rstL)) ;
    Inv ix1768 (.OUT (NOT_saciClk), .A (saciClk)) ;
    Inv ix459 (.OUT (nx458), .A (nx1480)) ;
    Inv ix349 (.OUT (nx348), .A (nx1671)) ;
    Inv ix287 (.OUT (nx286), .A (nx1724)) ;
    Inv ix1678 (.OUT (nx1677), .A (nx284)) ;
    Inv ix1680 (.OUT (nx1679), .A (nx278)) ;
    Inv ix273 (.OUT (nx272), .A (nx1727)) ;
    Inv ix261 (.OUT (nx1450), .A (nx1734)) ;
    Inv ix407 (.OUT (nx1449), .A (nx1693)) ;
    Inv ix1773 (.OUT (nx1774), .A (nx1646)) ;
    Inv ix1775 (.OUT (nx1776), .A (nx1646)) ;
    Inv ix1777 (.OUT (nx1778), .A (nx1646)) ;
    Inv ix1779 (.OUT (nx1780), .A (nx1646)) ;
    Buf1 ix1781 (.OUT (nx1782), .A (nx8)) ;
    Buf1 ix1783 (.OUT (nx1784), .A (nx8)) ;
    Buf1 ix1785 (.OUT (nx1786), .A (nx8)) ;
    Inv ix1787 (.OUT (nx1788), .A (nx1480_XX0_XREP17)) ;
    Inv ix1789 (.OUT (nx1790), .A (nx1480_XX0_XREP17)) ;
    Inv ix1791 (.OUT (nx1792), .A (nx1480)) ;
    Buf1 ix1793 (.OUT (nx1794), .A (nx514)) ;
    Buf1 ix1795 (.OUT (nx1796), .A (nx514)) ;
    Buf1 ix1797 (.OUT (nx1798), .A (nx514)) ;
    Buf1 ix1799 (.OUT (nx1800), .A (nx514)) ;
    Nand2 ix367 (.OUT (nx1646), .A (r_state_1), .B (r_state_0)) ;
    Nand2 ix1481 (.OUT (nx1480), .A (ack), .B (nx1445)) ;
    Inv ix457 (.OUT (nx1445), .A (nx1472)) ;
    Nand2 ix1481_0_XREP17 (.OUT (nx1480_XX0_XREP17), .A (ack), .B (nx1445)) ;
endmodule


module DFFRS ( set, reset, in, clk, out ) ;

    input set ;
    input reset ;
    input in ;
    input clk ;
    output out ;
reg out; 
always @ (posedge set or posedge reset or posedge clk)
begin
    if (set) out = 1;
    else if (reset) out = 0;
    else begin
     out = in;
    end
end

endmodule

