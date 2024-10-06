`timescale 1ns / 1ps

`ifndef APB_DATA_WIDTH
    `define APB_DATA_WIDTH 32
`endif

`ifndef APB_ADDR_WIDTH
    `define APB_ADDR_WIDTH 18
`endif

`include "route_params_def.vh"
`include "cfg_node_def.vh"

module NIC_Top
#(
    //ENGINE_TOP PARAMETERS
    //NIC_TOP PARAMETERS
    parameter C_DATA_WIDTH                   = 256,         // RX/TX interface data width
    parameter KEEP_WIDTH                     = C_DATA_WIDTH / 32,
    // defined for pcie interface
    parameter DMA_HEAD_WIDTH                 = 128      ,
    parameter AXIL_DATA_WIDTH                = 32       ,
    parameter AXIL_ADDR_WIDTH                = 24       ,
    parameter ETH_BASE                       = 24'h0    ,
    parameter ETH_LEN                        = 24'h1000 ,
    parameter DB_BASE                        = 12'h0    ,
    parameter HCR_BASE                       = 20'h80000,
    parameter AXIL_STRB_WIDTH                = (AXIL_DATA_WIDTH/8),
    parameter ENGINE_NIC_DATA_WIDTH 		 = 256,
    parameter ENGINE_NIC_KEEP_WIDTH 		 = 32,
    parameter ENGINE_LINK_LAYER_USER_WIDTH   = 7,
    //HOSTROUTE PARAMETERS
	parameter PORT_NUM_LOG_2                 = 32'd4,
	parameter PORT_INDEX                     = 32'd0,
	parameter PORT_NUM                       = 32'd16,
	parameter QUEUE_DEPTH_LOG_2              = 10, 	//Maximum depth of one output queue is (1 << QUEUE_DEPTH)

    //PCIE_SUBSYS PARAMETERS 
    parameter G_NUM_FUNC                     = 1,
    parameter G_NUM_LANES                    = 8,
    parameter G_PIPE_WIDTH                   = 'h44222,
    parameter G_PIPE_INTF                    = 0,
    parameter G_RXBUF_LATENCY                = 11,
    parameter G_TXBUF_LATENCY                = 11,
    parameter G_NPBUF_SIZE                   = 1,
    parameter G_NPBUF_WIDTH                  = 4,
    parameter G_MAX_VF                       = 0,
    parameter G_DATA_PROT                    = 0,
    parameter G_DL_DATAPATH                  = 8,
    parameter G_TL_DATAPATH                  = 8,
    parameter PCIE_DATA_WIDTH                = 32,
    parameter PCIE_ADDR_WIDTH                = 18  
)
(
    input 		wire 										rst,
	input 		wire 										pcie_clk,
	input 		wire 										nic_clk,

	output 		wire 										o_nic_init_finish,

    output 		wire                          				s_axis_rq_tvalid,
    output 		wire                          				s_axis_rq_tlast ,
    output 		wire 	[KEEP_WIDTH-1:0]     				s_axis_rq_tkeep ,
    output 		wire    [59:0]     							s_axis_rq_tuser ,
    output 		wire 	[C_DATA_WIDTH-1:0]     				s_axis_rq_tdata ,
    input    	wire    [0:0]       						s_axis_rq_tready,
	
    input    	wire                          				m_axis_rc_tvalid,
    input    	wire                          				m_axis_rc_tlast ,
    input    	wire   	[KEEP_WIDTH-1:0]       				m_axis_rc_tkeep ,
    input    	wire   	[74:0]								m_axis_rc_tuser ,
    input    	wire 	[C_DATA_WIDTH-1:0]     				m_axis_rc_tdata ,
    output 		wire                        	  			m_axis_rc_tready,

    input    	wire                        				m_axis_cq_tvalid,
    input    	wire                        				m_axis_cq_tlast ,
    input    	wire   	[KEEP_WIDTH-1:0]     				m_axis_cq_tkeep ,
    input    	wire    [84:0]     							m_axis_cq_tuser ,
    input    	wire 	[C_DATA_WIDTH-1:0]     				m_axis_cq_tdata ,
    output 		wire                          				m_axis_cq_tready,

    output 		wire                          				s_axis_cc_tvalid,
    output 		wire                          				s_axis_cc_tlast ,
    output 		wire    [KEEP_WIDTH-1:0]     				s_axis_cc_tkeep ,
    output 		wire    [32:0]     							s_axis_cc_tuser ,
    output 		wire    [C_DATA_WIDTH-1:0]     				s_axis_cc_tdata ,
    input       wire    [0:0]     							s_axis_cc_tready,

    //CONNECTIONS BETWEEN ENGINE AND LINK
    input       wire									nic_link_hpc_rx_pkt_valid,
    input       wire 									nic_link_hpc_rx_pkt_start,
    input       wire 									nic_link_hpc_rx_pkt_end  ,
    input       wire [`HOST_ROUTE_USER_WIDTH - 1 : 0]	nic_link_hpc_rx_pkt_user ,
    input       wire [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]	nic_link_hpc_rx_pkt_keep ,
    input       wire [`HOST_ROUTE_DATA_WIDTH - 1 : 0]	nic_link_hpc_rx_pkt_data ,
    output      wire 								    nic_link_hpc_rx_pkt_ready,

    input       wire									nic_link_eth_rx_pkt_valid ,
    input       wire 									nic_link_eth_rx_pkt_start ,
    input       wire 									nic_link_eth_rx_pkt_end   ,
    input       wire [`HOST_ROUTE_USER_WIDTH - 1 : 0]	nic_link_eth_rx_pkt_user  ,
    input       wire [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]	nic_link_eth_rx_pkt_keep  ,
    input       wire [`HOST_ROUTE_DATA_WIDTH - 1 : 0]	nic_link_eth_rx_pkt_data  ,
    output      wire 								    nic_link_eth_rx_pkt_ready ,

    output      wire 									nic_link_hpc_tx_pkt_valid,
    output      wire 									nic_link_hpc_tx_pkt_start,
    output      wire 									nic_link_hpc_tx_pkt_end  ,
    output      wire [`HOST_ROUTE_USER_WIDTH - 1 : 0]	nic_link_hpc_tx_pkt_user ,
    output      wire [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]	nic_link_hpc_tx_pkt_keep ,
    output      wire [`HOST_ROUTE_DATA_WIDTH - 1 : 0]	nic_link_hpc_tx_pkt_data ,
    input       wire 							        nic_link_hpc_tx_pkt_ready,

    output      wire                                     nic_link_eth_tx_pkt_valid,
    output      wire                                     nic_link_eth_tx_pkt_start,
    output      wire                                     nic_link_eth_tx_pkt_end  ,
    output      wire [`HOST_ROUTE_USER_WIDTH - 1 : 0]    nic_link_eth_tx_pkt_user ,
    output      wire [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]    nic_link_eth_tx_pkt_keep ,
    output      wire [`HOST_ROUTE_DATA_WIDTH - 1 : 0]    nic_link_eth_tx_pkt_data ,
    input       wire                                      nic_link_eth_tx_pkt_ready,

    input       wire [591 : 0]                            PCIe_Interface_rw_data,
    input       wire [2:0]                                cfg_max_payload,
    input       wire [2:0]                                cfg_max_read_req
);

    //connections of hpc traffic stream
    wire [5 - 1 : 0]     					  rdma_tx_keep ;
    wire                              		  hpc_tx_valid;
    wire                              		  hpc_tx_last ;
    wire [ENGINE_NIC_DATA_WIDTH - 1 : 0]      hpc_tx_data ;
    wire [ENGINE_NIC_KEEP_WIDTH - 1 : 0]      hpc_tx_keep ;
    wire                              		  hpc_tx_ready;
    wire 									  hpc_tx_start;
    wire [ENGINE_LINK_LAYER_USER_WIDTH - 1:0] hpc_tx_user ;
    wire [5 - 1 : 0]     					  rdma_rx_keep ;
    wire                              		  hpc_rx_valid;
    wire                              		  hpc_rx_last ;
    wire [ENGINE_NIC_DATA_WIDTH - 1 : 0]      hpc_rx_data ;
    wire [ENGINE_NIC_KEEP_WIDTH - 1 : 0]      hpc_rx_keep ;
    wire                              		  hpc_rx_ready;
    wire 									  hpc_rx_start;
    wire [ENGINE_LINK_LAYER_USER_WIDTH - 1:0] hpc_rx_user ;
    //connections of eth traffic stream
    wire                               		  eth_tx_valid;
    wire                               		  eth_tx_last ;
    wire [ENGINE_NIC_DATA_WIDTH - 1 : 0]      eth_tx_data ;
    wire [ENGINE_NIC_KEEP_WIDTH - 1 : 0]      eth_tx_keep ;
    wire                               		  eth_tx_ready;
    wire 									  eth_tx_start;
    wire [ENGINE_LINK_LAYER_USER_WIDTH - 1:0] eth_tx_user ;
    wire                              	      eth_rx_valid; 
    wire                              	      eth_rx_last ;
    wire [ENGINE_NIC_DATA_WIDTH - 1 : 0]      eth_rx_data ;
    wire [ENGINE_NIC_KEEP_WIDTH - 1 : 0]      eth_rx_keep ;
    wire                              	      eth_rx_ready;	
    wire 									  eth_rx_start;
    wire [ENGINE_LINK_LAYER_USER_WIDTH - 1:0] eth_rx_user ; 
    //CONNECTIONS OF P2P INTERFACES
    wire [1 - 1 : 0] 	                      p2p_tx_valid; 
    wire [1 - 1 : 0] 	                      p2p_tx_last ; 
    wire [256 - 1 : 0] 	                      p2p_tx_data ; 
    wire [64 - 1 : 0] 	                      p2p_tx_head ; 
    wire [1 - 1 : 0] 	                      p2p_tx_ready; 
    wire [1 - 1 : 0] 	                      p2p_rx_valid;
    wire [1 - 1 : 0] 	                      p2p_rx_last ;
    wire [256 - 1 : 0] 	                      p2p_rx_data ;
    wire [64 - 1 : 0] 	                      p2p_rx_head ;
    wire [1 - 1 : 0] 	                      p2p_rx_ready;
    // Command reset
    wire                            cmd_rst;
    /* -------pio interface{begin}------- */
    wire [63:0]                     pio_hcr_in_param    ;
    wire [31:0]                     pio_hcr_in_modifier ;
    wire [63:0]                     pio_hcr_out_dma_addr;
    wire [63:0]                     pio_hcr_out_param   ;
    wire [15:0]                     pio_hcr_token       ;
    wire [ 7:0]                     pio_hcr_status      ;
    wire                            pio_hcr_go          ;
    wire                            pio_hcr_clear       ;
    wire                            pio_hcr_event       ;
    wire [ 7:0]                     pio_hcr_op_modifier ;
    wire [11:0]                     pio_hcr_op          ;
    wire [63:0]                     pio_uar_db_data  ;
    wire                            pio_uar_db_ready ;
    wire                            pio_uar_db_valid ;
    /* -------pio interface{end}------- */

    /* -------dma interface{begin}------- */
    // CEU Relevant
    // CEU Read Req
    wire                            dma_ceu_rd_req_valid ;
    wire                            dma_ceu_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_ceu_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_ceu_rd_req_head  ;
    wire                            dma_ceu_rd_req_last  ;
    // CEU DMA Read Resp
    wire                            dma_ceu_rd_rsp_valid ;
    wire                            dma_ceu_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_ceu_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_ceu_rd_rsp_head  ;
    wire                            dma_ceu_rd_rsp_last  ;
    // CEU DMA Write Req
    wire                            dma_ceu_wr_req_valid ;
    wire                            dma_ceu_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_ceu_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_ceu_wr_req_head  ;
    wire                            dma_ceu_wr_req_last  ;
    // End CEU Relevant
    // CxtMgt Relevant
    // Context Management DMA Read Request
    wire                            dma_cm_rd_req_valid ;
    wire                            dma_cm_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cm_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cm_rd_req_head  ;
    wire                            dma_cm_rd_req_last  ;
    // Context Management DMA Read Response
    wire                            dma_cm_rd_rsp_valid ;
    wire                            dma_cm_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cm_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cm_rd_rsp_head  ;
    wire                            dma_cm_rd_rsp_last  ;
    // Context Management DMA Write Request
    wire                            dma_cm_wr_req_valid ;
    wire                            dma_cm_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cm_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cm_wr_req_head  ;
    wire                            dma_cm_wr_req_last  ;
    // End CxtMgt Relevant
    // Virt2Phys Relevant
    // Virtual to Physical DMA Context (MPT) Read Request
    wire                            dma_cv2p_mpt_rd_req_valid ;
    wire                            dma_cv2p_mpt_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mpt_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mpt_rd_req_head  ;
    wire                            dma_cv2p_mpt_rd_req_last  ;
    // Virtual to Physical DMA Context (MPT) Read Response
    wire                            dma_cv2p_mpt_rd_rsp_valid ;
    wire                            dma_cv2p_mpt_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mpt_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mpt_rd_rsp_head  ;
    wire                            dma_cv2p_mpt_rd_rsp_last  ;
    // Virtual to Physical DMA Cont1ext (MPT) Write Request
    wire                            dma_cv2p_mpt_wr_req_valid ;
    wire                            dma_cv2p_mpt_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mpt_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mpt_wr_req_head  ;
    wire                            dma_cv2p_mpt_wr_req_last  ;
    // Virtual to Physical DMA Context (MTT) Read Request
    wire                            dma_cv2p_mtt_rd_req_valid ;
    wire                            dma_cv2p_mtt_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mtt_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mtt_rd_req_head  ;
    wire                            dma_cv2p_mtt_rd_req_last  ;
    // Virtual to Physical DMA Context Read Response
    wire                            dma_cv2p_mtt_rd_rsp_valid ;
    wire                            dma_cv2p_mtt_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mtt_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mtt_rd_rsp_head  ;
    wire                            dma_cv2p_mtt_rd_rsp_last  ;
    // Virtual to Physical DMA Context Write Request
    wire                            dma_cv2p_mtt_wr_req_valid ;
    wire                            dma_cv2p_mtt_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_cv2p_mtt_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_cv2p_mtt_wr_req_head  ;
    wire                            dma_cv2p_mtt_wr_req_last  ;
    // Virtual to Physical DMA Data Read Request
    wire                            dma_dv2p_rd_req_valid ;
    wire                            dma_dv2p_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_dv2p_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_dv2p_rd_req_head  ;
    wire                            dma_dv2p_rd_req_last  ;
    // Virtual to Physical DMA Data Read Response
    wire                            dma_dv2p_rd_rsp_valid ;
    wire                            dma_dv2p_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_dv2p_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_dv2p_rd_rsp_head  ;
    wire                            dma_dv2p_rd_rsp_last  ;
    // Virtual to Physical DMA Data Write Request
    wire                            dma_dv2p_wr_req_valid ;
    wire                            dma_dv2p_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_dv2p_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_dv2p_wr_req_head  ;
    wire                            dma_dv2p_wr_req_last  ;
    // ADD 1 DMA read and response channel for v2p read RQ WQE
    // Virtual to Physical DMA RQ WQE Read Request
    wire                           dma_dv2p_wqe_rd_req_valid;
    wire                           dma_dv2p_wqe_rd_req_last ;
    wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_req_data ;
    wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_req_head ;
    wire                           dma_dv2p_wqe_rd_req_ready;
    // Virtual to Physical DMA RQ WQE  Read Response
    wire                           dma_dv2p_wqe_rd_rsp_valid;
    wire                           dma_dv2p_wqe_rd_rsp_last ;
    wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_rsp_data ;
    wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_rsp_head ;
    wire                           dma_dv2p_wqe_rd_rsp_ready;
    //Eth Interface with DMA
    //Tx Desc Fetch
    wire                            dma_tx_desc_rd_req_valid ;
    wire                            dma_tx_desc_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_tx_desc_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_tx_desc_rd_req_head  ;
    wire                            dma_tx_desc_rd_req_last  ;

    wire                            dma_tx_desc_rd_rsp_valid ;
    wire                            dma_tx_desc_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_tx_desc_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_tx_desc_rd_rsp_head  ;
    wire                            dma_tx_desc_rd_rsp_last  ;
    //Tx Frame Fetch
    wire                            dma_tx_frame_rd_req_valid ;
    wire                            dma_tx_frame_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_tx_frame_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_tx_frame_rd_req_head  ;
    wire                            dma_tx_frame_rd_req_last  ;

    wire                            dma_tx_frame_rd_rsp_valid ;
    wire                            dma_tx_frame_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_tx_frame_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_tx_frame_rd_rsp_head  ;
    wire                            dma_tx_frame_rd_rsp_last  ;
    //Tx Completion Write
    wire                            dma_tx_axis_wr_req_valid ;
    wire                            dma_tx_axis_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_tx_axis_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_tx_axis_wr_req_head  ;
    wire                            dma_tx_axis_wr_req_last  ;
    //Rx Desc Fetch
    wire                            dma_rx_desc_rd_req_valid ;
    wire                            dma_rx_desc_rd_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_rx_desc_rd_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_rx_desc_rd_req_head  ;
    wire                            dma_rx_desc_rd_req_last  ;

    wire                            dma_rx_desc_rd_rsp_valid ;
    wire                            dma_rx_desc_rd_rsp_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_rx_desc_rd_rsp_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_rx_desc_rd_rsp_head  ;
    wire                            dma_rx_desc_rd_rsp_last  ;
    //Rx Completion Write
    wire                            dma_rx_axis_wr_req_valid ;
    wire                            dma_rx_axis_wr_req_ready ;
    wire [(C_DATA_WIDTH-1)  :0]     dma_rx_axis_wr_req_data  ;
    wire [(DMA_HEAD_WIDTH-1):0]     dma_rx_axis_wr_req_head  ;
    wire                            dma_rx_axis_wr_req_last  ;
    /* -------dma interface{end}------- */

    //CONNECTIONS AMONG CFG_RING
    wire [66:0]                         cfg_pkt_0;
    wire                                cfg_pkt_vld_0;
    wire                                cfg_pkt_rdy_0;
    wire [66:0]                         cfg_pkt_1;
    wire                                cfg_pkt_vld_1;
    wire                                cfg_pkt_rdy_1;
    wire [66:0]                         cfg_pkt_2;
    wire                                cfg_pkt_vld_2;
    wire                                cfg_pkt_rdy_2;
    wire [66:0]                         cfg_pkt_3;
    wire                                cfg_pkt_vld_3;
    wire                                cfg_pkt_rdy_3;

    
    wire 				w_roce_prog_full;
    wire 	[255:0]		wv_roce_ingress_data;
    wire 				w_roce_wr_en;
    /* input from roce desc, request for a desc */
    wire 				w_tx_desc_empty;
    wire [191:0]		wv_tx_desc_data;
    wire 				w_tx_desc_rd_en;
    wire 				w_roce_empty;
    wire [255:0]		wv_roce_egress_data;
    wire 				w_roce_rd_en;
    wire                eq_ren ;
    wire [31:0]         eq_num ;
    wire                eq_dout;
    wire                cq_ren ; // i, 1
    wire [31:0]         cq_num ; // i, 32
    wire                cq_dout; // o, 1
    /* --------Interrupt Vector entry request & response{begin}-------- */
    wire                pio_eq_int_req_valid;
    wire [63:0]          pio_eq_int_req_num  ;
    wire                pio_eq_int_req_ready;
    wire                pio_eq_int_rsp_valid; // i, 1
    wire [127:0]        pio_eq_int_rsp_data ; // i, 128
    wire                pio_eq_int_rsp_ready; // o, 1
    wire                rdma_init_finish;
    wire                pcie_mprstn;
    wire                xlgmii_gate_en;
    wire                eth_scan_clk;
    wire                occ_eth_scan_clk;
    wire                occ_mbist_done;
    wire                ist_mbist_rstn;
    wire                wmbist_clk_wd;

	wire [31:0]         				PCIe_Interface_dbg_bus;//32 bit 
	wire [7:0] 							pcie_apb_dbg_bus;
	wire [31:0]                         host_dbg_sel,host_dbg_bus;
	
	wire [31:0]                         top_stat;
	wire [31:0] 						dbg_bus_top;

    /* --------Interact with Ethernet BAR{begin}------- */
    wire [AXIL_ADDR_WIDTH-1:0]    m_axi_awaddr ;
    wire                          m_axi_awvalid;
    wire                          m_axi_awready;
    wire [AXIL_DATA_WIDTH-1:0]    m_axi_wdata ;
    wire [AXIL_STRB_WIDTH-1:0]    m_axi_wstrb ;
    wire                          m_axi_wvalid;
    wire                          m_axi_wready;
    wire                          m_axi_bvalid;
    wire                          m_axi_bready;
    wire [AXIL_ADDR_WIDTH-1:0]    m_axi_araddr ;
    wire                          m_axi_arvalid;
    wire                          m_axi_arready;
    wire [AXIL_DATA_WIDTH-1:0]    m_axi_rdata ;
    wire                          m_axi_rvalid;
    wire                          m_axi_rready;
    /* --------Interact with Ethernet BAR{end}------- */

wire w_rdma_init_finish;
assign o_nic_init_finish = w_rdma_init_finish;

// pcie interface
    PCIe_Interface  u_pcie_interface (
        .pcie_clk                                ( pcie_clk),
        .pcie_rst_n                              ( ~rst      ),
        .user_clk                                ( nic_clk          ),
        .user_rst_n                              ( ~rst     ),
        .ist_mbist_rstn                          ( ~rst    ),  
        .ist_mbist_done                          (),  
        .ist_mbist_pass                          (),  
        .rdma_init_done                          (rdma_init_finish  ),

        .s_axis_rq_tvalid                        ( s_axis_rq_tvalid ), // o, 1
        .s_axis_rq_tlast                         ( s_axis_rq_tlast  ), // o, 1
        .s_axis_rq_tkeep                         ( s_axis_rq_tkeep  ), // o, 8
        .s_axis_rq_tuser                         ( s_axis_rq_tuser  ), // o, 60
        .s_axis_rq_tdata                         ( s_axis_rq_tdata  ), // o, 256
        .s_axis_rq_tready                        ( {3'b0, s_axis_rq_tready} ), // i, 1
        .m_axis_rc_tvalid                        ( m_axis_rc_tvalid ), // i, 1
        .m_axis_rc_tlast                         ( m_axis_rc_tlast  ), // i, 1
        .m_axis_rc_tkeep                         ( m_axis_rc_tkeep  ), // i, 8
        .m_axis_rc_tuser                         ( m_axis_rc_tuser  ), // i, 75
        .m_axis_rc_tdata                         ( m_axis_rc_tdata  ), // i, 256
        .m_axis_rc_tready                        ( m_axis_rc_tready ), // o, 1
        .m_axis_cq_tvalid                        ( m_axis_cq_tvalid ), // i, 1
        .m_axis_cq_tlast                         ( m_axis_cq_tlast  ), // i, 1
        .m_axis_cq_tkeep                         ( m_axis_cq_tkeep  ), // i, 8
        .m_axis_cq_tuser                         ( m_axis_cq_tuser  ), // i, 85
        .m_axis_cq_tdata                         ( m_axis_cq_tdata  ), // i, 256
        .m_axis_cq_tready                        ( m_axis_cq_tready ), // o, 1
        .s_axis_cc_tvalid                        ( s_axis_cc_tvalid ), // o, 1
        .s_axis_cc_tlast                         ( s_axis_cc_tlast  ), // o, 1
        .s_axis_cc_tkeep                         ( s_axis_cc_tkeep  ), // o, 256
        .s_axis_cc_tuser                         ( s_axis_cc_tuser  ), // o, 33
        .s_axis_cc_tdata                         ( s_axis_cc_tdata  ), // o, 256
        .s_axis_cc_tready                        ({3'b0, s_axis_cc_tready}), // i, 1
        .cfg_max_payload                         (cfg_max_payload       ), 
        .cfg_max_read_req                        (cfg_max_read_req     ),
        .cfg_interrupt_msix_enable               (2'h0  ), // i, 2
        .cfg_interrupt_msix_mask                 (2'h0  ), // i, 2
        .cfg_interrupt_msix_data                 (), // o, 32
        .cfg_interrupt_msix_address              (), // o, 64
        .cfg_interrupt_msix_int                  (), // o, 1
        .cfg_interrupt_msix_sent                 (1'b0  ), // i, 1
        .cfg_interrupt_msix_fail                 (1'b0  ), // i, 1
        .cfg_interrupt_msi_function_number       (), // o, 3
        .cmd_rst                                 ( cmd_rst  ), // o, 1
        .pio_hcr_in_param                        ( pio_hcr_in_param     ), // o, 64
        .pio_hcr_in_modifier                     ( pio_hcr_in_modifier  ), // o, 32
        .pio_hcr_out_dma_addr                    ( pio_hcr_out_dma_addr ), // o, 64
        .pio_hcr_out_param                       ( pio_hcr_out_param    ), // i, 64
        .pio_hcr_token                           ( pio_hcr_token        ), // o, 16
        .pio_hcr_status                          ( pio_hcr_status       ), // i, 8
        .pio_hcr_go                              ( pio_hcr_go           ), // o, 1
        .pio_hcr_clear                           ( pio_hcr_clear        ), // i, 1
        .pio_hcr_event                           ( pio_hcr_event        ), // o, 1
        .pio_hcr_op_modifier                     ( pio_hcr_op_modifier  ), // o, 8
        .pio_hcr_op                              ( pio_hcr_op           ), // o, 12
        .pio_uar_db_data                         ( pio_uar_db_data      ), // o, 64
        .pio_uar_db_ready                        ( pio_uar_db_ready     ), // i, 1
        .pio_uar_db_valid                        ( pio_uar_db_valid     ), // o, 1
        .cq_ren                                  ( cq_ren               ), // i, 1
        .cq_num                                  ( cq_num               ), // i, 32
        .cq_dout                                 ( cq_dout              ), // o, 1
        .eq_ren                                  ( eq_ren               ), // i, 1
        .eq_num                                  ( eq_num               ), // i, 31
        .eq_dout                                 ( eq_dout              ), // o, 1
        .pio_eq_int_req_valid                    ( pio_eq_int_req_valid ), // i, 1
        .pio_eq_int_req_num                      ( pio_eq_int_req_num   ), // i, 6
        .pio_eq_int_req_ready                    ( pio_eq_int_req_ready ), // o, 1
        .pio_eq_int_rsp_valid                    ( pio_eq_int_rsp_valid ), // i, 1
        .pio_eq_int_rsp_data                     ( pio_eq_int_rsp_data  ), // i, 128
        .pio_eq_int_rsp_ready                    ( pio_eq_int_rsp_ready ), // o, 1
        .m_axi_awaddr                            ( m_axi_awaddr         ), // o, AXIL_ADDR_WIDTH
        .m_axi_awvalid                           ( m_axi_awvalid        ), // o, 1
        .m_axi_awready                           ( m_axi_awready        ), // i, 1
        .m_axi_wdata                             ( m_axi_wdata          ), // o, AXIL_DATA_WIDTH
        .m_axi_wstrb                             ( m_axi_wstrb          ), // o, AXIL_STRB_WIDTH
        .m_axi_wvalid                            ( m_axi_wvalid         ), // o, 1
        .m_axi_wready                            ( m_axi_wready         ), // i, 1
        .m_axi_bvalid                            ( m_axi_bvalid         ), // i, 1
        .m_axi_bready                            ( m_axi_bready         ), // o, 1
        .m_axi_araddr                            ( m_axi_araddr         ), // o, AXIL_ADDR_WIDTH
        .m_axi_arvalid                           ( m_axi_arvalid        ), // o, 1
        .m_axi_arready                           ( m_axi_arready        ), // i, 1
        .m_axi_rdata                             ( m_axi_rdata          ), // i, AXIL_DATA_WIDTH
        .m_axi_rvalid                            ( m_axi_rvalid         ), // i, 1
        .m_axi_rready                            ( m_axi_rready         ), // o, 1
        /* --------Interact with Ethernet BAR{end}------- */
        .dma_rd_req_valid ({dma_ceu_rd_req_valid, dma_cm_rd_req_valid, dma_cv2p_mpt_rd_req_valid, dma_cv2p_mtt_rd_req_valid, dma_dv2p_wqe_rd_req_valid, dma_dv2p_rd_req_valid, dma_tx_desc_rd_req_valid, dma_tx_frame_rd_req_valid, dma_rx_desc_rd_req_valid}), // i, `DMA_CHNL_NUM * 1             
        .dma_rd_req_last  ({dma_ceu_rd_req_last , dma_cm_rd_req_last , dma_cv2p_mpt_rd_req_last , dma_cv2p_mtt_rd_req_last , dma_dv2p_wqe_rd_req_last , dma_dv2p_rd_req_last, dma_tx_desc_rd_req_last, dma_tx_frame_rd_req_last, dma_rx_desc_rd_req_last }), // i, `DMA_CHNL_NUM * 1             
        .dma_rd_req_data  ({dma_ceu_rd_req_data , dma_cm_rd_req_data , dma_cv2p_mpt_rd_req_data , dma_cv2p_mtt_rd_req_data , dma_dv2p_wqe_rd_req_data , dma_dv2p_rd_req_data, dma_tx_desc_rd_req_data, dma_tx_frame_rd_req_data, dma_rx_desc_rd_req_data }), // i, `DMA_CHNL_NUM * C_DATA_WIDTH  
        .dma_rd_req_head  ({dma_ceu_rd_req_head , dma_cm_rd_req_head , dma_cv2p_mpt_rd_req_head , dma_cv2p_mtt_rd_req_head , dma_dv2p_wqe_rd_req_head , dma_dv2p_rd_req_head, dma_tx_desc_rd_req_head, dma_tx_frame_rd_req_head, dma_rx_desc_rd_req_head }), // i, `DMA_CHNL_NUM * DMA_HEAD_WIDTH
        .dma_rd_req_ready ({dma_ceu_rd_req_ready, dma_cm_rd_req_ready, dma_cv2p_mpt_rd_req_ready, dma_cv2p_mtt_rd_req_ready, dma_dv2p_wqe_rd_req_ready, dma_dv2p_rd_req_ready, dma_tx_desc_rd_req_ready, dma_tx_frame_rd_req_ready, dma_rx_desc_rd_req_ready}), // o, `DMA_CHNL_NUM * 1             

        // DMA Read Resp
        .dma_rd_rsp_valid ( {dma_ceu_rd_rsp_valid, dma_cm_rd_rsp_valid, dma_cv2p_mpt_rd_rsp_valid, dma_cv2p_mtt_rd_rsp_valid, dma_dv2p_wqe_rd_rsp_valid, dma_dv2p_rd_rsp_valid, dma_tx_desc_rd_rsp_valid, dma_tx_frame_rd_rsp_valid, dma_rx_desc_rd_rsp_valid} ), // o, `DMA_CHNL_NUM * 1             
        .dma_rd_rsp_last  ( {dma_ceu_rd_rsp_last , dma_cm_rd_rsp_last , dma_cv2p_mpt_rd_rsp_last , dma_cv2p_mtt_rd_rsp_last , dma_dv2p_wqe_rd_rsp_last , dma_dv2p_rd_rsp_last, dma_tx_desc_rd_rsp_last, dma_tx_frame_rd_rsp_last, dma_rx_desc_rd_rsp_last } ), // o, `DMA_CHNL_NUM * 1             
        .dma_rd_rsp_data  ( {dma_ceu_rd_rsp_data , dma_cm_rd_rsp_data , dma_cv2p_mpt_rd_rsp_data , dma_cv2p_mtt_rd_rsp_data , dma_dv2p_wqe_rd_rsp_data , dma_dv2p_rd_rsp_data, dma_tx_desc_rd_rsp_data, dma_tx_frame_rd_rsp_data, dma_rx_desc_rd_rsp_data } ), // o, `DMA_CHNL_NUM * C_DATA_WIDTH  
        .dma_rd_rsp_head  ( {dma_ceu_rd_rsp_head , dma_cm_rd_rsp_head , dma_cv2p_mpt_rd_rsp_head , dma_cv2p_mtt_rd_rsp_head , dma_dv2p_wqe_rd_rsp_head , dma_dv2p_rd_rsp_head, dma_tx_desc_rd_rsp_head, dma_tx_frame_rd_rsp_head, dma_rx_desc_rd_rsp_head } ), // o, `DMA_CHNL_NUM * DMA_HEAD_WIDTH
        .dma_rd_rsp_ready ( {dma_ceu_rd_rsp_ready, dma_cm_rd_rsp_ready, dma_cv2p_mpt_rd_rsp_ready, dma_cv2p_mtt_rd_rsp_ready, dma_dv2p_wqe_rd_rsp_ready, dma_dv2p_rd_rsp_ready, dma_tx_desc_rd_rsp_ready, dma_tx_frame_rd_rsp_ready, dma_rx_desc_rd_rsp_ready} ), // i, `DMA_CHNL_NUM * 1             

        // DMA Write Req
        .dma_wr_req_valid ( {dma_ceu_wr_req_valid, dma_cm_wr_req_valid, dma_cv2p_mpt_wr_req_valid, dma_cv2p_mtt_wr_req_valid, dma_dv2p_wr_req_valid, dma_tx_axis_wr_req_valid, dma_rx_axis_wr_req_valid} ), // i, `DMA_CHNL_NUM * 1             
        .dma_wr_req_last  ( {dma_ceu_wr_req_last , dma_cm_wr_req_last , dma_cv2p_mpt_wr_req_last , dma_cv2p_mtt_wr_req_last , dma_dv2p_wr_req_last, dma_tx_axis_wr_req_last, dma_rx_axis_wr_req_last } ), // i, `DMA_CHNL_NUM * 1             
        .dma_wr_req_data  ( {dma_ceu_wr_req_data , dma_cm_wr_req_data , dma_cv2p_mpt_wr_req_data , dma_cv2p_mtt_wr_req_data , dma_dv2p_wr_req_data, dma_tx_axis_wr_req_data, dma_rx_axis_wr_req_data } ), // i, `DMA_CHNL_NUM * C_DATA_WIDTH  
        .dma_wr_req_head  ( {dma_ceu_wr_req_head , dma_cm_wr_req_head , dma_cv2p_mpt_wr_req_head , dma_cv2p_mtt_wr_req_head , dma_dv2p_wr_req_head, dma_tx_axis_wr_req_head, dma_rx_axis_wr_req_head } ), // i, `DMA_CHNL_NUM * DMA_HEAD_WIDTH
        .dma_wr_req_ready ( {dma_ceu_wr_req_ready, dma_cm_wr_req_ready, dma_cv2p_mpt_wr_req_ready, dma_cv2p_mtt_wr_req_ready, dma_dv2p_wr_req_ready, dma_tx_axis_wr_req_ready, dma_rx_axis_wr_req_ready} ), // o, `DMA_CHNL_NUM * 1             
        .p2p_upper_valid ( p2p_tx_valid ), // i, 1             
        .p2p_upper_last  ( p2p_tx_last  ), // i, 1             
        .p2p_upper_data  ( p2p_tx_data  ), // i, P2P_DATA_WIDTH  
        .p2p_upper_head  ( p2p_tx_head  ), // i, UPPER_HEAD_WIDTH
        .p2p_upper_ready ( p2p_tx_ready ), // o, 1        
        .p2p_down_valid  ( p2p_rx_valid ), // o, 1             
        .p2p_down_last   ( p2p_rx_last  ), // o, 1             
        .p2p_down_data   ( p2p_rx_data  ), // o, P2P_DATA_WIDTH  
        .p2p_down_head   ( p2p_rx_head  ), // o, DOWN_HEAD_WIDTH
        .p2p_down_ready  ( p2p_rx_ready )  // i, 1   

		`ifdef PCIEI_APB_DBG   
		,.rw_data(PCIe_Interface_rw_data)//424:0
		,.dbg_sel(host_dbg_sel			)// 'h1000_0000
		,.dbg_bus(PCIe_Interface_dbg_bus)//32 bit 
		`endif
    );


    ProtocolEngine_Top  u_protocol_engine(
        .clk                      ( nic_clk              ),
        .rst_n                    ( ~rst         ),
        .mgmt_clk                 ( nic_clk             ),
        .mgmt_rst_n               ( ~rst        ),
        .ist_mbist_rstn           ( ~rst        ),  
        .ist_mbist_done           (),  
        .ist_mbist_pass           (),  
		
		.o_rdma_init_finish(w_rdma_init_finish),

        //.ib_id                    ( 6'h1                 ),
        .hcr_in_param             ( pio_hcr_in_param     ), // i, 64
        .hcr_in_modifier          ( pio_hcr_in_modifier  ), // i, 32
        .hcr_out_dma_addr         ( pio_hcr_out_dma_addr ), // i, 64
        .hcr_out_param            ( pio_hcr_out_param    ), // o, 64
        .hcr_token                ( {16'd0, pio_hcr_token}),// i, 16
        .hcr_status               ( pio_hcr_status       ), // o, 8
        .hcr_go                   ( pio_hcr_go           ), // i, 1
        .hcr_clear                ( pio_hcr_clear        ), // o, 1
        .hcr_event                ( pio_hcr_event        ), // i, 1
        .hcr_op_modifier          ( pio_hcr_op_modifier  ), // i, 8
        .hcr_op                   ( pio_hcr_op           ), // i, 12
        .uar_db_data_diff         ( pio_uar_db_data      ), // i, 64
        .uar_db_ready_diff        ( pio_uar_db_ready     ), // o, 1
        .uar_db_valid_diff        ( pio_uar_db_valid     ), // i, 1

        /* --------ARM CQ interface{begin}-------- */
        .cq_ren(cq_ren) , // o, 1
        .cq_num(cq_num) , // o, 32
        .cq_dout(cq_dout), // i, 1
        /* --------ARM CQ interface{end}-------- */

        /* --------ARM EQ interface{begin}-------- */
        .eq_ren(eq_ren) , // o, 1
        .eq_num(eq_num) , // o, 32
        .eq_dout(eq_dout), // i, 1
        /* --------ARM EQ interface{end}-------- */

        /* --------Interrupt Vector entry request & response{begin}-------- */
        .pio_eq_int_req_valid(pio_eq_int_req_valid), // o, 1
        .pio_eq_int_req_num(pio_eq_int_req_num), // o, 64
        .pio_eq_int_req_ready(pio_eq_int_req_ready), // i, 1

        .pio_eq_int_rsp_valid(pio_eq_int_rsp_valid), // i, 1
        .pio_eq_int_rsp_data(pio_eq_int_rsp_data), // i, 128
        .pio_eq_int_rsp_ready(pio_eq_int_rsp_ready), // o, 1
        /* -------Interrupt Vector entry request & response{end}-------- */

        // CEU Read Req
        .dma_ceu_rd_req_valid_diff( dma_ceu_rd_req_valid ), // o, 1
        .dma_ceu_rd_req_last_diff ( dma_ceu_rd_req_last  ), // o, 1
        .dma_ceu_rd_req_data_diff ( dma_ceu_rd_req_data  ), // o, C_DATA_WIDTH
        .dma_ceu_rd_req_head_diff ( dma_ceu_rd_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_ceu_rd_req_ready_diff( dma_ceu_rd_req_ready ), // i, 1
        // CEU DMA Read Resp
        .dma_ceu_rd_rsp_valid_diff( dma_ceu_rd_rsp_valid ), // i, 1
        .dma_ceu_rd_rsp_last_diff ( dma_ceu_rd_rsp_last  ), // i, 1
        .dma_ceu_rd_rsp_data_diff ( dma_ceu_rd_rsp_data  ), // i, C_DATA_WIDTH
        .dma_ceu_rd_rsp_head_diff ( dma_ceu_rd_rsp_head  ), // i, DMA_HEAD_WIDTH
        .dma_ceu_rd_rsp_ready_diff( dma_ceu_rd_rsp_ready ), // o, 1
        // CEU DMA Write Req
        .dma_ceu_wr_req_valid_diff( dma_ceu_wr_req_valid ), // o, 1
        .dma_ceu_wr_req_last_diff ( dma_ceu_wr_req_last  ), // o, 1
        .dma_ceu_wr_req_data_diff ( dma_ceu_wr_req_data  ), // o, C_DATA_WIDTH
        .dma_ceu_wr_req_head_diff ( dma_ceu_wr_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_ceu_wr_req_ready_diff( dma_ceu_wr_req_ready ), // i, 1
        // Context Management DMA Read Request
        .dma_cm_rd_req_valid_diff ( dma_cm_rd_req_valid  ), // o, 1
        .dma_cm_rd_req_last_diff  ( dma_cm_rd_req_last   ), // o, 1
        .dma_cm_rd_req_data_diff  ( dma_cm_rd_req_data   ), // o, C_DATA_WIDTH
        .dma_cm_rd_req_head_diff  ( dma_cm_rd_req_head   ), // o, DMA_HEAD_WIDTH
        .dma_cm_rd_req_ready_diff ( dma_cm_rd_req_ready  ), // i, 1
        // Context Management DMA Read Response
        .dma_cm_rd_rsp_valid_diff ( dma_cm_rd_rsp_valid  ), // o, 1
        .dma_cm_rd_rsp_last_diff  ( dma_cm_rd_rsp_last   ), // o, 1
        .dma_cm_rd_rsp_data_diff  ( dma_cm_rd_rsp_data   ), // o, C_DATA_WIDTH
        .dma_cm_rd_rsp_head_diff  ( dma_cm_rd_rsp_head   ), // o, DMA_HEAD_WIDTH
        .dma_cm_rd_rsp_ready_diff ( dma_cm_rd_rsp_ready  ), // i, 1
        // Context Management DMA Write Request
        .dma_cm_wr_req_valid_diff ( dma_cm_wr_req_valid  ), // o, 1
        .dma_cm_wr_req_last_diff  ( dma_cm_wr_req_last   ), // o, 1
        .dma_cm_wr_req_data_diff  ( dma_cm_wr_req_data   ), // o, C_DATA_WIDTH
        .dma_cm_wr_req_head_diff  ( dma_cm_wr_req_head   ), // o, DMA_HEAD_WIDTH
        .dma_cm_wr_req_ready_diff ( dma_cm_wr_req_ready  ), // i, 1
        // Virtual to Physical DMA Context Read Request(MPT)
        .dma_cv2p_mpt_rd_req_valid_diff( dma_cv2p_mpt_rd_req_valid ), // o, 1
        .dma_cv2p_mpt_rd_req_last_diff ( dma_cv2p_mpt_rd_req_last  ), // o, 1
        .dma_cv2p_mpt_rd_req_data_diff ( dma_cv2p_mpt_rd_req_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mpt_rd_req_head_diff ( dma_cv2p_mpt_rd_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mpt_rd_req_ready_diff( dma_cv2p_mpt_rd_req_ready ), // i, 1
        // Virtual to Physical DMA Context Read Response
        .dma_cv2p_mpt_rd_rsp_valid_diff( dma_cv2p_mpt_rd_rsp_valid ), // o, 1
        .dma_cv2p_mpt_rd_rsp_last_diff ( dma_cv2p_mpt_rd_rsp_last  ), // o, 1
        .dma_cv2p_mpt_rd_rsp_data_diff ( dma_cv2p_mpt_rd_rsp_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mpt_rd_rsp_head_diff ( dma_cv2p_mpt_rd_rsp_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mpt_rd_rsp_ready_diff( dma_cv2p_mpt_rd_rsp_ready ), // i, 1
        // Virtual to Physical DMA Context Write Request
        .dma_cv2p_mpt_wr_req_valid_diff( dma_cv2p_mpt_wr_req_valid ), // o, 1
        .dma_cv2p_mpt_wr_req_last_diff ( dma_cv2p_mpt_wr_req_last  ), // o, 1
        .dma_cv2p_mpt_wr_req_data_diff ( dma_cv2p_mpt_wr_req_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mpt_wr_req_head_diff ( dma_cv2p_mpt_wr_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mpt_wr_req_ready_diff( dma_cv2p_mpt_wr_req_ready ), // i, 1

        .dma_cv2p_mtt_rd_req_valid_diff( dma_cv2p_mtt_rd_req_valid ), // o, 1
        .dma_cv2p_mtt_rd_req_last_diff ( dma_cv2p_mtt_rd_req_last  ), // o, 1
        .dma_cv2p_mtt_rd_req_data_diff ( dma_cv2p_mtt_rd_req_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mtt_rd_req_head_diff ( dma_cv2p_mtt_rd_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mtt_rd_req_ready_diff( dma_cv2p_mtt_rd_req_ready ), // i, 1
        // Virtual to Physical DMA Context Read Response
        .dma_cv2p_mtt_rd_rsp_valid_diff( dma_cv2p_mtt_rd_rsp_valid ), // o, 1
        .dma_cv2p_mtt_rd_rsp_last_diff ( dma_cv2p_mtt_rd_rsp_last  ), // o, 1
        .dma_cv2p_mtt_rd_rsp_data_diff ( dma_cv2p_mtt_rd_rsp_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mtt_rd_rsp_head_diff ( dma_cv2p_mtt_rd_rsp_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mtt_rd_rsp_ready_diff( dma_cv2p_mtt_rd_rsp_ready ), // i, 1
        // Virtual to Physical DMA Context Write Request
        .dma_cv2p_mtt_wr_req_valid_diff( dma_cv2p_mtt_wr_req_valid ), // o, 1
        .dma_cv2p_mtt_wr_req_last_diff ( dma_cv2p_mtt_wr_req_last  ), // o, 1
        .dma_cv2p_mtt_wr_req_data_diff ( dma_cv2p_mtt_wr_req_data  ), // o, C_DATA_WIDTH
        .dma_cv2p_mtt_wr_req_head_diff ( dma_cv2p_mtt_wr_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_cv2p_mtt_wr_req_ready_diff( dma_cv2p_mtt_wr_req_ready ), // i, 1
        // Virtual to Physical DMA Data Read Request
        .dma_dv2p_dt_rd_req_valid_diff( dma_dv2p_rd_req_valid ), // o, 1
        .dma_dv2p_dt_rd_req_last_diff ( dma_dv2p_rd_req_last  ), // o, 1
        .dma_dv2p_dt_rd_req_data_diff ( dma_dv2p_rd_req_data  ), // o, C_DATA_WIDTH
        .dma_dv2p_dt_rd_req_head_diff ( dma_dv2p_rd_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_dv2p_dt_rd_req_ready_diff( dma_dv2p_rd_req_ready ), // i, 1
        // Virtual to Physical DMA Data Read Response
        .dma_dv2p_dt_rd_rsp_valid_diff( dma_dv2p_rd_rsp_valid ), // o, 1
        .dma_dv2p_dt_rd_rsp_last_diff ( dma_dv2p_rd_rsp_last  ), // o, 1
        .dma_dv2p_dt_rd_rsp_data_diff ( dma_dv2p_rd_rsp_data  ), // o, C_DATA_WIDTH
        .dma_dv2p_dt_rd_rsp_head_diff ( dma_dv2p_rd_rsp_head  ), // o, DMA_HEAD_WIDTH
        .dma_dv2p_dt_rd_rsp_ready_diff( dma_dv2p_rd_rsp_ready ), // i, 1
        // Virtual to Physical DMA Data Write Request
        .dma_dv2p_dt_wr_req_valid_diff( dma_dv2p_wr_req_valid ), // o, 1
        .dma_dv2p_dt_wr_req_last_diff ( dma_dv2p_wr_req_last  ), // o, 1
        .dma_dv2p_dt_wr_req_data_diff ( dma_dv2p_wr_req_data  ), // o, C_DATA_WIDTH
        .dma_dv2p_dt_wr_req_head_diff ( dma_dv2p_wr_req_head  ), // o, DMA_HEAD_WIDTH
        .dma_dv2p_dt_wr_req_ready_diff( dma_dv2p_wr_req_ready ) , // i, 1
        // ADD 1 DMA read and response channel for v2p read RQ WQE
        // Virtual to Physical DMA RQ WQE Read Request
        .dma_dv2p_wqe_rd_req_valid_diff(dma_dv2p_wqe_rd_req_valid),//output  wire                       
        .dma_dv2p_wqe_rd_req_last_diff (dma_dv2p_wqe_rd_req_last ),//output  wire                       
        .dma_dv2p_wqe_rd_req_data_diff (dma_dv2p_wqe_rd_req_data ),//output  wire [(C_DATA_WIDTH-1)  :0]
        .dma_dv2p_wqe_rd_req_head_diff (dma_dv2p_wqe_rd_req_head ),//output  wire [(DMA_HEAD_WIDTH-1):0]
        .dma_dv2p_wqe_rd_req_ready_diff(dma_dv2p_wqe_rd_req_ready),//input   wire                       
        // Virtual to Physical DMA RQ WQE  Read Response
        .dma_dv2p_wqe_rd_rsp_valid_diff(dma_dv2p_wqe_rd_rsp_valid),//input   wire                        ,
        .dma_dv2p_wqe_rd_rsp_last_diff (dma_dv2p_wqe_rd_rsp_last) ,//input   wire                        ,
        .dma_dv2p_wqe_rd_rsp_data_diff (dma_dv2p_wqe_rd_rsp_data) ,//input   wire [(C_DATA_WIDTH-1)  :0] ,
        .dma_dv2p_wqe_rd_rsp_head_diff (dma_dv2p_wqe_rd_rsp_head) ,//input   wire [(DMA_HEAD_WIDTH-1):0] ,
        .dma_dv2p_wqe_rd_rsp_ready_diff(dma_dv2p_wqe_rd_rsp_ready),//output  wire                        ,

        /*-------------------------------------------eth_engine_top interface--------------------------------------------*/
        /* to dma module, to get the desc */
        .rx_desc_dma_req_valid_diff    (dma_rx_desc_rd_req_valid ),
        .rx_desc_dma_req_last_diff     (dma_rx_desc_rd_req_last  ),
        .rx_desc_dma_req_data_diff     (dma_rx_desc_rd_req_data  ),
        .rx_desc_dma_req_head_diff     (dma_rx_desc_rd_req_head  ),
        .rx_desc_dma_req_ready_diff    (dma_rx_desc_rd_req_ready ),
        .rx_desc_dma_rsp_valid_diff    (dma_rx_desc_rd_rsp_valid ),
        .rx_desc_dma_rsp_last_diff     (dma_rx_desc_rd_rsp_last  ),
        .rx_desc_dma_rsp_data_diff     (dma_rx_desc_rd_rsp_data  ),
        .rx_desc_dma_rsp_head_diff     (dma_rx_desc_rd_rsp_head  ),
        .rx_desc_dma_rsp_ready_diff    (dma_rx_desc_rd_rsp_ready ),
        /* -------to dma module , to write the frame{begin}------- */
        .rx_axis_wr_valid_diff         (dma_rx_axis_wr_req_valid ),
        .rx_axis_wr_last_diff          (dma_rx_axis_wr_req_last  ),
        .rx_axis_wr_data_diff          (dma_rx_axis_wr_req_data  ),
        .rx_axis_wr_head_diff          (dma_rx_axis_wr_req_head  ),
        .rx_axis_wr_ready_diff         (dma_rx_axis_wr_req_ready ),
        /* to dma module, to get the desc */
        .tx_desc_dma_req_valid_diff    (dma_tx_desc_rd_req_valid),
        .tx_desc_dma_req_last_diff     (dma_tx_desc_rd_req_last),
        .tx_desc_dma_req_data_diff     (dma_tx_desc_rd_req_data),
        .tx_desc_dma_req_head_diff     (dma_tx_desc_rd_req_head),
        .tx_desc_dma_req_ready_diff    (dma_tx_desc_rd_req_ready),
        /* to dma module, to get the desc */
        .tx_desc_dma_rsp_valid_diff    (dma_tx_desc_rd_rsp_valid),
        .tx_desc_dma_rsp_data_diff     (dma_tx_desc_rd_rsp_data),
        .tx_desc_dma_rsp_head_diff     (dma_tx_desc_rd_rsp_head),
        .tx_desc_dma_rsp_last_diff     (dma_tx_desc_rd_rsp_last),
        .tx_desc_dma_rsp_ready_diff    (dma_tx_desc_rd_rsp_ready),
        /* to dma module, to get the frame */
        .tx_frame_req_valid_diff       (dma_tx_frame_rd_req_valid),
        .tx_frame_req_last_diff        (dma_tx_frame_rd_req_last),
        .tx_frame_req_data_diff        (dma_tx_frame_rd_req_data),
        .tx_frame_req_head_diff        (dma_tx_frame_rd_req_head),
        .tx_frame_req_ready_diff       (dma_tx_frame_rd_req_ready),
        /* interface to dma */
        .tx_frame_rsp_valid_diff       (dma_tx_frame_rd_rsp_valid),
        .tx_frame_rsp_data_diff        (dma_tx_frame_rd_rsp_data),
        .tx_frame_rsp_head_diff        (dma_tx_frame_rd_rsp_head),
        .tx_frame_rsp_last_diff        (dma_tx_frame_rd_rsp_last),
        .tx_frame_rsp_ready_diff       (dma_tx_frame_rd_rsp_ready),
        /* completion data dma interface */
        .tx_axis_wr_valid_diff         (dma_tx_axis_wr_req_valid),
        .tx_axis_wr_data_diff          (dma_tx_axis_wr_req_data),
        .tx_axis_wr_head_diff          (dma_tx_axis_wr_req_head),
        .tx_axis_wr_last_diff          (dma_tx_axis_wr_req_last),
        .tx_axis_wr_ready_diff         (dma_tx_axis_wr_req_ready),
        // Write Address Channel from Master 1
        .awvalid_m  (m_axi_awvalid),
        .awaddr_m   (m_axi_awaddr),
        .awready_m  (m_axi_awready),
        // Write Data Channel from Master 1
        .wvalid_m(m_axi_wvalid),
        .wdata_m (m_axi_wdata),
        .wstrb_m (m_axi_wstrb),
        .wready_m(m_axi_wready),
        // Write Response Channel from Master 1
        .bvalid_m(m_axi_bvalid),
        .bready_m(m_axi_bready),
        // Read Address Channel from Master 1
        .arvalid_m(m_axi_arvalid),
        .araddr_m (m_axi_araddr),
        .arready_m(m_axi_arready),
        // Read Data Channel from Master 1
        .rvalid_m(m_axi_rvalid),
        .rdata_m(m_axi_rdata),
        .rready_m(m_axi_rready),
        //HostRoute_Top interface
        .p2p_tx_valid_diff(p2p_tx_valid),     
        .p2p_tx_last_diff (p2p_tx_last ),     
        .p2p_tx_data_diff (p2p_tx_data ), 
        .p2p_tx_head_diff (p2p_tx_head ), 
        .p2p_tx_ready_diff(p2p_tx_ready), 
     
        .p2p_rx_valid_diff(p2p_rx_valid),     
        .p2p_rx_last_diff (p2p_rx_last ),     
        .p2p_rx_data_diff (p2p_rx_data ), 
        .p2p_rx_head_diff (p2p_rx_head ), 
        .p2p_rx_ready_diff(p2p_rx_ready), 
    /* --------p2p forward down channel{end}-------- */
        .cfg_pkt_in       (cfg_pkt_0),
        .cfg_pkt_in_vld   (cfg_pkt_vld_0),
        .cfg_pkt_in_rdy   (cfg_pkt_rdy_0),
        .cfg_pkt_out      (cfg_pkt_1),
        .cfg_pkt_out_vld  (cfg_pkt_vld_1),
        .cfg_pkt_out_rdy  (cfg_pkt_rdy_1),
    //HPC Traffic in
        .i_link_hpc_rx_pkt_valid_diff(nic_link_hpc_rx_pkt_valid),
        .i_link_hpc_rx_pkt_start_diff(nic_link_hpc_rx_pkt_start),
        .i_link_hpc_rx_pkt_end_diff  (nic_link_hpc_rx_pkt_end  ),
        .iv_link_hpc_rx_pkt_user_diff(nic_link_hpc_rx_pkt_user),
        .iv_link_hpc_rx_pkt_keep_diff(nic_link_hpc_rx_pkt_keep),
        .iv_link_hpc_rx_pkt_data_diff(nic_link_hpc_rx_pkt_data),		
        .o_link_hpc_rx_pkt_ready_diff(nic_link_hpc_rx_pkt_ready),
    //ETH Traffic in、			
        .i_link_eth_rx_pkt_valid_diff(nic_link_eth_rx_pkt_valid), 
        .i_link_eth_rx_pkt_start_diff(nic_link_eth_rx_pkt_start), 
        .i_link_eth_rx_pkt_end_diff  (nic_link_eth_rx_pkt_end  ), 
        .iv_link_eth_rx_pkt_user_diff(nic_link_eth_rx_pkt_user),  
        .iv_link_eth_rx_pkt_keep_diff(nic_link_eth_rx_pkt_keep),  
        .iv_link_eth_rx_pkt_data_diff(nic_link_eth_rx_pkt_data),  
        .o_link_eth_rx_pkt_ready_diff(nic_link_eth_rx_pkt_ready), 
    //HPC Traffic out
        .o_link_hpc_tx_pkt_valid_diff(nic_link_hpc_tx_pkt_valid),
        .o_link_hpc_tx_pkt_start_diff(nic_link_hpc_tx_pkt_start),
        .o_link_hpc_tx_pkt_end_diff  (nic_link_hpc_tx_pkt_end  ),
        .ov_link_hpc_tx_pkt_user_diff(nic_link_hpc_tx_pkt_user),
        .ov_link_hpc_tx_pkt_keep_diff(nic_link_hpc_tx_pkt_keep),
        .ov_link_hpc_tx_pkt_data_diff(nic_link_hpc_tx_pkt_data),		
        .i_link_hpc_tx_pkt_ready_diff(nic_link_hpc_tx_pkt_ready),
    //ETH Traffic out、			
        .o_link_eth_tx_pkt_valid_diff(nic_link_eth_tx_pkt_valid),
        .o_link_eth_tx_pkt_start_diff(nic_link_eth_tx_pkt_start),
        .o_link_eth_tx_pkt_end_diff  (nic_link_eth_tx_pkt_end  ),
        .ov_link_eth_tx_pkt_user_diff(nic_link_eth_tx_pkt_user),
        .ov_link_eth_tx_pkt_keep_diff(nic_link_eth_tx_pkt_keep),
        .ov_link_eth_tx_pkt_data_diff(nic_link_eth_tx_pkt_data),
        .i_link_eth_tx_pkt_ready_diff(nic_link_eth_tx_pkt_ready)
    );
endmodule