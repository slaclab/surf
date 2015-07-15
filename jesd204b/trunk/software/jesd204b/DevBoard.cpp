//-----------------------------------------------------------------------------
// File          : DevBoard.cpp
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 11/14/2013
// Project       : HPS SVT
//-----------------------------------------------------------------------------
// Description :
// Device container for jesd cores
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/14/2013: created
//-----------------------------------------------------------------------------
#include <DevBoard.h>
#include <AxiVersion.h>
#include <Pgp2bAxi.h>
#include <JesdRxDaq.h>
#include <JesdRx.h>
#include <JesdTx.h>
#include <Adc16Dx370.h>
#include <Dac38J84.h>
#include <Lmk04828.h>

#include <AxiMicronP30.h>
#include <Register.h>
#include <RegisterLink.h>
#include <Variable.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
DevBoard::DevBoard ( uint linkConfig, uint baseAddress, uint index, Device *parent, uint addrSize) : 
                        Device(linkConfig,baseAddress,"DevBoard",index,parent) {

   // Description
   desc_ = "LLRF demo Board";

   addDevice(new Pgp2bAxi   ( linkConfig, baseAddress | ((0x01000000>>2) * (addrSize)), 0, this, addrSize)); 
   addDevice(new AxiVersion ( linkConfig, baseAddress | ((0x00000000>>2) * (addrSize)), 0, this, addrSize));
   addDevice(new JesdRx     ( linkConfig, baseAddress | ((0x00100000>>2) * (addrSize)), 0, this, addrSize)); 
   addDevice(new JesdTx     ( linkConfig, baseAddress | ((0x00200000>>2) * (addrSize)), 0, this, addrSize));
   addDevice(new JesdRxDaq  ( linkConfig, baseAddress | ((0x00300000>>2) * (addrSize)), 0, this, addrSize));
   
   addDevice(new Adc16Dx370 ( linkConfig, baseAddress | ((0x00500000>>2) * (addrSize)), 0, this, addrSize));
   addDevice(new Adc16Dx370 ( linkConfig, baseAddress | ((0x00600000>>2) * (addrSize)), 1, this, addrSize));
   addDevice(new Adc16Dx370 ( linkConfig, baseAddress | ((0x00700000>>2) * (addrSize)), 2, this, addrSize));
   
   addDevice(new Lmk04828   ( linkConfig, baseAddress | ((0x00800000>>2) * (addrSize)), 0, this, addrSize));
   addDevice(new Dac38J84   ( linkConfig, baseAddress | ((0x00900000>>2) * (addrSize)), 0, this, addrSize));
    
   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
DevBoard::~DevBoard ( ) { }

// Method to process a command
// void DevBoard::command ( string name, string arg) {
//    Device::command(name, arg);
// }
   
// // Method to read status registers and update variables
// void DevBoard::readStatus ( ) {
//      // Sub devices
//    Device::readStatus();
// }

// void DevBoard::readConfig ( ) {
//    // Sub devices
//    Device::readConfig();
// }

// Method to write configuration registers
void DevBoard::writeConfig ( bool force ) {
   // Sub devices
   Device::writeConfig(force);
}

// void DevBoard::verifyConfig() {
//    Device::verifyConfig();
// }
