// --------------------------------------------------
// Document:  pjdl_idma_wrap.sv
// Project:   PJON_ASIC/croc_pjon_hw
// Function:  wrap to use idma in the pjdl wrap
// Autor:     Pius Sieber
// Date:      25.04.2025
// Comments:  -
// --------------------------------------------------
module pjdl_idma_wrap #(
    // The OBI configuration for all ports.
    parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
    parameter obi_pkg::obi_cfg_t           MgrObiCfg   = obi_pkg::ObiDefaultConfig,
    // Settings
    parameter int unsigned                 AxisDataWidth = 8,
    // The request struct.
    parameter type                         obi_req_t   = logic,
    parameter type                         obi_mgr_req_t  = logic,
    // The response struct.
    parameter type                         obi_rsp_t   = logic,
    parameter type                         obi_mgr_rsp_t  = logic,
    // AXIs Bus
    parameter type                         axis_req_t = logic,
    parameter type                         axis_rsp_t = logic
)(
    input  logic          clk_i,
    input  logic          rst_ni,
    input  logic          testmode_i,

    // AXI-Stream interfaces (to pjdl-module)
    input axis_rsp_t axis_write_rsp_i,
    output axis_req_t axis_write_req_o,
    input axis_req_t axis_read_req_i,
    output axis_rsp_t axis_read_rsp_o,

    // OBI interface (to croc) for DMA
    input obi_req_t dma_obi_req_i,
    output obi_rsp_t dma_obi_rsp_o,

    // obi manager interfaces
    output obi_mgr_req_t obi_mgr_idma_write_req_o,
    input obi_mgr_rsp_t obi_mgr_idma_write_rsp_i,
    output obi_mgr_req_t obi_mgr_idma_read_req_o,
    input obi_mgr_rsp_t obi_mgr_idma_read_rsp_i,

    // dma status
    output dma_busy_o
);
    `include "idma/typedef.svh"
    `include "axi_stream/typedef.svh"
    `include "register_interface/typedef.svh"
    `include "common_cells/registers.svh"
    `include "obi/typedef.svh"

    // iDMA parameters
    localparam int unsigned TfLenWidth          = 32;
    localparam int unsigned ObiAddrWidth        = MgrObiCfg.AddrWidth;
    localparam int unsigned ObiDataWidth        = MgrObiCfg.DataWidth;
    localparam int unsigned IdWidth             = 1;
    localparam int unsigned NumAxInFlight       = 3;
    localparam int unsigned MemSysDepth         = 0;
    localparam bit          RAWCouplingAvail    = 0;
    localparam int unsigned ObiUserWidth        = 1; // do not use user bits in other modules 
                                                     // (axis user bits for pjdl are set in this module)
    localparam int unsigned DestWidth           = 1; // do not use axis dest bits

    typedef logic [ObiDataWidth-1:0]      obi_data_t;
    typedef logic [ObiDataWidth-1:0]      axis_large_data_t;
    typedef logic [ObiDataWidth/8-1:0]    obi_strb_t;
    typedef logic [ObiDataWidth/8-1:0]    axis_large_strb_t;
    typedef logic [ObiAddrWidth-1:0]      obi_addr_t;
    typedef logic [IdWidth-1:0]           id_t;
    typedef logic [TfLenWidth-1:0]        tf_len_t;
    typedef logic [ObiUserWidth-1:0]      user_t;
    typedef logic [ObiAddrWidth-1:0]      obi_addr_len_t;
     

    // iDMA request / response types
    `IDMA_TYPEDEF_FULL_REQ_T(idma_req_t, obi_addr_len_t, obi_addr_t, tf_len_t)
    `IDMA_TYPEDEF_FULL_RSP_T(idma_rsp_t, obi_addr_t)

    // AXI Stream typedefs
    `AXI_STREAM_TYPEDEF_S_CHAN_T(axis_large_t_chan_t, axis_large_data_t, axis_large_strb_t, 
                                 axis_large_strb_t, id_t, id_t, user_t)

    `AXI_STREAM_TYPEDEF_REQ_T(axis_large_req_t, axis_large_t_chan_t)

    // OBI typedefs
    `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(a_optional_t)
    `OBI_TYPEDEF_MINIMAL_R_OPTIONAL(r_optional_t)
    
    `OBI_TYPEDEF_TYPE_A_CHAN_T(obi_a_chan_t, obi_addr_t, obi_data_t, obi_strb_t, id_t, a_optional_t)
    `OBI_TYPEDEF_TYPE_R_CHAN_T(obi_r_chan_t, obi_data_t, id_t, r_optional_t)
    
    `OBI_TYPEDEF_REQ_T(obi_backend_req_t, obi_a_chan_t)
    `OBI_TYPEDEF_RSP_T(obi_backend_rsp_t, obi_r_chan_t)

    localparam int unsigned axis_t_chan_width = $bits(axis_large_t_chan_t);
    localparam int unsigned obi_a_chan_width = MgrObiCfg.OptionalCfg.AChkWidth;

    function int unsigned max_width(input int unsigned a, b);
        return (a > b) ? a : b;
    endfunction

    typedef struct packed {
        obi_a_chan_t a_chan;
    } obi_read_meta_channel_t;

    typedef struct packed {
        axis_large_t_chan_t t_chan;
        logic[26:0] padding;
        //logic[max_width(obi_a_chan_width, axis_t_chan_width)-axis_t_chan_width:0] padding;
    } axis_read_t_channel_padded_t;

    typedef union packed {
        obi_read_meta_channel_t obi;
        axis_read_t_channel_padded_t axis;
    } read_meta_channel_t;

    typedef struct packed {
        obi_a_chan_t a_chan;
    } obi_write_meta_channel_t;

    typedef struct packed {
        axis_large_t_chan_t t_chan;
        //logic[max_width(obi_a_chan_width, axis_t_chan_width)-axis_t_chan_width:0] padding;
        logic[26:0] padding;
    } axis_write_t_channel_padded_t;

    typedef union packed {
        obi_write_meta_channel_t obi;
        axis_write_t_channel_padded_t axis;
    } write_meta_channel_t;

    obi_backend_rsp_t obi_backend_write_rsp;
    obi_backend_req_t obi_backend_write_req;
    obi_backend_rsp_t obi_backend_read_rsp;
    obi_backend_req_t obi_backend_read_req;

    // DMA frontend signals
    idma_req_t frontend_idma_req;
    logic frontend_idma_req_valid;
    logic frontend_idma_req_ready;
    logic frontend_idma_rsp_valid;
    logic frontend_idma_rsp_ready;

    // DMA backend signals
    idma_req_t backend_idma_req;
    logic backend_idma_req_valid;
    logic backend_idma_req_ready;
    logic backend_idma_rsp_valid;
    logic backend_idma_rsp_ready;

    // Status signals
    idma_pkg::idma_busy_t busy;

    axis_rsp_t axis_large_read_rsp;
    axis_large_req_t axis_large_read_req;
    axis_rsp_t axis_large_write_rsp;
    axis_large_req_t axis_large_write_req;

    axis_rsp_t axis_read_rsp;
    axis_req_t axis_read_req;
    axis_rsp_t axis_write_rsp;
    axis_req_t axis_write_req;

    // axi-stream assignments (dma->pjdl) (ToDo: convert interface in pjdl-mudle to typedefs as well)
    always_comb begin
        axis_write_req_o = '0; // set all unused fields to zero

        axis_write_req_o.t.data = axis_write_req.t.data[7:0];
        axis_write_req_o.t.user[1:0] = 2'b0; // user-bits not settable over idma
        axis_write_req_o.t.last = axis_write_req.t.last;
        axis_write_req_o.tvalid = axis_write_req.tvalid;
        axis_write_req_o.t.strb = 1'b1;
        axis_write_req_o.t.keep = axis_write_req.t.keep;
        axis_write_rsp.tready = axis_write_rsp_i.tready;
    end

    // axi-stream assignments (pjdl->dma)
    always_comb begin
        axis_read_req = '0; // set all unused fields to zero

        axis_read_req.t.data[7:0] = axis_read_req_i.t.data;
        axis_read_req.t.last = axis_read_req_i.t.last;
        axis_read_req.tvalid = axis_read_req_i.tvalid;
        axis_read_req.t.keep = axis_read_req_i.t.keep;
        axis_read_req.t.user[ObiUserWidth-1:0] = '0; // user bits not used in this direction
        axis_read_rsp_o.tready = axis_read_rsp.tready;
    end

    // ******** iDMA frontend **************

    idma_obi_1d_frontend #(
        .ObiCfg      ( ObiCfg ),
        .obi_req_t   ( obi_req_t ),
        .obi_rsp_t   ( obi_rsp_t ),

        .idma_req_t  ( idma_req_t               ),
        .idma_rsp_t  ( idma_rsp_t               ),
        .idma_busy_t ( idma_pkg::idma_busy_t    )
    ) i_dma_frontend_1d (
        .clk_i            ( clk_i ),
        .rst_ni           ( rst_ni ),

        // OBI interface
        .dma_obi_ctrl_req_i   ( dma_obi_req_i),
        .dma_obi_ctrl_rsp_o   ( dma_obi_rsp_o),

        // Connection to the midend
        .dma_req_o        ( frontend_idma_req ),
        .req_valid_o      ( frontend_idma_req_valid ),
        .req_ready_i      ( frontend_idma_req_ready ),
        .rsp_valid_i      ( frontend_idma_rsp_valid ),
        .rsp_ready_o      ( frontend_idma_rsp_ready ),
        .busy_status_i    ( busy           ),
        .busy_o           ( dma_busy_o     )
    );

    // ************ iDMA midend **************

    pjdl_idma_midend #(
        .axis_address        ( 32'h2000_1018 ),

        .idma_req_t          ( idma_req_t  ),
        .idma_rsp_t          ( idma_rsp_t  ),

        .axis_large_req_t    ( axis_large_req_t ),
        .axis_large_rsp_t    ( axis_rsp_t )
    )i_pjdl_idma_midend (
        .clk_i,
        .rst_ni,
        
        // Connections to the frontend
        .frontend_idma_req_i            ( frontend_idma_req ),
        .frontend_idma_req_valid_i      ( frontend_idma_req_valid ),
        .frontend_idma_req_ready_o      ( frontend_idma_req_ready ),
        .frontend_idma_rsp_valid_o      ( frontend_idma_rsp_valid ),
        .frontend_idma_rsp_ready_i      ( frontend_idma_rsp_ready ),

        // Connections to the backend
        .backend_idma_req_o            ( backend_idma_req ),
        .backend_idma_req_valid_o      ( backend_idma_req_valid  ),
        .backend_idma_req_ready_i      ( backend_idma_req_ready  ),
        .backend_idma_rsp_valid_i      ( backend_idma_rsp_valid ),
        .backend_idma_rsp_ready_o      ( backend_idma_rsp_ready ),

        // axis interface
        .axis_large_req_i          ( axis_large_read_req ),
        .axis_large_rsp_i          ( axis_large_read_rsp )
    );

    // ************ iDMA backend **************

    idma_backend_rw_axis_rw_obi #(
        .CombinedShifter        ( 1'b0 ),
        .DataWidth              ( ObiDataWidth ),
        .AddrWidth              ( ObiAddrWidth ),
        .AxiIdWidth             ( IdWidth   ),
        .UserWidth              ( ObiUserWidth ),
        .TFLenWidth             ( TfLenWidth ),
        .MaskInvalidData        ( 1 ),
        .BufferDepth            ( 3 ),
        .RAWCouplingAvail       ( RAWCouplingAvail),
        .HardwareLegalizer      ( 1 ),
        .RejectZeroTransfers    ( 1 ),
        .ErrorCap               ( idma_pkg::NO_ERROR_HANDLING ),
        .PrintFifoInfo          ( 0 ),
        .NumAxInFlight          ( NumAxInFlight ),
        .MemSysDepth            ( MemSysDepth ),
        .idma_req_t             ( idma_req_t  ),
        .idma_rsp_t             ( idma_rsp_t  ),
        .idma_eh_req_t          ( idma_pkg::idma_eh_req_t ),
        .idma_busy_t            ( idma_pkg::idma_busy_t   ),

        .obi_req_t              ( obi_backend_req_t ),
        .obi_rsp_t              ( obi_backend_rsp_t ),

        .axis_req_t             ( axis_large_req_t ),
        .axis_rsp_t             ( axis_rsp_t ),

        .write_meta_channel_t   ( write_meta_channel_t ),
        .read_meta_channel_t    ( read_meta_channel_t  )
    ) i_idma_backend  (
        .clk_i,
        .rst_ni,
        .testmode_i,
        .idma_req_i       ( backend_idma_req ),
        .req_valid_i      ( backend_idma_req_valid  ),
        .req_ready_o      ( backend_idma_req_ready  ),
        .idma_rsp_o       (                         ),
        .rsp_valid_o      ( backend_idma_rsp_valid ),
        .rsp_ready_i      ( backend_idma_rsp_ready ),
        .idma_eh_req_i    ( '0 ),
        .eh_req_valid_i   ( '0 ),
        .eh_req_ready_o   (    ),

        .obi_read_req_o   ( obi_backend_read_req ),
        .obi_read_rsp_i   ( obi_backend_read_rsp ),

        .obi_write_req_o  ( obi_backend_write_req ),
        .obi_write_rsp_i  ( obi_backend_write_rsp ),

        .axis_read_req_i  ( axis_large_read_req ),
        .axis_read_rsp_o  ( axis_large_read_rsp ),

        .axis_write_req_o ( axis_large_write_req ),
        .axis_write_rsp_i ( axis_large_write_rsp ),

        .busy_o           ( busy )
    );

    // **************************************

    obi_interface_adapter #(
        .obi_req_t      ( obi_backend_req_t ),
        .obi_rsp_t      ( obi_backend_rsp_t ),
        .mgr_obi_req_t  ( obi_mgr_req_t ),
        .mgr_obi_rsp_t  ( obi_mgr_rsp_t )
    ) idma2croc_read (
        .req_i          ( obi_backend_read_req ),
        .rsp_o          ( obi_backend_read_rsp ),
        .req_o          ( obi_mgr_idma_read_req_o ),
        .rsp_i          ( obi_mgr_idma_read_rsp_i )
    );

    obi_interface_adapter #(
        .obi_req_t      ( obi_backend_req_t ),
        .obi_rsp_t      ( obi_backend_rsp_t ),
        .mgr_obi_req_t  ( obi_mgr_req_t ),
        .mgr_obi_rsp_t  ( obi_mgr_rsp_t )
    ) idma2croc_write (
        .req_i          ( obi_backend_write_req ),
        .rsp_o          ( obi_backend_write_rsp ),
        .req_o          ( obi_mgr_idma_write_req_o ),
        .rsp_i          ( obi_mgr_idma_write_rsp_i )
    );

    axi_stream_dw_downsizer #(
        .DataWidthIn         (ObiAddrWidth),
        .DataWidthOut        (AxisDataWidth),
        .IdWidth             (IdWidth),
        .DestWidth           (DestWidth),
        .UserWidth           (ObiUserWidth),
        .axi_stream_in_req_t(axis_large_req_t),
        .axi_stream_in_rsp_t(axis_rsp_t),
        .axi_stream_out_req_t(axis_req_t),
        .axi_stream_out_rsp_t(axis_rsp_t)
    ) i_axi_stream_dw_downsizer (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .in_req_i (axis_large_write_req),
        .in_rsp_o (axis_large_write_rsp),
        .out_req_o(axis_write_req),
        .out_rsp_i(axis_write_rsp)
    );

    axi_stream_dw_upsizer #(
        .DataWidthIn         (AxisDataWidth),
        .DataWidthOut        (ObiAddrWidth),
        .IdWidth             (IdWidth),
        .DestWidth           (DestWidth),
        .UserWidth           (ObiUserWidth), // ToDo: User bits could probably deleted in some places
        .axi_stream_in_req_t(axis_req_t),
        .axi_stream_in_rsp_t(axis_rsp_t),
        .axi_stream_out_req_t(axis_large_req_t),
        .axi_stream_out_rsp_t(axis_rsp_t)
    ) i_axi_stream_dw_upsizer (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .in_req_i (axis_read_req),
        .in_rsp_o (axis_read_rsp),
        .out_req_o(axis_large_read_req),
        .out_rsp_i(axis_large_read_rsp)
    );
endmodule