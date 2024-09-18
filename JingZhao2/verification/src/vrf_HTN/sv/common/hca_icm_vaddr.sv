//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-09-08
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_icm_vaddr.sv
//  FUNCTION : .
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-09-14    v1.0             create
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_ICM_VADDR__
`define __HCA_ICM_VADDR__

//----------------------------------------------------------------------------
//
// CLASS: hca_icm_vaddr
//
//----------------------------------------------------------------------------
class hca_icm_vaddr extends uvm_object;

    addr qpc_virt_addr[][$];
    addr cqc_virt_addr[][$];
    addr eqc_virt_addr[][$];
    addr mpt_virt_addr[][$];
    addr mtt_virt_addr[][$];

    int qpc_page_limit[];
    int cqc_page_limit[];
    int mpt_page_limit[];
    int mtt_page_limit[];

    int qpc_page_mapped[];
    int cqc_page_mapped[];
    int mpt_page_mapped[];
    int mtt_page_mapped[];

    int qpc_cap_left[];
    int cqc_cap_left[];
    int mtt_cap_left[];
    int mpt_cap_left[];

    `uvm_object_utils_begin(hca_icm_vaddr)
    `uvm_object_utils_end

    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_icm_vaddr");
        super.new(name);
    endfunction

    function init(int host_num);
        qpc_virt_addr = new[host_num];
        cqc_virt_addr = new[host_num];
        eqc_virt_addr = new[host_num];
        mpt_virt_addr = new[host_num];
        mtt_virt_addr = new[host_num];

        
        qpc_page_mapped = new[host_num];
        cqc_page_mapped = new[host_num];
        mpt_page_mapped = new[host_num];
        mtt_page_mapped = new[host_num];

        qpc_page_limit = new[host_num];
        cqc_page_limit = new[host_num];
        mpt_page_limit = new[host_num];
        mtt_page_limit = new[host_num];

        qpc_cap_left = new[host_num];
        cqc_cap_left = new[host_num];
        mtt_cap_left = new[host_num];
        mpt_cap_left = new[host_num];

        for (int i = 0; i < host_num; i++) begin
            qpc_page_mapped[i] = 0;
            cqc_page_mapped[i] = 0;
            mpt_page_mapped[i] = 0;
            mtt_page_mapped[i] = 0;
            qpc_page_limit[i] = `QPC_ICM_PAGE_LIMIT;
            cqc_page_limit[i] = `CQC_ICM_PAGE_LIMIT;
            mpt_page_limit[i] = `MPT_ICM_PAGE_LIMIT;
            mtt_page_limit[i] = `MTT_ICM_PAGE_LIMIT;
            qpc_cap_left[i] = 0;
            cqc_cap_left[i] = 0;
            mtt_cap_left[i] = 0;
            mpt_cap_left[i] = 0;
        end
    endfunction: init

    function add_icm_vaddr(int m_type, int page_num);
        case (m_type)
            `ICM_QPC_TYP: begin
                
            end
            `ICM_CQC_TYP: begin
                
            end
            `ICM_EQC_TYP: begin
                
            end
            `ICM_MPT_TYP: begin
                
            end
            `ICM_MTT_TYP: begin
                
            end
            default: begin
                
            end
        endcase
    endfunction: add_icm_vaddr

endclass: hca_icm_vaddr
`endif