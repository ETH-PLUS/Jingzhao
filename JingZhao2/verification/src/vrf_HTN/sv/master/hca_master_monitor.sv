//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-15
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_master_monitor.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-15    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_MASTER_MONITOR__
`define __HCA_MASTER_MONITOR__

//----------------------------------------------------------------------------
//
// CLASS: hca_master_monitor
//
//----------------------------------------------------------------------------
class hca_master_monitor extends uvm_monitor;
    virtual hca_interface v_if;

    `uvm_component_utils_begin(hca_master_monitor)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new
endclass: hca_master_monitor
`endif