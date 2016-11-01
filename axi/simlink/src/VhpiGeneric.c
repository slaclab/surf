//-----------------------------------------------------------------------------
// Title         : Pretty Good Protocol, VHPI Library Generic Interface
// Project       : General Purpose Core
//-----------------------------------------------------------------------------
// File          : VhpiGeneric.c
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/03/2007
//-----------------------------------------------------------------------------
// Description:
// This is a generic block of code to handle the low level interface to the
// VHDL simulator. The user code can access all bits through bit variables
// and only has to set the width and the in/out types for each port.
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------
// Modification history:
// 04/03/2007: created.
// 05/11/2007: Added ability to tri-state outputs.
//-----------------------------------------------------------------------------

//ENUM Types
// 0   /* uninitialized */
// 1   /* unknown */
// 2   /* forcing 0 */
// 3   /* forcing 1 */
// 4   /* high impedance */
// 5   /* weak unknown */
// 6   /* weak 0 */
// 7   /* weak 1 */
// 8   /* don't care */

#include "VhpiGeneric.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <string.h>

// Convert input values from enum to int
void VhpiGenericConvertIn( portDataT *portData ) {

   // Go through each port
   int x,y,bit;
   for (x=0; x < portData->portCount; x++) {
      if ( portData->portDir[x] != vhpiOut ) {
         if ( portData->portWidth[x] == 1 ) {
            if ( portData->portValue[x]->value.enumval == 3 ) 
               portData->intValue[x] = 1;
            else
               portData->intValue[x] = 0;
         }
         else {
            portData->intValue[x] = 0;
            for (y=0; y < portData->portWidth[x]; y++) {
               bit = (portData->portWidth[x] - 1) - y;
               if ( portData->portValue[x]->value.enums[y] == 3 ) 
                  portData->intValue[x] += 1<<bit;
            }
         }
      }
   }
}


// Convert output values from int to enum
void VhpiGenericConvertOut( portDataT *portData ) {

   // Go through each port
   int x,y,bit,temp;
   for (x=0; x < portData->portCount; x++) {
      if ( portData->portDir[x] != vhpiIn ) {
         if ( portData->portWidth[x] == 1 ) {
            if ( portData->outEnable[x] == 1 ) {
               if ( portData->intValue[x] == 0 )
                  portData->portValue[x]->value.enumval = 2;
               else
                  portData->portValue[x]->value.enumval = 3;
            }
            else portData->portValue[x]->value.enumval = 4; // Tri-state
         }
         else {
            if ( portData->outEnable[x] == 1 ) {
               for (y=0; y < portData->portWidth[x]; y++) {
                  bit = (portData->portWidth[x] - 1) - y;
                  temp = 1<<bit;
                  if ( (portData->intValue[x] & temp) != 0 )
                     portData->portValue[x]->value.enums[y] = 3;
                  else
                     portData->portValue[x]->value.enums[y] = 2;
               }
            }
            else 
               for (y=0; y < portData->portWidth[x]; y++) {
                  portData->portValue[x]->value.enums[y] = 4; // Tri-state
               }
         }
      }
   }
}


// Function that is called when the inputs have changed state
// Copy values over and call user function for further handling
void VhpiGenericCallBack(vhpiCbDataT *cbData ) {

   int x;

   // Get user data
   portDataT *portData = (portDataT *)cbData->user_data;

   // Get current state of all ports
   for (x=0; x < portData->portCount; x++) {

      // Get the inital input values
      if ( portData->portDir[x] != vhpiOut )
         vhpi_get_value(portData->portHandle[x],portData->portValue[x]);
   }

   // Convert Input values
   VhpiGenericConvertIn(portData);

   // Get simulation time
   vhpi_get_time(&(portData->simTime),NULL);

   // Call the user function to update state
   portData->stateUpdate ( portData );

   // Convert Output values
   VhpiGenericConvertOut(portData);

   // Set output values
   for (x=0; x < portData->portCount; x++) {
      if ( portData->portDir[x] != vhpiIn ) 
         vhpi_put_value(portData->portHandle[x],portData->portValue[x], vhpiForcePropagate);
   }
}


// Error handling function
void VhpiGenericErrors ( vhpiCbDataT *cb ) {
   vhpiErrorInfoT g_error;
   while (vhpi_chk_error(&g_error))
      vhpi_printf("\tError: %s: %s\n",g_error.str,g_error.message);
}


// Function that is called as the module is elaborated.
// Here we will simply register an error handling callback function. 
void VhpiGenericElab(vhpiHandleT compInst) {

   // Create callback structure, setup callback function
   vhpiCbDataT* pCbData = (vhpiCbDataT*) malloc(sizeof(vhpiCbDataT));
   pCbData->cbf    = VhpiGenericErrors;
   pCbData->time   = (vhpiTimeT*) malloc(sizeof(vhpiTimeT));
   pCbData->reason = vhpiCbPLIError;
   
#if (VCS_VERSION >= 2016)
   vhpi_register_cb(pCbData,vhpiReturnCb);
#else
   vhpi_register_cb(pCbData);
#endif   
}


// Function that is called as the module is initialized. 
// Check ports and setup functions to handle clock changes
void VhpiGenericInit(vhpiHandleT compInst, portDataT *portData ) {

   vhpiCbDataT *cbData;
   int width;
   int x, y;
   char *temp;

   // Blank out port handles and create value structures
   for (x=0; x < portData->portCount; x++) {
      portData->portHandle[x] = 0;
      portData->portValue[x]  = (vhpiValueT *) malloc(sizeof(vhpiValueT));
      portData->intValue[x]   = 0;
      portData->outEnable[x]  = 1;
   }

   // Copy block name
   temp = vhpi_get_str(vhpiFullNameP, compInst);
   portData->blockName = (char *) malloc(strlen(temp)+1);
   strcpy(portData->blockName,temp);

   // Get each port and verify width and direction, get initial value
   for (x=0; x < portData->portCount; x++) {

      // Get ID
      portData->portHandle[x] = vhpi_handle_by_index(vhpiPortDecls,compInst,x);

      // Setup value types
      if ( portData->portWidth[x] == 1 ) {
         portData->portValue[x]->format        = vhpiEnumVal;
         portData->portValue[x]->value.enumval = 2;
      } else {
         portData->portValue[x]->format        = vhpiEnumVecVal;
         width = vhpi_value_size(portData->portHandle[x],vhpiEnumVecVal);
         portData->portValue[x]->value.enums   = (vhpiEnumT*)malloc(width);
         for (y=0; y < portData->portWidth[x]; y++ ) 
            portData->portValue[x]->value.enums[y] = 2;
      }

      // Check direction
      if (vhpi_get(vhpiModeP, portData->portHandle[x]) != portData->portDir[x])
          vhpi_printf("Error: Port '%s' direction mismatch\n",
             vhpi_get_str(vhpiFullNameP, portData->portHandle[x]));

      // Check width
      if (vhpi_get(vhpiSizeP, portData->portHandle[x]) != portData->portWidth[x])
          vhpi_printf("Error: Port '%s' size mismatch\n",
             vhpi_get_str(vhpiFullNameP, portData->portHandle[x]));

      // Get the inital input values
      if ( portData->portDir[x] != vhpiOut )
         vhpi_get_value(portData->portHandle[x],portData->portValue[x]);

      // Set the inital output values
      if ( portData->portDir[x] != vhpiIn )
         vhpi_put_value(portData->portHandle[x],portData->portValue[x], vhpiForcePropagate);
   }

   // Setup callback function for port 0& 1
   for (x=0; x < 1; x++) {
      cbData = (vhpiCbDataT *) malloc(sizeof(vhpiCbDataT));
      cbData->reason    = vhpiCbValueChange;
      cbData->obj       = portData->portHandle[x];
      cbData->value     = portData->portValue[x];
      cbData->cbf       = VhpiGenericCallBack;
      cbData->time      = (vhpiTimeT *) malloc(sizeof(vhpiTimeT));
      cbData->user_data = (void *)portData;
      #if (VCS_VERSION >= 2016)
         vhpi_register_cb(cbData,vhpiReturnCb);
      #else
         vhpi_register_cb(cbData);
      #endif       
   }
}
