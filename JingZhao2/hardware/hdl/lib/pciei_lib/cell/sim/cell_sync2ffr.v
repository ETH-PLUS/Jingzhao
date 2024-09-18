// 2-FF synchronizer with reset input
`timescale 1ns / 100ps
module cell_sync2ffr (
    input   CK,
    input   D,
    input   R,      // active HIGH reset
    output  Q
);

reg sync_1ff; // 1-stage sync
reg sync_2ff; // 2-stage sync

assign Q = sync_2ff;

always @(posedge CK or posedge R)
begin
    if (R) begin
        sync_1ff <= 1'b0;
        sync_2ff <= 1'b0;
    end
    else begin
        sync_1ff <= D;
        sync_2ff <= sync_1ff;
    end
end

endmodule
