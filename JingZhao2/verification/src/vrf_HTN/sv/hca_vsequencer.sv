//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-17
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_vsequencer.sv
//  FUNCTION : This file supplies the virtual sequencer of verification of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-25    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_VSEQUENCER__
`define __HCA_VSEQUENCER__

//------------------------------------------------------------------------------
//
// CLASS: hca_vsequencer
//
//------------------------------------------------------------------------------
class hca_vsequencer extends uvm_sequencer;
    hca_slave_sequencer slv_sqr[];
    hca_master_sequencer mst_sqr[];
    int host_num = 1;

    `uvm_component_utils_begin(hca_vsequencer)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_vsequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiate config sequencer and 
    //                 slave sequencer.
    // invoked       : invoked by uvm automatically
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        string array_element;
        super.build_phase(phase);

        slv_sqr = new[host_num];
        // instantiate slv_sqr
        for (int i = 0; i < host_num; i++) begin
            array_element = $sformatf("slv_sqr[%0d]", i);
            slv_sqr[i] = hca_slave_sequencer::type_id::create(array_element, this);
        end

        mst_sqr = new[host_num];
        // instantiate mst_sqr
        for (int i = 0; i < host_num; i++) begin
            array_element = $sformatf("mst_sqr[%0d]", i);
            mst_sqr[i] = hca_master_sequencer::type_id::create(array_element, this);
        end
    endfunction: build_phase
endclass

`endif