//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-13
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_reg.sv
//  FUNCTION : This file supplies the case for testing registers in BAR space
//             of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-13    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __TEST_REG__
`define __TEST_REG__

//------------------------------------------------------------------------------
//
// CLASS: test_reg
//
//------------------------------------------------------------------------------
class test_reg extends uvm_test;
    string seq_name;
    hca_env env;
    uvm_reg_sequence reg_seq;
    `uvm_component_utils(test_reg)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_reg", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates env and reg_seq.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        string inst_name;
        // string seq_name;
        env = hca_env::type_id::create("env", this);
        `uvm_info("NOTICE", "env is created!", UVM_LOW)
        reg_seq = new;
        if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
            `uvm_warning("test_reg", "SEQ_NAME NOT GET!")
        end
        reg_seq = uvm_utils #(uvm_reg_sequence)::create_type_by_name(seq_name, "env");
        if (reg_seq == null)
            uvm_report_fatal("NO_SEQUENCE", "This env requires you to specify the sequence to run using UVM_SEQUENCE=<name>");
        super.build_phase(phase);
        `uvm_info("NOTICE", "test_reg.build_phase finished!", UVM_LOW)
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // function name : connect_phase
    // function      : connect_phase in uvm library, name the reg model in sequence 
    //                 to reg model in env.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // string seq_name;
        super.connect_phase(phase);
        case (seq_name)
            "test_hcr_seq": reg_seq.model = env.reg_blk_hcr[0];
            "test_db_seq": reg_seq.model = env.reg_blk_db[0];
            default: begin
                `uvm_info("NAME_UNKNOWN", "UNKNOWN SEQUENCE NAME...", UVM_LOW)
            end
        endcase
    endfunction: connect_phase

    //------------------------------------------------------------------------------
    // function name : end_of_elaboration_phase
    // function      : end_of_elaboration_phase in uvm library.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
    endfunction : end_of_elaboration_phase

    //------------------------------------------------------------------------------
    // function name : main_phase
    // function      : main_phase in uvm library, start reg_seq.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    task main_phase(uvm_phase phase);
        phase.raise_objection(this);
        #1000;
        uvm_report_info("START_SEQ", {"Starting sequence '", reg_seq.get_name(), "'"});
        reg_seq.start(null);
        `uvm_info("NOTICE", {get_full_name(), " reg_seq end!"}, UVM_LOW)
        phase.drop_objection(this);
        //set a drain-time for the environment if desired
        phase.phase_done.set_drain_time(this, 10);
    endtask: main_phase

    //------------------------------------------------------------------------------
    // function name : report_phase
    // function      : report_phase in uvm library, generate verification report.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        string ts_name;
        uvm_report_server svr;
        svr = _global_reporter.get_report_server();
        svr.summarize();
        if ($value$plusargs("HCA_CASE_NAME=%s", ts_name)) begin
            if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0) begin
                $write("*** HCA_TEST_NAME=%s: UVM TEST PASSED ***\n", ts_name); 
            end
            else begin 
                $write("!!! HCA_TEST_NAME=%s: UVM TEST FAILED !!!\n", ts_name);
            end
        end
    endfunction: report_phase
endclass: test_reg
`endif