// 2-FF synchronizer with set input

module cell_sync2ffs (
    input   CK,
    input   D,
    input   SN,     // active LOW set
    output  Q
);

reg sync_1ff; // 1-stage sync
reg sync_2ff; // 2-stage sync

assign Q = sync_2ff;

always @(posedge CK or negedge SN)
begin
    if (~SN) begin
        sync_1ff <= 1'b1;
        sync_2ff <= 1'b1;
    end
    else begin
        sync_1ff <= D;
        sync_2ff <= sync_1ff;
    end
end

endmodule
