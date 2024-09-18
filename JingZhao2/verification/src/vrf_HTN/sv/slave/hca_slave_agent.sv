//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-15
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_slave_agent.sv
//  FUNCTION : This file supplies the function of slave side of HCA verification.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-15    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_SLAVE_AGENT__
`define __HCA_SLAVE_AGENT__

//------------------------------------------------------------------------------
//
// CLASS: hca_slave_agent
//
//------------------------------------------------------------------------------
class hca_slave_agent extends uvm_agent;
    hca_slave_monitor slv_mon;
    hca_slave_driver slv_drv;
    hca_slave_sequencer slv_sqr;
    hca_memory mem;
    `uvm_component_utils_begin(hca_slave_agent)
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
    // function      : build slave driver, slave monitor and slave sequencer
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        slv_drv = hca_slave_driver::type_id::create("slv_drv", this);
        slv_mon = hca_slave_monitor::type_id::create("slv_mon", this);
        slv_sqr = hca_slave_sequencer::type_id::create("slv_sqr", this);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // function name : connect_phase
    // function      : connect slave driver and slave sequencer, slave monitor and
    //                 slave sequencer
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        slv_drv.seq_item_port.connect(slv_sqr.seq_item_export);
        slv_mon.seq_port.connect(slv_sqr.item_collected_fifo.analysis_export);
    endfunction: connect_phase

    //------------------------------------------------------------------------------
    // task name     : reset_phase
    // function      : reset_phase in uvm lib
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        $cast(slv_drv.mem, this.mem);
        $cast(slv_mon.mem, this.mem);
    endtask: reset_phase

endclass: hca_slave_agent
`endif