//-----------------------------------------------------------------------------
// File          : DevBoardSystem.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : Heavy Photon DevBoardSystem
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
#include <DevBoardSystem.h>
#include <DacBoard.h>
#include <AdcBoard.h>
#include <DevBoard.h>

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
DevBoardSystem::DevBoardSystem (CommLink *commLink, string defFile, uint addrSize) :
      System("DevBoardSystem", commLink) {


   // Description
   desc_ = "JESD Dev Board";
   
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
   addDevice(new DevBoard(linkConfig_, 0x00000000, 0, this, addrSize));
   //addDevice(new AdcBoard(AdclinkConfig, 0x00000000, 0, this, addrSize));
   //addDevice(new DacBoard(DaclinkConfig, 0x00000000, 0, this, addrSize));
   
   // Add Commands
   //addCommand(new Command("SoftwareTrigger", 0x015A));
   //getCommand("SoftwareTrigger")->setDescription("Send 1 trigger");

}

// Deconstructor
DevBoardSystem::~DevBoardSystem ( ) {
  //  delete commLink_;
//    delete dest_;
   // Add dest here later
}

// Method to process a command
void DevBoardSystem::command ( string name, string arg ) {

   System::command(name, arg);

}

void DevBoardSystem::periodState () {
   allStatusReq_ = getInt("PollStatusEn");
}

//! Method to return state string
string DevBoardSystem::localState ( ) {
   return "System is ready to take data.";
}

//! Method to perform soft reset
void DevBoardSystem::softReset ( ) {
   System::softReset();
}

//! Method to perform hard reset
void DevBoardSystem::hardReset ( ) {
   System::hardReset();
}

//! Method to set run state
void DevBoardSystem::setRunState ( string state ) {
   stringstream err;
   uint         toCount;
   uint         runNumber;

   // Stopped state is requested
   if ( state == "Stopped" ) {

      if ( swRunEnable_ ) {
         swRunEnable_ = false;
         pthread_join(swRunThread_,NULL);
      }

      if ( hwRunning_ ) {
         addRunStop();
         hwRunning_ = false;
         getVariable("RunState")->set(state);
      }

      writeConfig(false);      
         
      allStatusReq_ = true;
      addRunStop();   
   }

   // Software Driven State is Requested?
   else if ( !swRunning_ && (state == "Running")) {
      
      setRunCommand("SoftwareTrigger");
      writeConfig(false); 

      // Increment run number
      runNumber = getVariable("RunNumber")->getInt() + 1;
      getVariable("RunNumber")->setInt(runNumber);
      addRunStart();

      swRunRetState_ = "Stopped";
      swRunEnable_   = true;
      getVariable("RunState")->set(state);

      // Setup run parameters
      swRunCount_ = getInt("RunCount");
      if      ( get("RunRate") == "2000Hz") swRunPeriod_ =     500;
      else if ( get("RunRate") == "1000Hz") swRunPeriod_ =    1000;
      else if ( get("RunRate") == "120Hz") swRunPeriod_ =    8333;
      else if ( get("RunRate") == "100Hz") swRunPeriod_ =   10000;
      else if ( get("RunRate") ==  "10Hz") swRunPeriod_ =  100000;
      else if ( get("RunRate") ==   "1Hz") swRunPeriod_ = 1000000;
      else swRunPeriod_ = 1000000;

      // Start thread
      if ( swRunCount_ == 0 || pthread_create(&swRunThread_,NULL,swRunStatic,this) ) {
         err << "DevBoardSystem::startRun -> Failed to create runThread" << endl;
         if ( debug_ ) cout << err.str();
         getVariable("RunState")->set(swRunRetState_);
         throw(err.str());
      }

      // Wait for thread to start
      toCount = 0;
      while ( !swRunning_ ) {
         usleep(100);
         toCount++;
         if ( toCount > 1000 ) {
            swRunEnable_ = false;
            err << "DevBoardSystem::startRun -> Timeout waiting for runthread" << endl;
            if ( debug_ ) cout << err.str();
            getVariable("RunState")->set(swRunRetState_);
            throw(err.str());
         }
      }
   }

}


void DevBoardSystem::swRunThread() {
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
      cout << "DevBoardSystem::runThread -> Name: " << name_ 
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
               if ( debug_ ) cout << "DevBoardSystem::runThread -> Missed data event. Retrying" << endl;

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
