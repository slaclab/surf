//
// Verilog description for cell Decoder8b10b, 
// Fri May  3 09:07:37 2013
//
// LeonardoSpectrum Level 3, 2011a.4 
//


module Decoder8b10b ( clk, rstN, dataIn, dataOut, dataKOut, codeErr, dispErr ) ;

    input clk ;
    input rstN ;
    input [19:0]dataIn ;
    output [15:0]dataOut ;
    output [1:0]dataKOut ;
    output [1:0]codeErr ;
    output [1:0]dispErr ;

    wire nx32, nx46, nx68, nx70, nx76, nx88, nx92, nx96, nx100, nx114, nx118, 
         nx122, r_runDisp, nx124, nx128, nx130, nx138, nx144, nx172, nx174, 
         nx182, nx194, nx198, nx208, nx260, nx278, nx290, nx296, nx308, nx314, 
         nx324, nx330, nx338, nx348, nx352, nx354, nx366, nx372, nx384, nx394, 
         nx398, nx408, nx418, nx428, nx432, nx440, nx448, nx454, nx460, nx476, 
         nx484, nx498, nx520, nx528, nx534, nx540, nx544, nx548, nx558, nx568, 
         nx578, nx582, nx590, nx598, nx604, nx610, nx626, nx634, nx648, nx670, 
         nx678, nx684, nx690, nx722, nx754, nx762, nx768, nx774, nx776, nx786, 
         nx792, nx796, nx802, nx806, nx810, nx818, nx838, nx840, nx856, nx858, 
         nx874, nx876, nx928, nx942, nx966, nx976, nx984, nx990, nx996, nx998, 
         nx1008, nx1014, nx1018, nx1024, nx1028, nx1032, nx1040, nx1060, nx1062, 
         nx1078, nx1080, nx1096, nx1098, nx1150, nx1164, nx1188, nx1198, nx2200, 
         nx2205, nx2207, nx2213, nx2220, nx2222, nx2228, nx2234, nx2236, nx2238, 
         nx2242, nx2244, nx2250, nx2261, nx2263, nx2266, nx2268, nx2270, nx2281, 
         nx2283, nx2290, nx2297, nx2300, nx2303, nx2312, nx2319, nx2321, nx2323, 
         nx2325, nx2327, nx2330, nx2332, nx2334, nx2337, nx2340, nx2342, nx2344, 
         nx2347, nx2360, nx2362, nx2365, nx2367, nx2369, nx2372, nx2374, nx2377, 
         nx2380, nx2384, nx2393, nx2401, nx2403, nx2405, nx2407, nx2410, nx2412, 
         nx2415, nx2417, nx2420, nx2422, nx2427, nx2429, nx2432, nx2435, nx2437, 
         nx2440, nx2443, nx2450, nx2458, nx2460, nx2462, nx2464, nx2467, nx2469, 
         nx2472, nx2474, nx2477, nx2479, nx2484, nx2486, nx2489, nx2492, nx2494, 
         nx2497, nx2500, nx2507, nx2510, nx2512, nx2517, nx2520, nx2522, nx2527, 
         nx2530, nx2534, nx2549, nx2552, nx2558, nx2561, nx2563, nx2566, nx2570, 
         nx2576, nx2578, nx2584, nx2586, nx2591, nx2593, nx2595, nx2597, nx2599, 
         nx2604, nx2609, nx2612, nx2614, nx2616, nx2618, nx2623, nx2626, nx2630, 
         nx2645, nx2648, nx2654, nx2657, nx2659, nx2662, nx2666, nx2672, nx2674, 
         nx2680, nx2682, nx2687, nx2689, nx2691, nx2693, nx2695, nx2700, nx2705, 
         nx2708, nx2710, nx2712, nx2714, nx2747, nx126, nx2748, nx2749, nx2750, 
         nx2751, nx134, nx2752, nx2753, nx2218, nx2754, nx2755, nx2756, nx2757, 
         nx2758, nx2759, nx2760, nx2761, nx2762, nx2763, nx2764, nx2765, nx2766, 
         nx2767, nx2768, nx2769, nx274, nx2770, nx2771, nx2772, nx2314, nx2773, 
         nx2774, nx2775, nx2776, nx2777, nx2778, nx82, nx2292, nx2779, nx2780, 
         nx2781, nx2782, nx2783, nx80, nx38, nx2286, nx2784, nx2785, nx2786, 
         nx2787, nx2788, nx2789, nx2790, nx2791, nx2792, nx2793, nx2794, nx2795, 
         nx2796, nx2797, nx2798, nx2799, nx2800, nx2801, nx2802, nx2803, nx2804, 
         nx2805, nx2806, nx2807, nx2808, nx2809, nx2810, nx2256, nx2811, nx2812, 
         nx2813, nx2814, nx2815, nx2816, nx62, nx14, nx2817, nx20, nx2259, nx8, 
         nx2818, nx2819, nx2820, nx2821, nx2822, nx28, nx2823, nx2824, nx2825, 
         nx2826, nx24, nx2827, nx60, nx2828, nx2829, nx2830, nx2831, nx2832, 
         nx2833, nx390, nx150, nx2834, nx156, nx2232, nx188, nx2835, nx2836, 
         nx2837, nx2838, nx2839, nx166, nx2840, nx2841, nx2842, nx2843, nx160, 
         nx2844, nx250, nx2845, nx2846, nx2847, nx2848, nx2849, nx2850, nx2851;
    wire [21:0] \$dummy ;




    DFFC reg_r_dispErr_0 (.Q (dispErr[0]), .QB (\$dummy [0]), .D (nx314), .CLK (
         clk), .CLR (rstN)) ;
    Nand3 ix315 (.OUT (nx314), .A (nx2200), .B (nx2334), .C (nx2347)) ;
    Nand2 ix2201 (.OUT (nx2200), .A (r_runDisp), .B (nx308)) ;
    DFFC reg_r_runDisp (.Q (r_runDisp), .QB (nx2321), .D (nx274), .CLK (clk), .CLR (
         rstN)) ;
    Inv ix2206 (.OUT (nx2205), .A (dataIn[18])) ;
    Inv ix2208 (.OUT (nx2207), .A (dataIn[19])) ;
    Inv ix2214 (.OUT (nx2213), .A (dataIn[16])) ;
    Inv ix2221 (.OUT (nx2220), .A (dataIn[14])) ;
    Inv ix2223 (.OUT (nx2222), .A (dataIn[15])) ;
    Nand2 ix199 (.OUT (nx198), .A (nx194), .B (nx2238)) ;
    Inv ix2229 (.OUT (nx2228), .A (dataIn[12])) ;
    Inv ix2235 (.OUT (nx2234), .A (dataIn[10])) ;
    Inv ix2237 (.OUT (nx2236), .A (dataIn[11])) ;
    Inv ix2239 (.OUT (nx2238), .A (dataIn[13])) ;
    Inv ix2243 (.OUT (nx2242), .A (dataIn[8])) ;
    Inv ix2245 (.OUT (nx2244), .A (dataIn[9])) ;
    Inv ix2251 (.OUT (nx2250), .A (dataIn[6])) ;
    Inv ix2262 (.OUT (nx2261), .A (dataIn[0])) ;
    Inv ix2264 (.OUT (nx2263), .A (dataIn[1])) ;
    Inv ix2267 (.OUT (nx2266), .A (dataIn[2])) ;
    Inv ix2271 (.OUT (nx2270), .A (dataIn[3])) ;
    Inv ix2282 (.OUT (nx2281), .A (dataIn[4])) ;
    Inv ix2284 (.OUT (nx2283), .A (dataIn[5])) ;
    Nand2 ix209 (.OUT (nx208), .A (nx32), .B (nx2270)) ;
    Nand2 ix2291 (.OUT (nx2290), .A (nx114), .B (nx62)) ;
    Inv ix2298 (.OUT (nx2297), .A (dataIn[7])) ;
    Nand2 ix261 (.OUT (nx260), .A (nx2300), .B (nx182)) ;
    AOI22 ix2301 (.OUT (nx2300), .A (dataIn[13]), .B (nx172), .C (nx250), .D (
          nx174)) ;
    Nand2 ix183 (.OUT (nx182), .A (dataIn[14]), .B (dataIn[15])) ;
    Nand2 ix2313 (.OUT (nx2312), .A (nx172), .B (nx174)) ;
    Inv ix2320 (.OUT (nx2319), .A (dataIn[17])) ;
    Nand2 ix309 (.OUT (nx308), .A (nx2323), .B (nx2332)) ;
    AOI22 ix2324 (.OUT (nx2323), .A (dataIn[2]), .B (nx2828), .C (nx2325), .D (
          nx296)) ;
    AOI22 ix2326 (.OUT (nx2325), .A (nx32), .B (nx38), .C (nx60), .D (nx2327)) ;
    Nor2 ix2328 (.OUT (nx2327), .A (dataIn[4]), .B (dataIn[5])) ;
    Nand2 ix297 (.OUT (nx296), .A (nx2330), .B (nx2292)) ;
    Nand2 ix2331 (.OUT (nx2330), .A (dataIn[7]), .B (dataIn[6])) ;
    AOI22 ix2333 (.OUT (nx2332), .A (nx114), .B (nx62), .C (nx60), .D (nx2789)
          ) ;
    Nand2 ix2335 (.OUT (nx2334), .A (nx2321), .B (nx290)) ;
    Nand2 ix291 (.OUT (nx290), .A (nx2337), .B (nx2325)) ;
    AOI22 ix2338 (.OUT (nx2337), .A (nx2266), .B (nx14), .C (nx2332), .D (nx278)
          ) ;
    Nand2 ix279 (.OUT (nx278), .A (nx2340), .B (nx2342)) ;
    AOI22 ix2343 (.OUT (nx2342), .A (nx80), .B (nx2344), .C (nx70), .D (nx76)) ;
    Nor2 ix2345 (.OUT (nx2344), .A (dataIn[8]), .B (dataIn[9])) ;
    Nor2 ix77 (.OUT (nx76), .A (dataIn[7]), .B (dataIn[6])) ;
    AOI22 ix2348 (.OUT (nx2347), .A (nx100), .B (nx118), .C (nx68), .D (nx88)) ;
    DFFC reg_r_dispErr_1 (.Q (dispErr[1]), .QB (\$dummy [1]), .D (nx390), .CLK (
         clk), .CLR (rstN)) ;
    Nand2 ix367 (.OUT (nx366), .A (nx2360), .B (nx2372)) ;
    AOI22 ix2361 (.OUT (nx2360), .A (nx2228), .B (nx150), .C (nx2362), .D (nx354
          )) ;
    AOI22 ix2363 (.OUT (nx2362), .A (nx172), .B (nx174), .C (nx250), .D (nx2773)
          ) ;
    Nand2 ix355 (.OUT (nx354), .A (nx2365), .B (nx2367)) ;
    AOI22 ix2368 (.OUT (nx2367), .A (nx134), .B (nx2369), .C (nx128), .D (nx330)
          ) ;
    Nor2 ix2370 (.OUT (nx2369), .A (dataIn[18]), .B (dataIn[19])) ;
    Nor2 ix331 (.OUT (nx330), .A (dataIn[17]), .B (dataIn[16])) ;
    AOI22 ix2373 (.OUT (nx2372), .A (nx194), .B (nx182), .C (nx250), .D (nx2374)
          ) ;
    Nor2 ix2375 (.OUT (nx2374), .A (dataIn[14]), .B (dataIn[15])) ;
    Nand2 ix385 (.OUT (nx384), .A (nx2377), .B (nx2362)) ;
    AOI22 ix2378 (.OUT (nx2377), .A (dataIn[12]), .B (nx2845), .C (nx2372), .D (
          nx372)) ;
    Nand2 ix373 (.OUT (nx372), .A (nx2380), .B (nx2314)) ;
    Nand2 ix2381 (.OUT (nx2380), .A (dataIn[17]), .B (dataIn[16])) ;
    AOI22 ix2385 (.OUT (nx2384), .A (nx138), .B (nx348), .C (nx324), .D (nx338)
          ) ;
    DFFC reg_r_codeErr_0 (.Q (codeErr[0]), .QB (\$dummy [2]), .D (nx540), .CLK (
         clk), .CLR (rstN)) ;
    Nand4 ix541 (.OUT (nx540), .A (nx2393), .B (nx2410), .C (nx2432), .D (nx2440
          )) ;
    Nor3 ix2394 (.OUT (nx2393), .A (nx534), .B (nx122), .C (nx528)) ;
    Nor2 ix535 (.OUT (nx534), .A (nx20), .B (nx46)) ;
    Nand2 ix47 (.OUT (nx46), .A (dataIn[2]), .B (dataIn[3])) ;
    AO22 ix529 (.OUT (nx528), .A (nx14), .B (nx8), .C (nx2789), .D (nx520)) ;
    Nand4 ix521 (.OUT (nx520), .A (nx2401), .B (nx2403), .C (nx2405), .D (nx2407
          )) ;
    Nand3 ix2402 (.OUT (nx2401), .A (dataIn[8]), .B (dataIn[7]), .C (dataIn[6])
          ) ;
    AOI22 ix2404 (.OUT (nx2403), .A (nx2828), .B (nx28), .C (nx2268), .D (nx24)
          ) ;
    Nand3 ix2406 (.OUT (nx2405), .A (nx76), .B (nx2242), .C (nx2268)) ;
    Nand3 ix2408 (.OUT (nx2407), .A (nx498), .B (nx2266), .C (nx14)) ;
    Nand2 ix499 (.OUT (nx498), .A (nx2330), .B (nx2292)) ;
    Mux2 ix2411 (.OUT (nx2410), .A (nx2412), .B (nx2427), .SEL (dataIn[5])) ;
    AOI22 ix2413 (.OUT (nx2412), .A (nx2281), .B (nx484), .C (nx454), .D (nx476)
          ) ;
    Nand2 ix485 (.OUT (nx484), .A (nx2415), .B (nx2422)) ;
    Nand2 ix2416 (.OUT (nx2415), .A (nx2417), .B (nx448)) ;
    AOI22 ix2418 (.OUT (nx2417), .A (nx14), .B (nx28), .C (nx8), .D (nx24)) ;
    Nor2 ix449 (.OUT (nx448), .A (nx2297), .B (nx2420)) ;
    Nand2 ix2421 (.OUT (nx2420), .A (dataIn[9]), .B (dataIn[8])) ;
    Nand2 ix2423 (.OUT (nx2422), .A (nx2297), .B (nx2344)) ;
    Nor2 ix477 (.OUT (nx476), .A (nx428), .B (nx2268)) ;
    Nor3 ix429 (.OUT (nx428), .A (dataIn[4]), .B (dataIn[3]), .C (dataIn[2])) ;
    AOI22 ix2428 (.OUT (nx2427), .A (nx2429), .B (nx448), .C (dataIn[4]), .D (
          nx460)) ;
    AO22 ix461 (.OUT (nx460), .A (dataIn[7]), .B (nx96), .C (nx2403), .D (nx454)
         ) ;
    AOI22 ix2433 (.OUT (nx2432), .A (nx92), .B (nx440), .C (nx76), .D (nx418)) ;
    Nand2 ix441 (.OUT (nx440), .A (nx2435), .B (nx2420)) ;
    AOI22 ix2436 (.OUT (nx2435), .A (dataIn[8]), .B (nx2437), .C (nx118), .D (
          nx2344)) ;
    AO22 ix419 (.OUT (nx418), .A (nx2242), .B (nx2244), .C (nx68), .D (nx96)) ;
    Nand2 ix2441 (.OUT (nx2440), .A (nx2327), .B (nx408)) ;
    Nand2 ix409 (.OUT (nx408), .A (nx2443), .B (nx2417)) ;
    AOI22 ix2444 (.OUT (nx2443), .A (nx2242), .B (nx76), .C (nx394), .D (nx398)
          ) ;
    Nand2 ix395 (.OUT (nx394), .A (nx2340), .B (nx2342)) ;
    Nor2 ix399 (.OUT (nx398), .A (nx2266), .B (nx20)) ;
    DFFC reg_r_codeErr_1 (.Q (codeErr[1]), .QB (\$dummy [3]), .D (nx690), .CLK (
         clk), .CLR (rstN)) ;
    Nand4 ix691 (.OUT (nx690), .A (nx2450), .B (nx2467), .C (nx2489), .D (nx2497
          )) ;
    Nor3 ix2451 (.OUT (nx2450), .A (nx684), .B (nx352), .C (nx678)) ;
    Nor2 ix685 (.OUT (nx684), .A (nx156), .B (nx144)) ;
    Nand2 ix145 (.OUT (nx144), .A (dataIn[12]), .B (dataIn[13])) ;
    AO22 ix679 (.OUT (nx678), .A (nx150), .B (nx188), .C (nx2773), .D (nx670)) ;
    Nand4 ix671 (.OUT (nx670), .A (nx2458), .B (nx2460), .C (nx2462), .D (nx2464
          )) ;
    Nand3 ix2459 (.OUT (nx2458), .A (dataIn[18]), .B (dataIn[17]), .C (
          dataIn[16])) ;
    AOI22 ix2461 (.OUT (nx2460), .A (nx2845), .B (nx166), .C (nx2303), .D (nx160
          )) ;
    Nand3 ix2463 (.OUT (nx2462), .A (nx330), .B (nx2205), .C (nx2303)) ;
    Nand3 ix2465 (.OUT (nx2464), .A (nx648), .B (nx2228), .C (nx150)) ;
    Nand2 ix649 (.OUT (nx648), .A (nx2380), .B (nx2314)) ;
    Mux2 ix2468 (.OUT (nx2467), .A (nx2469), .B (nx2484), .SEL (dataIn[15])) ;
    AOI22 ix2470 (.OUT (nx2469), .A (nx2220), .B (nx634), .C (nx604), .D (nx626)
          ) ;
    Nand2 ix635 (.OUT (nx634), .A (nx2472), .B (nx2479)) ;
    Nand2 ix2473 (.OUT (nx2472), .A (nx2474), .B (nx598)) ;
    AOI22 ix2475 (.OUT (nx2474), .A (nx150), .B (nx166), .C (nx188), .D (nx160)
          ) ;
    Nor2 ix599 (.OUT (nx598), .A (nx2319), .B (nx2477)) ;
    Nand2 ix2478 (.OUT (nx2477), .A (dataIn[19]), .B (dataIn[18])) ;
    Nand2 ix2480 (.OUT (nx2479), .A (nx2319), .B (nx2369)) ;
    Nor2 ix627 (.OUT (nx626), .A (nx578), .B (nx2303)) ;
    Nor3 ix579 (.OUT (nx578), .A (dataIn[14]), .B (dataIn[13]), .C (dataIn[12])
         ) ;
    AOI22 ix2485 (.OUT (nx2484), .A (nx2486), .B (nx598), .C (dataIn[14]), .D (
          nx610)) ;
    AO22 ix611 (.OUT (nx610), .A (dataIn[17]), .B (nx124), .C (nx2460), .D (
         nx604)) ;
    AOI22 ix2490 (.OUT (nx2489), .A (nx130), .B (nx590), .C (nx330), .D (nx568)
          ) ;
    Nand2 ix591 (.OUT (nx590), .A (nx2492), .B (nx2477)) ;
    AOI22 ix2493 (.OUT (nx2492), .A (dataIn[18]), .B (nx2494), .C (nx348), .D (
          nx2369)) ;
    AO22 ix569 (.OUT (nx568), .A (nx2205), .B (nx2207), .C (nx324), .D (nx124)
         ) ;
    Nand2 ix2498 (.OUT (nx2497), .A (nx2374), .B (nx558)) ;
    Nand2 ix559 (.OUT (nx558), .A (nx2500), .B (nx2474)) ;
    AOI22 ix2501 (.OUT (nx2500), .A (nx2205), .B (nx330), .C (nx544), .D (nx548)
          ) ;
    Nand2 ix545 (.OUT (nx544), .A (nx2365), .B (nx2367)) ;
    Nor2 ix549 (.OUT (nx548), .A (nx2228), .B (nx156)) ;
    DFFC reg_r_dataKOut_0 (.Q (dataKOut[0]), .QB (\$dummy [4]), .D (nx722), .CLK (
         clk), .CLR (rstN)) ;
    Nand4 ix723 (.OUT (nx722), .A (nx2507), .B (nx432), .C (nx2510), .D (nx2512)
          ) ;
    Nand2 ix2508 (.OUT (nx2507), .A (nx2789), .B (nx2268)) ;
    Nand2 ix433 (.OUT (nx432), .A (nx428), .B (nx2283)) ;
    Nand4 ix2511 (.OUT (nx2510), .A (nx2283), .B (dataIn[4]), .C (nx114), .D (
          nx454)) ;
    Nand4 ix2513 (.OUT (nx2512), .A (dataIn[5]), .B (nx2281), .C (nx32), .D (
          nx448)) ;
    DFFC reg_r_dataKOut_1 (.Q (dataKOut[1]), .QB (\$dummy [5]), .D (nx754), .CLK (
         clk), .CLR (rstN)) ;
    Nand4 ix755 (.OUT (nx754), .A (nx2517), .B (nx582), .C (nx2520), .D (nx2522)
          ) ;
    Nand2 ix2518 (.OUT (nx2517), .A (nx2773), .B (nx2303)) ;
    Nand2 ix583 (.OUT (nx582), .A (nx578), .B (nx2222)) ;
    Nand4 ix2521 (.OUT (nx2520), .A (nx2222), .B (dataIn[14]), .C (nx172), .D (
          nx604)) ;
    Nand4 ix2523 (.OUT (nx2522), .A (dataIn[15]), .B (nx2220), .C (nx194), .D (
          nx598)) ;
    DFFC reg_r_dataOut_0 (.Q (dataOut[0]), .QB (\$dummy [6]), .D (nx802), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix803 (.out (nx802), .A (dataIn[0]), .B (nx2527)) ;
    Nor4 ix2528 (.OUT (nx2527), .A (nx796), .B (nx786), .C (nx776), .D (nx762)
         ) ;
    Nand2 ix797 (.OUT (nx796), .A (nx2530), .B (nx432)) ;
    Nor2 ix777 (.OUT (nx776), .A (nx2828), .B (nx2534)) ;
    Nor2 ix763 (.OUT (nx762), .A (nx20), .B (nx38)) ;
    DFFC reg_r_dataOut_1 (.Q (dataOut[1]), .QB (\$dummy [7]), .D (nx818), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix819 (.out (nx818), .A (dataIn[1]), .B (nx2549)) ;
    Nor4 ix2550 (.OUT (nx2549), .A (nx796), .B (nx786), .C (nx810), .D (nx762)
         ) ;
    Nor2 ix811 (.OUT (nx810), .A (nx14), .B (nx2552)) ;
    DFFC reg_r_dataOut_2 (.Q (dataOut[2]), .QB (\$dummy [8]), .D (nx840), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix841 (.out (nx840), .A (dataIn[2]), .B (nx838)) ;
    Nand4 ix839 (.OUT (nx838), .A (nx2558), .B (nx2561), .C (nx2563), .D (nx2570
          )) ;
    Nor3 ix793 (.OUT (nx792), .A (nx38), .B (nx2270), .C (nx2417)) ;
    AOI22 ix2562 (.OUT (nx2561), .A (nx2281), .B (nx32), .C (dataIn[5]), .D (
          nx114)) ;
    AOI22 ix2564 (.OUT (nx2563), .A (nx2261), .B (nx774), .C (dataIn[1]), .D (
          nx806)) ;
    Nor2 ix775 (.OUT (nx774), .A (dataIn[2]), .B (nx2566)) ;
    Nand2 ix2567 (.OUT (nx2566), .A (nx60), .B (nx768)) ;
    Nor2 ix807 (.OUT (nx806), .A (nx2266), .B (nx2566)) ;
    Nand2 ix2571 (.OUT (nx2570), .A (nx14), .B (nx2327)) ;
    DFFC reg_r_dataOut_3 (.Q (dataOut[3]), .QB (\$dummy [9]), .D (nx858), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix859 (.out (nx858), .A (dataIn[3]), .B (nx856)) ;
    Nand4 ix857 (.OUT (nx856), .A (nx2558), .B (nx2561), .C (nx2576), .D (nx2578
          )) ;
    AOI22 ix2577 (.OUT (nx2576), .A (nx2263), .B (nx774), .C (dataIn[0]), .D (
          nx806)) ;
    DFFC reg_r_dataOut_4 (.Q (dataOut[4]), .QB (\$dummy [10]), .D (nx876), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix877 (.out (nx876), .A (dataIn[4]), .B (nx874)) ;
    Nand3 ix875 (.OUT (nx874), .A (nx2584), .B (nx2558), .C (nx2586)) ;
    Nand2 ix2585 (.OUT (nx2584), .A (nx14), .B (nx2327)) ;
    AOI22 ix2587 (.OUT (nx2586), .A (nx32), .B (nx38), .C (nx20), .D (nx774)) ;
    DFFC reg_r_dataOut_5 (.Q (dataOut[5]), .QB (\$dummy [11]), .D (nx928), .CLK (
         clk), .CLR (rstN)) ;
    Nand3 ix929 (.OUT (nx928), .A (nx2591), .B (nx2593), .C (nx2595)) ;
    Mux2 ix2592 (.OUT (nx2591), .A (nx2340), .B (nx2330), .SEL (dataIn[9])) ;
    Mux2 ix2594 (.OUT (nx2593), .A (nx82), .B (nx2420), .SEL (dataIn[6])) ;
    Mux2 ix2596 (.OUT (nx2595), .A (nx2597), .B (nx2599), .SEL (nx432)) ;
    AOI22 ix2598 (.OUT (nx2597), .A (nx2242), .B (nx2297), .C (nx2244), .D (
          dataIn[6])) ;
    AOI22 ix2600 (.OUT (nx2599), .A (dataIn[8]), .B (dataIn[7]), .C (dataIn[9])
          , .D (nx2250)) ;
    DFFC reg_r_dataOut_6 (.Q (dataOut[6]), .QB (\$dummy [12]), .D (nx942), .CLK (
         clk), .CLR (rstN)) ;
    Nand3 ix943 (.OUT (nx942), .A (nx2591), .B (nx2593), .C (nx2604)) ;
    Mux2 ix2605 (.OUT (nx2604), .A (nx2599), .B (nx2597), .SEL (nx432)) ;
    DFFC reg_r_dataOut_7 (.Q (dataOut[7]), .QB (\$dummy [13]), .D (nx976), .CLK (
         clk), .CLR (rstN)) ;
    Nand2 ix977 (.OUT (nx976), .A (nx2609), .B (nx2618)) ;
    AOI22 ix2610 (.OUT (nx2609), .A (nx2250), .B (nx448), .C (nx70), .D (nx966)
          ) ;
    Nand2 ix967 (.OUT (nx966), .A (nx2612), .B (nx80)) ;
    Mux2 ix2613 (.OUT (nx2612), .A (nx2614), .B (nx2616), .SEL (nx432)) ;
    Nor2 ix2615 (.OUT (nx2614), .A (dataIn[8]), .B (nx2244)) ;
    Nor2 ix2617 (.OUT (nx2616), .A (nx2242), .B (dataIn[9])) ;
    Nand2 ix2619 (.OUT (nx2618), .A (dataIn[6]), .B (nx454)) ;
    DFFC reg_r_dataOut_8 (.Q (dataOut[8]), .QB (\$dummy [14]), .D (nx1024), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix1025 (.out (nx1024), .A (dataIn[10]), .B (nx2623)) ;
    Nor4 ix2624 (.OUT (nx2623), .A (nx1018), .B (nx1008), .C (nx998), .D (nx984)
         ) ;
    Nand2 ix1019 (.OUT (nx1018), .A (nx2626), .B (nx582)) ;
    Nor2 ix999 (.OUT (nx998), .A (nx2845), .B (nx2630)) ;
    Nor2 ix985 (.OUT (nx984), .A (nx156), .B (nx182)) ;
    DFFC reg_r_dataOut_9 (.Q (dataOut[9]), .QB (\$dummy [15]), .D (nx1040), .CLK (
         clk), .CLR (rstN)) ;
    Xnor2 ix1041 (.out (nx1040), .A (dataIn[11]), .B (nx2645)) ;
    Nor4 ix2646 (.OUT (nx2645), .A (nx1018), .B (nx1008), .C (nx1032), .D (nx984
         )) ;
    Nor2 ix1033 (.OUT (nx1032), .A (nx150), .B (nx2648)) ;
    DFFC reg_r_dataOut_10 (.Q (dataOut[10]), .QB (\$dummy [16]), .D (nx1062), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix1063 (.out (nx1062), .A (dataIn[12]), .B (nx1060)) ;
    Nand4 ix1061 (.OUT (nx1060), .A (nx2654), .B (nx2657), .C (nx2659), .D (
          nx2666)) ;
    Nor3 ix1015 (.OUT (nx1014), .A (nx182), .B (nx2238), .C (nx2474)) ;
    AOI22 ix2658 (.OUT (nx2657), .A (nx2220), .B (nx194), .C (dataIn[15]), .D (
          nx172)) ;
    AOI22 ix2660 (.OUT (nx2659), .A (nx2234), .B (nx996), .C (dataIn[11]), .D (
          nx1028)) ;
    Nor2 ix997 (.OUT (nx996), .A (dataIn[12]), .B (nx2662)) ;
    Nand2 ix2663 (.OUT (nx2662), .A (nx250), .B (nx990)) ;
    Nor2 ix1029 (.OUT (nx1028), .A (nx2228), .B (nx2662)) ;
    Nand2 ix2667 (.OUT (nx2666), .A (nx150), .B (nx2374)) ;
    DFFC reg_r_dataOut_11 (.Q (dataOut[11]), .QB (\$dummy [17]), .D (nx1080), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix1081 (.out (nx1080), .A (dataIn[13]), .B (nx1078)) ;
    Nand4 ix1079 (.OUT (nx1078), .A (nx2654), .B (nx2657), .C (nx2672), .D (
          nx2674)) ;
    AOI22 ix2673 (.OUT (nx2672), .A (nx2236), .B (nx996), .C (dataIn[10]), .D (
          nx1028)) ;
    DFFC reg_r_dataOut_12 (.Q (dataOut[12]), .QB (\$dummy [18]), .D (nx1098), .CLK (
         clk), .CLR (rstN)) ;
    Xor2 ix1099 (.out (nx1098), .A (dataIn[14]), .B (nx1096)) ;
    Nand3 ix1097 (.OUT (nx1096), .A (nx2680), .B (nx2654), .C (nx2682)) ;
    Nand2 ix2681 (.OUT (nx2680), .A (nx150), .B (nx2374)) ;
    AOI22 ix2683 (.OUT (nx2682), .A (nx194), .B (nx182), .C (nx156), .D (nx996)
          ) ;
    DFFC reg_r_dataOut_13 (.Q (dataOut[13]), .QB (\$dummy [19]), .D (nx1150), .CLK (
         clk), .CLR (rstN)) ;
    Nand3 ix1151 (.OUT (nx1150), .A (nx2687), .B (nx2689), .C (nx2691)) ;
    Mux2 ix2688 (.OUT (nx2687), .A (nx2365), .B (nx2380), .SEL (dataIn[19])) ;
    Mux2 ix2690 (.OUT (nx2689), .A (nx2770), .B (nx2477), .SEL (dataIn[16])) ;
    Mux2 ix2692 (.OUT (nx2691), .A (nx2693), .B (nx2695), .SEL (nx582)) ;
    AOI22 ix2694 (.OUT (nx2693), .A (nx2205), .B (nx2319), .C (nx2207), .D (
          dataIn[16])) ;
    AOI22 ix2696 (.OUT (nx2695), .A (dataIn[18]), .B (dataIn[17]), .C (
          dataIn[19]), .D (nx2213)) ;
    DFFC reg_r_dataOut_14 (.Q (dataOut[14]), .QB (\$dummy [20]), .D (nx1164), .CLK (
         clk), .CLR (rstN)) ;
    Nand3 ix1165 (.OUT (nx1164), .A (nx2687), .B (nx2689), .C (nx2700)) ;
    Mux2 ix2701 (.OUT (nx2700), .A (nx2695), .B (nx2693), .SEL (nx582)) ;
    DFFC reg_r_dataOut_15 (.Q (dataOut[15]), .QB (\$dummy [21]), .D (nx1198), .CLK (
         clk), .CLR (rstN)) ;
    Nand2 ix1199 (.OUT (nx1198), .A (nx2705), .B (nx2714)) ;
    AOI22 ix2706 (.OUT (nx2705), .A (nx2213), .B (nx598), .C (nx128), .D (nx1188
          )) ;
    Nand2 ix1189 (.OUT (nx1188), .A (nx2708), .B (nx134)) ;
    Mux2 ix2709 (.OUT (nx2708), .A (nx2710), .B (nx2712), .SEL (nx582)) ;
    Nor2 ix2711 (.OUT (nx2710), .A (dataIn[18]), .B (nx2207)) ;
    Nor2 ix2713 (.OUT (nx2712), .A (nx2205), .B (dataIn[19])) ;
    Nand2 ix2715 (.OUT (nx2714), .A (dataIn[16]), .B (nx604)) ;
    Inv ix2649 (.OUT (nx2648), .A (nx1028)) ;
    Inv ix2655 (.OUT (nx2654), .A (nx1018)) ;
    Inv ix2627 (.OUT (nx2626), .A (nx1014)) ;
    Inv ix1009 (.OUT (nx1008), .A (nx2657)) ;
    Inv ix2631 (.OUT (nx2630), .A (nx996)) ;
    Inv ix2675 (.OUT (nx2674), .A (nx984)) ;
    Inv ix2553 (.OUT (nx2552), .A (nx806)) ;
    Inv ix2559 (.OUT (nx2558), .A (nx796)) ;
    Inv ix2531 (.OUT (nx2530), .A (nx792)) ;
    Inv ix787 (.OUT (nx786), .A (nx2561)) ;
    Inv ix2535 (.OUT (nx2534), .A (nx774)) ;
    Inv ix2579 (.OUT (nx2578), .A (nx762)) ;
    Inv ix605 (.OUT (nx604), .A (nx2479)) ;
    Inv ix2495 (.OUT (nx2494), .A (nx582)) ;
    Inv ix2487 (.OUT (nx2486), .A (nx578)) ;
    Inv ix455 (.OUT (nx454), .A (nx2422)) ;
    Inv ix2438 (.OUT (nx2437), .A (nx432)) ;
    Inv ix2430 (.OUT (nx2429), .A (nx428)) ;
    Inv ix353 (.OUT (nx352), .A (nx2384)) ;
    Inv ix349 (.OUT (nx348), .A (nx2362)) ;
    Inv ix339 (.OUT (nx338), .A (nx2367)) ;
    Inv ix2366 (.OUT (nx2365), .A (nx330)) ;
    Inv ix325 (.OUT (nx324), .A (nx2372)) ;
    Inv ix195 (.OUT (nx194), .A (nx2474)) ;
    Inv ix175 (.OUT (nx174), .A (nx2374)) ;
    Inv ix173 (.OUT (nx172), .A (nx2460)) ;
    Inv ix2304 (.OUT (nx2303), .A (nx144)) ;
    Inv ix139 (.OUT (nx138), .A (nx2314)) ;
    Inv ix131 (.OUT (nx130), .A (nx2380)) ;
    Inv ix125 (.OUT (nx124), .A (nx2477)) ;
    Inv ix123 (.OUT (nx122), .A (nx2347)) ;
    Inv ix119 (.OUT (nx118), .A (nx2332)) ;
    Inv ix115 (.OUT (nx114), .A (nx2403)) ;
    Inv ix101 (.OUT (nx100), .A (nx2292)) ;
    Inv ix97 (.OUT (nx96), .A (nx2420)) ;
    Inv ix93 (.OUT (nx92), .A (nx2330)) ;
    Inv ix89 (.OUT (nx88), .A (nx2342)) ;
    Inv ix2341 (.OUT (nx2340), .A (nx76)) ;
    Inv ix69 (.OUT (nx68), .A (nx2325)) ;
    Inv ix2269 (.OUT (nx2268), .A (nx46)) ;
    Inv ix33 (.OUT (nx32), .A (nx2417)) ;
    Xor2 ix71 (.out (nx70), .A (dataIn[9]), .B (dataIn[8])) ;
    Xor2 ix129 (.out (nx128), .A (dataIn[19]), .B (dataIn[18])) ;
    Nand2 ix2544 (.OUT (nx768), .A (nx38), .B (nx62)) ;
    Nand2 ix2640 (.OUT (nx990), .A (nx182), .B (nx174)) ;
    BufI4 ix2852 (.OUT (nx2747), .A (nx260)) ;
    BufI4 reg_nx126 (.OUT (nx126), .A (nx2369)) ;
    BufI4 ix2853 (.OUT (nx2748), .A (dataIn[16])) ;
    Nand2 ix2854 (.OUT (nx2749), .A (dataIn[17]), .B (nx2748)) ;
    BufI4 ix2855 (.OUT (nx2750), .A (dataIn[17])) ;
    Nand2 ix2856 (.OUT (nx2751), .A (dataIn[16]), .B (nx2750)) ;
    Nand2 reg_nx134 (.OUT (nx134), .A (nx2749), .B (nx2751)) ;
    Nand2 ix2857 (.OUT (nx2752), .A (nx126), .B (nx134)) ;
    Nor2 ix2858 (.OUT (nx2753), .A (nx2747), .B (nx2752)) ;
    BufI4 reg_nx2218 (.OUT (nx2218), .A (nx182)) ;
    Nand2 ix2859 (.OUT (nx2754), .A (nx198), .B (nx2218)) ;
    Nand2 ix2860 (.OUT (nx2755), .A (nx2312), .B (nx2754)) ;
    AOI22 ix2861 (.OUT (nx2756), .A (dataIn[16]), .B (nx2750), .C (dataIn[17]), 
          .D (nx2748)) ;
    Nor2 ix2862 (.OUT (nx2757), .A (nx2369), .B (nx2756)) ;
    Nand2 ix2863 (.OUT (nx2758), .A (nx2755), .B (nx2757)) ;
    BufI4 ix2864 (.OUT (nx2759), .A (nx2369)) ;
    Nor2 ix2865 (.OUT (nx2760), .A (dataIn[17]), .B (dataIn[16])) ;
    BufI4 ix2866 (.OUT (nx2761), .A (nx2760)) ;
    Nand2 ix2867 (.OUT (nx2762), .A (dataIn[17]), .B (dataIn[16])) ;
    Nand3 ix2868 (.OUT (nx2763), .A (nx124), .B (nx2761), .C (nx2762)) ;
    BufI4 ix2869 (.OUT (nx2764), .A (nx128)) ;
    BufI4 ix2870 (.OUT (nx2765), .A (nx130)) ;
    AOI22 ix2871 (.OUT (nx2766), .A (nx2763), .B (nx2764), .C (nx2763), .D (
          nx2765)) ;
    AOI22 ix2872 (.OUT (nx2767), .A (nx2759), .B (nx2766), .C (dataIn[19]), .D (
          dataIn[18])) ;
    Nand2 ix2873 (.OUT (nx2768), .A (nx2758), .B (nx2767)) ;
    BufI4 ix2874 (.OUT (nx2769), .A (nx2768)) ;
    Nand2 reg_nx274 (.OUT (nx274), .A (nx2791), .B (nx2769)) ;
    BufI4 ix2875 (.OUT (nx2770), .A (nx2369)) ;
    Nand2 ix2876 (.OUT (nx2771), .A (nx2763), .B (nx2765)) ;
    Nand2 ix2877 (.OUT (nx2772), .A (nx2763), .B (nx2764)) ;
    Nand2 reg_nx2314 (.OUT (nx2314), .A (nx2771), .B (nx2772)) ;
    BufI4 ix2878 (.OUT (nx2773), .A (nx182)) ;
    Nand2 ix2879 (.OUT (nx2774), .A (dataIn[9]), .B (dataIn[8])) ;
    Nand2 ix2880 (.OUT (nx2775), .A (nx2344), .B (nx2774)) ;
    Nand2 ix2881 (.OUT (nx2776), .A (nx70), .B (nx92)) ;
    Nand2 ix2882 (.OUT (nx2777), .A (nx80), .B (nx96)) ;
    Nand3 ix2883 (.OUT (nx2778), .A (nx2774), .B (nx2776), .C (nx2777)) ;
    BufI4 reg_nx82 (.OUT (nx82), .A (nx2344)) ;
    AOI22 reg_nx2292 (.OUT (nx2292), .A (nx80), .B (nx96), .C (nx70), .D (nx92)
          ) ;
    BufI4 ix2884 (.OUT (nx2779), .A (dataIn[7])) ;
    BufI4 ix2885 (.OUT (nx2780), .A (dataIn[6])) ;
    AOI22 ix2886 (.OUT (nx2781), .A (dataIn[6]), .B (nx2779), .C (dataIn[7]), .D (
          nx2780)) ;
    Nand2 ix2887 (.OUT (nx2782), .A (dataIn[7]), .B (nx2780)) ;
    Nand2 ix2888 (.OUT (nx2783), .A (dataIn[6]), .B (nx2779)) ;
    Nand2 reg_nx80 (.OUT (nx80), .A (nx2782), .B (nx2783)) ;
    Nand2 reg_nx38 (.OUT (nx38), .A (dataIn[4]), .B (dataIn[5])) ;
    BufI4 reg_nx2286 (.OUT (nx2286), .A (nx38)) ;
    Nand2 ix2889 (.OUT (nx2784), .A (nx80), .B (nx2286)) ;
    BufI4 ix2890 (.OUT (nx2785), .A (nx2784)) ;
    Nand2 ix2891 (.OUT (nx2786), .A (nx208), .B (nx2785)) ;
    BufI4 ix2892 (.OUT (nx2787), .A (nx2786)) ;
    Nor2 ix2893 (.OUT (nx2788), .A (nx2781), .B (nx2290)) ;
    BufI4 ix2894 (.OUT (nx2789), .A (nx38)) ;
    BufI4 ix2895 (.OUT (nx2790), .A (r_runDisp)) ;
    Nand4 ix2896 (.OUT (nx2791), .A (nx2803), .B (nx2753), .C (nx2775), .D (
          nx2804)) ;
    Nand2 ix2897 (.OUT (nx2792), .A (r_runDisp), .B (nx2806)) ;
    Nand2 ix2898 (.OUT (nx2793), .A (nx2805), .B (nx2792)) ;
    BufI4 ix2899 (.OUT (nx2794), .A (nx2775)) ;
    Nor3 ix2900 (.OUT (nx2795), .A (nx2784), .B (nx2794), .C (nx2790)) ;
    BufI4 ix2901 (.OUT (nx2796), .A (nx2795)) ;
    BufI4 ix2902 (.OUT (nx2797), .A (nx2787)) ;
    Nor2 ix2903 (.OUT (nx2798), .A (nx2778), .B (nx2788)) ;
    BufI4 ix2904 (.OUT (nx2799), .A (nx2787)) ;
    BufI4 ix2905 (.OUT (nx2800), .A (nx2778)) ;
    Nand2 ix2906 (.OUT (nx2801), .A (nx2784), .B (nx2800)) ;
    Nor2 ix2907 (.OUT (nx2802), .A (nx2788), .B (nx2801)) ;
    Nand3 ix2908 (.OUT (nx2803), .A (nx2816), .B (nx2799), .C (nx2802)) ;
    Nand3 ix2909 (.OUT (nx2804), .A (nx2790), .B (nx2797), .C (nx2798)) ;
    Nor3 ix2910 (.OUT (nx2805), .A (nx2787), .B (nx2778), .C (nx2788)) ;
    Nand2 ix2911 (.OUT (nx2806), .A (nx2816), .B (nx2784)) ;
    Nand2 ix2912 (.OUT (nx2807), .A (dataIn[3]), .B (nx114)) ;
    Nand2 ix2913 (.OUT (nx2808), .A (nx2327), .B (nx2807)) ;
    BufI4 ix2914 (.OUT (nx2809), .A (nx60)) ;
    Nand2 ix2915 (.OUT (nx2810), .A (nx2807), .B (nx2809)) ;
    Nand2 reg_nx2256 (.OUT (nx2256), .A (nx2808), .B (nx2810)) ;
    BufI4 ix2916 (.OUT (nx2811), .A (nx2794)) ;
    BufI4 ix2917 (.OUT (nx2812), .A (nx2781)) ;
    Nand2 ix2918 (.OUT (nx2813), .A (nx2811), .B (nx2812)) ;
    Nor3 ix2919 (.OUT (nx2814), .A (nx2790), .B (nx2256), .C (nx2813)) ;
    BufI4 ix2920 (.OUT (nx2815), .A (nx2781)) ;
    Nand3 ix2921 (.OUT (nx2816), .A (nx2810), .B (nx2808), .C (nx2815)) ;
    BufI4 reg_nx62 (.OUT (nx62), .A (nx2327)) ;
    Nor2 reg_nx14 (.OUT (nx14), .A (dataIn[0]), .B (dataIn[1])) ;
    Nand2 ix2922 (.OUT (nx2817), .A (nx2268), .B (nx14)) ;
    Nand2 reg_nx20 (.OUT (nx20), .A (dataIn[0]), .B (dataIn[1])) ;
    BufI4 reg_nx2259 (.OUT (nx2259), .A (nx20)) ;
    Nor2 reg_nx8 (.OUT (nx8), .A (dataIn[3]), .B (dataIn[2])) ;
    Nand2 ix2923 (.OUT (nx2818), .A (nx2259), .B (nx8)) ;
    BufI4 ix2924 (.OUT (nx2819), .A (dataIn[2])) ;
    Nand2 ix2925 (.OUT (nx2820), .A (dataIn[3]), .B (nx2819)) ;
    BufI4 ix2926 (.OUT (nx2821), .A (dataIn[3])) ;
    Nand2 ix2927 (.OUT (nx2822), .A (dataIn[2]), .B (nx2821)) ;
    Nand2 reg_nx28 (.OUT (nx28), .A (nx2820), .B (nx2822)) ;
    BufI4 ix2928 (.OUT (nx2823), .A (dataIn[1])) ;
    Nand2 ix2929 (.OUT (nx2824), .A (dataIn[0]), .B (nx2823)) ;
    BufI4 ix2930 (.OUT (nx2825), .A (dataIn[0])) ;
    Nand2 ix2931 (.OUT (nx2826), .A (dataIn[1]), .B (nx2825)) ;
    Nand2 reg_nx24 (.OUT (nx24), .A (nx2824), .B (nx2826)) ;
    Nand2 ix2932 (.OUT (nx2827), .A (nx28), .B (nx24)) ;
    Nand3 reg_nx60 (.OUT (nx60), .A (nx2817), .B (nx2818), .C (nx2827)) ;
    BufI4 ix2933 (.OUT (nx2828), .A (nx20)) ;
    Nand2 ix2934 (.OUT (nx2829), .A (nx384), .B (nx2775)) ;
    BufI4 ix2935 (.OUT (nx2830), .A (nx2829)) ;
    Nand2 ix2936 (.OUT (nx2831), .A (nx2793), .B (nx2830)) ;
    Nand2 ix2937 (.OUT (nx2832), .A (nx2384), .B (nx2831)) ;
    BufI4 ix2938 (.OUT (nx2833), .A (nx2832)) ;
    Nand2 reg_nx390 (.OUT (nx390), .A (nx2851), .B (nx2833)) ;
    Nor2 reg_nx150 (.OUT (nx150), .A (dataIn[11]), .B (dataIn[10])) ;
    Nand2 ix2939 (.OUT (nx2834), .A (nx2303), .B (nx150)) ;
    Nand2 reg_nx156 (.OUT (nx156), .A (dataIn[11]), .B (dataIn[10])) ;
    BufI4 reg_nx2232 (.OUT (nx2232), .A (nx156)) ;
    Nor2 reg_nx188 (.OUT (nx188), .A (dataIn[13]), .B (dataIn[12])) ;
    Nand2 ix2940 (.OUT (nx2835), .A (nx2232), .B (nx188)) ;
    BufI4 ix2941 (.OUT (nx2836), .A (dataIn[12])) ;
    Nand2 ix2942 (.OUT (nx2837), .A (dataIn[13]), .B (nx2836)) ;
    BufI4 ix2943 (.OUT (nx2838), .A (dataIn[13])) ;
    Nand2 ix2944 (.OUT (nx2839), .A (dataIn[12]), .B (nx2838)) ;
    Nand2 reg_nx166 (.OUT (nx166), .A (nx2837), .B (nx2839)) ;
    BufI4 ix2945 (.OUT (nx2840), .A (dataIn[10])) ;
    Nand2 ix2946 (.OUT (nx2841), .A (dataIn[11]), .B (nx2840)) ;
    BufI4 ix2947 (.OUT (nx2842), .A (dataIn[11])) ;
    Nand2 ix2948 (.OUT (nx2843), .A (dataIn[10]), .B (nx2842)) ;
    Nand2 reg_nx160 (.OUT (nx160), .A (nx2841), .B (nx2843)) ;
    Nand2 ix2949 (.OUT (nx2844), .A (nx166), .B (nx160)) ;
    Nand3 reg_nx250 (.OUT (nx250), .A (nx2834), .B (nx2835), .C (nx2844)) ;
    BufI4 ix2950 (.OUT (nx2845), .A (nx156)) ;
    BufI4 ix2951 (.OUT (nx2846), .A (nx2814)) ;
    Nand2 ix2952 (.OUT (nx2847), .A (nx2797), .B (nx2798)) ;
    Nand2 ix2953 (.OUT (nx2848), .A (nx2775), .B (nx2847)) ;
    Nand2 ix2954 (.OUT (nx2849), .A (nx366), .B (nx2848)) ;
    BufI4 ix2955 (.OUT (nx2850), .A (nx2849)) ;
    Nand3 ix2956 (.OUT (nx2851), .A (nx2796), .B (nx2846), .C (nx2850)) ;
endmodule

