/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RequesterCore
Author:     YangFan
Function:   1.Deal with RDMA Semantics.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RDMACore
#(
    parameter                       INGRESS_CXT_HEAD_WIDTH                  =   128,
    parameter                       INGRESS_CXT_DATA_WIDTH                  =   256,
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256,

    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256,
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

/*************************** Interface with QueueSubsystem ****************************************/
//TX : SQ Interface
    input   wire                                                            TX_REQ_sub_wqe_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               TX_REQ_sub_wqe_meta,
    output  wire                                                            TX_REQ_sub_wqe_ready,

//TX : SCQ Interface
    output  wire                                                            TX_REQ_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_cq_req_head,
    input   wire                                                            TX_REQ_cq_req_ready,
     
    input   wire                                                            TX_REQ_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_cq_resp_head,
    output  wire                                                            TX_REQ_cq_resp_ready,

//TX : EQ Interface
    output  wire                                                            TX_REQ_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_eq_req_head,
    input   wire                                                            TX_REQ_eq_req_ready,
 
    input   wire                                                            TX_REQ_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_eq_resp_head,
    output  wire                                                            TX_REQ_eq_resp_ready,

//RX : RQ Interface
    output  wire                                                            RQ_wqe_req_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_req_head,
    output  wire                                                            RQ_wqe_req_start,
    output  wire                                                            RQ_wqe_req_last,
    input   wire                                                            RQ_wqe_req_ready,

    input   wire                                                            RQ_wqe_resp_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_resp_head,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                RQ_wqe_resp_data,
    input   wire                                                            RQ_wqe_resp_start,
    input   wire                                                            RQ_wqe_resp_last,
    output  wire                                                            RQ_wqe_resp_ready,

    output  wire                                                            RQ_cache_offset_wen,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_offset_addr,
    output  wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_din,
    input   wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_dout,

    output  wire                                                            RQ_offset_wen,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_offset_addr,
    output  wire    [23:0]                                                  RQ_offset_din,
    input   wire    [23:0]                                                  RQ_offset_dout,

    output  wire                                                            RQ_cache_owned_wen,
    output  wire    [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        RQ_cache_owned_addr,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_din,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_dout,

//RX : RCQ Interface
    output  wire                                                            RX_REQ_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_cq_req_head,
    input   wire                                                            RX_REQ_cq_req_ready,
     
    input   wire                                                            RX_REQ_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_cq_resp_head,
    output  wire                                                            RX_REQ_cq_resp_ready,

//RX : EQ Interface
    output  wire                                                            RX_REQ_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_eq_req_head,
    input   wire                                                            RX_REQ_eq_req_ready,
 
    input   wire                                                            RX_REQ_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_eq_resp_head,
    output  wire                                                            RX_REQ_eq_resp_ready,

//RX : SCQ Interface
    output  wire                                                            RX_RESP_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_cq_req_head,
    input   wire                                                            RX_RESP_cq_req_ready,
     
    input   wire                                                            RX_RESP_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_cq_resp_head,
    output  wire                                                            RX_RESP_cq_resp_ready,

//RX : EQ Interface
    output  wire                                                            RX_RESP_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_eq_req_head,
    input   wire                                                            RX_RESP_eq_req_ready,
 
    input   wire                                                            RX_RESP_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_eq_resp_head,
    output  wire                                                            RX_RESP_eq_resp_ready,

/*************************** Interface with ICMMgt(CxtMgt) ****************************************/
//TX : Cxt for transmit REQ
    output  wire                                                            TX_REQ_fetch_cxt_ingress_valid,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            TX_REQ_fetch_cxt_ingress_head,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            TX_REQ_fetch_cxt_ingress_data,
    output  wire                                                            TX_REQ_fetch_cxt_ingress_start,
    output  wire                                                            TX_REQ_fetch_cxt_ingress_last,
    input   wire                                                            TX_REQ_fetch_cxt_ingress_ready,

    input   wire                                                            TX_REQ_fetch_cxt_egress_valid,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             TX_REQ_fetch_cxt_egress_head,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             TX_REQ_fetch_cxt_egress_data,
    input   wire                                                            TX_REQ_fetch_cxt_egress_start,
    input   wire                                                            TX_REQ_fetch_cxt_egress_last,
    output  wire                                                            TX_REQ_fetch_cxt_egress_ready,

//RX : Cxt for receive REQ
    output  wire                                                            RX_REQ_fetch_cxt_ingress_valid,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_head,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_data,
    output  wire                                                            RX_REQ_fetch_cxt_ingress_start,
    output  wire                                                            RX_REQ_fetch_cxt_ingress_last,
    input   wire                                                            RX_REQ_fetch_cxt_ingress_ready,

    input   wire                                                            RX_REQ_fetch_cxt_egress_valid,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_head,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_data,
    input   wire                                                            RX_REQ_fetch_cxt_egress_start,
    input   wire                                                            RX_REQ_fetch_cxt_egress_last,
    output  wire                                                            RX_REQ_fetch_cxt_egress_ready,

//RX : Cxt for receive RESP
    output  wire                                                        RX_RESP_fetch_cxt_ingress_valid,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]       RX_RESP_fetch_cxt_ingress_head,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]       RX_RESP_fetch_cxt_ingress_data,
    output  wire                                                        RX_RESP_fetch_cxt_ingress_start,
    output  wire                                                        RX_RESP_fetch_cxt_ingress_last,
    input   wire                                                        RX_RESP_fetch_cxt_ingress_ready,

    input   wire                                                        RX_RESP_fetch_cxt_egress_valid,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]        RX_RESP_fetch_cxt_egress_head,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]        RX_RESP_fetch_cxt_egress_data,
    input   wire                                                        RX_RESP_fetch_cxt_egress_start,
    input   wire                                                        RX_RESP_fetch_cxt_egress_last,
    output  wire                                                        RX_RESP_fetch_cxt_egress_ready,

/*************************** Interface with ICMMgt(MRMgt) ****************************************/
//TX : Cxt for transmit REQ
    output  wire                                                            TX_REQ_fetch_mr_ingress_valid,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             TX_REQ_fetch_mr_ingress_head,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             TX_REQ_fetch_mr_ingress_data,
    output  wire                                                            TX_REQ_fetch_mr_ingress_start,
    output  wire                                                            TX_REQ_fetch_mr_ingress_last,
    input   wire                                                            TX_REQ_fetch_mr_ingress_ready,

    input   wire                                                            TX_REQ_fetch_mr_egress_valid,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              TX_REQ_fetch_mr_egress_head,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              TX_REQ_fetch_mr_egress_data,
    input   wire                                                            TX_REQ_fetch_mr_egress_start,
    input   wire                                                            TX_REQ_fetch_mr_egress_last,
    output  wire                                                            TX_REQ_fetch_mr_egress_ready,

