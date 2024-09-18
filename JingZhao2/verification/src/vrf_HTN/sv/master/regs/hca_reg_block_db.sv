//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-12
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_reg_block_db.sv
//  FUNCTION : This file supplies the function of simulating the registers
//             about Doorbell.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-12    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_REG_BLOCK_DB__ 
`define __HCA_REG_BLOCK_DB__
typedef class reg_db;

//------------------------------------------------------------------------------
//
// CLASS: hca_reg_block_db
//
//------------------------------------------------------------------------------
class hca_reg_block_db extends uvm_reg_block;
    `uvm_object_utils(hca_reg_block_db)
    int user_num;
    reg_db reg_db_inst;

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "reg_block_db");
        super.new(name, UVM_NO_COVERAGE);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build
    // function      : create regs, configure regs, build regs and map regs
    // invoked       : invoked by user
    //------------------------------------------------------------------------------
    virtual function void build();
        int i;
        // create default map
        default_map = create_map("default_map", 0, 256, UVM_BIG_ENDIAN, 1);
        // !!!probable to recycle memory space!!!
        for (i = 0; i < `MAX_PROC_NUM; i++) begin
            // create registers
            reg_db_inst = reg_db::type_id::create($sformatf("doorbell%0d", i));
            // configure registers
            reg_db_inst.configure(this, null, "");
            // build registers
            reg_db_inst.build();
            // add registers to default map
            default_map.add_reg(reg_db_inst, 'h18 + `PAGE_SIZE * i, "RW");
        end
    endfunction: build
endclass: hca_reg_block_db

//------------------------------------------------------------------------------
//
// CLASS: reg_db
//
//------------------------------------------------------------------------------
class reg_db extends uvm_reg;
    `uvm_object_utils(reg_db)
    rand uvm_reg_field nreq;
    rand uvm_reg_field sq_head;
    rand uvm_reg_field f0;
    rand uvm_reg_field opcode;
    rand uvm_reg_field qp_num;
    rand uvm_reg_field size0;

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "reg_db");
        super.new(name, 64, UVM_NO_COVERAGE);
    endfunction: new
    
    //------------------------------------------------------------------------------
    // function name : build
    // function      : create fields, configure fields
    // invoked       : invoked by user
    //------------------------------------------------------------------------------
    virtual function void build();
        nreq = uvm_reg_field::type_id::create("nreq");
        sq_head = uvm_reg_field::type_id::create("sq_head");
        f0 = uvm_reg_field::type_id::create("f0");
        opcode = uvm_reg_field::type_id::create("opcode");
        qp_num = uvm_reg_field::type_id::create("qp_num");
        size0 = uvm_reg_field::type_id::create("size0");
        // parameters: parent, size, lsb pos, access, volatile, reset value, has reset, is rand, individually accessible
        // nreq.configure(this, 8, 0, "RW", 0, 0, 1, 0, 0);
        // sq_head.configure(this, 16, 8, "RW", 0, 0, 1, 0, 0);
        // f0.configure(this, 1, 29, "RW", 0, 0, 1, 0, 0);
        // opcode.configure(this, 5, 24, "RW", 0, 0, 1, 0, 0);
        // qp_num.configure(this, 24, 55, "RW", 0, 0, 1, 0, 0);
        // size0.configure(this, 8, 56, "RW", 0, 0, 1, 0, 0);
    endfunction: build
endclass: reg_db
`endif
