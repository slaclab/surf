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

DESCRIPTION:
  This program generates a VHDL package of hamming code for
SEC (single error correction). It can correct one bit.
  This codes can generate hamming code for n bits, where n must be
greater than two (or three?!?).
  In, see below, "HAMM_GEN hamm(dataWidth);" you must pass the width
and in "hamm.GeneratePackageFile(argv[2]);" you must pass the name of
the resulting file.

**************************************
HOW TO USE THE HAMMING CODE GENERATOR:
**************************************

  The hamming code generator can be used in others codes
like the example presented below.

#include <iostream>
#include "hamm_gen.h"
using namespace std;

int main(int argc, char **argv){
  int dataWidth;

  sscanf(argv[1],"%d",&dataWidth);

  HAMM_GEN hamm(dataWidth);

  cout << "Generating hamming package ...\n";
  hamm.GeneratePackageFile(argv[2]);
  cout << "Generating hamming testbench ...\n";
  hamm.GenerateTBFile(argv[3]);
  cout << "Hamming package generated!!\n";

  return 0;
}

HOW TO USE THE CODE HAMMING GENERATED:

  The resulting VHDL package has two function. One for Hamming encoding and
other for decoding.

PROTOTYPE:

  FUNCTION hamming_encoder_16bit(data_in:data_ham_16bit) RETURN parity_ham_16bit;
  FUNCTION hamming_decoder_16bit(data_parity_in:coded_ham_16bit) RETURN data_ham_16bit;

EXAMPLE OF USAGE:
  Here there is a example of register using the VHDL package.

  process(clk)
  begin
    if (clk'event and clk='1') then
      reg <= data_in & hamming_encoder_16bit(data_in);
    end if;
  end process;

  data_out <= hamming_decoder_16bit(reg);

*/

//---------------------------------------------------------------------------
#ifndef hamm_sec_genH
#define hamm_sec_genH
//---------------------------------------------------------------------------
#include <string>
#include <stdlib.h>
#include <stdio.h>
using namespace std;

//---------------------------------------------------------------------------
class HammingSec {
private:
  int   dataBits,parityBits;//number of data and parity bits to encode hamming
  FILE  *fp; //destination file pointer

  // main functions
  void GenerateCorrector(void);
  void GenerateEnc(void);
  void GenerateGen(void);
  // auxiliar functions
  bool PotOf2(int value);
  int GetParityBits(int databits);
  // encoder and decorder function
  int ReturnIndex(int last);
  string toBit(int number,int width);
  string writeTB(void);

public:
  ~HammingSec();
  HammingSec(int dBits);
  void GeneratePackageFile(string targetFile);
  void GenerateTBFile(string targetFile);
};
#endif
