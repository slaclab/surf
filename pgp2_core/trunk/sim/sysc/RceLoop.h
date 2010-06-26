//----------------------------------------------------------------------------------------
// Title         : PNCCD PIC Interface Frame Test
// Project       : PNCCD
//----------------------------------------------------------------------------------------
// File          : RceLoop.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 08/27/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to send and receive test frames.
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 08/27/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __FRAME_TEST_H__
#define __FRAME_TEST_H__
#include <systemc.h>
#include "Pgp2PicModel.h"
using namespace std;

// Module declaration
SC_MODULE(RceLoop) {

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

   // Frame size constant in 32-bit words
   static const unsigned int frameSize = 31;

   // PIC Model
   Pgp2PicModel picModel;

   // Controlling thread
   void runThread(void);

   // Constructor
   SC_CTOR(RceLoop):
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
      picModel("picModel")
   {

      // Setup thread
      SC_THREAD(runThread);

      // Connect module
      picModel.Export_Clock(Export_Clock);
      picModel.Export_Core_Reset(Export_Core_Reset);
      picModel.Export_Data_Available(Export_Data_Available);
      picModel.Export_Data_Start(Export_Data_Start);
      picModel.Export_Advance_Data_Pipeline(Export_Advance_Data_Pipeline);
      picModel.Export_Data_Last_Line(Export_Data_Last_Line);
      picModel.Export_Data_Last_Valid_Byte(Export_Data_Last_Valid_Byte);
      picModel.Export_Data_Low(Export_Data_Low);
      picModel.Export_Data_High(Export_Data_High);
      picModel.Export_Advance_Status_Pipeline(Export_Advance_Status_Pipeline);
      picModel.Export_Status(Export_Status);
      picModel.Export_Status_Full(Export_Status_Full);
      picModel.Import_Clock(Import_Clock);
      picModel.Import_Core_Reset(Import_Core_Reset);
      picModel.Import_Free_List(Import_Free_List);
      picModel.Import_Advance_Data_Pipeline(Import_Advance_Data_Pipeline);
      picModel.Import_Data_Last_Line(Import_Data_Last_Line);
      picModel.Import_Data_Last_Valid_Byte(Import_Data_Last_Valid_Byte);
      picModel.Import_Data_Low(Import_Data_Low);
      picModel.Import_Data_High(Import_Data_High);
      picModel.Import_Data_Pipeline_Full(Import_Data_Pipeline_Full);
      picModel.Import_Pause(Import_Pause);
      picModel.Dcr_Clock(Dcr_Clock);
      picModel.Dcr_Write(Dcr_Write);
      picModel.Dcr_Write_Data(Dcr_Write_Data);
      picModel.Dcr_Read_Address(Dcr_Read_Address);
      picModel.Dcr_Read_Data(Dcr_Read_Data);
   }
};

#endif
