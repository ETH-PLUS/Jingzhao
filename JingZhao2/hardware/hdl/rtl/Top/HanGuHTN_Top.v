/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HanGuHTN_Top
Author:     YangFan
Function:   Intagrate .
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HanGuHTN_Top
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
    input   wire                                                    pcie_clk,
    input   wire                                                    pcie_rst,

    input   wire                                                    user_clk,
    input   wire                                                    user_rst,

    input   wire                                                    mac_tx_clk,
    input   wire                                                    mac_tx_rst,

    input   wire                                                    mac_rx_clk,
    input   wire                                                    mac_rx_rst,

//Interface with Host
    input   wire            [2:0]                                   cfg_max_payload,
    input   wire            [2:0]                                   cfg_max_read_req,
    input   wire            [12:0]                                  tl_cfg_busdev, 

    input   wire            [1:0]                                   cfg_interrupt_msix_enable,
    input   wire            [1:0]                                   cfg_interrupt_msix_mask,
    output  wire            [31:0]                                  cfg_interrupt_msix_data,
    output  wire            [63:0]                                  cfg_interrupt_msix_address,
    output  wire                                                    cfg_interrupt_msix_int,
    input   wire                                                    cfg_interrupt_msix_sent,
    input   wire                                                    cfg_interrupt_msix_fail,
    output wire             [2:0]                                   cfg_interrupt_msi_function_number,

    output wire                                                     s_axis_rq_tvalid,
    output wire                                                     s_axis_rq_tlast,
    output wire             [`PCIEI_KEEP_W-1:0]                     s_axis_rq_tkeep,
    output wire                          [59:0]                     s_axis_rq_tuser,
    output wire             [`PCIEI_DATA_W-1:0]                     s_axis_rq_tdata,
    input  wire                           [3:0]                     s_axis_rq_tready,

    input  wire                                                     m_axis_rc_tvalid,
    input  wire                                                     m_axis_rc_tlast,
    input  wire             [`PCIEI_KEEP_W-1:0]                     m_axis_rc_tkeep,
    input  wire                          [74:0]                     m_axis_rc_tuser,
    input  wire             [`PCIEI_DATA_W-1:0]                     m_axis_rc_tdata,
    output wire                                                     m_axis_rc_tready,

    input  wire                                                     m_axis_cq_tvalid,
    input  wire                                                     m_axis_cq_tlast,
    input  wire             [`PCIEI_KEEP_W-1:0]                     m_axis_cq_tkeep,
    input  wire                          [84:0]                     m_axis_cq_tuser,
    input  wire             [`PCIEI_DATA_W-1:0]                     m_axis_cq_tdata,
    output wire                                                     m_axis_cq_tready,

    output wire                                                     s_axis_cc_tvalid,
    output wire                                                     s_axis_cc_tlast,
    output wire             [`PCIEI_KEEP_W-1:0]                     s_axis_cc_tkeep,
    output wire                          [32:0]                     s_axis_cc_tuser,
    output wire             [`PCIEI_DATA_W-1:0]                     s_axis_cc_tdata,
    input  wire                           [3:0]                     s_axis_cc_tready,

//Interface with Network
    output  wire                                                    mac_tx_valid,
    input   wire                                                    mac_tx_ready,
    output  wire                                                    mac_tx_start,
    output  wire                                                    mac_tx_last,
    output  wire           [`MAC_KEEP_WIDTH - 1 : 0]                mac_tx_keep,
    output  wire                                                    mac_tx_user,
    output  wire           [`MAC_DATA_WIDTH - 1 : 0]                mac_tx_data,

    input   wire                                                    mac_rx_valid,
    output  wire                                                    mac_rx_ready,
    input   wire                                                    mac_rx_start,
    input   wire                                                    mac_rx_last,
    input   wire          [`MAC_KEEP_WIDTH - 1 : 0]                 mac_rx_keep,
    input   wire                                                    mac_rx_user,
    input   wire          [`MAC_DATA_WIDTH - 1 : 0]                 mac_rx_data
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire    [63:0]                                          ceu_hcr_in_param;
wire    [31:0]                                          ceu_hcr_in_modifier;
wire    [63:0]                                          ceu_hcr_out_dma_addr;
wire    [31:0]                                          ceu_hcr_token;
wire                                                    ceu_hcr_go;
wire                                                    ceu_hcr_event;
wire    [7:0]                                           ceu_hcr_op_modifier;
wire    [11:0]                                          ceu_hcr_op;

wire    [63:0]                                          ceu_hcr_out_param;
wire    [7:0]                                           ceu_hcr_status;
wire                                                    ceu_hcr_clear;

wire                                                    CEU_dma_rd_req_valid;
wire                                                    CEU_dma_rd_req_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CEU_dma_rd_req_data;
wire                                                    CEU_dma_rd_req_ready;

wire                                                    CEU_dma_rd_rsp_in_valid;
wire                                                    CEU_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    CEU_dma_rd_rsp_in_data;
wire                                                    CEU_dma_rd_rsp_in_ready;

wire                                                    CEU_dma_rd_rsp_out_valid;
wire                                                    CEU_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CEU_dma_rd_rsp_out_data;
wire                                                    CEU_dma_rd_rsp_out_ready;

wire                                                    CEU_dma_wr_req_in_valid;
wire                                                    CEU_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CEU_dma_wr_req_in_data;
wire                                                    CEU_dma_wr_req_in_ready;

wire                                                    CEU_dma_wr_req_out_valid;
wire                                                    CEU_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_wr_req_out_head;
wire    [255 : 0]                       			    CEU_dma_wr_req_out_data;
wire                                                    CEU_dma_wr_req_out_ready;

wire                                                    QPC_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       QPC_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       QPC_dma_rd_req_data;
wire                                                    QPC_dma_rd_req_last;
wire                                                    QPC_dma_rd_req_ready;

wire                                                    QPC_dma_rd_rsp_in_valid;
wire                                                    QPC_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       QPC_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    QPC_dma_rd_rsp_in_data;
wire                                                    QPC_dma_rd_rsp_in_ready;

wire                                                    QPC_dma_rd_rsp_out_valid;
wire                                                    QPC_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       QPC_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       QPC_dma_rd_rsp_out_data;
wire                                                    QPC_dma_rd_rsp_out_ready;

wire                                                    QPC_dma_wr_req_in_valid;
wire                                                    QPC_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       QPC_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       QPC_dma_wr_req_in_data;
wire                                                    QPC_dma_wr_req_in_ready;

wire                                                    QPC_dma_wr_req_out_valid;
wire                                                    QPC_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       QPC_dma_wr_req_out_head;
wire    [255 : 0]                       			    QPC_dma_wr_req_out_data;
wire                                                    QPC_dma_wr_req_out_ready;

wire                                                    CQC_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CQC_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CQC_dma_rd_req_data;
wire                                                    CQC_dma_rd_req_last;
wire                                                    CQC_dma_rd_req_ready;

wire                                                    CQC_dma_rd_rsp_in_valid;
wire                                                    CQC_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CQC_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    CQC_dma_rd_rsp_in_data;
wire                                                    CQC_dma_rd_rsp_in_ready;

wire                                                    CQC_dma_rd_rsp_out_valid;
wire                                                    CQC_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CQC_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CQC_dma_rd_rsp_out_data;
wire                                                    CQC_dma_rd_rsp_out_ready;

wire                                                    CQC_dma_wr_req_in_valid;
wire                                                    CQC_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CQC_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       CQC_dma_wr_req_in_data;
wire                                                    CQC_dma_wr_req_in_ready;

wire                                                    CQC_dma_wr_req_out_valid;
wire                                                    CQC_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CQC_dma_wr_req_out_head;
wire    [255 : 0]                       			    CQC_dma_wr_req_out_data;
wire                                                    CQC_dma_wr_req_out_ready;

wire                                                    EQC_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       EQC_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       EQC_dma_rd_req_data;
wire                                                    EQC_dma_rd_req_last;
wire                                                    EQC_dma_rd_req_ready;

wire                                                    EQC_dma_rd_rsp_in_valid;
wire                                                    EQC_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       EQC_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    EQC_dma_rd_rsp_in_data;
wire                                                    EQC_dma_rd_rsp_in_ready;

wire                                                    EQC_dma_rd_rsp_out_valid;
wire                                                    EQC_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       EQC_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       EQC_dma_rd_rsp_out_data;
wire                                                    EQC_dma_rd_rsp_out_ready;

wire                                                    EQC_dma_wr_req_in_valid;
wire                                                    EQC_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       EQC_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       EQC_dma_wr_req_in_data;
wire                                                    EQC_dma_wr_req_in_ready;

wire                                                    EQC_dma_wr_req_out_valid;
wire                                                    EQC_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       EQC_dma_wr_req_out_head;
wire    [255 : 0]                       			    EQC_dma_wr_req_out_data;
wire                                                    EQC_dma_wr_req_out_ready;

wire                                                    MPT_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MPT_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MPT_dma_rd_req_data;
wire                                                    MPT_dma_rd_req_last;
wire                                                    MPT_dma_rd_req_ready;

wire                                                    MPT_dma_rd_rsp_in_valid;
wire                                                    MPT_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MPT_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    MPT_dma_rd_rsp_in_data;
wire                                                    MPT_dma_rd_rsp_in_ready;

