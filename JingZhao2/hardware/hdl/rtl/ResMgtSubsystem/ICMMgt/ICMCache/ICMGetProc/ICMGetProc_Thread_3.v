/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMGetProc_Thread_3
Author:     YangFan
Function:   Deal with ICMBuffer response.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMGetProc_Thread_3
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

//ICMBuffer Get Response Interface
    input   wire                                                                                                    get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]   get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                     get_rsp_data,
    output  wire                                                                                                    get_rsp_ready,

//ReorderBuffer Interface
    output  reg                                                                                                     reorder_buffer_wen,
    output  reg     [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                                  reorder_buffer_addr,
    output  reg     [REORDER_BUFFER_WIDTH - 1 : 0]                                                                  reorder_buffer_din,
    input   wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                                  reorder_buffer_dout,

//DMA Read Req Interface
    output  wire                                                                                                    dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                       dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                       dma_rd_req_data,
    output  wire                                                                                                    dma_rd_req_last,
    input   wire                                                                                                    dma_rd_req_ready,

//ReqHitFIFO Interface 
    output  wire                                                                                                    req_hit_wr_en,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]       req_hit_din,
    input   wire                                                                                                    req_hit_prog_full,

//ReqMissFIFO Interface
    output  wire                                                                                                    req_miss_wr_en,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]       req_miss_din,
    input   wire                                                                                                    req_miss_prog_full
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            cache_hit;
wire                                                            cache_miss;
wire        [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                      req_tag;
wire        [31:0]                                              dma_len;
wire        [PHYSICAL_ADDR_WIDTH - 1 : 0]                       dma_addr;
wire        [COUNT_MAX_LOG - 1 : 0]                             count_max;
wire        [COUNT_MAX_LOG - 1 : 0]                             count_index;
wire        [COUNT_MAX_LOG - 1 : 0]                             count_collected;

reg    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]    get_rsp_head_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]           cur_state;
reg         [2:0]           next_state;

parameter   [2:0]           IDLE_s = 3'd1,
                            HIT_s = 3'd2,
                            MISS_s = 3'd3,
                            DMA_s = 3'd4;


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
        IDLE_s:             if(get_rsp_valid && cache_hit) begin
                                next_state = HIT_s;
                            end
                            else if(get_rsp_valid && cache_miss) begin
                                next_state = MISS_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        HIT_s:              if(!req_hit_prog_full) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = HIT_s;
                            end
        MISS_s:             if(!req_miss_prog_full) begin
                                next_state = DMA_s;
                            end
                            else begin
                                next_state = MISS_s;
                            end
        DMA_s:              if(dma_rd_req_valid && dma_rd_req_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = DMA_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- cache_hit --
assign cache_hit = (cur_state == IDLE_s && get_rsp_valid) ? get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] == 1'b1 : 'd0; 

//-- cache_miss --
assign cache_miss = (cur_state == IDLE_s && get_rsp_valid) ? get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] == 1'b0 : 'd0;

//-- dma_addr --
assign dma_addr = (cur_state == DMA_s) ? get_rsp_head_diff[PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : ICM_ADDR_WIDTH] : 'd0;

//-- dma_len --
assign dma_len = (cur_state == DMA_s) ? CACHE_ENTRY_WIDTH / 8 : 'd0;

//-- req_tag --
assign req_tag = get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];

