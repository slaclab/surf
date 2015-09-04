/*
Hamming Generator - Generates VHDL package with hamming encoder and decoder
Copyright (C) 2006  Alexandre de Morais Amory (amamory at gmail.com)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
http://www.fsf.org/licensing/licenses/gpl.txt
*/

#include <cstdlib>
#include <iostream>
#include <sstream>    // stringstream
#include <fstream>    // to create vhdl files

#include "hamm_secded_gen.h"
#include "hamm_sec_gen.h"

using namespace std;

int main(int argc, char *argv[])
{
   if( argc!=4){
      cout << "\nHamming Generator\n"
"HammingGen v.0.1 (26/Jun/2006).\n"
"Copyright Alexandre Amory(amamory@inf.ufrgs.br)\n"
"Usage: HammingGen <SEC/SEC-DED> <data width> <project_name>\n"
"SEC - single-error-correction\n"
"DED - double-error-detection\n"
"Description: Generates VHDL package with hamming encoder and decoder\n";
      exit(0);
   }

//   Conventional_Core *ccore;
   int width;
   stringstream strStream;

   // get the data width
   strStream << argv[2];
   strStream >> width;

   // get type of hamming code
   string hammingType = argv[1];

   // set file names
   string projectName = argv[3];
   string packageFileName = projectName + "_hamming" + hammingType + "_" + strStream.str() + "_pkg.vhd";
   string tbFileName = projectName + "_hamming" + hammingType + "_" + strStream.str() + "_tb.vhd";
   cout << hammingType << " " << width << " " << projectName << endl;

   if (hammingType == "SEC"){
      cout << "Generating Hamming SEC ..." << endl;
      HammingSec hamSec(width);
      hamSec.GeneratePackageFile(packageFileName.c_str());
      cout << "Hamming Package generated!!!" << endl;
      hamSec.GenerateTBFile(tbFileName.c_str());
      cout << "Hamming Testbench generated!!!" << endl;
   }else if (hammingType == "SEC-DED"){
      cout << "Generating Hamming SEC/DED ..." << endl;
      HammingSecDed hamSecDed(width);
      hamSecDed.GeneratePackageFile(packageFileName.c_str());
      cout << "Hamming Package generated!!!" << endl;
      hamSecDed.GenerateTBFile(tbFileName.c_str());
      cout << "Hamming Testbench generated!!!" << endl;
   }else{
      cout << "ERROR: invalid parameter. Valid input is SEC or SEC-DED" << endl;
      exit(0);
   }

   return EXIT_SUCCESS;
}
