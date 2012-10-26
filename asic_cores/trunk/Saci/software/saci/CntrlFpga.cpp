#include <CntrlFpga.h>
#include <SaciAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
CntrlFpga::CntrlFpga ( uint destination, uint index, Device *parent ) : 
                   Device(destination,0,"cntrlFpga",index,parent) {

   // Description
   desc_ = "SACI Control FPGA Object.";

   // Setup registers & variables
   addRegister(new Register("Version", 0x01000000));
   addVariable(new Variable("Version", Variable::Status));
   getVariable("Version")->setDescription("FPGA version field");
   addRegister(new Register("Reset", 0x01000001));

   // Add Commands
   addCommand(new Command("ResetSaciSlaves"));
   getCommand("ResetSaciSlaves")->setDescription("Reset all attached SACI Slaves");

   // Add sub-devices
   addDevice(new SaciAsic(destination,0x01100000,0,this));
   addDevice(new SaciAsic(destination,0x01180000,1,this));

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
CntrlFpga::~CntrlFpga ( ) { }

// Method to process a command
void CntrlFpga::command ( string name, string arg) {
   if (name == "ResetSaciSlaves") {
      REGISTER_LOCK
            
      getRegister("Reset")->set(0x1);
      writeRegister(getRegister("Reset"), true, true);
      
      REGISTER_UNLOCK
   } else {
      Device::command(name, arg);
   }
}

// Method to read status registers and update variables
void CntrlFpga::readStatus ( ) {
   REGISTER_LOCK

           
   readRegister(getRegister("Version"));

   getVariable("Version")->setInt(getRegister("Version")->get());



   // Sub devices
   Device::readStatus();
   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void CntrlFpga::readConfig ( ) {
   REGISTER_LOCK



   // Sub devices
   Device::readConfig();
   REGISTER_UNLOCK
}

// Method to write configuration registers
void CntrlFpga::writeConfig ( bool force ) {
   REGISTER_LOCK



   // Sub devices
   Device::writeConfig(force);
   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void CntrlFpga::verifyConfig ( ) {
   REGISTER_LOCK




   Device::verifyConfig();
   REGISTER_UNLOCK
}

