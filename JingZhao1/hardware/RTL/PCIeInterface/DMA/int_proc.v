`timescale 1ns / 100ps
//*************************************************************************
// > File Name: int_proc.v
// > Author   : Kangning
// > Date     : 2021-09-17
// > Note     : Process interrupt request
//*************************************************************************

module int_proc #(

) (
    input  wire                        pcie_clk  ,
    input  wire                        pcie_rst_n,
    input  wire                        dma_clk   ,
    input  wire                        rst_n     ,

    input wire                         int_req_valid,
    input wire [31:0]                  int_req_data ,
    input wire [63:0]                  int_req_addr ,
    output wire                        int_req_ready,

    /* -------Interrupt Interface Signals{begin}------- */
    input                  [1:0]     cfg_interrupt_msix_enable        ,
    input                  [1:0]     cfg_interrupt_msix_mask          ,
    output                [31:0]     cfg_interrupt_msix_data          ,
    output                [63:0]     cfg_interrupt_msix_address       ,
    output                           cfg_interrupt_msix_int           ,
    input                            cfg_interrupt_msix_sent          ,
    input                            cfg_interrupt_msix_fail          ,
    output wire            [2:0]     cfg_interrupt_msi_function_number 
    /* -------Interrupt Interface Signals{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,output wire [`INT_PROC_SIGNAL_W-1:0] dbg_signal  // o, `INT_PROC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/*-------Interrupt related logic{begin}------- */
wire int_req_full;

wire [31:0] int_out_data ;
wire [63:0] int_out_addr ;
wire        int_out_empty;
/*-------Interrupt related logic{end}------- */

/* -------State relevant in FSM{begin}------- */
localparam  WAIT_SEND     = 2'b01, // idle, or send the interrupt
            WAIT_RESP     = 2'b10; // Wait for the rsp of interrupt
reg [1:0] cur_state;
reg [1:0] nxt_state;
wire is_wait_send, is_wait_resp;
wire j_wait_send, j_wait_resp;

reg msix_enable;
/* -------State relevant in FSM{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  rtsel;
wire  [1:0]  wtsel;
wire  [1:0]  ptsel;
wire         vg   ;
wire         vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rtsel, wtsel, ptsel, vg, vs} = rw_data;
assign dbg_signal = { // 107
    int_req_full, // 1
    int_out_data, int_out_addr, int_out_empty, // 97
    cur_state, nxt_state, // 4
    is_wait_send, is_wait_resp, // 2
    j_wait_send, j_wait_resp, // 2
    msix_enable // 1
};
/* -------APB reated signal{end}------- */
`endif

/*-------Interrupt related logic{begin}------- */
assign int_req_ready = ~int_req_full;

pcieifc_async_fifo #(
    .DATA_WIDTH   ( (64 + 32) ),
    .ADDR_WIDTH   (  4        )
) async_fifo_int (
    .wr_clk ( dma_clk    ), // i, 1
    .rd_clk ( pcie_clk   ), // i, 1
    .wrst_n ( rst_n      ), // i, 1
    .rrst_n ( pcie_rst_n ), // i, 1

    .wen  ( int_req_valid & int_req_ready), // i, 1
    .din  ( {int_req_addr, int_req_data} ), // i, (64 + 32)
    .full (  int_req_full                ), // o, 1

    .ren   ( j_wait_send & cfg_interrupt_msix_sent & (!int_out_empty) ), // i, 1
    .dout  ( {int_out_addr, int_out_data} ), // o, (64 + 32)
    .empty ( int_out_empty                )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);

/*-------Interrupt related logic{end}------- */

/* -------{DMA Write Request FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_wait_send = cur_state == WAIT_SEND;
assign is_wait_resp = cur_state == WAIT_RESP;

assign j_wait_send = is_wait_resp & (cfg_interrupt_msix_sent | 
                                     cfg_interrupt_msix_fail | 
                                    !msix_enable);
assign j_wait_resp = is_wait_send & msix_enable & !int_out_empty;

always @(posedge pcie_clk, negedge pcie_rst_n) begin
	if(~pcie_rst_n)
		msix_enable <= `TD 1'd0;
	else
		msix_enable <= `TD cfg_interrupt_msix_enable[0];
end

always @(posedge pcie_clk, negedge pcie_rst_n) begin
	if(~pcie_rst_n)
		cur_state <= `TD WAIT_SEND;
	else
		cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/
always @(*) begin
	case(cur_state)
        WAIT_SEND: begin
            if (msix_enable & !int_out_empty)
                nxt_state = WAIT_RESP;
            else
                nxt_state = WAIT_SEND;
        end
        WAIT_RESP: begin
            if (cfg_interrupt_msix_sent | 
                cfg_interrupt_msix_fail | !msix_enable)
                nxt_state = WAIT_SEND;
            else
                nxt_state = WAIT_RESP;
        end
        default: begin
			nxt_state = WAIT_SEND;
		end
	endcase
end
/******************** Stage 3: Output **********************/

assign cfg_interrupt_msix_data           = int_out_data;
assign cfg_interrupt_msix_address        = int_out_addr;
assign cfg_interrupt_msix_int            = j_wait_resp;
assign cfg_interrupt_msi_function_number = 0;
/* -------{DMA Write Request FSM}end------- */


endmodule