//RX : Cxt for receive REQ
    output  wire                                                        RX_RESP_fetch_mr_ingress_valid,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]        RX_RESP_fetch_mr_ingress_head,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]        RX_RESP_fetch_mr_ingress_data,
    output  wire                                                        RX_RESP_fetch_mr_ingress_start,
    output  wire                                                        RX_RESP_fetch_mr_ingress_last,
    input   wire                                                        RX_RESP_fetch_mr_ingress_ready,

    input   wire                                                        RX_RESP_fetch_mr_egress_valid,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]         RX_RESP_fetch_mr_egress_head,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]         RX_RESP_fetch_mr_egress_data,
    input   wire                                                        RX_RESP_fetch_mr_egress_start,
    input   wire                                                        RX_RESP_fetch_mr_egress_last,
    output  wire                                                        RX_RESP_fetch_mr_egress_ready,

//RX : Cxt for receive RESP
    output  wire                                                                RX_REQ_fetch_mr_ingress_valid,
    output  wire        [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_head,
    output  wire        [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_data,
    output  wire                                                                RX_REQ_fetch_mr_ingress_start,
    output  wire                                                                RX_REQ_fetch_mr_ingress_last,
    input   wire                                                                RX_REQ_fetch_mr_ingress_ready,

    input   wire                                                                RX_REQ_fetch_mr_egress_valid,
    input   wire        [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_head,
    input   wire        [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_data,
    input   wire                                                                RX_REQ_fetch_mr_egress_start,
    input   wire                                                                RX_REQ_fetch_mr_egress_last,
    output  wire                                                                RX_REQ_fetch_mr_egress_ready,

/*************************** Interface with DMASubsystem **********************************************/
    output  wire                                                            TX_REQ_dma_wr_req_valid,
    output  wire                                                            TX_REQ_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               TX_REQ_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_dma_wr_req_data,
    input   wire                                                            TX_REQ_dma_wr_req_ready,

    output  wire                                                            RX_REQ_dma_wr_req_valid,
    output  wire                                                            RX_REQ_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               RX_REQ_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               RX_REQ_dma_wr_req_data,
    input   wire                                                            RX_REQ_dma_wr_req_ready,

    output  wire                                                            RX_RESP_dma_wr_req_valid,
    output  wire                                                            RX_RESP_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               RX_RESP_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               RX_RESP_dma_wr_req_data,
    input   wire                                                            RX_RESP_dma_wr_req_ready,

    output  wire                                                            TX_REQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               TX_REQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_dma_rd_req_data,
    output  wire                                                            TX_REQ_dma_rd_req_last,
    input   wire                                                            TX_REQ_dma_rd_req_ready,
    
    input   wire                                                            TX_REQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               TX_REQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_dma_rd_rsp_data,
    input   wire                                                            TX_REQ_dma_rd_rsp_last,
    output  wire                                                            TX_REQ_dma_rd_rsp_ready,

    output  wire                                                            TX_RESP_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               TX_RESP_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_RESP_dma_rd_req_data,
    output  wire                                                            TX_RESP_dma_rd_req_last,
    input   wire                                                            TX_RESP_dma_rd_req_ready,
    
    input   wire                                                            TX_RESP_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               TX_RESP_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_RESP_dma_rd_rsp_data,
    input   wire                                                            TX_RESP_dma_rd_rsp_last,
    output  wire                                                            TX_RESP_dma_rd_rsp_ready,
/*************************** Interface with TransportSubsystem ****************************************/
//TX : Inject pkt header
    output  wire                                                            TX_egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_egress_pkt_head,
    input   wire                                                            TX_egress_pkt_ready,

//TX : Insert REQ payload
    output  wire                                                            TX_insert_req_valid,
    output  wire                                                            TX_insert_req_start,
    output  wire                                                            TX_insert_req_last,
    output  wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_insert_req_data,
    input   wire                                                            TX_insert_req_ready,

    input   wire                                                            TX_insert_resp_valid,
    input   wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_insert_resp_data,

//RX Interfaces
    input   wire                                                            RX_ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_ingress_pkt_head,
    output  wire                                                            RX_ingress_pkt_ready,

//RX : Delete REQ payload
    output  wire                                                            RX_delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      RX_delete_req_head,
    input   wire                                                            RX_delete_req_ready,
                    
    input   wire                                                            RX_delete_resp_valid,
    input   wire                                                            RX_delete_resp_start,
    input   wire                                                            RX_delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_delete_resp_data,
    output  wire                                                            RX_delete_resp_ready

);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            TX_REQ_gather_req_wr_en;
wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      TX_REQ_gather_req_din;
wire                                                            TX_REQ_gather_req_prog_full;

wire                                                            TX_REQ_net_data_rd_en;
wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_net_data_dout;
wire                                                            TX_REQ_net_data_empty;

wire                                                            TX_RESP_gather_req_wr_en;
wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      TX_RESP_gather_req_din;
wire                                                            TX_RESP_gather_req_prog_full;

wire                                                            TX_RESP_payload_empty;
wire    [511:0]                                                 TX_RESP_payload_dout;
wire                                                            TX_RESP_payload_rd_en;

wire                                                            TX_REQ_scatter_req_wr_en;
wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      TX_REQ_scatter_req_din;
wire                                                            TX_REQ_scatter_req_prog_full;

wire                                                            TX_REQ_scatter_data_wr_en;
wire     [`DMA_DATA_WIDTH - 1 : 0]                              TX_REQ_scatter_data_din;
wire                                                            TX_REQ_scatter_data_prog_full;

wire                                                            RX_REQ_scatter_req_wr_en;
wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      RX_REQ_scatter_req_din;
wire                                                            RX_REQ_scatter_req_prog_full;

wire                                                            RX_REQ_scatter_data_wr_en;
wire     [`DMA_DATA_WIDTH - 1: 0]                               RX_REQ_scatter_data_din;
wire                                                            RX_REQ_scatter_data_prog_full;

wire                                                            RX_RESP_scatter_req_wr_en;
wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      RX_RESP_scatter_req_din;
wire                                                            RX_RESP_scatter_req_prog_full;

wire                                                            RX_RESP_scatter_data_wr_en;
wire     [`DMA_DATA_WIDTH - 1 : 0]                              RX_RESP_scatter_data_din;
wire                                                            RX_RESP_scatter_data_prog_full;

wire                                                            TX_REQ_insert_req_valid;
wire                                                            TX_REQ_insert_req_start;
wire                                                            TX_REQ_insert_req_last;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_REQ_insert_req_head;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_REQ_insert_req_data;
wire                                                            TX_REQ_insert_req_ready;

wire                                                            TX_REQ_insert_resp_valid;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_REQ_insert_resp_data;

wire                                                            TX_RESP_insert_req_valid;
wire                                                            TX_RESP_insert_req_start;
wire                                                            TX_RESP_insert_req_last;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_RESP_insert_req_head;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_RESP_insert_req_data;
wire                                                            TX_RESP_insert_req_ready;

wire                                                            TX_RESP_insert_resp_valid;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_RESP_insert_resp_data;

wire                                                            RX_REQ_delete_req_valid;
wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      RX_REQ_delete_req_head;
wire                                                            RX_REQ_delete_req_ready;

wire                                                            RX_REQ_delete_resp_valid;
wire                                                            RX_REQ_delete_resp_start;
wire                                                            RX_REQ_delete_resp_last;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_REQ_delete_resp_data;
wire                                                            RX_REQ_delete_resp_ready;

wire                                                            RX_RESP_delete_req_valid;
wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      RX_RESP_delete_req_head;
wire                                                            RX_RESP_delete_req_ready;

wire                                                            RX_RESP_delete_resp_valid;
wire                                                            RX_RESP_delete_resp_start;
wire                                                            RX_RESP_delete_resp_last;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_RESP_delete_resp_data;
wire                                                            RX_RESP_delete_resp_ready;

wire                                                            RX_REQ_ingress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_REQ_ingress_pkt_head;
wire                                                            RX_REQ_ingress_pkt_ready;

wire                                                            RX_RESP_ingress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_RESP_ingress_pkt_head;
wire                                                            RX_RESP_ingress_pkt_ready;

wire                                                            TX_REQ_egress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_REQ_egress_pkt_head;
wire                                                            TX_REQ_egress_pkt_ready;

wire                                                            TX_RESP_egress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_RESP_egress_pkt_head;
wire                                                            TX_RESP_egress_pkt_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
RequesterCore
#(
    .INGRESS_CXT_HEAD_WIDTH                 (       INGRESS_CXT_HEAD_WIDTH          ),
    .INGRESS_CXT_DATA_WIDTH                 (       INGRESS_CXT_DATA_WIDTH          ),
    .EGRESS_CXT_HEAD_WIDTH                  (       EGRESS_CXT_HEAD_WIDTH           ),
    .EGRESS_CXT_DATA_WIDTH                  (       EGRESS_CXT_DATA_WIDTH           ),


    .INGRESS_MR_HEAD_WIDTH                  (       INGRESS_MR_HEAD_WIDTH           ),
    .INGRESS_MR_DATA_WIDTH                  (       INGRESS_MR_DATA_WIDTH           ),
    .EGRESS_MR_HEAD_WIDTH                   (       EGRESS_MR_HEAD_WIDTH            ),
    .EGRESS_MR_DATA_WIDTH                   (       EGRESS_MR_DATA_WIDTH            )
)
RequesterCore_Inst
(
    .clk                                    (           clk         ),
    .rst                                    (           rst         ),

    .TX_REQ_sub_wqe_valid                   (           TX_REQ_sub_wqe_valid                        ),
    .TX_REQ_sub_wqe_meta                    (           TX_REQ_sub_wqe_meta                         ),
    .TX_REQ_sub_wqe_ready                   (           TX_REQ_sub_wqe_ready                        ),

    .TX_REQ_fetch_cxt_ingress_valid         (           TX_REQ_fetch_cxt_ingress_valid              ),
    .TX_REQ_fetch_cxt_ingress_head          (           TX_REQ_fetch_cxt_ingress_head               ),
    .TX_REQ_fetch_cxt_ingress_data          (           TX_REQ_fetch_cxt_ingress_data               ),
    .TX_REQ_fetch_cxt_ingress_start         (           TX_REQ_fetch_cxt_ingress_start              ),
    .TX_REQ_fetch_cxt_ingress_last          (           TX_REQ_fetch_cxt_ingress_last               ),
    .TX_REQ_fetch_cxt_ingress_ready         (           TX_REQ_fetch_cxt_ingress_ready              ),
    
    .TX_REQ_fetch_cxt_egress_valid          (           TX_REQ_fetch_cxt_egress_valid               ),
    .TX_REQ_fetch_cxt_egress_head           (           TX_REQ_fetch_cxt_egress_head                ),
    .TX_REQ_fetch_cxt_egress_data           (           TX_REQ_fetch_cxt_egress_data                ),
    .TX_REQ_fetch_cxt_egress_start          (           TX_REQ_fetch_cxt_egress_start               ),
    .TX_REQ_fetch_cxt_egress_last           (           TX_REQ_fetch_cxt_egress_last                ),
    .TX_REQ_fetch_cxt_egress_ready          (           TX_REQ_fetch_cxt_egress_ready               ),

    .TX_REQ_fetch_mr_ingress_valid          (           TX_REQ_fetch_mr_ingress_valid               ),
    .TX_REQ_fetch_mr_ingress_head           (           TX_REQ_fetch_mr_ingress_head                ),
    .TX_REQ_fetch_mr_ingress_data           (           TX_REQ_fetch_mr_ingress_data                ),
    .TX_REQ_fetch_mr_ingress_start          (           TX_REQ_fetch_mr_ingress_start               ),
    .TX_REQ_fetch_mr_ingress_last           (           TX_REQ_fetch_mr_ingress_last                ),
    .TX_REQ_fetch_mr_ingress_ready          (           TX_REQ_fetch_mr_ingress_ready               ),

    .TX_REQ_fetch_mr_egress_valid           (           TX_REQ_fetch_mr_egress_valid                ),
    .TX_REQ_fetch_mr_egress_head            (           TX_REQ_fetch_mr_egress_head                 ),
    .TX_REQ_fetch_mr_egress_data            (           TX_REQ_fetch_mr_egress_data                 ),
    .TX_REQ_fetch_mr_egress_start           (           TX_REQ_fetch_mr_egress_start                ),
    .TX_REQ_fetch_mr_egress_last            (           TX_REQ_fetch_mr_egress_last                 ),
    .TX_REQ_fetch_mr_egress_ready           (           TX_REQ_fetch_mr_egress_ready                ),

    .TX_REQ_cq_req_valid                    (           TX_REQ_cq_req_valid                         ),
    .TX_REQ_cq_req_head                     (           TX_REQ_cq_req_head                          ),
    .TX_REQ_cq_req_ready                    (           TX_REQ_cq_req_ready                         ),
     
    .TX_REQ_cq_resp_valid                   (           TX_REQ_cq_resp_valid                        ),
    .TX_REQ_cq_resp_head                    (           TX_REQ_cq_resp_head                         ),
    .TX_REQ_cq_resp_ready                   (           TX_REQ_cq_resp_ready                        ),

    .TX_REQ_eq_req_valid                    (           TX_REQ_eq_req_valid                         ),
    .TX_REQ_eq_req_head                     (           TX_REQ_eq_req_head                          ),
    .TX_REQ_eq_req_ready                    (           TX_REQ_eq_req_ready                         ),
 
    .TX_REQ_eq_resp_valid                   (           TX_REQ_eq_resp_valid                        ),
    .TX_REQ_eq_resp_head                    (           TX_REQ_eq_resp_head                         ),
    .TX_REQ_eq_resp_ready                   (           TX_REQ_eq_resp_ready                        ),

    .TX_REQ_gather_req_wr_en                (           TX_REQ_gather_req_wr_en                     ),
    .TX_REQ_gather_req_din                  (           TX_REQ_gather_req_din                       ),
    .TX_REQ_gather_req_prog_full            (           TX_REQ_gather_req_prog_full                 ),

    .TX_REQ_net_data_rd_en                  (           TX_REQ_net_data_rd_en                       ),
    .TX_REQ_net_data_dout                   (           TX_REQ_net_data_dout                        ),
    .TX_REQ_net_data_empty                  (           TX_REQ_net_data_empty                       ),

    .TX_REQ_scatter_req_wen                 (           TX_REQ_scatter_req_wr_en                      ),
    .TX_REQ_scatter_req_din                 (           TX_REQ_scatter_req_din                      ),
    .TX_REQ_scatter_req_prog_full           (           TX_REQ_scatter_req_prog_full                ),

    .TX_REQ_scatter_data_wen                (           TX_REQ_scatter_data_wr_en                     ),
    .TX_REQ_scatter_data_din                (           TX_REQ_scatter_data_din                     ),
    .TX_REQ_scatter_data_prog_full          (           TX_REQ_scatter_data_prog_full               ),

    .TX_REQ_insert_req_valid                (           TX_REQ_insert_req_valid                     ),
    .TX_REQ_insert_req_start                (           TX_REQ_insert_req_start                     ),
    .TX_REQ_insert_req_last                 (           TX_REQ_insert_req_last                      ),
    .TX_REQ_insert_req_head                 (           TX_REQ_insert_req_head                      ),
    .TX_REQ_insert_req_data                 (           TX_REQ_insert_req_data                      ),
    .TX_REQ_insert_req_ready                (           TX_REQ_insert_req_ready                     ),

    .TX_REQ_insert_resp_valid               (           TX_REQ_insert_resp_valid                    ),
    .TX_REQ_insert_resp_data                (           TX_REQ_insert_resp_data                     ),
        
    .TX_REQ_egress_pkt_valid                (           TX_REQ_egress_pkt_valid                     ),
    .TX_REQ_egress_pkt_head                 (           TX_REQ_egress_pkt_head                      ),
    .TX_REQ_egress_pkt_ready                (           TX_REQ_egress_pkt_ready                     ),
        
    .RX_RESP_ingress_pkt_valid              (           RX_RESP_ingress_pkt_valid                   ),
    .RX_RESP_ingress_pkt_head               (           RX_RESP_ingress_pkt_head                    ),
    .RX_RESP_ingress_pkt_ready              (           RX_RESP_ingress_pkt_ready                   ),

    .RX_RESP_fetch_cxt_ingress_valid        (           RX_RESP_fetch_cxt_ingress_valid             ),
    .RX_RESP_fetch_cxt_ingress_head         (           RX_RESP_fetch_cxt_ingress_head              ),
    .RX_RESP_fetch_cxt_ingress_data         (           RX_RESP_fetch_cxt_ingress_data              ),
    .RX_RESP_fetch_cxt_ingress_start        (           RX_RESP_fetch_cxt_ingress_start             ),
    .RX_RESP_fetch_cxt_ingress_last         (           RX_RESP_fetch_cxt_ingress_last              ),
    .RX_RESP_fetch_cxt_ingress_ready        (           RX_RESP_fetch_cxt_ingress_ready             ),

    .RX_RESP_fetch_cxt_egress_valid         (           RX_RESP_fetch_cxt_egress_valid              ),
    .RX_RESP_fetch_cxt_egress_head          (           RX_RESP_fetch_cxt_egress_head               ),
    .RX_RESP_fetch_cxt_egress_data          (           RX_RESP_fetch_cxt_egress_data               ),
    .RX_RESP_fetch_cxt_egress_start         (           RX_RESP_fetch_cxt_egress_start              ),
    .RX_RESP_fetch_cxt_egress_last          (           RX_RESP_fetch_cxt_egress_last               ),
    .RX_RESP_fetch_cxt_egress_ready         (           RX_RESP_fetch_cxt_egress_ready              ),

    .RX_RESP_fetch_mr_ingress_valid         (           RX_RESP_fetch_mr_ingress_valid              ),
    .RX_RESP_fetch_mr_ingress_head          (           RX_RESP_fetch_mr_ingress_head               ),
    .RX_RESP_fetch_mr_ingress_data          (           RX_RESP_fetch_mr_ingress_data               ),
    .RX_RESP_fetch_mr_ingress_start         (           RX_RESP_fetch_mr_ingress_start              ),
    .RX_RESP_fetch_mr_ingress_last          (           RX_RESP_fetch_mr_ingress_last               ),
    .RX_RESP_fetch_mr_ingress_ready         (           RX_RESP_fetch_mr_ingress_ready              ),

    .RX_RESP_fetch_mr_egress_valid          (           RX_RESP_fetch_mr_egress_valid               ),
    .RX_RESP_fetch_mr_egress_head           (           RX_RESP_fetch_mr_egress_head                ),
    .RX_RESP_fetch_mr_egress_data           (           RX_RESP_fetch_mr_egress_data                ),
    .RX_RESP_fetch_mr_egress_start          (           RX_RESP_fetch_mr_egress_start               ),
    .RX_RESP_fetch_mr_egress_last           (           RX_RESP_fetch_mr_egress_last                ),
    .RX_RESP_fetch_mr_egress_ready          (           RX_RESP_fetch_mr_egress_ready               ),

    .RX_RESP_cq_req_valid                   (           RX_RESP_cq_req_valid                        ),
    .RX_RESP_cq_req_head                    (           RX_RESP_cq_req_head                         ),
    .RX_RESP_cq_req_ready                   (           RX_RESP_cq_req_ready                        ),
     
    .RX_RESP_cq_resp_valid                  (           RX_RESP_cq_resp_valid                       ),
    .RX_RESP_cq_resp_head                   (           RX_RESP_cq_resp_head                        ),
    .RX_RESP_cq_resp_ready                  (           RX_RESP_cq_resp_ready                       ),

    .RX_RESP_eq_req_valid                   (           RX_RESP_eq_req_valid                        ),
    .RX_RESP_eq_req_head                    (           RX_RESP_eq_req_head                         ),
    .RX_RESP_eq_req_ready                   (           RX_RESP_eq_req_ready                        ),
 
    .RX_RESP_eq_resp_valid                  (           RX_RESP_eq_resp_valid                       ),
    .RX_RESP_eq_resp_head                   (           RX_RESP_eq_resp_head                        ),
    .RX_RESP_eq_resp_ready                  (           RX_RESP_eq_resp_ready                       ),

    .RX_RESP_scatter_req_wen                (           RX_RESP_scatter_req_wr_en                     ),
    .RX_RESP_scatter_req_din                (           RX_RESP_scatter_req_din                     ),
    .RX_RESP_scatter_req_prog_full          (           RX_RESP_scatter_req_prog_full               ),

    .RX_RESP_scatter_data_wen               (           RX_RESP_scatter_data_wr_en                    ),
    .RX_RESP_scatter_data_din               (           RX_RESP_scatter_data_din                    ),
    .RX_RESP_scatter_data_prog_full         (           RX_RESP_scatter_data_prog_full              ),

    .RX_RESP_delete_req_valid               (           RX_RESP_delete_req_valid                    ),
    .RX_RESP_delete_req_head                (           RX_RESP_delete_req_head                     ),
    .RX_RESP_delete_req_ready               (           RX_RESP_delete_req_ready                    ),
                            
    .RX_RESP_delete_resp_valid              (           RX_RESP_delete_resp_valid                   ),
    .RX_RESP_delete_resp_start              (           RX_RESP_delete_resp_start                   ),
    .RX_RESP_delete_resp_last               (           RX_RESP_delete_resp_last                    ),
    .RX_RESP_delete_resp_data               (           RX_RESP_delete_resp_data                    ),
    .RX_RESP_delete_resp_ready              (           RX_RESP_delete_resp_ready                   )
);

ResponderCore
#(
    .INGRESS_CXT_HEAD_WIDTH                 (           INGRESS_CXT_HEAD_WIDTH                      ),
    .INGRESS_CXT_DATA_WIDTH                 (           INGRESS_CXT_DATA_WIDTH                      ),
    .EGRESS_CXT_HEAD_WIDTH                  (           EGRESS_CXT_HEAD_WIDTH                       ),
    .EGRESS_CXT_DATA_WIDTH                  (           EGRESS_CXT_DATA_WIDTH                       ),

    .INGRESS_MR_HEAD_WIDTH                  (           INGRESS_MR_HEAD_WIDTH                       ),
    .INGRESS_MR_DATA_WIDTH                  (           INGRESS_MR_DATA_WIDTH                       ),
    .EGRESS_MR_HEAD_WIDTH                   (           EGRESS_MR_HEAD_WIDTH                        ),
    .EGRESS_MR_DATA_WIDTH                   (           EGRESS_MR_DATA_WIDTH                        )
)
ResponderCore_Inst
(
    .clk                                    (           clk                                         ),
    .rst                                    (           rst                                         ),

    .RX_REQ_ingress_pkt_valid               (           RX_REQ_ingress_pkt_valid                    ),
    .RX_REQ_ingress_pkt_head                (           RX_REQ_ingress_pkt_head                     ),
    .RX_REQ_ingress_pkt_ready               (           RX_REQ_ingress_pkt_ready                    ),

    .RX_REQ_fetch_cxt_ingress_valid         (           RX_REQ_fetch_cxt_ingress_valid              ),
    .RX_REQ_fetch_cxt_ingress_head          (           RX_REQ_fetch_cxt_ingress_head               ),
    .RX_REQ_fetch_cxt_ingress_data          (           RX_REQ_fetch_cxt_ingress_data               ),
    .RX_REQ_fetch_cxt_ingress_start         (           RX_REQ_fetch_cxt_ingress_start              ),
    .RX_REQ_fetch_cxt_ingress_last          (           RX_REQ_fetch_cxt_ingress_last               ),
    .RX_REQ_fetch_cxt_ingress_ready         (           RX_REQ_fetch_cxt_ingress_ready              ),

    .RX_REQ_fetch_cxt_egress_valid          (           RX_REQ_fetch_cxt_egress_valid               ),
    .RX_REQ_fetch_cxt_egress_head           (           RX_REQ_fetch_cxt_egress_head                ),
    .RX_REQ_fetch_cxt_egress_data           (           RX_REQ_fetch_cxt_egress_data                ),
    .RX_REQ_fetch_cxt_egress_start          (           RX_REQ_fetch_cxt_egress_start               ),
    .RX_REQ_fetch_cxt_egress_last           (           RX_REQ_fetch_cxt_egress_last                ),
    .RX_REQ_fetch_cxt_egress_ready          (           RX_REQ_fetch_cxt_egress_ready               ),

    .RX_REQ_fetch_mr_ingress_valid          (           RX_REQ_fetch_mr_ingress_valid               ),
    .RX_REQ_fetch_mr_ingress_head           (           RX_REQ_fetch_mr_ingress_head                ),
    .RX_REQ_fetch_mr_ingress_data           (           RX_REQ_fetch_mr_ingress_data                ),
    .RX_REQ_fetch_mr_ingress_start          (           RX_REQ_fetch_mr_ingress_start               ),
    .RX_REQ_fetch_mr_ingress_last           (           RX_REQ_fetch_mr_ingress_last                ),
    .RX_REQ_fetch_mr_ingress_ready          (           RX_REQ_fetch_mr_ingress_ready               ),

    .RX_REQ_fetch_mr_egress_valid           (           RX_REQ_fetch_mr_egress_valid                ),
    .RX_REQ_fetch_mr_egress_head            (           RX_REQ_fetch_mr_egress_head                 ),
    .RX_REQ_fetch_mr_egress_data            (           RX_REQ_fetch_mr_egress_data                 ),
    .RX_REQ_fetch_mr_egress_start           (           RX_REQ_fetch_mr_egress_start                ),
    .RX_REQ_fetch_mr_egress_last            (           RX_REQ_fetch_mr_egress_last                 ),
    .RX_REQ_fetch_mr_egress_ready           (           RX_REQ_fetch_mr_egress_ready                ),

    .RQ_wqe_req_valid                       (           RQ_wqe_req_valid                            ),
    .RQ_wqe_req_head                        (           RQ_wqe_req_head                             ),
    .RQ_wqe_req_start                       (           RQ_wqe_req_start                            ),
    .RQ_wqe_req_last                        (           RQ_wqe_req_last                             ),
    .RQ_wqe_req_ready                       (           RQ_wqe_req_ready                            ),

    .RQ_wqe_resp_valid                      (           RQ_wqe_resp_valid                           ),
    .RQ_wqe_resp_head                       (           RQ_wqe_resp_head                            ),
    .RQ_wqe_resp_data                       (           RQ_wqe_resp_data                            ),
    .RQ_wqe_resp_start                      (           RQ_wqe_resp_start                           ),
    .RQ_wqe_resp_last                       (           RQ_wqe_resp_last                            ),
    .RQ_wqe_resp_ready                      (           RQ_wqe_resp_ready                           ),

    .RQ_cache_offset_wen                    (           RQ_cache_offset_wen                         ),
    .RQ_cache_offset_addr                   (           RQ_cache_offset_addr                        ),
    .RQ_cache_offset_din                    (           RQ_cache_offset_din                         ),
    .RQ_cache_offset_dout                   (           RQ_cache_offset_dout                        ),

    .RQ_offset_wen                          (           RQ_offset_wen                               ),
    .RQ_offset_addr                         (           RQ_offset_addr                              ),
    .RQ_offset_din                          (           RQ_offset_din                               ),
    .RQ_offset_dout                         (           RQ_offset_dout                              ),

    .RQ_cache_owned_wen                 (           RQ_cache_owned_wen              ),
    .RQ_cache_owned_addr                (           RQ_cache_owned_addr             ),
    .RQ_cache_owned_din                 (           RQ_cache_owned_din              ),
    .RQ_cache_owned_dout                (           RQ_cache_owned_dout             ),

    .RX_REQ_cq_req_valid                    (           RX_REQ_cq_req_valid                         ),
    .RX_REQ_cq_req_head                     (           RX_REQ_cq_req_head                          ),
    .RX_REQ_cq_req_ready                    (           RX_REQ_cq_req_ready                         ),
     
    .RX_REQ_cq_resp_valid                   (           RX_REQ_cq_resp_valid                        ),
    .RX_REQ_cq_resp_head                    (           RX_REQ_cq_resp_head                         ),
    .RX_REQ_cq_resp_ready                   (           RX_REQ_cq_resp_ready                        ),

    .RX_REQ_eq_req_valid                    (           RX_REQ_eq_req_valid                         ),
    .RX_REQ_eq_req_head                     (           RX_REQ_eq_req_head                          ),
    .RX_REQ_eq_req_ready                    (           RX_REQ_eq_req_ready                         ),
 
    .RX_REQ_eq_resp_valid                   (           RX_REQ_eq_resp_valid                        ),
    .RX_REQ_eq_resp_head                    (           RX_REQ_eq_resp_head                         ),
    .RX_REQ_eq_resp_ready                   (           RX_REQ_eq_resp_ready                        ),

    .RX_REQ_delete_req_valid                (           RX_REQ_delete_req_valid                     ),
    .RX_REQ_delete_req_head                 (           RX_REQ_delete_req_head                      ),
    .RX_REQ_delete_req_ready                (           RX_REQ_delete_req_ready                     ),
                    
    .RX_REQ_delete_resp_valid               (           RX_REQ_delete_resp_valid                    ),
    .RX_REQ_delete_resp_start               (           RX_REQ_delete_resp_start                    ),
    .RX_REQ_delete_resp_last                (           RX_REQ_delete_resp_last                     ),
    .RX_REQ_delete_resp_data                (           RX_REQ_delete_resp_data                     ),
    .RX_REQ_delete_resp_ready               (           RX_REQ_delete_resp_ready                    ),

    .RX_REQ_scatter_req_wr_en               (           RX_REQ_scatter_req_wr_en                    ),
    .RX_REQ_scatter_req_din                 (           RX_REQ_scatter_req_din                      ),
    .RX_REQ_scatter_req_prog_full           (           RX_REQ_scatter_req_prog_full                ),

    .RX_REQ_scatter_data_wr_en              (           RX_REQ_scatter_data_wr_en                   ),
    .RX_REQ_scatter_data_din                (           RX_REQ_scatter_data_din                     ),
    .RX_REQ_scatter_data_prog_full          (           RX_REQ_scatter_data_prog_full               ),

    .TX_RESP_gather_req_wr_en               (           TX_RESP_gather_req_wr_en                    ),
    .TX_RESP_gather_req_din                 (           TX_RESP_gather_req_din                      ),
    .TX_RESP_gather_req_prog_full           (           TX_RESP_gather_req_prog_full                ),

    .TX_RESP_payload_empty                  (           TX_RESP_payload_empty                       ),
    .TX_RESP_payload_data                   (           TX_RESP_payload_dout                       ),
    .TX_RESP_payload_rd_en                  (           TX_RESP_payload_rd_en                         ),

    .TX_RESP_insert_req_valid               (           TX_RESP_insert_req_valid                    ),
    .TX_RESP_insert_req_start               (           TX_RESP_insert_req_start                    ),
    .TX_RESP_insert_req_last                (           TX_RESP_insert_req_last                     ),
    .TX_RESP_insert_req_head                (           TX_RESP_insert_req_head                     ),
    .TX_RESP_insert_req_data                (           TX_RESP_insert_req_data                     ),
    .TX_RESP_insert_req_ready               (           TX_RESP_insert_req_ready                    ),

    .TX_RESP_insert_resp_valid              (           TX_RESP_insert_resp_valid                   ),
    .TX_RESP_insert_resp_data               (           TX_RESP_insert_resp_data                    ),

    .TX_RESP_egress_pkt_valid               (           TX_RESP_egress_pkt_valid                    ),
    .TX_RESP_egress_pkt_head                (           TX_RESP_egress_pkt_head                     ),
    .TX_RESP_egress_pkt_ready               (           TX_RESP_egress_pkt_ready                    )
);

GatherData TX_GatherData_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),
    
    .gather_req_wr_en               (       TX_REQ_gather_req_wr_en            ),
    .gather_req_din                 (       TX_REQ_gather_req_din              ),
    .gather_req_prog_full           (       TX_REQ_gather_req_prog_full        ),
    
    .dma_rd_req_valid               (       TX_REQ_dma_rd_req_valid             ),
    .dma_rd_req_head                (       TX_REQ_dma_rd_req_head              ),
    .dma_rd_req_data                (       TX_REQ_dma_rd_req_data              ),
    .dma_rd_req_last                (       TX_REQ_dma_rd_req_last              ),
    .dma_rd_req_ready               (       TX_REQ_dma_rd_req_ready             ),
    
    .dma_rd_rsp_valid              (       TX_REQ_dma_rd_rsp_valid            ),
    .dma_rd_rsp_head               (       TX_REQ_dma_rd_rsp_head             ),
    .dma_rd_rsp_data               (       TX_REQ_dma_rd_rsp_data             ),
    .dma_rd_rsp_last               (       TX_REQ_dma_rd_rsp_last             ),
    .dma_rd_rsp_ready              (       TX_REQ_dma_rd_rsp_ready            ),
    
    .gather_resp_rd_en              (       TX_REQ_net_data_rd_en               ),
    .gather_resp_empty              (       TX_REQ_net_data_empty               ),
    .gather_resp_dout               (       TX_REQ_net_data_dout                )
);

GatherData RX_GatherData_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),
    
    .gather_req_wr_en               (       TX_RESP_gather_req_wr_en            ),
    .gather_req_din                 (       TX_RESP_gather_req_din              ),
    .gather_req_prog_full           (       TX_RESP_gather_req_prog_full        ),
    
    .dma_rd_req_valid               (       TX_RESP_dma_rd_req_valid            ),
    .dma_rd_req_head                (       TX_RESP_dma_rd_req_head             ),
    .dma_rd_req_data                (       TX_RESP_dma_rd_req_data             ),
    .dma_rd_req_last                (       TX_RESP_dma_rd_req_last             ),
    .dma_rd_req_ready               (       TX_RESP_dma_rd_req_ready            ),
    
    .dma_rd_rsp_valid              (       TX_RESP_dma_rd_rsp_valid           ),
    .dma_rd_rsp_head               (       TX_RESP_dma_rd_rsp_head            ),
    .dma_rd_rsp_data               (       TX_RESP_dma_rd_rsp_data            ),
    .dma_rd_rsp_last               (       TX_RESP_dma_rd_rsp_last            ),
    .dma_rd_rsp_ready              (       TX_RESP_dma_rd_rsp_ready           ),
    
    .gather_resp_rd_en              (       TX_RESP_payload_rd_en               ),
    .gather_resp_empty              (       TX_RESP_payload_empty                ),
    .gather_resp_dout               (       TX_RESP_payload_dout                 )
);

ScatterData TX_REQ_ScatterData_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),

    .scatter_req_wr_en              (       TX_REQ_scatter_req_wr_en              ),
    .scatter_req_din                (       TX_REQ_scatter_req_din              ),
    .scatter_req_prog_full          (       TX_REQ_scatter_req_prog_full        ),

    .scatter_data_wr_en             (       TX_REQ_scatter_data_wr_en             ),
    .scatter_data_din               (       TX_REQ_scatter_data_din             ),
    .scatter_data_prog_full         (       TX_REQ_scatter_data_prog_full       ),

    .dma_wr_req_valid               (       TX_REQ_dma_wr_req_valid             ),
    .dma_wr_req_last                (       TX_REQ_dma_wr_req_last              ),
    .dma_wr_req_head                (       TX_REQ_dma_wr_req_head              ),
    .dma_wr_req_data                (       TX_REQ_dma_wr_req_data              ),
    .dma_wr_req_ready               (       TX_REQ_dma_wr_req_ready             )
);

ScatterData RX_REQ_ScatterData_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),

    .scatter_req_wr_en              (       RX_REQ_scatter_req_wr_en            ),
    .scatter_req_din                (       RX_REQ_scatter_req_din              ),
    .scatter_req_prog_full          (       RX_REQ_scatter_req_prog_full        ),

    .scatter_data_wr_en             (       RX_REQ_scatter_data_wr_en           ),
    .scatter_data_din               (       RX_REQ_scatter_data_din             ),
    .scatter_data_prog_full         (       RX_REQ_scatter_data_prog_full       ),

    .dma_wr_req_valid               (       RX_REQ_dma_wr_req_valid             ),
    .dma_wr_req_last                (       RX_REQ_dma_wr_req_last              ),
    .dma_wr_req_head                (       RX_REQ_dma_wr_req_head              ),
    .dma_wr_req_data                (       RX_REQ_dma_wr_req_data              ),
    .dma_wr_req_ready               (       RX_REQ_dma_wr_req_ready             )
);

ScatterData RX_RESP_ScatterData_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),

    .scatter_req_wr_en              (       RX_RESP_scatter_req_wr_en           ),
    .scatter_req_din                (       RX_RESP_scatter_req_din             ),
    .scatter_req_prog_full          (       RX_RESP_scatter_req_prog_full       ),

    .scatter_data_wr_en             (       RX_RESP_scatter_data_wr_en          ),
    .scatter_data_din               (       RX_RESP_scatter_data_din            ),
    .scatter_data_prog_full         (       RX_RESP_scatter_data_prog_full      ),

    .dma_wr_req_valid               (       RX_RESP_dma_wr_req_valid            ),
    .dma_wr_req_last                (       RX_RESP_dma_wr_req_last             ),
    .dma_wr_req_head                (       RX_RESP_dma_wr_req_head             ),
    .dma_wr_req_data                (       RX_RESP_dma_wr_req_data             ),
    .dma_wr_req_ready               (       RX_RESP_dma_wr_req_ready            )
);

AXISArbiter 
#(
    .HEAD_WIDTH     (       `PKT_META_BUS_WIDTH     ),
    .DATA_WIDTH     (       64                      )   //Unused
)
TX_Arbiter_Inst 
(
    .clk                    (   clk                         ),
    .rst                    (   rst                         ),

    .in_axis_valid_a        (   TX_REQ_egress_pkt_valid     ),
    .in_axis_head_a         (   TX_REQ_egress_pkt_head      ),
    .in_axis_data_a         (   'd0                         ),
    .in_axis_start_a        (   TX_REQ_egress_pkt_valid     ),
    .in_axis_last_a         (   TX_REQ_egress_pkt_valid     ),
    .in_axis_ready_a        (   TX_REQ_egress_pkt_ready     ),

    .in_axis_valid_b        (   TX_RESP_egress_pkt_valid    ),
    .in_axis_head_b         (   TX_RESP_egress_pkt_head     ),
    .in_axis_data_b         (   'd0                         ),
    .in_axis_start_b        (   TX_RESP_egress_pkt_valid    ),
    .in_axis_last_b         (   TX_RESP_egress_pkt_valid    ),
    .in_axis_ready_b        (   TX_RESP_egress_pkt_ready    ),

    .out_axis_valid         (   TX_egress_pkt_valid         ),
    .out_axis_head          (   TX_egress_pkt_head          ),
    .out_axis_data          (                               ),
    .out_axis_start         (                               ),
    .out_axis_last          (                               ),
    .out_axis_ready         (   TX_egress_pkt_ready         )
);

// TXArbiter TX_Arbiter_Inst(
//     .clk                            (       clk                                 ),
//     .rst                            (       rst                                 ),

//     .chnl_0_pkt_valid               (       TX_REQ_egress_pkt_valid             ),
//     .chnl_0_pkt_head                (       TX_REQ_egress_pkt_head              ),
//     .chnl_0_pkt_ready               (       TX_REQ_egress_pkt_ready             ),

//     .chnl_1_pkt_valid               (       TX_RESP_egress_pkt_valid            ),
//     .chnl_1_pkt_head                (       TX_RESP_egress_pkt_head             ),
//     .chnl_1_pkt_ready               (       TX_RESP_egress_pkt_ready            ),

//     .egress_pkt_valid               (       TX_egress_pkt_valid                 ),
//     .egress_pkt_head                (       TX_egress_pkt_head                  ),
//     .egress_pkt_ready               (       TX_egress_pkt_ready                 )
// );

RXDispatcher RX_Dispatcher_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),

    .ingress_pkt_valid              (       RX_ingress_pkt_valid                 ),
    .ingress_pkt_head               (       RX_ingress_pkt_head                  ),
    .ingress_pkt_ready              (       RX_ingress_pkt_ready                 ),

    .req_recv_pkt_valid               (       RX_REQ_ingress_pkt_valid             ),
    .req_recv_pkt_head                (       RX_REQ_ingress_pkt_head              ),
    .req_recv_pkt_ready               (       RX_REQ_ingress_pkt_ready             ),

    .resp_recv_pkt_valid               (       RX_RESP_ingress_pkt_valid            ),
    .resp_recv_pkt_head                (       RX_RESP_ingress_pkt_head             ),
    .resp_recv_pkt_ready               (       RX_RESP_ingress_pkt_ready            )
);

DynamicBufferInsertArbiter PacketBufferInsertArbiter_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),  

    .chnl_0_req_valid               (       TX_REQ_insert_req_valid             ),
    .chnl_0_req_start               (       TX_REQ_insert_req_start             ),
    .chnl_0_req_last                (       TX_REQ_insert_req_last              ),
    .chnl_0_req_head                (       TX_REQ_insert_req_head              ),
    .chnl_0_req_data                (       TX_REQ_insert_req_data              ),
    .chnl_0_req_ready               (       TX_REQ_insert_req_ready             ),

    .chnl_0_resp_valid              (       TX_REQ_insert_resp_valid            ),
    .chnl_0_resp_data               (       TX_REQ_insert_resp_data             ),

    .chnl_1_req_valid               (       TX_RESP_insert_req_valid            ),
    .chnl_1_req_start               (       TX_RESP_insert_req_start            ),
    .chnl_1_req_last                (       TX_RESP_insert_req_last             ),
    .chnl_1_req_head                (       TX_RESP_insert_req_head             ),
    .chnl_1_req_data                (       TX_RESP_insert_req_data             ),
    .chnl_1_req_ready               (       TX_RESP_insert_req_ready            ),

    .chnl_1_resp_valid              (       TX_RESP_insert_resp_valid           ),
    .chnl_1_resp_data               (       TX_RESP_insert_resp_data            ),

    .insert_req_valid               (       TX_insert_req_valid                 ),
    .insert_req_start               (       TX_insert_req_start                 ),
    .insert_req_last                (       TX_insert_req_last                  ),
    .insert_req_head                (       TX_insert_req_head                  ),
    .insert_req_data                (       TX_insert_req_data                  ),
    .insert_req_ready               (       TX_insert_req_ready                 ),

    .insert_resp_valid              (       TX_insert_resp_valid                ),
    .insert_resp_data               (       TX_insert_resp_data                 ) 
);

