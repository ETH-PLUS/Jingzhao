`timescale 1ns / 100ps
//*************************************************************************
// > File Name: ini_pyld_split_proc.v
// > Author   : Kangning
// > Date     : 2022-07-27
// > Note     : split payload into 4KB aligned packet
//*************************************************************************


module ini_pyld_split_proc #(
    
) (

    input  wire clk   , // i, 1
    input  wire rst_n , // i, 1

    /* --------raw pyld{begin}-------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:16   |    15:0     |
     */
    input  wire                       axis_raw_valid, // i, 1             
    input  wire                       axis_raw_last , // i, 1     
    input  wire [`DMA_HEAD_W - 1 : 0] axis_raw_head , // i, `DMA_HEAD_W
    input  wire [`P2P_DATA_W - 1 : 0] axis_raw_data , // i, `P2P_DATA_W  
    output wire                       axis_raw_ready, // o, 1        
    /* --------raw pyld{end}-------- */

    /* -------splited_pyld{begin}------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:16   |    15:0     |
     */
    output wire                       axis_splited_valid, // o, 1 
    output wire                       axis_splited_last , // o, 1 
    output wire [`DMA_HEAD_W - 1 : 0] axis_splited_head , // o, `DMA_HEAD_W
    output wire [`P2P_DATA_W - 1 : 0] axis_splited_data , // o, `P2P_DATA_W
    input  wire                       axis_splited_ready  // i, 1
    /* -------splited_pyld{end}------- */
);

assign axis_splited_valid = axis_raw_valid;
assign axis_splited_last  = axis_raw_last ;
assign axis_splited_head  = axis_raw_head ;
assign axis_splited_data  = axis_raw_data ;
assign axis_raw_ready     = axis_splited_ready;

endmodule
