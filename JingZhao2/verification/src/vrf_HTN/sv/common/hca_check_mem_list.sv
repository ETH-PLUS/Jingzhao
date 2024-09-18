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

`ifndef __HCA_CHECK_MEM_LIST__
`define __HCA_CHECK_MEM_LIST__

//----------------------------------------------------------------------------
//
// CLASS: hca_check_mem_list
//
//----------------------------------------------------------------------------
class hca_check_mem_list extends uvm_object;

    check_mem_unit check_list[][$];

    `uvm_object_utils_begin(hca_check_mem_list)
    `uvm_object_utils_end

    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_check_mem_list");
        super.new(name);
    endfunction

    function init(int host_num);
        check_list = new[host_num];
    endfunction: init

endclass: hca_check_mem_list
`endif