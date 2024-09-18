//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-06-25
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_comm_sequence.sv
//  FUNCTION : This file supplies the sequence of communication verification.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-06-25    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_COMM_SEQUENCE__
`define __HCA_COMM_SEQUENCE__

//------------------------------------------------------------------------------
//
// CLASS: hca_comm_sequence
//
//------------------------------------------------------------------------------
class hca_comm_sequence extends uvm_sequence #(hca_pcie_item);
    hca_pcie_item comm_item_que[$];
    hca_pcie_item comm_item;
    
    string seq_name;
    
    `uvm_object_utils(hca_comm_sequence)
    
    //------------------------------------------------------------------------------
    // function name : new 
    // function      : constructor 
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_comm_sequence");
        super.new(name);
        comm_item = hca_pcie_item::type_id::create("comm_item");
    endfunction: new
    
    //------------------------------------------------------------------------------
    // task name     : pre_body 
    // function      : cast the register model passed in to reg_blk_hcr 
    // invoked       : be invoked by uvm
    //------------------------------------------------------------------------------
    virtual task pre_body();
        // $cast(reg_blk_hcr, model);
    endtask: pre_body

    //------------------------------------------------------------------------------
    // task name     : body
    // function      : generate pcie items 
    // invoked       : invoked by uvm automatically
    //------------------------------------------------------------------------------
    task body();
        bit [`DATA_WIDTH-1 : 0] temp_data;
        bit                     cmd_result;
        // get case name
        // if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
        //     `uvm_warning("hca_comm_sequence", "HCA_CASE_NAME not get!")
        // end
        while (comm_item_que.size != 0) begin
            comm_item = comm_item_que.pop_front();
            start_item(comm_item);
            // set descriptor
            comm_item.cq_addr = `DB_BAR_ADDR + {comm_item.db.proc_id, 12'b0};
            comm_item.cq_addr_type = 0; //not sure
            comm_item.cq_attr = 0; //not sure
            comm_item.cq_tc = 0; //not sure
            comm_item.cq_target_function = 0; //not sure
            comm_item.cq_tag = 0; //not sure
            comm_item.cq_bus = 0; //not sure
            comm_item.cq_req_type = MEM_WR;
            comm_item.cq_dword_count = 2; // WARNING: should be modified!
            comm_item.cq_bar_id = `DB_BAR_ID;
            comm_item.cq_bar_aperture = 22;
            comm_item.item_type = DOORBELL;
            temp_data = {
                {192'b0},
                {comm_item.db.qp_num, comm_item.db.size0},
                {comm_item.db.nreq, comm_item.db.sq_head, 2'b0, comm_item.db.f0, comm_item.db.opcode}};
            comm_item.data_payload.push_back(temp_data);
            `uvm_info("NOTICE", $sformatf("input doorbell: %h", temp_data), UVM_LOW);
            finish_item(comm_item);
        end
    endtask: body
endclass: hca_comm_sequence
`endif