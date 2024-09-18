//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-07-13
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_test.sv
//  FUNCTION : This file supplies the case for testing configuration of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-07-13    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __HCA_TEST__
`define __HCA_TEST__

//------------------------------------------------------------------------------
//
// CLASS: hca_test
//
//------------------------------------------------------------------------------
class hca_test extends uvm_test;
    string seq_name;
    hca_env env;
    hca_vsequence vseq;
    hca_pcie_item pcie_item;
    hca_fifo #(.width(256)) data_fifo;
    bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    int host_num = 1;

    bit      [`ADDR_WIDTH - 1 : 0] qpc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] cqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mpt_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mtt_virt_addr[][$];

    bit      [`ADDR_WIDTH - 1 : 0] data_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] data_phys_addr[][$];

    `uvm_component_utils(test_config)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_config", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates env and sequence.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        qpc_virt_addr = new[host_num];
        cqc_virt_addr = new[host_num];
        mpt_virt_addr = new[host_num];
        mtt_virt_addr = new[host_num];
        data_phys_addr = new[host_num];
        env = hca_env::type_id::create("env", this);
        vseq = hca_vsequence::type_id::create("vseq", this);
        if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
            `uvm_warning("test_config", "SEQ_NAME NOT GET!")
        end
        data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // function name : connect_phase
    // function      : connect_phase in uvm library, connect mem in env with in seq
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        string test_name;
        super.connect_phase(phase);
        for (int i = 0; i < host_num; i++) begin
            vseq.cfg_seq[i].mem = env.mem[i];
        end
    endfunction: connect_phase

    //------------------------------------------------------------------------------
    // task name     : main_phase
    // function      : main_phase in uvm library, start vseq.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    task main_phase(uvm_phase phase);
        // super.main_phase(phase);
        phase.raise_objection(this);
        gen_item();
        `uvm_info("NOTICE", "generate item finished!", UVM_LOW)
        vseq.starting_phase = phase;
        for (int i = 0; i < host_num; i++) begin
            vseq.cfg_seq[i].mem = env.mem[i];
            vseq.slv_seq[i].mem = env.mem[i];
        end
        vseq.start(env.vsqr, , , 1);
        `uvm_info("NOTICE", "vseq finished!", UVM_LOW)
        phase.drop_objection(this);
    endtask: main_phase

    //------------------------------------------------------------------------------
    // task name     : gen_item
    // function      : generate initial item.
    // invoked       : by build_phase
    //------------------------------------------------------------------------------
    task gen_item();
        case (seq_name)
            "test_db_seq": begin
                doorbell db;
                post_db(db);
            end
            "test_init_hca_seq": begin
                init_hca();
            end
            "test_close_hca_seq": begin
                init_hca();
                close_hca();
            end
            "test_query_adapter_seq": begin
                query_adapter();
            end
            "test_query_dev_lim_seq": begin
                query_dev_lim();
            end
            "test_query_dev_info_seq": begin
                query_dev_lim();
                query_adapter();
                init_hca();
            end
            "test_map_icm_seq": begin
                init_hca();
                map_icm(1);
                map_icm(2);
                map_icm(3);
                map_icm(4);
            end
            "test_unmap_icm_seq": begin
                pcie_item.randomize() with {hcr_op == `CMD_UNMAP_ICM;};
            end
            "test_hw2sw_cq_seq": begin
                pcie_item.randomize() with {hcr_op == `CMD_HW2SW_CQ;};
            end
            "test_sw2hw_cq_seq": begin
                pcie_item.randomize() with {hcr_op == `CMD_SW2HW_CQ;};
            end
            "test_modify_qp_seq": begin
                qp_context qp_ctx;
                init_hca();
                map_icm(1); // map icm space for qp
                modify_qp(create_qpc());
                query_qp(2);
            end
            // "test_modify_qp_rst_seq": begin
                
            // end
            // "test_resize_cq_seq": begin
            //     pcie_item.randomize() with {hcr_op == `CMD_RESIZE_CQ;};
            // end
            // "test_hw2sw_mpt_seq": begin
            //     pcie_item.randomize() with {hcr_op == `CMD_HW2SW_MPT;};
            // end
            // "test_sw2hw_mpt_seq": begin
            //     pcie_item.randomize() with {hcr_op == `CMD_SW2HW_MPT;};
            // end
            // "test_write_mtt_seq": begin
            //     write_mtt();
            // end
            // "test_full_cmd_seq": begin
            //     init_hca();

            // end
            "test_comm_seq": begin
                simple_comm();
            end
        endcase
    endtask: gen_item

    task init_hca();
        hca_pcie_item init_hca_item;
        init_hca_item = hca_pcie_item::type_id::create("init_hca_item", this);
        init_hca_item.randomize() with {hcr_op == `CMD_INIT_HCA;};
        init_hca_item.icm_base_struct.qpc_base          = `QPC_OFFSET;
        init_hca_item.icm_base_struct.cqc_base          = `CQC_OFFSET;
        init_hca_item.icm_base_struct.mpt_base          = `MPT_OFFSET;
        init_hca_item.icm_base_struct.mtt_base          = `MTT_OFFSET;
        init_hca_item.icm_base_struct.log_num_qps       = `LOG_NUM_QPS;
        init_hca_item.icm_base_struct.log_num_cqs       = `LOG_NUM_CQS;
        init_hca_item.icm_base_struct.log_mpt_sz        = `LOG_MPT_SZ;
        vseq.cfg_item_que[0].push_back(init_hca_item);
    endtask: init_hca

    function bit [63:0] map_icm(int m_type); // m_type: 1: qp context; 2: cq context; 3: mpt; 4: mtt;
                                             // return the virtual address of the mapped page in ICM space;
                                             // currently support only one page
        hca_pcie_item map_icm_item;
        bit [63:0] temp_virt_addr;
        bit [63:0] temp_phys_addr;
        int i;
        bit flag = 0;

        if (m_type == 1) begin
            temp_virt_addr = `QPC_OFFSET;
            foreach (qpc_virt_addr[0][i]) begin
                if (qpc_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += 4096;
                end
                else begin
                    qpc_virt_addr[0].insert(i, temp_virt_addr);
                    flag = 1;
                    break;
                end
            end
            if (flag == 0) begin
                qpc_virt_addr[0].push_back(temp_virt_addr);
            end
        end
        else if (m_type == 2) begin
            temp_virt_addr = `CQC_OFFSET;
            foreach (cqc_virt_addr[0][i]) begin
                if (cqc_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += 4096;
                end
                else begin
                    cqc_virt_addr[0].insert(i, temp_virt_addr);
                    flag = 1;
                    break;
                end
            end
            if (flag == 0) begin
                cqc_virt_addr[0].push_back(temp_virt_addr);
            end
        end
        else if (m_type == 3) begin
            temp_virt_addr = `MPT_OFFSET;
            foreach (mpt_virt_addr[0][i]) begin
                if (mpt_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += 4096;
                end
                else begin
                    mpt_virt_addr[0].insert(i, temp_virt_addr);
                    flag = 1;
                    break;
                end
            end
            if (flag == 0) begin
                mpt_virt_addr[0].push_back(temp_virt_addr);
            end
        end
        else if (m_type == 4) begin
            temp_virt_addr = `MTT_OFFSET;
            foreach (mtt_virt_addr[0][i]) begin
                if (mtt_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += 4096;
                end
                else begin
                    mtt_virt_addr[0].insert(i, temp_virt_addr);
                    flag = 1;
                    break;
                end
            end
            if (flag == 0) begin
                mtt_virt_addr[0].push_back(temp_virt_addr);
            end
        end
        else begin
            `uvm_fatal("ILG_INPUT", "illegal m_type in map_icm!");
        end

        map_icm_item = hca_pcie_item::type_id::create("map_icm_item", this);
        map_icm_item.randomize() with {hcr_op == `CMD_MAP_ICM; map_type == m_type;};
        map_icm_item.icm_addr_map.virt.push_back(temp_virt_addr);
        map_icm_item.icm_addr_map.page.push_back(temp_virt_addr + `ICM_BASE);
        map_icm_item.icm_addr_map.page_num = 1;
        vseq.cfg_item_que[0].push_back(map_icm_item);
        return temp_virt_addr;
    endfunction: map_icm

    //------------------------------------------------------------------------------
    // task name     : modify_qp
    // function      : generate and send modify qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task modify_qp(qp_context qp_ctx);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_RST2INIT_QPEE;};// qp_num == 2;};
        pcie_item.qp_ctx = qp_ctx;
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: modify_qp

    //------------------------------------------------------------------------------
    // task name     : query_qp
    // function      : generate and send query qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_qp(int qpn);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_QUERY_QP; qp_num == qpn;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_qp

    //------------------------------------------------------------------------------
    // func name     : create_qp
    // function      : create a queue pair and return the context
    // invoked       : by modify_qp
    //------------------------------------------------------------------------------
    function qp_context create_qpc();
        qp_context qp_ctx;
        qp_ctx.opt_param_mask           = 1; // modify
        qp_ctx.flags                    = 2;
        qp_ctx.mtu_msgmax               = 3;
        qp_ctx.rq_size_stride           = 4;
        qp_ctx.sq_size_stride           = 5;
        qp_ctx.rlkey_arbel_sched_queue  = 6;
        qp_ctx.usr_page                 = 7;
        qp_ctx.local_qpn                = 2;
        qp_ctx.remote_qpn               = 2;
        qp_ctx.port_pkey                = 2;
        qp_ctx.rnr_retry                = 3;
        qp_ctx.g_mylmc                  = 4;
        qp_ctx.rlid                     = 5;
        qp_ctx.ackto                    = 6;
        qp_ctx.mgid_index               = 7;
        qp_ctx.static_rate              = 8;
        qp_ctx.hop_limit                = 1;
        qp_ctx.sl_tclass_flowlabel      = 2;
        qp_ctx.rgid                     = 3;
        qp_ctx.pd                       = 4;
        qp_ctx.wqe_base                 = 5;
        qp_ctx.wqe_lkey                 = 1;
        qp_ctx.next_send_psn            = 0;
        qp_ctx.cqn_snd                  = 8;
        qp_ctx.snd_wqe_base_l           = 1;
        qp_ctx.snd_db_index             = 2;
        qp_ctx.last_acked_psn           = 3;
        qp_ctx.ssn                      = 4;
        qp_ctx.rnr_nextrecvpsn          = 5;
        qp_ctx.ra_buff_indx             = 6;
        qp_ctx.cqn_rcv                  = 7;
        qp_ctx.rcv_wqe_base_l           = 2;
        qp_ctx.rcv_db_index             = 1;
        qp_ctx.qkey                     = 2;
        qp_ctx.rmsn                     = 3;
        qp_ctx.rq_wqe_counter           = 4;
        qp_ctx.sq_wqe_counter           = 5;
        return qp_ctx;
    endfunction: create_qpc

    task write_mtt(bit [63:0] start_index); // input is the ICM virtual address of mtt item
                                            // currently not support modify mtt item
        int i;
        bit [63:0] temp = `DATA_BASE;
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_WRITE_MTT; num_mtt == 1;};
        pcie_item.mtt_item.start_index = start_index;
        foreach (data_phys_addr[0][i]) begin
            if (temp == data_phys_addr[0][i]) begin
                temp += 4096;
            end
        end
        data_phys_addr[0].push_back(temp);
        pcie_item.mtt_item.phys_addr.push_back(temp);
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: write_mtt

    task close_hca();
        `uvm_info("NOTICE", "close hca begin in test", UVM_LOW);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_CLOSE_HCA;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: close_hca

    //------------------------------------------------------------------------------
    // func name     : query_adapter
    // function      : query device id
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_adapter();
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_QUERY_ADAPTER;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_adapter

    //------------------------------------------------------------------------------
    // func name     : query_dev_lim
    // function      : query device limit information
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_dev_lim();
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_QUERY_DEV_LIM;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_dev_lim

    task sw2hw_mpt(mpt mpt_item);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_SW2HW_MPT;};
        pcie_item.mpt_item = mpt_item;
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: sw2hw_mpt

    task post_db(doorbell db);
        pcie_item = hca_pcie_item::type_id::create("db_item", this);
        pcie_item.item_type = DOORBELL;
        pcie_item.db = db;
        vseq.comm_item_que[0].push_back(pcie_item);
    endtask: post_db

    task simple_comm();
        addr data_mtt_offset;
        addr data_mpt_offset;
        addr rq_mtt_offset;
        addr rq_mpt_offset;
        addr sq_mtt_offset;
        addr sq_mpt_offset;
        addr qpc_offset;
        mpt data_mpt_item;
        mpt rq_mpt_item;
        mpt sq_mpt_item;
        mtt mtt_item;
        qp_context qp_ctx;
        doorbell db;
        wqe temp_wqe;

        init_hca();

        // create data page
        data_mtt_offset = map_icm(4); // map icm space for mtt
        write_mtt(data_mtt_offset); // allocate space for qp

        // create data protection table
        data_mpt_offset = map_icm(3);
        // write_mtt(data_mpt_offset);
        data_mpt_item.flags = 32'hffff_ffff;
        data_mpt_item.page_size = `PAGE_SIZE;
        data_mpt_item.key = 0;
        data_mpt_item.pd = 4;
        data_mpt_item.start = 0; // the start virtual address of the memory region of data
        data_mpt_item.length = `PAGE_SIZE;
        data_mpt_item.mtt_seg = data_mtt_offset - `MTT_OFFSET;
        sw2hw_mpt(data_mpt_item);

        // create qp context page
        qpc_offset = map_icm(1);

        // create rq page
        rq_mtt_offset = map_icm(4);
        write_mtt(rq_mtt_offset);
        // rq_mtt_offset = map_icm(1); // map icm space for qpc
        // write_mtt(rq_mtt_offset);

        // create rq protection talble
        rq_mpt_offset = map_icm(3);
        rq_mpt_item.flags = 32'hffff_ffff;
        rq_mpt_item.page_size = `PAGE_SIZE;
        rq_mpt_item.key = 1;
        rq_mpt_item.pd = 4;
        rq_mpt_item.start = 4096; // the start virtual address of the memory region of RQ
        rq_mpt_item.length = `PAGE_SIZE;
        rq_mpt_item.mtt_seg = rq_mtt_offset - `MTT_OFFSET;
        sw2hw_mpt(rq_mpt_item);

        // create sq page
        sq_mtt_offset = map_icm(4);
        write_mtt(sq_mtt_offset);

        // create sq protection table
        sq_mpt_offset = map_icm(3);
        sq_mpt_item.flags = 32'hffff_ffff;
        sq_mpt_item.page_size = `PAGE_SIZE;
        sq_mpt_item.key = 2;
        sq_mpt_item.pd = 4;
        sq_mpt_item.start = 8192; // the start virtual address of the memory region of SQ
        sq_mpt_item.length = `PAGE_SIZE;
        sq_mpt_item.mtt_seg = sq_mtt_offset - `MTT_OFFSET;
        sw2hw_mpt(sq_mpt_item);
        
        // write data to send
        for (int i = 0; i < 32; i++) begin
            data[i] = i;
        end
        data_fifo.push(data);
        env.mem[0].write_block(`DATA_BASE, data_fifo, 32);

        // create qp
        // qp_ctx = create_qpc();
        qp_ctx.opt_param_mask           = 1; // modify
        qp_ctx.flags                    = 2;
        qp_ctx.mtu_msgmax               = 3;
        qp_ctx.rq_size_stride           = 4;
        qp_ctx.sq_size_stride           = 5;
        qp_ctx.rlkey_arbel_sched_queue  = 6;
        qp_ctx.usr_page                 = 7;
        qp_ctx.local_qpn                = 2;
        qp_ctx.remote_qpn               = 2;
        qp_ctx.port_pkey                = 2;
        qp_ctx.rnr_retry                = 3;
        qp_ctx.g_mylmc                  = 4;
        qp_ctx.rlid                     = 5;
        qp_ctx.ackto                    = 6;
        qp_ctx.mgid_index               = 7;
        qp_ctx.static_rate              = 8;
        qp_ctx.hop_limit                = 1;
        qp_ctx.sl_tclass_flowlabel      = 2;
        qp_ctx.rgid                     = 3;
        qp_ctx.pd                       = 4;
        qp_ctx.wqe_base                 = 5;
        qp_ctx.wqe_lkey                 = 1;
        qp_ctx.next_send_psn            = 0;
        qp_ctx.cqn_snd                  = 8;
        qp_ctx.snd_wqe_base_l           = sq_mpt_item.key;
        qp_ctx.snd_db_index             = 2;
        qp_ctx.last_acked_psn           = 3;
        qp_ctx.ssn                      = 4;
        qp_ctx.rnr_nextrecvpsn          = 5;
        qp_ctx.ra_buff_indx             = 6;
        qp_ctx.cqn_rcv                  = 7;
        qp_ctx.rcv_wqe_base_l           = rq_mpt_item.key;
        qp_ctx.rcv_db_index             = 1;
        qp_ctx.qkey                     = 2;
        qp_ctx.rmsn                     = 3;
        qp_ctx.rq_wqe_counter           = 4;
        qp_ctx.sq_wqe_counter           = 5;
        
        modify_qp(qp_ctx);
        query_qp(qp_ctx.local_qpn);

        // create WQE, WRITE, non-inline
        temp_wqe.raddr_seg.raddr = 0;
        temp_wqe.raddr_seg.rkey = 0;
        // set next seg
        data[127:0] = {
            temp_wqe.next_seg.imm_data,
            {28'b0}, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, 1'b0,
            temp_wqe.next_seg.next_ee, temp_wqe.next_seg.next_dbd, temp_wqe.next_seg.next_wqe_size,
            temp_wqe.next_seg.next_wqe, 1'b0, temp_wqe.next_seg.next_opcode
        };
        // set raddr seg
        data[255:128] = {
            32'b0,
            temp_wqe.raddr_seg.rkey,
            temp_wqe.raddr_seg.raddr
        };
        data_fifo.push(data);
        data = 0;
        // set data seg
        data[127:64] = {
            temp_wqe.data_seg.addr,
            temp_wqe.data_seg.lkey,
            temp_wqe.data_seg.byte_count
        };
        data_fifo.push(data);
        env.mem[0].write_block(`DATA_BASE + 4096 * 3, data_fifo, 384);
        // send doorbell
        db.nreq = 1;
        db.sq_head = 0;
        db.f0 = 0;
        db.opcode = `VERBS_RDMA_WRITE;
        db.qp_num = 2;
        db.size0 = 24;
        post_db(db);
    endtask: simple_comm
endclass: hca_test
`endif