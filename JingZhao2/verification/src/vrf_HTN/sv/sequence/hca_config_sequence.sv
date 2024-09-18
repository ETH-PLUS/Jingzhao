//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-26
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_config_sequence.sv
//  FUNCTION : This file supplies the sequence of configuration verification.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-26    v1.0             create
//  mazhenlong      2021-04-06    v1.1             add gen_inbox
//  mazhenlong      2021-05-10    v1.2             change class type from uvm_reg_sequence
//                                                 to uvm_sequence and delete register model
//  mazhenlong      2021-07-23    v1.3             optimize code, split large functions and 
//                                                 tasks
//
//----------------------------------------------------------------------------

`ifndef __HCA_CONFIG_SEQUENCE__
`define __HCA_CONFIG_SEQUENCE__

//------------------------------------------------------------------------------
//
// CLASS: hca_config_sequence
//
//------------------------------------------------------------------------------
class hca_config_sequence extends uvm_sequence #(hca_pcie_item);
    // hca_reg_block_hcr reg_blk_hcr;
    hca_pcie_item cfg_item_que[$];
    hca_pcie_item cfg_item;
    // uvm_tlm_analysis_fifo #(hca_pcie_item) cfg_fifo;
    hca_memory mem;
    hca_fifo #(.width(256)) data_fifo;
    string seq_name;

    // hca_event_generator event_generator;
    mailbox cmd_done;

    // addr temp_virt_addr;
    // addr temp_phys_addr;

    `uvm_object_utils(hca_config_sequence)
    
    //------------------------------------------------------------------------------
    // function name : new 
    // function      : constructor 
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_config_sequence");
        super.new(name);
        // cfg_item = hca_pcie_item::type_id::create("cfg_item");
        data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");
        // cfg_fifo = new("cfg_fifo");
    endfunction: new
    
    //------------------------------------------------------------------------------
    // task name     : pre_body 
    // function      : cast the register model passed in to reg_blk_hcr 
    // invoked       : be invoked by uvm
    //------------------------------------------------------------------------------
    virtual task pre_body();
        // get case name
        if(!uvm_config_db#(mailbox)::get(null, get_full_name(), "mbx_cmd_done", cmd_done)) begin
            `uvm_fatal("NO_MBX", $sformatf("mailbox not get in config_sequence! full name: %s, m_sequencer: %s.", get_full_name(), m_sequencer.get_full_name()));
        end
    endtask: pre_body

    //------------------------------------------------------------------------------
    // task name     : body
    // function      : generate pcie items 
    // invoked       : invoked by uvm automatically
    //------------------------------------------------------------------------------
    task body();
        bit [`DATA_WIDTH-1 : 0] temp_data;
        bit                     cmd_result;
        while (cfg_item_que.size() != 0) begin
            `uvm_info("NOTICE", "processing config item in config sequence", UVM_LOW);
            cfg_item = cfg_item_que.pop_front();
            `uvm_info("NOTICE", "config item got in config sequence", UVM_LOW);
            start_item(cfg_item);
            if (cfg_item.item_type == HCR) begin
                `uvm_info("ITEM_INFO", "HCR item received in config sequence", UVM_LOW);
                // print_begin_info(cfg_item);
                write_inbox(cfg_item);
                set_cq_payload(cfg_item);
                finish_item(cfg_item);

                // synchronize with master driver and DUT, wati until clear
                cmd_done.get(cmd_result);
            end
            else if (cfg_item.item_type == GLOBAL_STOP) begin
                `uvm_info("ITEM_INFO", "GLOBAL_STOP item received by config sequence!", UVM_LOW);
                finish_item(cfg_item);
            end
            else if (cfg_item.item_type == INTR) begin
                `uvm_info("ITEM_INFO", "INTR item received by config sequence!", UVM_LOW);
                finish_item(cfg_item);

            end
            else begin
                `uvm_fatal("ITEM_TYP_ERR", $sformatf("Illegal cfg_item type! item_type: %h.", cfg_item.item_type));
            end
        end
        `uvm_info("NOTICE", "cfg_item finished in config_sequence!", UVM_LOW);
    endtask: body

    task write_inbox(hca_pcie_item item);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] inbox_data;
        hca_pcie_item temp_item;
        temp_item = hca_pcie_item::type_id::create("temp_item");
        temp_item.copy(item);
        temp_item.copy_struct(item);
        data_fifo.clean();

        case (temp_item.hcr_op)
            `CMD_INIT_HCA: begin
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i] = 0;
                end
                for (int i = 0; i < 7; i++) begin
                    inbox_data[i + 8] = temp_item.icm_base_struct.qpc_base[63 - i * 8 -: 8]; // big endian
                end
                inbox_data[15] = temp_item.icm_base_struct.log_num_qps;
                for (int i = 0; i < 7; i++) begin
                    inbox_data[i + 16] = temp_item.icm_base_struct.cqc_base[63 - i * 8 -: 8];
                end
                inbox_data[23] = temp_item.icm_base_struct.log_num_cqs;
                for (int i = 0; i < 7; i++) begin
                    inbox_data[i + 24] = temp_item.icm_base_struct.eqc_base[63 - i * 8 -: 8];
                end
                inbox_data[31] = temp_item.icm_base_struct.log_num_eqs; // DW full
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 16; i++) begin
                    inbox_data[i] = 0;
                end
                for (int i = 0; i < 7; i++) begin
                    inbox_data[i + 16] = temp_item.icm_base_struct.mpt_base[63 - i * 8 -: 8];
                end
                inbox_data[23] = temp_item.icm_base_struct.log_mpt_sz;
                for (int i = 0; i < 8; i++) begin // ??
                    inbox_data[i + 24] = temp_item.icm_base_struct.mtt_base[63 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;
            end
            `CMD_MAP_ICM: begin
                // warning: not support multichunk
                bit [63:0] temp;
                for (int i = 0; i < 16; i++) begin
                    inbox_data[i] = 0;
                end

                temp = temp_item.icm_addr_map.virt.pop_front();
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i + 16] = temp[63 - i * 8 -: 8];
                end

                temp = temp_item.icm_addr_map.page.pop_front();
                for (int i = 0; i < 6; i++) begin
                    inbox_data[i + 24] = temp[63 - i * 8 -: 8];
                end

                inbox_data[30] = {temp[15:12], temp_item.icm_addr_map.page_num[11:8]};
                inbox_data[31] = temp_item.icm_addr_map.page_num[7:0];
                data_fifo.push(inbox_data);
            end
            `CMD_RST2INIT_QPEE   ,
            `CMD_INIT2RTR_QPEE   ,
            `CMD_RTR2RTS_QPEE    ,
            `CMD_RTS2RTS_QPEE    ,
            `CMD_SQERR2RTS_QPEE  ,
            `CMD_2ERR_QPEE       ,
            `CMD_RTS2SQD_QPEE    ,
            `CMD_SQD2SQD_QPEE    ,
            `CMD_SQD2RTS_QPEE    ,
            `CMD_INIT2INIT_QPEE: begin
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.qp_ctx.opt_param_mask[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = 0;
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.qp_ctx.flags[31 - i * 8 -: 8];
                end
                inbox_data[12] = temp_item.qp_ctx.mtu_msgmax;
                inbox_data[13] = temp_item.qp_ctx.rq_entry_sz_log;
                inbox_data[14] = temp_item.qp_ctx.sq_entry_sz_log;
                inbox_data[15] = temp_item.qp_ctx.rlkey_arbel_sched_queue;
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 16] = temp_item.qp_ctx.usr_page[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 20] = temp_item.qp_ctx.local_qpn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 24] = temp_item.qp_ctx.remote_qpn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 28] = temp_item.qp_ctx.port_pkey[31 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;

                inbox_data[0] = temp_item.qp_ctx.rnr_retry;
                inbox_data[1] = temp_item.qp_ctx.g_mylmc;
                inbox_data[2] = 0; // temp_item.qp_ctx.rlid[15:8];
                inbox_data[3] = 0; // temp_item.qp_ctx.rlid[7:0];
                inbox_data[4] = temp_item.qp_ctx.ackto;
                inbox_data[5] = temp_item.qp_ctx.mgid_index;
                inbox_data[6] = temp_item.qp_ctx.static_rate;
                inbox_data[7] = temp_item.qp_ctx.hop_limit;
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.qp_ctx.sl_tclass_flowlabel[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 16; i++) begin
                    inbox_data[i + 12] = temp_item.qp_ctx.rgid[127 - i * 8 -: 8];
                end
                inbox_data[28] = temp_item.qp_ctx.dmac[15:8];
                inbox_data[29] = temp_item.qp_ctx.dmac[7:0];
                inbox_data[30] = temp_item.qp_ctx.smac[15:8];
                inbox_data[31] = temp_item.qp_ctx.smac[7:0];
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.qp_ctx.smac[47 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = temp_item.qp_ctx.dmac[47 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.qp_ctx.sip[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 12] = temp_item.qp_ctx.dip[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 12; i++) begin
                    inbox_data[i + 16] = 0;
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 28] = temp_item.qp_ctx.pd[31 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.qp_ctx.wqe_base[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = temp_item.qp_ctx.wqe_lkey[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = 0;
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 12] = temp_item.qp_ctx.next_send_psn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 16] = temp_item.qp_ctx.cqn_snd[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 20] = temp_item.qp_ctx.snd_wqe_base_l[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 24] = temp_item.qp_ctx.snd_wqe_len[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 28] = temp_item.qp_ctx.last_acked_psn[31 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.qp_ctx.ssn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = temp_item.qp_ctx.rnr_nextrecvpsn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.qp_ctx.ra_buff_indx[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 12] = temp_item.qp_ctx.cqn_rcv[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 16] = temp_item.qp_ctx.rcv_wqe_base_l[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 20] = temp_item.qp_ctx.rcv_wqe_len[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 24] = temp_item.qp_ctx.qkey[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 28] = temp_item.qp_ctx.rmsn[31 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 28; i++) begin
                    inbox_data[i] = 0;
                end
                inbox_data[28] = temp_item.qp_ctx.rq_wqe_counter[15:8];
                inbox_data[29] = temp_item.qp_ctx.rq_wqe_counter[7:0];
                inbox_data[30] = temp_item.qp_ctx.sq_wqe_counter[15:8];
                inbox_data[31] = temp_item.qp_ctx.sq_wqe_counter[7:0];
                data_fifo.push(inbox_data);
                inbox_data = 0;
            end
            `CMD_WRITE_MTT: begin
                int beat_num;
                addr temp_phys_addr;
                data_fifo.clean();
                // calculate beat num
                if (temp_item.inbox_size % 256 == 0) begin
                    beat_num = temp_item.inbox_size / 256;
                end
                else begin
                    beat_num = temp_item.inbox_size / 256 + 1;
                end
                
                for (int j = 0; j < beat_num; j++) begin
                    // write start index
                    if (j == 0) begin
                        for (int i = 0; i < 24; i++) begin
                            inbox_data[i] = 0;
                        end
                        for (int i = 0; i < 8; i++) begin
                            inbox_data[i + 24] = temp_item.mtt_item.start_index[63 - i * 8 -: 8];
                        end
                        data_fifo.push(inbox_data);
                        inbox_data = 0;
                    end
                    else begin
                        for (int i = 0; i < 4; i++) begin
                            if (temp_item.mtt_item.phys_addr.size() != 0) begin
                                temp_phys_addr = temp_item.mtt_item.phys_addr.pop_front();
                                for (int k = 0; k < 8; k++) begin
                                    inbox_data[24 - 8 * i + k] = temp_phys_addr[63 - k * 8 -: 8];
                                end
                            end
                            else begin
                                break;
                            end
                        end
                        data_fifo.push(inbox_data);
                        inbox_data = 0;
                    end
                end
            end
            `CMD_SW2HW_MPT: begin
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.mpt_item.flags[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = temp_item.mpt_item.page_size[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.mpt_item.key[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 12] = temp_item.mpt_item.pd[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i + 16] = temp_item.mpt_item.start[63 - i * 8 -: 8];
                end
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i + 24] = temp_item.mpt_item.length[63 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.mpt_item.lkey[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 4] = temp_item.mpt_item.window_count[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 8] = temp_item.mpt_item.window_count_limit[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i + 12] = temp_item.mpt_item.mtt_seg[63 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 20] = temp_item.mpt_item.mtt_sz[31 - i * 8 -: 8];
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;
            end
            `CMD_SW2HW_CQ: begin
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i] = temp_item.cq_ctx.flags[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 8; i++) begin
                    inbox_data[i + 4] = temp_item.cq_ctx.start[63 - i * 8 -: 8];
                end
                inbox_data[12] = temp_item.cq_ctx.logsize;
                for (int i = 0; i < 3; i++) begin
                    inbox_data[i + 13] = temp_item.cq_ctx.usrpage[23 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 16] = temp_item.cq_ctx.comp_eqn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 20] = temp_item.cq_ctx.pd[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 24] = temp_item.cq_ctx.lkey[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 28] = 0;
                end
                data_fifo.push(inbox_data);
                inbox_data = 0;

                for (int i = 0; i < 12; i++) begin
                    inbox_data[i] = 0;
                end
                for (int i = 0; i < 4; i++) begin
                    inbox_data[i + 12] = temp_item.cq_ctx.cqn[31 - i * 8 -: 8];
                end
                for (int i = 0; i < 16; i++) begin
                    inbox_data[i + 16] = 0;
                end
                data_fifo.push(inbox_data);
            end
        endcase

        // write content in data_fifo into inbox
        if (temp_item.inbox_size != 0 ) begin
            mem.write_block(`INBOX_ADDR, data_fifo, temp_item.inbox_size);
        end
    endtask: write_inbox

    task set_cq_payload(hca_pcie_item item);
        // set cq descriptor and data_payload, which will become cq_tdata
        bit [`DATA_WIDTH - 1 : 0] temp_data;
        item.cq_addr = `HCR_BAR_ADDR;
        item.cq_addr_type = 0; //not sure
        item.cq_attr = 0; //not sure
        item.cq_tc = 0; //not sure
        item.cq_target_function = 0; //not sure
        item.cq_tag = 0; //not sure
        item.cq_bus = 0; //not sure
        item.cq_req_type = MEM_WR;
        item.cq_dword_count = 7;
        item.cq_bar_id = `HCR_BAR_ID;
        item.cq_bar_aperture = 28;
        temp_data = {
            {32'b0},
            {8'b0, item.hcr_go, item.hcr_e, 2'b0, item.hcr_op_modifier, item.hcr_op},
            {item.hcr_token, 16'b0},
            {item.hcr_out_param[31:0]},
            {item.hcr_out_param[63:32]},
            {item.hcr_in_modifier},
            {item.hcr_in_param[31:0]},
            {item.hcr_in_param[63:32]}};
        item.data_payload.push_back(temp_data);
        `uvm_info("NOTICE", $sformatf("input hcr: %h", temp_data), UVM_LOW);
    endtask: set_cq_payload

    task print_begin_info(hca_pcie_item cfg_item);
        case (cfg_item.hcr_op)
            `CMD_INIT_HCA: begin
                `uvm_info("CMD_BEGIN_NOTICE", "init hca begin!", UVM_LOW);
            end
            `CMD_CLOSE_HCA: begin
                `uvm_info("CMD_BEGIN_NOTICE", "close hca begin!", UVM_LOW);
            end
            `CMD_QUERY_ADAPTER: begin
                `uvm_info("CMD_BEGIN_NOTICE", "query adapter begin!", UVM_LOW);
            end
            `CMD_QUERY_DEV_LIM: begin
                `uvm_info("CMD_BEGIN_NOTICE", "query dev lim begin!", UVM_LOW);
            end
            `CMD_QUERY_QP: begin
                `uvm_info("CMD_BEGIN_NOTICE", "query qp begin!", UVM_LOW);
            end
            `CMD_MAP_ICM: begin
                `uvm_info("CMD_BEGIN_NOTICE", "map icm begin!", UVM_LOW);
            end
            `CMD_RST2INIT_QPEE,
            `CMD_INIT2RTR_QPEE,
            `CMD_RTR2RTS_QPEE,
            `CMD_RTS2RTS_QPEE,
            `CMD_SQERR2RTS_QPEE,
            `CMD_2ERR_QPEE,
            `CMD_RTS2SQD_QPEE,
            `CMD_SQD2SQD_QPEE,
            `CMD_SQD2RTS_QPEE,
            `CMD_INIT2INIT_QPEE: begin
                `uvm_info("CMD_BEGIN_NOTICE", "modify qp begin!", UVM_LOW);
            end
            `CMD_WRITE_MTT: begin
                `uvm_info("CMD_BEGIN_NOTICE", "write mtt begin!", UVM_LOW);
            end
            `CMD_SW2HW_MPT: begin
                `uvm_info("CMD_BEGIN_NOTICE", "sw2hw mpt begin!", UVM_LOW);
            end
            `CMD_SW2HW_CQ: begin
                `uvm_info("CMD_BEGIN_NOTICE", "sw2hw cq begin!", UVM_LOW);
            end
            default: begin
                // if (seq_name != "test_ilg_op") begin
                //     `uvm_fatal("HCR_OP_ERROR", $sformatf("Illegal hcr opcode! hcr_op: %h", cfg_item.hcr_op));
                // end
                // else begin
                //     `uvm_info("CMD_BEGIN_NOTICE", "test illegal op begin!", UVM_LOW);
                // end
                `uvm_fatal("HCR_OP_ERROR", $sformatf("Illegal hcr opcode! hcr_op: %h", cfg_item.hcr_op));
            end
        endcase
    endtask: print_begin_info
endclass: hca_config_sequence
`endif
