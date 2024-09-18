//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-07
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_slave_sequencer.sv
//  FUNCTION : This file supplies the function of slave side of HCA verification.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-07    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_SLAVE_SEQUENCER__
`define __HCA_SLAVE_SEQUENCER__

//------------------------------------------------------------------------------
//
// CLASS: hca_slave_driver
//
//------------------------------------------------------------------------------
class hca_slave_sequencer extends uvm_sequencer #(hca_pcie_item);
    hca_memory mem;
    uvm_tlm_analysis_fifo #(hca_pcie_item, hca_slave_sequencer) item_collected_fifo;
    `uvm_component_utils_begin(hca_slave_sequencer)
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
    // function      : build_phase in uvm lib
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_collected_fifo = new ("item_collected_fifo", this);
    endfunction: build_phase

endclass: hca_slave_sequencer
`endif 