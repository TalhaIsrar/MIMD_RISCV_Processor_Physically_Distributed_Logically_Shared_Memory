// Example code for an AHBLite System-on-Chip
//  Iain McNally
//  ECS, University of Soutampton
//
// This module is an AHB-Lite Slave containing two read/write registers
//
// Number of addressable locations : 2
// Size of each addressable location : 16 bits
// Supported transfer sizes : Half Word
// Alignment of base address : Word aligned
//
// Address map :
//   Base addess + 0 : 
//     Read DataOut register
//     Write DataOut register, Copy NextDataValid to DataValid
//   Base addess + 2 : 
//     Read NextDataValid and DataValid registers
//     Write NextDataValid register
//
// Bits within status register :
//   Bit 1   NextDataValid
//   Bit 0   DataValid


// In order to update the output, the software should update the NextDataValid
// register followed by the DataOut register.


module ahb_out(

  // AHB Global Signals
  input HCLK,
  input HRESETn,

  // AHB Signals from Master to Slave
  input [31:0] HADDR, // With this interface only HADDR[1] is used (other bits are ignored)
  input [31:0] HWDATA,
  input [2:0] HSIZE,
  input [1:0] HTRANS,
  input HWRITE,
  input HREADY,
  input HSEL,

  // AHB Signals from Slave to Master
  output logic [31:0] HRDATA,
  output HREADYOUT,

  //Non-AHB Signals
  output logic [15:0] DataOut,
  output logic DataValid

);

timeunit 1ns;
timeprecision 100ps;

  // AHB transfer codes needed in this module
  localparam No_Transfer = 2'b0;

  //control signals are stored in registers
  logic write_enable, read_enable;
  logic half_word_address;
 
  logic NextDataValid;
  logic [15:0] Status;

  //Generate the control signals in the address phase
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
      begin
        write_enable <= '0;
        read_enable <= '0;
        half_word_address <= '0;
      end
    else if ( HREADY && HSEL && (HTRANS != No_Transfer) )
      begin
        write_enable <= HWRITE;
        read_enable <= ! HWRITE;
        half_word_address <= HADDR[1];
     end
    else
      begin
        write_enable <= '0;
        read_enable <= '0;
        half_word_address <= '0;
     end

  //Act on control signals in the data phase

  // write
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
      begin
        DataOut <= '0;
        DataValid <= '0;
        NextDataValid <= '0;
      end
    else if ( write_enable && (half_word_address==0))
      begin
        DataOut <= HWDATA[15:0];
        DataValid <= NextDataValid;

        // this is not synthesized but provides useful debugging information
        if ( NextDataValid )
          $display( "DataOut:      ", HWDATA[15:0], " @", $time );
        else
          $display( "DataOut:--Invalid-- @", $time );

     end
    else if ( write_enable && (half_word_address==1))
      begin
        NextDataValid <= HWDATA[16];
     end

  // define the bits in the status register
  assign Status = { 14'd0, NextDataValid, DataValid};

  //read
  always_comb
    if ( ! read_enable )
      // (output of zero when not enabled for read is not necessary
      //  but may help with debugging)
      HRDATA = '0;
    else
      case (half_word_address)
        // ensure that half-word data is correctly aligned
        0 : HRDATA = { 16'd0, DataOut };
        1 : HRDATA = { Status, 16'd0 };
        // unused address - returns zero
        default : HRDATA = '0;
      endcase

  //Transfer Response
  assign HREADYOUT = '1; //Single cycle Write & Read. Zero Wait state operations


endmodule

