//-----------------------------------------------------------------------------
// File          : Dac38J84.cpp
// Author        : Uros legat <ulegat@slac.stanford.edu>
//                            <uros.legat@cosylab.com>
// Created       : 27/04/2015
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//    Device container for Dac38J84
//-----------------------------------------------------------------------------
// Copyright (c) 2015 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 27/04/2015: created
//-----------------------------------------------------------------------------
#include <Dac38J84.h>
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
Dac38J84::Dac38J84 ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
                        Device(linkConfig,baseAddress,"Dac38J84",index,parent) {
   uint32_t i;
   RegisterLink *rl;
   stringstream tmp;
   Command      *c;
   
  // Description
   desc_ = "DAC data acquisition control";

   // Create Registers: name, address
   for (i=START_ADDR;i<=END_ADDR;i++) {
      tmp.str("");
      tmp << "DacReg" << hex << setw(4) << setfill('0') << hex << i;
      addRegisterLink(rl = new RegisterLink(tmp.str(), (baseAddress_+ (i*addrSize)), Variable::Configuration));
      rl->getVariable()->setPerInstance(true);                                                                              
   }  
   
   // Status
   addRegisterLink(rl = new RegisterLink("L1SERDES_alarm",    baseAddress_ + (0x64 *addrSize), 1, 12,
                                "L1ReadFifoEmpty",            Variable::Status, 0,  0x1,
                                "L1ReadFifoUnderflow",        Variable::Status, 1,  0x1, 
                                "L1ReadFifoFull",             Variable::Status, 2,  0x1,
                                "L1ReadFifoOverflow",         Variable::Status, 3,  0x1,                                
                                "L1DispErr",                  Variable::Status, 8,  0x1,
                                "L1NotitableErr",             Variable::Status, 9,  0x1, 
                                "L1CodeSyncErr",              Variable::Status, 10, 0x1,
                                "L1FirstDataMatchErr",        Variable::Status, 11, 0x1,
                                "L1ElasticBuffOverflow",      Variable::Status, 12, 0x1,
                                "L1LinkConfigErr",            Variable::Status, 13, 0x1, 
                                "L1FrameAlignErr",            Variable::Status, 14, 0x1,
                                "L1MultiFrameAlignErr",       Variable::Status, 15, 0x1));

   addRegisterLink(rl = new RegisterLink("L2SERDES_alarm",    baseAddress_ + (0x65 *addrSize), 1, 12,
                                "L2ReadFifoEmpty",            Variable::Status, 0,  0x1,
                                "L2ReadFifoUnderflow",        Variable::Status, 1,  0x1, 
                                "L2ReadFifoFull",             Variable::Status, 2,  0x1,
                                "L2ReadFifoOverflow",         Variable::Status, 3,  0x1,                                
                                "L2DispErr",                  Variable::Status, 8,  0x1,
                                "L2NotitableErr",             Variable::Status, 9,  0x1, 
                                "L2CodeSyncErr",              Variable::Status, 10, 0x1,
                                "L2FirstDataMatchErr",        Variable::Status, 11, 0x1,
                                "L2ElasticBuffOverflow",      Variable::Status, 12, 0x1,
                                "L2LinkConfigErr",            Variable::Status, 13, 0x1, 
                                "L2FrameAlignErr",            Variable::Status, 14, 0x1,
                                "L2MultiFrameAlignErr",       Variable::Status, 15, 0x1));                                 
   
   addRegisterLink(rl = new RegisterLink("SERDES_alarm",    baseAddress_ + (0x6C*addrSize), 1, 3,
                                "Serdes1pllAlarm",           Variable::Status, 2, 0x1,
                                "Serdes0pllAlarm",           Variable::Status, 3, 0x1,
                                "SysRefAlarms",              Variable::Status,12, 0xf));
   
   addRegisterLink(rl = new RegisterLink("Lane_alarm",    baseAddress_ + (0x6D*addrSize), 1, 2,
                                "Lane1Alarm",           Variable::Status, 8, 0x1,
                                "Lane2Alarm",           Variable::Status, 9, 0x1 ));
                                
   // Variables
   getVariable("Enabled")->setHidden(true);
   
   //Commands
   addCommand(c = new Command("ClearDACAlarms"));
   c->setDescription("Clear all the DAC alarms.");
   
   addCommand(c = new Command("InitDAC_JESD"));
   c->setDescription("Initialialization sequence for the DAC JESD core");
}

// Deconstructor
Dac38J84::~Dac38J84 ( ) { }

// Process Commands
void Dac38J84::command(string name, string arg) {
   if (name == "ClearDACAlarms") clrAlarms();
   else if (name == "InitDAC_JESD") initDac();
   else Device::command(name,arg);
}

//! Clear alarms
void Dac38J84::clrAlarms () {

   Register *r;
   
   REGISTER_LOCK
   
   r = getRegister("DacReg0064");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg0065");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg0066");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg0067");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg0068");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg0069");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg006a");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg006b");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   r = getRegister("DacReg006c");
   r->set(0x0,0,0xffff);
   writeRegister(r, true, false);
   
   REGISTER_UNLOCK

}

//! Initialisation process
void Dac38J84::initDac () {

   Register *r;
   
   REGISTER_LOCK
   
   // Disable TX
   r = getRegister("DacReg0003");
   r->set(0x0,0,0x1);
   writeRegister(r, true, false);
   
   // Disable and initialize JESD
   r = getRegister("DacReg004a");
   r->set(0x1E,0,0x1f);
   writeRegister(r, true, false);
   
   // Enable JESD
   r = getRegister("DacReg004a");
   r->set(0x01,0,0x1f);
   writeRegister(r, true, false);
   
   // Enable TX
   r = getRegister("DacReg0003");
   r->set(0x1,0,0x1);
   writeRegister(r, true, false);
   
   REGISTER_UNLOCK

}






