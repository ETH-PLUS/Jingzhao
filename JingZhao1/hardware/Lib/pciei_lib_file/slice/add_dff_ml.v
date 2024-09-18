module add_dff_ml#(
    parameter DATA_WIDTH  = 1,
    parameter NUM_LEVELS  = 1
)

(
    // Outputs
    data_d,
    // Inputs
    data_s,
    clk_d,
    rstn_d
    );


    input [DATA_WIDTH-1:0]  data_s;   // data vector in source domain, to be synced
    input                   clk_d;    // clock in destination domain
    input                   rstn_d;   // async reset in destination domain, active low
    output [DATA_WIDTH-1:0] data_d;   // data vector in destination domain

wire [DATA_WIDTH-1:0] data[NUM_LEVELS:0];
assign data_d = data[NUM_LEVELS];
assign data[0]=data_s;
genvar i;
generate for (i=0; i<NUM_LEVELS;i=i+1) begin: add_dff_ins
    add_dff #(DATA_WIDTH) u_add_dff(
        .clk_d(clk_d),
        .rstn_d(rstn_d),
        .data_s(data[i]),
        .data_d(data[i+1])
        );
    end 
endgenerate 

endmodule
