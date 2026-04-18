// Example code for an AHBLite System-on-Chip
//  Iain McNally
//  ECS, University of Soutampton
//
// This module is an AHB-Lite Slave containing a RAM
// Since this loads a program it is for FPGA use only
//
// Number of addressable locations : 2**MEMWIDTH
// Size of each addressable location : 8 bits
// Supported transfer sizes : Word, Halfword, Byte
// Alignment of base address : Word aligned
//

// Memory is synchronous which should suit block memory types
//   Read takes 1 cycle
//   Write takes 2 cycles (single wait state)
//
// Note this is not the most efficient design but works with
//  Xilinx and Altera(Intel) FPGAs
//


`ifdef PROG_FILE
  // already defined - do nothing
`else
  `define PROG_FILE  "code.hex"
`endif

module ahb_ram #(
  parameter MEMWIDTH = 14
)(
  //AHBLITE INTERFACE

    //Slave Select Signal
    input HSEL,
    //Global Signals
    input HCLK,
    input HRESETn,
    //Address, Control & Write Data
    input HREADY,
    input [31:0] HADDR,
    input [1:0] HTRANS,
    input HWRITE,
    input [2:0] HSIZE,
    input [31:0] HWDATA,
    // Transfer Response & Read Data
    output HREADYOUT,
    output [31:0] HRDATA

);

timeunit 1ns;
timeprecision 100ps;

  localparam No_Transfer = 2'b0;

// Memory Array  
  logic [31:0] memory[0:(2**(MEMWIDTH-2)-1)];

// other declarations
  logic [31:0] data_from_memory, data_to_memory;
  logic write_cycle, read_cycle;
  logic [MEMWIDTH-3:0] word_address, saved_word_address;
  logic [3:0] byte_select;
  

// read program into ram
  initial
    $readmemh( `PROG_FILE, memory, 0, (2**(MEMWIDTH-2)-1));
 
//Generate the control signals here:

  always_ff @(posedge HCLK, negedge HRESETn)
    if (! HRESETn )
      begin
        write_cycle <= '0;
        read_cycle <= '0;
        saved_word_address <= '0;
        byte_select <= '0;
      end
    else
      begin
        if ( HREADY && HSEL && (HTRANS != No_Transfer) )
          begin
            write_cycle <= HWRITE;
            read_cycle <= ! HWRITE;
            saved_word_address <= HADDR[MEMWIDTH-1:2];
            byte_select <= generate_byte_select( HSIZE, HADDR[1:0] );
         end
        else
          begin
            write_cycle <= '0;
            read_cycle <= '0;
         end
      end

  // the word address is available in the address phase
  always_comb
    if ( HREADY && HSEL && (HTRANS != No_Transfer) && ! write_cycle )
      word_address = HADDR[MEMWIDTH-1:2];
    else
      word_address = saved_word_address;
      
// model the memory here:

  // read and write are both synchronous
  // the code uses a simple format to ensure easy identification of RAM for synthesis
  always_ff @(posedge HCLK)
    begin
      data_from_memory <= memory[word_address];
      if ( write_cycle )
        memory[word_address] <= data_to_memory;
    end

// deal with byte access here:

  // byte write is achieved using a read-modify-write strategy
  // this slows down the write but avoids problems mapping byte-access RAM to block memory
  always_comb
    if (write_cycle)
      begin
        data_to_memory[ 7: 0] = ( byte_select[0] ) ? HWDATA[ 7: 0] : data_from_memory[ 7: 0];
        data_to_memory[15: 8] = ( byte_select[1] ) ? HWDATA[15: 8] : data_from_memory[15: 8];
        data_to_memory[23:16] = ( byte_select[2] ) ? HWDATA[23:16] : data_from_memory[23:16];
        data_to_memory[31:24] = ( byte_select[3] ) ? HWDATA[31:24] : data_from_memory[31:24];
      end
    else
      data_to_memory = '0;

  // only the required bytes are returned to the AHB-Lite bus
  // (output of zero when not enabled for read is not necessary but may help with debugging)
  assign HRDATA[ 7: 0] = ( read_cycle && byte_select[0] ) ? data_from_memory[ 7: 0] : '0;
  assign HRDATA[15: 8] = ( read_cycle && byte_select[1] ) ? data_from_memory[15: 8] : '0;
  assign HRDATA[23:16] = ( read_cycle && byte_select[2] ) ? data_from_memory[23:16] : '0;
  assign HRDATA[31:24] = ( read_cycle && byte_select[3] ) ? data_from_memory[31:24] : '0;


//Transfer Response
  assign HREADYOUT = ! write_cycle; //Single Cycle Wait State for Write


// decode byte select signals from the size and the lowest two address bits
  function logic [3:0] generate_byte_select( logic [2:0] size, logic [1:0] byte_adress );
    logic byte3, byte2, byte1, byte0;
    byte0 = size[1] || ( byte_adress == 0 );
    byte1 = size[1] || ( size[0] && ( byte_adress == 0 ) ) || ( byte_adress == 1 );
    byte2 = size[1] || ( byte_adress == 2 );
    byte3 = size[1] || ( size[0] && ( byte_adress == 2 ) ) || ( byte_adress == 3 );
    return { byte3, byte2, byte1, byte0 };
  endfunction

endmodule
