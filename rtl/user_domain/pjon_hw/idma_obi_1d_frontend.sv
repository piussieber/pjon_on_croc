// --------------------------------------------------
// Document:  idma_obi_1d_frontend.sv
// Project:   PJON_ASIC/croc_pjon_hw
// Function:  frontend for idm supporting id transfers, configurable over OBI
// Autor:     Pius Sieber
// Date:      25.04.2025
// Comments:  -
// --------------------------------------------------
module idma_obi_1d_frontend #(
    // The OBI configuration for all ports.
    parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
    // The request struct.
    parameter type                         obi_req_t   = logic,
    // The response struct.
    parameter type                         obi_rsp_t   = logic,

    parameter type                         idma_req_t  = logic,
    parameter type                         idma_rsp_t  = logic,
    parameter type                         idma_busy_t = logic
)(
    input   logic clk_i,
    input   logic rst_ni,

    // OBI interface
    input   obi_req_t dma_obi_ctrl_req_i,
    output  obi_rsp_t dma_obi_ctrl_rsp_o,

    // Connections to the backend
    output  idma_req_t dma_req_o,
    output  logic req_valid_o,
    input   logic req_ready_i,

    input   logic rsp_valid_i,
    output  logic rsp_ready_o,
    input   idma_busy_t busy_status_i, // full backend busy status

    output logic busy_o
);
    `include "common_cells/registers.svh"
    `include "idma/typedef.svh"

    // Obi signal registers
    logic req_d, req_q;
    logic we_d, we_q;
    logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
    logic [ObiCfg.IdWidth-1:0] id_d, id_q;
    logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

    // Signals used to create the obi response
    logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
    logic rsp_err; // Error field of the obi response

    // DMA-connection signal registers
    logic dma_req_valid_d, dma_req_valid_q;
    logic dma_req_ready_d, dma_req_ready_q;
    logic dma_rsp_valid_d, dma_rsp_valid_q;

    logic busy_q, busy_d; // backend busy signal

    // Registers for the dma control
    logic [31:0] length_q, length_d;
    logic [31:0] src_addr_q, src_addr_d;
    logic [31:0] dst_addr_q, dst_addr_d;

    // ToDo: make options changeable

    always_comb begin // dma_req_o assignments
        dma_req_o = '0; // set all unasigned fields to zero

        // Protocols
        dma_req_o.opt.src_protocol = idma_pkg::OBI; // default, can be changed by midend
        dma_req_o.opt.dst_protocol = idma_pkg::OBI; // default, can be changed by midend

        // Current backend only supports incremental burst
        dma_req_o.opt.src.burst = axi_pkg::BURST_INCR;
        dma_req_o.opt.dst.burst = axi_pkg::BURST_INCR;
        // this frontend currently does not support cache variations
        dma_req_o.opt.dst.cache = axi_pkg::CACHE_MODIFIABLE;
        dma_req_o.opt.src.cache = axi_pkg::CACHE_MODIFIABLE;

        // Backend options -> ToDo: check options
        dma_req_o.opt.beo.decouple_aw    = 1'b0;
        dma_req_o.opt.beo.decouple_rw    = 1'b0;
        dma_req_o.opt.beo.src_max_llen   = 3'd1;
        dma_req_o.opt.beo.dst_max_llen   = 3'd1;
        dma_req_o.opt.beo.src_reduce_len = 1'b0;
        dma_req_o.opt.beo.dst_reduce_len = 1'b0;
        dma_req_o.opt.last = 1'b0;

        // Main dma request assignments
        dma_req_o.src_addr = src_addr_q;
        dma_req_o.dst_addr = dst_addr_q;
        dma_req_o.length = length_q;
    end

    // Signal assignments to midend or backend
    assign req_valid_o = dma_req_valid_q;
    assign dma_req_ready_d = req_ready_i;
    assign rsp_ready_o = 1'b1; // always ready to not interrupt backend

    //OBI assignemts
    assign req_d = dma_obi_ctrl_req_i.req;
    assign id_d = dma_obi_ctrl_req_i.a.aid;
    assign we_d = dma_obi_ctrl_req_i.a.we;
    assign addr_d = dma_obi_ctrl_req_i.a.addr;
    assign wdata_d = dma_obi_ctrl_req_i.a.wdata;

    assign busy_o = busy_q; // ToDo: improve signal calculation

    // Always-ff statements
    `FF(req_q, req_d, '0);
    `FF(id_q , id_d , '0);
    `FF(we_q , we_d , '0);
    `FF(wdata_q , wdata_d , '0);
    `FF(addr_q , addr_d , '0);
    `FF(dma_req_valid_q , dma_req_valid_d , '0);
    `FF(length_q , length_d , '0);
    `FF(src_addr_q , src_addr_d , '0);
    `FF(dst_addr_q , dst_addr_d , '0);
    `FF(dma_req_ready_q , dma_req_ready_d , '0);
    `FF(dma_rsp_valid_q , dma_rsp_valid_d , '0);
    `FF(busy_q, busy_d, '0);

    logic [2:0] word_addr;
    always_comb begin
        rsp_data = '0;
        rsp_err  = '0;
        word_addr = addr_q[4:2];

        length_d = length_q;
        src_addr_d = src_addr_q;
        dst_addr_d = dst_addr_q;
        dma_req_valid_d = dma_req_valid_q;

        dma_rsp_valid_d = rsp_valid_i;
        busy_d = busy_q;

        if(dma_req_ready_q&&dma_req_valid_q) begin
            dma_req_valid_d = 1'b0;
        end

        if(dma_rsp_valid_q) begin
            busy_d = 1'b0;
        end

        if(req_q) begin
            if(we_q) begin
                case(word_addr)
                    3'd1: begin // length, writing to this register starts the dma command execution
                        length_d = wdata_q[31:0];
                        dma_req_valid_d = 1'b1;
                        busy_d = 1'b1;
                    end
                    3'd2: begin
                        src_addr_d = wdata_q[31:0];
                    end
                    3'd3: begin
                        dst_addr_d = wdata_q[31:0];
                    end
                    default: rsp_err = 1'b1;
                endcase
            end else begin
                case(word_addr)
                    3'h1: begin
                        rsp_data = length_q;
                    end
                    3'h2: begin
                        rsp_data = src_addr_q;
                    end
                    3'h3: begin
                        rsp_data = dst_addr_q;
                    end
                    3'h4: begin // returns one if idma is ready to receive next command
                        rsp_data = {31'h0, !dma_req_valid_q}; // ToDo: some more testing is needed if this register should be used 
                    end                               //       -> better wait for command done (register 7)
                    3'h5: begin  // returns the busy status of the idma
                        rsp_data = busy_status_i;
                    end
                    3'h6: begin // returns one if the execution of the last command is done
                        rsp_data = {31'b0, !busy_q};
                    end
                    default: rsp_data = 32'hffffffff;
                endcase
            end
        end
    end

    // Wire the response
    // A channel
    assign dma_obi_ctrl_rsp_o.gnt = dma_obi_ctrl_req_i.req;
    // R channel:
    assign dma_obi_ctrl_rsp_o.rvalid = req_q;
    assign dma_obi_ctrl_rsp_o.r.rdata = rsp_data;
    assign dma_obi_ctrl_rsp_o.r.rid = id_q;
    assign dma_obi_ctrl_rsp_o.r.err = rsp_err;
    assign dma_obi_ctrl_rsp_o.r.r_optional = '0;
endmodule