//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-09-08
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_queue_list.sv
//  FUNCTION : .
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-09-08    v1.0             create
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_QUEUE_LIST__
`define __HCA_QUEUE_LIST__

//----------------------------------------------------------------------------
//
// CLASS: hca_queue_list
//
//----------------------------------------------------------------------------
class hca_queue_list extends uvm_object;

    hca_queue_pair qp_list[][$];
    hca_comp_queue cq_list[][$];

    `uvm_object_utils_begin(hca_queue_list)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_queue_list");
        super.new(name);
    endfunction

    function init(int host_num);
        qp_list = new[host_num];
        cq_list = new[host_num];
    endfunction: init

    function hca_queue_pair get_qp(int host_id, bit [31:0] qpn);
        for (int i = 0; i < qp_list[host_id].size(); i++) begin
            if (qpn == qp_list[host_id][i].ctx.local_qpn) begin
                return qp_list[host_id][i];
            end
        end
        `uvm_fatal("GET_QP_ERR", $sformatf("Get QP error! qpn: %h, host_id: %h", qpn, host_id));
    endfunction: get_qp

    function hca_comp_queue get_cq(int host_id, bit [31:0] cqn);
        for (int i = 0; i < cq_list[host_id].size(); i++) begin
            if (cqn == cq_list[host_id][i].ctx.cqn) begin
                return cq_list[host_id][i];
            end
        end
        `uvm_fatal("GET_CQ_ERR", $sformatf("Get CQ error! cqn: %h", cqn));
    endfunction: get_cq
endclass: hca_queue_list
`endif