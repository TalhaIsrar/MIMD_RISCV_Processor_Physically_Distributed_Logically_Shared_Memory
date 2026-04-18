module soc_stim();
     
timeunit 1ns;
timeprecision 100ps;

  logic HRESETn, HCLK; 
  wire [15:0] DataOut;
  wire DataValid;

  soc dut(.HCLK, .HRESETn, .DataOut, .DataValid);

  always
    begin
           HCLK = 0;
      #5ns HCLK = 1;
      #10ns HCLK = 0;
      #5ns HCLK = 0;
    end

  initial
    begin
            HRESETn = 0;
            Buttons = 0;
            Switches = 1;
      #10.0ns HRESETn = 1;
            
      #250us $stop;
            $finish;
    end
       
endmodule
