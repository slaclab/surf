//-----------------------------------------------------------------------------
// File          : 
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 05/14/2013
// Project       : 
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 05/14/2013: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <UdpLink.h>
#include <AtcaDemoBoardSystem.h>
#include <ControlServer.h>
#include <MultDest.h>
#include <MultDestPgp.h>
#include <MultLink.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>

using namespace std;

#define DEBUGGING_C        true

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
   int            port;
   stringstream   cmd;
   AtcaDemoBoardSystem *sys;
   MultLink       multLink;
   MultDest       *dest;

   if ( argc > 1 ) defFile = argv[1];
   else defFile = "";

   // Catch signals
   signal (SIGINT,&sigTerm);
   
   try {
      int           pid;

      dest = new MultDestPgp("/dev/pgpcard0");

      multLink.setDebug(true);
      multLink.setMaxRxTx(0x800000);
      multLink.open(1, dest);

      sys = new AtcaDemoBoardSystem(&multLink, defFile, 4);
      sys->setDebug(DEBUGGING_C);
   
      usleep(100);

      // Setup control server
      cntrlServer.setDebug(DEBUGGING_C);
      cntrlServer.enableSharedMemory("AtcaDemoBoard",1);
      port = cntrlServer.startListen(0);
      cntrlServer.setSystem(sys);
      
      cout << "Starting server at port " << dec << port << endl;
      
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
            cout << "Starting server at port " << dec << port << endl;
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

