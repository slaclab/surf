//-----------------------------------------------------------------------------
// File          : SigGenRam.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 07/10/2015
//-----------------------------------------------------------------------------
// Description :
//    Signal generator RAM. Defining a period of generated signal.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 09/04/2013: created
//-----------------------------------------------------------------------------

#include <SigGenRam.h>

#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <RegisterLink.h>

#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>

using namespace std;

// Constructor
SigGenRam::SigGenRam ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"SigGenRam",index,parent) {

   stringstream tmp;    
   uint32_t i;   
   RegisterLink * rl;   
                        
   // Description
   desc_ = "RAM object.";
   
   for (i=0;i<RAM_SAMPLE_SIZE/2;i++) {
      tmp.str("");
      tmp << "RAM" << dec << setw(4) << setfill('0') << i;// RAM[0:1023]
      addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
      rl->getVariable()->setPerInstance(true);                                                                                  
   }   
   
   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
SigGenRam::~SigGenRam ( ) { }
