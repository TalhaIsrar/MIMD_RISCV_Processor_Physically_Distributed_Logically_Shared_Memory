module dma_controller(
    input HCLK,
    input HRESETn,

    // SLAVE PORT — CPU configures the DMA through here
    input  logic        HSEL_S,
    input  logic        HREADY_S,
    input  logic [31:0] HADDR_S,
    input  logic [31:0] HWDATA_S,
    input  logic        HWRITE_S,
    input  logic [1:0]  HTRANS_S,
    output logic        HREADYOUT_S,
    output logic [31:0] HRDATA_S,

    // MASTER PORT
    input  logic        HREADY_M,       // bus HREADY in (from interconnect)
    input  logic [31:0] HRDATA_M,       // read data from bus
    output logic [31:0] HADDR_M,
    output logic        HWRITE_M,
    output logic [31:0] HWDATA_M,
    output logic [1:0]  HTRANS_M,
    output logic [2:0]  HSIZE_M
);

    // Config registers (written by CPU via slave port)
    // Offset 0x00 : src_addr
    // Offset 0x04 : dst_addr
    // Offset 0x08 : length (word count)
    // Offset 0x0C : control  bit[0]=start, bit[1]=done (read-only)
    logic [31:0] src_addr_r, dst_addr_r, length_r;
    logic        start_r, done_r;

    // DMA Slave Operation (Configuration)
    // Two-phase: capture address in phase 1, act on data in phase 2
    logic        slv_write_ph2;
    logic [31:0] slv_addr_ph2;

    // DMA States
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        READ  = 2'b01,
        WRITE = 2'b10,
        DONE  = 2'b11
    } state_t;

    state_t state;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            slv_write_ph2 <= '0;
            slv_addr_ph2  <= '0;
        end else if (HREADY_S) begin
            slv_write_ph2 <= HSEL_S & HWRITE_S & (HTRANS_S != 2'b00);
            slv_addr_ph2  <= HADDR_S;
        end
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            src_addr_r <= '0;
            dst_addr_r <= '0;
            length_r   <= '0;
            start_r    <= '0;
        end else if (slv_write_ph2) begin
            case (slv_addr_ph2[3:0])
                4'h0: src_addr_r  <= HWDATA_S;
                4'h4: dst_addr_r  <= HWDATA_S;
                4'h8: length_r    <= HWDATA_S;
                4'hC: start_r     <= HWDATA_S[0]; // write 1 to start
                default: ;
            endcase
        end else begin
            // Auto-clear start once DMA picks it up
            if (start_r && (state == READ))
                start_r <= 1'b0;
        end
    end

    always_comb begin
        HREADYOUT_S = 1'b1;
        case (HADDR_S[3:0])
            4'h0:    HRDATA_S = src_addr_r;
            4'h4:    HRDATA_S = dst_addr_r;
            4'h8:    HRDATA_S = length_r;
            4'hC:    HRDATA_S = {30'b0, done_r, start_r};
            default: HRDATA_S = 32'hDEAD_BEEF;
        endcase
    end

    // DMA Master Operation (Transfer)

    logic [31:0] src_ptr, dst_ptr, cnt;
    logic [31:0] rd_data;   // buffer: holds data read from source

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state   <= IDLE;
            src_ptr <= '0;
            dst_ptr <= '0;
            cnt     <= '0;
            rd_data <= '0;
            done_r  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    done_r <= '0;
                    if (start_r) begin
                        src_ptr <= src_addr_r;
                        dst_ptr <= dst_addr_r;
                        cnt     <= length_r;
                        state   <= READ;
                    end
                end

                READ: begin
                    // Wait for READ address phase to be accepted
                    if (HREADY_M) begin
                        // Data phase of READ happens next cycle;
                        // we move to WRITE to present the dst address
                        // while capturing read data below
                        state <= WRITE;
                    end
                end

                WRITE: begin
                    // HRDATA_M is now valid (data phase of preceding read)
                    // We capture it and the WRITE address phase is presented
                    if (HREADY_M) begin
                        rd_data <= HRDATA_M;
                        // Advance pointers
                        src_ptr <= src_ptr + 4;
                        dst_ptr <= dst_ptr + 4;
                        cnt     <= cnt - 1;
                        if (cnt == 1)
                            state <= DONE;
                        else
                            state <= READ;
                    end
                end

                DONE: begin
                    // Wait one more cycle for the final write data phase
                    if (HREADY_M) begin
                        done_r <= 1'b1;
                        state  <= IDLE;
                    end
                end
            endcase
        end
    end

    always_comb begin
        // Defaults — idle bus
        HADDR_M  = '0;
        HWRITE_M = '0;
        HWDATA_M = '0;
        HTRANS_M = 2'b00;   // IDLE
        HSIZE_M  = 3'b010;  // 32-bit word

        case (state)
            READ: begin
                HADDR_M  = src_ptr;
                HWRITE_M = 1'b0;
                HTRANS_M = 2'b10;  // NONSEQ
            end
            WRITE: begin
                HADDR_M  = dst_ptr;
                HWRITE_M = 1'b1;
                HWDATA_M = rd_data;  // previous cycle's read data
                HTRANS_M = 2'b10;
            end
            DONE: begin
                // Final write data phase - hold write with no new address
                HWRITE_M = 1'b1;
                HWDATA_M = rd_data;
                HTRANS_M = 2'b00;  // IDLE - no new address
            end
            default: ;
        endcase
    end


endmodule