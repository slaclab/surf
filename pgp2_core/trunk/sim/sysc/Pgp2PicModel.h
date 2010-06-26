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
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 08/26/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PIC_EXPORT_MODEL_H__
#define __PIC_EXPORT_MODEL_H__
#include <systemc.h>
using namespace std;

// Forward declaration
class PicFrame;

// Module declaration
SC_MODULE(Pgp2PicModel) {

   // Export interface signals
   sc_in    <sc_logic  >  Export_Clock;
   sc_out   <sc_logic  >  Export_Core_Reset;
   sc_out   <sc_logic  >  Export_Data_Available;
   sc_out   <sc_logic  >  Export_Data_Start;
   sc_in    <sc_logic  >  Export_Advance_Data_Pipeline;
   sc_out   <sc_logic  >  Export_Data_Last_Line;
   sc_out   <sc_lv<3>  >  Export_Data_Last_Valid_Byte;
   sc_out   <sc_lv<32> >  Export_Data_Low;
   sc_out   <sc_lv<32> >  Export_Data_High;
   sc_in    <sc_logic  >  Export_Advance_Status_Pipeline;
   sc_in    <sc_lv<32> >  Export_Status;
   sc_out   <sc_logic  >  Export_Status_Full;

   // Import interface signals
   sc_in    <sc_logic  >  Import_Clock;
   sc_out   <sc_logic  >  Import_Core_Reset;
   sc_in    <sc_lv<4>  >  Import_Free_List;
   sc_in    <sc_logic  >  Import_Advance_Data_Pipeline;
   sc_in    <sc_logic  >  Import_Data_Last_Line;
   sc_in    <sc_lv<3>  >  Import_Data_Last_Valid_Byte;
   sc_in    <sc_lv<32> >  Import_Data_Low;
   sc_in    <sc_lv<32> >  Import_Data_High;
   sc_out   <sc_logic  >  Import_Data_Pipeline_Full;
   sc_out   <sc_logic  >  Import_Pause;

   // DCR Bus Interface
   sc_in    <sc_logic  >  Dcr_Clock;
   sc_out   <sc_logic  >  Dcr_Write;
   sc_out   <sc_lv<32> >  Dcr_Write_Data;
   sc_out   <sc_lv<2>  >  Dcr_Read_Address;
   sc_in    <sc_lv<32> >  Dcr_Read_Data;

   // Import state constants
   static const unsigned int StIdle = 0;
   static const unsigned int StCell = 1;
   static const unsigned int StStat = 2;

   // Cell size
   static const unsigned int CellSize = 64;

   // FIFOs
   sc_fifo<unsigned long> txFifo;
   sc_fifo<unsigned long> rxFifo;
   sc_fifo<unsigned long> pendFifo;
   sc_fifo<unsigned long> statusFifo;
   sc_fifo<unsigned int>  writeFifo;
   sc_fifo<unsigned int>  addrFifo;
   sc_fifo<unsigned int>  readFifo;

   // Threads to transmit and receive data
   void exportThread(void);
   void importThread(void);
   void dcrThread(void);

   // Method to indicate that another frame can be transmitted
   bool txReady(void);

   // Method to transmit a frame
   bool txFrame(PicFrame *frame);

   // Method to read status frame
   PicFrame *readStatus(void);

   // Method to read received frame
   PicFrame *rxFrame(void);

   // Method to set reset state
   void setImportReset(bool reset);
   void setExportReset(bool reset);

   // Methods to access DCR bus
   unsigned int dcrRead(unsigned int addr);
   void dcrWrite(unsigned int data);

   // Internal reset status
   bool importReset;
   bool exportReset;

   // Constructor
   SC_CTOR(Pgp2PicModel):
      Export_Clock("Export_Clock"),
      Export_Core_Reset("Export_Core_Reset"),
      Export_Data_Available("Export_Data_Available"),
      Export_Data_Start("Export_Data_Start"),
      Export_Advance_Data_Pipeline("Export_Advance_Data_Pipeline"),
      Export_Data_Last_Line("Export_Data_Last_Line"),
      Export_Data_Last_Valid_Byte("Export_Data_Last_Valid_Byte"),
      Export_Data_Low("Export_Data_Low"),
      Export_Data_High("Export_Data_High"),
      Export_Advance_Status_Pipeline("Export_Advance_Status_Pipeline"),
      Export_Status("Export_Status"),
      Export_Status_Full("Export_Status_Full"),
      Import_Clock("Import_Clock"),
      Import_Core_Reset("Import_Core_Reset"),
      Import_Free_List("Import_Free_List"),
      Import_Advance_Data_Pipeline("Import_Advance_Data_Pipeline"),
      Import_Data_Last_Line("Import_Data_Last_Line"),
      Import_Data_Last_Valid_Byte("Import_Data_Last_Valid_Byte"),
      Import_Data_Low("Import_Data_Low"),
      Import_Data_High("Import_Data_High"),
      Import_Data_Pipeline_Full("Import_Data_Pipeline_Full"),
      Import_Pause("Import_Pause"),
      Dcr_Clock("Dcr_Clock"),
      Dcr_Write("Dcr_Write"),
      Dcr_Write_Data("Dcr_Write_Data"),
      Dcr_Read_Address("Dcr_Read_Address"),
      Dcr_Read_Data("Dcr_Read_Data"),
      txFifo(20),
      rxFifo(20),
      pendFifo(64),
      statusFifo(8),
      writeFifo(8),
      addrFifo(8),
      readFifo(8)
   {

      // Setup threads
      SC_CTHREAD(exportThread,Export_Clock.pos());
      SC_CTHREAD(importThread,Import_Clock.pos());
      SC_CTHREAD(dcrThread,Dcr_Clock.pos());

      // Init reset
      importReset = false;
      exportReset = false;
   }
};

#endif
