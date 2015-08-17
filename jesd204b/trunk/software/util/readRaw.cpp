//-----------------------------------------------------------------------------
// File          : readExample.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 12/02/2011
// Project       : Kpix DAQ
//-----------------------------------------------------------------------------
// Description :
// Read data example
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 12/02/2011: created
//----------------------------------------------------------------------------
#include <iomanip>
#include <fstream>
#include <iostream>
#include <sstream>
#include <Data.h>
#include <DataRead.h>

using namespace std;

int main (int argc, char **argv) {
   DataRead   dataRead;
   Data  event;
   uint       x;
   ofstream file;
   
   std::stringstream outFileNameStream;
   std::string outFileName;
   
   
   // Check args
   if ( argc != 2 ) {
      cout << "Usage: readExample filename" << endl;
      return(1);
   }
   
   // Construct the output file name
   outFileNameStream << argv[1] << ".txt";
   outFileName = outFileNameStream.str();
   
   cout << outFileNameStream.str() << endl;
   
   // Open file
   file.open (outFileName.c_str());
  
   // Attempt to open data file
   if ( ! dataRead.open(argv[1]) ) return(2);

   // Process each event
   while ( dataRead.next(&event) ) {
     cout <<  endl << endl << "Got Data Size" << event.size() << endl;
     for (x = 0; x < event.size(); x++) {
       cout << "0x" << hex << setw(2) << setfill('0') << (0xFF & event.data()[x])        << setw(2) << setfill('0') <<  (0xFF & (event.data()[x]>> 8))  << endl;
       cout << "0x" << hex << setw(2) << setfill('0') << (0xFF & (event.data()[x]>> 16)) << setw(2) << setfill('0') <<  (0xFF & (event.data()[x]>> 24)) << endl;
       file << "0x" << hex << setw(2) << setfill('0') << (0xFF & event.data()[x])        << setw(2) << setfill('0') <<  (0xFF & (event.data()[x]>> 8))  << endl;
       file << "0x" << hex << setw(2) << setfill('0') << (0xFF & (event.data()[x]>> 16)) << setw(2) << setfill('0') <<  (0xFF & (event.data()[x]>> 24)) << endl;
     }
      
   }
   
   file.close();
   // Dump config
   //dataRead.dumpConfig();
   //dataRead.dumpStatus();

   return(0);
}

