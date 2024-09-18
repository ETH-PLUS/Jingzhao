//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-06
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_addr_table.sv
//  FUNCTION : This file supplies the address table of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-06    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_ADDR_TABLE__
`define __HCA_ADDR_TABLE__

class hca_addr_table extends uvm_object;
    
    rand bit [63:0] qpc_base;
    rand bit [7:0] log_num_qps;
    rand bit [63:0] cqc_base;
    rand bit [7:0] log_num_cqs;
    rand bit [63:0] eqc_base;
    rand bit [7:0] log_num_eqs;
    rand bit [63:0] mpt_base;
    rand bit [7:0] log_mpt_sz;
    rand bit [63:0] mtt_base;

    rand bit [63:0] inbox_addr;
    rand bit [63:0] outbox_addr;

    bit [11:0]    config_status; // current command

    // hca_mpt                        mpt[$];
    bit      [`ADDR_WIDTH - 1 : 0] mtt[$];

    bit      [`ADDR_WIDTH - 1 : 0] icm_virt_addr[$];
    bit      [`ADDR_WIDTH - 1 : 0] icm_phys_addr[$];

    bit      [`ADDR_WIDTH - 1 : 0] mem_virt_addr[$];
    bit      [`ADDR_WIDTH - 1 : 0] mem_phys_addr[$];

    qp_context qp_list[$];

    constraint icm_base_addr {
        qpc_base        == `QPC_OFFSET;
        cqc_base        == `CQC_OFFSET;
        mpt_base        == `MPT_OFFSET;
        mtt_base        == `MTT_OFFSET;
        log_num_qps     == `LOG_NUM_QPS;
        log_num_cqs     == `LOG_NUM_CQS;
        log_mpt_sz      == `LOG_MPT_SZ;

        inbox_addr      == `INBOX_ADDR;
        outbox_addr     == `OUTBOX_ADDR;
    }

    `uvm_object_param_utils_begin(hca_addr_table)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_addr_table");
        super.new(name);
    endfunction: new

    //------------------------------------------------------------------------------
    // task name     : gen_base_addr
    // function      : generate base address of qp context and cq context
    // invoked       : by user
    //------------------------------------------------------------------------------
    task gen_base_addr();
        qpc_base = 64'h0000_0001_0000_0000;
        cqc_base = 64'h0;
    endtask: gen_base_addr;

    //------------------------------------------------------------------------------
    // task name     : map_icm
    // function      : map icm space address to physical address. 
    //                 type: 1 - qp
    //                       2 - cq
    //                       3 - mpt
    //                       4 - mtt
    // invoked       : by user
    //------------------------------------------------------------------------------
    //---------------------------NOTICE: TASK TO BE FIXED!------------------------//
    task map_icm(int typ, int page_num, ref bit [`ADDR_WIDTH - 1 : 0] temp_virt_addr, ref bit [`ADDR_WIDTH - 1 : 0] temp_phys_addr);
        // bit [`ADDR_WIDTH - 1 : 0] temp_virt_addr;
        // bit [`ADDR_WIDTH - 1 : 0] temp_phys_addr;
        if (typ == 1) begin
            temp_virt_addr = `QPC_OFFSET;
            temp_phys_addr = `ICM_BASE + `QPC_OFFSET;
        end
        else if (typ == 2) begin
            temp_virt_addr = `CQC_OFFSET;
            temp_phys_addr = `ICM_BASE + `CQC_OFFSET;
        end
        else if (typ == 3) begin
            temp_virt_addr = `MPT_OFFSET;
            temp_phys_addr = `ICM_BASE + `MPT_OFFSET;
        end
        else if (typ == 4) begin
            temp_virt_addr = `MTT_OFFSET;
            temp_phys_addr = `ICM_BASE + `MTT_OFFSET;
        end
        for (int i = 0; i < page_num; i++) begin
            foreach (icm_virt_addr[j]) begin
                if (icm_virt_addr[j] == temp_virt_addr && icm_phys_addr[j] == temp_phys_addr) begin
                    temp_virt_addr += 4096;
                    temp_phys_addr += 4096;
                end
                else if (icm_virt_addr[j] > temp_virt_addr && icm_phys_addr[j] > temp_phys_addr) begin
                    temp_virt_addr = icm_virt_addr[j] + 4096;
                    temp_phys_addr = icm_phys_addr[j] + 4096;
                end
            end
            icm_virt_addr.push_back(temp_virt_addr);
            icm_phys_addr.push_back(temp_phys_addr);
        end
    endtask: map_icm

    //------------------------------------------------------------------------------
    // task name     : write_mtt
    // function      : allocate physical address in data page, only one page!
    // invoked       : by user
    //------------------------------------------------------------------------------
    task write_mtt(int page_num, ref bit [`ADDR_WIDTH - 1 : 0] temp_virt_addr, ref bit [`ADDR_WIDTH - 1 : 0] temp_phys_addr);
        int j = 0;
        temp_virt_addr = 0;
        temp_phys_addr = `DATA_BASE;
        foreach(mem_phys_addr[i]) begin
            if (mem_virt_addr[i] == temp_virt_addr && mem_phys_addr[i] == temp_phys_addr) begin
                temp_virt_addr = mem_virt_addr[i] + 4096;
                temp_phys_addr = mem_phys_addr[i] + 4096;
            end
            mem_virt_addr.push_back(temp_virt_addr);
            mem_phys_addr.push_back(temp_phys_addr);
            j++;
            if (j == page_num || j > page_num) begin
                break;
            end
        end
    endtask: write_mtt
endclass: hca_addr_table

`endif