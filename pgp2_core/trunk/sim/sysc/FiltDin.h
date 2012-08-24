#ifndef __FILT_DIN_H__
#define __FILT_DIN_H__
#include <systemc.h>
using namespace std;

// Module declaration
SC_MODULE(FiltDin) {

   // Filter Interface
   sc_in    <sc_logic  >  sysCLk;
   sc_in    <sc_logic  >  sysCLkRst;
   sc_in    <sc_logic  >  filtRfd;
   sc_out   <sc_logic  >  filtNd;
   sc_out   <sc_lv<16> >  filtDin;
   sc_in    <sc_logic  >  filtDone;

   // State count
   uint stateCnt;

   // Constructor
   SC_CTOR(FiltDin):
      sysCLk("sysCLk"),
      sysCLkRst("sysCLkRst"),
      filtRfd("filtRfd"),
      filtNd("filtNd"),
      filtDin("filtDin"),
      filtDone("filtDone")
   {

      // Setup thread
      SC_THREAD(runThread);

   }
};

#endif
