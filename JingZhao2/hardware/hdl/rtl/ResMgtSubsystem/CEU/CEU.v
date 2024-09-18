`timescale 1ns / 100ps
//*************************************************************************
//   > File Name  : CEU.v
//   > Description: CEU, passes host command to corresponding module.
//   > Author     : Corning
//   > Date       : 2020-07-04
//*************************************************************************

`include "ceu_def_h.vh"
`include "protocol_engine_def.vh"


module CEU #( 
    parameter DMA_HEAD_WIDTH     = 128             // DMA Stream *_head width
) (
    input   wire    clk,
    input   wire    rst_n,

    /* -------Interact with PIO Interface{begin}------- */
    input   wire [63:0]  hcr_in_param      ,
    input   wire [31:0]  hcr_in_modifier   ,
    input   wire [63:0]  hcr_out_dma_addr  ,
    input   wire [31:0]  hcr_token         ,
    input   wire         hcr_go            ,
    input   wire         hcr_event         ,
    input   wire [ 7:0]  hcr_op_modifier   ,
    input   wire [11:0]  hcr_op            ,
    
    output  wire [63:0]  hcr_out_param     ,
    output  wire [ 7:0]  hcr_status        ,
    output  wire         hcr_clear         ,
    /* -------Interact with PIO Interface{end}------- */


    /* -------Interact with DMA-engine module{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA Read Request
    output  wire                       dma_rd_req_valid ,
    output  wire                       dma_rd_req_last  ,
    output  wire [`DMA_DATA_WIDTH-1:0] dma_rd_req_data  ,
    output  wire [`DMA_HEAD_WIDTH-1:0] dma_rd_req_head  ,
    input   wire                       dma_rd_req_ready ,
    
    // DMA Read Response
    input   wire                       dma_rd_rsp_valid,
    input   wire                       dma_rd_rsp_last ,
    input   wire [`DMA_DATA_WIDTH-1:0] dma_rd_rsp_data ,
    input   wire [`DMA_HEAD_WIDTH-1:0] dma_rd_rsp_head ,
    output  wire                       dma_rd_rsp_ready,
    
    // DMA Write Request
    output  wire                       dma_wr_req_valid,
    output  wire                       dma_wr_req_last ,
    output  wire [`DMA_DATA_WIDTH-1:0] dma_wr_req_data ,
    output  wire [`DMA_HEAD_WIDTH-1:0] dma_wr_req_head ,
    input   wire                       dma_wr_req_ready,
    /* -------Interact with DMA-engine module{end}------- */
    

    //* -------Interact with Context Management Module{begin}------- */
    // CtxMgt (read & write) request
    output  wire                          cm_req_valid,
    output  wire                          cm_req_last ,
    output  wire [`CEU_DATA_WIDTH-1   :0] cm_req_data ,
    output  wire [`CEU_CM_HEAD_WIDTH-1:0] cm_req_head ,
    input   wire                          cm_req_ready,

    // CtxMgt read response
    input   wire                          cm_rsp_valid,
    input   wire                          cm_rsp_last ,
    input   wire [`CEU_DATA_WIDTH-1   :0] cm_rsp_data ,
    input   wire [`CEU_CM_HEAD_WIDTH-1:0] cm_rsp_head ,
    output  wire                          cm_rsp_ready,
    /* -------Interact with Context Management Module{end}------- */


    /* -------Interact with virtual-to-physial Module{begin}------- */
    // VirtToPhys write request
    output  wire                           v2p_req_valid,
    output  wire                           v2p_req_last ,
    output  wire [`CEU_DATA_WIDTH-1    :0] v2p_req_data ,
    output  wire [`CEU_V2P_HEAD_WIDTH-1:0] v2p_req_head ,
    input   wire                           v2p_req_ready//,
    /* -------Interact with virtual-to-physial Module{end}------- */

`ifdef CEU_DBG_LOGIC 
    /* -------APB reated signal{begin}------- */
    ,input  wire [`ACC_LOCAL_RW_WIDTH-1:0] rw_data // i, 32; read-writer register interface
    ,output wire [`ACC_LOCAL_RW_WIDTH-1:0] rw_init_data // o, 
	,output wire [`ACC_LOCAL_RW_WIDTH-1:0] ro_data // o, 32; read-only register interface
	,input  wire [32-1:0] dbg_sel // i, 32; debug bus select
	,output wire [32-1:0] dbg_bus // o, 32; debug bus data	
	//,output wire [`CEU_DBG_WIDTH-1:0] dbg_bus // o, 32; debug bus data	
    /* -------APB reated signal{end}------- */
`endif
);

wire                                                    CEU_dma_wr_req_in_valid;
wire                                                    CEU_dma_wr_req_in_last;
wire    [`DMA_HEAD_WIDTH - 1 : 0]                       CEU_dma_wr_req_in_head;
wire    [256 - 1 : 0]                                   CEU_dma_wr_req_in_data;
wire                                                    CEU_dma_wr_req_in_ready;

