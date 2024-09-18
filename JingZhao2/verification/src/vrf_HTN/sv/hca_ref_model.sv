//CREATE INFORMATION
//--------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-09
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_ref_model.sv
//  FUNCTION : This file supplies the reference model of DUV.
//
//--------------------------------------------------------------------------------------

//CHANGE HISTORY
//--------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-09    v1.0             create
//  mazhenlong      2021-09-17    v1.1             modify format of QP context in QUERY_QP
//
//--------------------------------------------------------------------------------------

`ifndef __HCA_REF_MODEL__
`define __HCA_REF_MODEL__

//----------------------------------------------------------------------------------------
//
// CLASS: hca_ref_model
//
//----------------------------------------------------------------------------------------
class hca_ref_model extends uvm_component;

    uvm_tlm_analysis_fifo #(hca_pcie_item, hca_ref_model) cfg_fifo[]; // from master driver
    hca_pcie_item cfg_fifo_item[];
    uvm_analysis_port #(hca_pcie_item) port2scb[];

    uvm_tlm_analysis_fifo #(hca_pcie_item, hca_ref_model) cfg_resp_fifo[]; // from slave driver
    hca_pcie_item cfg_resp_fifo_item[];

    uvm_tlm_analysis_fifo #(hca_pcie_item, hca_ref_model) comm_fifo[]; // from slave driver
    hca_pcie_item comm_fifo_item[];

    hca_memory mem[];
    int host_num = 1;
    hca_queue_list q_list;
    hca_icm_vaddr icm_vaddr;
    hca_mem_info mem_info;
    
  
    bit      [`ADDR_WIDTH - 1 : 0] qpc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] cqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] eqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mpt_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mtt_virt_addr[][$];

    mpt                            mpt_item[][$];

    bit      [`ADDR_WIDTH - 1 : 0] mtt_item_index[][$]; // icm virtual address of mtt item
    bit      [`ADDR_WIDTH - 1 : 0] data_phys_addr[][$];

    mtt                            mem_table[][$];

    icm_base                            icm_base_addr[];
    qp_context                          qpc[][$];
    cq_context                          cqc[][$];

    int max_payload_size;
    int max_read_req_size;

    `uvm_component_utils_begin(hca_ref_model)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : be invoked when instantiates hca_ref_model
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build phase in uvm library, instantiates variables
    // invoked       : be invoked by uvm automaticly
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        
        string array_element;
        super.build_phase(phase);

        cfg_fifo            = new[host_num];
        cfg_fifo_item       = new[host_num];

        cfg_resp_fifo       = new[host_num];
        cfg_resp_fifo_item  = new[host_num];

        comm_fifo           = new[host_num];
        comm_fifo_item      = new[host_num];

        port2scb            = new[host_num];

        icm_base_addr       = new[host_num];
        qpc_virt_addr       = new[host_num];
        cqc_virt_addr       = new[host_num];
        eqc_virt_addr       = new[host_num];
        mpt_virt_addr       = new[host_num];
        mtt_virt_addr       = new[host_num];

        data_phys_addr      = new[host_num];
        qpc                 = new[host_num];
        cqc                 = new[host_num];
        mtt_item_index      = new[host_num];
        mpt_item            = new[host_num];

        mem                 = new[host_num];
        mem_table           = new[host_num];

        for (int i = 0; i < host_num; i++) begin
            $sformat(array_element, "cfg_fifo[%0d]", i);
            cfg_fifo[i] = new(array_element, this);
        end

        for (int i = 0; i < host_num; i++) begin
            $sformat(array_element, "cfg_resp_fifo[%0d]", i);
            cfg_resp_fifo[i] = new(array_element, this);
        end

        for (int i = 0; i < host_num; i++) begin
            $sformat(array_element, "comm_fifo[%0d]", i);
            comm_fifo[i] = new(array_element, this);
        end

        for (int i = 0; i < host_num; i++) begin
            $sformat(array_element, "port2scb[%0d]", i);
            port2scb[i] = new(array_element, this);
        end

        if (!uvm_config_db#(hca_queue_list)::get(this, "", "q_list", q_list)) begin
            `uvm_fatal("NOQLIST", {"q_list must be set for: ",get_full_name(),".q_list"});
        end
        if (!uvm_config_db#(hca_icm_vaddr)::get(this, "", "icm_vaddr", icm_vaddr)) begin
            `uvm_fatal("NOQLIST", {"icm vaddr must be set for: ",get_full_name(),".icm_vaddr"});
        end
        if (!uvm_config_db#(hca_mem_info)::get(this, "", "mem_info", mem_info)) begin
            `uvm_fatal("NOQLIST", {"mem info must be set for: ",get_full_name(),".mem_info"});
        end
        case(`MAX_PAYLOAD)
            3'b000: begin
                max_payload_size = 128;
            end
            3'b010: begin
                max_payload_size = 256;
            end
            3'b011: begin
                max_payload_size = 512;
            end
            3'b100: begin
                max_payload_size = 1024;
            end
            3'b101: begin
                max_payload_size = 4096;
            end
        endcase

        case(`MAX_READ_REQ)
            3'b000: begin
                max_read_req_size = 128;
            end
            3'b010: begin
                max_read_req_size = 256;
            end
            3'b011: begin
                max_read_req_size = 512;
            end
            3'b100: begin
                max_read_req_size = 1024;
            end
            3'b101: begin
                max_read_req_size = 4096;
            end
        endcase
        
    endfunction: build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase

    //------------------------------------------------------------------------------
    // task name     : run_phase
    // function      : run phase in uvm library, sends the pcie items to scoreboard
    // invoked       : be invoked by uvm automaticly
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info("NOTICE", "ref model run_phase begin!", UVM_LOW);
        // forever begin //wrong!
        for (int i = 0; i < host_num; i++) begin
            fork
                automatic int j = i;
                while (1) begin
                    `uvm_info("NOTICE", "cfg_fifo_item ready to get in ref model!", UVM_LOW);
                    cfg_fifo[j].get(cfg_fifo_item[j]);
                    `uvm_info("NOTICE", "cfg_fifo_item get in ref model!", UVM_LOW);
                    if (cfg_fifo_item[j].item_type == GLOBAL_STOP) begin
                        `uvm_info("NOTICE", "global stop cfg_fifo_item get in ref model!", UVM_LOW);
                        break;
                    end
                    process_cfg_item(cfg_fifo_item[j], j);
                    // `uvm_info("NOTICE", "process cfg item finished in ref model!", UVM_LOW);
                    listen_inbox(cfg_fifo_item[j], j);
                end
                while (1) begin
                    comm_fifo[j].get(comm_fifo_item[j]);
                    `uvm_info("NOTICE", "comm_fifo_item get in ref model!", UVM_LOW);
                    if (comm_fifo_item[j].item_type == GLOBAL_STOP) begin
                        `uvm_info("NOTICE", "global stop comm_fifo_item get in ref model!", UVM_LOW);
                        break;
                    end
                    // process_db(comm_fifo_item[j].db.proc_id, j, comm_fifo_item[j].db);
                end
            join_none
        end
        wait fork;
        `uvm_info("NOTICE", "ref model run_phase end!", UVM_LOW);
        // end
    endtask: run_phase

    //------------------------------------------------------------------------------
    // task name     : process_cfg_item
    // function      : process config item received and send dma requests to scoreboard.
    // invoked       : by run_phase()
    //------------------------------------------------------------------------------
    task process_cfg_item(hca_pcie_item cfg_item, int host_id);
        hca_pcie_item exp_item;
        bit [`DATA_WIDTH-1 : 0] temp_data;
        case (cfg_item.hcr_op)
            `CMD_INIT_HCA: begin
                icm_base_addr[host_id] = cfg_item.icm_base_struct;
                send_read_mbx_req(host_id, `INIT_HCA_INBOX_DW_CNT, cfg_item.rq_tag);
                `uvm_info("NOTICE", "init hca finished in ref model", UVM_LOW);
            end
            `CMD_QUERY_DEV_LIM: begin
                exp_item = hca_pcie_item::type_id::create("query_dev_lim_item");
                exp_item.rq_addr = `OUTBOX_ADDR;
                exp_item.rq_addr_type = 0;
                exp_item.rq_dword_count = `DEV_LIM_DW_CNT;
                exp_item.rq_req_type = MEM_WR;
                exp_item.rq_poisoned_req = 0;
                exp_item.rq_requester_device = 0; // ?
                exp_item.rq_requester_bus = 0;
                exp_item.rq_tag = cfg_item.rq_tag;
                exp_item.rq_completer_device = 0;
                exp_item.rq_completer_bus = 0;
                exp_item.rq_requester_id_en = 0;
                exp_item.rq_tc = 0;
                exp_item.rq_attr = 0;
                exp_item.rq_force_ecrc = 0;
                temp_data = {
                    `RESVED_QPS, `RESVED_CQS, `RESVED_EQS, `RESVED_MTTS,
                    8'd0, `RESVED_PDS, 8'd0, `RESVED_LKEYS,
                    `MAX_QP_SZ, `MAX_CQ_SZ,
                    `MAX_QPS, `MAX_CQS, `MAX_EQS, `MAX_MPTS,
                    `MAX_PDS, 8'd0, `MAX_GIDS, `MAX_PKEYS,
                    8'd0, `MAX_MTT_SEG, 16'd0, 
                    `QPC_ENTRY_SZ, `CQC_ENTRY_SZ, 
                    `EQC_ENTRY_SZ, `MPT_ENTRY_SZ
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    4'd0, `ACK_DELAY, `MAX_MTU, `MAX_PORT_WIDTH, 8'd0, `MAX_VL, `NUM_PORTS,
                    8'd0, `MIN_PAGE_SZ, 16'd0, 
                    8'd0, `MAX_SG, `MAX_DESC_SZ,
                    8'd0, `MAX_SG_RQ, `MAX_DESC_SZ_RQ,
                    `MAX_ICM_SZ,
                    32'd0,
                    32'd0
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                port2scb[host_id].write(exp_item);
                `uvm_info("NOTICE", "query dev lim finished in ref model", UVM_LOW);
            end
            `CMD_QUERY_ADAPTER: begin
                exp_item = hca_pcie_item::type_id::create("query_adapter_item");
                exp_item.rq_addr = `OUTBOX_ADDR;
                exp_item.rq_addr_type = 0;
                exp_item.rq_dword_count = `ADAPTER_DW_CNT;
                exp_item.rq_req_type = MEM_WR;
                exp_item.rq_poisoned_req = 0;
                exp_item.rq_requester_device = 0; // ?
                exp_item.rq_requester_bus = 0;
                exp_item.rq_tag = cfg_item.rq_tag;
                exp_item.rq_completer_device = 0;
                exp_item.rq_completer_bus = 0;
                exp_item.rq_requester_id_en = 0;
                exp_item.rq_tc = 0;
                exp_item.rq_attr = 0;
                exp_item.rq_force_ecrc = 0;
                temp_data = {
                    32'd0, 
                    32'd0, 
                    32'd0, 
                    32'd0, 
                    32'd0, 
                    32'd0,
                    `BOARD_ID
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                port2scb[host_id].write(exp_item);
                `uvm_info("NOTICE", "query adapter finished in ref model", UVM_LOW);
            end
            `CMD_MAP_ICM: begin // check and modify
                if (cfg_item.icm_addr_map.virt.size == 0) begin
                    `uvm_fatal("EMPTY_MAP_ICM", "cfg_item.icm_addr_map.virt is empty!");
                end
                // currently not support unmap_icm, so virtual address can be simply pushed
                if (cfg_item.map_type == `ICM_QPC_TYP) begin
                    for (int i = 0; i < cfg_item.icm_addr_map.page_num; i++) begin
                        qpc_virt_addr[host_id].push_back(cfg_item.icm_addr_map.virt.pop_front());
                    end
                end
                else if (cfg_item.map_type == `ICM_CQC_TYP) begin
                    for (int i = 0; i < cfg_item.icm_addr_map.page_num; i++) begin
                        cqc_virt_addr[host_id].push_back(cfg_item.icm_addr_map.virt.pop_front());
                    end
                end
                else if (cfg_item.map_type == `ICM_MPT_TYP) begin
                    for (int i = 0; i < cfg_item.icm_addr_map.page_num; i++) begin
                        mpt_virt_addr[host_id].push_back(cfg_item.icm_addr_map.virt.pop_front());
                    end
                end
                else if (cfg_item.map_type == `ICM_MTT_TYP) begin
                    for (int i = 0; i < cfg_item.icm_addr_map.page_num; i++) begin
                        mtt_virt_addr[host_id].push_back(cfg_item.icm_addr_map.virt.pop_front());
                    end
                end
                else if (cfg_item.map_type == `ICM_EQC_TYP) begin
                    for (int i = 0; i <cfg_item.icm_addr_map.page_num; i++) begin
                        eqc_virt_addr[host_id].push_back(cfg_item.icm_addr_map.virt.pop_front());
                    end
                end
                else begin
                    `uvm_fatal("MAP_TYPE_ERROR", "illegal map type in reference model!");
                end
                send_read_mbx_req(host_id, 8, cfg_item.rq_tag);
                `uvm_info("NOTICE", "map icm finished in ref model", UVM_LOW);
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
                qpc[host_id].push_back(cfg_item.qp_ctx);
                `uvm_info("NOTICE", $sformatf("write qp context, qp number: %h", cfg_item.qp_ctx.local_qpn), UVM_LOW);
                send_read_mbx_req(host_id, `QPC_DW_CNT, cfg_item.rq_tag);
                `uvm_info("NOTICE", "modify qp finished in ref model", UVM_LOW);
            end
            `CMD_WRITE_MTT: begin // check and modify
                                  // currently not support modify mtt, so virtual address can be simply pushed
                // int i;
                // for (int i = 0; i < mtt_item[host_id].size; i++) begin
                //     if (mtt_item)
                // end
                bit [`ADDR_WIDTH] temp_index;
                bit flag = 0;
                bit [10:0] dword_count;
                temp_index = cfg_item.mtt_item.start_index;
                while (cfg_item.mtt_item.phys_addr.size != 0) begin
                    flag = 1;
                    `uvm_info("NOTICE", $sformatf("write start index: %h", temp_index), UVM_LOW);
                    mtt_item_index[host_id].push_back(temp_index);
                    data_phys_addr[host_id].push_back(cfg_item.mtt_item.phys_addr.pop_front());
                    temp_index++;
                end
                if (flag == 0) begin
                    `uvm_fatal("EMPTY_MTT", "mtt_item is empty!");
                end
                // mtt_item[host_id].push_back(cfg_item.mtt_item);
                // dword_count = cfg_item.num_mtt * 2 + 8;
                if (cfg_item.num_mtt % 4 == 0) begin
                    dword_count = cfg_item.num_mtt * 2 + 8;
                end
                else begin
                    dword_count = ((cfg_item.num_mtt / 4) + 1) * 8 + 8;
                end
                send_read_mbx_req(host_id, dword_count, cfg_item.rq_tag);
                `uvm_info("NOTICE", "write mtt finished in ref model", UVM_LOW);
            end
            `CMD_SW2HW_MPT: begin
                mpt_item[host_id].push_back(cfg_item.mpt_item);
                send_read_mbx_req(host_id, 16, cfg_item.rq_tag);
                `uvm_info("NOTICE", "sw2hw mpt finished in ref model", UVM_LOW);
            end
            `CMD_QUERY_QP: begin
                int i;
                int flag = 0;
                qp_context temp_qpc;
                for (i = 0; i < q_list.qp_list[host_id].size; i++) begin
                    if (q_list.qp_list[host_id][i].ctx.local_qpn == cfg_item.hcr_in_modifier) begin
                        temp_qpc = q_list.qp_list[host_id][i].ctx;
                        flag = 1;
                        break;
                    end
                end
                if (flag == 0) begin
                    if (q_list.qp_list[host_id].size == 0) begin
                        `uvm_fatal("Empty QPC list", $sformatf("qpc list is empty! host_id: %h", host_id));
                    end
                    `uvm_fatal("QPC not found", $sformatf("NO QPC found in query qp in ref model! qpn: %h", cfg_item.hcr_in_modifier));
                end
                `uvm_info("NOTICE","QPC found in query qp in ref model!", UVM_LOW);

                exp_item = hca_pcie_item::type_id::create("exp_item", this);
                exp_item.rq_addr = `OUTBOX_ADDR;
                exp_item.rq_addr_type = 0;
                exp_item.rq_dword_count = `QPC_DW_CNT;
                exp_item.rq_req_type = MEM_WR;
                exp_item.rq_poisoned_req = 0;
                exp_item.rq_requester_device = 0; // ?
                exp_item.rq_requester_bus = 0;
                exp_item.rq_tag = cfg_item.rq_tag;
                exp_item.rq_completer_device = 0;
                exp_item.rq_completer_bus = 0;
                exp_item.rq_requester_id_en = 0;
                exp_item.rq_tc = 0;
                exp_item.rq_attr = 0;
                exp_item.rq_force_ecrc = 0;

                temp_data = {
                    temp_qpc.opt_param_mask,
                    32'b0, 
                    temp_qpc.flags,
                    temp_qpc.mtu_msgmax, temp_qpc.rq_entry_sz_log, temp_qpc.sq_entry_sz_log, temp_qpc.rlkey_arbel_sched_queue,
                    temp_qpc.usr_page,
                    temp_qpc.local_qpn,
                    temp_qpc.remote_qpn,
                    temp_qpc.port_pkey
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    temp_qpc.rnr_retry, temp_qpc.g_mylmc, 16'b0,
                    temp_qpc.ackto, temp_qpc.mgid_index, temp_qpc.static_rate, temp_qpc.hop_limit,
                    temp_qpc.sl_tclass_flowlabel,
                    temp_qpc.rgid,
                    temp_qpc.dmac[15:0], temp_qpc.smac[15:0]
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    temp_qpc.smac[47:16],
                    temp_qpc.dmac[47:16],
                    temp_qpc.sip,
                    temp_qpc.dip,
                    96'b0,
                    temp_qpc.pd
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    temp_qpc.wqe_base,
                    temp_qpc.wqe_lkey,
                    32'b0,
                    temp_qpc.next_send_psn,
                    temp_qpc.cqn_snd,
                    temp_qpc.snd_wqe_base_l,
                    temp_qpc.snd_wqe_len,
                    temp_qpc.last_acked_psn
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    temp_qpc.ssn,
                    temp_qpc.rnr_nextrecvpsn,
                    temp_qpc.ra_buff_indx,
                    temp_qpc.cqn_rcv,
                    temp_qpc.rcv_wqe_base_l,
                    temp_qpc.rcv_wqe_len,
                    temp_qpc.qkey,
                    temp_qpc.rmsn
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));
                temp_data = {
                    224'b0,
                    temp_qpc.rq_wqe_counter, temp_qpc.sq_wqe_counter
                };
                exp_item.data_payload.push_back(big_endian_trans(temp_data));

                
                port2scb[host_id].write(exp_item);
                `uvm_info("NOTICE", "query qp finished in ref model", UVM_LOW);
            end
            `CMD_SW2HW_CQ: begin
                cqc[host_id].push_back(cfg_item.cq_ctx);
                send_read_mbx_req(host_id, 16, cfg_item.rq_tag);
                `uvm_info("NOTICE", "sw2hw cq finished in ref model", UVM_LOW);
            end
        endcase
    endtask: process_cfg_item

    task send_read_mbx_req(int host_id, bit [10:0] dword_cnt, bit [7:0] tag);
        hca_pcie_item exp_item;
        exp_item = hca_pcie_item::type_id::create("exp_item", this);
        exp_item.rq_addr = `INBOX_ADDR;
        exp_item.rq_addr_type = 0;
        exp_item.rq_dword_count = dword_cnt;
        exp_item.rq_req_type = MEM_RD;
        exp_item.rq_poisoned_req = 0;
        exp_item.rq_requester_device = 0; // ?
        exp_item.rq_requester_bus = 0;
        exp_item.rq_tag = tag;
        exp_item.rq_completer_device = 0;
        exp_item.rq_completer_bus = 0;
        exp_item.rq_requester_id_en = 0;
        exp_item.rq_tc = 0;
        exp_item.rq_attr = 0;
        exp_item.rq_force_ecrc = 0;
        port2scb[host_id].write(exp_item);
    endtask: send_read_mbx_req

    task process_db(bit [10:0] proc_id, int host_id, doorbell db);
        wqe temp_wqe;
        // temp_wqe = get_wqe_db(db);
        int flag;
        // qp_context qp_ctx;
        hca_queue_pair qp;
        mpt sq_mpt;
        // hca_pcie_item exp_item;
        wqe no_use_wqe;

        // look for qp context, do not need to send memory request
        flag = 0;
        for (int i = 0; i < q_list.qp_list.size(); i++) begin
            if (q_list.qp_list[host_id][i].ctx.local_qpn == db.qp_num) begin
                flag = 1;
                qp = q_list.qp_list[host_id][i];
                break;
            end
        end
        if (flag == 0) begin
            `uvm_fatal("NO_QPC", $sformatf("No qp context found in reference model! db.qpn: %h", db.qp_num));
        end
        `uvm_info("NOTICE", $sformatf("QP context found! QP number: %h", db.qp_num), UVM_LOW);

        // look for wqe, need to send memory request
        // look for sq mpt
        flag = 0;
        for (int i = 0; i < mem_info.mem_region[host_id].size(); i++) begin
            if (mem_info.mem_region[host_id][i].key == qp.ctx.snd_wqe_base_l) begin
                sq_mpt = mem_info.mem_region[host_id][i];
                flag = 1;
                break;
            end
        end
        if (flag == 0) begin
            `uvm_fatal("NO_MPT", "No send mpt item found in reference model!");
        end
        if (sq_mpt.pd != qp.ctx.pd) begin
            `uvm_fatal("ILLEGAL_MR_ACCESS", $sformatf("Different pd between qp and mpt! qp pd: %h, mpt pd: %h", qp.ctx.pd, sq_mpt.pd));
        end
        else begin
            `uvm_info("NOTICE", $sformatf("PD match! PD: %h", qp.ctx.pd), UVM_LOW);
        end
        `uvm_info("NOTICE", $sformatf("SQ MPT found! key: %h", qp.ctx.snd_wqe_base_l), UVM_LOW);
        // send memory read request
        
        // get wqe
        temp_wqe = get_wqe(proc_id, host_id, 1, db, no_use_wqe, qp);
        // process_wqe(proc_id, host_id, qp, db.opcode, temp_wqe, db.sq_head);
        send_cqe(proc_id, host_id, qp);
    endtask: process_db

    function wqe get_wqe(bit [10:0] proc_id, int host_id, int source_type, doorbell db = 0, wqe prev_wqe = 0, hca_queue_pair qp); // source_type: 1 - doorbell
                                                                                                                                  //              2 - previous WQE
                                                                                                                                  //              3 - RQ
        // 1: send memory read request to scoreboard
        // 2: get wqe from q_list.qp_list
        wqe result_wqe;
        addr snd_wqe_phys_addr;
        hca_pcie_item exp_item;
        addr desc_byte_len;
        addr recv_wqe_phys_addr;

        if (source_type == 1) begin
            // snd_wqe_phys_addr = {5'b0, proc_id, 14'h1, qp.ctx.local_qpn[13:0], 20'h0} + db.sq_head;
            snd_wqe_phys_addr = `PA_QP(proc_id, qp.ctx.local_qpn) + db.sq_head;
        end
        else if (source_type == 2) begin
            // snd_wqe_phys_addr = {5'b0, proc_id, 14'h1, qp.ctx.local_qpn[13:0], 20'h0} + prev_wqe.next_seg.next_wqe;
            snd_wqe_phys_addr = `PA_QP(proc_id, qp.ctx.local_qpn) + prev_wqe.next_seg.next_wqe;
        end
        else begin
            // recv_wqe_phys_addr = {5'b0, proc_id, 14'h1, qp.ctx.local_qpn[13:0], 20'h0} + `SQ_RQ_GAP + qp.sq_tail;
            snd_wqe_phys_addr = `PA_QP(proc_id, qp.ctx.local_qpn) + `SQ_RQ_GAP + qp.sq_tail;
        end
        
        exp_item = hca_pcie_item::type_id::create("exp_item", this);
        exp_item.rq_addr = snd_wqe_phys_addr;
        exp_item.rq_addr_type = 0;

        // The size of WQE does not exceed the least value of the maximum payload size or read request size of PCIe packet(128B).
        if (source_type == 1) begin
            exp_item.rq_dword_count = db.size0 * 4;
        end
        else if (source_type == 2) begin
            exp_item.rq_dword_count = prev_wqe.next_seg.next_wqe_size * 4;
        end
        else begin
             exp_item.rq_dword_count = `RQ_WQE_BYTE_LEN / 4;
        end
        
        exp_item.rq_req_type = MEM_RD;
        exp_item.rq_poisoned_req = 0;
        exp_item.rq_requester_device = 0; // ?
        exp_item.rq_requester_bus = 0;
        // exp_item.rq_tag = cfg_item.rq_tag;
        exp_item.rq_tag = 0; // how to set tag?
        exp_item.rq_completer_device = 0;
        exp_item.rq_completer_bus = 0;
        exp_item.rq_requester_id_en = 0;
        exp_item.rq_tc = 0;
        exp_item.rq_attr = 0;
        exp_item.rq_force_ecrc = 0;
        port2scb[host_id].write(exp_item);
        `uvm_info("NOTICE", "ref model to scb sent finished!", UVM_LOW);

        if (source_type == 3) begin // RQ
            `uvm_info("NOTICE", $sformatf("wqe_list.size = %0d!", qp.rq.size()), UVM_LOW);
            result_wqe = qp.rq.pop_front();
            desc_byte_len = 0;
            desc_byte_len[qp.ctx.rq_entry_sz_log] = 1'b1;
            qp.rq_tail += desc_byte_len;
            `uvm_info("NOTICE", $sformatf("wqe get from wqe_list! raddr_seg.raddr: %h", result_wqe.raddr_seg.raddr), UVM_LOW);
        end
        else begin // SQ
            `uvm_info("NOTICE", $sformatf("wqe_list.size = %0d!", qp.sq.size()), UVM_LOW);
            result_wqe = qp.sq.pop_front();
            desc_byte_len = 0;
            desc_byte_len[qp.ctx.sq_entry_sz_log] = 1'b1;
            qp.sq_tail += desc_byte_len;
            `uvm_info("NOTICE", $sformatf("wqe get from wqe_list! raddr_seg.raddr: %h", result_wqe.raddr_seg.raddr), UVM_LOW);
        end
        return result_wqe;
    endfunction: get_wqe
    
    task send_cqe(bit [10:0] proc_id, int host_id, hca_queue_pair qp);
        cqe cqe_to_send;

        // send cqe to cq_list

        // send cqe to scoreboard

        
    endtask: send_cqe

    task send2scb(bit [10:0] proc_id, int host_id, int req_type, bit [31:0] byte_cnt, addr req_phys_addr, bit [255:0] data[$]); // type: 1 - read, 2 - write
        int item_num;
        int read_offset;
        hca_pcie_item exp_item;
        
        if (req_type == 1) begin
            
        end
        else if (req_type == 2) begin
            // send read requests
            if (byte_cnt % max_read_req_size == 0) begin
                item_num = byte_cnt / max_read_req_size;
            end
            else begin
                item_num = byte_cnt / max_read_req_size + 1;
            end
            read_offset = 0;
            for (int i = 0; i < item_num; i++) begin
                exp_item = hca_pcie_item::type_id::create($sformatf("read_req_item[%0d]", i), this);

                exp_item.rq_addr = req_phys_addr + read_offset;
                exp_item.rq_addr_type = 0;
                if (read_offset + max_read_req_size <= byte_cnt) begin
                    exp_item.rq_dword_count = max_read_req_size / 4;
                end
                else begin
                    // byte_cnt % max_read_req_size
                    if (byte_cnt % max_read_req_size % 4 == 0) begin
                        exp_item.rq_dword_count = byte_cnt / max_read_req_size;
                    end
                    else begin
                        exp_item.rq_dword_count = byte_cnt / max_read_req_size + 1;
                    end
                end
                
                exp_item.rq_req_type = MEM_RD;
                exp_item.rq_poisoned_req = 0;
                exp_item.rq_requester_device = 0; // ?
                exp_item.rq_requester_bus = 0;
                // exp_item.rq_tag = cfg_item.rq_tag;
                exp_item.rq_tag = 0; // how to set tag?
                exp_item.rq_completer_device = 0;
                exp_item.rq_completer_bus = 0;
                exp_item.rq_requester_id_en = 0;
                exp_item.rq_tc = 0;
                exp_item.rq_attr = 0;
                exp_item.rq_force_ecrc = 0;
                port2scb[host_id].write(exp_item);
                `uvm_info("NOTICE", "ref model to scb sent finished!", UVM_LOW);
            end
        end
    endtask: send2scb

    // task process_wqe(bit [10:0] proc_id, int host_id, hca_queue_pair qp, bit [4:0] opcode, wqe temp_wqe, bit [31:0] wqe_offset);
    //     hca_pcie_item exp_item;
    //     int rd_req_num;
    //     int wr_req_num;
    //     int read_offset;
    //     int write_offset;
    //     hca_comp_queue send_cq;
    //     hca_comp_queue recv_cq;
    //     cqe temp_cqe;
    //     // int flag;
    //     hca_fifo #(`MEM_LINE_SIZE) data_fifo;
    //     bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] push_data;
    //     data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");

    //     send_cq = find_cq(host_id, qp.ctx.cqn_snd);
    //     recv_cq = find_cq(host_id, qp.ctx.cqn_rcv);
    //     if (opcode == `VERBS_RDMA_WRITE) begin
    //         // send read requests
    //         if (temp_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size;
    //         end
    //         else begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size + 1;
    //         end

    //         read_offset = 0;
    //         for (int i = 0; i < rd_req_num; i++) begin
    //             exp_item = hca_pcie_item::type_id::create($sformatf("read_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, temp_wqe.data_seg.addr[47:0]} + read_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (read_offset + max_read_req_size <= temp_wqe.data_seg.byte_count) begin
    //                 exp_item.rq_dword_count = max_read_req_size / 4;
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_read_req_size
    //                 if (temp_wqe.data_seg.byte_count % max_read_req_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4 + 1;
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_RD;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", $sformatf("ref model to scb data read request sent in RDMA WRITE finished!\nrq_addr: %h", exp_item.rq_addr), UVM_LOW);
    //             read_offset += max_read_req_size;
    //         end

    //         // read data
    //         data_fifo = mem[host_id].read_block({5'b0, proc_id, temp_wqe.data_seg.addr[47:0]}, temp_wqe.data_seg.byte_count);

    //         // send cqe
    //         temp_cqe.my_qpn = qp.ctx.local_qpn;
    //         temp_cqe.rqpn = qp.ctx.remote_qpn;
    //         temp_cqe.rlid = qp.ctx.dmac[15:0];
    //         temp_cqe.imm_etype_pkey_eec = 0;
    //         temp_cqe.byte_cnt = temp_wqe.data_seg.byte_count;
    //         temp_cqe.wqe = wqe_offset;
    //         temp_cqe.opcode = `VERBS_RDMA_WRITE;
    //         temp_cqe.is_send = 1;
    //         temp_cqe.owner = `CQE_OWNER_SW;
    //         // temp_cqe.rlid = 0;
    //         exp_item = hca_pcie_item::type_id::create($sformatf("cq_item"));
    //         // exp_item.rq_addr = {5'b0, proc_id, 19'b1, send_cq.ctx.cqn, 16'b0} + send_cq.header;
    //         exp_item.rq_addr = `PA_CQ(proc_id, send_cq.ctx.cqn) + send_cq.header;
    //         exp_item.is_cq = TRUE;            
    //         exp_item.rq_addr_type = 0;
    //         exp_item.rq_dword_count = 8;
    //         exp_item.rq_req_type = MEM_WR;
    //         exp_item.rq_poisoned_req = 0;
    //         exp_item.rq_requester_device = 0; // ?
    //         exp_item.rq_requester_bus = 0;
    //         // exp_item.rq_tag = cfg_item.rq_tag;
    //         exp_item.rq_tag = 0; // how to set tag?
    //         exp_item.rq_completer_device = 0;
    //         exp_item.rq_completer_bus = 0;
    //         exp_item.rq_requester_id_en = 0;
    //         exp_item.rq_tc = 0;
    //         exp_item.rq_attr = 0;
    //         exp_item.rq_force_ecrc = 0;
    //         exp_item.data_payload.push_back({temp_cqe.owner, 8'b0, temp_cqe.is_send, temp_cqe.opcode,
    //                                          temp_cqe.wqe,
    //                                          temp_cqe.byte_cnt,
    //                                          temp_cqe.imm_etype_pkey_eec,
    //                                          temp_cqe.rlid, temp_cqe.g_mlpath, temp_cqe.sl_ipok,
    //                                          temp_cqe.rqpn,
    //                                          temp_cqe.my_ee,
    //                                          temp_cqe.my_qpn});
    //         port2scb[host_id].write(exp_item);
    //         send_cq.cqe_list.push_back(temp_cqe);
    //         `uvm_info("CQE_NOTICE", $sformatf("RM send CQE, ref cqe remaining: %0d!", send_cq.cqe_list.size()), UVM_LOW);
    //         send_cq.header += `CQE_SIZE;

    //         // send write requests
    //         if (temp_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             wr_req_num = temp_wqe.data_seg.byte_count / max_payload_size;
    //         end
    //         else begin
    //             wr_req_num = temp_wqe.data_seg.byte_count / max_payload_size + 1;
    //         end

    //         write_offset = 0;
    //         for (int i = 0; i < wr_req_num; i++) begin
    //             exp_item = hca_pcie_item::type_id::create($sformatf("write_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, temp_wqe.raddr_seg.raddr[47:0]} + write_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (write_offset + max_payload_size <= temp_wqe.data_seg.byte_count) begin // is not the last item
    //                 exp_item.rq_dword_count = max_payload_size / 4;

    //                 for (int j = 0; j < max_payload_size / 32; j++) begin
    //                     exp_item.data_payload.push_back(data_fifo.pop());
    //                 end
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_payload_size
    //                 if (temp_wqe.data_seg.byte_count % max_payload_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_payload_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_payload_size / 4 + 1;
    //                 end
    //                 while (data_fifo.get_depth() != 0) begin
    //                     exp_item.data_payload.push_back(data_fifo.pop());
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_WR;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
                
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", "ref model to scb sent finished!", UVM_LOW);
    //             write_offset += max_payload_size;
    //         end
    //     end
    //     else if (opcode == `VERBS_RDMA_READ) begin
    //         wqe recv_wqe;
    //         // send read requests
    //         if (temp_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size;
    //         end
    //         else begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size + 1;
    //         end

    //         read_offset = 0;
    //         for (int i = 0; i < rd_req_num; i++) begin
    //             exp_item = hca_pcie_item::type_id::create($sformatf("read_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, temp_wqe.raddr_seg.raddr[47:0]} + read_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (read_offset + max_read_req_size <= temp_wqe.data_seg.byte_count) begin
    //                 exp_item.rq_dword_count = max_read_req_size / 4;
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_read_req_size
    //                 if (temp_wqe.data_seg.byte_count % max_read_req_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4 + 1;
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_RD;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", $sformatf("ref model to scb data read request sent in RDMA READ finished!\nrq_addr: %h", exp_item.rq_addr), UVM_LOW);
    //             read_offset += max_read_req_size;
    //         end

    //         // read data
    //         data_fifo = mem[host_id].read_block({5'b0, proc_id, temp_wqe.raddr_seg.raddr[47:0]}, temp_wqe.data_seg.byte_count);

    //         // send write requests
    //         if (temp_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             wr_req_num = temp_wqe.data_seg.byte_count / max_payload_size;
    //         end
    //         else begin
    //             wr_req_num = temp_wqe.data_seg.byte_count / max_payload_size + 1;
    //         end

    //         write_offset = 0;
    //         for (int i = 0; i < wr_req_num; i++) begin
    //             exp_item = hca_pcie_item::type_id::create($sformatf("write_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, temp_wqe.data_seg.addr[47:0]} + write_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (write_offset + max_payload_size <= temp_wqe.data_seg.byte_count) begin
    //                 exp_item.rq_dword_count = max_payload_size / 4;
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_payload_size
    //                 if (temp_wqe.data_seg.byte_count % max_payload_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_payload_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_payload_size / 4 + 1;
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_WR;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
                
    //             // push data
    //             while (data_fifo.get_depth() != 0) begin
    //                 exp_item.data_payload.push_back(data_fifo.pop());
    //             end
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", "ref model to scb sent finished!", UVM_LOW);
    //             write_offset += max_payload_size;
    //         end

    //         // send cqe
    //         temp_cqe.my_qpn = qp.ctx.local_qpn;
    //         temp_cqe.rqpn = qp.ctx.remote_qpn;
    //         temp_cqe.rlid = qp.ctx.dmac[15:0];
    //         temp_cqe.imm_etype_pkey_eec = 0;
    //         temp_cqe.byte_cnt = temp_wqe.data_seg.byte_count;
    //         temp_cqe.wqe = wqe_offset;
    //         temp_cqe.opcode = `VERBS_RDMA_READ;
    //         temp_cqe.is_send = 1;
    //         temp_cqe.owner = `CQE_OWNER_SW;
    //         // temp_cqe.rlid = 0;
    //         exp_item = hca_pcie_item::type_id::create($sformatf("cq_item"));
    //         // exp_item.rq_addr = {5'b0, proc_id, 19'b1, send_cq.ctx.cqn, 16'b0} + send_cq.header;
    //         exp_item.rq_addr = `PA_CQ(proc_id, send_cq.ctx.cqn) + send_cq.header;
    //         exp_item.is_cq = TRUE;            
    //         exp_item.rq_addr_type = 0;
    //         exp_item.rq_dword_count = 8;
    //         exp_item.rq_req_type = MEM_WR;
    //         exp_item.rq_poisoned_req = 0;
    //         exp_item.rq_requester_device = 0; // ?
    //         exp_item.rq_requester_bus = 0;
    //         // exp_item.rq_tag = cfg_item.rq_tag;
    //         exp_item.rq_tag = 0; // how to set tag?
    //         exp_item.rq_completer_device = 0;
    //         exp_item.rq_completer_bus = 0;
    //         exp_item.rq_requester_id_en = 0;
    //         exp_item.rq_tc = 0;
    //         exp_item.rq_attr = 0;
    //         exp_item.rq_force_ecrc = 0;
    //         exp_item.data_payload.push_back({temp_cqe.owner, 8'b0, temp_cqe.is_send, temp_cqe.opcode,
    //                                          temp_cqe.wqe,
    //                                          temp_cqe.byte_cnt,
    //                                          temp_cqe.imm_etype_pkey_eec,
    //                                          temp_cqe.rlid, temp_cqe.g_mlpath, temp_cqe.sl_ipok,
    //                                          temp_cqe.rqpn,
    //                                          temp_cqe.my_ee,
    //                                          temp_cqe.my_qpn});
    //         port2scb[host_id].write(exp_item);
    //         send_cq.cqe_list.push_back(temp_cqe);
    //         send_cq.header += `CQE_SIZE;
    //     end
    //     else if (opcode == `VERBS_SEND) begin
    //         wqe recv_wqe;
    //         wqe no_use_wqe;
    //         doorbell no_use_db;
    //         // send read requests
    //         if (temp_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size;
    //         end
    //         else begin
    //             rd_req_num = temp_wqe.data_seg.byte_count / max_read_req_size + 1;
    //         end

    //         read_offset = 0;
    //         for (int i = 0; i < rd_req_num; i++) begin

    //             exp_item = hca_pcie_item::type_id::create($sformatf("read_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, temp_wqe.raddr_seg.raddr[47:0]} + read_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (read_offset + max_read_req_size <= temp_wqe.data_seg.byte_count) begin
    //                 exp_item.rq_dword_count = max_read_req_size / 4;
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_read_req_size
    //                 if (temp_wqe.data_seg.byte_count % max_read_req_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = temp_wqe.data_seg.byte_count % max_read_req_size / 4 + 1;
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_RD;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", $sformatf("ref model to scb data read request sent in RDMA READ finished!\nrq_addr: %h", exp_item.rq_addr), UVM_LOW);
    //             read_offset += max_read_req_size;
    //         end

    //         // read data
    //         data_fifo.clean();
    //         data_fifo = mem[host_id].read_block({5'b0, proc_id, temp_wqe.raddr_seg.raddr[47:0]}, temp_wqe.data_seg.byte_count);

    //         // get recv wqe
    //         recv_wqe = get_wqe(proc_id, host_id, 3, no_use_db, no_use_wqe, qp);

    //         // send write request
    //         if (recv_wqe.data_seg.byte_count % max_read_req_size == 0) begin
    //             wr_req_num = recv_wqe.data_seg.byte_count / max_payload_size;
    //         end
    //         else begin
    //             wr_req_num = recv_wqe.data_seg.byte_count / max_payload_size + 1;
    //         end

    //         write_offset = 0;
    //         for (int i = 0; i < wr_req_num; i++) begin
    //             exp_item = hca_pcie_item::type_id::create($sformatf("write_req_item[%0d]", i), this);

    //             exp_item.rq_addr = {5'b0, proc_id, recv_wqe.data_seg.addr[47:0]} + write_offset;
    //             exp_item.rq_addr_type = 0;
    //             if (write_offset + max_payload_size <= recv_wqe.data_seg.byte_count) begin
    //                 exp_item.rq_dword_count = max_payload_size / 4;
    //             end
    //             else begin
    //                 // temp_wqe.data_seg.byte_count % max_payload_size
    //                 if (recv_wqe.data_seg.byte_count % max_payload_size % 4 == 0) begin
    //                     exp_item.rq_dword_count = recv_wqe.data_seg.byte_count % max_payload_size / 4;
    //                 end
    //                 else begin
    //                     exp_item.rq_dword_count = recv_wqe.data_seg.byte_count % max_payload_size / 4 + 1;
    //                 end
    //             end
                
    //             exp_item.rq_req_type = MEM_WR;
    //             exp_item.rq_poisoned_req = 0;
    //             exp_item.rq_requester_device = 0; // ?
    //             exp_item.rq_requester_bus = 0;
    //             // exp_item.rq_tag = cfg_item.rq_tag;
    //             exp_item.rq_tag = 0; // how to set tag?
    //             exp_item.rq_completer_device = 0;
    //             exp_item.rq_completer_bus = 0;
    //             exp_item.rq_requester_id_en = 0;
    //             exp_item.rq_tc = 0;
    //             exp_item.rq_attr = 0;
    //             exp_item.rq_force_ecrc = 0;
                
    //             // push data
    //             while (data_fifo.get_depth() != 0) begin
    //                 exp_item.data_payload.push_back(data_fifo.pop());
    //             end
    //             port2scb[host_id].write(exp_item);
    //             `uvm_info("NOTICE", "ref model to scb sent finished!", UVM_LOW);
    //             write_offset += max_payload_size;
    //         end
    //     end
    // endtask: process_wqe

    function hca_comp_queue find_cq(int host_id, bit [31:0] cqn);
        hca_comp_queue cq;
        int flag;
        flag = 0;
        for (int i = 0; i < q_list.cq_list[host_id].size(); i++) begin
            if (q_list.cq_list[host_id][i].ctx.cqn == cqn) begin
                flag = 1;
                cq = q_list.cq_list[host_id][i];
                break;
            end
        end
        if (flag == 0) begin
            `uvm_fatal("OBJ_NOT_FOUND", "CQ not found in q_list.cq_list in RM!");
        end
        return cq;
    endfunction: find_cq

    //------------------------------------------------------------------------------
    // function name : big_endian_trans
    // function      : transform data between big endian and little endian.
    // invoked       : by process_cfg_item()
    //------------------------------------------------------------------------------
    function bit [255:0] big_endian_trans(bit [255:0] data);
        bit [255:0] result;
        for (int i = 0; i < 255; i += 8) begin
            result[i +: 8] = data[255 - i -: 8];
        end
        return result;
    endfunction: big_endian_trans

    task listen_inbox(hca_pcie_item item, int host_num); // no need for this task/
        bit [255:0] temp_data;
        // cfg_resp_fifo[host_num].get(cfg_resp_fifo_item[host_num]);
        // case (item.hcr_op)
        //     `CMD_INIT_HCA: begin
        //         cfg_resp_fifo[host_num].get(cfg_resp_fifo_item[host_num]);
        //         temp_data = big_endian_trans(cfg_resp_fifo_item[host_num].data_payload.pop_front());
        //         icm_base_addr[host_num].qpc_base      = {temp_data[191:136], 8'b0};
        //         icm_base_addr[host_num].log_num_qps   = temp_data[135:128];
        //         icm_base_addr[host_num].cqc_base      = {temp_data[127:72], 8'b0};
        //         icm_base_addr[host_num].log_num_cqs   = temp_data[71:64];
        //         icm_base_addr[host_num].eqc_base      = {temp_data[63:8], 8'b0};
        //         icm_base_addr[host_num].log_num_eqs   = temp_data[7:0];
        //         temp_data = big_endian_trans(cfg_resp_fifo_item[host_num].data_payload.pop_front());
        //         icm_base_addr[host_num].mtt_base      = temp_data[63:0];
        //         icm_base_addr[host_num].log_mpt_sz    = temp_data[71:64];
        //         icm_base_addr[host_num].mpt_base      = {temp_data[127:72], 8'b0};
        //         if (cfg_resp_fifo_item[host_num].data_payload.size != 0) begin
        //             `uvm_fatal("PAYLOAD_LENGTH_ERROR", "data_payload length error in reference model!");
        //         end
        //     end
        //     `CMD_MAP_ICM: begin
        //         // only support one page
        //         cfg_resp_fifo[host_num].get(cfg_resp_fifo_item[host_num]);
        //         temp_data = big_endian_trans(cfg_resp_fifo_item[host_num].data_payload.pop_front());
        //         if (item.map_type == 1) begin
        //             qpc_virt_addr[host_num].push_back(temp_data[127:64]);
        //         end
        //         else if (item.map_type == 2) begin
        //             cqc_virt_addr[host_num].push_back(temp_data[127:64]);
        //         end
        //         else if (item.map_type == 3) begin
        //             mpt_virt_addr[host_num].push_back(temp_data[127:64]);
        //         end
        //         else if (item.map_type == 4) begin
        //             mtt_virt_addr[host_num].push_back(temp_data[127:64]);
        //         end
        //         else begin
        //             `uvm_fatal("MAP_TYPE_ERROR", "map_type illegal in reference model!");
        //         end
        //     end
        //     `CMD_WRITE_MTT: begin
        //         // only support one page
        //         mtt temp_mtt_item;
        //         cfg_resp_fifo[host_num].get(cfg_resp_fifo_item[host_num]);
        //         temp_data = big_endian_trans(cfg_resp_fifo_item[host_num].data_payload.pop_front());
        //         temp_mtt_item.start_index = temp_data[63:0];
        //         temp_data = big_endian_trans(cfg_resp_fifo_item[host_num].data_payload.pop_front());
        //         temp_mtt_item.phys_addr.push_back(temp_data[63:0]);
        //     end
        //     `CMD_SW2HW_MPT: begin
        //         cfg_resp_fifo[host_num].get(cfg_resp_fifo_item[host_num]);
        //     end
        //     default: begin
                
        //     end
        // endcase
    endtask: listen_inbox
endclass: hca_ref_model
`endif