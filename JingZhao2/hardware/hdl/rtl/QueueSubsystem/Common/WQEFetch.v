/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       WQEFetch
Author:     YangFan
Function:   Fetch WQE from WQECache or Host Memory.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module WQEFetch
#(
	parameter 	CACHE_SLOT_NUM 			=		256,
	parameter 	CACHE_SLOT_NUM_LOG 		=		log2b(CACHE_SLOT_NUM),

	parameter 	CACHE_CELL_NUM 			=		256,
	parameter 	CACHE_CELL_NUM_LOG 		=		log2b(CACHE_CELL_NUM)
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with SQMetaProc(Send) or RDMACore(Recv)
    input   wire                                                            meta_valid,
    input   wire    [`SQ_META_WIDTH - 1 : 0]                                meta_data,
    output  wire                                                            meta_ready,

//Interface with WQECache
    //Interface with Cache Buffer
    output  reg                                                            	cache_buffer_wea,
    output  reg    	[log2b(CACHE_CELL_NUM * CACHE_SLOT_NUM - 1) - 1 : 0]                        	cache_buffer_addra,
    output  reg    	[`WQE_SEG_WIDTH - 1 : 0]                                cache_buffer_dina,

    output  wire   	[log2b(CACHE_CELL_NUM * CACHE_SLOT_NUM - 1) - 1 : 0]                        	cache_buffer_addrb,
    input   wire   	[`WQE_SEG_WIDTH - 1 : 0]                                cache_buffer_doutb,

    //Interface with Cache Owned Table
    output  reg                                                            	cache_owned_wen,
    output  reg    	[CACHE_CELL_NUM_LOG - 1 : 0]                        	cache_owned_addr,
    output  reg    	[`QP_NUM_LOG - CACHE_CELL_NUM_LOG + 1 - 1 : 0]          cache_owned_din,
    input   wire    [`QP_NUM_LOG - CACHE_CELL_NUM_LOG + 1 - 1 : 0]          cache_owned_dout,

//Interface with DMA Read Channel
    output  wire                                                            dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               dma_rd_req_data,
    output  wire                                                            dma_rd_req_last,
    input   wire                                                            dma_rd_req_ready,
                        
    input   wire                                                            dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               dma_rd_rsp_data,
    input   wire                                                            dma_rd_rsp_last,
    output  wire                                                            dma_rd_rsp_ready,

//-- Interface with Cache Offset
    output  wire                                                            cache_offset_wen,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   cache_offset_addr,
    output  wire    [CACHE_SLOT_NUM_LOG - 1:0]                          	cache_offset_din,
    input  	wire    [CACHE_SLOT_NUM_LOG - 1:0]                          	cache_offset_dout,

//Interface with WQEParser or RDMACore
    output  wire                                                            wqe_valid,
    output  wire    [`WQE_PARSER_META_WIDTH - 1 : 0]                        wqe_head,
    output  wire    [`WQE_SEG_WIDTH - 1 : 0]                                wqe_data,
    output 	wire 															wqe_start,
    output 	wire 															wqe_last,
    input   wire                                                            wqe_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
//Cell Index is lower bits of QPN
`define 	CELL_INDEX_OFFSET 			CACHE_CELL_NUM_LOG-1:0

`define     LOCAL_QPN_OFFSET            15:0

`define     MR_VALID_0_OFFSET           3+288:0+288
`define     MR_VALID_1_OFFSET           7+288:4+288
`define     MR_SIZE_0_OFFSET            63+288:32+288
`define     MR_SIZE_1_OFFSET            95+288:64+288 
`define     MR_PTE_0_OFFSET             159+288:96+288
`define     MR_PTE_1_OFFSET             223+288:160+288

//NextUnit filed offset
`define 	CUR_WQE_SIZE_OFFSET 		77:70
`define 	NEXT_WQE_SIZE_OFFSET 		37:32	
`define 	NEXT_WQE_ADDR_OFFSET 		31:6
`define 	NEXT_WQE_VALID_OFFSET 		5
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg    	[`SQ_META_WIDTH - 1 : 0]                                meta_data_diff;

reg                                                             gather_req_wr_en;
reg     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       gather_req_din;
wire                                                            gather_req_prog_full;

