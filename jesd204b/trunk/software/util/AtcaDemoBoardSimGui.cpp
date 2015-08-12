#include <SimLink.h>
#include <AtcaDemoBoardSystem.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

// Run flag for sig catch
bool stop;

// Function to catch cntrl-c
void sigTerm (int) { 
   cout << "Got Signal!" << endl;
   stop = true; 
}

int main (int argc, char **argv) {
   ControlServer  cntrlServer;
   string         defFile;
   uint           shmId;
   int            port;
   stringstream   cmd;
   AtcaDemoBoardSystem *sys;
   SimLink        simLink;
   
   if ( argc == 1 ) {
      cout << "Usage: AtcaDemoBoardSimGui smem_id [default.xml]" << endl;
      return(1);
   }
   shmId = atoi(argv[1]);

   if ( argc > 2 ) defFile = argv[2];
   else defFile = "";

   // Catch signals
   signal (SIGINT,&sigTerm);

   try {
      int           pid;

      // Create and setup PGP link
      simLink.setMaxRxTx(500000);
      simLink.setDebug(true);
      simLink.open("axi_stream",shmId);

      sys = new AtcaDemoBoardSystem(&simLink, defFile, 1);
      sys->setDebug(true);

      usleep(100);

      // Setup control server
      cntrlServer.enableSharedMemory("axi_stream",1);
      cntrlServer.setDebug(true);
      port = cntrlServer.startListen(0);
      cntrlServer.setSystem(sys);
      cout << "Control id = 1" << endl;


      // Fork and start gui
      stop = false;
      switch (pid = fork()) {

         // Error
         case -1:
            cout << "Error occured in fork!" << endl;
            return(1);
            break;

         // Child
         case 0:
            usleep(100);
            cout << "Starting GUI" << endl;
            cmd.str("");
            cmd << "cntrlGui localhost " << dec << port;
            system(cmd.str().c_str());
            cout << "GUI stopped" << endl;
            kill(getppid(),SIGINT);
            break;

         // Server
         default:
            cout << "Starting server at port" << dec << port << endl;
            while ( ! stop ) cntrlServer.receive(100);
            cntrlServer.stopListen();
            cout << "Stopped server" << endl;
            break;
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
      cntrlServer.stopListen();
   }
}

