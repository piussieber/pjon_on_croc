// --------------------------------------------------
// Document:  pjdl_wrap.sv
// Project:   PJON_ASIC/croc_pjon_hw
// Function:  wrap to connect croc directly to PJDL
// Autor:     Pius Sieber
// Date:      19.04.2025
// Comments:  -
// --------------------------------------------------

module pjdl_wrap #(
    // The OBI configuration for all ports.
    parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
    parameter obi_pkg::obi_cfg_t           MgrObiCfg   = obi_pkg::ObiDefaultConfig,
    // The request struct.
    parameter type                         obi_req_t   = logic,
    parameter type                         obi_mgr_req_t = logic,
    // The response struct.
    parameter type                         obi_rsp_t   = logic,
    parameter type                         obi_mgr_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    // HW interface
    input   logic pjon_i,
    output  logic pjon_o,
    output  logic pjon_en_o,

    // OBI request interface
    input  obi_req_t obi_req_i,
    // OBI response interface
    output obi_rsp_t obi_rsp_o,

    // DMA OBI request interface
    input  obi_req_t obi_dma_req_i,
    // DMA OBI response interface
    output obi_rsp_t obi_dma_rsp_o,

    // obi manager interfaces
    output obi_mgr_req_t obi_mgr_idma_write_req_o,
    input obi_mgr_rsp_t obi_mgr_idma_write_rsp_i,
    output obi_mgr_req_t obi_mgr_idma_read_req_o,
    input obi_mgr_rsp_t obi_mgr_idma_read_rsp_i
);
    `include "axi_stream/typedef.svh"
    `include "common_cells/registers.svh"

    localparam int unsigned AxisDataWidth       = 8; 

    // Axi Stream typedefs
    typedef logic [AxisDataWidth-1:0]     axis_data_t;
    typedef logic                         axis_strb_t;
    typedef logic                         id_t; // id not used
    typedef logic [1:0]                   user_t; // 2 bits
    `AXI_STREAM_TYPEDEF_S_CHAN_T(axis_t_chan_t, axis_data_t, axis_strb_t, axis_strb_t, id_t, id_t, user_t)
    `AXI_STREAM_TYPEDEF_REQ_T(axis_req_t, axis_t_chan_t)
    `AXI_STREAM_TYPEDEF_RSP_T(axis_rsp_t)

    // Define some registers to hold the requests fields
    logic req_d, req_q;
    logic we_d, we_q;
    logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
    logic [ObiCfg.IdWidth-1:0] id_d, id_q;
    logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

    // registers for directly sent axi-stream data
    logic [10:0] axi_stream_send_data_d, axi_stream_send_data_q;
    logic [8:0] axi_stream_receive_data_d, axi_stream_receive_data_q;

    logic axi_direct_send_valid_d, axi_direct_send_valid_q;
    logic axi_direct_send_ready_d, axi_direct_send_ready_q;
    logic axi_direct_receive_valid_d, axi_direct_receive_valid_q;
    logic axi_direct_read_data_available_d, axi_direct_read_data_available_q;
    logic dma_receiving_process_happend_d, dma_receiving_process_happend_q;

    axis_rsp_t axis_dma_write_rsp;
    axis_req_t axis_dma_write_req;
    axis_req_t axis_dma_read_req;
    axis_rsp_t axis_dma_read_rsp;

    logic sending_in_progress;
    logic receiving_in_progress;
    logic start_ack_receving;

    // PJON Control Registers
    logic [7:0] pjon_address_d, pjon_address_q;
    logic pjon_router_mode_d, pjon_router_mode_q;

    // Signals used to create the response
    logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
    logic rsp_err; // Error field of the obi response

    axis_req_t axis_pjdl_send_req;
    axis_rsp_t axis_pjdl_send_rsp;
    axis_req_t axis_pjon_send_req;
    axis_rsp_t axis_pjon_send_rsp;
    axis_rsp_t axis_pjdl_receive_rsp;
    axis_req_t axis_pjdl_receive_req;
    axis_rsp_t axis_pjon_receive_rsp;
    axis_req_t axis_pjon_receive_req;

    logic [19:0] pjdl_spec_preamble_q, pjdl_spec_preamble_d;
    logic [13:0] pjdl_spec_pad_q, pjdl_spec_pad_d;
    logic [11:0] pjdl_spec_data_q, pjdl_spec_data_d;
    logic [11:0] pjdl_spec_acceptance_q, pjdl_spec_acceptance_d;

    logic pjdl_activate_module_q, pjdl_activate_module_d;

    logic dma_busy;
    logic pjon_i_synchronized;

    logic activate_dma_receiving_d, activate_dma_receiving_q;

    //OBI assignemts
    assign req_d = obi_req_i.req;
    assign id_d = obi_req_i.a.aid;
    assign we_d = obi_req_i.a.we;
    assign addr_d = obi_req_i.a.addr;
    assign wdata_d = obi_req_i.a.wdata;

    // Always-ff statements
    `FF(req_q, req_d, '0);
    `FF(id_q , id_d , '0);
    `FF(we_q , we_d , '0);
    `FF(wdata_q , wdata_d , '0);
    `FF(addr_q , addr_d , '0);
    `FF(pjdl_spec_preamble_q , pjdl_spec_preamble_d , '0);
    `FF(pjdl_spec_pad_q , pjdl_spec_pad_d , '0);
    `FF(pjdl_spec_data_q , pjdl_spec_data_d , '0);
    `FF(pjdl_spec_acceptance_q , pjdl_spec_acceptance_d , '0);
    `FF(pjdl_activate_module_q , pjdl_activate_module_d , '0);
    `FF(axi_stream_send_data_q , axi_stream_send_data_d , '0);
    `FF(axi_direct_send_valid_q , axi_direct_send_valid_d , '0);
    `FF(axi_direct_send_ready_q , axi_direct_send_ready_d , '0);
    `FF(axi_stream_receive_data_q , axi_stream_receive_data_d , '0);
    `FF(axi_direct_receive_valid_q , axi_direct_receive_valid_d , '0);
    `FF(axi_direct_read_data_available_q , axi_direct_read_data_available_d , 1'b0);
    `FF(activate_dma_receiving_q , activate_dma_receiving_d , 1'b0);
    `FF(pjon_router_mode_q , pjon_router_mode_d, 1'b0);
    `FF(pjon_address_q , pjon_address_d, 1'b0);
    `FF(dma_receiving_process_happend_q , dma_receiving_process_happend_d , 1'b0);


    // Switch between direct axi access and dma access
    always_comb begin // ToDo: check axis protocol specifications in the following part
        axis_dma_read_req = '0; // set unused signals to zero
        axis_pjon_send_req = '0; // set unused signals to zero

        if(dma_busy || axis_dma_write_req.tvalid) begin // dma active // ToDo: check if dma is not busy because of memcpy
            // sending
            axis_pjon_send_req.tvalid = axis_dma_write_req.tvalid;
            axis_pjon_send_req.t.data = axis_dma_write_req.t.data;
            axis_pjon_send_req.t.last = axis_dma_write_req.t.last;
            axis_pjon_send_req.t.user = 2'b0;
            axis_pjon_send_req.t.keep = axis_dma_write_req.t.keep;
            axis_pjon_send_req.t.strb = axis_dma_write_req.t.strb;
            axis_dma_write_rsp.tready = axis_pjon_send_rsp.tready;

            // direct sending
            axi_direct_send_ready_d = 1'b0;

        end else begin // direct sending active
            // sending
            axis_pjon_send_req.tvalid = axi_direct_send_valid_q;
            axis_pjon_send_req.t.data = axi_stream_send_data_q[7:0];
            axis_pjon_send_req.t.last = axi_stream_send_data_q[8];
            axis_pjon_send_req.t.user = axi_stream_send_data_q[10:9];
            axis_pjon_send_req.t.keep = 1'b1;
            axis_pjon_send_req.t.strb = 1'b1;
            axi_direct_send_ready_d = axis_pjon_send_rsp.tready;

            // dma sending
            axis_dma_write_rsp.tready = 1'b0;
        end

        if(activate_dma_receiving_q) begin
            // receiving dma
            axis_dma_read_req.tvalid = axis_pjon_receive_req.tvalid;
            axis_dma_read_req.t.data = axis_pjon_receive_req.t.data;
            axis_dma_read_req.t.last = axis_pjon_receive_req.t.last;
            axis_dma_read_req.t.user = axis_pjon_receive_req.t.user;
            axis_dma_read_req.t.keep = axis_pjon_receive_req.t.keep;
            axis_dma_read_req.t.strb = axis_pjon_receive_req.t.strb;
            axis_pjon_receive_rsp.tready = axis_dma_read_rsp.tready;

            // receiving direct
            axi_direct_receive_valid_d = axis_pjon_receive_req.tvalid;

        end else begin
            // receiving direct
            axi_direct_receive_valid_d = axis_pjon_receive_req.tvalid;
            axis_pjon_receive_rsp.tready = !axi_direct_read_data_available_q; 
            // ToDo: negatve value has to be assigned diffrently!

            // receiving dma
            axis_dma_read_req.tvalid = 1'b0;
            axis_dma_read_req.t.data = '0;
            axis_dma_read_req.t.last = 1'b0;
            axis_dma_read_req.t.user = '0;
            axis_dma_read_req.t.keep = '0;
            axis_dma_read_req.t.strb = '0;
        end
    end

    logic [3:0] word_addr;
    always_comb begin
        rsp_data = '0;
        rsp_err  = '0;
        word_addr = addr_q[5:2];

        pjdl_spec_preamble_d = pjdl_spec_preamble_q;
        pjdl_spec_pad_d = pjdl_spec_pad_q;
        pjdl_spec_data_d = pjdl_spec_data_q;
        pjdl_spec_acceptance_d = pjdl_spec_acceptance_q;
        pjdl_activate_module_d = pjdl_activate_module_q;
        axi_stream_send_data_d = axi_stream_send_data_q;
        axi_stream_receive_data_d = axi_stream_receive_data_q;
        activate_dma_receiving_d = activate_dma_receiving_q;
        axi_direct_send_valid_d = axi_direct_send_valid_q;
        axi_direct_read_data_available_d = axi_direct_read_data_available_q;
        pjon_address_d = pjon_address_q;
        pjon_router_mode_d = pjon_router_mode_q;
        dma_receiving_process_happend_d = dma_receiving_process_happend_q;

        if(axi_direct_send_ready_q&&axi_direct_send_valid_q) begin
            axi_direct_send_valid_d = 1'b0;
        end

        if(axis_pjon_receive_rsp.tready&&axis_pjon_receive_req.tvalid) begin
            axi_stream_receive_data_d[7:0] = axis_pjon_receive_req.t.data;
            axi_stream_receive_data_d[8] = axis_pjon_receive_req.t.last;
        end

        if(activate_dma_receiving_q) begin
            axi_direct_read_data_available_d = 1'b0;
        end else if(!axi_direct_read_data_available_q&&axi_direct_receive_valid_q) begin
            axi_direct_read_data_available_d = 1'b1;
        end

        if(axis_dma_read_req.tvalid && axis_dma_read_rsp.tready && activate_dma_receiving_q) begin
            dma_receiving_process_happend_d = 1'b1; // indicator that the dma has received data
        end

        if(req_q) begin
            if(we_q) begin
                case(word_addr)
                    4'h0: begin
                        activate_dma_receiving_d = wdata_q[0];
                    end
                    4'h1: begin
                        pjdl_spec_preamble_d = wdata_q[19:0];
                    end
                    4'h2: begin
                        pjdl_spec_pad_d = wdata_q[13:0];
                    end
                    4'h3: begin
                        pjdl_spec_data_d = wdata_q[11:0];
                    end
                    4'h4: begin
                        pjdl_spec_acceptance_d = wdata_q[11:0];
                    end
                    4'h5: begin
                        pjdl_activate_module_d = wdata_q[0];
                    end
                    4'h6: begin // Address to read and write directly to and from the AXI stream interface
                        axi_stream_send_data_d = wdata_q[10:0];
                        axi_direct_send_valid_d = 1'b1;
                    end
                    4'h8: begin
                        pjon_address_d = wdata_q[7:0];
                    end
                    4'h9: begin
                        pjon_router_mode_d = wdata_q[0];
                    end
                    4'hA: begin // writing here just resets the indicator
                        dma_receiving_process_happend_d = 1'b0; // reset the indicator
                    end
                    default: rsp_err = 1'b1;
                endcase
            end else begin
                case(word_addr)
                    4'h0: begin
                        rsp_data = {31'h0, activate_dma_receiving_q};
                    end
                    4'h1: begin
                        rsp_data = {12'h0, pjdl_spec_preamble_q};
                    end
                    4'h2: begin
                        rsp_data = {18'h0, pjdl_spec_pad_q};
                    end
                    4'h3: begin
                        rsp_data = {20'h0, pjdl_spec_data_q};
                    end
                    4'h4: begin
                        rsp_data = {20'h0, pjdl_spec_acceptance_q};
                    end
                    4'h5: begin
                        rsp_data = {31'h0, pjdl_activate_module_q};
                    end
                    4'h6: begin // Address to read and write directly to the AXI stream interface
                        rsp_data = {23'h0, axi_stream_receive_data_q};
                        axi_direct_read_data_available_d = 1'b0;
                    end
                    4'h7: begin // bit3: receiving in progress, bit2: sending in prog., bit 1: data to be read from axi-stream?, bit 0: all axi-stream data sent?
                        rsp_data = {28'h0, receiving_in_progress, sending_in_progress, axi_direct_read_data_available_q, !axi_direct_send_valid_q};
                    end
                    4'h8: begin
                        rsp_data = {24'h0, pjon_address_q};
                    end
                    4'h9: begin
                        rsp_data = {31'h0, pjon_router_mode_q};
                    end
                    4'hA: begin // indicates if the dma has received data since the last check
                        rsp_data = {31'h0, dma_receiving_process_happend_q};
                        dma_receiving_process_happend_d = 1'b0; // reset the indicator
                    end
                    default: rsp_data = 32'hffffffff;
                endcase
            end
        end
    end
    
    // Wire the response
    // A channel
    assign obi_rsp_o.gnt = obi_req_i.req;
    // R channel:
    assign obi_rsp_o.rvalid = req_q;
    assign obi_rsp_o.r.rdata = rsp_data;
    assign obi_rsp_o.r.rid = id_q;
    assign obi_rsp_o.r.err = rsp_err;
    assign obi_rsp_o.r.r_optional = '0;

    pjdl_idma_wrap #(
        .ObiCfg      ( ObiCfg     ),
        .MgrObiCfg   ( MgrObiCfg  ),
        .AxisDataWidth ( AxisDataWidth ),
        .obi_req_t   ( obi_req_t  ),
        .obi_rsp_t   ( obi_rsp_t  ),
        .obi_mgr_req_t   ( obi_mgr_req_t ),
        .obi_mgr_rsp_t   ( obi_mgr_rsp_t ),
        .axis_req_t  ( axis_req_t ),
        .axis_rsp_t  ( axis_rsp_t )
    ) i_pjdl_idma (
        .clk_i                    ( clk_i                    ),
        .rst_ni                   ( rst_ni                   ),
        .testmode_i               ( 1'b0                     ),

        // AXI-Stream interfaces (to pjdl-module)
        .axis_write_rsp_i         ( axis_dma_write_rsp       ),
        .axis_write_req_o         ( axis_dma_write_req       ),
        .axis_read_req_i          ( axis_dma_read_req        ),
        .axis_read_rsp_o          ( axis_dma_read_rsp        ),


        // DMA-OBI configuration interface
        .dma_obi_req_i             ( obi_dma_req_i           ),
        .dma_obi_rsp_o             ( obi_dma_rsp_o           ),

        // OBI manager interfaces
        .obi_mgr_idma_write_req_o ( obi_mgr_idma_write_req_o ),
        .obi_mgr_idma_write_rsp_i ( obi_mgr_idma_write_rsp_i ),
        .obi_mgr_idma_read_req_o ( obi_mgr_idma_read_req_o   ),
        .obi_mgr_idma_read_rsp_i ( obi_mgr_idma_read_rsp_i   ),

        // status
        .dma_busy_o              (dma_busy)
    );

    pjon_addressing #(
        .BufferSize(1),

        .axis_req_t(axis_req_t),
        .axis_rsp_t(axis_rsp_t)
    ) i_pjon_addressing(
        .clk_i                    ( clk_i                   ),
        .rst_ni                   ( rst_ni                  ),

        // send-axi-connection to wrapper
        .axis_read_req_i          ( axis_pjon_send_req      ),
        .axis_read_rsp_o          ( axis_pjon_send_rsp      ),

        // send-axi-connection from layer 2 module
        .axis_read_req_o          ( axis_pjdl_send_req ),
        .axis_read_rsp_i          ( axis_pjdl_send_rsp ),

        // receive-axi-connection from layer 2 module
        .axis_write_rsp_o         ( axis_pjdl_receive_rsp ),
        .axis_write_req_i         ( axis_pjdl_receive_req ),

        // receive-axi-connection to wrapper
        .axis_write_rsp_i         ( axis_pjon_receive_rsp   ),
        .axis_write_req_o         ( axis_pjon_receive_req   ),

        .start_ack_receiving_i    ( start_ack_receving   ), // when ack_receiving is active, address checking isn't needed

        // PJON Settings
        .pjon_device_id_i         ( pjon_address_q ), // PJON Address
        .router_mode_i            ( pjon_router_mode_q )
    );

    pjdl #(
        .axis_req_t ( axis_req_t ),
        .axis_rsp_t ( axis_rsp_t )
    ) i_pjdl (
        .clk_i                    ( clk_i                                 ),
        .rst_ni                   ( rst_ni && pjdl_activate_module_q      ),

        // sending (Axi-stream interface)
        .axis_read_req_i          ( axis_pjdl_send_req ),
        .axis_read_rsp_o          ( axis_pjdl_send_rsp ),

        // receiving (Axi-stream interface)
        .axis_write_rsp_i         ( axis_pjdl_receive_rsp ),
        .axis_write_req_o         ( axis_pjdl_receive_req ),

        .sending_in_progress_o    ( sending_in_progress ),
        .receiving_in_progress_o  ( receiving_in_progress ),
        .start_ack_receiving_o    ( start_ack_receving ),

        // HW interface
        .pjon_i                   ( pjon_i_synchronized  ),
        .pjon_o                   ( pjon_o      ),
        .pjon_en_o                ( pjon_en_o   ),

        // PJDL specification (mode dependent)
        .pjdl_spec_preamble_i     ( pjdl_spec_preamble_q     ),
        .pjdl_spec_pad_i          ( pjdl_spec_pad_q          ),
        .pjdl_spec_data_i         ( pjdl_spec_data_q         ),
        .pjdl_spec_acceptance_i   ( pjdl_spec_acceptance_q   )
    );

    sync #(
        .STAGES(3),
        .ResetValue(1'b0)
    ) i_sync (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .serial_i(pjon_i),
        .serial_o(pjon_i_synchronized)
    );

endmodule
