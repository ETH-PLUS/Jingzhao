//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-09-16
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_comp_queue.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-09-16    v1.0             create
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_COMP_QUEUE__
`define __HCA_COMP_QUEUE__

//----------------------------------------------------------------------------
//
// CLASS: hca_comp_queue
//
//----------------------------------------------------------------------------
class hca_comp_queue extends uvm_object;

    cq_context ctx;
    addr    header;
    addr    tail;
    addr    last_header;
    cqe     cqe_list[$];

    `uvm_object_utils_begin(hca_comp_queue)
    `uvm_object_utils_end

    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_comp_queue");
        super.new(name);
    endfunction

    task put_cqe(cqe input_cqe);
        cqe_list.push_back(input_cqe);
    endtask: put_cqe

    // cqe get_cqe()

endclass: hca_comp_queue
`endif