wire                                                            gather_resp_rd_en;
wire                                                            gather_resp_empty;
wire    [`DMA_DATA_WIDTH - 1 : 0]                               gather_resp_dout;

reg 	[log2b(CACHE_CELL_NUM * CACHE_SLOT_NUM - 1) - 1 : 0]							cache_buffer_addra_diff;
reg 	[log2b(CACHE_CELL_NUM * CACHE_SLOT_NUM - 1) - 1 : 0]							cache_buffer_addrb_diff;

//SQ Metadata
reg  	[CACHE_CELL_NUM_LOG - 1 : 0]							cell_index;
reg     [23:0]                                                  local_qpn;

reg     [3:0]                                                   mr_valid_0;
reg     [3:0]                                                   mr_valid_1;
reg     [31:0]                                                  mr_size_0;
reg     [63:0]                                                  mr_pte_0;
reg     [31:0]                                                  mr_size_1;
reg     [63:0]                                                  mr_pte_1;

reg     [31:0]                                                  wqe_fetch_total;
reg     [31:0]                                                  wqe_fetch_count;

wire                                                            cache_valid;

reg 	[31:0]													dma_req_count;
reg 	[31:0]													dma_req_total;

reg     [31:0]                                                  cache_slot_wr_count;
reg     [31:0]                                                  cache_slot_wr_total;

wire 															wqe_seg_valid;
wire 	[`WQE_SEG_WIDTH - 1 : 0]								wqe_seg_data;
wire 															wqe_seg_ready;

wire 	[5:0]													next_wqe_size;
wire 	[25:0]													next_wqe_addr;
wire 	[0:0]													next_wqe_valid;

wire                                                            size_valid;

reg                                                             judge_count;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
GatherData GatherData_Inst(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .gather_req_wr_en           (   gather_req_wr_en            ),
    .gather_req_din             (   gather_req_din              ),
    .gather_req_prog_full       (   gather_req_prog_full        ),
    
    .dma_rd_req_valid           (   dma_rd_req_valid            ),
    .dma_rd_req_head            (   dma_rd_req_head             ),
    .dma_rd_req_data            (   dma_rd_req_data             ),
    .dma_rd_req_last            (   dma_rd_req_last             ),
    .dma_rd_req_ready           (   dma_rd_req_ready            ),
    
    .dma_rd_rsp_valid          (   dma_rd_rsp_valid           ),
    .dma_rd_rsp_head           (   dma_rd_rsp_head            ),
    .dma_rd_rsp_data           (   dma_rd_rsp_data            ),
    .dma_rd_rsp_last           (   dma_rd_rsp_last            ),
    .dma_rd_rsp_ready          (   dma_rd_rsp_ready           ),
    
    .gather_resp_rd_en          (   gather_resp_rd_en           ),
    .gather_resp_empty          (   gather_resp_empty           ),
    .gather_resp_dout           (   gather_resp_dout            )
);

BitWidthTrans_512To128 WQEBlockBitTrans_Inst(
    .clk                        (   clk                             ),
    .rst                        (   rst                             ),

    .size_valid                 (   size_valid                      ),
    .block_size                 (   mr_size_0 + mr_size_1   		),

    .gather_resp_rd_en          (   gather_resp_rd_en               ),
    .gather_resp_empty          (   gather_resp_empty               ),
    .gather_resp_dout           (   gather_resp_dout                ),

    .wqe_seg_valid              (   wqe_seg_valid                   ),
    .wqe_seg_data               (   wqe_seg_data                    ),
    .wqe_seg_ready              (   wqe_seg_ready                   )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]           cur_state;
reg             [2:0]           next_state;