wire                                                    MPT_dma_rd_rsp_out_valid;
wire                                                    MPT_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MPT_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MPT_dma_rd_rsp_out_data;
wire                                                    MPT_dma_rd_rsp_out_ready;

wire                                                    MPT_dma_wr_req_in_valid;
wire                                                    MPT_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MPT_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MPT_dma_wr_req_in_data;
wire                                                    MPT_dma_wr_req_in_ready;

wire                                                    MPT_dma_wr_req_out_valid;
wire                                                    MPT_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MPT_dma_wr_req_out_head;
wire    [255 : 0]                       			    MPT_dma_wr_req_out_data;
wire                                                    MPT_dma_wr_req_out_ready;

wire                                                    MTT_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MTT_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MTT_dma_rd_req_data;
wire                                                    MTT_dma_rd_req_last;
wire                                                    MTT_dma_rd_req_ready;

wire                                                    MTT_dma_rd_rsp_in_valid;
wire                                                    MTT_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MTT_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    MTT_dma_rd_rsp_in_data;
wire                                                    MTT_dma_rd_rsp_in_ready;

wire                                                    MTT_dma_rd_rsp_out_valid;
wire                                                    MTT_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MTT_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MTT_dma_rd_rsp_out_data;
wire                                                    MTT_dma_rd_rsp_out_ready;

wire                                                    MTT_dma_wr_req_in_valid;
wire                                                    MTT_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MTT_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       MTT_dma_wr_req_in_data;
wire                                                    MTT_dma_wr_req_in_ready;

wire                                                    MTT_dma_wr_req_out_valid;
wire                                                    MTT_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       MTT_dma_wr_req_out_head;
wire    [255 : 0]                       			    MTT_dma_wr_req_out_data;
wire                                                    MTT_dma_wr_req_out_ready;

wire                                                    SQ_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       SQ_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       SQ_dma_rd_req_data;
wire                                                    SQ_dma_rd_req_last;
wire                                                    SQ_dma_rd_req_ready;
                        
wire                                                    SQ_dma_rd_rsp_in_valid;
wire                                                    SQ_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       SQ_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    SQ_dma_rd_rsp_in_data;
wire                                                    SQ_dma_rd_rsp_in_ready;

wire                                                    SQ_dma_rd_rsp_out_valid;
wire                                                    SQ_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       SQ_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       SQ_dma_rd_rsp_out_data;
wire                                                    SQ_dma_rd_rsp_out_ready;

wire                                                    RQ_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RQ_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       RQ_dma_rd_req_data;
wire                                                    RQ_dma_rd_req_last;
wire                                                    RQ_dma_rd_req_ready;
                        
wire                                                    RQ_dma_rd_rsp_in_valid;
wire                                                    RQ_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RQ_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    RQ_dma_rd_rsp_in_data;
wire                                                    RQ_dma_rd_rsp_in_ready;

wire                                                    RQ_dma_rd_rsp_out_valid;
wire                                                    RQ_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RQ_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       RQ_dma_rd_rsp_out_data;
wire                                                    RQ_dma_rd_rsp_out_ready;

wire                                                    TX_REQ_dma_wr_req_in_valid;
wire                                                    TX_REQ_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_wr_req_in_data;
wire                                                    TX_REQ_dma_wr_req_in_ready;

wire                                                    TX_REQ_dma_wr_req_out_valid;
wire                                                    TX_REQ_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_wr_req_out_head;
wire    [255 : 0]                       			    TX_REQ_dma_wr_req_out_data;
wire                                                    TX_REQ_dma_wr_req_out_ready;

wire                                                    RX_REQ_dma_wr_req_in_valid;
wire                                                    RX_REQ_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_REQ_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       RX_REQ_dma_wr_req_in_data;
wire                                                    RX_REQ_dma_wr_req_in_ready;

wire                                                    RX_REQ_dma_wr_req_out_valid;
wire                                                    RX_REQ_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_REQ_dma_wr_req_out_head;
wire    [255 : 0]                       			    RX_REQ_dma_wr_req_out_data;
wire                                                    RX_REQ_dma_wr_req_out_ready;

wire                                                    RX_RESP_dma_wr_req_in_valid;
wire                                                    RX_RESP_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_RESP_dma_wr_req_in_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       RX_RESP_dma_wr_req_in_data;
wire                                                    RX_RESP_dma_wr_req_in_ready;

wire                                                    RX_RESP_dma_wr_req_out_valid;
wire                                                    RX_RESP_dma_wr_req_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_RESP_dma_wr_req_out_head;
wire    [255 : 0]                       			    RX_RESP_dma_wr_req_out_data;
wire                                                    RX_RESP_dma_wr_req_out_ready;

wire                                                    TX_REQ_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_rd_req_data;
wire                                                    TX_REQ_dma_rd_req_last;
wire                                                    TX_REQ_dma_rd_req_ready;
    
wire                                                    TX_REQ_dma_rd_rsp_in_valid;
wire                                                    TX_REQ_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    TX_REQ_dma_rd_rsp_in_data;
wire                                                    TX_REQ_dma_rd_rsp_in_ready;

wire                                                    TX_REQ_dma_rd_rsp_out_valid;
wire                                                    TX_REQ_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_rd_rsp_out_data;
wire                                                    TX_REQ_dma_rd_rsp_out_ready;

wire                                                    TX_RESP_dma_rd_req_valid;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_RESP_dma_rd_req_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_RESP_dma_rd_req_data;
wire                                                    TX_RESP_dma_rd_req_last;
wire                                                    TX_RESP_dma_rd_req_ready;
    
wire                                                    TX_RESP_dma_rd_rsp_in_valid;
wire                                                    TX_RESP_dma_rd_rsp_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_RESP_dma_rd_rsp_in_head;
wire    [255 : 0]                       			    TX_RESP_dma_rd_rsp_in_data;
wire                                                    TX_RESP_dma_rd_rsp_in_ready;

wire                                                    TX_RESP_dma_rd_rsp_out_valid;
wire                                                    TX_RESP_dma_rd_rsp_out_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_RESP_dma_rd_rsp_out_head;
wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_RESP_dma_rd_rsp_out_data;
wire                                                    TX_RESP_dma_rd_rsp_out_ready;

wire                                                    db_fifo_wen;
wire    [63:0]                                          db_fifo_din;
wire                                                    db_fifo_prog_full;

wire                                                    db_fifo_ren;
wire    [63:0]                                          db_fifo_dout;
wire                                                    db_fifo_empty;

wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_req_valid;
wire    [`DMA_HEAD_WIDTH * `DMA_RD_CHNL_NUM - 1 : 0]    DMA_RD_req_head;
wire    [`DMA_DATA_WIDTH * `DMA_RD_CHNL_NUM - 1 : 0]    DMA_RD_req_data;
wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_req_last;
wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_req_ready;

wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_rsp_in_valid;
wire    [`DMA_HEAD_WIDTH * `DMA_RD_CHNL_NUM - 1 : 0]    DMA_RD_rsp_in_head;
wire    [256 * `DMA_RD_CHNL_NUM - 1 : 0]    			DMA_RD_rsp_in_data;
wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_rsp_in_last;
wire    [1 * `DMA_RD_CHNL_NUM - 1 : 0]                  DMA_RD_rsp_in_ready;

