`timescale 1ns / 1ps

`include "route_params_def.vh"

module MiscLayer
#(
    parameter       RW_REG_NUM      =       7 + 6 + 1,
    parameter       RO_REG_NUM      =       7 + 6 + 1
)
(
	input 	wire 		clk,    
	input 	wire 		rst,


/*Interface with RDMAEngine*/
//Egress traffic from RDMAEngine
    input   wire                i_outbound_pkt_wr_en,
    output  wire                o_outbound_pkt_prog_full,
    input   wire    [255:0]     iv_outbound_pkt_data,

					
    output 	wire                o_inbound_pkt_empty,
    input 	wire                i_inbound_pkt_rd_en,
    output  wire    [255:0]     ov_inbound_pkt_data,

/*Interface with CxtMgt*/
    output  wire                o_cxtmgt_cmd_wr_en,
    input   wire                i_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_cxtmgt_cmd_data,

    input   wire                i_cxtmgt_resp_empty,
    output  wire                o_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_cxtmgt_resp_data,

    input   wire                i_cxtmgt_cxt_empty,
    output  wire                o_cxtmgt_cxt_rd_en,
    input   wire    [255:0]     iv_cxtmgt_cxt_data,

/*Interface with TX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Tx  */
	output  wire                                 		o_hpc_tx_valid,
	output  wire                                 		o_hpc_tx_last,
	output  wire	[`NIC_DATA_WIDTH - 1 : 0]           ov_hpc_tx_data,
	output  wire	[`NIC_KEEP_WIDTH - 1 : 0]           ov_hpc_tx_keep,
	input   wire                                 		i_hpc_tx_ready,
	 //Additional signals
	output wire 										o_hpc_tx_start, 		//Indicates start of the packet
	output wire 	[6:0]		ov_hpc_tx_user, 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

/*Interface with RX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Rx  */
	input     wire                                 		i_hpc_rx_valid, 
	input     wire                                 		i_hpc_rx_last,
	input     wire	[`NIC_DATA_WIDTH - 1 : 0]       	iv_hpc_rx_data,
	input     wire	[`NIC_KEEP_WIDTH - 1 : 0]       	iv_hpc_rx_keep,
	output    wire                                 		o_hpc_rx_ready,	
	//Additional signals
	input 	  wire 										i_hpc_rx_start,
	//input 	  wire 	[`LINK_LAYER_USER_WIDTH - 1:0]		iv_hpc_rx_user, 
	input 	  wire 	[6:0]		iv_hpc_rx_user, 

/*Interface with Tx Eth Link, FIFO Interface*/
	output 		wire 									o_desc_empty,
	output 		wire 	[`ROCE_DESCRIPTOR_WIDTH - 1 : 0]		ov_desc_data,
	input 		wire 									i_desc_rd_en,

	output 		wire 									o_roce_egress_empty,
	input 		wire 									i_roce_egress_rd_en,
	output 		wire 	[`NIC_DATA_WIDTH - 1 : 0]		ov_roce_egress_data,

/*Interface with Rx Eth Link, FIFO Interface*/
	output 		wire 									o_roce_ingress_prog_full,
	input 		wire 									i_roce_ingress_wr_en,
	input 		wire 	[`NIC_DATA_WIDTH - 1 : 0]		iv_roce_ingress_data,

    output      wire                                    o_misc_layer_init_finish,

    input       wire    [RW_REG_NUM * 32 - 1 : 0]       rw_data,
    output      wire    [RW_REG_NUM * 32 - 1 : 0]       rw_init_data,
    output      wire    [RO_REG_NUM * 32 - 1 : 0]       ro_data,

    input       wire    [31:0]                          dbg_sel,
    output      wire    [32 - 1:0]                          dbg_bus
    //output      wire    [`DBG_NUM_MISC_LAYER * 32 - 1:0]                          dbg_bus
);

wire                [191:0]         wv_pe_rw_data;
wire                [191:0]         wv_pe_rw_init_data;
wire                [191:0]          wv_pe_ro_data;


reg 			     q_work_mode;

always @(posedge clk or posedge rst) begin
    if(rst) begin 
        q_work_mode <= `ETH_MODE;
    end
    else begin
        q_work_mode <= `ETH_MODE;
    end
end

assign wv_pe_rw_data = rw_data[191 + 7 * 32 : 0 + 7 * 32];

