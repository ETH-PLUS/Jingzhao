//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-09-14
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_mem_info.sv
//  FUNCTION : .
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-09-14    v1.0             create
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_MEM_INFO__
`define __HCA_MEM_INFO__

//----------------------------------------------------------------------------
//
// CLASS: hca_mem_info
//
//----------------------------------------------------------------------------
class hca_mem_info extends uvm_object;

    mpt mem_region[][$];
    mtt mem_table[][$];

    `uvm_object_utils_begin(hca_mem_info)
    `uvm_object_utils_end

    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_mem_info");
        super.new(name);
    endfunction

    function init(int host_num);
        mem_region = new[host_num];
        mem_table = new[host_num];
    endfunction: init

endclass: hca_mem_info
`endif