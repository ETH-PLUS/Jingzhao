//CREATE INFORMATION
//--------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-19
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_master_agent.sv
//  FUNCTION : This file supplies the agent that accesses HCR and doorbell 
//             registers of HCA.
//
//--------------------------------------------------------------------------------------

//CHANGE HISTORY
//--------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-19    v1.0             create
//  mazhenlong      2021-04-01    v1.1             change filename and reg_* to mst_*
//
//--------------------------------------------------------------------------------------

`ifndef __HCA_MASTER_AGENT__
`define __HCA_MASTER_AGENT__

//------------------------------------------------------------------------------
//
// CLASS: hca_master_agent
//
//------------------------------------------------------------------------------
class hca_master_agent extends uvm_agent;
    hca_master_sequencer mst_sqr;
    hca_master_driver mst_drv;
    hca_memory mem;
    mailbox cmd_done;


    `uvm_component_utils_begin(hca_master_agent)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates sequencer and driver.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mst_sqr = hca_master_sequencer::type_id::create("mst_sqr", this);
        mst_drv = hca_master_driver::type_id::create("mst_drv", this);
        cmd_done = new();
        uvm_config_db#(mailbox)::set(this, "*", "mbx_cmd_done", cmd_done);
        // `uvm_info("PARAM_INFO", $sformatf("uvm_config_db set finished! full name: %s.", get_full_name()), UVM_LOW);
        // uvm_config_db#(mailbox)::set(this, "", "mbx_cmd_done", cmd_done);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // function name : connect_phase
    // function      : connect_phase in uvm library, connect sequencer and driver.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        mst_drv.seq_item_port.connect(mst_sqr.seq_item_export);
    endfunction: connect_phase
endclass: hca_master_agent
`endif