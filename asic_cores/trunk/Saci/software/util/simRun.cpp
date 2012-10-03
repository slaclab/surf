#include <SimLink.h>
#include <SaciControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

int main (int argc, char **argv) {
   string        defFile;
   uint          shmId;
   stringstream  cmd;

   if ( argc == 1 ) {
      cout << "Usage: simRun smem_id [default.xml]" << endl;
      return(1);
   }
   shmId = atoi(argv[1]);

   if ( argc > 2 ) defFile = argv[2];
   else defFile = "";

   try {

      SimLink     simLink; 
      SaciControl saci(&simLink,defFile);

      simLink.setMaxRxTx(500000);
      simLink.setDebug(true);
      simLink.open("saci",shmId);
      usleep(100);

      // Test FPGA Read
      cout << "Fgga Version: 0x" << hex << setw(8) << setfill('0') << saci.device("cntrlFpga",0)->readSingle("Version") << endl;

      // Asic Write
      saci.device("cntrlFpga",0)->device("saciAsic",0)->writeSingle("RegA",0xa5a5a5a5);

      // Asic Read
      cout << "Read: 0x" << hex << setw(8) << setfill('0') << saci.device("cntrlFpga",0)->device("saciAsic",0)->readSingle("RegA") << endl;

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

