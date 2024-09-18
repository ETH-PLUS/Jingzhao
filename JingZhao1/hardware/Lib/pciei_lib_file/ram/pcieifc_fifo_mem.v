module pcieifc_fifo_mem #(
    parameter DATASIZE  = 8, // Memory data word width
    parameter ADDRSIZE  = 4, // Number of mem address bits
    parameter DEPTH     = 1<<ADDRSIZE
    )
    (output [DATASIZE-1:0] rdata,
        input [DATASIZE-1:0] wdata,
        input [ADDRSIZE-1:0] waddr,
        input [ADDRSIZE-1:0] raddr,
        input wclken,
        input wfull,
        input wclk,
        input wrst_n
    );

    `ifdef VENDORRAM
        // instantiation of a vendor's dual-port RAM
        vendor_ram mem (.dout(rdata), .din(wdata),
        .waddr(waddr), .raddr(raddr),
        .wclken(wclken),
        .wclken_n(wfull), .clk(wclk));
    `else

        localparam GROUP_WIDTH = 2 * (1 << ADDRSIZE) - 1;
        localparam ARRAY_WIDTH = DATASIZE * GROUP_WIDTH;

        wire [ARRAY_WIDTH-1:0]  arr;
        genvar  bb;
        integer ii;
        genvar  kk;
        genvar  jj;

        function integer level_start_index;
        input integer ss;
        begin: func_level_index
            integer pp;
            level_start_index = 0;
            for (pp=0; pp<ss+1; pp=pp+1) begin
                level_start_index = level_start_index + (1 << (ADDRSIZE - pp));
            end
        end
        endfunction

        // RTL Verilog memory model
        reg [DATASIZE-1:0] mem [DEPTH-1:0];
        always @(posedge wclk or negedge wrst_n)
            if (!wrst_n) begin
                for (ii=0; ii<DEPTH; ii=ii+1)
                    mem[ii] <= `TD {DATASIZE{1'b0}};
            end
            else if (wclken && !wfull) 
                mem[waddr] <= `TD wdata;
        
        `ifdef SIMULATION
        
          assign rdata = mem[raddr];
        
        `else
         
          generate
            for (bb=0; bb<DATASIZE; bb=bb+1) begin: d_loop
              for (kk=0; kk<(1<<ADDRSIZE); kk=kk+1) begin: k1_loop
                  // initialize data input
                  if (kk < DEPTH) begin: valid_input
                      assign arr[bb*GROUP_WIDTH+kk] = mem[kk][bb];
                  end
                  else begin: invalid_input
                      assign arr[bb*GROUP_WIDTH+kk] = 1'b0;
                  end
              end

              // generate data output
              assign rdata[bb] = arr[bb*GROUP_WIDTH+GROUP_WIDTH-1];

              for (kk=0; kk<ADDRSIZE; kk=kk+1) begin: k2_loop
                for (jj=0; jj<(1<<(ADDRSIZE-kk-1)); jj=jj+1) begin: j_loop
                    if ((2*jj+1)*(1<<kk) < DEPTH) begin: two_inputs   // two inputs are valid
                        cell_mux2 u_cell_mux2 (
                            .A  (arr[bb*GROUP_WIDTH + level_start_index(kk-1) + 2*jj]      ),
                            .B  (arr[bb*GROUP_WIDTH + level_start_index(kk-1) + 2*jj + 1]  ),
                            .S  (raddr[kk]                                               ),
                            .Y  (arr[bb*GROUP_WIDTH + level_start_index(kk) + jj]          )
                        );
                    end
                    else if (2*jj*(1<<kk) < DEPTH) begin: one_input  // only one input is valid
                        assign arr[bb*GROUP_WIDTH + level_start_index(kk) + jj] = arr[bb*GROUP_WIDTH + level_start_index(kk-1) + 2*jj];
                    end
                    else begin: no_input  // both inputs are invalid
                        assign arr[bb*GROUP_WIDTH + level_start_index(kk) + jj] = 1'b0;
                    end
                end
              end
            end
          endgenerate
          
        `endif
    `endif
endmodule
