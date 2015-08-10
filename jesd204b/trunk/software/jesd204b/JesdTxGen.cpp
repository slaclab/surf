//-----------------------------------------------------------------------------
// File          : JesdTxGen.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Rx DAQ
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <JesdTxGen.h>
#include <Register.h>
#include <RegisterLink.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
JesdTxGen::JesdTxGen ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdTxGen",index,parent) {

   // Description
   desc_ = "DAC data signal generation control";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("Enable", baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enable/turn on the corresponding waveform");

   //addRegisterLink(rl = new RegisterLink("DisplayRateDiv", baseAddress_ + (0x01*addrSize), Variable::Configuration));
   //rl->getVariable()->setDescription("Divides the display rate (0 - DR, 1 - DR/2, 2 - DR/4, 2 - DR/6 etc)");

   addRegisterLink(rl = new RegisterLink("PeriodSize", baseAddress_ + (0x02*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Size of a generated signal period buffer. NOTE: The data in the buffer has to be properly defined");    

   // Variables
   getVariable("Enabled")->setHidden(true);
   //Commands
}

// Deconstructor
JesdTxGen::~JesdTxGen ( ) { }

// Process Commands


