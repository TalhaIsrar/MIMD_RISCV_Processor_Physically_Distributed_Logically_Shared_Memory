module ahb_arbiter(
    // Global Signals
    input HCLK,
    input HRESETn,

    // Requests
    input [1:0]     HBUSREQ,

    // Master 0
    input [31:0]    HADDR_M0,
    input           HWRITE_M0,
    input [31:0]    HWDATA_M0,
    input [1:0]     HTRANS_M0,
    input [2:0]     HSIZE_M0,
 
    // Master 1
    input [31:0]    HADDR_M1,
    input           HWRITE_M1,
    input [31:0]    HWDATA_M1,
    input [1:0]     HTRANS_M1,
    input [2:0]     HSIZE_M1,

    // Interconnect
    input HREADY,

    // Signals to bus
    output logic [31:0] HADDR,
    output logic        HWRITE,
    output logic [31:0] HWDATA,
    output logic [1:0]  HTRANS,
    output logic [2:0]  HSIZE,

    // Grant to Masters
    output logic [1:0]  HGRANT

);

    timeunit 1ns; timeprecision 1ps;
    logic granted_to_m1;
    logic grant_next;

    // Combinational arbitration decision
    // Priority: M1 (DMA) > M0 (CPU) to allow DMA to drain quickly
    always_comb begin
        if (HBUSREQ[1]) grant_next = 1'b1;
        else            grant_next = 1'b0;
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            granted_to_m1 <= 1'b0;
        else if (HREADY)
            granted_to_m1 <= grant_next;
    end

    always_comb begin
        if (granted_to_m1) begin
            HADDR  = HADDR_M1;
            HWRITE = HWRITE_M1;
            HWDATA = HWDATA_M1;
            HTRANS = HTRANS_M1;
            HSIZE  = HSIZE_M1;
            HGRANT = {HREADY, 1'b0};
        end else begin
            HADDR  = HADDR_M0;
            HWRITE = HWRITE_M0;
            HWDATA = HWDATA_M0;
            HTRANS = HTRANS_M0;
            HSIZE  = HSIZE_M0;
            HGRANT = {1'b0, HREADY & ~grant_next};  // kill CPU's HREADY if DMA wins next 
        end
    end

endmodule
