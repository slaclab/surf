{ "signal" : [
  { "name": "saciSelL",    "wave": "10...........................|...|.......................1"},
  { "name": "saciClk",     "wave": "p............................|...|........................" },
  { "name": "saciCmd",     "wave": "0.145......5...........3.....|..0|........................",   "data": [ "Read", "Command", "Address", "Data (32 bits)"] },
  {},  
  { "name": "saciRsp",     "wave": "z0...........................|...|.145......5...........0z", "data": [ "Read", "Command", "Address"] },

  
]}

--------------------

Write
{ "signal" : [
  { "name": "saciSelL",    "wave": "1.0........................................"},
  { "name": "saciClk",     "wave": "p.........................................." },
  { "name": "saciCmd",     "wave": "0..115......5...........3...............0..",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  {},  
  { "name": "saciRsp",     "wave": "z.0........................................", "data": ["Command[6:0]", "Address[11:0]", "Data[31:0]" ] },
]}

Better Write
{ "signal" : [
  { "name": "saciSelL",    "wave": "1.0.........................|...."},
  { "name": "saciClk",     "wave": "p...........................|...." },
  { "name": "saciCmd",     "wave": "0..115......3...........4...|.0..",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  { "name": "saciRsp",     "wave": "z.0.........................|....", "data": ["Command[6:0]", "Address[11:0]", "Data[31:0]" ] },
]} 

Write Response
{ "signal" : [
  { "name": "saciSelL",    "wave": "0.......................1."},
  { "name": "saciClk",     "wave": "p........................." },
  { "name": "saciCmd",     "wave": "0.........................",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  { "name": "saciRsp",     "wave": "0115......3...........0.z.", "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
]}
       
Read
{ "signal" : [
  { "name": "saciSelL",    "wave": "1.0........................"},
  { "name": "saciClk",     "wave": "p.........................." },
  { "name": "saciCmd",     "wave": "0..105......3...........0..",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  { "name": "saciRsp",     "wave": "z.0........................", "data": ["Command[6:0]", "Address[11:0]", "Data[31:0]"] },
]}

Read Response
{ "signal" : [
  { "name": "saciSelL",    "wave": "0.......................................1."},
  { "name": "saciClk",     "wave": "p........................................." },
  { "name": "saciCmd",     "wave": "0.........................................",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  {},  
  { "name": "saciRsp",     "wave": "0105......5...........4...............0.z.", "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },

  
]} 
Better Read Response  
{ "signal" : [
  { "name": "saciSelL",    "wave": "0.........................|..1."},
  { "name": "saciClk",     "wave": "p.........................|...." },
  { "name": "saciCmd",     "wave": "0.........................|....",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  { "name": "saciRsp",     "wave": "0105......5...........4...|0.z.", "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
]} 


----------------------



junk
{ "signal" : [
  { "name": "saciSelL",    "wave": "1.0......................................1."},
  { "name": "saciClk",     "wave": "p.........................................." },
  { "name": "saciCmd",     "wave": "0..115......5...........0..................",   "data": [ "Command[6:0]", "Address[11:0]", "Data[31:0]"] },
  {},  
  { "name": "saciRsp",     "wave": "z.0.......................115......5..........4...............0.", "data": ["Command[6:0]", "Address[11:0]", "Data[31:0]"] },

  
]}
          