//-- count_max --
//-- count_index --
//-- count_collected --
assign count_index = get_rsp_head[COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign count_max = get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign count_collected = reorder_buffer_dout[REORDER_BUFFER_WIDTH - 1 : REORDER_BUFFER_WIDTH - COUNT_MAX_LOG];

//-- get_rsp_ready --
assign get_rsp_ready = (cur_state == HIT_s && !req_hit_prog_full) || (cur_state == MISS_s && !req_miss_prog_full);

//-- reorder_buffer_wen --
//-- reorder_buffer_addr --
always @(*) begin
    if(rst) begin
        reorder_buffer_wen = 'd0;
        reorder_buffer_addr = 'd0;
    end
    else if(cur_state == IDLE_s && get_rsp_valid) begin
        reorder_buffer_wen = 'd0;
        reorder_buffer_addr = req_tag;        
    end
    else if(cur_state == HIT_s) begin
        reorder_buffer_wen = 'd1;
        reorder_buffer_addr = req_tag;
    end
    else begin
        reorder_buffer_wen = 'd0;
        reorder_buffer_addr = 'd0;
    end       
end

//-- reorder_buffer_din --
always @(*) begin
    if(rst) begin
        reorder_buffer_din = 'd0;
    end
    else if(cur_state == HIT_s) begin
        if(ICM_CACHE_TYPE == `CACHE_TYPE_MTT) begin
            if(count_index == 0) begin
                reorder_buffer_din = {count_collected + 'd1, reorder_buffer_dout[CACHE_ENTRY_WIDTH * 2 - 1 : CACHE_ENTRY_WIDTH], get_rsp_data};
            end
            else if(count_index == 1) begin
                reorder_buffer_din = {count_collected + 'd1, get_rsp_data, reorder_buffer_dout[CACHE_ENTRY_WIDTH - 1 : 0]};
            end
            else begin
                reorder_buffer_din = 'd0;
            end
        end
        else if(ICM_CACHE_TYPE == `CACHE_TYPE_QPC || ICM_CACHE_TYPE == `CACHE_TYPE_CQC || ICM_CACHE_TYPE == `CACHE_TYPE_EQC || ICM_CACHE_TYPE == `CACHE_TYPE_MPT) begin
            reorder_buffer_din = {count_collected + 'd1, get_rsp_data};
        end
        else begin
            reorder_buffer_din = 'd0;
        end
    end
    else begin
        reorder_buffer_din = 'd0;
    end       
end

//-- dma_rd_req_valid --
//-- dma_rd_req_head --
//-- dma_rd_req_data --
//-- dma_rd_req_last --
assign dma_rd_req_valid = (cur_state == DMA_s) ? 'd1 : 'd0;
assign dma_rd_req_head = (cur_state == DMA_s) ? {dma_addr, dma_len}: 'd0;
assign dma_rd_req_data = 'd0;
assign dma_rd_req_last = (cur_state == DMA_s) ? 'd1 : 'd0;

//-- req_hit_wr_en --
//-- req_hit_din --
assign req_hit_wr_en = (cur_state == HIT_s && !req_hit_prog_full) ? 'd1 : 'd0;
assign req_hit_din = (cur_state == HIT_s && !req_hit_prog_full) ? get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0] : 'd0;

//-- req_miss_wr_en --
//-- req_miss_din --
assign req_miss_wr_en = (cur_state == MISS_s && !req_miss_prog_full) ? 'd1 : 'd0;
assign req_miss_din = (cur_state == MISS_s && !req_miss_prog_full) ? get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0] : 'd0;

//-- get_rsp_head_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        get_rsp_head_diff <= 'd0;
    end
    else if (cur_state == IDLE_s && get_rsp_valid) begin
        get_rsp_head_diff <= get_rsp_head;
    end
    else begin
        get_rsp_head_diff <= get_rsp_head_diff;
    end
end
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/


`ifdef ILA_ON
    generate 
        if(ICM_CACHE_TYPE == `CACHE_TYPE_QPC) begin
            ila_qpc_cache   ila_qpc_cache_inst(
                .clk(clk),

                .probe0(get_rsp_valid),
                .probe1(get_rsp_head),
                .probe2(get_rsp_data),
                .probe3(get_rsp_ready),

                .probe4(reorder_buffer_wen),
                .probe5(reorder_buffer_addr),
                .probe6(reorder_buffer_din),
                .probe7(reorder_buffer_dout),

                .probe8(dma_rd_req_valid),
                .probe9(dma_rd_req_head),
                .probe10(dma_rd_req_data),
                .probe11(dma_rd_req_last),
                .probe12(dma_rd_req_ready),

                .probe13(req_hit_wr_en),
                .probe14(req_hit_din),

                .probe15(req_miss_wr_en),
                .probe16(req_miss_din)
            );

        end
    endgenerate
`endif

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule