//----------------------------------------------------------------------------------------
// Title         : PIC SystemC Interface Model
// Project       : General
//----------------------------------------------------------------------------------------
// File          : Pgp2PicModel.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 08/26/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model the RCE PIC export interface.
//----------------------------------------------------------------------------------------
// This file is part of 'SLAC PGP2 Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP2 Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------------------
// Modification history:
// 08/26/2009: created.
//----------------------------------------------------------------------------------------
#include <iostream>
#include <iomanip>
#include "Pgp2PicModel.h"
#include "PicFrame.h"
using namespace std;


// Import Thread
void Pgp2PicModel::importThread(void) {
   PicFrame     *currFrame[4];
   unsigned int  currVc;
   unsigned long frameInt;
   unsigned int  byteCount;
   unsigned int  tempCount;
   unsigned int  tempHigh;
   unsigned int  tempLow;
   unsigned int  currState;
   unsigned int  tempChar;
   unsigned int  vcCount;

   // Init
   Import_Core_Reset.write(SC_LOGIC_0);
   Import_Data_Pipeline_Full.write(SC_LOGIC_0);
   Import_Pause.write(SC_LOGIC_0);
   currFrame[0] = NULL;
   currFrame[1] = NULL;
   currFrame[2] = NULL;
   currFrame[3] = NULL;
   currState    = StIdle;
   vcCount      = 0;

   // Run forever
   while (1) {

      // Clock Edge
      wait();

      // Check for data pipeline advance
      if ( Import_Advance_Data_Pipeline.read() != 0 ) {

         // Read in the data
         tempHigh = Import_Data_High.read().to_uint();  
         tempLow  = Import_Data_Low.read().to_uint();  

         // Idle, store VC
         if ( currState == StIdle ) {

            // Free list contains vc number
            currVc = (Import_Free_List.read().to_uint() & 0x3);

            // Create a new frame if not active
            if ( currFrame[currVc] == NULL ) currFrame[currVc] = new PicFrame();

            // Process cell data
            currState = StCell;
         }

         // Store free list and data
         else if ( currState == StCell ) {
            if ( currFrame[currVc]->size == 0 ) currFrame[currVc]->freeList = Import_Free_List.read().to_uint();

            // End of cell
            if ( vcCount == (CellSize-1)) {
               currState = StIdle;
               vcCount = 0;
            }
            else vcCount ++;

            // Figure out byte count
            if ( Import_Data_Last_Line.read() == 0 ) byteCount = 8;
            else {
               byteCount = Import_Data_Last_Valid_Byte.read().to_uint() + 1;
               currState = StStat;
            }

            // Proces each low word byte
            tempCount = 0;
            while ( tempCount < byteCount && tempCount < 4 ) {
               tempChar = (tempLow >> (tempCount*8)) & 0xFF; 
               currFrame[currVc]->addData(tempChar);
               tempCount++;
            }

            // Proces each high word byte
            while ( tempCount < byteCount ) {
               tempChar = (tempHigh >> ((tempCount-4)*8)) & 0xFF; 
               currFrame[currVc]->addData(tempChar);
               tempCount++;
            }
         }

         // Expecting status word
         else if ( currState == StStat ) {

            // Store status
            currFrame[currVc]->status = tempLow;

            // Add frame to queue
            frameInt = (unsigned long)currFrame[currVc];

            // FIFO is full
            if ( rxFifo.num_free() == 0 ) {
               cout << "Import FIFO Overflow.";
               cout << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
               sc_stop();
            }
            else rxFifo.write(frameInt);
            currState = StIdle;
            currFrame[currVc] = NULL;
            vcCount = 0;
         }
      }

      // Update Status
      Import_Data_Pipeline_Full.write((rxFifo.num_free() == 0)?SC_LOGIC_1:SC_LOGIC_0);
      Import_Pause.write((rxFifo.num_free() < 5)?SC_LOGIC_1:SC_LOGIC_0);

      // Update reset state
      Import_Core_Reset.write(importReset?SC_LOGIC_1:SC_LOGIC_0);
   }
}


// Export Thread
void Pgp2PicModel::exportThread(void) {
   PicFrame      *tempFrame;
   PicFrame      *currFrame;
   unsigned int  tempInt;
   unsigned long frameInt;
   unsigned int  txCount;
   unsigned int  byteCount;
   unsigned int  tempHigh;
   unsigned int  tempLow;
   bool          statError;
   bool          setStatus;

   // Init
   Export_Core_Reset.write(SC_LOGIC_0);
   Export_Data_Available.write(SC_LOGIC_0);
   Export_Data_Start.write(SC_LOGIC_0);
   Export_Data_Last_Line.write(SC_LOGIC_0);
   Export_Data_Last_Valid_Byte.write(0);
   Export_Status_Full.write(SC_LOGIC_0);
   Export_Data_Low.write(0);
   Export_Data_High.write(0);
   currFrame = NULL;
   statError = false;
   setStatus = false;

   // Run forever
   while (1) {

      // Clock Edge
      wait();

      // Get next frame if ready
      if ( currFrame == NULL && txFifo.num_available() != 0 ) {
          txFifo.read(frameInt);
          currFrame = (PicFrame*)frameInt;
          txCount = 0;
      }

      // Check for data pipeline advance
      if ( Export_Advance_Data_Pipeline.read() != 0 ) {

         // Data is not available
         if ( currFrame == NULL ) {
            cout << "Export Advance Without Data Error.";
            cout << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
            sc_stop();
         }
         else {
 
            // Continue until 8 bytes are read or all of frame is sent
            byteCount = 0;
            tempHigh  = 0;  
            tempLow   = 0;  
            while ( byteCount < 4 && txCount < currFrame->size ) {
               tempLow += currFrame->data[txCount] << (byteCount*8);
               byteCount++;
               txCount++;
            }
            while ( byteCount < 8 && txCount < currFrame->size ) {
               tempHigh += currFrame->data[txCount] << ((byteCount-4)*8);
               byteCount++;
               txCount++;
            }

            // Set output
            Export_Data_Last_Valid_Byte.write(byteCount-1);
            Export_Data_Low.write(tempLow);
            Export_Data_High.write(tempHigh);

            // Data was last
            if ( txCount == currFrame->size ) {
               Export_Data_Last_Line.write(SC_LOGIC_1);
               frameInt = (unsigned long)currFrame;
               pendFifo.write(frameInt);
               currFrame = NULL;
            }
            else Export_Data_Last_Line.write(SC_LOGIC_0);
         }
      }

      // Check for status update
      if ( Export_Advance_Status_Pipeline.read() != 0 ) {

          // Get status value
          tempInt = Export_Status.read().to_uint();

          // Error if pending FIFO is empty
          if ( pendFifo.num_available() == 0 ) {
             cout << "Export Pending FIFO Read Available Error.";
             cout << " Time=" << dec << setw(12) << setfill(' ') << sc_time_stamp() << endl;
             sc_stop();
          }

          // Status with error was passed previously
          if ( statError ) {
             statError = false;
             setStatus = true;
          }

          // Current word has a status error
          else if ( tempInt & 0x1 ) {
             statError = true;
             setStatus = false;
          }

          // Non-error status
          else {
             statError = false;
             setStatus = true;
          }
             
          // Status is to be set
          // Pop frame from pending queue, update status and add to status queue
          if ( setStatus ) {
             pendFifo.read(frameInt);
             tempFrame = (PicFrame*)frameInt;
             tempFrame->status = tempInt;
             statusFifo.write(frameInt);
          }
      }

      // Update data status
      if ( currFrame != NULL || txFifo.num_available() != 0 ) {
         Export_Data_Available.write(SC_LOGIC_1);
         Export_Data_Start.write(SC_LOGIC_1);
      } else {
         Export_Data_Available.write(SC_LOGIC_0);
         Export_Data_Start.write(SC_LOGIC_0);
      }

      // Update reset state
      Export_Core_Reset.write(exportReset?SC_LOGIC_1:SC_LOGIC_0);

      // Update export status pipeline state
      Export_Status_Full.write((statusFifo.num_free()==0)?SC_LOGIC_1:SC_LOGIC_0);
   }
}


// Thread to handle DCR access
void Pgp2PicModel::dcrThread(void) {

   unsigned int tempInt;

   // Init
   Dcr_Write.write(SC_LOGIC_0);
   Dcr_Write_Data.write(0);
   Dcr_Read_Address.write(0);

   // Run forever
   while (1) {

      // Clock Edge
      wait();

      // Read FIFO has an address
      if ( addrFifo.num_available() != 0 ) {

         // Put out address
         addrFifo.read(tempInt);
         Dcr_Read_Address.write(tempInt);

         wait();

         // Read In Data
         tempInt = Dcr_Read_Data.read().to_uint();
         readFifo.write(tempInt);
      }

      // Write FIFO has data
      else if ( writeFifo.num_available() != 0 ) {

         // Put out data
         writeFifo.read(tempInt);
         Dcr_Write_Data.write(tempInt);
         Dcr_Write.write(SC_LOGIC_1);

         wait();

         // De-assert write
         Dcr_Write.write(SC_LOGIC_0);
      }
   }
}


// Method to indicate that another frame can be transmitted
bool Pgp2PicModel::txReady(void) {
   return(txFifo.num_free() != 0);
}


// Method to transmit a frame
bool Pgp2PicModel::txFrame(PicFrame *frame) {
   txFifo.write((unsigned long)frame);
}


// Method to read status frame
PicFrame *Pgp2PicModel::readStatus(void) {
   unsigned long pointer;

   if ( statusFifo.num_available() != 0 ) {
      statusFifo.read(pointer);
      return((PicFrame *)pointer);
   }
   else return(NULL);
}


// Method to read received frame
PicFrame *Pgp2PicModel::rxFrame(void) {
   unsigned long pointer;

   if ( rxFifo.num_available() != 0 ) {
      rxFifo.read(pointer);
      return((PicFrame *)pointer);
   }
   else return(NULL);
}


// Method to set import reset state
void Pgp2PicModel::setImportReset(bool reset) {
   importReset = reset;
}


// Method to set export reset state
void Pgp2PicModel::setExportReset(bool reset) {
   exportReset = reset;
}


// Read from DCR Bus
unsigned int Pgp2PicModel::dcrRead(unsigned int addr) {
   unsigned int ret;
   addrFifo.write(addr);
   readFifo.read(ret);
   return(ret);
}


// Write to DCR bus
void Pgp2PicModel::dcrWrite(unsigned int data) {
   writeFifo.write(data);
}