wire                                                    CEU_dma_rd_rsp_out_valid;
wire    [127:0]                                         CEU_dma_rd_rsp_out_head;
wire    [255:0]                                         CEU_dma_rd_rsp_out_data;
wire                                                    CEU_dma_rd_rsp_out_last;
wire                                                    CEU_dma_rd_rsp_out_ready;

DMAWrReqChannel DMARdRspChannel_CEU(    //512 to 256
    .clk                        (           clk                         ),
    .rst                        (           !rst_n                      ),

    .dma_wr_req_in_valid        (           dma_rd_rsp_valid            ),
    .dma_wr_req_in_head         (           dma_rd_rsp_head             ),
    .dma_wr_req_in_data         (           dma_rd_rsp_data             ),
    .dma_wr_req_in_last         (           dma_rd_rsp_last             ),
    .dma_wr_req_in_ready        (           dma_rd_rsp_ready            ),

    .dma_wr_req_out_valid       (           CEU_dma_rd_rsp_out_valid    ),
    .dma_wr_req_out_head        (           CEU_dma_rd_rsp_out_head     ),
    .dma_wr_req_out_data        (           CEU_dma_rd_rsp_out_data     ),
    .dma_wr_req_out_last        (           CEU_dma_rd_rsp_out_last     ),
    .dma_wr_req_out_ready       (           CEU_dma_rd_rsp_out_ready    )
);


DMARdRspChannel DMAWrReqChannel_CEU(    //256 to 512
    .clk                        (           clk                             ),
    .rst                        (           !rst_n                          ),

    .dma_rd_rsp_in_valid        (           CEU_dma_wr_req_in_valid         ),
    .dma_rd_rsp_in_head         (           CEU_dma_wr_req_in_head          ),
    .dma_rd_rsp_in_data         (           CEU_dma_wr_req_in_data          ),
    .dma_rd_rsp_in_last         (           CEU_dma_wr_req_in_last          ),
    .dma_rd_rsp_in_ready        (           CEU_dma_wr_req_in_ready         ),

    .dma_rd_rsp_out_valid       (           dma_wr_req_valid                ),
    .dma_rd_rsp_out_head        (           dma_wr_req_head                 ),
    .dma_rd_rsp_out_data        (           dma_wr_req_data                 ),
    .dma_rd_rsp_out_last        (           dma_wr_req_last                 ),
    .dma_rd_rsp_out_ready       (           dma_wr_req_ready                )
);


/* -------CMD decode{begin}------- */

// identify cmd type
wire is_query_dev_lim, is_query_adapter, is_init_ib, is_close_ib, is_set_ib, is_conf_special_qp, is_mad_ifc;
wire is_sw2hw_cq, is_resize_cq, is_sw2hw_eq, is_map_eq, is_modify_qp, is_hw2sw_cq, is_hw2sw_eq, is_query_qp;
wire is_sw2hw_mpt, is_write_mtt, is_hw2sw_mpt;
wire is_init_hca, is_close_hca;
wire is_map_icm, is_unmap_icm;

// If (`CMD_MAP_ICM | `CMD_UNMAP_ICM) cmd is in cm
wire is_in_cm, is_in_v2p;

// the module cmd belongs to
wire is_acc_local;
// wire is_rd_local ;
// wire is_wr_local ;
wire is_acc_cm   ;
// wire is_rd_cm    ;
// wire is_wr_cm    ;
wire is_wr_v2p   ;
wire is_wr_both  ;


// If the cmd has inbox / outbox
wire has_inbox;
wire has_outbox;

/* -------CMD decode{end}------- */

/* -------Status encode{begin}------- */
wire is_bad_op, is_bad_param, is_bad_sys_stat, is_bad_nvmem;


// EXECUTE state end (related module has finished execution).
// Assert one cycle to inform CEU_ctrl the end of cmd execution.
wire is_exe_end;
wire acc_local_end;
wire acc_cm_end;
wire wr_v2p_end;
wire wr_both_end;
/* -------Status encode{end}------- */



/* -------CEU_ctrl FSM relevant{begin}------- */
localparam  IDLE      = 4'b0001,
            DECODE    = 4'b0010,
            GET_INBOX = 4'b0100,
            EXECUTE   = 4'b1000;

reg [3:0] cur_state;
reg [3:0] nxt_state;

reg [63:0]  reg_in_param    ;
reg [31:0]  reg_in_modifier ;
reg [63:0]  reg_out_dma_addr;
reg [ 7:0]  reg_op_modifier ;
reg [11:0]  reg_op          ;


wire is_idle, is_decode, is_get_inbox, is_execute;


// inbox relevant
wire [63:0] inbox_addr;
wire [11:0] inbox_len; // length in bytes

wire [11:0] map_icm_len;
wire [11:0] write_mtt_len;
/* -------CEU_ctrl FSM relevant{end}------- */

/* -------MUX{begin}------- */
wire dma_rrsp_local_ready, dma_rrsp_cm_ready, dma_rrsp_v2p_ready, dma_rrsp_both_ready; 

