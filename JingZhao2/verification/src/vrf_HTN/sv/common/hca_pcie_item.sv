//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2020-11-26
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_pcie_item.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-11-26    v1.0             create
//  mazhenlong      2021-01-14    v1.1             rewrite the class, referring
//                                                 to pg023
//  mazhenlong      2021-01-20    v1.2             rewrite members, classified 
//                                                 by CQ, CC, RQ and RC
//  mazhenlong      2021-03-04    v1.3             add gen_cq_desc()
//  mazhenlong      2021-04-09    v1.4             add RQ
//  mazhenlong      2021-04-12    v1.5             add do_compare function
//  mazhenlong      2021-04-29    v1.6             extend constraint c_hcr to query_adapter, 
//                                                 query_dev_lim, close_hca
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_PCIE_ITEM__
`define __HCA_PCIE_ITEM__

typedef enum {  MEM_RD            = 4'b0000,
                MEM_WR            = 4'b0001,
                IO_RD             = 4'b0010,
                IO_WR             = 4'b0011,
                MEM_FETCH_ADD     = 4'b0100,
                MEM_UNCON_SWAP    = 4'b0101,
                MEM_COMP_SWAP     = 4'b0110,
                LOCKED_RD         = 4'b0111,
                TYPE0_CONF_RD     = 4'b1000,
                TYPE1_CONF_RD     = 4'b1001,
                TYPE0_CONF_WR     = 4'b1010,
                TYPE1_CONF_WR     = 4'b1011,
                ANY               = 4'b1100,
                VENDOR_DEF        = 4'b1101,
                ATS               = 4'b1110,
                RESERVED          = 4'b1111} e_req_type;

// typedef enum {CQ, CC, RQ, RC, BASE_REG, RAM_DATA} e_item_type;
typedef enum {INIT, HCR, DOORBELL, DMA_RD, DMA_WR, DMA_RSP, BATCH, INTR, GLOBAL_STOP} e_item_type;

import uvm_pkg::*;
//----------------------------------------------------------------------------
//
// CLASS: hca_pcie_item
//
//----------------------------------------------------------------------------
class hca_pcie_item extends uvm_sequence_item;

    rand e_item_type                                 item_type;
    bool                                        is_cq = FALSE;

    rand int                                    host_num = 0;
    rand bit          [63:0]                    dma_addr;
    rand bit          [16:0]                    dma_length;
    rand bit          [16:0]                    inbox_size;
    rand int                                    map_type; // 1:qp
                                                          // 2:cq 
                                                          // 3:mpt 
                                                          // 4:mtt
    rand bit          [63:0]                    query_qp_num;
    qp_context                                  qp_ctx;
    cq_context                                  cq_ctx;
    rand bit          [63:0]                    num_mtt;

    doorbell                                    db;
    mpt                                         mpt_item;
    mtt_unit                                    mtt_item;
    icm_base                                    icm_base_struct;
    icm_map                                     icm_addr_map;

    // completer request
    // content in desc
    rand bit     [`ADDR_WIDTH-1: 0]             cq_addr;
    rand bit     [1: 0]                         cq_addr_type;
    rand bit     [2: 0]                         cq_attr;
    rand bit     [2: 0]                         cq_tc;
    rand bit     [5: 0]                         cq_bar_aperture;
    rand bit     [2: 0]                         cq_bar_id;
    rand bit     [7: 0]                         cq_target_function;
    rand bit     [7: 0]                         cq_tag;
    rand bit     [7: 0]                         cq_bus;
    rand bit     [7: 0]                         cq_device;
    rand e_req_type                             cq_req_type;
    rand bit     [10: 0]                        cq_dword_count;
    // not in desc
    rand bit     [127:0]                        cq_desc;
    rand bit     [6: 0]                         cq_rd_dw_size;

    // requester request
    rand bit     [`ADDR_WIDTH-1: 0]             rq_addr;
    rand bit     [1: 0]                         rq_addr_type;
    rand bit     [10: 0]                        rq_dword_count;
    rand e_req_type                             rq_req_type;
    rand bit                                    rq_poisoned_req;
    rand bit     [7:  0]                        rq_requester_device;
    rand bit     [7:  0]                        rq_requester_bus;
    rand bit     [7:  0]                        rq_tag;
    rand bit     [7:  0]                        rq_completer_device;
    rand bit     [7:  0]                        rq_completer_bus;
    rand bit                                    rq_requester_id_en;
    rand bit     [2:  0]                        rq_tc;
    rand bit     [2:  0]                        rq_attr;
    rand bit                                    rq_force_ecrc;
    rand bit     [3:  0]                        rq_first_be;
    rand bit     [3:  0]                        rq_last_be;

    // requester completion
    rand bit     [11: 0]                        rc_addr;
    rand bit     [3:  0]                        rc_error_code;
    rand bit     [14: 0]                        rc_byte_count;
    rand bit                                    rc_locked_read_completion;
    rand bit                                    rc_request_completed;
    rand bit     [10: 0]                        rc_dword_count;
    rand bit     [2:  0]                        rc_completion_status;
    rand bit                                    rc_poisoned_completion;
    rand bit     [7:  0]                        rc_requester_device;
    rand bit     [7:  0]                        rc_requester_bus;
    rand bit     [7:  0]                        rc_tag;
    rand bit     [7:  0]                        rc_completer_device;
    rand bit     [7:  0]                        rc_completer_bus;
    rand bit     [2:  0]                        rc_tc;
    rand bit     [2:  0]                        rc_attr;
    rand bit     [3:  0]                        rc_first_be;
    rand bit     [3:  0]                        rc_last_be;

    rand bit     [95: 0]                        rc_desc;
    
    // completer completion
    rand bit     [2: 0]                         cc_attr;
    rand bit     [2: 0]                         cc_tc;
    rand bit     [5: 0]                         cc_bar_aperture;
    rand bit     [2: 0]                         cc_bar_id;
    rand bit     [7: 0]                         cc_target_function;
    rand bit     [7: 0]                         cc_tag;
    rand bit     [7: 0]                         cc_bus;
    rand bit     [7: 0]                         cc_device;
    
    rand bit     [6: 0]                         lower_addr;
    rand bit     [`DATA_WIDTH-1 : 0]            data_payload[$];
    
    rand bit          [63:0]                    hcr_in_param;
    rand bit          [31:0]                    hcr_in_modifier;
    rand bit          [63:0]                    hcr_out_param;
    rand bit          [15:0]                    hcr_token;
    rand bit                                    hcr_go;
    rand bit                                    hcr_e;
    rand bit          [7:0]                     hcr_op_modifier;
    rand bit          [11:0]                    hcr_op;

    bit               [`ADDR_WIDTH-1 : 0]       qpc_base;
    bit               [`ADDR_WIDTH-1 : 0]       cqc_base;
    bit               [`ADDR_WIDTH-1 : 0]       eqc_base;
    bit               [`ADDR_WIDTH-1 : 0]       mpt_base;
    bit               [`ADDR_WIDTH-1 : 0]       mtt_base;

    // bit                                         is_init_hca_resp;

    bool                                        ig_rq_addr;
    bool                                        ig_rq_addr_type;
    bool                                        ig_rq_dword_count;
    bool                                        ig_rq_req_type;
    bool                                        ig_rq_poisoned_req;
    bool                                        ig_rq_requester_id;
    bool                                        ig_rq_tag;
    bool                                        ig_rq_completer_id;
    bool                                        ig_rq_rqr_id_en;
    bool                                        ig_rq_tc;
    bool                                        ig_rq_attr;
    bool                                        ig_rq_force_ecrc;

    bool                                        ig_rq;
    bool                                        ig_base_reg;

    `uvm_object_utils_begin(hca_pcie_item)
        `uvm_field_enum(e_item_type, item_type,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(rq_addr,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_addr_type,        UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_dword_count,      UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_req_type,         UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_poisoned_req,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_requester_device, UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_requester_bus,    UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_tag,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_completer_device, UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_completer_bus,    UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_requester_id_en,  UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_tc,               UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_attr,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_force_ecrc,       UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_first_be,         UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(rq_last_be,          UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        
        `uvm_field_int(cq_addr,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_addr_type,        UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_attr,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_tc,               UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_bar_aperture,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_bar_id,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_target_function,  UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_tag,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_bus,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_device,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_req_type,         UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cq_dword_count,      UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(cc_attr,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_tc,               UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_bar_aperture,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_bar_id,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_target_function,  UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_tag,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_bus,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cc_device,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(hcr_in_param,        UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_in_modifier,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_out_param,       UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_token,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_go,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_e,               UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_op_modifier,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(hcr_op,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_queue_int(data_payload,  UVM_DEFAULT|        UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(map_type,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(inbox_size,          UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_int(qpc_base,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(cqc_base,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(eqc_base,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(mpt_base,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(mtt_base,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_int(num_mtt,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)

        `uvm_field_enum(bool, ig_rq_addr,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_addr_type,       UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_dword_count,     UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_req_type,        UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_poisoned_req,    UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_requester_id,    UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_tag,             UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_completer_id,    UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_rqr_id_en,       UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_tc,              UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_attr,            UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq_force_ecrc,      UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_rq,                 UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
        `uvm_field_enum(bool, ig_base_reg,           UVM_DEFAULT|UVM_HEX|UVM_NOCOMPARE|UVM_NOPRINT)
    `uvm_object_utils_end

    constraint c_hcr 
    {
        hcr_go == 1;
        hcr_e == 0;
        hcr_token == `CMD_POLL_TOKEN;
        item_type == HCR;
        if (hcr_op == `CMD_INIT_HCA)
        {
            hcr_in_param == `INBOX_ADDR;
            hcr_in_modifier == 0;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
            inbox_size == 64;
        }
        else if (hcr_op == `CMD_QUERY_ADAPTER)
        {
            hcr_in_param == 0;
            hcr_in_modifier == 0;
            hcr_out_param == `OUTBOX_ADDR;
            hcr_op_modifier == 0;
        }
        else if (hcr_op == `CMD_QUERY_DEV_LIM)
        {
            hcr_in_param == 0;
            hcr_in_modifier == 0;
            hcr_out_param == `OUTBOX_ADDR;
            hcr_op_modifier == 0;
        }
        else if (hcr_op == `CMD_CLOSE_HCA)
        {
            hcr_in_param == 0;
            hcr_in_modifier == 0;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
        }
        else if (hcr_op == `CMD_MAP_ICM) // to be completed
        {
            hcr_in_param == `INBOX_ADDR;
            hcr_in_modifier == 1;
            hcr_out_param == 0;
            if (map_type == `ICM_QPC_TYP || map_type == `ICM_CQC_TYP || map_type == `ICM_EQC_TYP)
            {
                hcr_op_modifier == 1;
            }
            else if (map_type == `ICM_MPT_TYP || map_type == `ICM_MTT_TYP)
            {
                hcr_op_modifier == 2;
            }
            inbox_size == ((hcr_in_modifier >> 1) + 1) * 32;
        }
        else if (hcr_op == `CMD_RST2INIT_QPEE   ||
                 hcr_op == `CMD_INIT2RTR_QPEE   ||
                 hcr_op == `CMD_RTR2RTS_QPEE    ||
                 hcr_op == `CMD_RTS2RTS_QPEE    ||
                 hcr_op == `CMD_SQERR2RTS_QPEE  ||
                 hcr_op == `CMD_2ERR_QPEE       ||
                 hcr_op == `CMD_RTS2SQD_QPEE    ||
                 hcr_op == `CMD_SQD2SQD_QPEE    ||
                 hcr_op == `CMD_SQD2RTS_QPEE    ||
                 hcr_op == `CMD_INIT2INIT_QPEE  )
        {
            hcr_in_param == `INBOX_ADDR;
            hcr_in_modifier == qp_ctx.local_qpn;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
            inbox_size == 192;
        }
        else if (hcr_op == `CMD_ERR2RST_QPEE)
        {
            hcr_in_param == 0;
            hcr_in_modifier == num_mtt;
            hcr_out_param == 0;
            hcr_op_modifier == 3;
        }
        // else if (hcr_op == `CMD_UNMAP_ICM)
        // {

        // }
        // else if (hcr_op == `CMD_HW2SW_CQ)
        // {

        // }
        else if (hcr_op == `CMD_SW2HW_CQ)
        {
            hcr_in_param == `INBOX_ADDR;
            // hcr_in_modifier == ;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
            inbox_size == 64;
        }
        // else if (hcr_op == `CMD_RESIZE_CQ)
        // {

        // }
        // else if (hcr_op == `CMD_HW2SW_MPT)
        // {

        // }
        else if (hcr_op == `CMD_SW2HW_MPT)
        {
            hcr_in_param == `INBOX_ADDR;
            hcr_in_modifier == mpt_item.key;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
            inbox_size == 64;
        }
        else if (hcr_op == `CMD_WRITE_MTT)
        {
            hcr_in_param == `INBOX_ADDR;
            hcr_in_modifier == num_mtt;
            hcr_out_param == 0;
            hcr_op_modifier == 0;
            inbox_size == num_mtt * 64 + 256;
        }
        else if (hcr_op == `CMD_QUERY_QP)
        {
            hcr_in_param == 0;
            hcr_out_param == `OUTBOX_ADDR;
            // hcr_in_modifier == 0; do not set this
            hcr_op_modifier == 0;
            // inbox_size == 64;
        }
    }

    constraint c_cq_bar_aperture {
        if (cq_bar_id == 3'd0)
            cq_bar_aperture == 6'd20;
        else if (cq_bar_id == 3'd2)
            cq_bar_aperture == 6'd23;
    }
    

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_pcie_item");
        super.new(name);

        // ignore rq comparation
        ig_rq_addr                          = TRUE;
        ig_rq_addr_type                     = TRUE;
        ig_rq_dword_count                   = TRUE;
        ig_rq_req_type                      = TRUE;
        ig_rq_poisoned_req                  = TRUE;
        ig_rq_requester_id                  = TRUE;
        ig_rq_tag                           = TRUE;
        ig_rq_completer_id                  = TRUE;
        ig_rq_rqr_id_en                     = TRUE;
        ig_rq_tc                            = TRUE;
        ig_rq_attr                          = TRUE;
        ig_rq_force_ecrc                    = TRUE;
        ig_rq                               = TRUE;
        ig_base_reg                         = TRUE;
    endfunction

    //------------------------------------------------------------------------------
    // task name     : gen_cq_desc
    // function      : generate cq descriptor by related variables.
    // invoked       : invoked by hca_reg_driver
    //------------------------------------------------------------------------------
    task gen_cq_desc();
        cq_desc[1:0]        = cq_addr_type;
        cq_desc[63:2]       = cq_addr[63:2];
        cq_desc[74:64]      = cq_dword_count;
        cq_desc[78:75]      = cq_req_type;
        cq_desc[79]         = 0;
        cq_desc[87:80]      = cq_device;
        cq_desc[95:88]      = cq_bus;
        cq_desc[103:96]     = cq_tag;
        cq_desc[111:104]    = cq_target_function;
        cq_desc[114:112]    = cq_bar_id;
        cq_desc[120:115]    = cq_bar_aperture;
        cq_desc[123:121]    = cq_tc;
        cq_desc[126:124]    = cq_attr;
        cq_desc[127]        = 0;
    endtask: gen_cq_desc

    //------------------------------------------------------------------------------
    // task name     : gen_rc_desc
    // function      : generate cq descriptor by related variables.
    // invoked       : invoked by hca_reg_driver
    //------------------------------------------------------------------------------
    task gen_rc_desc();

    endtask: gen_rc_desc

    //------------------------------------------------------------------------------
    // task name     : gen_hcr
    // function      : generate hcr contents by related variables.
    // invoked       : invoked by ref model
    //------------------------------------------------------------------------------
    task gen_hcr();

    endtask: gen_hcr

    //------------------------------------------------------------------------------
    // function name : do_compare
    // function      : compare variables according to user set in scb.
    // invoked       : by scoreboard
    //------------------------------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        hca_pcie_item rhs_;
        do_compare = 1;
        if (rhs == null || !$cast(rhs_, rhs)) begin
            return 0;
        end
        do_compare &= super.do_compare(rhs, comparer);
        if (ig_rq == FALSE) begin
            do_compare &= comparer.compare_field_int("rq_addr", rq_addr, rhs_.rq_addr, 64); //
            do_compare &= comparer.compare_field_int("rq_addr_type", rq_addr_type, rhs_.rq_addr_type, 32);
            // do_compare &= comparer.compare_field_int("rq_dword_count", rq_addr_type, rhs_.rq_addr_type, 32);
            do_compare &= comparer.compare_field_int("rq_dword_count", rq_dword_count, rhs_.rq_dword_count, 32);
            do_compare &= comparer.compare_field_int("rq_req_type", rq_req_type, rhs_.rq_req_type, 32);
            while (data_payload.size() != 0) begin
                int i = 0;
                do_compare &= comparer.compare_field($sformatf("data_payload[%0d]", i), data_payload.pop_front(), rhs_.data_payload.pop_front(), 256);
                i++;
            end
            // do_compare &= comparer.compare_field_int("rq_poisoned_req", rq_poisoned_req, rhs_.rq_poisoned_req, 32);
            // do_compare &= comparer.compare_field_int("rq_requester_device", rq_requester_device, rhs_.rq_requester_device, 32);
            // do_compare &= comparer.compare_field_int("rq_requester_bus", rq_requester_bus, rhs_.rq_requester_bus, 32);
            // do_compare &= comparer.compare_field_int("rq_tag", rq_tag, rhs_.rq_tag, 32);
            // do_compare &= comparer.compare_field_int("rq_completer_device", rq_completer_device, rhs_.rq_completer_device, 32);
            // do_compare &= comparer.compare_field_int("rq_completer_bus", rq_completer_bus, rhs_.rq_completer_bus, 32);
            // do_compare &= comparer.compare_field_int("rq_requester_id_en", rq_requester_id_en, rhs_.rq_requester_id_en, 32);
            // do_compare &= comparer.compare_field_int("rq_tc", rq_tc, rhs_.rq_tc, 32);
            // do_compare &= comparer.compare_field_int("rq_attr", rq_attr, rhs_.rq_attr, 32);
            // do_compare &= comparer.compare_field_int("rq_force_ecrc", rq_force_ecrc, rhs_.rq_force_ecrc, 32);
        end
        if (ig_base_reg == FALSE) begin
            // to do
            do_compare &= comparer.compare_field("qpc_base", qpc_base, rhs_.qpc_base, `ADDR_WIDTH);
            do_compare &= comparer.compare_field("cqc_base", cqc_base, rhs_.cqc_base, `ADDR_WIDTH);
            do_compare &= comparer.compare_field("eqc_base", eqc_base, rhs_.eqc_base, `ADDR_WIDTH);
            do_compare &= comparer.compare_field("mpt_base", mpt_base, rhs_.mpt_base, `ADDR_WIDTH);
            do_compare &= comparer.compare_field("mtt_base", mtt_base, rhs_.mtt_base, `ADDR_WIDTH);
        end
        return do_compare;
    endfunction: do_compare


    // uvm field macros do not support struct, so a copy function for struct should be manually added
    function copy_struct(hca_pcie_item item);
        this.qp_ctx = item.qp_ctx;
        this.cq_ctx = item.cq_ctx;
        this.db = item.db;
        this.mpt_item = item.mpt_item;
        this.mtt_item = item.mtt_item;
        this.icm_base_struct = item.icm_base_struct;
        this.icm_addr_map = item.icm_addr_map;
    endfunction: copy_struct

endclass: hca_pcie_item
`endif