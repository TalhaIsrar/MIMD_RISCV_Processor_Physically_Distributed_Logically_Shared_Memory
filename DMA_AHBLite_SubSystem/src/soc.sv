module soc (
  input HCLK,
  input HRESETn,
  output [15:0] DataOut,
  output DataValid
)
  // Global & Master AHB Signals
  wire [31:0] HADDR, HADDR_M0, HADDR_M1, HWDATA, HWDATA_M0, HWDATA_M1, HRDATA;
  wire [1:0] HTRANS_M0, HTRANS_M1, HTRANS;
  wire [2:0] HSIZE_M0, HSIZE_M1, HBURST;
  wire [3:0] HPROT;
  wire HWRITE, HWRITE_M0, HWRITE_M1 , HMASTLOCK, HRESP;
  wire HREADY_M0, HREADY_M1 , HREADY;

  // Per-Slave AHB Signals
  wire HSEL_RAM1, HSEL_RAM2, HSEL_DMA, HSEL_OUT;
  wire [31:0] HRDATA_RAM1, HRDATA_RAM2, HRDATA_DMA, HRDATA_OUT;
  wire HREADYOUT_RAM1, HREADYOUT_RAM2, HREADYOUT_DMA, HREADYOUT_OUT;

  // Arbiter Signals
  wire [1:0] HBUSREQ;

  // Set this to zero because PicoRV32 does not support LOCKUP
  assign LOCKUP = '0;

  // Set this to zero because simple slaves do not generate errors
  assign HRESP = '0;

  assign HBUSREQ = {HTRANS_M1[1], HTRANS_M0[1]};

  // PicoRV32 is AHB Master
  picorv32_ahb riscv_1 (

    // AHB Signals
    .HCLK, .HRESETn,
    .HADDR_M0, .HBURST, .HMASTLOCK, .HPROT, .HSIZE_M0, .HTRANS_M0, .HWDATA_M0, .HWRITE_M0,
    .HRDATA, .HREADY_M0, .HRESP                                   

  );

  // AHB Arbiter is used to connect 2 Masters
  ahb_arbiter ahb_arbiter_inst(
    .HCLK(HCLK), .HRESETn(HRESETn), .HBUSREQ(HBUSREQ),
    .HADDR_M0(HADDR_M0), .HWRITE_M0(HWRITE_M0), .HWDATA_M0(HWDATA_M0), HTRANS_M0(HTRANS_M0), HSIZE_M0(HSIZE_M0),
    .HADDR_M1(HADDR_M1), .HWRITE_M1(HWRITE_M1), .HWDATA_M1(HWDATA_M1), HTRANS_M1(HTRANS_M1), HSIZE_M1(HSIZE_M1),
    .HREADY(HREADY),
    .HADDR(HADDR), .HWRITE(HWRITE), .HWDATA(HWDATA), .HTRANS(HTRANS), HSIZE(HSIZE),
    .HGRANT({HREADY_M1, HREADY_M0})
  );


  // AHB interconnect including address decoder, register and multiplexer
  ahb_interconnect interconnect_1 (
    .HCLK, .HRESETn, .HADDR, .HRDATA, .HREADY,
    .HSEL_SIGNALS({HSEL_OUT,HSEL_DMA,HSEL_RAM2,HSEL_RAM1}),
    .HRDATA_SIGNALS({HRDATA_OUT,HRDATA_DMA,HRDATA_RAM2,HRDATA_RAM1}),
    .HREADYOUT_SIGNALS({HREADYOUT_OUT,HREADYOUT_DMA,HREADYOUT_RAM2,HREADYOUT_RAM1})

  );


  // Slaves
  // RAM 1 - Start Address 0x0000_0000, Range 4K Words
  ahb_ram ram_1 (
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_RAM1),
    .HRDATA(HRDATA_RAM1), .HREADYOUT(HREADYOUT_RAM1)
  );

  // RAM 2 - Start Address 0x1000_0000, Range 4K Words
  ahb_ram ram_2 (
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_RAM2),
    .HRDATA(HRDATA_RAM2), .HREADYOUT(HREADYOUT_RAM2)
  );

    ahb_out out_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_OUT),
    .HRDATA(HRDATA_OUT), .HREADYOUT(HREADYOUT_OUT),

    .DataOut(DataOut), .DataValid(DataValid)

  );

  // DMA Controller
  dma_controller dma_controller_inst(
    .HCLK(HCLK), .HRESETn(HRESETn),
    // Slave configuration ports
    .HSELS(HSEL_DMA), .HREADY_S(HREADY), .HADDR_S(HADDR), .HWDATA_S(HWDATA),
    .HWRITE_S(HWRITE), .HTRANS_S(HTRANS), .HREADYOUT_S(HREADYOUT_DMA), .HRDATA_S(HRDATA_DMA)

    // Master DMA ports
    .HREADY_M(HREADY_M1), .HRDATA_M(HRDATA), .HADDR_M(HADDR_M1), .HWRITE_M(HWRITE_M1),
    .HWDATA_M(HWDATA_M1), .HTRANS_M(HTRANS_M1), .HSIZE_M(HSIZE_M1)
  );

endmodule