wire                       dma_wreq_local_valid, dma_wreq_cm_valid;
wire                       dma_wreq_local_last , dma_wreq_cm_last ;
wire [`CEU_DATA_WIDTH-1:0] dma_wreq_local_data , dma_wreq_cm_data ;
wire [DMA_HEAD_WIDTH -1:0] dma_wreq_local_head , dma_wreq_cm_head ;

wire                          cm_req_cm_valid, cm_req_both_valid;
wire                          cm_req_cm_last , cm_req_both_last ;
wire [`CEU_DATA_WIDTH   -1:0] cm_req_cm_data , cm_req_both_data ;
wire [`CEU_CM_HEAD_WIDTH-1:0] cm_req_cm_head , cm_req_both_head ;

wire                           v2p_req_both_valid, v2p_req_v2p_valid;
wire                           v2p_req_both_last , v2p_req_v2p_last ;
wire [`CEU_DATA_WIDTH-1    :0] v2p_req_both_data , v2p_req_v2p_data ;
wire [`CEU_V2P_HEAD_WIDTH-1:0] v2p_req_both_head , v2p_req_v2p_head ;
/* -------MUX{end}------- */

/* -------- DMA Read Response{begin}-------- */
wire                       st_dma_rd_rsp_valid;
wire                       st_dma_rd_rsp_last ;
wire [`CEU_DATA_WIDTH-1:0] st_dma_rd_rsp_data ;
wire [DMA_HEAD_WIDTH-1 :0] st_dma_rd_rsp_head ;
wire                       st_dma_rd_rsp_ready;
/* -------- DMA Read Response{end}-------- */

`ifdef CEU_DBG_LOGIC 
/* -------APB reated signal{begin}------- */
wire [`CEU_DBG_WIDTH      -1:0] ceu_dbg      ;
wire [`TOP_DBG_WIDTH      -1:0] top_dbg      ;
wire [`ACC_CM_DBG_WIDTH   -1:0] acc_cm_dbg   ;
wire [`ACC_LOCAL_DBG_WIDTH-1:0] acc_local_dbg;
wire [`WR_BOTH_DBG_WIDTH  -1:0] wr_both_dbg  ;
wire [`WR_V2P_DBG_WIDTH   -1:0] wr_v2p_dbg   ;
/* -------APB reated signal{end}------- */
`endif

/* -------CMD decode logic{begin}------- */


// acc local cmd type
assign is_query_dev_lim   = (reg_op == `CMD_QUERY_DEV_LIM  );
assign is_query_adapter   = (reg_op == `CMD_QUERY_ADAPTER  );
assign is_init_ib         = (reg_op == `CMD_INIT_IB        ); // not realized
assign is_close_ib        = (reg_op == `CMD_CLOSE_IB       ); // not realized
assign is_set_ib          = (reg_op == `CMD_SET_IB         ); // not realized
assign is_conf_special_qp = (reg_op == `CMD_CONF_SPECIAL_QP); // not realized
assign is_mad_ifc         = (reg_op == `CMD_MAD_IFC        ); // not realized

// acc cm cmd type
assign is_sw2hw_cq  = (reg_op == `CMD_SW2HW_CQ );
assign is_resize_cq = (reg_op == `CMD_RESIZE_CQ);
assign is_sw2hw_eq  = (reg_op == `CMD_SW2HW_EQ );
assign is_map_eq    = (reg_op == `CMD_MAP_EQ   );
assign is_hw2sw_cq  = (reg_op == `CMD_HW2SW_CQ );
assign is_hw2sw_eq  = (reg_op == `CMD_HW2SW_EQ );
assign is_query_qp  = (reg_op == `CMD_QUERY_QP );
assign is_modify_qp = `IS_MODIFY_QP(reg_op);

// wr v2p cmd type
assign is_sw2hw_mpt = (reg_op == `CMD_SW2HW_MPT);
assign is_write_mtt = (reg_op == `CMD_WRITE_MTT);
assign is_hw2sw_mpt = (reg_op == `CMD_HW2SW_MPT);

// wr v2p & cm cmd type
assign is_init_hca  = (reg_op == `CMD_INIT_HCA );
assign is_close_hca = (reg_op == `CMD_CLOSE_HCA);

// wr v2p || cm cmd type
assign is_map_icm   = (reg_op == `CMD_MAP_ICM  );
assign is_unmap_icm = (reg_op == `CMD_UNMAP_ICM);

// module selection for v2p || cm cmd type
assign is_in_cm  = (reg_op_modifier == 1);
assign is_in_v2p = (reg_op_modifier == 2);


// 
assign is_acc_local = is_query_dev_lim | is_query_adapter   | is_init_ib | is_close_ib | 
                      is_set_ib        | is_conf_special_qp | is_mad_ifc;
// assign is_rd_local  = is_query_dev_lim | is_query_adapter;
// assign is_wr_local  = 0;
assign is_acc_cm    = is_sw2hw_cq | is_resize_cq | is_sw2hw_eq | is_map_eq | 
                      is_hw2sw_cq | is_hw2sw_eq  | is_query_qp | is_modify_qp | 
                      (is_map_icm & is_in_cm) | (is_unmap_icm & is_in_cm);