assign rw_init_data = {`ETH_MODE, wv_pe_rw_init_data, {7{32'd0}}};
assign ro_data = {q_work_mode, wv_pe_ro_data, rw_data[223:0]};
//assign wv_pe_rw_init_data = rw_data[159:0];

//wire        [31:0]      wv_pe_dbg_sel;
//wire        [`DBG_NUM_PACKET_ENCAP * 32 - 1:0]      wv_pe_dbg_bus;
//wire        [31:0]      wv_pd_dbg_sel;
//wire        [`DBG_NUM_PACKET_DECAP * 32 - 1:0]      wv_pd_dbg_bus;
//wire        [31:0]      wv_fta_dbg_sel;
//wire        [`DBG_NUM_FIFO_TO_AXIS_TRANS * 32 - 1:0]      wv_fta_dbg_bus;
wire        [31:0]      wv_pe_dbg_sel;
wire        [32 - 1:0]      wv_pe_dbg_bus;
wire        [31:0]      wv_pd_dbg_sel;
wire        [32 - 1:0]      wv_pd_dbg_bus;
wire        [31:0]      wv_fta_dbg_sel;
wire        [32 - 1:0]      wv_fta_dbg_bus;

assign wv_pe_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_pd_dbg_sel = dbg_sel - (`DBG_NUM_PACKET_ENCAP);
assign wv_fta_dbg_sel = dbg_sel - (`DBG_NUM_PACKET_ENCAP + `DBG_NUM_PACKET_DECAP);

assign dbg_bus =    (dbg_sel >= `DBG_NUM_ZERO && dbg_sel <= `DBG_NUM_PACKET_ENCAP - 1) ? wv_pe_dbg_bus :
                    (dbg_sel >= `DBG_NUM_PACKET_ENCAP && dbg_sel <= `DBG_NUM_PACKET_ENCAP + `DBG_NUM_PACKET_DECAP - 1) ? wv_pd_dbg_bus :
                    (dbg_sel >= `DBG_NUM_PACKET_ENCAP + `DBG_NUM_PACKET_DECAP && dbg_sel <= `DBG_NUM_PACKET_ENCAP + `DBG_NUM_PACKET_DECAP + `DBG_NUM_FIFO_TO_AXIS_TRANS- 1) ? wv_fta_dbg_bus : 32'd0;
//assign dbg_bus = {wv_pe_dbg_bus, wv_pd_dbg_bus, wv_fta_dbg_bus};

//FIFO Interface with AXIS-FIFO module
wire                w_encap_prog_full;
wire                w_encap_wr_en;
wire    [255:0]     wv_encap_din; 
wire                w_encap_empty;
wire                w_encap_rd_en;
wire    [255:0]     wv_encap_dout;

wire                w_decap_prog_full;
wire                w_decap_wr_en;
wire    [255:0]     wv_decap_din; 
wire                w_decap_empty;
wire                w_decap_rd_en;
wire    [255:0]     wv_decap_dout;

//FIFO Interface with RDMAEngine
wire                w_outbound_pkt_empty;
wire                w_outbound_pkt_rd_en;
wire    [255:0]     wv_outbound_pkt_dout;

wire                w_inbound_pkt_prog_full;            
wire                w_inbound_pkt_wr_en;
wire    [255:0]     wv_inbound_pkt_din;

wire                w_roce_ingress_empty;
wire                w_roce_ingress_rd_en;
wire    [255:0]     wv_roce_ingress_dout;

wire                w_roce_egress_prog_full;            
wire                w_roce_egress_wr_en;
wire    [255:0]     wv_roce_egress_din;

wire                w_desc_wr_en;
wire                w_desc_prog_full;
wire    [191:0]     wv_desc_din;

`ifndef RDMA_SIM
SyncFIFO_256w_32d OutboundFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL(rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL(rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(rw_data[0 * 32 + 7 : 0 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(i_outbound_pkt_wr_en),
    .din(iv_outbound_pkt_data),
    .prog_full(o_outbound_pkt_prog_full),
	.full(),
    .rd_en(w_outbound_pkt_rd_en),
    .empty(w_outbound_pkt_empty),
    .dout(wv_outbound_pkt_dout)
);

SyncFIFO_256w_32d InboundFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL(rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL(rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(rw_data[1 * 32 + 7 : 1 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(w_inbound_pkt_wr_en),
    .din(wv_inbound_pkt_din),
    .prog_full(w_inbound_pkt_prog_full),
	.full(),
    .rd_en(i_inbound_pkt_rd_en),
    .empty(o_inbound_pkt_empty),
    .dout(ov_inbound_pkt_data)
);

SyncFIFO_256w_32d EncapFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL(rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL(rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(rw_data[2 * 32 + 7 : 2 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(w_encap_wr_en),
    .din(wv_encap_din),
    .prog_full(w_encap_prog_full),
	.full(),
    .rd_en(w_encap_rd_en),
    .empty(w_encap_empty),
    .dout(wv_encap_dout)
);

SyncFIFO_256w_32d DecapFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL(rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL(rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(rw_data[3 * 32 + 7 : 3 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(w_decap_wr_en),
    .din(wv_decap_din),
    .prog_full(w_decap_prog_full),
	.full(),
    .rd_en(w_decap_rd_en),
    .empty(w_decap_empty),
    .dout(wv_decap_dout)
);

SyncFIFO_256w_32d RoCE_EgressFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL(rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL(rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(rw_data[4 * 32 + 7 : 4 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(w_roce_egress_wr_en),
    .din(wv_roce_egress_din),
    .prog_full(w_roce_egress_prog_full),
	.full(),
    .rd_en(i_roce_egress_rd_en),
    .empty(o_roce_egress_empty),
    .dout(ov_roce_egress_data)
);

SyncFIFO_256w_32d RoCE_IngressFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL(rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL(rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(rw_data[5 * 32 + 7 : 5 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(i_roce_ingress_wr_en),
    .din(iv_roce_ingress_data),
    .prog_full(o_roce_ingress_prog_full),
	.full(),
    .rd_en(w_roce_ingress_rd_en),
    .empty(w_roce_ingress_empty),
    .dout(wv_roce_ingress_dout)
);

SyncFIFO_192w_32d DescFIFO(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL(rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL(rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(rw_data[6 * 32 + 7 : 6 * 32 + 7]),
`endif
    .clk(clk),
    .srst(rst),
    .wr_en(w_desc_wr_en),
    .din(wv_desc_din),
    .prog_full(w_desc_prog_full),
	.full(),
    .rd_en(i_desc_rd_en),
    .empty(o_desc_empty),
    .dout(ov_desc_data)
);

`else 
SyncFIFO_256w_32d OutboundFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(i_outbound_pkt_wr_en),
    .din(iv_outbound_pkt_data),
    .prog_full(o_outbound_pkt_prog_full),
    .rd_en(w_outbound_pkt_rd_en),
    .empty(w_outbound_pkt_empty),
    .dout(wv_outbound_pkt_dout)
);

SyncFIFO_256w_32d InboundFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(w_inbound_pkt_wr_en),
    .din(wv_inbound_pkt_din),
    .prog_full(w_inbound_pkt_prog_full),
    .rd_en(i_inbound_pkt_rd_en),
    .empty(o_inbound_pkt_empty),
    .dout(ov_inbound_pkt_data)
);

SyncFIFO_256w_32d EncapFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(w_encap_wr_en),
    .din(wv_encap_din),
    .prog_full(w_encap_prog_full),
    .rd_en(w_encap_rd_en),
    .empty(w_encap_empty),
    .dout(wv_encap_dout)
);

SyncFIFO_256w_32d DecapFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(w_decap_wr_en),
    .din(wv_decap_din),
    .prog_full(w_decap_prog_full),
    .rd_en(w_decap_rd_en),
    .empty(w_decap_empty),
    .dout(wv_decap_dout)
);

SyncFIFO_256w_32d RoCE_EgressFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(w_roce_egress_wr_en),
    .din(wv_roce_egress_din),
    .prog_full(w_roce_egress_prog_full),
    .rd_en(i_roce_egress_rd_en),
    .empty(o_roce_egress_empty),
    .dout(ov_roce_egress_data)
);

SyncFIFO_256w_32d RoCE_ingressFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(i_roce_ingress_wr_en),
    .din(iv_roce_ingress_data),
    .prog_full(o_roce_ingress_prog_full),
    .rd_en(w_roce_ingress_rd_en),
    .empty(w_roce_ingress_empty),
    .dout(wv_roce_ingress_dout)
);

SyncFIFO_192w_32d DescFIFO(
    .clk(clk),
    .srst(rst),
    .wr_en(w_desc_wr_en),
    .din(wv_desc_din),
    .prog_full(w_desc_prog_full),
    .rd_en(i_desc_rd_en),
    .empty(o_desc_empty),
    .dout(ov_desc_data)
);
`endif

PacketEncap		PacketEncap_Inst(
	.clk(clk),
	.rst(rst),

	.i_work_mode(q_work_mode),

//CxtMgt
    .o_cxtmgt_cmd_wr_en(o_cxtmgt_cmd_wr_en),
    .i_cxtmgt_cmd_prog_full(i_cxtmgt_cmd_prog_full),
    .ov_cxtmgt_cmd_data(ov_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_cxtmgt_resp_empty),
    .o_cxtmgt_resp_rd_en(o_cxtmgt_resp_rd_en),
    .iv_cxtmgt_resp_data(iv_cxtmgt_resp_data),

    .i_cxtmgt_cxt_empty(i_cxtmgt_cxt_empty),
    .o_cxtmgt_cxt_rd_en(o_cxtmgt_cxt_rd_en),
    .iv_cxtmgt_cxt_data(iv_cxtmgt_cxt_data),

//Egress traffic from RDMAEngine
    .i_ib_pkt_empty(w_outbound_pkt_empty),
    .o_ib_pkt_rd_en(w_outbound_pkt_rd_en),
    .iv_ib_pkt_data(wv_outbound_pkt_dout), 

//Interface with Roce Subsystem
    .i_desc_prog_full(w_desc_prog_full),
    .o_desc_wr_en(w_desc_wr_en),
    .ov_desc_data(wv_desc_din),

    .i_eth_prog_full(w_roce_egress_prog_full),
    .o_eth_wr_en(w_roce_egress_wr_en),
    .ov_eth_data(wv_roce_egress_din),

    .i_hpc_prog_full(w_encap_prog_full),
    .o_hpc_wr_en(w_encap_wr_en),
    .ov_hpc_data(wv_encap_din),


    .o_fe_init_finish(o_misc_layer_init_finish),

    .rw_data(wv_pe_rw_data),
    .rw_init_data(wv_pe_rw_init_data),
    .ro_data(wv_pe_ro_data),

    .dbg_sel(wv_pe_dbg_sel),
    .dbg_bus(wv_pe_dbg_bus)
);

PacketDecap 	PacketDecap_Inst(
	.clk(clk),
	.rst(rst),

	.i_work_mode(q_work_mode),

/*Interface with RDMAEngine*/
	.iv_hpc_pkt_data(wv_decap_dout),
	.i_hpc_pkt_empty(w_decap_empty),
	.o_hpc_pkt_rd_en(w_decap_rd_en),

	.iv_roce_pkt_data(wv_roce_ingress_dout),
	.i_roce_pkt_empty(w_roce_ingress_empty),
	.o_roce_pkt_rd_en(w_roce_ingress_rd_en),

    .ov_pkt_data(wv_inbound_pkt_din),
    .o_pkt_wr_en(w_inbound_pkt_wr_en),
    .i_pkt_prog_full(w_inbound_pkt_prog_full),

    .dbg_sel(wv_pd_dbg_sel),
    .dbg_bus(wv_pd_dbg_bus)
);

AXIStoFIFOTrans 	AXISToFIFOTrans_Inst(
    .clk(clk),
    .rst(rst),

    .i_hpc_prog_full(w_decap_prog_full),
    .o_hpc_wr_en(w_decap_wr_en),
    .ov_hpc_data(wv_decap_din),

    .i_hpc_rx_valid(i_hpc_rx_valid),
    .i_hpc_rx_last(i_hpc_rx_last),
    .iv_hpc_rx_data(iv_hpc_rx_data),
    .iv_hpc_rx_keep(iv_hpc_rx_keep),
    .o_hpc_rx_ready(o_hpc_rx_ready),
    .i_hpc_rx_start(i_hpc_rx_start),
    .iv_hpc_rx_user(iv_hpc_rx_user)
);

FIFOToAXISTrans 	FIFOToAXISTrans_Inst(
    .clk(clk),
    .rst(rst),

    .o_hpc_rd_en(w_encap_rd_en),
    .i_hpc_empty(w_encap_empty),
    .iv_hpc_data(wv_encap_dout),

    .o_hpc_tx_valid(o_hpc_tx_valid),
    .o_hpc_tx_last(o_hpc_tx_last),
    .ov_hpc_tx_data(ov_hpc_tx_data),
    .ov_hpc_tx_keep(ov_hpc_tx_keep),
    .i_hpc_tx_ready(i_hpc_tx_ready),
    .o_hpc_tx_start(o_hpc_tx_start),
    .ov_hpc_tx_user(ov_hpc_tx_user),

    .dbg_sel(wv_fta_dbg_sel),
    .dbg_bus(wv_fta_dbg_bus)

);

endmodule
