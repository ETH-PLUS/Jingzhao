// 3-FF synchronizer with set input

module cell_sync3ffs (
    input   CK,
    input   D,
    input   SN,     // active LOW set
    output  Q
);

reg sync_1ff; // 1-stage sync
reg sync_2ff; // 2-stage sync
reg sync_3ff; // 2-stage sync

assign Q = sync_3ff;

always @(posedge CK or negedge SN)
begin
    if (~SN) begin
        sync_1ff <= 1'b1;
        sync_2ff <= 1'b1;
        sync_3ff <= 1'b1;
    end
    else begin
        sync_1ff <= D;
        sync_2ff <= sync_1ff;
        sync_3ff <= sync_2ff;
    end
end

endmodule
