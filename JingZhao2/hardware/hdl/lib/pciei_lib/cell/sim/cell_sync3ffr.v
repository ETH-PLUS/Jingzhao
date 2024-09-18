// 3-FF synchronizer with reset input

module cell_sync3ffr (
    input   CK,
    input   D,
    input   R,      // active HIGH reset
    output  Q
);

reg sync_1ff; // 1-stage sync
reg sync_2ff; // 2-stage sync
reg sync_3ff; // 3-stage sync

assign Q = sync_3ff;

always @(posedge CK or posedge R)
begin
    if (R) begin
        sync_1ff <= 1'b0;
        sync_2ff <= 1'b0;
        sync_3ff <= 1'b0;
    end
    else begin
        sync_1ff <= D;
        sync_2ff <= sync_1ff;
        sync_3ff <= sync_2ff;
    end
end

endmodule