DynamicBufferDeleteArbiter PacketBufferDeleteArbiter_Inst(
    .clk                            (       clk                                 ),
    .rst                            (       rst                                 ),

    .chnl_0_req_valid               (       RX_REQ_delete_req_valid             ),
    .chnl_0_req_head                (       RX_REQ_delete_req_head              ),
    .chnl_0_req_ready               (       RX_REQ_delete_req_ready             ),

    .chnl_0_resp_valid              (       RX_REQ_delete_resp_valid            ),
    .chnl_0_resp_start              (       RX_REQ_delete_resp_start            ),
    .chnl_0_resp_last               (       RX_REQ_delete_resp_last             ),
    .chnl_0_resp_data               (       RX_REQ_delete_resp_data             ),
    .chnl_0_resp_ready              (       RX_REQ_delete_resp_ready            ),

    .chnl_1_req_valid               (       RX_RESP_delete_req_valid            ),
    .chnl_1_req_head                (       RX_RESP_delete_req_head             ),
    .chnl_1_req_ready               (       RX_RESP_delete_req_ready            ),

    .chnl_1_resp_valid              (       RX_RESP_delete_resp_valid           ),
    .chnl_1_resp_start              (       RX_RESP_delete_resp_start           ),
    .chnl_1_resp_last               (       RX_RESP_delete_resp_last            ),
    .chnl_1_resp_data               (       RX_RESP_delete_resp_data            ),
    .chnl_1_resp_ready              (       RX_RESP_delete_resp_ready           ),

    .delete_req_valid               (       RX_delete_req_valid                 ),
    .delete_req_head                (       RX_delete_req_head                  ),
    .delete_req_ready               (       RX_delete_req_ready                 ),

    .delete_resp_valid              (       RX_delete_resp_valid                ),
    .delete_resp_start              (       RX_delete_resp_start                ),
    .delete_resp_last               (       RX_delete_resp_last                 ),
    .delete_resp_data               (       RX_delete_resp_data                 ),
    .delete_resp_ready              (       RX_delete_resp_ready                )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule