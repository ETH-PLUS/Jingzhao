module DW_minmax (
    // Inputs
    a,
    tc,
    min_max,
    // Outputs
    value,
    index
);
parameter WIDTH =                 4;        // element WIDTH
parameter NUM_INPUTS =                 8;        // number of elements in input array
parameter INDEX_WIDTH =         3;        // size of index pointer = ceil(log2(NUM_INPUTS))
input  [NUM_INPUTS*WIDTH-1 : 0]                a;        // Concatenated input vector
input                                        tc;        // 0 = unsigned, 1 = signed
input                                        min_max;// 0 = find min, 1 = find max
output [WIDTH-1:0]                        value;        // mon or max value found
output [INDEX_WIDTH-1:0]                index;        // index to value found
wire   [NUM_INPUTS*WIDTH-1 : 0]                a_uns, a_trans;
reg    [WIDTH-1:0]                        val_int;
wire   [WIDTH-1:0]                        val_trans;
reg    [INDEX_WIDTH-1:0]                indx_int;
wire [INDEX_WIDTH:0] num_inputs_log2;
assign num_inputs_log2 = 1 << INDEX_WIDTH;
assign a_uns = (WIDTH == 1) ? a ^ {NUM_INPUTS{tc}}: a ^ { NUM_INPUTS { tc, { WIDTH-1 {1'b0}}}};
assign a_trans = a_uns;
always @ (a_trans or min_max) begin : PROC_find_minmax
    reg    [WIDTH-1:0]        val_1, val_2;
    reg    [INDEX_WIDTH-1 : 0]        indx_1, indx_2;
    reg    [( (2 << INDEX_WIDTH)-1)*WIDTH-1 : 0]         val_array;
    reg    [( (2 << INDEX_WIDTH)-1)*INDEX_WIDTH-1:0] indx_array;
    reg    [31 : 0]                i, j, k, l, m, n;
    i = 0;
    j = 0;
    val_array = {WIDTH << (INDEX_WIDTH+1){1'b0}};
    indx_array = {INDEX_WIDTH << (INDEX_WIDTH+1){1'b0}};
    for (n=0 ; n<NUM_INPUTS ; n=n+1) begin
        for (m=0 ; m<WIDTH ; m=m+1)
        val_array[i+m] = a_trans[i+m];
        for (m=0 ; m < INDEX_WIDTH ; m=m+1)
        indx_array[j+m] = n[m];
        i = i + WIDTH;
        j = j + INDEX_WIDTH;
    end
    for (n=NUM_INPUTS ; n<(1 << INDEX_WIDTH) ; n=n+1) begin
        for (m=0 ; m<WIDTH ; m=m+1)
        val_array[i+m] = val_array[(NUM_INPUTS-1)*WIDTH+m];
        for (m=0 ; m < INDEX_WIDTH ; m=m+1)
        indx_array[j+m] = indx_array[(NUM_INPUTS-1)*INDEX_WIDTH+m];
        i = i + WIDTH;
        j = j + INDEX_WIDTH;
    end
    k = 0;
    l = 0;
    for (n=0 ; n < (1 << (INDEX_WIDTH-1))*2-1 ; n=n+1) begin

        for (m=0 ; m<WIDTH ; m=m+1) begin
            val_1[m] = val_array[k+m];
        end

        for (m=0 ; m<INDEX_WIDTH ; m=m+1) begin
            indx_1[m] = indx_array[l+m];
        end
        k = k + WIDTH;
        l = l + INDEX_WIDTH;

        for (m=0 ; m<WIDTH ; m=m+1) begin
            val_2[m] = val_array[k+m];
        end
        for (m=0 ; m<INDEX_WIDTH ; m=m+1) begin
            indx_2[m] = indx_array[l+m];
        end
        k = k + WIDTH;
        l = l + INDEX_WIDTH;
        if (((min_max==1'b1) && (val_1 > val_2)) || ((min_max==1'b0) && (val_1 <= val_2))) begin
            for (m=0 ; m<WIDTH ; m=m+1)
            val_array[i+m] = val_1[m];

            for (m=0 ; m<INDEX_WIDTH ; m=m+1)
            indx_array[j+m] = indx_1[m];
        end else begin
            for (m=0 ; m<WIDTH ; m=m+1)
            val_array[i+m] = val_2[m];

            for (m=0 ; m<INDEX_WIDTH ; m=m+1)
            indx_array[j+m] = indx_2[m];
        end
        i = i + WIDTH;
        j = j + INDEX_WIDTH;
    end
    for (m=0 ; m < WIDTH ; m=m+1)
    val_int[m] = val_array[k+m];

    for (m=0 ; m < INDEX_WIDTH ; m=m+1)
    indx_int[m] = indx_array[l+m];

end
assign val_trans = val_int;
assign value = (WIDTH == 1) ? val_trans ^ tc: val_trans ^ { tc, { WIDTH-1 {1'b0}}};
assign index = indx_int;
endmodule
