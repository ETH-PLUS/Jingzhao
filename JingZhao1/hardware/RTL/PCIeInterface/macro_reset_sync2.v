module macro_reset_sync2(
	input test_en,
	input reset_n,
	input ck,
	output reset_sync_n
);

reg d1, d2;

always @(posedge ck or negedge reset_n) begin
	if(~reset_n) begin
		{d2, d1} <= 2'b0;
	end 
	else begin
		{d2, d1} <= {d1, 1'b1};
	end 
end 

assign reset_sync_n = test_en ? reset_n : d2;

endmodule 
