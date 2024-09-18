//CREATE INFORMATION
//--------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-08-22
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_virt_addr.sv
//  FUNCTION : 
//
//--------------------------------------------------------------------------------------

//CHANGE HISTORY
//--------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-08-22    v1.0             create
//
//--------------------------------------------------------------------------------------

`ifndef __HCA_VIRT_ADDR__
`define __HCA_VIRT_ADDR__

//----------------------------------------------------------------------------------------
//
// CLASS: hca_virt_addr
//
//----------------------------------------------------------------------------------------
class hca_virt_addr extends uvm_object;
    bit [63:0] full_addr;
    randc bit [31:0] page_align_addr_lo;
    randc bit [31:0] page_align_addr_hi;

    `uvm_object_utils_begin(hca_virt_addr)
    `uvm_object_utils_end

    constraint c_page_align
    {
        page_align_addr_lo[11:0] == 0;
    }

    function new(string name = "hca_virt_addr");
        super.new(name);
    endfunction

endclass: hca_virt_addr

`endif