// assign is_rd_cm     = is_query_qp;
// assign is_wr_cm     = is_sw2hw_cq | is_resize_cq | is_sw2hw_eq  | is_map_eq | 
//                       is_hw2sw_cq | is_hw2sw_eq  | is_modify_qp | 
//                       (is_map_icm & is_in_cm) | (is_unmap_icm & is_in_cm);
assign is_wr_v2p    = is_sw2hw_mpt | is_write_mtt | is_hw2sw_mpt |
                      (is_map_icm & is_in_v2p) | (is_unmap_icm & is_in_v2p);
assign is_wr_both   = is_init_hca | is_close_hca;

// if cmd has inbox or outbox
assign has_inbox  = is_init_hca | is_map_icm   | is_sw2hw_cq  | is_resize_cq | 
                    is_sw2hw_eq | is_sw2hw_mpt | is_write_mtt | is_init_ib   | 
                    is_set_ib   | (is_modify_qp & (reg_op_modifier == 0));
assign has_outbox = is_query_dev_lim | is_query_adapter | is_query_qp | is_mad_ifc;
/* -------CMD decode logic{end}------- */



/* -------Status encode{begin}------- */

// reasons for error 
// FIXME: Adding cmd should fix this signal
assign is_bad_op       = ~(is_map_icm  | is_unmap_icm | is_init_hca | is_close_hca     | 
                           is_sw2hw_cq | is_resize_cq | is_sw2hw_eq | is_write_mtt     | 
                           is_hw2sw_cq | is_hw2sw_mpt | is_query_qp | is_query_adapter | 
                           is_map_eq   | is_modify_qp | is_hw2sw_eq | is_query_dev_lim |
                           is_sw2hw_mpt| is_mad_ifc);
