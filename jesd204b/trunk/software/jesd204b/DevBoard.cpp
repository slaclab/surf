//-----------------------------------------------------------------------------
// File          : DevBoard.cpp
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 11/14/2013
// Project       : HPS SVT
//-----------------------------------------------------------------------------
// Description :
// Device container for AxiVersion.vhd
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
#include <JesdCommon.h>
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
DevBoard::DevBoard ( uint linkConfig, uint baseAddress, uint index, Device *parent, uint addrSize) : 
                        Device(linkConfig,baseAddress,"DevBoard",index,parent) {

   // Description
   desc_ = "JESD Dev Board";

   addDevice(new Pgp2bAxi   ( linkConfig, baseAddress | (0x00F00000 * (addrSize/4)), 0, this, addrSize)); 
   addDevice(new AxiVersion ( linkConfig, baseAddress | (0x00000000 * (addrSize/4)), 0, this, addrSize));
   addDevice(new JesdCommon ( linkConfig, baseAddress | (0x00010000 * (addrSize/4)), 0, this, addrSize)); 

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
