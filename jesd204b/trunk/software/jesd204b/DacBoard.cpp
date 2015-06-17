//-----------------------------------------------------------------------------
// File          : DacBoard.cpp
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 11/14/2013
// Project       : HPS SVT
//-----------------------------------------------------------------------------
// Description :
// Device container for jesd TX cores
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/14/2013: created
//-----------------------------------------------------------------------------
#include <DacBoard.h>
#include <AxiVersion.h>
#include <Pgp2bAxi.h>
#include <JesdRx.h>
#include <JesdTx.h>
#include <AxiMicronP30.h>
#include <PrbsRx.h>
#include <PrbsTx.h>
#include <Register.h>
#include <RegisterLink.h>
#include <Variable.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
DacBoard::DacBoard ( uint linkConfig, uint baseAddress, uint index, Device *parent, uint addrSize) : 
                        Device(linkConfig,baseAddress,"DacBoard",index,parent) {

   // Description
   desc_ = "JESD DAC Board";

   addDevice(new Pgp2bAxi   ( linkConfig, baseAddress | ((0x00F00000>>2) * (addrSize)), 0, this, addrSize)); 
   addDevice(new AxiVersion ( linkConfig, baseAddress | ((0x00000000>>2) * (addrSize)), 0, this, addrSize));
   //addDevice(new JesdRx     ( linkConfig, baseAddress | ((0x00010000>>2) * (addrSize)), 0, this, addrSize)); 
   addDevice(new JesdTx     ( linkConfig, baseAddress | ((0x00020000>>2) * (addrSize)), 0, this, addrSize)); 
}

// Deconstructor
DacBoard::~DacBoard ( ) { }

// Method to process a command
// void DacBoard::command ( string name, string arg) {
//    Device::command(name, arg);
// }
   
// // Method to read status registers and update variables
// void DacBoard::readStatus ( ) {
//      // Sub devices
//    Device::readStatus();
// }

// void DacBoard::readConfig ( ) {
//    // Sub devices
//    Device::readConfig();
// }

// Method to write configuration registers
void DacBoard::writeConfig ( bool force ) {
   // Sub devices
   Device::writeConfig(force);
}

// void DacBoard::verifyConfig() {
//    Device::verifyConfig();
// }
