//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-27
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_sub_env.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//----------------------------------------------------------------------------


//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-27    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_SUB_ENV__
`define __HCA_SUB_ENV__

//------------------------------------------------------------------------------
//
// CLASS: hca_sub_env
//
//------------------------------------------------------------------------------
class hca_sub_env extends uvm_env;
    hca_master_agent mst_agt;
    hca_slave_agent slv_agt;
    hca_memory mem;

    `uvm_component_utils_begin(hca_sub_env)
        `uvm_field_object(mst_agt, UVM_DEFAULT)
        `uvm_field_object(slv_agt, UVM_DEFAULT)
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
    // function      : build_phase in uvm library, instantiates agents
    // invoked       : invoked by uvm automatically
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mst_agt = hca_master_agent::type_id::create("mst_agt", this);
        slv_agt = hca_slave_agent::type_id::create("slv_agt", this);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // task name     : pre_reset_phase
    // function      : point mem in agent to this.mem
    // invoked       : invoked by uvm automatically
    //------------------------------------------------------------------------------
    task pre_reset_phase(uvm_phase phase);
        super.pre_reset_phase(phase);
        // $cast(mst_agt.if, this.v_if);
        $cast(mst_agt.mem, this.mem);
        $cast(slv_agt.mem, this.mem);
    endtask: pre_reset_phase
endclass: hca_sub_env
`endif