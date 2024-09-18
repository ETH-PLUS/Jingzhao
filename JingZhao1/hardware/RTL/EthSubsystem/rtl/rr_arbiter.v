
module round_robin_arbiter #(
    parameter N = 32
) (
	input	  wire	            rst_n,
	input	  wire	            clk,
	input	  wire [N-1:0]	    req,
	output  reg [N-1:0]	      grant
);

reg	    [N-1:0]	rotate_ptr;
wire	  [N-1:0]	mask_req;
wire	  [N-1:0]	mask_grant;
wire	  [N-1:0]	grant_comb;

wire		        no_mask_req;
wire	  [N-1:0] nomask_grant;
wire		        update_ptr;

genvar i;

// rotate pointer update logic
assign update_ptr = |grant[N-1:0];

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		rotate_ptr[1:0] <= `TD 2'b11;
  end else if (update_ptr)	begin
		// note: N must be at least 2
		rotate_ptr[0] <= `TD grant[N-1];
		rotate_ptr[1] <= `TD grant[N-1] | grant[0];
	end
end

generate
  for (i=2; i<N; i=i+1) begin:gen_rotate_ptr
    always @ (posedge clk or negedge rst_n) begin
      if (!rst_n)
        rotate_ptr[i] <= `TD 1'b1;
      else if (update_ptr)
        rotate_ptr[i] <= `TD grant[N-1] | (|grant[i-1:0]);
      else 
        rotate_ptr[i] <= `TD rotate_ptr[i];
    end
  end
endgenerate

// mask grant generation logic
assign mask_req[N-1:0] = req[N-1:0] & rotate_ptr[N-1:0];

assign mask_grant[0] = mask_req[0];

generate
  for (i=1; i<N; i=i+1) begin:gen_mask_grant
    assign mask_grant[i] = (~|mask_req[i-1:0]) & mask_req[i];
  end
endgenerate

// non-mask grant generation logic
assign nomask_grant[0] = req[0];
generate
  for (i=1; i<N; i=i+1) begin:gen_nomask_grant
    assign nomask_grant[i] = (~|req[i-1:0]) & req[i];
  end
endgenerate

// grant generation logic
assign no_mask_req = ~|mask_req[N-1:0];
assign grant_comb[N-1:0] = mask_grant[N-1:0] | (nomask_grant[N-1:0] & {N{no_mask_req}});

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n)	
    grant[N-1:0] <= `TD {N{1'b0}};
	else
    grant[N-1:0] <= `TD grant_comb[N-1:0] & ~grant[N-1:0];
end

endmodule