//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-14
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_hcr_seq.sv
//  FUNCTION : This file supplies the task of verifying the HCR register.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-14    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __TEST_HCR_SEQ__
`define __TEST_HCR_SEQ__

//------------------------------------------------------------------------------
//
// CLASS: test_hcr_seq
//
//------------------------------------------------------------------------------
class test_hcr_seq extends uvm_reg_sequence;
    string                          test_name;
    hca_reg_block_hcr               reg_block_hcr;

    `uvm_object_utils(test_hcr_seq)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_hcr_seq");
        super.new(name);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : pre_body 
    // function      : cast the register model passed in to reg_block_hcr 
    // invoked       : be invoked by uvm
    //------------------------------------------------------------------------------
    virtual task pre_body();
        $cast(reg_block_hcr, model);
    endtask : pre_body

    //------------------------------------------------------------------------------
    // function name : body
    // function      : write the reg randomly, read and compare
    // invoked       : invoked by uvm
    //------------------------------------------------------------------------------
    virtual task body();
        uvm_reg_data_t data, rd_data;
        uvm_status_e status;
        // data[`HCR_SIZE-1: 0] = {$urandom(), $urandom(), $urandom(), $urandom(),
        //                         $urandom(), $urandom(), $urandom()};
        bit [7:0]   temp_data;
        int i;
        for (i = 0; i < `HCR_BYTE_SIZE; i++) begin
            data[i * 8 + 7 -: 8] = i;
        end
        //data[`HCR_BIT_SIZE-1: 0] = {8'h12, 8'h34, 8'h56, 8'h78, 8'h12, 8'h34, 8'h56}; 
        reg_block_hcr.reg_hcr_inst.write(status, data, .parent(this));
        reg_block_hcr.reg_hcr_inst.mirror(status, UVM_CHECK, .parent(this));
        rd_data = reg_block_hcr.reg_hcr_inst.get();
        if (data[`HCR_BIT_SIZE-1: 0] != rd_data[`HCR_BIT_SIZE-1: 0]) begin
            `uvm_error(get_type_name(), "HCR REGISTER MISMATCH!")
        end
        reg_block_hcr.reg_hcr_inst.write(status, ~data, .parent(this));
        reg_block_hcr.reg_hcr_inst.mirror(status, UVM_CHECK, .parent(this));
        rd_data = reg_block_hcr.reg_hcr_inst.get();
        if (~data[`HCR_BIT_SIZE-1: 0] != rd_data[`HCR_BIT_SIZE-1: 0]) begin
            `uvm_error(get_type_name(), "HCR REGISTER MISMATCH!")
        end
        `uvm_info("NOTICE", {get_full_name(), " body end!"}, UVM_LOW)
    endtask: body
endclass: test_hcr_seq
`endif