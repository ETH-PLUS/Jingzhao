//CREATE INFORMATION
//--------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-13
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_env.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//--------------------------------------------------------------------------------------

//CHANGE HISTORY
//--------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-11    v1.0             create
//  mazhenlong      2021-04-01    v1.1             change reg_agt and reg_sqr to mst
//  mazhenlong      2021-04-17    v1.2             delete cfg_seq
//
//--------------------------------------------------------------------------------------

`ifndef __HCA_ENV__
`define __HCA_ENV__

//----------------------------------------------------------------------------------------
//
// CLASS: hca_env
//
//----------------------------------------------------------------------------------------
class hca_env extends uvm_env;
    string test_name;
    int host_num = 1;
    hca_vsequencer vsqr;

    hca_scoreboard scb;

    // memory model
    hca_memory mem[];

    // host model
    hca_sub_env sub_env[];
    hca_master_agent mst_agt;

    hca_ref_model rm;

    `uvm_component_utils_begin(hca_env)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates memory, reg block,
    //                 adapter and sub_env.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        string inst_name;
        
        vsqr = hca_vsequencer::type_id::create("vsqr", this);
        vsqr.host_num = this.host_num;

        sub_env = new[host_num];

        `uvm_info("HOST_NUM_INFO", $sformatf("host_num in hca_env: %0d.", host_num), UVM_LOW);

        // instantiate memory for every sub env
        mem = new[host_num];
        foreach (mem[i]) begin
            mem[i] = hca_memory::type_id::create($sformatf("mem%0d", i));
        end
        
        // instantiate sub env
        for (int i = 0; i < host_num; i++) begin
            inst_name = $sformatf("sub_env[%0d]", i);
            sub_env[i] = hca_sub_env::type_id::create(inst_name, this);
        end

        // instantiate scoreboard
        scb = hca_scoreboard::type_id::create("scb", this);

        // instantiate reference model
        rm = hca_ref_model::type_id::create("rm", this);
        rm.host_num = this.host_num;

        super.build_phase(phase);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // function name : connect_phase
    // function      : connect_phase in uvm library, point sqr in sub_env to vsqr.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        string inst_name;
        // connect vsqr to sub_env sqr
        foreach (sub_env[i]) begin
            vsqr.mst_sqr[i] = sub_env[i].mst_agt.mst_sqr;
            vsqr.slv_sqr[i] = sub_env[i].slv_agt.slv_sqr;
        end

        // connect slave and scoreboard
        foreach (sub_env[i]) begin
            sub_env[i].slv_agt.slv_mon.port2scb.connect(scb.duv_fifo[i].analysis_export);
        end

        // connect master and reference model
        foreach (sub_env[i]) begin
            sub_env[i].mst_agt.mst_drv.port2rm_cfg.connect(rm.cfg_fifo[i].analysis_export);
            sub_env[i].mst_agt.mst_drv.port2rm_comm.connect(rm.comm_fifo[i].analysis_export);
        end

        // connect slave and rm
        foreach (sub_env[i]) begin
            sub_env[i].slv_agt.slv_drv.port2rm.connect(rm.cfg_resp_fifo[i].analysis_export);
        end

        // connect ref model and scb
        foreach (rm.port2scb[i]) begin
            rm.port2scb[i].connect(scb.rm_fifo[i].analysis_export);
        end
        foreach (mem[i]) begin
            $cast(sub_env[i].mem, this.mem[i]);
            $cast(rm.mem[i], this.mem[i]);
            $cast(scb.mem[i], this.mem[i]);
        end
    endfunction: connect_phase

    //------------------------------------------------------------------------------
    // task name     : configure_phase
    // function      : configure_phase in uvm library.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    task configure_phase(uvm_phase phase);
        if ($value$plusargs("UVM_TESTNAME=%s", test_name)) begin
            if (test_name == "test_reg") begin
                
            end
        end
    endtask: configure_phase

    //------------------------------------------------------------------------------
    // task name     : connect_phase
    // function      : main_phase in uvm library.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    task main_phase(uvm_phase phase);

    endtask: main_phase
endclass
`endif