//-----------------------------------------------------------------------------
// File          : JesdCommon.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Jesd204b
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <JesdCommon.h>
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
JesdCommon::JesdCommon ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdCommon",index,parent) {

   // Description
   desc_ = "Firmware Version object.";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("Enable",        baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enables the RX modules: 0x3 - enables both modules at a time");
   
   
   addRegisterLink(rl = new RegisterLink("SysrefDelay",   baseAddress_ + (0x01*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Sets the synchronisation delay in clock cycles");   
   
   
   
   addRegisterLink(rl = new RegisterLink("StatusL1",      baseAddress_ + (0x10*addrSize), 1, 8,
                                "GTXRdy",        Variable::Status, 0, 0x1,
                                "DataValid",     Variable::Status, 1, 0x1, 
                                "IlasActive",    Variable::Status, 2, 0x1,
                                "nSync",         Variable::Status, 3, 0x1,                                 
                                "RxBuffUfl",     Variable::Status, 4, 0x1,
                                "RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "AlignErr",      Variable::Status, 6, 0x1,
                                "RxEnabled",     Variable::Status, 7, 0x1));                                                      
                                
   addRegisterLink(rl = new RegisterLink("StatusL2",      baseAddress_ + (0x11*addrSize), 1, 8,
                                "GTXRdy",        Variable::Status, 0, 0x1,
                                "DataValid",     Variable::Status, 1, 0x1, 
                                "IlasActive",    Variable::Status, 2, 0x1,
                                "nSync",         Variable::Status, 3, 0x1,                                 
                                "RxBuffUfl",     Variable::Status, 4, 0x1,
                                "RxBuffOfl",     Variable::Status, 5, 0x1,                                 
                                "AlignErr",      Variable::Status, 6, 0x1,
                                "RxEnabled",     Variable::Status, 7, 0x1));
   // Variables

   //Commands


}

// Deconstructor
JesdCommon::~JesdCommon ( ) { }

// Process Commands


