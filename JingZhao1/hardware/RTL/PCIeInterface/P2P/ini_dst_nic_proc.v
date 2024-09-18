`timescale 1ns / 100ps
//*************************************************************************
// > File Name: ini_dst_nic_proc.v
// > Author   : Kangning
// > Date     : 2022-07-25
// > Note     : Related processing if destination address is belongs to NIC.
//*************************************************************************


module ini_dst_nic_proc #(
    
) (

    input  wire clk   , // i, 1
    input  wire rst_n , // i, 1

    /* -------next pkt information{begin}-------- */
    input  wire                                nxt_is_valid, // i, 1
    input  wire [`DEV_TYPE_WIDTH      - 1 : 0] nxt_dev_type, // i, `DEV_TYPE_WIDTH
    input  wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] nxt_bar_addr, // i, `BAR_ADDR_BASE_WIDTH
    /* -------next pkt information{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    input  wire                        p2p_upper_valid, // i, 1             
    input  wire                        p2p_upper_last , // i, 1     
    input  wire [`P2P_UHEAD_W - 1 : 0] p2p_upper_head , // i, `P2P_UHEAD_W        
    input  wire [`P2P_DATA_W  - 1 : 0] p2p_upper_data , // i, `P2P_DATA_W  
    output wire                        p2p_upper_ready, // o, 1        
    /* --------p2p forward up channel{end}-------- */

    /* --------current pkt information{begin}-------- */
    input  wire                                is_valid, // i, 1
    input  wire [`DEV_TYPE_WIDTH      - 1 : 0] dev_type, // i, `DEV_TYPE_WIDTH
    input  wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] bar_addr, // i, `BAR_ADDR_BASE_WIDTH
    /* --------current pkt information{end}-------- */

    /* -------output inteface{begin}------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:16   |    15:0     |
     */
    output wire                       axis_nic_valid, // o, 1 
    output wire                       axis_nic_last , // o, 1 
    output wire [`DMA_HEAD_W - 1 : 0] axis_nic_head , // o, `DMA_HEAD_W
    output wire [`P2P_DATA_W - 1 : 0] axis_nic_data , // o, `P2P_DATA_W
    input  wire                       axis_nic_ready  // i, 1
    /* -------output inteface{end}------- */
);

localparam P2P_BYTE_NUM = `P2P_DATA_W / 8; // byte num in one beat

/* -------- FSM when Destination is NIC{begin}-------- */
localparam  IDLE    = 3'b001,
            TX_DESC = 3'b010,
            TX_PYLD = 3'b100;

reg [2:0] cur_state, nxt_state;
wire is_idle, is_tx_desc, is_tx_pyld;
/* -------- FSM when Destination is NIC{end}-------- */

/* -------- Output head generation {begin} -------- */
reg [15:0] byte_left;

wire [`DEV_NUM_WIDTH-1:0] pyld_dst_dev, pyld_src_dev;
wire [15:0] pyld_byte_len;
wire [63:0] pyld_addr;

wire [15:0] desc_byte_len;
wire [63:0] desc_addr;

wire [`P2P_DATA_W-1:0] pyld_data_w, desc_data_w;
wire [`DMA_HEAD_W-1:0] pyld_head_w, desc_head_w;
/* -------- Output head generation {end} -------- */

//----------------------------------------------------------------------------------------------------------------------------------------------//

/* -------- Output head generation {begin} -------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        byte_left <= `TD 0;
    end
    else if (is_tx_pyld & axis_nic_valid & axis_nic_ready & axis_nic_last) begin
        byte_left <= `TD 0;
    end
    else if (is_tx_desc & axis_nic_valid & axis_nic_ready) begin
        byte_left <= `TD pyld_byte_len;
    end
    else if (is_tx_pyld & axis_nic_valid & axis_nic_ready) begin
        byte_left <= `TD byte_left - P2P_BYTE_NUM;
    end
end 

assign pyld_head_w = {32'd0, pyld_addr, 16'd0, pyld_byte_len};
assign pyld_data_w = p2p_upper_data;

assign desc_head_w = {32'd0, desc_addr, 16'd0, desc_byte_len};
assign desc_data_w = {192'd0, pyld_dst_dev, pyld_src_dev, pyld_byte_len, 32'd0};

assign pyld_dst_dev  = p2p_upper_head[32+2*`DEV_NUM_WIDTH-1:32+`DEV_NUM_WIDTH];
assign pyld_src_dev  = p2p_upper_head[32+`DEV_NUM_WIDTH-1:32];
assign pyld_byte_len = p2p_upper_head[15:0];
assign pyld_addr     = {bar_addr, 14'd0};

assign desc_byte_len = 16'd16;
assign desc_addr     = {bar_addr, 14'h0} + `BAR_DESC_OFFSET;
/* -------- Output head generation {end} -------- */

/* -------Destinstaion NIC processing FSM{begin}------- */
/******************** Stage 1: State Register **********************/
assign is_idle    = (cur_state == IDLE   );
assign is_tx_desc = (cur_state == TX_DESC);
assign is_tx_pyld = (cur_state == TX_PYLD);

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
            if (nxt_dev_type == `DEV_NIC & nxt_is_valid) // Imlying the only beat
                nxt_state = TX_DESC;
            else
                nxt_state = IDLE;
        end
        TX_DESC: begin
            if (axis_nic_valid & axis_nic_ready)
                nxt_state = TX_PYLD;
            else
                nxt_state = TX_DESC;
        end
        TX_PYLD: begin
            if (axis_nic_valid & axis_nic_ready & axis_nic_last) begin
                if (nxt_dev_type == `DEV_NIC & nxt_is_valid)
                    nxt_state = TX_DESC;
                else
                    nxt_state = IDLE;
            end
            else
                nxt_state = TX_PYLD;
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign axis_nic_valid =  is_tx_desc |
                        (is_tx_pyld & p2p_upper_valid);
assign axis_nic_last  =  is_tx_desc | 
                        (is_tx_pyld & (byte_left <= 16'd32));
assign axis_nic_head  = ({`DMA_HEAD_W{is_tx_desc}} & desc_head_w) |
                        ({`DMA_HEAD_W{is_tx_pyld}} & pyld_head_w);
assign axis_nic_data  = ({`P2P_DATA_W{is_tx_desc}} & desc_data_w) |
                        ({`P2P_DATA_W{is_tx_pyld}} & pyld_data_w);

assign p2p_upper_ready = is_tx_pyld & axis_nic_ready;
/* -------Destinstaion NIC processing FSM{end}------- */

endmodule
