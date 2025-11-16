// --------------------------------------------------
// Document:  pjdl_idma_midend.sv
// Project:   PJON_ASIC/croc_pjon_hw
// Function:  midend for the idma to work with the pjdl module, this midend assigns a specific
//            address to the axis interace and allows to interrupt idma transfers when a pjdl packet
//            ends
// Autor:     Pius Sieber
// Date:      25.04.2025
// Comments:  -
// --------------------------------------------------

module pjdl_idma_midend #(
    parameter logic [31:0] axis_address = 32'h0000_0000,

    parameter type idma_req_t = logic,
    parameter type idma_rsp_t = logic,

    parameter type axis_large_req_t = logic,
    parameter type axis_large_rsp_t = logic
)(
    input  logic clk_i,
    input  logic rst_ni,

    // Connections to the frontend
    input idma_req_t frontend_idma_req_i,
    input logic frontend_idma_req_valid_i,
    output logic frontend_idma_req_ready_o,
    output logic frontend_idma_rsp_valid_o,
    input logic frontend_idma_rsp_ready_i,

    // Connections to the backend
    output idma_req_t backend_idma_req_o,
    output logic backend_idma_req_valid_o,
    input logic backend_idma_req_ready_i,
    input logic backend_idma_rsp_valid_i,
    output logic backend_idma_rsp_ready_o,

    // axis interface
    input axis_large_req_t axis_large_req_i,
    input axis_large_rsp_t axis_large_rsp_i
);
    `include "common_cells/registers.svh"

    // DMA midend signals
    idma_req_t midend_idma_req_q, midend_idma_req_d;
    logic midend_idma_req_valid_q, midend_idma_req_valid_d;
    logic midend_idma_req_ready_q, midend_idma_req_ready_d;
    logic midend_idma_rsp_valid_q, midend_idma_rsp_valid_d;
    logic midend_idma_rsp_ready_q, midend_idma_rsp_ready_d;

    logic midend_transfer_in_progress_q, midend_transfer_in_progress_d;
    logic midend_last_transfer_q, midend_last_transfer_d;
    logic midend_idma_req_prepare_valid_q, midend_idma_req_prepare_valid_d;

    always_comb begin
        midend_idma_req_ready_d = midend_idma_req_ready_q;
        midend_idma_req_valid_d = midend_idma_req_valid_q;
        midend_transfer_in_progress_d = midend_transfer_in_progress_q;
        midend_idma_rsp_ready_d = midend_idma_rsp_ready_q;
        midend_last_transfer_d = midend_last_transfer_q;
        midend_idma_req_prepare_valid_d = midend_idma_req_prepare_valid_q;
        midend_idma_rsp_valid_d = midend_idma_rsp_valid_q;
        midend_idma_req_d = midend_idma_req_q;

        backend_idma_req_o = midend_idma_req_q;
        

        if(!midend_transfer_in_progress_q) begin
            midend_last_transfer_d = 1'b0;
            if(frontend_idma_req_valid_i && midend_idma_req_ready_q) begin
                midend_idma_req_valid_d = 1'b1;
                midend_idma_req_ready_d = 1'b0;
                midend_idma_req_d = frontend_idma_req_i;

                // rewrite protocol if address is 0x2000_1018, to use this address for axi-stream
                if (frontend_idma_req_i.src_addr[31:0] == axis_address) begin
                    midend_idma_req_d.opt.src_protocol = idma_pkg::AXI_STREAM;

                    midend_transfer_in_progress_d = 1'b1;
                    midend_idma_req_valid_d = 1'b0;
                end
            end
            if(midend_idma_req_valid_q && backend_idma_req_ready_i) begin
                midend_idma_req_valid_d = 1'b0;
                midend_idma_req_ready_d = 1'b1;
            end

            if(backend_idma_rsp_valid_i && midend_idma_rsp_ready_q) begin
                midend_idma_rsp_valid_d = 1'b1;
                midend_idma_rsp_ready_d = 1'b0;
            end
            if(midend_idma_rsp_valid_q && frontend_idma_rsp_ready_i) begin
                midend_idma_rsp_valid_d = 1'b0;
                midend_idma_rsp_ready_d = 1'b1;
            end
            midend_idma_req_prepare_valid_d = 1'b1;
        end else begin
            midend_idma_req_ready_d = 1'b0;

            if(axis_large_req_i.tvalid&&midend_idma_req_prepare_valid_q) begin
                midend_idma_req_valid_d = 1'b1; // only start transfer if axis data is valid
                midend_idma_req_prepare_valid_d = 1'b0;
            end
            if(backend_idma_req_ready_i && midend_idma_req_valid_q) begin
                midend_idma_req_valid_d = 1'b0;
                if(axis_large_req_i.t.last) begin
                    midend_last_transfer_d = 1'b1;
                end
                if(midend_idma_req_q.length > 4) begin
                    midend_idma_req_d.length = midend_idma_req_q.length - 4;
                    midend_idma_req_d.dst_addr = midend_idma_req_q.dst_addr + 4;
                end else if (midend_last_transfer_q) begin
                    midend_transfer_in_progress_d = 1'b0;
                    midend_idma_req_ready_d = 1'b1;
                    midend_idma_req_valid_d = 1'b0;
                end else begin
                    midend_last_transfer_d = 1'b1;
                end
            end
            if(axis_large_req_i.tvalid&&axis_large_rsp_i.tready)begin
                midend_idma_req_prepare_valid_d = 1'b1;
                if(midend_last_transfer_q) begin
                    midend_transfer_in_progress_d = 1'b0;
                    midend_idma_req_ready_d = 1'b1;
                    midend_idma_req_valid_d = 1'b0;
                end
            end

            backend_idma_req_o.length = (midend_idma_req_q.length > 4) ? 4 : midend_idma_req_q.length;
        end

        if (midend_idma_req_q.dst_addr[31:0] == 32'h2000_1018) begin
            backend_idma_req_o.opt.dst_protocol = idma_pkg::AXI_STREAM;
        end
    end

    //assign backend_idma_req = midend_idma_req_q;
    assign backend_idma_req_valid_o = midend_idma_req_valid_q;
    assign frontend_idma_req_ready_o = midend_idma_req_ready_q;
    
    assign frontend_idma_rsp_valid_o = midend_idma_rsp_valid_q;
    assign backend_idma_rsp_ready_o = midend_idma_rsp_ready_q;

    `FF(midend_idma_req_q, midend_idma_req_d, '0);
    `FF(midend_idma_req_ready_q, midend_idma_req_ready_d, '1);
    `FF(midend_idma_req_valid_q, midend_idma_req_valid_d, '0);
    `FF(midend_idma_rsp_ready_q, midend_idma_rsp_ready_d, '1);
    `FF(midend_idma_rsp_valid_q, midend_idma_rsp_valid_d, '0);
    `FF(midend_transfer_in_progress_q, midend_transfer_in_progress_d, '0);
    `FF(midend_last_transfer_q, midend_last_transfer_d, '0);
    `FF(midend_idma_req_prepare_valid_q, midend_idma_req_prepare_valid_d, '0);
endmodule