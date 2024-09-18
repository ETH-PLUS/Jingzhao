/*-------------------------------------------------- Common Function Definition : Begin ------------------------------------------*/
`ifndef COMMON_FUNCTION
`define COMMON_FUNCTION
    function integer log2b;
    input integer val;
    begin: func_log2b
        integer i;
        log2b = 1;
        for(i = 0; i < 32; i = i + 1) begin
            if(|(val >> i)) begin
                log2b = i + 1;
            end
        end
    end
    endfunction
`endif
/*-------------------------------------------------- Common Function Definition : End -------------------------------------------*/