wire    [1 * (`DMA_WR_CHNL_NUM - 1) - 1 : 0]                  	DMA_WR_req_out_valid;
wire    [`DMA_HEAD_WIDTH * (`DMA_WR_CHNL_NUM - 1) - 1 : 0]    	DMA_WR_req_out_head;
wire    [256 * (`DMA_WR_CHNL_NUM - 1) - 1 : 0]    				DMA_WR_req_out_data;
wire    [1 * (`DMA_WR_CHNL_NUM - 1) - 1 : 0]                 	DMA_WR_req_out_last;
wire    [1 * (`DMA_WR_CHNL_NUM - 1) - 1 : 0]                 	DMA_WR_req_out_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ProtocolEngine_Top ProtocolEngine_Top_Inst(
    .user_clk                           (           user_clk                           ),
    .user_rst                           (           user_rst                           ),

    .mac_tx_clk                         (           mac_tx_clk                         ),
    .mac_tx_rst                         (           mac_tx_rst                         ),

    .mac_rx_clk                         (           mac_rx_clk                         ),
    .mac_rx_rst                         (           mac_rx_rst                         ),

    .ceu_hcr_in_param                   (           ceu_hcr_in_param                   ),
    .ceu_hcr_in_modifier                (           ceu_hcr_in_modifier                ),
    .ceu_hcr_out_dma_addr               (           ceu_hcr_out_dma_addr               ),
    .ceu_hcr_token                      (           ceu_hcr_token                      ),
    .ceu_hcr_go                         (           ceu_hcr_go                         ),
    .ceu_hcr_event                      (           ceu_hcr_event                      ),
    .ceu_hcr_op_modifier                (           ceu_hcr_op_modifier                ),
    .ceu_hcr_op                         (           ceu_hcr_op                         ),

    .ceu_hcr_out_param                  (           ceu_hcr_out_param                  ),
    .ceu_hcr_status                     (           ceu_hcr_status                     ),
    .ceu_hcr_clear                      (           ceu_hcr_clear                      ),

    .CEU_dma_rd_req_valid               (           CEU_dma_rd_req_valid               ),
    .CEU_dma_rd_req_last                (           CEU_dma_rd_req_last                ),
    .CEU_dma_rd_req_head                (           CEU_dma_rd_req_head                ),
    .CEU_dma_rd_req_data                (           CEU_dma_rd_req_data                ),
    .CEU_dma_rd_req_ready               (           CEU_dma_rd_req_ready               ),

    .CEU_dma_rd_rsp_valid               (           CEU_dma_rd_rsp_out_valid               ),
    .CEU_dma_rd_rsp_last                (           CEU_dma_rd_rsp_out_last                ),
    .CEU_dma_rd_rsp_head                (           CEU_dma_rd_rsp_out_head                ),
    .CEU_dma_rd_rsp_data                (           CEU_dma_rd_rsp_out_data                ),
    .CEU_dma_rd_rsp_ready               (           CEU_dma_rd_rsp_out_ready               ),

    .CEU_dma_wr_req_valid               (           CEU_dma_wr_req_in_valid             ),
    .CEU_dma_wr_req_last                (           CEU_dma_wr_req_in_last              ),
    .CEU_dma_wr_req_head                (           CEU_dma_wr_req_in_head              ),
    .CEU_dma_wr_req_data                (           CEU_dma_wr_req_in_data              ),
    .CEU_dma_wr_req_ready               (           CEU_dma_wr_req_in_ready             ),

    .db_fifo_empty                      (           db_fifo_empty                      ),
    .db_fifo_dout                       (           db_fifo_dout                       ),
    .db_fifo_rd_en                      (           db_fifo_ren                        ),

    .QPC_dma_rd_req_valid               (           QPC_dma_rd_req_valid               ),
    .QPC_dma_rd_req_head                (           QPC_dma_rd_req_head                ),
    .QPC_dma_rd_req_data                (           QPC_dma_rd_req_data                ),
    .QPC_dma_rd_req_last                (           QPC_dma_rd_req_last                ),
    .QPC_dma_rd_req_ready               (           QPC_dma_rd_req_ready               ),

    .QPC_dma_rd_rsp_valid               (           QPC_dma_rd_rsp_out_valid               ),
    .QPC_dma_rd_rsp_head                (           QPC_dma_rd_rsp_out_head                ),
    .QPC_dma_rd_rsp_data                (           QPC_dma_rd_rsp_out_data                ),
    .QPC_dma_rd_rsp_last                (           QPC_dma_rd_rsp_out_last                ),
    .QPC_dma_rd_rsp_ready               (           QPC_dma_rd_rsp_out_ready               ),

    .QPC_dma_wr_req_valid               (           QPC_dma_wr_req_in_valid               ),
    .QPC_dma_wr_req_head                (           QPC_dma_wr_req_in_head                ),
    .QPC_dma_wr_req_data                (           QPC_dma_wr_req_in_data                ),
    .QPC_dma_wr_req_last                (           QPC_dma_wr_req_in_last                ),
    .QPC_dma_wr_req_ready               (           QPC_dma_wr_req_in_ready               ),

    .CQC_dma_rd_req_valid               (           CQC_dma_rd_req_valid               ),
    .CQC_dma_rd_req_head                (           CQC_dma_rd_req_head                ),
    .CQC_dma_rd_req_data                (           CQC_dma_rd_req_data                ),
    .CQC_dma_rd_req_last                (           CQC_dma_rd_req_last                ),
    .CQC_dma_rd_req_ready               (           CQC_dma_rd_req_ready               ),

    .CQC_dma_rd_rsp_valid               (           CQC_dma_rd_rsp_out_valid               ),
    .CQC_dma_rd_rsp_head                (           CQC_dma_rd_rsp_out_head                ),
    .CQC_dma_rd_rsp_data                (           CQC_dma_rd_rsp_out_data                ),
    .CQC_dma_rd_rsp_last                (           CQC_dma_rd_rsp_out_last                ),
    .CQC_dma_rd_rsp_ready               (           CQC_dma_rd_rsp_out_ready               ),

    .CQC_dma_wr_req_valid               (           CQC_dma_wr_req_in_valid               ),
    .CQC_dma_wr_req_head                (           CQC_dma_wr_req_in_head                ),
    .CQC_dma_wr_req_data                (           CQC_dma_wr_req_in_data                ),
    .CQC_dma_wr_req_last                (           CQC_dma_wr_req_in_last                ),
    .CQC_dma_wr_req_ready               (           CQC_dma_wr_req_in_ready               ),

    .EQC_dma_rd_req_valid               (           EQC_dma_rd_req_valid               ),
    .EQC_dma_rd_req_head                (           EQC_dma_rd_req_head                ),
    .EQC_dma_rd_req_data                (           EQC_dma_rd_req_data                ),
    .EQC_dma_rd_req_last                (           EQC_dma_rd_req_last                ),
    .EQC_dma_rd_req_ready               (           EQC_dma_rd_req_ready               ),

    .EQC_dma_rd_rsp_valid               (           EQC_dma_rd_rsp_out_valid               ),
    .EQC_dma_rd_rsp_head                (           EQC_dma_rd_rsp_out_head                ),
    .EQC_dma_rd_rsp_data                (           EQC_dma_rd_rsp_out_data                ),
    .EQC_dma_rd_rsp_last                (           EQC_dma_rd_rsp_out_last                ),
    .EQC_dma_rd_rsp_ready               (           EQC_dma_rd_rsp_out_ready               ),

    .EQC_dma_wr_req_valid               (           EQC_dma_wr_req_in_valid               ),
    .EQC_dma_wr_req_head                (           EQC_dma_wr_req_in_head                ),
    .EQC_dma_wr_req_data                (           EQC_dma_wr_req_in_data                ),
    .EQC_dma_wr_req_last                (           EQC_dma_wr_req_in_last                ),
    .EQC_dma_wr_req_ready               (           EQC_dma_wr_req_in_ready               ),

    .MPT_dma_rd_req_valid               (           MPT_dma_rd_req_valid               ),
    .MPT_dma_rd_req_head                (           MPT_dma_rd_req_head                ),
    .MPT_dma_rd_req_data                (           MPT_dma_rd_req_data                ),
    .MPT_dma_rd_req_last                (           MPT_dma_rd_req_last                ),
    .MPT_dma_rd_req_ready               (           MPT_dma_rd_req_ready               ),

    .MPT_dma_rd_rsp_valid               (           MPT_dma_rd_rsp_out_valid               ),
    .MPT_dma_rd_rsp_head                (           MPT_dma_rd_rsp_out_head                ),
    .MPT_dma_rd_rsp_data                (           MPT_dma_rd_rsp_out_data                ),
    .MPT_dma_rd_rsp_last                (           MPT_dma_rd_rsp_out_last                ),
    .MPT_dma_rd_rsp_ready               (           MPT_dma_rd_rsp_out_ready               ),

    .MPT_dma_wr_req_valid               (           MPT_dma_wr_req_in_valid               ),
    .MPT_dma_wr_req_head                (           MPT_dma_wr_req_in_head                ),
    .MPT_dma_wr_req_data                (           MPT_dma_wr_req_in_data                ),
    .MPT_dma_wr_req_last                (           MPT_dma_wr_req_in_last                ),
    .MPT_dma_wr_req_ready               (           MPT_dma_wr_req_in_ready               ),

    .MTT_dma_rd_req_valid               (           MTT_dma_rd_req_valid               ),
    .MTT_dma_rd_req_head                (           MTT_dma_rd_req_head                ),
    .MTT_dma_rd_req_data                (           MTT_dma_rd_req_data                ),
    .MTT_dma_rd_req_last                (           MTT_dma_rd_req_last                ),
    .MTT_dma_rd_req_ready               (           MTT_dma_rd_req_ready               ),

    .MTT_dma_rd_rsp_valid               (           MTT_dma_rd_rsp_out_valid               ),
    .MTT_dma_rd_rsp_head                (           MTT_dma_rd_rsp_out_head                ),
    .MTT_dma_rd_rsp_data                (           MTT_dma_rd_rsp_out_data                ),
    .MTT_dma_rd_rsp_last                (           MTT_dma_rd_rsp_out_last                ),
    .MTT_dma_rd_rsp_ready               (           MTT_dma_rd_rsp_out_ready               ),

    .MTT_dma_wr_req_valid               (           MTT_dma_wr_req_in_valid               ),
    .MTT_dma_wr_req_head                (           MTT_dma_wr_req_in_head                ),
    .MTT_dma_wr_req_data                (           MTT_dma_wr_req_in_data                ),
    .MTT_dma_wr_req_last                (           MTT_dma_wr_req_in_last                ),
    .MTT_dma_wr_req_ready               (           MTT_dma_wr_req_in_ready               ),

    .SQ_dma_rd_req_valid                (           SQ_dma_rd_req_valid                ),
    .SQ_dma_rd_req_head                 (           SQ_dma_rd_req_head                 ),
    .SQ_dma_rd_req_data                 (           SQ_dma_rd_req_data                 ),
    .SQ_dma_rd_req_last                 (           SQ_dma_rd_req_last                 ),
    .SQ_dma_rd_req_ready                (           SQ_dma_rd_req_ready                ),
              
    .SQ_dma_rd_rsp_valid               (           SQ_dma_rd_rsp_out_valid               ),
    .SQ_dma_rd_rsp_head                (           SQ_dma_rd_rsp_out_head                ),
    .SQ_dma_rd_rsp_data                (           SQ_dma_rd_rsp_out_data                ),
    .SQ_dma_rd_rsp_last                (           SQ_dma_rd_rsp_out_last                ),
    .SQ_dma_rd_rsp_ready               (           SQ_dma_rd_rsp_out_ready               ),

    .RQ_dma_rd_req_valid                (           RQ_dma_rd_req_valid                ),
    .RQ_dma_rd_req_head                 (           RQ_dma_rd_req_head                 ),
    .RQ_dma_rd_req_data                 (           RQ_dma_rd_req_data                 ),
    .RQ_dma_rd_req_last                 (           RQ_dma_rd_req_last                 ),
    .RQ_dma_rd_req_ready                (           RQ_dma_rd_req_ready                ),

    .RQ_dma_rd_rsp_valid               (           RQ_dma_rd_rsp_out_valid               ),
    .RQ_dma_rd_rsp_head                (           RQ_dma_rd_rsp_out_head                ),
    .RQ_dma_rd_rsp_data                (           RQ_dma_rd_rsp_out_data                ),
    .RQ_dma_rd_rsp_last                (           RQ_dma_rd_rsp_out_last                ),
    .RQ_dma_rd_rsp_ready               (           RQ_dma_rd_rsp_out_ready               ),

    .TX_REQ_dma_wr_req_valid            (           TX_REQ_dma_wr_req_in_valid            ),
    .TX_REQ_dma_wr_req_last             (           TX_REQ_dma_wr_req_in_last             ),
    .TX_REQ_dma_wr_req_head             (           TX_REQ_dma_wr_req_in_head             ),
    .TX_REQ_dma_wr_req_data             (           TX_REQ_dma_wr_req_in_data             ),
    .TX_REQ_dma_wr_req_ready            (           TX_REQ_dma_wr_req_in_ready            ),

    .RX_REQ_dma_wr_req_valid            (           RX_REQ_dma_wr_req_in_valid            ),
    .RX_REQ_dma_wr_req_last             (           RX_REQ_dma_wr_req_in_last             ),
    .RX_REQ_dma_wr_req_head             (           RX_REQ_dma_wr_req_in_head             ),
    .RX_REQ_dma_wr_req_data             (           RX_REQ_dma_wr_req_in_data             ),
    .RX_REQ_dma_wr_req_ready            (           RX_REQ_dma_wr_req_in_ready            ),

    .RX_RESP_dma_wr_req_valid           (           RX_RESP_dma_wr_req_in_valid           ),
    .RX_RESP_dma_wr_req_last            (           RX_RESP_dma_wr_req_in_last            ),
    .RX_RESP_dma_wr_req_head            (           RX_RESP_dma_wr_req_in_head            ),
    .RX_RESP_dma_wr_req_data            (           RX_RESP_dma_wr_req_in_data            ),
    .RX_RESP_dma_wr_req_ready           (           RX_RESP_dma_wr_req_in_ready           ),

    .TX_REQ_dma_rd_req_valid            (           TX_REQ_dma_rd_req_valid            ),
    .TX_REQ_dma_rd_req_head             (           TX_REQ_dma_rd_req_head             ),
    .TX_REQ_dma_rd_req_data             (           TX_REQ_dma_rd_req_data             ),
    .TX_REQ_dma_rd_req_last             (           TX_REQ_dma_rd_req_last             ),
    .TX_REQ_dma_rd_req_ready            (           TX_REQ_dma_rd_req_ready            ),
    
    .TX_REQ_dma_rd_rsp_valid           (           TX_REQ_dma_rd_rsp_out_valid           ),
    .TX_REQ_dma_rd_rsp_head            (           TX_REQ_dma_rd_rsp_out_head            ),
    .TX_REQ_dma_rd_rsp_data            (           TX_REQ_dma_rd_rsp_out_data            ),
    .TX_REQ_dma_rd_rsp_last            (           TX_REQ_dma_rd_rsp_out_last            ),
    .TX_REQ_dma_rd_rsp_ready           (           TX_REQ_dma_rd_rsp_out_ready           ),

    .TX_RESP_dma_rd_req_valid           (           TX_RESP_dma_rd_req_valid           ),
    .TX_RESP_dma_rd_req_head            (           TX_RESP_dma_rd_req_head            ),
    .TX_RESP_dma_rd_req_data            (           TX_RESP_dma_rd_req_data            ),
    .TX_RESP_dma_rd_req_last            (           TX_RESP_dma_rd_req_last            ),
    .TX_RESP_dma_rd_req_ready           (           TX_RESP_dma_rd_req_ready           ),
    
    .TX_RESP_dma_rd_rsp_valid          (           TX_RESP_dma_rd_rsp_out_valid          ),
    .TX_RESP_dma_rd_rsp_head           (           TX_RESP_dma_rd_rsp_out_head           ),
    .TX_RESP_dma_rd_rsp_data           (           TX_RESP_dma_rd_rsp_out_data           ),
    .TX_RESP_dma_rd_rsp_last           (           TX_RESP_dma_rd_rsp_out_last           ),
    .TX_RESP_dma_rd_rsp_ready          (           TX_RESP_dma_rd_rsp_out_ready          ),

    .mac_tx_valid                       (           mac_tx_valid                       ),
    .mac_tx_ready                       (           mac_tx_ready                       ),
    .mac_tx_start                       (           mac_tx_start                       ),
    .mac_tx_last                        (           mac_tx_last                        ),
    .mac_tx_keep                        (           mac_tx_keep                        ),
    .mac_tx_user                        (           mac_tx_user                        ),
    .mac_tx_data                        (           mac_tx_data                        ),

    .mac_rx_valid                       (           mac_rx_valid                       ),
    .mac_rx_ready                       (           mac_rx_ready                       ),
    .mac_rx_start                       (           mac_rx_start                       ),
    .mac_rx_last                        (           mac_rx_last                        ),
    .mac_rx_keep                        (           mac_rx_keep                        ),
    .mac_rx_user                        (           mac_rx_user                        ),
    .mac_rx_data                        (           mac_rx_data                        )
);

PCIe_Interface PCIe_Interface_Inst(
    .pcie_clk                           (           pcie_clk                                ),
    .pcie_rst_n                         (           ~pcie_rst                               ),
    .user_clk                           (           user_clk                                ),
    .user_rst_n                         (           ~user_rst                               ),

    .rdma_init_done                     (           1'b1                               ),

    .s_axis_rq_tvalid                   (           s_axis_rq_tvalid                   ),
    .s_axis_rq_tlast                    (           s_axis_rq_tlast                    ),
    .s_axis_rq_tkeep                    (           s_axis_rq_tkeep                    ),
    .s_axis_rq_tuser                    (           s_axis_rq_tuser                    ),
    .s_axis_rq_tdata                    (           s_axis_rq_tdata                    ),
    .s_axis_rq_tready                   (           s_axis_rq_tready                   ),

    .m_axis_rc_tvalid                   (           m_axis_rc_tvalid                   ),
    .m_axis_rc_tlast                    (           m_axis_rc_tlast                    ),
    .m_axis_rc_tkeep                    (           m_axis_rc_tkeep                    ),
    .m_axis_rc_tuser                    (           m_axis_rc_tuser                    ),
    .m_axis_rc_tdata                    (           m_axis_rc_tdata                    ),
    .m_axis_rc_tready                   (           m_axis_rc_tready                   ),

    .m_axis_cq_tvalid                   (           m_axis_cq_tvalid                   ),
    .m_axis_cq_tlast                    (           m_axis_cq_tlast                    ),
    .m_axis_cq_tkeep                    (           m_axis_cq_tkeep                    ),
    .m_axis_cq_tuser                    (           m_axis_cq_tuser                    ),
    .m_axis_cq_tdata                    (           m_axis_cq_tdata                    ),
    .m_axis_cq_tready                   (           m_axis_cq_tready                   ),

    .s_axis_cc_tvalid                   (           s_axis_cc_tvalid                   ),
    .s_axis_cc_tlast                    (           s_axis_cc_tlast                    ),
    .s_axis_cc_tkeep                    (           s_axis_cc_tkeep                    ),
    .s_axis_cc_tuser                    (           s_axis_cc_tuser                    ),
    .s_axis_cc_tdata                    (           s_axis_cc_tdata                    ),
    .s_axis_cc_tready                   (           s_axis_cc_tready                   ),

    .cfg_max_payload                    (           cfg_max_payload                    ),
    .cfg_max_read_req                   (           cfg_max_read_req                   ),
    .tl_cfg_busdev                      (           tl_cfg_busdev                      ), 

    .cfg_interrupt_msix_enable          (           cfg_interrupt_msix_enable          ),
    .cfg_interrupt_msix_mask            (           cfg_interrupt_msix_mask            ),
    .cfg_interrupt_msix_data            (           cfg_interrupt_msix_data            ),
    .cfg_interrupt_msix_address         (           cfg_interrupt_msix_address         ),
    .cfg_interrupt_msix_int             (           cfg_interrupt_msix_int             ),
    .cfg_interrupt_msix_sent            (           cfg_interrupt_msix_sent            ),
    .cfg_interrupt_msix_fail            (           cfg_interrupt_msix_fail            ),
    .cfg_interrupt_msi_function_number  (           cfg_interrupt_msi_function_number  ),

    .pio_hcr_in_param                   (           ceu_hcr_in_param                   ),
    .pio_hcr_in_modifier                (           ceu_hcr_in_modifier                ),
    .pio_hcr_out_dma_addr               (           ceu_hcr_out_dma_addr               ),
    .pio_hcr_out_param                  (           ceu_hcr_out_param                  ),
    .pio_hcr_token                      (           ceu_hcr_token                      ),
    .pio_hcr_status                     (           ceu_hcr_status                     ),
    .pio_hcr_go                         (           ceu_hcr_go                         ),
    .pio_hcr_clear                      (           ceu_hcr_clear                      ),
    .pio_hcr_event                      (           ceu_hcr_event                      ),
    .pio_hcr_op_modifier                (           ceu_hcr_op_modifier                ),
    .pio_hcr_op                         (           ceu_hcr_op                         ),

    .cmd_rst                            (                                               ),

    .pio_uar_db_valid                   (           db_fifo_wen                         ),
    .pio_uar_db_data                    (           db_fifo_din                         ),
    .pio_uar_db_ready                   (           !db_fifo_prog_full                  ),

    .cq_ren                             (           'd0                                 ),
    .cq_num                             (           'd0                                 ),
    .cq_dout                            (                                               ),

    .eq_ren                             (           'd0                                 ),
    .eq_num                             (           'd0                                 ),
    .eq_dout                            (                                               ),

    .pio_eq_int_req_valid               (           'd0                                 ),
    .pio_eq_int_req_num                 (           'd0                                 ),
    .pio_eq_int_req_ready               (                                               ),

    .pio_eq_int_rsp_valid               (                                               ),
    .pio_eq_int_rsp_data                (                                               ),
    .pio_eq_int_rsp_ready               (           'd0                                 ),

    .m_axi_awaddr                       (                                               ),
    .m_axi_awvalid                      (                                               ),
    .m_axi_awready                      (           'd0                                 ),

    .m_axi_wdata                        (                                               ),
    .m_axi_wstrb                        (                                               ),
    .m_axi_wvalid                       (                                               ),
    .m_axi_wready                       (           'd0                                 ),

    .m_axi_bvalid                       (           'd0                                 ),
    .m_axi_bready                       (                                               ),

    .m_axi_araddr                       (                                               ),
    .m_axi_arvalid                      (                                               ),
    .m_axi_arready                      (           'd0                                 ),
    
    .m_axi_rdata                        (           'd0                                 ),
    .m_axi_rvalid                       (           'd0                                 ),
    .m_axi_rready                       (                                               ),

    .dma_rd_req_valid                   (           DMA_RD_req_valid                    ),
    .dma_rd_req_last                    (           DMA_RD_req_last                     ),
    .dma_rd_req_data                    (           DMA_RD_req_data                     ),
    .dma_rd_req_head                    (           DMA_RD_req_head                     ),
    .dma_rd_req_ready                   (           DMA_RD_req_ready                    ),

    .dma_rd_rsp_valid                   (           DMA_RD_rsp_in_valid                   ),
    .dma_rd_rsp_last                    (           DMA_RD_rsp_in_last                    ),
    .dma_rd_rsp_data                    (           DMA_RD_rsp_in_data                    ),
    .dma_rd_rsp_head                    (           DMA_RD_rsp_in_head                    ),
    .dma_rd_rsp_ready                   (           DMA_RD_rsp_in_ready                   ),

    .dma_wr_req_valid                   (           DMA_WR_req_out_valid                    ), 
    .dma_wr_req_last                    (           DMA_WR_req_out_last                     ), 
    .dma_wr_req_data                    (           DMA_WR_req_out_data                     ), 
    .dma_wr_req_head                    (           DMA_WR_req_out_head                     ), 
    .dma_wr_req_ready                   (           DMA_WR_req_out_ready                    ),

    .p2p_upper_valid                    (           'd0                                 ),
    .p2p_upper_last                     (           'd0                                 ),
    .p2p_upper_data                     (           'd0                                 ),
    .p2p_upper_head                     (           'd0                                 ),
    .p2p_upper_ready                    (                                               ),

    .p2p_down_valid                     (                                               ), 
    .p2p_down_last                      (                                               ), 
    .p2p_down_data                      (                                               ), 
    .p2p_down_head                      (                                               ), 
    .p2p_down_ready                     (           'd0                                 )
);

SyncFIFO_Template #(
    .FIFO_TYPE                          (       0                   ),
    .FIFO_WIDTH                         (       64                  ),
    .FIFO_DEPTH                         (       128                 )
)
DoorbellFIFO_Inst
(
    .clk                                (       user_clk                 ),
    .rst                                (       user_rst                 ),

    .wr_en                              (       db_fifo_wen         ),
    .din                                (       db_fifo_din         ),
    .prog_full                          (       db_fifo_prog_full   ),

    .rd_en                              (       db_fifo_ren         ),
    .dout                               (       db_fifo_dout        ),
    .empty                              (       db_fifo_empty       )
);

DMA_Channel_Top DMA_Channel_Top_Inst
(
	.clk								(			user_clk									),
	.rst								(			user_rst									),

	.CEU_dma_wr_req_in_valid			(			CEU_dma_wr_req_in_valid				),
	.CEU_dma_wr_req_in_head				(			CEU_dma_wr_req_in_head				),
	.CEU_dma_wr_req_in_data				(			CEU_dma_wr_req_in_data				),
	.CEU_dma_wr_req_in_last				(			CEU_dma_wr_req_in_last				),
	.CEU_dma_wr_req_in_ready			(			CEU_dma_wr_req_in_ready				),

	.CEU_dma_wr_req_out_valid			(			CEU_dma_wr_req_out_valid			),
	.CEU_dma_wr_req_out_head			(			CEU_dma_wr_req_out_head				),
	.CEU_dma_wr_req_out_data			(			CEU_dma_wr_req_out_data				),
	.CEU_dma_wr_req_out_last			(			CEU_dma_wr_req_out_last				),
	.CEU_dma_wr_req_out_ready			(			CEU_dma_wr_req_out_ready			),

	.QPC_dma_wr_req_in_valid			(			QPC_dma_wr_req_in_valid				),
	.QPC_dma_wr_req_in_head				(			QPC_dma_wr_req_in_head				),
	.QPC_dma_wr_req_in_data				(			QPC_dma_wr_req_in_data				),
	.QPC_dma_wr_req_in_last				(			QPC_dma_wr_req_in_last				),
	.QPC_dma_wr_req_in_ready			(			QPC_dma_wr_req_in_ready				),

	.QPC_dma_wr_req_out_valid			(			QPC_dma_wr_req_out_valid			),
	.QPC_dma_wr_req_out_head			(			QPC_dma_wr_req_out_head				),
	.QPC_dma_wr_req_out_data			(			QPC_dma_wr_req_out_data				),
	.QPC_dma_wr_req_out_last			(			QPC_dma_wr_req_out_last				),
	.QPC_dma_wr_req_out_ready			(			QPC_dma_wr_req_out_ready			),

	.CQC_dma_wr_req_in_valid			(			CQC_dma_wr_req_in_valid				),
	.CQC_dma_wr_req_in_head				(			CQC_dma_wr_req_in_head				),
	.CQC_dma_wr_req_in_data				(			CQC_dma_wr_req_in_data				),
	.CQC_dma_wr_req_in_last				(			CQC_dma_wr_req_in_last				),
	.CQC_dma_wr_req_in_ready			(			CQC_dma_wr_req_in_ready				),

	.CQC_dma_wr_req_out_valid			(			CQC_dma_wr_req_out_valid			),
	.CQC_dma_wr_req_out_head			(			CQC_dma_wr_req_out_head				),
	.CQC_dma_wr_req_out_data			(			CQC_dma_wr_req_out_data				),
	.CQC_dma_wr_req_out_last			(			CQC_dma_wr_req_out_last				),
	.CQC_dma_wr_req_out_ready			(			CQC_dma_wr_req_out_ready			),

	.EQC_dma_wr_req_in_valid			(			EQC_dma_wr_req_in_valid				),
	.EQC_dma_wr_req_in_head				(			EQC_dma_wr_req_in_head				),
	.EQC_dma_wr_req_in_data				(			EQC_dma_wr_req_in_data				),
	.EQC_dma_wr_req_in_last				(			EQC_dma_wr_req_in_last				),
	.EQC_dma_wr_req_in_ready			(			EQC_dma_wr_req_in_ready				),

	.EQC_dma_wr_req_out_valid			(			EQC_dma_wr_req_out_valid			),
	.EQC_dma_wr_req_out_head			(			EQC_dma_wr_req_out_head				),
	.EQC_dma_wr_req_out_data			(			EQC_dma_wr_req_out_data				),
	.EQC_dma_wr_req_out_last			(			EQC_dma_wr_req_out_last				),
	.EQC_dma_wr_req_out_ready			(			EQC_dma_wr_req_out_ready			),

	.MPT_dma_wr_req_in_valid			(			MPT_dma_wr_req_in_valid				),
	.MPT_dma_wr_req_in_head				(			MPT_dma_wr_req_in_head				),
	.MPT_dma_wr_req_in_data				(			MPT_dma_wr_req_in_data				),
	.MPT_dma_wr_req_in_last				(			MPT_dma_wr_req_in_last				),
	.MPT_dma_wr_req_in_ready			(			MPT_dma_wr_req_in_ready				),

	.MPT_dma_wr_req_out_valid			(			MPT_dma_wr_req_out_valid			),
	.MPT_dma_wr_req_out_head			(			MPT_dma_wr_req_out_head				),
	.MPT_dma_wr_req_out_data			(			MPT_dma_wr_req_out_data				),
	.MPT_dma_wr_req_out_last			(			MPT_dma_wr_req_out_last				),
	.MPT_dma_wr_req_out_ready			(			MPT_dma_wr_req_out_ready			),

	.MTT_dma_wr_req_in_valid			(			MTT_dma_wr_req_in_valid				),
	.MTT_dma_wr_req_in_head				(			MTT_dma_wr_req_in_head				),
	.MTT_dma_wr_req_in_data				(			MTT_dma_wr_req_in_data				),
	.MTT_dma_wr_req_in_last				(			MTT_dma_wr_req_in_last				),
	.MTT_dma_wr_req_in_ready			(			MTT_dma_wr_req_in_ready				),

	.MTT_dma_wr_req_out_valid			(			MTT_dma_wr_req_out_valid			),
	.MTT_dma_wr_req_out_head			(			MTT_dma_wr_req_out_head				),
	.MTT_dma_wr_req_out_data			(			MTT_dma_wr_req_out_data				),
	.MTT_dma_wr_req_out_last			(			MTT_dma_wr_req_out_last				),
	.MTT_dma_wr_req_out_ready			(			MTT_dma_wr_req_out_ready			),

	.TX_REQ_dma_wr_req_in_valid			(			TX_REQ_dma_wr_req_in_valid			),
	.TX_REQ_dma_wr_req_in_head			(			TX_REQ_dma_wr_req_in_head			),
	.TX_REQ_dma_wr_req_in_data			(			TX_REQ_dma_wr_req_in_data			),
	.TX_REQ_dma_wr_req_in_last			(			TX_REQ_dma_wr_req_in_last			),
	.TX_REQ_dma_wr_req_in_ready			(			TX_REQ_dma_wr_req_in_ready			),

	.TX_REQ_dma_wr_req_out_valid		(			TX_REQ_dma_wr_req_out_valid			),
	.TX_REQ_dma_wr_req_out_head			(			TX_REQ_dma_wr_req_out_head			),
	.TX_REQ_dma_wr_req_out_data			(			TX_REQ_dma_wr_req_out_data			),
	.TX_REQ_dma_wr_req_out_last			(			TX_REQ_dma_wr_req_out_last			),
	.TX_REQ_dma_wr_req_out_ready		(			TX_REQ_dma_wr_req_out_ready			),

	.RX_REQ_dma_wr_req_in_valid			(			RX_REQ_dma_wr_req_in_valid			),
	.RX_REQ_dma_wr_req_in_head			(			RX_REQ_dma_wr_req_in_head			),
	.RX_REQ_dma_wr_req_in_data			(			RX_REQ_dma_wr_req_in_data			),
	.RX_REQ_dma_wr_req_in_last			(			RX_REQ_dma_wr_req_in_last			),
	.RX_REQ_dma_wr_req_in_ready			(			RX_REQ_dma_wr_req_in_ready			),

	.RX_REQ_dma_wr_req_out_valid		(			RX_REQ_dma_wr_req_out_valid			),
	.RX_REQ_dma_wr_req_out_head			(			RX_REQ_dma_wr_req_out_head			),
	.RX_REQ_dma_wr_req_out_data			(			RX_REQ_dma_wr_req_out_data			),
	.RX_REQ_dma_wr_req_out_last			(			RX_REQ_dma_wr_req_out_last			),
	.RX_REQ_dma_wr_req_out_ready		(			RX_REQ_dma_wr_req_out_ready			),

	.RX_RESP_dma_wr_req_in_valid		(			RX_RESP_dma_wr_req_in_valid			),
	.RX_RESP_dma_wr_req_in_head			(			RX_RESP_dma_wr_req_in_head			),
	.RX_RESP_dma_wr_req_in_data			(			RX_RESP_dma_wr_req_in_data			),
	.RX_RESP_dma_wr_req_in_last			(			RX_RESP_dma_wr_req_in_last			),
	.RX_RESP_dma_wr_req_in_ready		(			RX_RESP_dma_wr_req_in_ready			),

	.RX_RESP_dma_wr_req_out_valid		(			RX_RESP_dma_wr_req_out_valid		),
	.RX_RESP_dma_wr_req_out_head		(			RX_RESP_dma_wr_req_out_head			),
	.RX_RESP_dma_wr_req_out_data		(			RX_RESP_dma_wr_req_out_data			),
	.RX_RESP_dma_wr_req_out_last		(			RX_RESP_dma_wr_req_out_last			),
	.RX_RESP_dma_wr_req_out_ready		(			RX_RESP_dma_wr_req_out_ready		),

	.CEU_dma_rd_rsp_in_valid			(			CEU_dma_rd_rsp_in_valid				),
	.CEU_dma_rd_rsp_in_head				(			CEU_dma_rd_rsp_in_head				),
	.CEU_dma_rd_rsp_in_data				(			CEU_dma_rd_rsp_in_data				),
	.CEU_dma_rd_rsp_in_last				(			CEU_dma_rd_rsp_in_last				),
	.CEU_dma_rd_rsp_in_ready			(			CEU_dma_rd_rsp_in_ready				),

	.CEU_dma_rd_rsp_out_valid			(			CEU_dma_rd_rsp_out_valid			),
	.CEU_dma_rd_rsp_out_head			(			CEU_dma_rd_rsp_out_head				),
	.CEU_dma_rd_rsp_out_data			(			CEU_dma_rd_rsp_out_data				),
	.CEU_dma_rd_rsp_out_last			(			CEU_dma_rd_rsp_out_last				),
	.CEU_dma_rd_rsp_out_ready			(			CEU_dma_rd_rsp_out_ready			),

	.SQ_dma_rd_rsp_in_valid				(			SQ_dma_rd_rsp_in_valid				),
	.SQ_dma_rd_rsp_in_head				(			SQ_dma_rd_rsp_in_head				),
	.SQ_dma_rd_rsp_in_data				(			SQ_dma_rd_rsp_in_data				),
	.SQ_dma_rd_rsp_in_last				(			SQ_dma_rd_rsp_in_last				),
	.SQ_dma_rd_rsp_in_ready				(			SQ_dma_rd_rsp_in_ready				),

	.SQ_dma_rd_rsp_out_valid			(			SQ_dma_rd_rsp_out_valid				),
	.SQ_dma_rd_rsp_out_head				(			SQ_dma_rd_rsp_out_head				),
	.SQ_dma_rd_rsp_out_data				(			SQ_dma_rd_rsp_out_data				),
	.SQ_dma_rd_rsp_out_last				(			SQ_dma_rd_rsp_out_last				),
	.SQ_dma_rd_rsp_out_ready			(			SQ_dma_rd_rsp_out_ready				),

	.RQ_dma_rd_rsp_in_valid				(			RQ_dma_rd_rsp_in_valid				),
	.RQ_dma_rd_rsp_in_head				(			RQ_dma_rd_rsp_in_head				),
	.RQ_dma_rd_rsp_in_data				(			RQ_dma_rd_rsp_in_data				),
	.RQ_dma_rd_rsp_in_last				(			RQ_dma_rd_rsp_in_last				),
	.RQ_dma_rd_rsp_in_ready				(			RQ_dma_rd_rsp_in_ready				),

	.RQ_dma_rd_rsp_out_valid			(			RQ_dma_rd_rsp_out_valid				),
	.RQ_dma_rd_rsp_out_head				(			RQ_dma_rd_rsp_out_head				),
	.RQ_dma_rd_rsp_out_data				(			RQ_dma_rd_rsp_out_data				),
	.RQ_dma_rd_rsp_out_last				(			RQ_dma_rd_rsp_out_last				),
	.RQ_dma_rd_rsp_out_ready			(			RQ_dma_rd_rsp_out_ready				),

	.QPC_dma_rd_rsp_in_valid			(			QPC_dma_rd_rsp_in_valid				),
	.QPC_dma_rd_rsp_in_head				(			QPC_dma_rd_rsp_in_head				),
	.QPC_dma_rd_rsp_in_data				(			QPC_dma_rd_rsp_in_data				),
	.QPC_dma_rd_rsp_in_last				(			QPC_dma_rd_rsp_in_last				),
	.QPC_dma_rd_rsp_in_ready			(			QPC_dma_rd_rsp_in_ready				),

	.QPC_dma_rd_rsp_out_valid			(			QPC_dma_rd_rsp_out_valid			),
	.QPC_dma_rd_rsp_out_head			(			QPC_dma_rd_rsp_out_head				),
	.QPC_dma_rd_rsp_out_data			(			QPC_dma_rd_rsp_out_data				),
	.QPC_dma_rd_rsp_out_last			(			QPC_dma_rd_rsp_out_last				),
	.QPC_dma_rd_rsp_out_ready			(			QPC_dma_rd_rsp_out_ready			),

	.CQC_dma_rd_rsp_in_valid			(			CQC_dma_rd_rsp_in_valid				),
	.CQC_dma_rd_rsp_in_head				(			CQC_dma_rd_rsp_in_head				),
	.CQC_dma_rd_rsp_in_data				(			CQC_dma_rd_rsp_in_data				),
	.CQC_dma_rd_rsp_in_last				(			CQC_dma_rd_rsp_in_last				),
	.CQC_dma_rd_rsp_in_ready			(			CQC_dma_rd_rsp_in_ready				),

	.CQC_dma_rd_rsp_out_valid			(			CQC_dma_rd_rsp_out_valid			),
	.CQC_dma_rd_rsp_out_head			(			CQC_dma_rd_rsp_out_head				),
	.CQC_dma_rd_rsp_out_data			(			CQC_dma_rd_rsp_out_data				),
	.CQC_dma_rd_rsp_out_last			(			CQC_dma_rd_rsp_out_last				),
	.CQC_dma_rd_rsp_out_ready			(			CQC_dma_rd_rsp_out_ready			),

	.EQC_dma_rd_rsp_in_valid			(			EQC_dma_rd_rsp_in_valid				),
	.EQC_dma_rd_rsp_in_head				(			EQC_dma_rd_rsp_in_head				),
	.EQC_dma_rd_rsp_in_data				(			EQC_dma_rd_rsp_in_data				),
	.EQC_dma_rd_rsp_in_last				(			EQC_dma_rd_rsp_in_last				),
	.EQC_dma_rd_rsp_in_ready			(			EQC_dma_rd_rsp_in_ready				),

	.EQC_dma_rd_rsp_out_valid			(			EQC_dma_rd_rsp_out_valid			),
	.EQC_dma_rd_rsp_out_head			(			EQC_dma_rd_rsp_out_head				),
	.EQC_dma_rd_rsp_out_data			(			EQC_dma_rd_rsp_out_data				),
	.EQC_dma_rd_rsp_out_last			(			EQC_dma_rd_rsp_out_last				),
	.EQC_dma_rd_rsp_out_ready			(			EQC_dma_rd_rsp_out_ready			),

	.MPT_dma_rd_rsp_in_valid			(			MPT_dma_rd_rsp_in_valid				),
	.MPT_dma_rd_rsp_in_head				(			MPT_dma_rd_rsp_in_head				),
	.MPT_dma_rd_rsp_in_data				(			MPT_dma_rd_rsp_in_data				),
	.MPT_dma_rd_rsp_in_last				(			MPT_dma_rd_rsp_in_last				),
	.MPT_dma_rd_rsp_in_ready			(			MPT_dma_rd_rsp_in_ready				),

	.MPT_dma_rd_rsp_out_valid			(			MPT_dma_rd_rsp_out_valid			),
	.MPT_dma_rd_rsp_out_head			(			MPT_dma_rd_rsp_out_head				),
	.MPT_dma_rd_rsp_out_data			(			MPT_dma_rd_rsp_out_data				),
	.MPT_dma_rd_rsp_out_last			(			MPT_dma_rd_rsp_out_last				),
	.MPT_dma_rd_rsp_out_ready			(			MPT_dma_rd_rsp_out_ready			),

	.MTT_dma_rd_rsp_in_valid			(			MTT_dma_rd_rsp_in_valid				),
	.MTT_dma_rd_rsp_in_head				(			MTT_dma_rd_rsp_in_head				),
	.MTT_dma_rd_rsp_in_data				(			MTT_dma_rd_rsp_in_data				),
	.MTT_dma_rd_rsp_in_last				(			MTT_dma_rd_rsp_in_last				),
	.MTT_dma_rd_rsp_in_ready			(			MTT_dma_rd_rsp_in_ready				),

	.MTT_dma_rd_rsp_out_valid			(			MTT_dma_rd_rsp_out_valid			),
	.MTT_dma_rd_rsp_out_head			(			MTT_dma_rd_rsp_out_head				),
	.MTT_dma_rd_rsp_out_data			(			MTT_dma_rd_rsp_out_data				),
	.MTT_dma_rd_rsp_out_last			(			MTT_dma_rd_rsp_out_last				),
	.MTT_dma_rd_rsp_out_ready			(			MTT_dma_rd_rsp_out_ready			),

	.TX_REQ_dma_rd_rsp_in_valid			(			TX_REQ_dma_rd_rsp_in_valid			),
	.TX_REQ_dma_rd_rsp_in_head			(			TX_REQ_dma_rd_rsp_in_head			),
	.TX_REQ_dma_rd_rsp_in_data			(			TX_REQ_dma_rd_rsp_in_data			),
	.TX_REQ_dma_rd_rsp_in_last			(			TX_REQ_dma_rd_rsp_in_last			),
	.TX_REQ_dma_rd_rsp_in_ready			(			TX_REQ_dma_rd_rsp_in_ready			),

	.TX_REQ_dma_rd_rsp_out_valid		(			TX_REQ_dma_rd_rsp_out_valid			),
	.TX_REQ_dma_rd_rsp_out_head			(			TX_REQ_dma_rd_rsp_out_head			),
	.TX_REQ_dma_rd_rsp_out_data			(			TX_REQ_dma_rd_rsp_out_data			),
	.TX_REQ_dma_rd_rsp_out_last			(			TX_REQ_dma_rd_rsp_out_last			),
	.TX_REQ_dma_rd_rsp_out_ready		(			TX_REQ_dma_rd_rsp_out_ready			),

	.TX_RESP_dma_rd_rsp_in_valid		(			TX_RESP_dma_rd_rsp_in_valid			),
	.TX_RESP_dma_rd_rsp_in_head			(			TX_RESP_dma_rd_rsp_in_head			),
	.TX_RESP_dma_rd_rsp_in_data			(			TX_RESP_dma_rd_rsp_in_data			),
	.TX_RESP_dma_rd_rsp_in_last			(			TX_RESP_dma_rd_rsp_in_last			),
	.TX_RESP_dma_rd_rsp_in_ready		(			TX_RESP_dma_rd_rsp_in_ready			),

	.TX_RESP_dma_rd_rsp_out_valid		(			TX_RESP_dma_rd_rsp_out_valid		),
	.TX_RESP_dma_rd_rsp_out_head		(			TX_RESP_dma_rd_rsp_out_head			),
	.TX_RESP_dma_rd_rsp_out_data		(			TX_RESP_dma_rd_rsp_out_data			),
	.TX_RESP_dma_rd_rsp_out_last		(			TX_RESP_dma_rd_rsp_out_last			),
	.TX_RESP_dma_rd_rsp_out_ready		(			TX_RESP_dma_rd_rsp_out_ready		)
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
assign DMA_RD_req_valid = {     TX_RESP_dma_rd_req_valid,
                                TX_REQ_dma_rd_req_valid,
                                MTT_dma_rd_req_valid,
                                MPT_dma_rd_req_valid,
                                EQC_dma_rd_req_valid,
                                CQC_dma_rd_req_valid,
                                QPC_dma_rd_req_valid,
                                RQ_dma_rd_req_valid,
                                SQ_dma_rd_req_valid,
                                CEU_dma_rd_req_valid
                            };

assign DMA_RD_req_head = {      TX_RESP_dma_rd_req_head,
                                TX_REQ_dma_rd_req_head,
                                MTT_dma_rd_req_head,
                                MPT_dma_rd_req_head,
                                EQC_dma_rd_req_head,
                                CQC_dma_rd_req_head,
                                QPC_dma_rd_req_head,
                                RQ_dma_rd_req_head,
                                SQ_dma_rd_req_head,
                                CEU_dma_rd_req_head
                            };

assign DMA_RD_req_last = {      TX_RESP_dma_rd_req_last,
                                TX_REQ_dma_rd_req_last,
                                MTT_dma_rd_req_last,
                                MPT_dma_rd_req_last,
                                EQC_dma_rd_req_last,
                                CQC_dma_rd_req_last,
                                QPC_dma_rd_req_last,
                                RQ_dma_rd_req_last,
                                SQ_dma_rd_req_last,
                                CEU_dma_rd_req_last
                            };

assign DMA_RD_req_data = {      256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0,
                                256'd0
                         };

assign TX_RESP_dma_rd_req_ready = DMA_RD_req_ready[9];
assign TX_REQ_dma_rd_req_ready = DMA_RD_req_ready[8];
assign MTT_dma_rd_req_ready = DMA_RD_req_ready[7];
assign MPT_dma_rd_req_ready = DMA_RD_req_ready[6];
assign EQC_dma_rd_req_ready = DMA_RD_req_ready[5];
assign CQC_dma_rd_req_ready = DMA_RD_req_ready[4];
assign QPC_dma_rd_req_ready = DMA_RD_req_ready[3];
assign RQ_dma_rd_req_ready = DMA_RD_req_ready[2];
assign SQ_dma_rd_req_ready = DMA_RD_req_ready[1];
assign CEU_dma_rd_req_ready = DMA_RD_req_ready[0];

assign TX_RESP_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[9];
assign TX_REQ_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[8];
assign MTT_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[7];
assign MPT_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[6];
assign EQC_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[5];
assign CQC_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[4];
assign QPC_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[3];
assign RQ_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[2];
assign SQ_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[1];
assign CEU_dma_rd_rsp_in_valid = DMA_RD_rsp_in_valid[0];

assign TX_RESP_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[10 * `DMA_HEAD_WIDTH - 1 : 9 * `DMA_HEAD_WIDTH];
assign TX_REQ_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[9 * `DMA_HEAD_WIDTH - 1 : 8 * `DMA_HEAD_WIDTH];
assign MTT_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[8 * `DMA_HEAD_WIDTH - 1 : 7 * `DMA_HEAD_WIDTH];
assign MPT_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[7 * `DMA_HEAD_WIDTH - 1 : 6 * `DMA_HEAD_WIDTH];
assign EQC_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[6 * `DMA_HEAD_WIDTH - 1 : 5 * `DMA_HEAD_WIDTH];
assign CQC_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[5 * `DMA_HEAD_WIDTH - 1 : 4 * `DMA_HEAD_WIDTH];
assign QPC_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[4 * `DMA_HEAD_WIDTH - 1 : 3 * `DMA_HEAD_WIDTH];
assign RQ_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[3 * `DMA_HEAD_WIDTH - 1 : 2 * `DMA_HEAD_WIDTH];
assign SQ_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[2 * `DMA_HEAD_WIDTH - 1 : 1 * `DMA_HEAD_WIDTH];
assign CEU_dma_rd_rsp_in_head = DMA_RD_rsp_in_head[1 * `DMA_HEAD_WIDTH - 1 : 0 * `DMA_HEAD_WIDTH];

assign TX_RESP_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[10 * 256 - 1 : 9 * 256];
assign TX_REQ_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[9 * 256 - 1 : 8 * 256];
assign MTT_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[8 * 256 - 1 : 7 * 256];
assign MPT_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[7 * 256 - 1 : 6 * 256];
assign EQC_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[6 * 256 - 1 : 5 * 256];
assign CQC_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[5 * 256 - 1 : 4 * 256];
assign QPC_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[4 * 256 - 1 : 3 * 256];
assign RQ_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[3 * 256 - 1 : 2 * 256];
assign SQ_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[2 * 256 - 1 : 1 * 256];
assign CEU_dma_rd_rsp_in_data = DMA_RD_rsp_in_data[1 * 256 - 1 : 0 * 256];

assign TX_RESP_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[9];
assign TX_REQ_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[8];
assign MTT_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[7];
assign MPT_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[6];
assign EQC_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[5];
assign CQC_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[4];
assign QPC_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[3];
assign RQ_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[2];
assign SQ_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[1];
assign CEU_dma_rd_rsp_in_last = DMA_RD_rsp_in_last[0];

assign DMA_RD_rsp_in_ready = {  TX_RESP_dma_rd_rsp_in_ready,
                                TX_REQ_dma_rd_rsp_in_ready,
                                MTT_dma_rd_rsp_in_ready,
                                MPT_dma_rd_rsp_in_ready,
                                EQC_dma_rd_rsp_in_ready,
                                CQC_dma_rd_rsp_in_ready,
                                QPC_dma_rd_rsp_in_ready,
                                RQ_dma_rd_rsp_in_ready,
                                SQ_dma_rd_rsp_in_ready,
                                CEU_dma_rd_rsp_in_ready
                            };


assign DMA_WR_req_out_valid = { 
                                RX_RESP_dma_wr_req_out_valid,
                                RX_REQ_dma_wr_req_out_valid, 
                                TX_REQ_dma_wr_req_out_valid,
                                MTT_dma_wr_req_out_valid,
                                MPT_dma_wr_req_out_valid,
                                EQC_dma_wr_req_out_valid,
                                CQC_dma_wr_req_out_valid,
                                QPC_dma_wr_req_out_valid,
                                CEU_dma_wr_req_out_valid
                            };

assign DMA_WR_req_out_head = {      
                                RX_RESP_dma_wr_req_out_head,
                                RX_REQ_dma_wr_req_out_head, 
                                TX_REQ_dma_wr_req_out_head,
                                MTT_dma_wr_req_out_head,
                                MPT_dma_wr_req_out_head,
                                EQC_dma_wr_req_out_head,
                                CQC_dma_wr_req_out_head,
                                QPC_dma_wr_req_out_head,
                                CEU_dma_wr_req_out_head
                            };

assign DMA_WR_req_out_data = {      
                                RX_RESP_dma_wr_req_out_data,
                                RX_REQ_dma_wr_req_out_data, 
                                TX_REQ_dma_wr_req_out_data,
                                MTT_dma_wr_req_out_data,
                                MPT_dma_wr_req_out_data,
                                EQC_dma_wr_req_out_data,
                                CQC_dma_wr_req_out_data,
                                QPC_dma_wr_req_out_data,
                                CEU_dma_wr_req_out_data
                            };

assign DMA_WR_req_out_last = {    
                                RX_RESP_dma_wr_req_out_last,
                                RX_REQ_dma_wr_req_out_last, 
                                TX_REQ_dma_wr_req_out_last,
                                MTT_dma_wr_req_out_last,
                                MPT_dma_wr_req_out_last,
                                EQC_dma_wr_req_out_last,
                                CQC_dma_wr_req_out_last,
                                QPC_dma_wr_req_out_last,
                                CEU_dma_wr_req_out_last
                            };

 assign RX_RESP_dma_wr_req_out_ready = DMA_WR_req_out_ready[8];
 assign RX_REQ_dma_wr_req_out_ready = DMA_WR_req_out_ready[7];
 assign TX_REQ_dma_wr_req_out_ready = DMA_WR_req_out_ready[6];
 assign MTT_dma_wr_req_out_ready = DMA_WR_req_out_ready[5];
 assign MPT_dma_wr_req_out_ready = DMA_WR_req_out_ready[4];
 assign EQC_dma_wr_req_out_ready = DMA_WR_req_out_ready[3];
 assign CQC_dma_wr_req_out_ready = DMA_WR_req_out_ready[2];
 assign QPC_dma_wr_req_out_ready = DMA_WR_req_out_ready[1];
 assign CEU_dma_wr_req_out_ready = DMA_WR_req_out_ready[0];
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

`ifdef ILA_ON
//  ila_dma CEU_dma_rd_req (
//     .clk(user_clk),

//     .probe0(CEU_dma_rd_req_valid),
//     .probe1(CEU_dma_rd_req_head),
//     .probe2(CEU_dma_rd_req_data),
//     .probe3(CEU_dma_rd_req_last),
//     .probe4(CEU_dma_rd_req_ready)
// );

// ila_dma CEU_dma_rd_rsp (
//     .clk(user_clk),

//     .probe0(CEU_dma_rd_rsp_in_valid),
//     .probe1(CEU_dma_rd_rsp_in_head),
//     .probe2(CEU_dma_rd_rsp_in_data),
//     .probe3(CEU_dma_rd_rsp_in_last),
//     .probe4(CEU_dma_rd_rsp_in_ready)
// );


//  ila_dma TX_REQ_dma_rd_req (
//     .clk(user_clk),

//     .probe0(TX_REQ_dma_rd_req_valid),
//     .probe1(TX_REQ_dma_rd_req_head),
//     .probe2(TX_REQ_dma_rd_req_data),
//     .probe3(TX_REQ_dma_rd_req_last),
//     .probe4(TX_REQ_dma_rd_req_ready)
// );

// ila_dma TX_REQ_dma_rd_rsp (
//     .clk(user_clk),

//     .probe0(TX_REQ_dma_rd_rsp_in_valid),
//     .probe1(TX_REQ_dma_rd_rsp_in_head),
//     .probe2(TX_REQ_dma_rd_rsp_in_data),
//     .probe3(TX_REQ_dma_rd_rsp_in_last),
//     .probe4(TX_REQ_dma_rd_rsp_in_ready)
// );

// ila_mac ila_mac_tx_inst(
//     .clk(mac_tx_clk),

//     .probe0(mac_tx_valid),
//     .probe1(mac_tx_ready),
//     .probe2(mac_tx_start),
//     .probe3(mac_tx_last),
//     .probe4(mac_tx_keep),
//     .probe5(mac_tx_data)
// );

// ila_mac ila_mac_rx_inst(
//     .clk(mac_rx_clk),

//     .probe0(mac_rx_valid),
//     .probe1(mac_rx_ready),
//     .probe2(mac_rx_start),
//     .probe3(mac_rx_last),
//     .probe4(mac_rx_keep),
//     .probe5(mac_rx_data)
// );

//  ila_dma qpc_dma_wr_req (
//     .clk(user_clk),

//     .probe0(QPC_dma_wr_req_out_valid),
//     .probe1(QPC_dma_wr_req_out_head),
//     .probe2(QPC_dma_wr_req_out_data),
//     .probe3(QPC_dma_wr_req_out_last),
//     .probe4(QPC_dma_wr_req_out_ready)
// );
`endif

endmodule