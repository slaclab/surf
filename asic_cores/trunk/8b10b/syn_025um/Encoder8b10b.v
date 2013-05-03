//
// Verilog description for cell Encoder8b10b, 
// Fri May  3 09:04:05 2013
//
// LeonardoSpectrum Level 3, 2011a.4 
//


module Encoder8b10b ( clk, rstN, dataIn, dataKIn, dataOut ) ;

    input clk ;
    input rstN ;
    input [15:0]dataIn ;
    input [1:0]dataKIn ;
    output [19:0]dataOut ;

    wire r_runDisp, nx18, nx102, nx104, nx128, nx130, nx158, nx212, nx214, nx220, 
         nx236, nx238, nx246, nx248, nx258, nx260, nx270, nx276, nx286, nx296, 
         nx300, nx310, nx312, nx324, nx328, nx338, nx350, nx364, nx372, nx380, 
         nx384, nx400, nx408, nx418, nx432, nx436, nx452, nx454, nx464, nx474, 
         nx476, nx478, nx484, nx490, nx500, nx508, nx510, nx520, nx530, nx546, 
         nx554, nx556, nx614, nx618, nx624, nx638, nx642, nx931, nx936, nx940, 
         nx950, nx972, nx1000, nx1002, nx1009, nx1023, nx1029, nx1032, nx1043, 
         nx1049, nx1052, nx1056, nx1060, nx1066, nx1076, nx1082, nx1089, nx1094, 
         nx1096, nx1099, nx1108, nx1112, nx1132, nx1155, nx1157, nx1159, nx1165, 
         nx1172, nx1182, nx1193, nx1200, nx1202, nx1205, nx1229, nx1238, nx1277, 
         nx1278, nx1279, nx1280, nx1281, nx1282, nx1283, nx1284, nx1285, nx1286, 
         nx1287, nx1288, nx1289, nx1290, nx1291, nx1292, nx1220, nx1293, nx1054, 
         nx1013, nx1294, nx1295, nx1296, nx1297, nx10, nx20, nx1298, nx1299, 
         nx1300, nx1301, nx1302, nx1303, nx1304, nx1222, nx1305, nx1306, nx1307, 
         nx1308, nx1309, nx1310, nx1311, nx1312, nx1313, nx1314, nx1315, nx82, 
         nx1316, nx1317, nx1318, nx1319, nx1320, nx1321, nx1322, nx1323, nx1324, 
         nx1325, nx1326, nx1327, nx1328, nx1329, nx1330, nx1331, nx462, nx1332, 
         nx1333, nx522, nx1334, nx1335, nx995, nx1336, nx1337, nx1338, nx1339, 
         nx1340, nx1341, nx1068, nx979, nx1342, nx1343, nx1344, nx1345, nx1346, 
         nx1347, nx1348, nx1349, nx1350, nx1351, nx1352, nx1353, nx1354, nx120, 
         nx1355, nx1356, nx1357, nx1358, nx1359, nx1360, nx192, nx1361, nx1362, 
         nx1015, nx1363, nx1364, nx1365, nx1366, nx967, nx1367, nx1368, nx1369, 
         nx1370, nx1371, nx1372, nx1373, nx1374, nx1375, nx1376, nx586, nx929, 
         nx1377, nx1378, nx1379, nx1380, nx1381, nx1382, nx1383, nx1384, nx1385, 
         nx1386, nx1387, nx1388, nx1389, nx1390, nx1391, nx991, nx1392, nx953, 
         nx1393, nx12, nx1394, nx1395, nx1396, nx1397, nx1398, nx1399, nx1400, 
         nx1401, nx1402, nx1403, nx1404, nx1405, nx1406, nx1407, nx1408, nx110, 
         nx1114, nx1409, nx1410, nx1411, nx1412, nx1413, nx1414, nx1116, nx1415, 
         nx1416, nx412, nx1417, nx1418, nx1419, nx1420, nx1421, nx1422, nx1045, 
         nx1423, nx1424, nx1425, nx1004, nx1426, nx1427, nx1047, nx1428, nx1429, 
         nx1430, nx1431, nx178, nx1174, nx1432, nx1433, nx1434, nx1435, nx1436, 
         nx1437, nx1438, nx1439, nx1440, nx1441, nx1442, nx1443, nx1444, nx1445, 
         nx1446, nx1447, nx1448, nx1449, nx1150, nx1450, nx1451, nx1452, nx1453, 
         nx122, nx1454, nx1455, nx1456, nx1457, nx1458, nx1459, nx1460, nx1461, 
         nx1462, nx1463, nx1464, nx1465, nx1466, nx200, nx166, nx1041, nx1467, 
         nx1468, nx1469, nx1470, nx1471, nx96, nx1472, nx1473, nx1474, nx1475, 
         nx1476, nx1477, nx1478, nx1479, nx1480, nx206, nx1481, nx1482, nx1483, 
         nx1484, nx1485, nx1486, nx1487, nx68, nx1488, nx1489, nx1490, nx1491, 
         nx1492, nx1493, nx1494, nx1495, nx1496, nx1497, nx1498, nx1499, nx1500, 
         nx1501, nx1502, nx1503, nx1504, nx1505, nx606, nx1506, nx1507, nx1508, 
         nx1509, nx1510, nx1511, nx1512, nx1513, nx1514, nx1515, nx1516, nx1517, 
         nx1518, nx1519, nx1520, nx1521, nx1522, nx1523, nx1524, nx1525, nx1526, 
         nx1527, nx1528, nx1529, nx1530, nx1531, nx974, nx1532, nx1533, nx1534, 
         nx1535, nx1536, nx1537, nx1538, nx1539, nx1540, nx1541, nx1542, nx1543, 
         nx1544, nx1545, nx1546, nx1547, nx1548, nx1549, nx1550, nx1551, nx1552, 
         nx976;
    wire [19:0] \$dummy ;




    DFFC reg_r_dataOut_0 (.Q (dataOut[0]), .QB (\$dummy [0]), .D (nx248), .CLK (
         clk), .CLR (rstN)) ;
    Nor4 ix237 (.OUT (nx236), .A (dataIn[4]), .B (dataIn[3]), .C (nx929), .D (
         nx931)) ;
    Inv ix932 (.OUT (nx931), .A (dataIn[2])) ;
    Inv ix941 (.OUT (nx940), .A (dataIn[3])) ;
    Nand3 ix973 (.OUT (nx972), .A (dataIn[3]), .B (dataIn[2]), .C (nx10)) ;
    DFFC reg_r_runDisp (.Q (r_runDisp), .QB (nx1056), .D (nx220), .CLK (clk), .CLR (
         rstN)) ;
    Xnor2 ix221 (.out (nx220), .A (nx206), .B (nx1049)) ;
    Inv ix1001 (.OUT (nx1000), .A (dataIn[6])) ;
    Inv ix1003 (.OUT (nx1002), .A (dataIn[5])) ;
    Inv ix1030 (.OUT (nx1029), .A (dataIn[10])) ;
    Nor3 ix159 (.OUT (nx158), .A (nx1032), .B (dataIn[11]), .C (dataIn[10])) ;
    Nand2 ix1033 (.OUT (nx1032), .A (dataIn[9]), .B (dataIn[8])) ;
    Nand2 ix1044 (.OUT (nx1043), .A (dataIn[10]), .B (nx1015)) ;
    AOI22 ix1050 (.OUT (nx1049), .A (dataIn[15]), .B (nx214), .C (nx1052), .D (
          nx1054)) ;
    Inv ix1053 (.OUT (nx1052), .A (dataIn[14])) ;
    DFFC reg_r_dataOut_1 (.Q (dataOut[1]), .QB (\$dummy [1]), .D (nx276), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix277 (.out (nx276), .A (nx1060), .B (nx246)) ;
    AOI22 ix1061 (.OUT (nx1060), .A (dataIn[1]), .B (nx270), .C (nx10), .D (
          nx258)) ;
    Nand3 ix271 (.OUT (nx270), .A (dataIn[2]), .B (dataIn[3]), .C (nx20)) ;
    Nor2 ix259 (.OUT (nx258), .A (dataIn[3]), .B (dataIn[2])) ;
    Nand2 ix239 (.OUT (nx238), .A (nx1066), .B (nx1068)) ;
    DFFC reg_r_dataOut_2 (.Q (dataOut[2]), .QB (\$dummy [2]), .D (nx286), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix287 (.out (nx286), .A (nx1076), .B (nx246)) ;
    Nor3 ix1077 (.OUT (nx1076), .A (nx18), .B (dataIn[2]), .C (nx260)) ;
    Nor3 ix261 (.OUT (nx260), .A (nx950), .B (dataIn[3]), .C (dataIn[2])) ;
    DFFC reg_r_dataOut_3 (.Q (dataOut[3]), .QB (\$dummy [3]), .D (nx300), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix301 (.out (nx300), .A (nx1082), .B (nx246)) ;
    Nand2 ix1083 (.OUT (nx1082), .A (dataIn[3]), .B (nx296)) ;
    Nand2 ix297 (.OUT (nx296), .A (nx20), .B (dataIn[2])) ;
    DFFC reg_r_dataOut_4 (.Q (dataOut[4]), .QB (\$dummy [4]), .D (nx312), .CLK (
         clk), .CLR (rstN)) ;
    Nor2 ix311 (.OUT (nx310), .A (nx18), .B (nx1089)) ;
    Nor2 ix1090 (.OUT (nx1089), .A (nx82), .B (dataIn[4])) ;
    DFFC reg_r_dataOut_5 (.Q (dataOut[5]), .QB (\$dummy [5]), .D (nx350), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix351 (.out (nx350), .A (nx1094), .B (nx246)) ;
    Mux2 ix1095 (.OUT (nx1094), .A (nx1096), .B (nx953), .SEL (dataIn[4])) ;
    Nor2 ix1097 (.OUT (nx1096), .A (nx338), .B (nx324)) ;
    Nor2 ix339 (.OUT (nx338), .A (nx967), .B (nx1099)) ;
    AOI22 ix1100 (.OUT (nx1099), .A (dataKIn[0]), .B (nx10), .C (nx1082), .D (
          nx328)) ;
    Nand2 ix329 (.OUT (nx328), .A (nx20), .B (nx931)) ;
    Nor3 ix325 (.OUT (nx324), .A (dataIn[3]), .B (dataIn[1]), .C (dataIn[0])) ;
    DFFC reg_r_dataOut_6 (.Q (dataOut[6]), .QB (\$dummy [6]), .D (nx400), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix401 (.out (nx400), .A (nx384), .B (nx1116)) ;
    Nor2 ix385 (.OUT (nx384), .A (nx1002), .B (nx380)) ;
    Nor3 ix381 (.OUT (nx380), .A (nx1108), .B (nx1112), .C (nx1114)) ;
    Nor3 ix1109 (.OUT (nx1108), .A (nx372), .B (nx364), .C (dataKIn[0])) ;
    Nor4 ix373 (.OUT (nx372), .A (dataIn[4]), .B (nx940), .C (nx1056), .D (nx991
         )) ;
    Nor4 ix365 (.OUT (nx364), .A (nx979), .B (dataIn[3]), .C (r_runDisp), .D (
         nx936)) ;
    Inv ix1113 (.OUT (nx1112), .A (dataIn[7])) ;
    DFFC reg_r_dataOut_7 (.Q (dataOut[7]), .QB (\$dummy [7]), .D (nx412), .CLK (
         clk), .CLR (rstN)) ;
    Nor3 ix409 (.OUT (nx408), .A (dataIn[7]), .B (dataIn[6]), .C (dataIn[5])) ;
    DFFC reg_r_dataOut_8 (.Q (dataOut[8]), .QB (\$dummy [8]), .D (nx418), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix419 (.out (nx418), .A (dataIn[7]), .B (nx1116)) ;
    DFFC reg_r_dataOut_9 (.Q (dataOut[9]), .QB (\$dummy [9]), .D (nx436), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix437 (.out (nx436), .A (nx1132), .B (nx1116)) ;
    Nor2 ix1133 (.OUT (nx1132), .A (nx432), .B (nx380)) ;
    Nor3 ix433 (.OUT (nx432), .A (nx104), .B (dataIn[7]), .C (nx102)) ;
    Nor2 ix103 (.OUT (nx102), .A (dataIn[6]), .B (dataIn[5])) ;
    DFFC reg_r_dataOut_10 (.Q (dataOut[10]), .QB (\$dummy [10]), .D (nx464), .CLK (
         clk), .CLR (rstN)) ;
    Nor4 ix453 (.OUT (nx452), .A (dataIn[12]), .B (dataIn[11]), .C (nx1032), .D (
         nx1029)) ;
    Nand3 ix1156 (.OUT (nx1155), .A (dataIn[11]), .B (dataIn[10]), .C (nx120)) ;
    Nand2 ix1160 (.OUT (nx1159), .A (nx1015), .B (nx1150)) ;
    DFFC reg_r_dataOut_11 (.Q (dataOut[11]), .QB (\$dummy [11]), .D (nx490), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix491 (.out (nx490), .A (nx1165), .B (nx462)) ;
    AOI22 ix1166 (.OUT (nx1165), .A (dataIn[9]), .B (nx484), .C (nx120), .D (
          nx474)) ;
    Nand2 ix485 (.OUT (nx484), .A (nx478), .B (dataIn[11])) ;
    Nor2 ix479 (.OUT (nx478), .A (nx1029), .B (nx1032)) ;
    Nor2 ix475 (.OUT (nx474), .A (dataIn[11]), .B (dataIn[10])) ;
    Nand2 ix455 (.OUT (nx454), .A (nx1172), .B (nx1174)) ;
    DFFC reg_r_dataOut_12 (.Q (dataOut[12]), .QB (\$dummy [12]), .D (nx500), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix501 (.out (nx500), .A (nx1182), .B (nx462)) ;
    Nor3 ix1183 (.OUT (nx1182), .A (nx128), .B (dataIn[10]), .C (nx476)) ;
    Nor3 ix477 (.OUT (nx476), .A (nx1023), .B (dataIn[11]), .C (dataIn[10])) ;
    DFFC reg_r_dataOut_13 (.Q (dataOut[13]), .QB (\$dummy [13]), .D (nx510), .CLK (
         clk), .CLR (rstN)) ;
    Nor2 ix509 (.OUT (nx508), .A (nx1013), .B (nx478)) ;
    DFFC reg_r_dataOut_14 (.Q (dataOut[14]), .QB (\$dummy [14]), .D (nx522), .CLK (
         clk), .CLR (rstN)) ;
    Nor2 ix521 (.OUT (nx520), .A (nx128), .B (nx1193)) ;
    Nor2 ix1194 (.OUT (nx1193), .A (nx192), .B (dataIn[12])) ;
    DFFC reg_r_dataOut_15 (.Q (dataOut[15]), .QB (\$dummy [15]), .D (nx556), .CLK (
         clk), .CLR (rstN)) ;
    Mux2 ix555 (.OUT (nx554), .A (nx546), .B (nx166), .SEL (dataIn[12])) ;
    Nand3 ix547 (.OUT (nx546), .A (nx1200), .B (nx1202), .C (nx1205)) ;
    Nand3 ix1201 (.OUT (nx1200), .A (nx120), .B (dataKIn[1]), .C (dataIn[10])) ;
    Nand3 ix1203 (.OUT (nx1202), .A (nx530), .B (nx1032), .C (nx1013)) ;
    Nand2 ix531 (.OUT (nx530), .A (nx1150), .B (nx1015)) ;
    Nand4 ix1206 (.OUT (nx1205), .A (dataIn[11]), .B (dataIn[10]), .C (dataIn[9]
          ), .D (dataIn[8])) ;
    DFFC reg_r_dataOut_16 (.Q (dataOut[16]), .QB (\$dummy [16]), .D (nx606), .CLK (
         clk), .CLR (rstN)) ;
    DFFC reg_r_dataOut_17 (.Q (dataOut[17]), .QB (\$dummy [17]), .D (nx618), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix619 (.out (nx618), .A (nx1229), .B (nx1222)) ;
    Nor2 ix1230 (.OUT (nx1229), .A (nx614), .B (dataIn[14])) ;
    Nor3 ix615 (.OUT (nx614), .A (dataIn[15]), .B (dataIn[14]), .C (dataIn[13])
         ) ;
    DFFC reg_r_dataOut_18 (.Q (dataOut[18]), .QB (\$dummy [18]), .D (nx624), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix625 (.out (nx624), .A (dataIn[15]), .B (nx1222)) ;
    DFFC reg_r_dataOut_19 (.Q (dataOut[19]), .QB (\$dummy [19]), .D (nx642), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix643 (.out (nx642), .A (nx1238), .B (nx1222)) ;
    Nor2 ix1239 (.OUT (nx1238), .A (nx638), .B (nx586)) ;
    Nor3 ix639 (.OUT (nx638), .A (nx214), .B (dataIn[15]), .C (nx212)) ;
    Nor2 ix213 (.OUT (nx212), .A (dataIn[14]), .B (dataIn[13])) ;
    Inv ix1173 (.OUT (nx1172), .A (nx452)) ;
    Inv ix1067 (.OUT (nx1066), .A (nx236)) ;
    Inv ix215 (.OUT (nx214), .A (nx1220)) ;
    Inv ix1010 (.OUT (nx1009), .A (nx192)) ;
    Inv ix1158 (.OUT (nx1157), .A (nx158)) ;
    Inv ix131 (.OUT (nx130), .A (nx1032)) ;
    Inv ix129 (.OUT (nx128), .A (nx1047)) ;
    Inv ix1024 (.OUT (nx1023), .A (nx120)) ;
    Inv ix105 (.OUT (nx104), .A (nx1114)) ;
    Inv ix937 (.OUT (nx936), .A (nx82)) ;
    Inv ix19 (.OUT (nx18), .A (nx995)) ;
    Inv ix951 (.OUT (nx950), .A (nx10)) ;
    Xor2 ix249 (.out (nx248), .A (dataIn[0]), .B (nx246)) ;
    Mux2 ix247 (.OUT (nx246), .A (nx68), .B (nx238), .SEL (nx1056)) ;
    Xor2 ix313 (.out (nx312), .A (nx310), .B (nx246)) ;
    Xor2 ix465 (.out (nx464), .A (dataIn[8]), .B (nx462)) ;
    Xor2 ix511 (.out (nx510), .A (nx508), .B (nx462)) ;
    Xor2 ix557 (.out (nx556), .A (nx554), .B (nx462)) ;
    Nor2 ix1553 (.OUT (nx1277), .A (nx1032), .B (nx122)) ;
    Nor2 ix1554 (.OUT (nx1278), .A (nx1453), .B (nx1043)) ;
    Nor2 ix1555 (.OUT (nx1279), .A (nx1277), .B (nx1278)) ;
    BufI4 ix1556 (.OUT (nx1280), .A (dataIn[12])) ;
    Nand2 ix1557 (.OUT (nx1281), .A (dataIn[11]), .B (nx1280)) ;
    Nor2 ix1558 (.OUT (nx1282), .A (nx1279), .B (nx1281)) ;
    BufI4 ix1559 (.OUT (nx1283), .A (dataKIn[1])) ;
    Nand3 ix1560 (.OUT (nx1284), .A (dataIn[13]), .B (dataIn[14]), .C (
          dataIn[15])) ;
    BufI4 ix1561 (.OUT (nx1285), .A (nx1284)) ;
    BufI4 ix1562 (.OUT (nx1286), .A (dataKIn[1])) ;
    BufI4 ix1563 (.OUT (nx1287), .A (nx1052)) ;
    Nand2 ix1564 (.OUT (nx1288), .A (nx1286), .B (nx1287)) ;
    BufI4 ix1565 (.OUT (nx1289), .A (dataIn[14])) ;
    Nand2 ix1566 (.OUT (nx1290), .A (dataKIn[1]), .B (nx1289)) ;
    Nand2 ix1567 (.OUT (nx1291), .A (dataIn[13]), .B (nx1290)) ;
    Nand2 ix1568 (.OUT (nx1292), .A (nx1288), .B (nx1291)) ;
    Nand2 reg_nx1220 (.OUT (nx1220), .A (dataIn[13]), .B (dataIn[14])) ;
    Nand4 ix1569 (.OUT (nx1293), .A (nx1352), .B (nx1319), .C (dataIn[13]), .D (
          nx1222)) ;
    BufI4 reg_nx1054 (.OUT (nx1054), .A (dataIn[13])) ;
    BufI4 reg_nx1013 (.OUT (nx1013), .A (dataIn[11])) ;
    Nand2 ix1570 (.OUT (nx1294), .A (nx1032), .B (nx1453)) ;
    Nand2 ix1571 (.OUT (nx1295), .A (nx1043), .B (nx1454)) ;
    BufI4 ix1572 (.OUT (nx1296), .A (dataIn[1])) ;
    BufI4 ix1573 (.OUT (nx1297), .A (dataIn[0])) ;
    Nor2 reg_nx10 (.OUT (nx10), .A (dataIn[1]), .B (dataIn[0])) ;
    BufI4 reg_nx20 (.OUT (nx20), .A (nx929)) ;
    Nand2 ix1574 (.OUT (nx1298), .A (nx1292), .B (nx1004)) ;
    Nand2 ix1575 (.OUT (nx1299), .A (nx1425), .B (nx1298)) ;
    AOI22 ix1576 (.OUT (nx1300), .A (nx1000), .B (nx1002), .C (dataIn[7]), .D (
          nx104)) ;
    Nand2 ix1577 (.OUT (nx1301), .A (dataIn[7]), .B (nx104)) ;
    Nand2 ix1578 (.OUT (nx1302), .A (nx1000), .B (nx1002)) ;
    Nand2 ix1579 (.OUT (nx1303), .A (nx1301), .B (nx1302)) ;
    Nand3 ix1580 (.OUT (nx1304), .A (nx1299), .B (nx1473), .C (nx1403)) ;
    Nand2 reg_nx1222 (.OUT (nx1222), .A (nx1304), .B (nx1402)) ;
    BufI4 ix1581 (.OUT (nx1305), .A (nx1004)) ;
    BufI4 ix1582 (.OUT (nx1306), .A (nx1004)) ;
    BufI4 ix1583 (.OUT (nx1307), .A (nx104)) ;
    Nand2 ix1584 (.OUT (nx1308), .A (nx1302), .B (nx1307)) ;
    BufI4 ix1585 (.OUT (nx1309), .A (dataIn[7])) ;
    Nand2 ix1586 (.OUT (nx1310), .A (nx1302), .B (nx1309)) ;
    Nand2 ix1587 (.OUT (nx1311), .A (nx1296), .B (nx1297)) ;
    BufI4 ix1588 (.OUT (nx1312), .A (dataIn[3])) ;
    Nand4 ix1589 (.OUT (nx1313), .A (nx12), .B (nx929), .C (nx1311), .D (nx1312)
          ) ;
    BufI4 ix1590 (.OUT (nx1314), .A (nx12)) ;
    Nand2 ix1591 (.OUT (nx1315), .A (nx10), .B (nx1314)) ;
    Nand2 reg_nx82 (.OUT (nx82), .A (nx1313), .B (nx1315)) ;
    Nor2 ix1592 (.OUT (nx1316), .A (nx1432), .B (dataIn[11])) ;
    Nand2 ix1593 (.OUT (nx1317), .A (nx1285), .B (nx1316)) ;
    Nor2 ix1594 (.OUT (nx1318), .A (nx1009), .B (nx1317)) ;
    Nand3 ix1595 (.OUT (nx1319), .A (nx1473), .B (nx1403), .C (nx1318)) ;
    BufI4 ix1596 (.OUT (nx1320), .A (nx1300)) ;
    Nand2 ix1597 (.OUT (nx1321), .A (nx178), .B (nx1320)) ;
    Nand2 ix1598 (.OUT (nx1322), .A (nx454), .B (nx1300)) ;
    Nand2 ix1599 (.OUT (nx1323), .A (nx1321), .B (nx1322)) ;
    Nand2 ix1600 (.OUT (nx1324), .A (nx96), .B (nx1323)) ;
    BufI4 ix1601 (.OUT (nx1325), .A (nx1303)) ;
    Nand2 ix1602 (.OUT (nx1326), .A (nx178), .B (nx1325)) ;
    Nand2 ix1603 (.OUT (nx1327), .A (nx454), .B (nx1303)) ;
    Nand2 ix1604 (.OUT (nx1328), .A (nx1326), .B (nx1327)) ;
    BufI4 ix1605 (.OUT (nx1329), .A (nx96)) ;
    Nand2 ix1606 (.OUT (nx1330), .A (nx1328), .B (nx1329)) ;
    Nand3 ix1607 (.OUT (nx1331), .A (nx520), .B (nx1324), .C (nx1330)) ;
    Nand2 reg_nx462 (.OUT (nx462), .A (nx1324), .B (nx1330)) ;
    BufI4 ix1608 (.OUT (nx1332), .A (nx520)) ;
    Nand2 ix1609 (.OUT (nx1333), .A (nx462), .B (nx1332)) ;
    Nand2 reg_nx522 (.OUT (nx522), .A (nx1331), .B (nx1333)) ;
    Nand2 ix1610 (.OUT (nx1334), .A (dataIn[4]), .B (dataIn[3])) ;
    BufI4 ix1611 (.OUT (nx1335), .A (nx1334)) ;
    Nand3 reg_nx995 (.OUT (nx995), .A (nx10), .B (nx931), .C (nx1335)) ;
    BufI4 ix1612 (.OUT (nx1336), .A (nx1056)) ;
    BufI4 ix1613 (.OUT (nx1337), .A (dataKIn[0])) ;
    BufI4 ix1614 (.OUT (nx1338), .A (dataKIn[0])) ;
    BufI4 ix1615 (.OUT (nx1339), .A (nx1530)) ;
    BufI4 ix1616 (.OUT (nx1340), .A (dataKIn[0])) ;
    AOI22 ix1617 (.OUT (nx1341), .A (nx1504), .B (nx1338), .C (nx1339), .D (
          nx1340)) ;
    BufI4 reg_nx1068 (.OUT (nx1068), .A (nx1341)) ;
    BufI4 reg_nx979 (.OUT (nx979), .A (dataIn[4])) ;
    Nand3 ix1618 (.OUT (nx1342), .A (nx1308), .B (nx1283), .C (nx1310)) ;
    BufI4 ix1619 (.OUT (nx1343), .A (nx1342)) ;
    Nand2 ix1620 (.OUT (nx1344), .A (nx96), .B (nx1343)) ;
    Nand2 ix1621 (.OUT (nx1345), .A (nx1308), .B (nx1310)) ;
    Nand2 ix1622 (.OUT (nx1346), .A (nx1283), .B (nx1345)) ;
    BufI4 ix1623 (.OUT (nx1347), .A (nx1346)) ;
    Nand4 ix1624 (.OUT (nx1348), .A (nx1347), .B (nx1471), .C (nx1493), .D (
          nx1488)) ;
    BufI4 ix1625 (.OUT (nx1349), .A (nx1283)) ;
    Nor2 ix1626 (.OUT (nx1350), .A (nx1349), .B (nx1282)) ;
    Nor2 ix1627 (.OUT (nx1351), .A (nx1284), .B (nx1350)) ;
    Nand3 ix1628 (.OUT (nx1352), .A (nx1344), .B (nx1348), .C (nx1351)) ;
    BufI4 ix1629 (.OUT (nx1353), .A (nx1159)) ;
    BufI4 ix1630 (.OUT (nx1354), .A (nx130)) ;
    Nor2 reg_nx120 (.OUT (nx120), .A (dataIn[9]), .B (dataIn[8])) ;
    Nor3 ix1631 (.OUT (nx1355), .A (nx120), .B (dataIn[11]), .C (dataIn[10])) ;
    BufI4 ix1632 (.OUT (nx1356), .A (dataIn[10])) ;
    Nand2 ix1633 (.OUT (nx1357), .A (dataIn[11]), .B (nx1356)) ;
    BufI4 ix1634 (.OUT (nx1358), .A (dataIn[11])) ;
    Nand2 ix1635 (.OUT (nx1359), .A (dataIn[10]), .B (nx1358)) ;
    Nand2 ix1636 (.OUT (nx1360), .A (nx1357), .B (nx1359)) ;
    Nand2 reg_nx192 (.OUT (nx192), .A (nx1438), .B (nx1439)) ;
    Nand2 ix1637 (.OUT (nx1361), .A (nx1155), .B (nx1157)) ;
    BufI4 ix1638 (.OUT (nx1362), .A (nx1361)) ;
    Nor2 reg_nx1015 (.OUT (nx1015), .A (nx120), .B (nx130)) ;
    BufI4 ix1639 (.OUT (nx1363), .A (dataIn[2])) ;
    BufI4 ix1640 (.OUT (nx1364), .A (dataIn[3])) ;
    BufI4 ix1641 (.OUT (nx1365), .A (dataIn[0])) ;
    BufI4 ix1642 (.OUT (nx1366), .A (dataIn[1])) ;
    Nand2 reg_nx967 (.OUT (nx967), .A (nx1522), .B (nx1523)) ;
    Nand3 ix1643 (.OUT (nx1367), .A (nx1403), .B (nx1473), .C (nx1318)) ;
    Nand3 ix1644 (.OUT (nx1368), .A (dataIn[13]), .B (nx1352), .C (nx1367)) ;
    BufI4 ix1645 (.OUT (nx1369), .A (nx1004)) ;
    Nand2 ix1646 (.OUT (nx1370), .A (nx1292), .B (nx1305)) ;
    BufI4 ix1647 (.OUT (nx1371), .A (nx1370)) ;
    Nand2 ix1648 (.OUT (nx1372), .A (nx1292), .B (nx1004)) ;
    BufI4 ix1649 (.OUT (nx1373), .A (nx1372)) ;
    Nand2 ix1650 (.OUT (nx1374), .A (nx1473), .B (nx1373)) ;
    BufI4 ix1651 (.OUT (nx1375), .A (nx1374)) ;
    AOI22 ix1652 (.OUT (nx1376), .A (nx110), .B (nx1371), .C (nx1403), .D (
          nx1375)) ;
    Nand2 reg_nx586 (.OUT (nx586), .A (nx1352), .B (nx1367)) ;
    Nand2 reg_nx929 (.OUT (nx929), .A (dataIn[1]), .B (dataIn[0])) ;
    BufI4 ix1653 (.OUT (nx1377), .A (nx1546)) ;
    Nor2 ix1654 (.OUT (nx1378), .A (nx1377), .B (nx1545)) ;
    BufI4 ix1655 (.OUT (nx1379), .A (nx1545)) ;
    Nor2 ix1656 (.OUT (nx1380), .A (nx1365), .B (nx1366)) ;
    Nor2 ix1657 (.OUT (nx1381), .A (nx1366), .B (dataIn[1])) ;
    Nor2 ix1658 (.OUT (nx1382), .A (nx1380), .B (nx1381)) ;
    Nor2 ix1659 (.OUT (nx1383), .A (nx1365), .B (dataIn[0])) ;
    BufI4 ix1660 (.OUT (nx1384), .A (dataIn[2])) ;
    Nor2 ix1661 (.OUT (nx1385), .A (dataIn[1]), .B (dataIn[0])) ;
    Nor3 ix1662 (.OUT (nx1386), .A (nx1383), .B (nx1384), .C (nx1385)) ;
    Nand2 ix1663 (.OUT (nx1387), .A (nx1382), .B (nx1386)) ;
    AOI22 ix1664 (.OUT (nx1388), .A (nx929), .B (nx1378), .C (nx12), .D (nx1387)
          ) ;
    Nor3 ix1665 (.OUT (nx1389), .A (nx1544), .B (dataIn[4]), .C (nx1388)) ;
    Nand2 ix1666 (.OUT (nx1390), .A (nx12), .B (nx1387)) ;
    Nand3 ix1667 (.OUT (nx1391), .A (nx929), .B (nx1546), .C (nx1379)) ;
    Nand2 reg_nx991 (.OUT (nx991), .A (nx1390), .B (nx1391)) ;
    Nand3 ix1668 (.OUT (nx1392), .A (nx974), .B (nx976), .C (nx972)) ;
    BufI4 reg_nx953 (.OUT (nx953), .A (nx1392)) ;
    Nand3 ix1669 (.OUT (nx1393), .A (nx10), .B (nx1546), .C (nx1379)) ;
    Nand2 reg_nx12 (.OUT (nx12), .A (nx1546), .B (nx1379)) ;
    Nand3 ix1670 (.OUT (nx1394), .A (nx1311), .B (nx929), .C (nx1312)) ;
    Nor2 ix1671 (.OUT (nx1395), .A (nx1292), .B (nx1004)) ;
    BufI4 ix1672 (.OUT (nx1396), .A (nx1395)) ;
    BufI4 ix1673 (.OUT (nx1397), .A (nx1220)) ;
    Nand2 ix1674 (.OUT (nx1398), .A (nx1004), .B (nx1397)) ;
    BufI4 ix1675 (.OUT (nx1399), .A (nx1303)) ;
    BufI4 ix1676 (.OUT (nx1400), .A (nx1300)) ;
    AOI22 ix1677 (.OUT (nx1401), .A (nx1471), .B (nx1535), .C (nx96), .D (nx1400
          )) ;
    Nand3 ix1678 (.OUT (nx1402), .A (nx1396), .B (nx1398), .C (nx1401)) ;
    Nand4 ix1679 (.OUT (nx1403), .A (nx1471), .B (nx1493), .C (nx1303), .D (
          nx1488)) ;
    Nand2 ix1680 (.OUT (nx1404), .A (nx1493), .B (nx1488)) ;
    Nand2 ix1681 (.OUT (nx1405), .A (nx1300), .B (nx1404)) ;
    BufI4 ix1682 (.OUT (nx1406), .A (nx1300)) ;
    Nor2 ix1683 (.OUT (nx1407), .A (nx1406), .B (nx1471)) ;
    BufI4 ix1684 (.OUT (nx1408), .A (nx1407)) ;
    Nand3 reg_nx110 (.OUT (nx110), .A (nx1403), .B (nx1405), .C (nx1408)) ;
    Nand2 reg_nx1114 (.OUT (nx1114), .A (dataIn[6]), .B (dataIn[5])) ;
    AOI22 ix1685 (.OUT (nx1409), .A (dataKIn[0]), .B (nx1114), .C (nx1000), .D (
          nx1002)) ;
    Nand4 ix1686 (.OUT (nx1410), .A (nx1409), .B (nx1488), .C (nx1471), .D (
          nx1493)) ;
    Nand2 ix1687 (.OUT (nx1411), .A (nx96), .B (nx1114)) ;
    BufI4 ix1688 (.OUT (nx1412), .A (dataIn[6])) ;
    BufI4 ix1689 (.OUT (nx1413), .A (nx408)) ;
    Nand4 ix1690 (.OUT (nx1414), .A (nx1410), .B (nx1411), .C (nx1412), .D (
          nx1413)) ;
    Nand2 reg_nx1116 (.OUT (nx1116), .A (nx1410), .B (nx1411)) ;
    Nand2 ix1691 (.OUT (nx1415), .A (nx1412), .B (nx1413)) ;
    Nand2 ix1692 (.OUT (nx1416), .A (nx1116), .B (nx1415)) ;
    Nand2 reg_nx412 (.OUT (nx412), .A (nx1414), .B (nx1416)) ;
    BufI4 ix1693 (.OUT (nx1417), .A (dataKIn[0])) ;
    BufI4 ix1694 (.OUT (nx1418), .A (nx974)) ;
    BufI4 ix1695 (.OUT (nx1419), .A (dataIn[4])) ;
    Nor2 ix1696 (.OUT (nx1420), .A (nx1419), .B (nx1532)) ;
    Nand4 ix1697 (.OUT (nx1421), .A (nx1393), .B (nx1498), .C (nx972), .D (
          nx1420)) ;
    BufI4 ix1698 (.OUT (nx1422), .A (nx200)) ;
    BufI4 reg_nx1045 (.OUT (nx1045), .A (dataIn[12])) ;
    BufI4 ix1699 (.OUT (nx1423), .A (dataKIn[1])) ;
    Nand3 ix1700 (.OUT (nx1424), .A (nx1422), .B (nx1436), .C (nx1423)) ;
    Nand2 ix1701 (.OUT (nx1425), .A (nx1424), .B (nx1220)) ;
    BufI4 reg_nx1004 (.OUT (nx1004), .A (nx1466)) ;
    Nand2 ix1702 (.OUT (nx1426), .A (dataIn[12]), .B (dataIn[11])) ;
    BufI4 ix1703 (.OUT (nx1427), .A (nx1426)) ;
    Nand3 reg_nx1047 (.OUT (nx1047), .A (nx120), .B (nx1029), .C (nx1427)) ;
    BufI4 ix1704 (.OUT (nx1428), .A (dataIn[12])) ;
    Nand2 ix1705 (.OUT (nx1429), .A (nx1041), .B (nx1428)) ;
    BufI4 ix1706 (.OUT (nx1430), .A (nx1429)) ;
    Nand2 ix1707 (.OUT (nx1431), .A (nx1437), .B (nx1430)) ;
    Nand2 reg_nx178 (.OUT (nx178), .A (nx1047), .B (nx1431)) ;
    Nor2 reg_nx1174 (.OUT (nx1174), .A (nx200), .B (dataKIn[1])) ;
    BufI4 ix1708 (.OUT (nx1432), .A (dataIn[12])) ;
    BufI4 ix1709 (.OUT (nx1433), .A (dataIn[12])) ;
    Nor2 ix1710 (.OUT (nx1434), .A (nx1511), .B (nx1045)) ;
    Nand2 ix1711 (.OUT (nx1435), .A (nx1045), .B (nx166)) ;
    Nand3 ix1712 (.OUT (nx1436), .A (nx1435), .B (nx1457), .C (nx1513)) ;
    BufI4 ix1713 (.OUT (nx1437), .A (nx166)) ;
    Nand2 ix1714 (.OUT (nx1438), .A (nx1354), .B (nx1355)) ;
    Nand2 ix1715 (.OUT (nx1439), .A (nx1360), .B (nx120)) ;
    Nand4 ix1716 (.OUT (nx1440), .A (nx1155), .B (nx1438), .C (dataIn[12]), .D (
          nx1439)) ;
    Nand2 ix1717 (.OUT (nx1441), .A (nx995), .B (nx1337)) ;
    BufI4 ix1718 (.OUT (nx1442), .A (nx1441)) ;
    BufI4 ix1719 (.OUT (nx1443), .A (nx1056)) ;
    BufI4 ix1720 (.OUT (nx1444), .A (nx1337)) ;
    BufI4 ix1721 (.OUT (nx1445), .A (nx1157)) ;
    BufI4 ix1722 (.OUT (nx1446), .A (dataIn[10])) ;
    Nand2 ix1723 (.OUT (nx1447), .A (dataIn[11]), .B (nx1446)) ;
    BufI4 ix1724 (.OUT (nx1448), .A (dataIn[11])) ;
    Nand2 ix1725 (.OUT (nx1449), .A (dataIn[10]), .B (nx1448)) ;
    Nand2 reg_nx1150 (.OUT (nx1150), .A (nx1447), .B (nx1449)) ;
    Nor2 ix1726 (.OUT (nx1450), .A (dataIn[11]), .B (dataIn[10])) ;
    Nand2 ix1727 (.OUT (nx1451), .A (dataIn[11]), .B (dataIn[10])) ;
    BufI4 ix1728 (.OUT (nx1452), .A (nx1451)) ;
    Nor2 ix1729 (.OUT (nx1453), .A (nx1450), .B (nx1452)) ;
    BufI4 reg_nx122 (.OUT (nx122), .A (nx1453)) ;
    BufI4 ix1730 (.OUT (nx1454), .A (nx1453)) ;
    Nand2 ix1731 (.OUT (nx1455), .A (nx1433), .B (nx1294)) ;
    BufI4 ix1732 (.OUT (nx1456), .A (nx1455)) ;
    Nand2 ix1733 (.OUT (nx1457), .A (nx1295), .B (nx1456)) ;
    Nand2 ix1734 (.OUT (nx1458), .A (nx1434), .B (nx1457)) ;
    BufI4 ix1735 (.OUT (nx1459), .A (nx1159)) ;
    BufI4 ix1736 (.OUT (nx1460), .A (nx1362)) ;
    Nor3 ix1737 (.OUT (nx1461), .A (nx1511), .B (nx1459), .C (nx1460)) ;
    Nand2 ix1738 (.OUT (nx1462), .A (nx1457), .B (nx1461)) ;
    BufI4 ix1739 (.OUT (nx1463), .A (nx1353)) ;
    Nor2 ix1740 (.OUT (nx1464), .A (nx1440), .B (nx1445)) ;
    Nand2 ix1741 (.OUT (nx1465), .A (nx1463), .B (nx1464)) ;
    Nand4 ix1742 (.OUT (nx1466), .A (nx1458), .B (nx1462), .C (nx1465), .D (
          nx1423)) ;
    Nor3 reg_nx200 (.OUT (nx200), .A (nx1353), .B (nx1440), .C (nx1445)) ;
    Nand2 reg_nx166 (.OUT (nx166), .A (nx1159), .B (nx1362)) ;
    Nand2 reg_nx1041 (.OUT (nx1041), .A (nx1294), .B (nx1295)) ;
    Nand2 ix1743 (.OUT (nx1467), .A (nx972), .B (dataIn[4])) ;
    Nand3 ix1744 (.OUT (nx1468), .A (nx1487), .B (nx1442), .C (nx1502)) ;
    Nand2 ix1745 (.OUT (nx1469), .A (nx1056), .B (nx1468)) ;
    BufI4 ix1746 (.OUT (nx1470), .A (nx995)) ;
    Nand3 ix1747 (.OUT (nx1471), .A (nx1336), .B (nx1487), .C (nx1518)) ;
    Nand2 reg_nx96 (.OUT (nx96), .A (nx1469), .B (nx1471)) ;
    BufI4 ix1748 (.OUT (nx1472), .A (nx1306)) ;
    Nand2 ix1749 (.OUT (nx1473), .A (nx1300), .B (nx96)) ;
    Nand3 ix1750 (.OUT (nx1474), .A (nx1472), .B (nx1403), .C (nx1473)) ;
    Nand2 ix1751 (.OUT (nx1475), .A (nx1403), .B (nx1473)) ;
    Nand2 ix1752 (.OUT (nx1476), .A (nx1369), .B (nx1475)) ;
    Nand3 ix1753 (.OUT (nx1477), .A (nx1474), .B (nx1220), .C (nx1476)) ;
    Nand3 ix1754 (.OUT (nx1478), .A (nx1306), .B (nx1403), .C (nx1473)) ;
    BufI4 ix1755 (.OUT (nx1479), .A (nx1369)) ;
    Nand2 ix1756 (.OUT (nx1480), .A (nx1475), .B (nx1479)) ;
    Nand2 reg_nx206 (.OUT (nx206), .A (nx1478), .B (nx1480)) ;
    Nor2 ix1757 (.OUT (nx1481), .A (nx1444), .B (nx1530)) ;
    BufI4 ix1758 (.OUT (nx1482), .A (nx1481)) ;
    Nand2 ix1759 (.OUT (nx1483), .A (nx1337), .B (nx1504)) ;
    Nand2 ix1760 (.OUT (nx1484), .A (nx1482), .B (nx1483)) ;
    Nand2 ix1761 (.OUT (nx1485), .A (nx974), .B (nx972)) ;
    BufI4 ix1762 (.OUT (nx1486), .A (nx1485)) ;
    Nand2 ix1763 (.OUT (nx1487), .A (nx1389), .B (nx1486)) ;
    Nand2 reg_nx68 (.OUT (nx68), .A (nx995), .B (nx1487)) ;
    Nand2 ix1764 (.OUT (nx1488), .A (nx1056), .B (nx68)) ;
    BufI4 ix1765 (.OUT (nx1489), .A (nx1444)) ;
    BufI4 ix1766 (.OUT (nx1490), .A (nx1530)) ;
    AOI22 ix1767 (.OUT (nx1491), .A (nx1337), .B (nx1504), .C (nx1489), .D (
          nx1490)) ;
    BufI4 ix1768 (.OUT (nx1492), .A (nx1443)) ;
    Nand2 ix1769 (.OUT (nx1493), .A (nx1491), .B (nx1492)) ;
    BufI4 ix1770 (.OUT (nx1494), .A (nx1467)) ;
    BufI4 ix1771 (.OUT (nx1495), .A (nx974)) ;
    BufI4 ix1772 (.OUT (nx1496), .A (nx1393)) ;
    BufI4 ix1773 (.OUT (nx1497), .A (nx1394)) ;
    Nand2 ix1774 (.OUT (nx1498), .A (nx12), .B (nx1497)) ;
    BufI4 ix1775 (.OUT (nx1499), .A (nx1532)) ;
    Nand2 ix1776 (.OUT (nx1500), .A (nx1498), .B (nx1499)) ;
    Nor3 ix1777 (.OUT (nx1501), .A (nx1495), .B (nx1496), .C (nx1500)) ;
    Nand2 ix1778 (.OUT (nx1502), .A (nx1494), .B (nx1501)) ;
    BufI4 ix1779 (.OUT (nx1503), .A (nx1467)) ;
    Nand3 ix1780 (.OUT (nx1504), .A (nx1503), .B (nx1393), .C (nx1498)) ;
    Nand3 ix1781 (.OUT (nx1505), .A (nx1376), .B (nx1368), .C (nx1477)) ;
    Nand2 reg_nx606 (.OUT (nx606), .A (nx1293), .B (nx1505)) ;
    Nand2 ix1782 (.OUT (nx1506), .A (nx1029), .B (dataIn[11])) ;
    Nand2 ix1783 (.OUT (nx1507), .A (dataIn[12]), .B (nx1506)) ;
    BufI4 ix1784 (.OUT (nx1508), .A (dataIn[12])) ;
    Nor2 ix1785 (.OUT (nx1509), .A (nx1508), .B (nx120)) ;
    BufI4 ix1786 (.OUT (nx1510), .A (nx1509)) ;
    Nand2 ix1787 (.OUT (nx1511), .A (nx1507), .B (nx1510)) ;
    Nand3 ix1788 (.OUT (nx1512), .A (nx120), .B (nx1029), .C (dataIn[11])) ;
    Nand2 ix1789 (.OUT (nx1513), .A (dataIn[12]), .B (nx1512)) ;
    Nor2 ix1790 (.OUT (nx1514), .A (dataKIn[0]), .B (nx1470)) ;
    Nand2 ix1791 (.OUT (nx1515), .A (nx1421), .B (nx1514)) ;
    BufI4 ix1792 (.OUT (nx1516), .A (nx1470)) ;
    Nand3 ix1793 (.OUT (nx1517), .A (nx1516), .B (nx1417), .C (nx1418)) ;
    Nand2 ix1794 (.OUT (nx1518), .A (nx1515), .B (nx1517)) ;
    Nand2 ix1795 (.OUT (nx1519), .A (dataIn[0]), .B (nx1366)) ;
    Nand2 ix1796 (.OUT (nx1520), .A (dataIn[1]), .B (nx1365)) ;
    Nand2 ix1797 (.OUT (nx1521), .A (nx1519), .B (nx1520)) ;
    Nand2 ix1798 (.OUT (nx1522), .A (dataIn[3]), .B (nx1363)) ;
    Nand2 ix1799 (.OUT (nx1523), .A (dataIn[2]), .B (nx1364)) ;
    Nand2 ix1800 (.OUT (nx1524), .A (nx1522), .B (nx1523)) ;
    Nand2 ix1801 (.OUT (nx1525), .A (nx1521), .B (nx1524)) ;
    Nor2 ix1802 (.OUT (nx1526), .A (dataIn[3]), .B (dataIn[2])) ;
    BufI4 ix1803 (.OUT (nx1527), .A (nx1526)) ;
    Nand2 ix1804 (.OUT (nx1528), .A (nx1525), .B (nx1527)) ;
    Nand2 ix1805 (.OUT (nx1529), .A (nx929), .B (nx1525)) ;
    Nand2 ix1806 (.OUT (nx1530), .A (nx1528), .B (nx1529)) ;
    BufI4 ix1807 (.OUT (nx1531), .A (nx929)) ;
    Nand2 reg_nx974 (.OUT (nx974), .A (nx1526), .B (nx1531)) ;
    AOI22 ix1808 (.OUT (nx1532), .A (nx1522), .B (nx1523), .C (nx1519), .D (
          nx1520)) ;
    Nand3 ix1809 (.OUT (nx1533), .A (nx1443), .B (nx1399), .C (nx1488)) ;
    Nand3 ix1810 (.OUT (nx1534), .A (nx1484), .B (nx1399), .C (nx1488)) ;
    Nand2 ix1811 (.OUT (nx1535), .A (nx1533), .B (nx1534)) ;
    BufI4 ix1812 (.OUT (nx1536), .A (dataIn[0])) ;
    Nand2 ix1813 (.OUT (nx1537), .A (dataIn[1]), .B (nx1536)) ;
    BufI4 ix1814 (.OUT (nx1538), .A (dataIn[1])) ;
    Nand2 ix1815 (.OUT (nx1539), .A (dataIn[0]), .B (nx1538)) ;
    BufI4 ix1816 (.OUT (nx1540), .A (dataIn[2])) ;
    Nand2 ix1817 (.OUT (nx1541), .A (dataIn[3]), .B (nx1540)) ;
    BufI4 ix1818 (.OUT (nx1542), .A (dataIn[3])) ;
    Nand2 ix1819 (.OUT (nx1543), .A (dataIn[2]), .B (nx1542)) ;
    AOI22 ix1820 (.OUT (nx1544), .A (nx1537), .B (nx1539), .C (nx1541), .D (
          nx1543)) ;
    Nor2 ix1821 (.OUT (nx1545), .A (dataIn[3]), .B (dataIn[2])) ;
    Nand2 ix1822 (.OUT (nx1546), .A (dataIn[3]), .B (dataIn[2])) ;
    BufI4 ix1823 (.OUT (nx1547), .A (nx1546)) ;
    Nor2 ix1824 (.OUT (nx1548), .A (nx1545), .B (nx1547)) ;
    Nor2 ix1825 (.OUT (nx1549), .A (dataIn[1]), .B (dataIn[0])) ;
    Nand2 ix1826 (.OUT (nx1550), .A (dataIn[1]), .B (dataIn[0])) ;
    BufI4 ix1827 (.OUT (nx1551), .A (nx1550)) ;
    Nor2 ix1828 (.OUT (nx1552), .A (nx1549), .B (nx1551)) ;
    Nand2 reg_nx976 (.OUT (nx976), .A (nx1548), .B (nx1552)) ;
endmodule

