`timescale 1ns / 100ps
module pcieifc_sync_fifo #(
    parameter DSIZE = 8,
    parameter ASIZE = 4
) (
    input  wire             clk  ,
    input  wire             rst_n,
    input  wire             clr  ,
    input  wire             wen  ,
    input  wire             ren  ,
    input  wire [DSIZE-1:0] din  ,
    output wire [DSIZE-1:0] dout ,
    output wire             full ,
    output wire             empty

`ifdef PCIEI_APB_DBG
    ,input wire  [1:0]  rtsel
    ,input wire  [1:0]  wtsel
    ,input wire  [1:0]  ptsel
    ,input wire         vg   
    ,input wire         vs   
`endif
);

generate 
if((ASIZE == 2 && DSIZE == 388) || // eth_cfg, 1, eth_cfg_sync_fifo
   (ASIZE == 2 && DSIZE == 132) || // p2p_access, 1, p2p_cfg_sync_fifo
   (ASIZE == 4 && DSIZE == 273) || // rq_async_fifos, 1, pkt_store_fifo
   (ASIZE == 2 && DSIZE == 128)    // sub_req_rsp_concat, 1, head_store_fifo
   ) begin:DEFAULT0_FIFO	
    reg [ASIZE:0]   waddr;
    reg [ASIZE:0]   raddr;

    wire            wr_dis;

    assign wr_dis = full & (~ren);

    pcieifc_fifo_mem #(
        .DATASIZE(DSIZE),
        .ADDRSIZE(ASIZE),
        .DEPTH(1<<ASIZE)
        ) u_fifo_mem (
        .rdata(dout),
        .wdata(din),
        .waddr(waddr[ASIZE-1:0]),
        .raddr(raddr[ASIZE-1:0]),
        .wclken(wen),
        .wfull(wr_dis),
        .wclk(clk),
        .wrst_n(rst_n)
    );

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            waddr <= `TD {(ASIZE+1){1'b0}};
        end
        else if (clr) begin
            waddr <= `TD {(ASIZE+1){1'b0}};
        end
        else if(wen) begin
            if (!wr_dis) begin
                waddr <= `TD waddr + 1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            raddr <= `TD {(ASIZE+1){1'b0}};
        end
        else if (clr) begin
            raddr <= `TD {(ASIZE+1){1'b0}};
        end
        else if(ren) begin
            if (!empty) begin
                raddr <= `TD raddr + 1;
            end
        end
    end

    assign empty = (raddr == waddr);
    assign full  = (raddr[ASIZE-1:0] == waddr[ASIZE-1:0]) & (raddr[ASIZE] != waddr[ASIZE]);

end 
else begin: GEN_SYNC_FIFO_XILINX_IP
    wire             st_wen  ;
    wire             st_ren  ;
    wire [DSIZE-1:0] st_din  ;
    wire [DSIZE-1:0] st_dout ;
    wire             st_full ;
    wire             st_empty;
    wire fifo_in_ready ;
    wire fifo_out_valid;


    /* --------Stream reg out for rd rsp{begin}-------- */
    assign full = !fifo_in_ready;
    st_reg #(
        .TUSER_WIDTH ( 1     ), // unused
        .TDATA_WIDTH ( DSIZE )  // 256
    ) in_fifo_st_reg (
        .clk   ( clk   ), // i, 1
        .rst_n ( rst_n ), // i, 1

        /* -------input axis-like interface{begin}------- */
        .axis_tvalid ( wen   ), // i, 1
        .axis_tlast  ( 1'b0  ), // i, 1
        .axis_tuser  ( 1'b0  ), // i, TUSER_WIDTH
        .axis_tdata  ( din   ), // i, TDATA_WIDTH
        .axis_tready ( fifo_in_ready ), // o, 1
        /* -------input axis-like interface{end}------- */

        /* -------output st_reg inteface{begin}------- */
        .axis_reg_tvalid ( st_wen   ), // o, 1  
        .axis_reg_tlast  (          ), // o, 1
        .axis_reg_tuser  (          ), // o, TUSER_WIDTH
        .axis_reg_tdata  ( st_din   ), // o, TDATA_WIDTH
        .axis_reg_tready ( !st_full )  // i, 1
        /* -------output st_reg inteface{end}------- */
    );
    /* --------Stream reg out for rd rsp{end}-------- */

	if(ASIZE == 5 && DSIZE == 265) begin : GEN_SYNC_FIFO_265W_32D // rq_async_fifos, 1, pkt_store_fifo
	    pcieifc_sync_fifo_265W_32D pcieifc_sync_fifo_265W_32D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end 
	else if(ASIZE == 6 && DSIZE == 6) begin : GEN_SYNC_FIFO_6W_64D // free_tag_fifo
	    pcieifc_sync_fifo_6W_64D pcieifc_sync_fifo_6W_64D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end 
	else if(ASIZE == 6 && DSIZE == 30) begin : GEN_SYNC_FIFO_30W_64D // allocated_tag_fifo
	    pcieifc_sync_fifo_30W_64D pcieifc_sync_fifo_30W_64D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end 
	else if(ASIZE == 4 && DSIZE == 8) begin : GEN_SYNC_FIFO_8W_16D // rsp_data_fifo
	    pcieifc_sync_fifo_8W_16D pcieifc_sync_fifo_8W_16D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end
	else if(ASIZE == 7 && DSIZE == 385) begin : GEN_SYNC_FIFO_385W_128D // data_sync_fifo
	    pcieifc_sync_fifo_385W_128D pcieifc_sync_fifo_385W_128D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end
	else if(ASIZE == 6 && DSIZE == 64) begin : GEN_SYNC_FIFO_64W_64D // doorbell sync fifo
	    pcieifc_sync_fifo_64W_64D pcieifc_sync_fifo_64W_64D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end
	else if(ASIZE == 7 && DSIZE == 256) begin : GEN_SYNC_FIFO_256W_128D // data fifo
	    pcieifc_sync_fifo_256W_128D pcieifc_sync_fifo_256W_128D_inst (
	      .clk(clk),      // input wire clk
	      .srst(~rst_n),    // input wire srst
	      .din(st_din),      // input wire [387 : 0] din
	      .wr_en(st_wen),  // input wire wr_en
	      .rd_en(st_ren),  // input wire rd_en
	      .dout(st_dout),    // output wire [387 : 0] dout
	      .full(st_full),    // output wire full
	      .empty(st_empty)  // output wire empty
	    );
	end
	else begin: GENERATED_FIFO
	
	end
    

    /* --------Stream reg out fifo out{begin}-------- */
    assign empty = !fifo_out_valid;
    st_reg #(
        .TUSER_WIDTH ( 1     ), // unused
        .TDATA_WIDTH ( DSIZE )  // 256
    ) out_fifo_st_reg (
        .clk   ( clk   ), // i, 1
        .rst_n ( rst_n ), // i, 1

        /* -------input axis-like interface{begin}------- */
        .axis_tvalid ( !st_empty ), // i, 1
        .axis_tlast  ( 1'b0      ), // i, 1
        .axis_tuser  ( 1'b0      ), // i, TUSER_WIDTH
        .axis_tdata  ( st_dout   ), // i, TDATA_WIDTH
        .axis_tready ( st_ren    ), // o, 1
        /* -------input axis-like interface{end}------- */

        /* -------output st_reg inteface{begin}------- */
        .axis_reg_tvalid ( fifo_out_valid ), // o, 1  
        .axis_reg_tlast  (            ), // o, 1
        .axis_reg_tuser  (            ), // o, TUSER_WIDTH
        .axis_reg_tdata  ( dout       ), // o, TDATA_WIDTH
        .axis_reg_tready ( ren        )  // i, 1
        /* -------output st_reg inteface{end}------- */
    );
end
endgenerate

endmodule
