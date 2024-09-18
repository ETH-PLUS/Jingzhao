`timescale 1ns / 100ps
//*************************************************************************
// > File   : tgt_pyld_recv_proc.v
// > Author : Kangning
// > Date   : 2022-08-25
// > Note   : target payload recvive processing
//*************************************************************************

module tgt_pyld_recv_proc #(
    
) (

    input  wire clk     , // i, 1
    input  wire rst_n   , // i, 1
    output reg  init_end, // o, 1
    
    /* --------Next mem payload{begin}-------- */
    input  wire             nxt_vaild, // i, 1
    input  wire [7:0]       nxt_qnum , // i, 8
    /* --------Next mem payload{end}-------- */
    
    /* --------p2p mem payload in{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire                   st0_p2p_pyld_req_valid, // i, 1
    input  wire                   st0_p2p_pyld_req_last , // i, 1
    input  wire [`P2P_HEAD_W-1:0] st0_p2p_pyld_req_head , // i, `P2P_HEAD_W
    input  wire [`P2P_DATA_W-1:0] st0_p2p_pyld_req_data , // i, `P2P_DATA_W
    output wire                   st0_p2p_pyld_req_ready, // o, 1
    /* --------p2p mem payload in{end}-------- */
    
    /* --------p2p mem payload out{begin}-------- */
    output wire                       st_pyld_req_valid, // o, 1
    output wire                       st_pyld_req_last , // o, 1
    output wire [`MSG_BLEN_WIDTH-1:0] st_pyld_req_blen , // o, `MSG_BLEN_WIDTH
    output wire [8              -1:0] st_pyld_req_qnum , // o, 8
    output wire [`P2P_DATA_W    -1:0] st_pyld_req_data , // o, `P2P_DATA_W
    input  wire                       st_pyld_req_ready, // i, 1
    /* --------p2p mem payload out{end}-------- */

    /* --------dropped queue{begin}-------- */
    input  wire                      dropped_wen , // i, 1
    input  wire [`QUEUE_NUM_LOG-1:0] dropped_qnum, // i, `QUEUE_NUM_LOG
    input  wire                      dropped_data  // i, 1
    /* --------dropped queue{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output  wire [`TGT_RECV_SIGNAL_W-1:0] dbg_signal
    /* -------APB reated signal{end}------- */
`endif
);

/* --------Dropped Register{begin}-------- */
// reg init_end;
reg [`QUEUE_NUM_LOG-1:0] tab_index;
reg dropped_tab[`QUEUE_NUM-1:0];
reg [7:0] pass_qnum;
/* --------Dropped Register{end}-------- */

/* --------Payload Receiving FSM{begin}-------- */
localparam  IDLE      = 3'b001,
            PYLD_DROP = 3'b010,
            PYLD_PASS = 3'b100;

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_idle, is_pyld_drop, is_pyld_pass;
// wire j_pyld_pass;
wire is_nxt_pass; // process next pkt in the next cycle
/* --------Payload Receiving FSM{end}-------- */

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- //

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_signal = { // 38

    tab_index, // 4
    
    dropped_tab[0 ], dropped_tab[1 ], dropped_tab[2 ], dropped_tab[3 ], 
    dropped_tab[4 ], dropped_tab[5 ], dropped_tab[6 ], dropped_tab[7 ], 
    dropped_tab[8 ], dropped_tab[9 ], dropped_tab[10], dropped_tab[11], 
    dropped_tab[12], dropped_tab[13], dropped_tab[14], dropped_tab[15], // 16 

    pass_qnum, cur_state, nxt_state, is_idle, is_pyld_drop, is_pyld_pass, is_nxt_pass // 18
};
/* -------APB reated signal{end}------- */
`endif

/* --------Dropped Register{begin}-------- */

// Init state end
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        init_end <= `TD 0;
    end
    else if (tab_index == (1'h1 << `QUEUE_NUM_LOG) - 1) begin
        init_end <= `TD 1;
    end
end

// drop table index calculation
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        tab_index <= `TD 0;
    end
    else if (~init_end) begin
        tab_index <= `TD tab_index + 1;
    end
end

// drop table update
integer i;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        for (i =  0; i < `QUEUE_NUM; i=i+1) begin
            dropped_tab[i] <= `TD 0;
        end
    end
    else if (~init_end) begin // Initialize queue drop table
        dropped_tab[tab_index] <= `TD 1;
    end
    else if (dropped_wen) begin
        dropped_tab[dropped_qnum] <= `TD dropped_data;
    end
    // else if (is_nxt_pass) begin // if next state is pass (pass new payload), 
    //                             // set accordingly queue to dropped state
    //     dropped_tab[tab_index] <= `TD 1;
    // end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        pass_qnum <= `TD 0;
    end
    else if (is_nxt_pass) begin
        pass_qnum <= `TD nxt_qnum;
    end
end
/* --------Dropped Register{end}-------- */


/* -------Payload Receiving FSM{begin}------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_pyld_drop = (cur_state == PYLD_DROP);
assign is_pyld_pass = (cur_state == PYLD_PASS);

// assign j_pyld_pass  = (nxt_state == IDLE) & (cur_state == PYLD_PASS);

assign is_nxt_pass  =   ((cur_state == IDLE     ) & (nxt_state == PYLD_PASS)) |
                        ((cur_state == PYLD_DROP) & (nxt_state == PYLD_PASS)) |
                        ((cur_state == PYLD_PASS) & (nxt_state == PYLD_PASS) & st0_p2p_pyld_req_valid & st0_p2p_pyld_req_ready & st0_p2p_pyld_req_last);

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (nxt_vaild) begin
                if (dropped_tab[nxt_qnum]) begin
                    nxt_state = PYLD_DROP;
                end
                else begin
                    nxt_state = PYLD_PASS;
                end
            end
            else begin
                nxt_state = IDLE;
            end
        end
        PYLD_DROP: begin
            if (st0_p2p_pyld_req_valid & st0_p2p_pyld_req_last) begin
                if (nxt_vaild) begin
                    if (dropped_tab[nxt_qnum]) begin
                        nxt_state = PYLD_DROP;
                    end
                    else begin
                        nxt_state = PYLD_PASS;
                    end
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = PYLD_DROP;
            end
        end
        PYLD_PASS: begin
            if (st0_p2p_pyld_req_valid & st0_p2p_pyld_req_ready & st0_p2p_pyld_req_last) begin
                if (nxt_vaild) begin
                    if (dropped_tab[nxt_qnum]) begin
                        nxt_state = PYLD_DROP;
                    end
                    else begin
                        nxt_state = PYLD_PASS;
                    end
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = PYLD_PASS;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign st0_p2p_pyld_req_ready = is_pyld_drop | (is_pyld_pass & st_pyld_req_ready);

assign st_pyld_req_valid = is_pyld_pass ? st0_p2p_pyld_req_valid                     : 0;
assign st_pyld_req_last  = is_pyld_pass ? st0_p2p_pyld_req_last                      : 0;
assign st_pyld_req_blen  = is_pyld_pass ? st0_p2p_pyld_req_head[`MSG_BLEN_WIDTH-1:0] : 0;
assign st_pyld_req_qnum  = is_pyld_pass ? pass_qnum                                  : 0;
assign st_pyld_req_data  = is_pyld_pass ? st0_p2p_pyld_req_data                      : 0;
/* -------Destinstaion NIC processing FSM{end}------- */

endmodule
