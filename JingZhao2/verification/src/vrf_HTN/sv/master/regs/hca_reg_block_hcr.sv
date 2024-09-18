//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-13
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_reg_block_hcr.sv
//  FUNCTION : This file supplies the function of simulating the HCR register.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-13    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_REG_BLOCK_HCR__
`define __HCA_REG_BLOCK_HCR__
typedef class reg_hcr;

//------------------------------------------------------------------------------
//
// CLASS: hca_reg_block_hcr
//
//------------------------------------------------------------------------------
class hca_reg_block_hcr extends uvm_reg_block;
    `uvm_object_utils(hca_reg_block_hcr)
    
    reg_hcr reg_hcr_inst;

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hcr_reg_block_hcr");
        super.new(name, UVM_NO_COVERAGE);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build
    // function      : create fields, configure fields
    // invoked       : invoked by user
    //------------------------------------------------------------------------------
    virtual function void build();
        // create default map
        // | name | base address | system bus byte width | big/little endian | byte address enable|
        default_map = create_map("default_map", 64'h0000_0000_0008_0000, 32, UVM_BIG_ENDIAN, 1);
        // create registers
        reg_hcr_inst = reg_hcr::type_id::create("reg_hcr");
        // configure registers
        reg_hcr_inst.configure(this, null, "");
        // build registers
        reg_hcr_inst.build();
        // add registers to default_map
        default_map.add_reg(reg_hcr_inst, 0, "RW");
    endfunction: build
endclass: hca_reg_block_hcr

//------------------------------------------------------------------------------
//
// CLASS: hca_reg_block_hcr
//
//------------------------------------------------------------------------------
class reg_hcr extends uvm_reg;
    `uvm_object_utils(reg_hcr)
    rand uvm_reg_field in_param;
    rand uvm_reg_field in_modifier;
    rand uvm_reg_field out_param;
    rand uvm_reg_field token;
    rand uvm_reg_field status;
    rand uvm_reg_field go;
    rand uvm_reg_field e;
    rand uvm_reg_field op_modifier_a;
    rand uvm_reg_field op_modifier_b;
    rand uvm_reg_field op_a;
    rand uvm_reg_field op_b;

    rand uvm_reg_field op_modifier;
    rand uvm_reg_field op;

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "reg_hcr");
        // | reg name | reg width | coverage |
        super.new(name, 224, UVM_NO_COVERAGE);
    endfunction: new
    
    //------------------------------------------------------------------------------
    // function name : build
    // function      : create fields, configure fields
    // invoked       : invoked by user
    //------------------------------------------------------------------------------
    virtual function void build();
        // create fields
        in_param = uvm_reg_field::type_id::create("in_param");
        in_modifier = uvm_reg_field::type_id::create("in_modifier");
        out_param = uvm_reg_field::type_id::create("out_param");
        token = uvm_reg_field::type_id::create("token");
        status = uvm_reg_field::type_id::create("status");
        go = uvm_reg_field::type_id::create("go");
        e = uvm_reg_field::type_id::create("e");
        op_modifier_a = uvm_reg_field::type_id::create("op_modifier_a");
        op_modifier_b = uvm_reg_field::type_id::create("op_modifier_b");
        op_a = uvm_reg_field::type_id::create("op_a");
        op_b = uvm_reg_field::type_id::create("op_b");

        op_modifier = uvm_reg_field::type_id::create("op_modifier");
        op = uvm_reg_field::type_id::create("op");



        // configure fields
        in_param.configure(this, 64, 0, "RW", 0, 0, 1, 0, 0);
        in_modifier.configure(this, 32, 64, "RW", 0, 0, 1, 0, 0);
        out_param.configure(this, 64, 96, "RW", 0, 0, 1, 0, 0);
        token.configure(this, 16, 168, "RW", 0, 0, 1, 0, 0);
        status.configure(this, 8, 192, "RW", 0, 0, 1, 0, 0);
        go.configure(this, 1, 207, "RW", 0, 0, 1, 0, 0);
        e.configure(this, 1, 206, "RW", 0, 0, 1, 0, 0);
        op_modifier_a.configure(this, 4, 200, "RW", 0, 0, 1, 0, 0);
        op_modifier_b.configure(this, 4, 212, "RW", 0, 0, 1, 0, 0);
        op_a.configure(this, 4, 208, "RW", 0, 0, 1, 0, 0);
        op_b.configure(this, 8, 216, "RW", 0, 0, 1, 0, 0);

        // in_param.configure(this, 64, 0, "RW", 0, 0, 1, 0, 0);
        // in_modifier.configure(this, 32, 64, "RW", 0, 0, 1, 0, 0);
        // out_param.configure(this, 64, 96, "RW", 0, 0, 1, 0, 0);
        // token.configure(this, 16, 160, "RW", 0, 0, 1, 0, 0);
        // status.configure(this, 8, 192, "RW", 0, 0, 1, 0, 0);
        // go.configure(this, 1, 207, "RW", 0, 0, 1, 0, 0);
        // e.configure(this, 1, 206, "RW", 0, 0, 1, 0, 0);
        // op_modifier.configure(this, 8, 200, "RW", 0, 0, 1, 0, 0);
        // op.configure(this, 12, 208, "RW", 0, 0, 1, 0, 0);

        // in_param.configure(this, 64, 56, "RW", 0, 0, 1, 0, 0);
        // in_modifier.configure(this, 32, 88, "RW", 0, 0, 1, 0, 0);
        // out_param.configure(this, 64, 152, "RW", 0, 0, 1, 0, 0);
        // token.configure(this, 16, 168, "RW", 0, 0, 1, 0, 0);

        // status.configure(this, 8, 192, "RW", 0, 0, 1, 0, 0);
        // go.configure(this, 1, 207, "RW", 0, 0, 1, 0, 0);
        // e.configure(this, 1, 206, "RW", 0, 0, 1, 0, 0);
        // op_modifier.configure(this, 8, 212, "RW", 0, 0, 1, 0, 0);
        // op.configure(this, 12, 216, "RW", 0, 0, 1, 0, 0);
    endfunction: build
endclass: reg_hcr
`endif
