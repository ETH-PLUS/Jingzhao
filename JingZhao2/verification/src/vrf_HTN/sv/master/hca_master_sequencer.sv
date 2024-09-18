//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-19
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_maseter_sequencer.sv
//  FUNCTION : This file supplies the sequencer of registers, passing items
//             to driver.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-19    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_MASTER_SEQUENCER__
`define __HCA_MASTER_SEQUENCER__

//------------------------------------------------------------------------------
//
// CLASS: hca_master_sequencer
//
//------------------------------------------------------------------------------
class hca_master_sequencer extends uvm_sequencer #(hca_pcie_item);
    `uvm_component_utils_begin(hca_master_sequencer)
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
    endfunction: build_phase
endclass: hca_master_sequencer
`endif