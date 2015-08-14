//-----------------------------------------------------------------------------
// File          : AtcaDemoBoardSystem.cpp
// Author        : Uros Legat <ulegat@slac.stanford.edu>
// Created       : 7/10/2015
// Project       : HPS carrier board and LLRF demo board
//-----------------------------------------------------------------------------
// Description :
// Control FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//-----------------------------------------------------------------------------

#include <MultLink.h>
#include <MultDestPgp.h>
#include <AtcaDemoBoardSystem.h>
#include <DacBoard.h>
#include <AdcBoard.h>
#include <AtcaDemoBoard.h>

#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <CommLink.h>

#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>

using namespace std;

#define PGP_REG(lane, vc)    (((lane&0xF)<<12)|(vc<<8))
#define PGP_CMD(lane, vc)    ((lane<<20)|(vc<<16))
#define PGP_DATA(lane, vc)   ((lane<<28)|(vc<<24))


// Constructor
AtcaDemoBoardSystem::AtcaDemoBoardSystem (CommLink *commLink, string defFile, uint addrSize) :
      System("AtcaDemoBoardSystem", commLink) {


   // Description
   desc_ = "HPS LRRF demo Board";
   
   // Data mask:
   //   REG  = lane 0, vc 0 (RX and TX)
   //   CMD  = lane 0, vc 1 (TX only)
   //   DATA0 = lane 0, vc 1 (Streaming RX only)
   //   DATA0 = lane 0, vc 2 (Streaming RX only)   
    commLink_->addDataSource(PGP_DATA(0,1));
    commLink_->addDataSource(PGP_DATA(0,2));    
    linkConfig_ = PGP_CMD(0,1)|PGP_REG(0,0);
    
    uint AdclinkConfig = PGP_CMD(0,1)|PGP_REG(0,0);
    uint DaclinkConfig = PGP_CMD(1,1)|PGP_REG(1,0);
   
   // Setup top level device
   //   setDebug(true);

   if ( defFile == "" ) defaults_ = "xml/defaults.xml";
   else defaults_ = defFile;
   
   // Set run states
   vector<string> states;
   states.resize(2);
   states[0] = "Stopped";
   states[1] = "Running";
   getVariable("RunState")->setEnums(states);

   Variable *v;
   addVariable(v = new Variable("PollStatusEn", Variable::Configuration));
   v->setTrueFalse();
   v->set("False");
   
   // Add sub-devices
   addDevice(new AtcaDemoBoard(linkConfig_, 0x00000000, 0, this, addrSize));
   //addDevice(new AdcBoard(AdclinkConfig, 0x00000000, 0, this, addrSize));
   //addDevice(new DacBoard(DaclinkConfig, 0x00000000, 0, this, addrSize));
   
   // Add Commands
   //addCommand(new Command("SoftwareTrigger", 0x015A));
   //getCommand("SoftwareTrigger")->setDescription("Send 1 trigger");

}

// Deconstructor
AtcaDemoBoardSystem::~AtcaDemoBoardSystem ( ) {
  //  delete commLink_;
//    delete dest_;
   // Add dest here later
}

// Method to process a command
void AtcaDemoBoardSystem::command ( string name, string arg ) {

   System::command(name, arg);

}

void AtcaDemoBoardSystem::periodState () {
   allStatusReq_ = getInt("PollStatusEn");
}

//! Method to return state string
string AtcaDemoBoardSystem::localState ( ) {
   return "System is ready to take data.";
}

//! Method to perform soft reset
void AtcaDemoBoardSystem::softReset ( ) {
   System::softReset();
}

//! Method to perform hard reset
void AtcaDemoBoardSystem::hardReset ( ) {
   System::hardReset();
}


/*
void AtcaDemoBoardSystem::swRunThread() {
   struct timespec tme;
   ulong           ctime;
   ulong           ltime;
   uint            runTotal;
   uint            stepTotal;
   uint            lastData;
   bool            gotEvent;
   stringstream    oldConfig;
   stringstream    xml;

   oldConfig.str("");

   // Setup run status and init clock
   lastData    = commLink_->dataRxCount();
   runTotal    = 0;
   stepTotal   = 0;
   swRunning_  = true;
   swRunError_ = "";
   clock_gettime(CLOCK_REALTIME,&tme);
   ltime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);

   // Show start
   if ( debug_ ) {
      cout << "AtcaDemoBoardSystem::runThread -> Name: " << name_ 
           << ", Run Started"
           << ", RunState=" << dec << getVariable("RunState")->get()
           << ", RunCount=" << dec << swRunCount_
           << ", RunPeriod=" << dec << swRunPeriod_ << endl;
   }

   try {

      // Enable run counter register
      //      writeConfig(false);


      // Run
      while ( swRunEnable_ ) {

         // Delay between attempts
         do {
            usleep(1);
            clock_gettime(CLOCK_REALTIME,&tme);
            ctime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);
         } while ( (ctime-ltime) < swRunPeriod_);

         // Check that we received a data frame
         gotEvent = true;

         while ( commLink_->dataRxCount() == lastData ) {
            usleep(1);
            clock_gettime(CLOCK_REALTIME,&tme);
            ctime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);

            // Ten seconds have passed. event was missed.
            if ( (ctime-ltime) > 1000000) {
               ltime = ctime;

               gotEvent = false;
               if ( debug_ ) cout << "AtcaDemoBoardSystem::runThread -> Missed data event. Retrying" << endl;

               // Verify and re-configure here

               break;
            }

            if ( !swRunEnable_ ) break;
         }
         if ( !swRunEnable_ ) break; 

         
         if ( gotEvent ) runTotal++;
         if ( swRunCount_ == 0 ) getVariable("RunProgress")->setInt(0);
         else getVariable("RunProgress")->setInt((uint)(((double)runTotal/(double)swRunCount_)*100.0));
         if ( swRunCount_ != 0 && runTotal >= swRunCount_ ) break;
         

         // Execute command
         lastData = commLink_->dataRxCount();
         ltime = ctime;
         commLink_->queueRunCommand();
      }

      // Set run
      usleep(100);

   } catch (string error) { swRunError_ = error; }

   // Cleanup
   sleep(1);

   getVariable("RunState")->set(swRunRetState_);
   swRunning_ = false;
}
*/