assign is_bad_param    = ((is_map_icm | is_unmap_icm) & (~(is_in_cm | is_in_v2p))) |  // param in map_icm, unmap_icm
                         (has_inbox  & (reg_in_param     == 0)) |                      // there's inbox, but in_param is zero (no valid inbox addr)
                         (has_outbox & (reg_out_dma_addr == 0)) |                      // there's inbox, but in_param is zero (no valid inbox addr)
                         (is_modify_qp & !((reg_op_modifier == 0) | (reg_op_modifier == 2) | (reg_op_modifier == 3))) |
                         (is_mad_ifc & !(reg_op_modifier == 8'h1));
assign is_bad_sys_stat = (rst_n == 0);

// assign is_bad_nvmem    = ;


// end of module execution
assign is_exe_end = (is_acc_local & acc_local_end) |
                    (is_wr_both   & wr_both_end  ) |
                    (is_acc_cm    & acc_cm_end   ) |
                    (is_wr_v2p    & wr_v2p_end   );

// output hcr register
assign hcr_out_param = 0; // in this version, out_param as an output is unused
assign hcr_status = !is_idle ? (({8{is_bad_op      }} & `HGRNIC_CMD_STAT_BAD_OP       ) |
                                ({8{is_bad_param   }} & `HGRNIC_CMD_STAT_BAD_PARAM    ) |
                                ({8{is_bad_sys_stat}} & `HGRNIC_CMD_STAT_BAD_SYS_STATE) |
                                ({8{is_bad_nvmem   }} & `HGRNIC_CMD_STAT_BAD_NVMEM    )) : 0;
assign hcr_clear  = ((|hcr_status) && is_decode) ||
                    (is_exe_end && is_execute);
/* -------Status encode{end}------- */

/* -------get inbox{begin}------- */

// inbox addr
assign inbox_addr  = reg_in_param;

// inbox length (in bytes)
assign map_icm_len   = {reg_in_modifier[7:1] + reg_in_modifier[0], 5'b0};
assign write_mtt_len = {reg_in_modifier[7:2] + (|reg_in_modifier[1:0]) + 7'd1, 5'b0};

assign inbox_len = ({12{is_init_hca }} & `INBOX_LEN_INIT_HCA ) |
                   ({12{is_sw2hw_cq }} & `INBOX_LEN_SW2HW_CQ ) |
                   ({12{is_resize_cq}} & `INBOX_LEN_RESIZE_CQ) |
                   ({12{is_sw2hw_eq }} & `INBOX_LEN_SW2HW_EQ ) |
                   ({12{is_sw2hw_mpt}} & `INBOX_LEN_SW2HW_MPT) |
                   ({12{is_modify_qp}} & `INBOX_LEN_MODIFY_QP) |
                   ({12{is_map_icm  }} & map_icm_len         ) |
                   ({12{is_write_mtt}} & write_mtt_len       );
/* -------get inbox{end}------- */


//------------------------------{CEU_ctrl FSM}begin------------------------------//
/******************** Stage 1: State Register **********************/

always @(posedge clk or negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end


always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_in_param     <= `TD 0;
        reg_in_modifier  <= `TD 0;
        reg_out_dma_addr <= `TD 0;
        reg_op_modifier  <= `TD 0;
        reg_op           <= `TD 0;
    end
    else if ((is_execute & is_exe_end) || (is_decode & (|hcr_status))) begin
        reg_in_param     <= `TD 0;
        reg_in_modifier  <= `TD 0;
        reg_out_dma_addr <= `TD 0;
        reg_op_modifier  <= `TD 0;
        reg_op           <= `TD 0;
    end
    else if (is_idle & (hcr_go == 1)) begin
        reg_in_param     <= `TD hcr_in_param    ;
        reg_in_modifier  <= `TD hcr_in_modifier ;
        reg_out_dma_addr <= `TD hcr_out_dma_addr;
        reg_op_modifier  <= `TD hcr_op_modifier ;
        reg_op           <= `TD hcr_op          ;
    end
end


/******************** Stage 2: State Transition **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_decode    = (cur_state == DECODE   );
assign is_get_inbox = (cur_state == GET_INBOX);
assign is_execute   = (cur_state == EXECUTE  );

always @(*) begin
    case(cur_state)
         IDLE: begin
            if (hcr_go == 1) begin // incomming HCR command
                nxt_state = DECODE;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        DECODE: begin
            if (hcr_status != 0) begin
                nxt_state = IDLE;
            end
            else if ((hcr_status == 0) & has_inbox) begin
                nxt_state = GET_INBOX;
            end
            else begin // (hcr_status == 0) & (!has_inbox)
                nxt_state = EXECUTE;
            end
        end
        GET_INBOX: begin
            if (dma_rd_req_valid & dma_rd_req_ready) begin // send DMA read request
                nxt_state = EXECUTE;
            end
            else begin
                nxt_state = GET_INBOX;
            end
        end
        EXECUTE: begin
            if (is_exe_end) begin
                nxt_state =  IDLE;
            end
            else begin
                nxt_state = EXECUTE;
            end
        end
        default: begin
            nxt_state =  IDLE;
        end
    endcase
end


/******************** Stage 3: Output **********************/

// output for dma read request
/*************************head*********************************
dma read inbox request head
|--------| --------------------64bit---------------------- |
|  127:  |            R            |     inbox_addr        |
|   64   |         (63:32)         |     (63:32 bit)       |
|--------|-------------------------------------------------|
|   63:  |       inbox_addr        |    R    |  inbox_len  |
|    0   |       (31: 0 bit)       | (31:12) | (11:0 bit)  |
|--------|-------------------------------------------------|
 *****************************************************************/
assign dma_rd_req_valid = is_get_inbox;
assign dma_rd_req_last  = is_get_inbox;
assign dma_rd_req_data  = 0; // dma read request doesn't use data signal
assign dma_rd_req_head  = is_get_inbox ? {32'd0, inbox_addr, 20'd0, inbox_len} : 0;

//------------------------------{CEU_ctrl FSM}end------------------------------//

/* --------stream reg{begin}-------- */
st_reg #(
    .TUSER_WIDTH ( DMA_HEAD_WIDTH  ),
    .TDATA_WIDTH ( `CEU_DATA_WIDTH )
) ceu_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( CEU_dma_rd_rsp_out_valid ), // i, 1
    .axis_tlast  ( CEU_dma_rd_rsp_out_last  ), // i, 1
    .axis_tuser  ( CEU_dma_rd_rsp_out_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( beat_trans(CEU_dma_rd_rsp_out_data)  ), // i, `CEU_DATA_WIDTH
    .axis_tready ( CEU_dma_rd_rsp_out_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_dma_rd_rsp_valid ), // o, 1
    .axis_reg_tlast  ( st_dma_rd_rsp_last  ), // o, 1
    .axis_reg_tuser  ( st_dma_rd_rsp_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_dma_rd_rsp_data  ), // o, `CEU_DATA_WIDTH
    .axis_reg_tready ( st_dma_rd_rsp_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* --------stream reg{end}-------- */

/* -------DMA Read Signal MUX{begin}------- */
assign st_dma_rd_rsp_ready = (is_acc_local & dma_rrsp_local_ready) |
                             (is_acc_cm    & dma_rrsp_cm_ready   ) |
                             (is_wr_v2p    & dma_rrsp_v2p_ready  ) |
                             (is_wr_both   & dma_rrsp_both_ready );
/* -------DMA Read Signal MUX{end}------- */


/* -------DMA Write Signal MUX{begin}------- */
assign CEU_dma_wr_req_in_valid = (is_acc_local & dma_wreq_local_valid) |
                          (is_acc_cm    & dma_wreq_cm_valid   );
assign CEU_dma_wr_req_in_last  = (is_acc_local & dma_wreq_local_last) |
                          (is_acc_cm    & dma_wreq_cm_last   );
assign CEU_dma_wr_req_in_data  = beat_trans(
                                        ({`CEU_DATA_WIDTH  {is_acc_local}} & dma_wreq_local_data) |
                                        ({`CEU_DATA_WIDTH  {is_acc_cm   }} & dma_wreq_cm_data   )
                                );
assign CEU_dma_wr_req_in_head  = ({DMA_HEAD_WIDTH{is_acc_local}} & dma_wreq_local_head) |
                          ({DMA_HEAD_WIDTH{is_acc_cm   }} & dma_wreq_cm_head   );
/* -------DMA Write Signal MUX{end}------- */


/* -------Context Management Request Signal MUX{begin}------- */
assign cm_req_valid = (is_wr_both & cm_req_both_valid) |
                      (is_acc_cm  & cm_req_cm_valid   );
assign cm_req_last  = (is_wr_both & cm_req_both_last) |
                      (is_acc_cm  & cm_req_cm_last   );
assign cm_req_data  = ({`CEU_DATA_WIDTH      {is_wr_both}}  & cm_req_both_data) |
                      ({`CEU_DATA_WIDTH      {is_acc_cm  }} & cm_req_cm_data  );
assign cm_req_head  = ({`CEU_CM_HEAD_WIDTH{is_wr_both}}  & cm_req_both_head) |
                      ({`CEU_CM_HEAD_WIDTH{is_acc_cm  }} & cm_req_cm_head   );
/* -------Context Management Request Signal MUX{end}------- */


/* -------Virtual to physical write Request Signal MUX{begin}------- */
assign v2p_req_valid = (is_wr_both & v2p_req_both_valid) |
                       (is_wr_v2p  & v2p_req_v2p_valid );
assign v2p_req_last  = (is_wr_both & v2p_req_both_last) |
                       (is_wr_v2p  & v2p_req_v2p_last );
assign v2p_req_data  = ({`CEU_DATA_WIDTH       {is_wr_both}} & v2p_req_both_data) |
                       ({`CEU_DATA_WIDTH       {is_wr_v2p }} & v2p_req_v2p_data );
assign v2p_req_head  = ({`CEU_V2P_HEAD_WIDTH{is_wr_both}} & v2p_req_both_head) |
                       ({`CEU_V2P_HEAD_WIDTH{is_wr_v2p }} & v2p_req_v2p_head );
/* -------Virtual to physical write Request Signal MUX{end}------- */
assign dma_rrsp_local_ready = 0;
acc_local #(
    .DMA_HEAD_WIDTH     ( DMA_HEAD_WIDTH     )     // DMA Stream *_head width
) CEU_ACC_LOCAL (
    .clk        ( clk    ),// i, 1
    .rst_n      ( rst_n  ),// i, 1

    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // // DMA read response
    // .dma_rd_rsp_valid ( st_dma_rd_rsp_valid  ), // i, 1
    // .dma_rd_rsp_last  ( st_dma_rd_rsp_last   ), // i, 1
    // .dma_rd_rsp_data  ( st_dma_rd_rsp_data   ), // i, `CEU_DATA_WIDTH
    // .dma_rd_rsp_head  ( st_dma_rd_rsp_head   ), // i, DMA_HEAD_WIDTH
    // .dma_rd_rsp_ready ( dma_rrsp_local_ready ), // o, 1

    // DMA write req
    .dma_wr_req_valid ( dma_wreq_local_valid ), // o, 1
    .dma_wr_req_last  ( dma_wreq_local_last  ), // o, 1
    .dma_wr_req_data  ( dma_wreq_local_data  ), // o, `CEU_DATA_WIDTH
    .dma_wr_req_head  ( dma_wreq_local_head  ), // o, DMA_HEAD_WIDTH
    .dma_wr_req_ready ( CEU_dma_wr_req_in_ready     ), // i, 1
    /* -------DMA Interface{end}------- */

    /* -------CMD Information{begin}------- */
    .op              ( reg_op           ), // i, 12
    .outbox_addr     ( reg_out_dma_addr ), // i, 64
    .op_modifier     ( reg_op_modifier  ), // i, 8
    .is_bad_nvmem    ( is_bad_nvmem     ), // o, 1   ; used to indicate if data of local ram is not ready
    /* -------CMD Information{end}------- */


    .start     ( is_acc_local & is_execute ), // i, 1
    .finish    ( acc_local_end ) // o, 1

`ifdef CEU_DBG_LOGIC 
    ,.rw_data      ( rw_data       ) // i, `ACC_LOCAL_RW_WIDTH
    ,.rw_init_data ( rw_init_data  ) // o, `ACC_LOCAL_RW_WIDTH
    ,.dbg_bus      ( acc_local_dbg ) // o, `ACC_LOCAL_DBG_WIDTH
`endif
);

acc_cm #(
    .DMA_HEAD_WIDTH     ( DMA_HEAD_WIDTH     )     // DMA Stream *_head width
) CEU_ACC_CM (
    .clk   ( clk   ),// i, 1
    .rst_n ( rst_n ),// i, 1

    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    .dma_rd_rsp_valid ( st_dma_rd_rsp_valid  ), // i, 1
    .dma_rd_rsp_last  ( st_dma_rd_rsp_last   ), // i, 1
    .dma_rd_rsp_data  ( st_dma_rd_rsp_data   ), // i, `CEU_DATA_WIDTH
    .dma_rd_rsp_head  ( st_dma_rd_rsp_head   ), // i, DMA_HEAD_WIDTH
    .dma_rd_rsp_ready ( dma_rrsp_cm_ready ), // o, 1

    // DMA write req
    .dma_wr_req_valid ( dma_wreq_cm_valid ), // o, 1
    .dma_wr_req_last  ( dma_wreq_cm_last  ), // o, 1
    .dma_wr_req_data  ( dma_wreq_cm_data  ), // o, `CEU_DATA_WIDTH
    .dma_wr_req_head  ( dma_wreq_cm_head  ), // o, DMA_HEAD_WIDTH
    .dma_wr_req_ready ( CEU_dma_wr_req_in_ready  ), // i, 1
    /* -------DMA Interface{end}------- */

    /* -------Context Management Interface{begin}------- */
    // CtxMgt req
    .cm_req_valid ( cm_req_cm_valid ), // o, 1
    .cm_req_last  ( cm_req_cm_last  ), // o, 1
    .cm_req_data  ( cm_req_cm_data  ), // o, `CEU_DATA_WIDTH
    .cm_req_head  ( cm_req_cm_head  ), // o, `CEU_CM_HEAD_WIDTH
    .cm_req_ready ( cm_req_ready    ), // i, 1

    // CtxMgt read resp
    .cm_rsp_valid ( cm_rsp_valid ), // i, 1
    .cm_rsp_last  ( cm_rsp_last  ), // i, 1
    .cm_rsp_data  ( cm_rsp_data  ), // i, `CEU_DATA_WIDTH
    .cm_rsp_head  ( cm_rsp_head  ), // i, `CEU_CM_HEAD_WIDTH
    .cm_rsp_ready ( cm_rsp_ready ), // o, 1
    /* -------Context Management Interface{end}------- */

    /* -------CMD Information{begin}------- */
    .has_inbox   ( has_inbox        ), // i, 1
    .op          ( reg_op           ), // i, 12
    .in_param    ( reg_in_param     ), // i, 64
    .in_modifier ( reg_in_modifier  ), // i, 32
    .outbox_addr ( reg_out_dma_addr ), // i, 64
    /* -------CMD Information{end}------- */


    .start     ( is_acc_cm & is_execute ), // i, 1
    .finish    ( acc_cm_end )  // o, 1

`ifdef CEU_DBG_LOGIC 
    ,.dbg_bus      ( acc_cm_dbg ) // o, `ACC_CM_DBG_WIDTH
`endif
);

wr_v2p #(
    .DMA_HEAD_WIDTH     ( DMA_HEAD_WIDTH     )     // DMA Stream *_head width
) CEU_WR_V2P (
    .clk        ( clk      ),// i, 1
    .rst_n      ( rst_n ),// i, 1

    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    .dma_rd_rsp_valid ( st_dma_rd_rsp_valid   ), // i, 1
    .dma_rd_rsp_last  ( st_dma_rd_rsp_last    ), // i, 1
    .dma_rd_rsp_data  ( st_dma_rd_rsp_data    ), // i, `CEU_DATA_WIDTH
    .dma_rd_rsp_head  ( st_dma_rd_rsp_head    ), // i, DMA_HEAD_WIDTH
    .dma_rd_rsp_ready ( dma_rrsp_v2p_ready ), // o, 1
    /* -------DMA Interface{end}------- */

    /* -------Virtual-to-physial Interface{begin}------- */
    // VirtToPhys write req
    .v2p_req_valid ( v2p_req_v2p_valid ), // o, 1
    .v2p_req_last  ( v2p_req_v2p_last  ), // o, 1
    .v2p_req_data  ( v2p_req_v2p_data  ), // o, `CEU_DATA_WIDTH
    .v2p_req_head  ( v2p_req_v2p_head  ), // o, `CEU_V2P_HEAD_WIDTH
    .v2p_req_ready ( v2p_req_ready     ),  // i, 1
    /* -------Virtual-to-physial Interface{end}------- */

    /* -------CMD Information{begin}------- */
    .has_inbox   ( has_inbox       ), // i, 1
    .op          ( reg_op          ), // i, 12
    .in_param    ( reg_in_param    ), // i, 64
    .in_modifier ( reg_in_modifier ), // i, 32
    /* -------CMD Information{end}------- */

    .start      ( is_wr_v2p & is_execute  ), // i, 1
    .finish     ( wr_v2p_end )  // o, 1

`ifdef CEU_DBG_LOGIC 
    ,.dbg_bus      ( wr_v2p_dbg ) // o, `WR_V2P_DBG_WIDTH
`endif
);

wr_both #(
    .DMA_HEAD_WIDTH     ( DMA_HEAD_WIDTH     )     // DMA Stream *_head width
) CEU_WR_BOTH (
    .clk      ( clk   ), // i, 1
    .rst_n    ( rst_n ), // i, 1

    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    .dma_rd_rsp_valid ( st_dma_rd_rsp_valid    ), // i, 1
    // .dma_rd_rsp_last  ( st_dma_rd_rsp_last     ), // i, 1
    .dma_rd_rsp_data  ( st_dma_rd_rsp_data     ), // i, `CEU_DATA_WIDTH
    // .dma_rd_rsp_head  ( st_dma_rd_rsp_head     ), // i, DMA_HEAD_WIDTH
    .dma_rd_rsp_ready ( dma_rrsp_both_ready ), // o, 1
    /* -------DMA Interface{end}------- */

    /* -------Virtual-to-physial Interface{begin}------- */
    // VirtToPhys write req
    .v2p_req_valid ( v2p_req_both_valid ), // o, 1
    .v2p_req_last  ( v2p_req_both_last  ), // o, 1
    .v2p_req_data  ( v2p_req_both_data  ), // o, `CEU_DATA_WIDTH
    .v2p_req_head  ( v2p_req_both_head  ), // o, `CEU_V2P_HEAD_WIDTH
    .v2p_req_ready ( v2p_req_ready      ), // i, 1
    /* -------Virtual-to-physial Interface{end}------- */

    /* -------Context Management Interface{begin}------- */
    // CtxMgt req
    .cm_req_valid ( cm_req_both_valid ), // o, 1
    .cm_req_last  ( cm_req_both_last  ), // o, 1
    .cm_req_data  ( cm_req_both_data  ), // o, `CEU_DATA_WIDTH
    .cm_req_head  ( cm_req_both_head  ), // o, `CEU_CM_HEAD_WIDTH
    .cm_req_ready ( cm_req_ready      ), // i, 1
    /* -------Context Management Interface{end}------- */

    /* -------CMD Information{begin}------- */
    .op            ( reg_op           ), // i, 12
    /* -------CMD Information{end}------- */

    .start  ( is_wr_both & is_execute  ), // i, 1
    .finish ( wr_both_end )  // o, 1

`ifdef CEU_DBG_LOGIC 
    ,.dbg_bus      ( wr_both_dbg ) // o, `WR_BOTH_DBG_WIDTH
`endif
);

`ifdef CEU_DBG_LOGIC 

assign ceu_dbg = {  top_dbg      ,
                    acc_cm_dbg   ,
                    acc_local_dbg,
                    wr_both_dbg  ,
                    wr_v2p_dbg   };
assign top_dbg = {  cur_state       , 
                    nxt_state       , 
                    reg_in_param    , 
                    reg_in_modifier , 
                    reg_out_dma_addr, 
                    reg_op_modifier , 
                    reg_op          };

assign ro_data = rw_data;
assign dbg_bus = ceu_dbg >> {dbg_sel, 5'd0};
//assign dbg_bus = ceu_dbg;

`endif

//ceu_ila_0 ceu_ila_0 (
//    .clk ( clk ),
//    .probe0 ( cm_req_valid ),
//    .probe1 ( cm_req_last  ),
//    .probe2 ( cm_req_data  ),
//    .probe3 ( cm_req_head  ),
//    .probe4 ( cm_req_ready )
//);


//ceu_ila_1 ceu_ila_1 (
//    .clk ( clk ),
//    .probe0 ( reg_op     ), // i, 12
//    .probe1 ( inbox_len  ), // i, 12
//    .probe2 ( hcr_clear  ), // i, 1
//    .probe3 ( cur_state  )  // i, 4
//);

// pio_ila_3 pio_ila_3_inst (
//      .clk (clk), 
//      .probe0  ( hcr_in_param     ), // i, 64
//      .probe1  ( hcr_in_modifier  ), // i, 32
//      .probe2  ( hcr_out_dma_addr ), // i, 64
//      .probe3  ( hcr_out_param    ), // i, 64
//      .probe4  ( hcr_token        ), // i, 32
//      .probe5  ( hcr_status       ), // i, 8
//      .probe6  ( hcr_go           ), // i, 1
//      .probe7  ( hcr_clear        ), // i, 1
//      .probe8  ( hcr_event        ), // i, 1
//      .probe9  ( hcr_op_modifier  ), // i, 8
//      .probe10 ( hcr_op           )  // i, 12
//  );

`ifdef ILA_ON
// ila_dma ceu_dma_wr (
//     .clk(clk), // input wire clk


//     .probe0(dma_wr_req_valid), // input wire [0:0]  probe0  
//     .probe1(dma_wr_req_head), // input wire [127:0]  probe1 
//     .probe2(dma_wr_req_data), // input wire [255:0]  probe2 
//     .probe3(dma_wr_req_ready), // input wire [0:0]  probe3 
//     .probe4(dma_wr_req_last) // input wire [0:0]  probe4
// );

ila_ceu ila_ceu_inst (
    .clk(clk), // input wire clk

    .probe0(hcr_in_param), // input wire [63:0]  probe0  
    .probe1(hcr_in_modifier), // input wire [31:0]  probe1 
    .probe2(hcr_out_dma_addr), // input wire [63:0]  probe2 
    .probe3(hcr_token), // input wire [31:0]  probe3 
    .probe4(hcr_go), // input wire [0:0]  probe4 
    .probe5(hcr_event), // input wire [0:0]  probe5 
    .probe6(hcr_op_modifier), // input wire [7:0]  probe6 
    .probe7(hcr_op), // input wire [11:0]  probe7 
    .probe8(hcr_out_param), // input wire [63:0]  probe8 
    .probe9(hcr_status), // input wire [7:0]  probe9 
    .probe10(hcr_clear) // input wire [0:0]  probe10
);
`endif

endmodule
