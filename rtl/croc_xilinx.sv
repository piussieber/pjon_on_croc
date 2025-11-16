module croc_xilinx #(
  localparam int unsigned GpioCount = 3
) (
  input  logic                 sys_clk,
  input  logic                 sys_reset,
  input  logic                 fetch_en_i,
  input  logic [GpioCount-1:0] gpio_i,
  output logic [GpioCount-1:0] gpio_o,
  output logic                 status_o,
  input  logic                 jtag_tck_i,
  input  logic                 jtag_tms_i,
  input  logic                 jtag_tdi_i,
  output logic                 jtag_tdo_o,
  // input  logic                 jtag_trst_ni,
  output logic                 uart_tx_o,
  input  logic                 uart_rx_i,

  //input logic                  pjon_in,
  //output logic                 pjon_out,
  inout wire                 pjon_io
);

  //////////////////////////////////
  //  Clock and reset generation  //
  //////////////////////////////////

  wire soc_clk;
  logic pjon_in, pjon_out, pjon_out_en;

  clk_wiz_0 i_clkwiz (
    .clk_in1  ( sys_clk ),
    .reset    ( '0      ),
    .locked   (         ),
    .clk_out1 ( soc_clk )
  );

  wire rst_n;

  rstgen i_rstgen (
    .clk_i       ( soc_clk     ),
    .rst_ni      ( ~sys_reset  ),
    .test_mode_i ( '0          ),
    .rst_no      ( rst_n       ),
    .init_no     (             )
  );

  /////////////////////////
  // "RTC" Clock Divider //
  /////////////////////////

  logic        rtc_clk_d;
  logic        rtc_clk_q;
  logic [15:0] counter_d; 
  logic [15:0] counter_q;

  // Divide soc_clk (20 MHz) by 610 => ~32.768kHz RTC Clock
  always_comb begin
    counter_d = counter_q + 1;
    rtc_clk_d = rtc_clk_q;
    if(counter_q == ((610 / 2) - 1)) begin
      counter_d = '0;
      rtc_clk_d = ~rtc_clk_q;
    end
  end

  always_ff @(posedge soc_clk, negedge rst_n) begin
    if(~rst_n) begin
      counter_q <= '0;
      rtc_clk_q <= 0;
    end else begin
      counter_q <= counter_d;
      rtc_clk_q <= rtc_clk_d;
    end
  end

  /////////////
  //  GPIOs  //
  /////////////

  logic [GpioCount-1:0] gpio_in;
  logic [GpioCount-1:0] gpio_out;
  logic [GpioCount-1:0] gpio_out_en;

  for(genvar i = 0; i < GpioCount; i++) begin
    assign gpio_o[i]  =  gpio_out_en[i] ? gpio_out[i] : '0;
    assign gpio_in[i] = ~gpio_out_en[i] ? gpio_i[i]   : '0;
  end

  assign gpio_o[0]            =  1'b0;
  //assign gpio_o[1]            =  1'b0;
  assign gpio_in[1]           =  1'b0;
  //assign gpio_in[0]           = pjon_in;
  //assign pjon_out             = gpio_out[1];

  IOBUF #(
    .DRIVE        ( 12        ),
    .IBUF_LOW_PWR ( "FALSE"   ),
    .IOSTANDARD   ( "DEFAULT" ),
    .SLEW         ( "FAST"    )
  ) i_scl_iobuf (
    .O  ( pjon_in     ),
    .IO ( pjon_io      ),
    .I  ( pjon_out      ),
    .T  ( ~pjon_out_en )
  );


  //////////////
  // Croc SoC //
  //////////////

  croc_soc #(
    .GpioCount( GpioCount )
  )
  i_croc_soc (
    .clk_i           ( soc_clk      ),
    .rst_ni          ( rst_n        ),
    .ref_clk_i       ( rtc_clk_q    ),
    .testmode_i      ( '0           ),
    .fetch_en_i      ( fetch_en_i   ),
    .status_o        ( status_o     ),
    .jtag_tck_i      ( jtag_tck_i   ),
    .jtag_tdi_i      ( jtag_tdi_i   ),
    .jtag_tdo_o      ( jtag_tdo_o   ),
    .jtag_tms_i      ( jtag_tms_i   ),
    .jtag_trst_ni    ( '1           ),
    .uart_rx_i       ( uart_rx_i    ),
    .uart_tx_o       ( uart_tx_o    ),
    .gpio_i          ( gpio_in      ),
    .gpio_o          ( gpio_out     ),
    .gpio_out_en_o   ( gpio_out_en  ),

    .pjon_hw_o       ( pjon_out ),
    .pjon_hw_i       ( pjon_in  ),
    .pjon_hw_en_o    ( pjon_out_en  )
);

endmodule