parameter       [2:0]           IDLE_s      = 3'd1,
                                JUDGE_s     = 3'd2,		//Decide whether we need to DMA from Host Memory
                                DMA_REQ_s   = 3'd4,
                                DMA_RSP_s   = 3'd5,
                                FETCH_WQE_s = 3'd6;

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
        IDLE_s:         if(meta_valid) begin
                            next_state = JUDGE_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        JUDGE_s:        if(!cache_valid && judge_count == 'd1) begin    //Current QP is not cached.
                            next_state = DMA_REQ_s;
                        end
                        else if(cache_valid && judge_count == 'd1) begin  //Current WQE Cache Buffer is available
                            next_state = FETCH_WQE_s;
                        end
                        else begin
                            next_state = JUDGE_s;
                        end
        DMA_REQ_s:      if(dma_req_count == dma_req_total && !gather_req_prog_full) begin
                            next_state = DMA_RSP_s;
                        end
                        else begin
                            next_state = DMA_REQ_s;
                        end
        DMA_RSP_s:      if(cache_slot_wr_count == cache_slot_wr_total && wqe_seg_valid) begin
                            next_state = FETCH_WQE_s;
                        end
                        else begin
                            next_state = DMA_RSP_s;
                        end
        FETCH_WQE_s:    if((wqe_fetch_count == wqe_fetch_total) && wqe_valid && wqe_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = FETCH_WQE_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- next_wqe_size --
//-- next_wqe_addr --
//-- next_wqe_valid --
assign next_wqe_size = cache_buffer_doutb[`NEXT_WQE_SIZE_OFFSET];
assign next_wqe_addr = cache_buffer_doutb[`NEXT_WQE_ADDR_OFFSET];
assign next_wqe_valid = cache_buffer_doutb[`NEXT_WQE_VALID_OFFSET];

//-- meta_data_diff --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		meta_data_diff <= 'd0;		
	end
	else if (cur_state == IDLE_s && meta_valid) begin
		meta_data_diff <= meta_data;
	end
	else begin
		meta_data_diff <= meta_data_diff;
	end
end

//-- cell_index --
//-- local_qpn --
//-- mr_valid_0 --
//-- mr_valid_1 --
//-- mr_size_0 --
//-- mr_pte_0 --
//-- mr_size_1 --
//-- mr_pte_1 --
always @(posedge clk or posedge rst) begin
    if(rst) begin
    	cell_index <= 'd0;
        local_qpn <= 'd0;

        mr_valid_0 <= 'd0;
        mr_valid_1 <= 'd0;
        mr_size_0 <= 'd0;
        mr_pte_0 <= 'd0;
        mr_size_1 <= 'd0;
        mr_pte_1 <= 'd0;
    end
    else if(cur_state == IDLE_s && meta_valid) begin
    	cell_index <= meta_data[`CELL_INDEX_OFFSET];
        local_qpn <= meta_data[`LOCAL_QPN_OFFSET];

        mr_valid_0 <= meta_data[`MR_VALID_0_OFFSET];
        mr_valid_1 <= meta_data[`MR_VALID_1_OFFSET];
        mr_size_0 <= meta_data[`MR_SIZE_0_OFFSET];
        mr_pte_0 <= meta_data[`MR_PTE_0_OFFSET];
        mr_size_1 <= meta_data[`MR_SIZE_1_OFFSET];
        mr_pte_1 <= meta_data[`MR_PTE_1_OFFSET];
    end
    else begin
    	cell_index <= cell_index;
        local_qpn <= local_qpn;

        mr_valid_0 <= mr_valid_0;
        mr_valid_1 <= mr_valid_1;
        mr_size_0 <= mr_size_0;
        mr_pte_0 <= mr_pte_0;
        mr_size_1 <= mr_size_1;
        mr_pte_1 <= mr_pte_1;
    end
end

//-- dma_req_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_req_count <= 'd0;        
    end
    else if (cur_state == IDLE_s && meta_valid) begin
        dma_req_count <= 'd1;
    end
    else if(cur_state == DMA_REQ_s && !gather_req_prog_full) begin
        dma_req_count <= dma_req_count + 'd1;
    end
    else begin
        dma_req_count <= dma_req_count;
    end
end

//-- dma_req_total --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_req_total <= 'd0;        
    end
    else if (cur_state == IDLE_s && meta_valid) begin
        if(meta_data[`MR_RESP_VALID_0_OFFSET] == `PAGE_VALID && meta_data[`MR_RESP_VALID_1_OFFSET] == `PAGE_VALID) begin
            dma_req_total <= 'd2;
        end
        else begin
            dma_req_total <= 'd1;
        end
    end
    else begin
        dma_req_total <= dma_req_total;
    end
end

//-- gather_req_wr_en --
//-- gather_req_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        gather_req_wr_en <= 'd0;
        gather_req_din <= 'd0;
    end
    else if (cur_state == DMA_REQ_s && !gather_req_prog_full) begin
        if(dma_req_count == 'd1) begin
            gather_req_wr_en <= 'd1;
            gather_req_din <= {mr_size_0 + mr_size_1, mr_size_0, mr_pte_0};
        end
        else if(dma_req_count == 'd2) begin
            gather_req_wr_en <= 'd1;
            gather_req_din <= {mr_size_0 + mr_size_1, mr_size_1, mr_pte_1};
        end
        else begin
            gather_req_wr_en <= 'd0;
            gather_req_din <= 'd0;
        end
    end
    else begin
        gather_req_wr_en <= 'd0;
        gather_req_din <= 'd0;
    end
end

//-- cache_valid -- Cahce entry is valid and current cache entry is owned by current qp. CACHE_CELL_NUM must be less than QP_NUM
assign cache_valid = cache_owned_dout[`QP_NUM_LOG - CACHE_CELL_NUM_LOG] && (cache_owned_dout[`QP_NUM_LOG - CACHE_CELL_NUM_LOG - 1 : 0] == local_qpn[`QP_NUM_LOG - 1 : 4]);

//-- cache_slot_wr_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_slot_wr_count <= 'd0;        
    end
    else if (cur_state == DMA_REQ_s && next_state == DMA_RSP_s) begin
        cache_slot_wr_count <= 'd1;
    end
    else if (cur_state == DMA_RSP_s && wqe_seg_valid) begin
        cache_slot_wr_count <= cache_slot_wr_count + 'd1;
    end
    else begin
        cache_slot_wr_count <= cache_slot_wr_count;
    end
end

//-- cache_slot_wr_total --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_slot_wr_total <= 'd0;
    end
    else if (cur_state == DMA_REQ_s && next_state == DMA_RSP_s) begin
        cache_slot_wr_total <= (mr_size_0 + mr_size_1) >> 4;  //Each cycle is 16B WQE Seg
    end
    else begin
    	cache_slot_wr_total <= cache_slot_wr_total;
    end
end

//-- cache_buffer_addra_diff --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		cache_buffer_addra_diff <= 'd0;		
	end
	else if (cur_state == DMA_REQ_s) begin
		cache_buffer_addra_diff <= local_qpn[CACHE_CELL_NUM_LOG - 1 : 0] << CACHE_SLOT_NUM_LOG;
	end
	else if (cur_state == DMA_RSP_s && wqe_seg_valid) begin
		cache_buffer_addra_diff <= cache_buffer_addra_diff + 'd1;
	end
	else begin
		cache_buffer_addra_diff <= cache_buffer_addra_diff;
	end
end

//-- cache_buffer_wea --
//-- cache_buffer_addra --
//-- cache_buffer_dina --
always @(*) begin
    if (rst) begin
        cache_buffer_wea = 'd0;
        cache_buffer_addra = 'd0;
        cache_buffer_dina = 'd0;
    end
    else if (cur_state == DMA_RSP_s && wqe_seg_valid) begin
        cache_buffer_wea = 'd1;
        cache_buffer_addra = cache_buffer_addra_diff;
        cache_buffer_dina = wqe_seg_data;
    end
    else begin
        cache_buffer_wea = 'd0;
        cache_buffer_addra = 'd0;
        cache_buffer_dina = 'd0;
    end
end

//-- cache_buffer_addrb --
assign cache_buffer_addrb = 	(cur_state == JUDGE_s && cache_valid) ? ((local_qpn[`CELL_INDEX_OFFSET] << CACHE_SLOT_NUM_LOG) + cache_offset_dout) :
								(cur_state == JUDGE_s && !cache_valid) ? ((local_qpn[`CELL_INDEX_OFFSET] << CACHE_SLOT_NUM_LOG) + 'd0) :    //If a cache cell is valid, it must be processed in WQEParser, cache offset cannot be 0
                                (cur_state == FETCH_WQE_s && wqe_ready) ? cache_buffer_addrb_diff + 'd1 : cache_buffer_addrb_diff;

//-- cache_buffer_addrb_diff --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		cache_buffer_addrb_diff <= 'd0;
	end
	else begin
		cache_buffer_addrb_diff <= cache_buffer_addrb;
	end
end

//-- cache_owned_wen --
//-- cache_owned_addr --
//-- cache_owned_din --
always @(*) begin
	if(rst) begin
		cache_owned_wen = 'd0;
		cache_owned_addr = 'd0;
		cache_owned_din = 'd0;
	end
	else if(cur_state == IDLE_s && meta_valid) begin
		cache_owned_wen = 'd0;
		cache_owned_addr = meta_data[`CELL_INDEX_OFFSET];
		cache_owned_din = 'd0;
	end
	else if(cur_state == DMA_RSP_s && cache_slot_wr_count == cache_slot_wr_total && wqe_seg_valid) begin
		cache_owned_wen = 'd1;
		cache_owned_addr = cell_index;
		cache_owned_din = {'d1, local_qpn[`QP_NUM_LOG - 1 : 4]};
	end
	else begin
		cache_owned_wen = 'd0;
		cache_owned_addr = cell_index;
		cache_owned_din = 'd0;
	end
end

//-- cache_offset_wen --
//-- cache_offset_addr --
//-- cache_offset_din --
assign cache_offset_wen = (cur_state == DMA_REQ_s) ? 'd1 : 'd0;
assign cache_offset_addr = (cur_state == IDLE_s && meta_valid) ? meta_data[`CELL_INDEX_OFFSET] :
                                (cur_state == DMA_REQ_s) ? local_qpn[`CELL_INDEX_OFFSET] : local_qpn[`CELL_INDEX_OFFSET];
assign cache_offset_din = (cur_state == DMA_REQ_s) ? 'd0 : 'd0;

//-- wqe_fetch_total --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        wqe_fetch_total <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
    	wqe_fetch_total <= 'd0;
    end
    else if(cur_state == JUDGE_s && judge_count == 'd1) begin
        wqe_fetch_total <= cache_buffer_doutb[`CUR_WQE_SIZE_OFFSET];
    end
    else if(cur_state == DMA_RSP_s && cache_slot_wr_count == 'd1) begin
        wqe_fetch_total <= wqe_seg_data[`CUR_WQE_SIZE_OFFSET]; 	//WQE size is in unit of 16B, hence cur_wqe_size is 16B count
    end
    else begin
        wqe_fetch_total <= wqe_fetch_total;
    end
end

//-- wqe_fetch_count --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		wqe_fetch_count <= 'd0;
	end
	else if(cur_state == IDLE_s) begin
		wqe_fetch_count <= 'd0;
	end
	else if(cur_state != FETCH_WQE_s && next_state == FETCH_WQE_s) begin
		wqe_fetch_count <= 'd1;
	end
	else if(cur_state == FETCH_WQE_s && wqe_valid && wqe_ready) begin
		wqe_fetch_count <= wqe_fetch_count + 'd1;
	end
	else begin
		wqe_fetch_count <= wqe_fetch_count;
	end
end

//-- wqe_valid --
//-- wqe_head --
//-- wqe_data --
//-- wqe_start --
//-- wqe_last --
assign wqe_valid = (cur_state == FETCH_WQE_s) ? 'd1 : 'd0;
assign wqe_head = (cur_state == FETCH_WQE_s) ? meta_data_diff[`WQE_PARSER_META_WIDTH - 1 : 0] : 'd0;
assign wqe_data = (cur_state == FETCH_WQE_s) ? cache_buffer_doutb : 'd0; 
assign wqe_start = (cur_state == FETCH_WQE_s) ? (wqe_fetch_count == 'd1) : 'd0;
assign wqe_last = (cur_state == FETCH_WQE_s) ? (wqe_fetch_count == wqe_fetch_total) : 'd0;


//-- meta_ready --
assign meta_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- size_valid --
assign size_valid = (cur_state != IDLE_s);

//-- wqe_seg_ready --
assign wqe_seg_ready = 'd1;

//-- judge_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        judge_count <= 'd0;        
    end
    else if (cur_state == JUDGE_s) begin
        judge_count <= judge_count + 'd1;
    end
    else begin
        judge_count <= 'd0;
    end
end
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     CELL_INDEX_OFFSET

`undef     LOCAL_QPN_OFFSET

`undef     MR_VALID_0_OFFSET
`undef     MR_VALID_1_OFFSET
`undef     MR_SIZE_0_OFFSET
`undef     MR_SIZE_1_OFFSET
`undef     MR_PTE_0_OFFSET
`undef     MR_PTE_1_OFFSET

`undef     CUR_WQE_SIZE_OFFSET
`undef     NEXT_WQE_SIZE_OFFSET
`undef     NEXT_WQE_ADDR_OFFSET
`undef     NEXT_WQE_VALID_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule