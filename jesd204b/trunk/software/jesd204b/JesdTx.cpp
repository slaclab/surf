//-----------------------------------------------------------------------------
// File          : JesdTx.cpp
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
#include <JesdTx.h>
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
JesdTx::JesdTx ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"JesdTx",index,parent) {

   // Description
   desc_ = "Common JESD interface object.";

   // Create Registers: name, address
   RegisterLink *rl;
   
   addRegisterLink(rl = new RegisterLink("Enable",           baseAddress_ + (0x00*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Enables the Tx modules: 0x3 - enables both modules at a time");
   
   
   // addRegisterLink(rl = new RegisterLink("SysrefDelay",      baseAddress_ + (0x01*addrSize), Variable::Configuration));
   // rl->getVariable()->setDescription("Sets the synchronisation delay in clock cycles");

   // addRegisterLink(rl = new RegisterLink("AXISTrigger",      baseAddress_ + (0x02*addrSize), Variable::Configuration));
   // rl->getVariable()->setDescription("Triggers the AXI stream transfer: 0x3 - triggers both modules at a time");
   
   
   // addRegisterLink(rl = new RegisterLink("AXISpacketSize",   baseAddress_ + (0x03*addrSize), Variable::Configuration));
   // rl->getVariable()->setDescription("Data packet size (when enabled packets are being sent continuously)"); 

   addRegisterLink(rl = new RegisterLink("CommonControl",    baseAddress_ + (0x04*addrSize), 1, 5,
                                "SubClass",              Variable::Configuration, 0, 0x1,
                                "ReplaceEnable",         Variable::Configuration, 1, 0x1,
                                "ResetGTs",              Variable::Configuration, 2, 0x1,
                                //"ClearErrors",           Variable::Configuration, 3, 0x1,
                                "InvertSync",            Variable::Configuration, 4, 0x1,
                                "EnableTestSig",         Variable::Configuration, 5, 0x1));

   addRegisterLink(rl = new RegisterLink("PeriodRampStep",    baseAddress_ + (0x05*addrSize), 1, 2,
                                "RampStep",              Variable::Configuration, 0, 0xffff,
                                "SquarePeriod",          Variable::Configuration, 16,0xffff));
   rl->getVariable()->setDescription("Ramp increment step and a period of the wave in c-c ");

   addRegisterLink(rl = new RegisterLink("LowAmplitudeVal",   baseAddress_ + (0x06*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("Low value of the square waveform amplitude");

   addRegisterLink(rl = new RegisterLink("HighAmplitudeVal",  baseAddress_ + (0x07*addrSize), Variable::Configuration));
   rl->getVariable()->setDescription("High value of the square waveform amplitude");
   
   addRegisterLink(rl = new RegisterLink("L1_Status",    baseAddress_ + (0x10*addrSize), 1, 6,
                                "L1_GTXRdy",        Variable::Status, 0, 0x1,
                                "L1_DataValid",     Variable::Status, 1, 0x1, 
                                "L1_IlasActive",    Variable::Status, 2, 0x1,
                                "L1_nSync",         Variable::Status, 3, 0x1,                                                     
                                "L1_TxEnabled",     Variable::Status, 4, 0x1,
                                "L1_SysRefDetected",Variable::Status, 5, 0x1));
                                
   addRegisterLink(rl = new RegisterLink("L2_Status",     baseAddress_ + (0x11*addrSize), 1, 6,
                                "L2_GTXRdy",        Variable::Status, 0, 0x1,
                                "L2_DataValid",     Variable::Status, 1, 0x1, 
                                "L2_IlasActive",    Variable::Status, 2, 0x1,
                                "L2_nSync",         Variable::Status, 3, 0x1,                                                     
                                "L2_TxEnabled",     Variable::Status, 4, 0x1,
                                "L2_SysRefDetected",Variable::Status, 5, 0x1));
                                
    
   addRegisterLink(rl = new RegisterLink("L1_SignalSelect",    baseAddress_ + (0x20*addrSize), 1, 2,
                                "L1_data_out_mux",  Variable::Configuration, 0, 0xf,
                                "L1_test_out_mux",  Variable::Configuration, 4, 0xf));
                                
   rl->getVariable()->setDescription("Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream, b011 - Test data ");                            
    
   addRegisterLink(rl = new RegisterLink("L2_SignalSelect",    baseAddress_ + (0x21*addrSize), 1, 2,
                                "L2_data_out_mux",  Variable::Configuration, 0, 0xf,
                                "L2_test_out_mux",  Variable::Configuration, 4, 0xf));
                                
   rl->getVariable()->setDescription("Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream, b011 - Test data ");     
                                
   // Variables
   getVariable("Enabled")->setHidden(true);

   //Commands


}

// Deconstructor
JesdTx::~JesdTx ( ) { }

// Process Commands


