#include <SimLink.h>
#include <SaciControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

const uint VALUES[4] = {0, 0xa5a5a5a5, 0x5a5a5a5a, 0xffffffff};

void testPattern(SaciControl* saci, int asicNum, uint startIndex) {
   saci->device("cntrlFpga",0)->device("saciAsic",asicNum)->writeSingle("Reg_00_000",VALUES[startIndex%4]);
   saci->device("cntrlFpga",0)->device("saciAsic",asicNum)->writeSingle("Reg_2A_AAA",VALUES[(startIndex+1)%4]);
   saci->device("cntrlFpga",0)->device("saciAsic",asicNum)->writeSingle("Reg_55_555",VALUES[(startIndex+2)%4]);
   saci->device("cntrlFpga",0)->device("saciAsic",asicNum)->writeSingle("Reg_7F_FFF",VALUES[(startIndex+3)%4]);
   
   saci->device("cntrlFpga",0)->device("saciAsic",asicNum)->verifyConfig();
   cout << "Test Pattern " << startIndex << " Done.\n" << endl;
}

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

      saci.setDebug(true);

      // Test FPGA Read
      cout << "Fgga Version: 0x" << hex << setw(8) << setfill('0') << saci.device("cntrlFpga",0)->readSingle("Version") << endl;

      // Reset SACI Slaves
      cout << "Reset SACI Slaves" << endl;
      saci.device("cntrlFpga",0)->command("ResetSaciSlaves","");
      cout << "Done" << endl;

      for (int i = 0; i < 2; i++) {
         testPattern(&saci, i, 0);
         testPattern(&saci, i, 1);
         testPattern(&saci, i, 2);
         testPattern(&saci, i, 3);
      }
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

