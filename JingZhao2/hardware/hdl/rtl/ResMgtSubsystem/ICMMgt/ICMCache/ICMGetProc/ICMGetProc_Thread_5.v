/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMGetProc_Thread_5
Author:     YangFan
Function:   Extract needed ICM info from DMA Response.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMGetProc_Thread_5
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       log2b(ICM_ENTRY_NUM * ICM_SLOT_SIZE - 1),
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(ICM_SLOT_SIZE - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       `PHY_SPACE_ADDR_WIDTH,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       32,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//DMA Read Rsp Interface
    input   wire                                                                                                dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                   dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                   dma_rd_rsp_data,
    input   wire                                                                                                dma_rd_rsp_last,
    output  wire                                                                                                dma_rd_rsp_ready,

//ICM Entry from Memory
    output  wire                                                                                                icm_entry_rsp_valid,
    output  reg     [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_entry_rsp_data,
    input   wire                                                                                                icm_entry_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                         [2:0]               piece_count;
reg                         [2:0]               piece_num;

//QPC Info
wire                        [2:0]               service_type;
wire                        [3:0]               state;
wire                        [7:0]               mtu_msgmax;
wire                        [7:0]               sq_entry_sz_log;
wire                        [7:0]               rq_entry_sz_log;
wire                        [15:0]              dst_qpn;
wire                        [7:0]               pkey_index;
wire                        [7:0]               port_index;
wire                        [15:0]              cqn_snd;
wire                        [15:0]              cqn_rcv;
wire                        [31:0]              qp_pd;
wire                        [31:0]              sq_lkey;
wire                        [31:0]              sq_length;
wire                        [31:0]              rq_lkey;
wire                        [31:0]              rq_length;
wire                        [15:0]              dmac_low_dlid;
wire                        [15:0]              smac_low_slid;
wire                        [31:0]              dmac_high;
wire                        [31:0]              smac_high;
wire                        [31:0]              dip;
wire                        [31:0]              sip;
    
//CQC Info
wire                        [7:0]               cq_log_size;
wire                        [31:0]              comp_eqn;
wire                        [31:0]              cq_pd;
wire                        [31:0]              cq_lkey;
        
//EQC Info
wire                        [7:0]               eq_log_size;
wire                        [7:0]               msix_interrupt;
wire                        [31:0]              eq_pd;
wire                        [31:0]              eq_lkey;

//MPT Info
wire                        [31:0]              flags;
wire                        [31:0]              page_size;
wire                        [31:0]              mpt_key;
wire                        [31:0]              mpt_pd;
wire                        [63:0]              start_addr;
wire                        [63:0]              mr_length;
wire                        [63:0]              mtt_seg;

//MTT Info
wire                        [63:0]              physical_address;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [1:0]           cur_state;
reg             [1:0]           next_state;
    
parameter       [1:0]           IDLE_s = 2'd1,
                                COLLECT_s = 2'd2,
                                RSP_s = 2'd3;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cur_state <= IDLE_s;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:         if(dma_rd_rsp_valid) begin
                            next_state = COLLECT_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        COLLECT_s:      if(dma_rd_rsp_valid && piece_count == piece_num) begin
                            next_state = RSP_s;
                        end
                        else begin
                            next_state = COLLECT_s;
                        end
        RSP_s:          if(icm_entry_rsp_valid && icm_entry_rsp_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = RSP_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- piece_count -- 
always @(posedge clk or posedge rst) begin
    if(rst) begin
        piece_count <= 'd0;
    end
    else if(cur_state == IDLE_s && dma_rd_rsp_valid) begin
        piece_count <= 'd1;
    end
    else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
        piece_count <= piece_count + 'd1;
    end
    else if(cur_state == RSP_s) begin
        piece_count <= 'd0;
    end
    else begin
        piece_count <= piece_count;
    end
end

//-- piece_num --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        piece_num <= 'd0;        
    end
    else if (cur_state == IDLE_s && dma_rd_rsp_valid) begin
        case(ICM_CACHE_TYPE)
            `CACHE_TYPE_QPC:    piece_num <= 'd1;
            `CACHE_TYPE_CQC:    piece_num <= 'd1;
            `CACHE_TYPE_EQC:    piece_num <= 'd1;
            `CACHE_TYPE_MPT:    piece_num <= 'd1;
            `CACHE_TYPE_MTT:    piece_num <= 'd1;
            default:            piece_num <= 'd0;
        endcase
    end
    else if(cur_state == RSP_s) begin
        piece_num <= 'd0;
    end
    else begin
        piece_num <= piece_num;
    end
end

//-- icm_entry_rsp_valid --
assign icm_entry_rsp_valid = (cur_state == RSP_s) ? 'd1 : 'd0;

//-- QPC Info --
assign service_type = dma_rd_rsp_data[82:80];
assign state = dma_rd_rsp_data[93:91];
assign mtu_msgmax = dma_rd_rsp_data[127:120];
assign sq_entry_sz_log = dma_rd_rsp_data[111:104];
assign rq_entry_sz_log = dma_rd_rsp_data[119:112];
assign dst_qpn = dma_rd_rsp_data[223:192];
assign pkey_index = dma_rd_rsp_data[231:224];
assign port_index = dma_rd_rsp_data[255:248];
assign cqn_snd = dma_rd_rsp_data[159 + 256:128 + 256];
assign cqn_rcv = dma_rd_rsp_data[127:96];
assign qp_pd = dma_rd_rsp_data[255:224];
assign sq_lkey = dma_rd_rsp_data[191 + 256:160 + 256];
assign sq_length = dma_rd_rsp_data[223 + 256 : 192 + 256];
assign rq_lkey = dma_rd_rsp_data[159:128];
assign rq_length = dma_rd_rsp_data[191:160];
assign dmac_low_dlid = dma_rd_rsp_data[255 + 256:240 + 256];
assign smac_low_slid = dma_rd_rsp_data[239 + 256:224 + 256];
assign dmac_high = dma_rd_rsp_data[63:32];
assign smac_high = dma_rd_rsp_data[31:0];
assign dip = dma_rd_rsp_data[127:96];
assign sip = dma_rd_rsp_data[95:64];

//-- CQC Info --
assign cq_log_size = dma_rd_rsp_data[127:120];
assign comp_eqn = dma_rd_rsp_data[159:128];
assign cq_pd = dma_rd_rsp_data[191:160];
assign cq_lkey = dma_rd_rsp_data[223:192];
        
//-- EQC Info --
assign eq_log_size = dma_rd_rsp_data[127:96];
assign msix_interrupt = dma_rd_rsp_data[167:160];
assign eq_pd = dma_rd_rsp_data[223:192];
assign eq_lkey = dma_rd_rsp_data[255:224];

//-- MPT Info --
assign flags = dma_rd_rsp_data[31:0];
assign page_size = dma_rd_rsp_data[63:32];
assign mpt_key = dma_rd_rsp_data[95:64];
assign mpt_pd = dma_rd_rsp_data[127:96];
assign start_addr = dma_rd_rsp_data[191:128];
assign mr_length = dma_rd_rsp_data[255:192];
assign mtt_seg = dma_rd_rsp_data[415:352];

//-- MTT Info --
assign physical_address = dma_rd_rsp_data[63:0];

// generate 
//     if(ICM_CACHE_TYPE == `CACHE_TYPE_QPC) begin: EXTRACT_QPC
//         //-- icm_entry_rsp_data --
//         always @(posedge clk or posedge rst) begin
//             if(rst) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
//                 if(piece_count == 1) begin
//                     icm_entry_rsp_data <= {128'd0, dmac_low_dlid, smac_low_slid, 192'd0, port_index, pkey_index, dst_qpn, rq_entry_sz_log, sq_entry_sz_log, mtu_msgmax, {2'd0, state, service_type}};
//                 end
//                 else if(piece_count == 2) begin
//                     icm_entry_rsp_data <= {dip, sip, dmac_high, smac_high, icm_entry_rsp_data[283:256], 64'd0, sq_length, sq_lkey, qp_pd, cqn_snd, 16'd0, icm_entry_rsp_data[63:0]};
//                 end
//                 else if(piece_count == 3) begin
//                     icm_entry_rsp_data <= {icm_entry_rsp_data[415:256], rq_length, rq_lkey, icm_entry_rsp_data[191:96], cqn_rcv, icm_entry_rsp_data[71:0]};
//                 end
//                 else begin
//                     icm_entry_rsp_data <= icm_entry_rsp_data;
//                 end
//             end
//             else if(cur_state == RSP_s && icm_entry_rsp_valid && icm_entry_rsp_ready) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else begin
//                 icm_entry_rsp_data <= icm_entry_rsp_data;
//             end
//         end
//     end
//     else if(ICM_CACHE_TYPE == `CACHE_TYPE_CQC) begin: EXTRACT_CQC
//         //-- icm_entry_rsp_data --
//         always @(posedge clk or posedge rst) begin
//             if(rst) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
//                 icm_entry_rsp_data <= {cq_lkey, cq_pd, comp_eqn, 24'd0, cq_log_size};
//             end
//             else if(cur_state == RSP_s && icm_entry_rsp_valid && icm_entry_rsp_ready) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else begin
//                 icm_entry_rsp_data <= icm_entry_rsp_data;
//             end
//         end    
//     end
//     else if(ICM_CACHE_TYPE == `CACHE_TYPE_EQC) begin: EXTRACT_EQC
//         //-- icm_entry_rsp_data --
//         always @(posedge clk or posedge rst) begin
//             if(rst) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
//                 icm_entry_rsp_data <= {eq_lkey, eq_pd, 16'd0, msix_interrupt, eq_log_size};
//             end
//             else if(cur_state == RSP_s && icm_entry_rsp_valid && icm_entry_rsp_ready) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else begin
//                 icm_entry_rsp_data <= icm_entry_rsp_data;
//             end
//         end    
//     end
//     else if(ICM_CACHE_TYPE == `CACHE_TYPE_MPT) begin: EXTRACT_MPT
//         //-- icm_entry_rsp_data --
//         always @(posedge clk or posedge rst) begin
//             if(rst) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
//                 icm_entry_rsp_data <= {mtt_seg, mr_length, start_addr, mpt_pd, mpt_key, page_size, flags};
//             end
//             else if(cur_state == RSP_s && icm_entry_rsp_valid && icm_entry_rsp_ready) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else begin
//                 icm_entry_rsp_data <= icm_entry_rsp_data;
//             end
//         end    
//     end
//     else if(ICM_CACHE_TYPE == `CACHE_TYPE_MTT) begin: EXTRACT_MTT
//         //-- icm_entry_rsp_data --
//         always @(posedge clk or posedge rst) begin
//             if(rst) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else if(cur_state == COLLECT_s && dma_rd_rsp_valid) begin
//                 icm_entry_rsp_data <= physical_address;
//             end
//             else if(cur_state == RSP_s && icm_entry_rsp_valid && icm_entry_rsp_ready) begin
//                 icm_entry_rsp_data <= 'd0;
//             end
//             else begin
//                 icm_entry_rsp_data <= icm_entry_rsp_data;
//             end
//         end    
//     end
//     else begin
        
//     end
// endgenerate

//-- dma_rd_rsp_ready --
assign dma_rd_rsp_ready = (cur_state == COLLECT_s) ? 'd1 : 'd0;

//-- icm_entry_rsp_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        icm_entry_rsp_data <= 'd0;        
    end
    else if (cur_state == COLLECT_s && dma_rd_rsp_valid) begin
        icm_entry_rsp_data <= dma_rd_rsp_data;
    end
    else begin
        icm_entry_rsp_data <= icm_entry_rsp_data;
    end
end

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule