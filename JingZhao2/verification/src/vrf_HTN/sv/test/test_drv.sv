//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-07-28
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_drv.sv
//  FUNCTION : This file supplies the case for communication of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-07-28    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __TEST_DRV__
`define __TEST_DRV__

//------------------------------------------------------------------------------
//
// CLASS: test_drv
//
//------------------------------------------------------------------------------
class test_drv extends uvm_test;
    string seq_name;
    hca_env env;
    hca_vsequence vseq;
    hca_pcie_item pcie_item;
    hca_fifo #(.width(256)) data_fifo;
    bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    int host_num = 1;

    bit      [`ADDR_WIDTH - 1 : 0] qpc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] cqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] eqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mpt_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mtt_virt_addr[][$];

    bit      [`ADDR_WIDTH - 1 : 0] data_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] data_phys_addr[][$];

    bit      [31:0]                data_count;
    addr                           rcv_mtt_id;
    addr                           send_mtt_id;

    `uvm_component_utils(test_drv)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_drv", uvm_component parent=null);
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
        eqc_virt_addr = new[host_num];
        mpt_virt_addr = new[host_num];
        mtt_virt_addr = new[host_num];
        data_phys_addr = new[host_num];
        env = hca_env::type_id::create("env", this);
        vseq = hca_vsequence::type_id::create("vseq", this);
        if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
            `uvm_warning("test_drv", "SEQ_NAME NOT GET!")
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
            "test_drv": begin
                data_count = 32'h0000_000c;
                driver_mon();
            end
            "test_read": begin
                test_read_no_param();
            end
            "test_write_4k": begin
                data_count = 32'h0000_1000;
                test_write();
            end
            "test_temp": begin
                data_count = 32'h0000_0030;
                test_write();
            end
            "test_write_8k": begin
                data_count = 32'h0000_2000;
                test_write();
            end
        endcase
    endtask: gen_item

    task init_hca();
        hca_pcie_item init_hca_item;
        init_hca_item = hca_pcie_item::type_id::create("init_hca_item", this);
        assert (init_hca_item.randomize() with {hcr_op == `CMD_INIT_HCA;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in init hca1");
        end
        init_hca_item.icm_base_struct.qpc_base          = `QPC_OFFSET;
        init_hca_item.icm_base_struct.cqc_base          = `CQC_OFFSET;
        init_hca_item.icm_base_struct.eqc_base          = `EQC_OFFSET;
        init_hca_item.icm_base_struct.mpt_base          = `MPT_OFFSET;
        init_hca_item.icm_base_struct.mtt_base          = `MTT_OFFSET;
        init_hca_item.icm_base_struct.log_num_qps       = `LOG_NUM_QPS;
        init_hca_item.icm_base_struct.log_num_cqs       = `LOG_NUM_CQS;
        init_hca_item.icm_base_struct.log_num_eqs       = `LOG_NUM_EQS;
        init_hca_item.icm_base_struct.log_mpt_sz        = `LOG_MPT_SZ;
        vseq.cfg_item_que[0].push_back(init_hca_item);
    endtask: init_hca

    function bit [63:0] map_icm(int m_type, int page_num); // m_type: 1: qp context; 2: cq context; 3: mpt; 4: mtt;
                                             // return the virtual address of the mapped page in ICM space;
                                             // currently support only one page
        hca_pcie_item map_icm_item;
        bit [63:0] temp_virt_addr;
        bit [63:0] temp_phys_addr;
        // addr start_virt_addr;
        int i;
        bit flag = 0;
        if (page_num > 4095) begin
            `uvm_fatal("PAGE_NUM_ERROR", "illegal page_num in map_icm!");
        end
        if (m_type == `ICM_QPC_TYP) begin
            temp_virt_addr = `QPC_OFFSET;
            foreach (qpc_virt_addr[0][i]) begin
                if (qpc_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (qpc_virt_addr[0][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        // start_virt_addr = temp_virt_addr;
                        for (int j = 0; j < page_num; j++) begin
                            qpc_virt_addr[0].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    qpc_virt_addr[0].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_CQC_TYP) begin
            temp_virt_addr = `CQC_OFFSET;
            foreach (cqc_virt_addr[0][i]) begin
                if (cqc_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (cqc_virt_addr[0][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            cqc_virt_addr[0].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    cqc_virt_addr[0].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_MPT_TYP) begin
            temp_virt_addr = `MPT_OFFSET;
            foreach (mpt_virt_addr[0][i]) begin
                if (mpt_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (mpt_virt_addr[0][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            mpt_virt_addr[0].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    mpt_virt_addr[0].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_MTT_TYP) begin
            temp_virt_addr = `MTT_OFFSET;
            foreach (mtt_virt_addr[0][i]) begin
                if (mtt_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (mtt_virt_addr[0][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            mtt_virt_addr[0].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    mtt_virt_addr[0].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_EQC_TYP) begin
            temp_virt_addr = `EQC_OFFSET;
            foreach (eqc_virt_addr[0][i]) begin
                if (eqc_virt_addr[0][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (eqc_virt_addr[0][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            eqc_virt_addr[0].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    eqc_virt_addr[0].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else begin
            `uvm_fatal("ILG_INPUT", "illegal m_type in map_icm!");
        end

        map_icm_item = hca_pcie_item::type_id::create("map_icm_item", this);
        assert(map_icm_item.randomize() with {hcr_op == `CMD_MAP_ICM; map_type == m_type;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in map icm!");
        end
        for (int i = 0; i < page_num; i++) begin
            map_icm_item.icm_addr_map.virt.push_back(temp_virt_addr + i * `PAGE_SIZE);
            map_icm_item.icm_addr_map.page.push_back(temp_virt_addr + `ICM_BASE + i * `PAGE_SIZE);
        end
        map_icm_item.icm_addr_map.page_num = page_num;
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
        pcie_item.qp_ctx = qp_ctx;
        assert(pcie_item.randomize() with {hcr_op == `CMD_RTR2RTS_QPEE;})// qp_num == 2;};
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in modify qp!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: modify_qp

    //------------------------------------------------------------------------------
    // task name     : query_qp
    // function      : generate and send query qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_qp(int qpn);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_QUERY_QP; hcr_in_modifier == qpn;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query qp!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_qp

    task sw2hw_cq(cq_context cq_ctx);
        hca_pcie_item sw2hw_cq_item;
        bit [31:0] cqn;
        sw2hw_cq_item = hca_pcie_item::type_id::create("sw2hw_cq_item", this);
        sw2hw_cq_item.cq_ctx = cq_ctx;
        cqn = cq_ctx.cqn;
        assert(sw2hw_cq_item.randomize() with {hcr_op == `CMD_SW2HW_CQ; hcr_in_modifier == cq_ctx.cqn;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in sw2hw cq!");
        end
        vseq.cfg_item_que[0].push_back(sw2hw_cq_item);
    endtask: sw2hw_cq

    function bit [63:0] write_mtt(bit [63:0] start_index); // input is the mtt item number
                                            // currently not support modify mtt item
        int i;
        bit [63:0] temp = `DATA_BASE;
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_WRITE_MTT; num_mtt == 1;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in write mtt!");
        end
        pcie_item.mtt_item.start_index = start_index;
        foreach (data_phys_addr[0][i]) begin
            if (temp == data_phys_addr[0][i]) begin
                temp += 4096;
            end
        end
        data_phys_addr[0].push_back(temp);
        pcie_item.mtt_item.phys_addr.push_back(temp);
        vseq.cfg_item_que[0].push_back(pcie_item);
        `uvm_info("MTT_MOTICE", $sformatf("write_mtt phys addr: %h", temp), UVM_LOW);
        `uvm_info("MTT_MOTICE", $sformatf("write_mtt start index: %h", start_index), UVM_LOW);
        return temp;
    endfunction: write_mtt

    task close_hca();
        `uvm_info("NOTICE", "close hca begin in test", UVM_LOW);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_CLOSE_HCA;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in close hca!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: close_hca

    //------------------------------------------------------------------------------
    // func name     : query_adapter
    // function      : query device id
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_adapter();
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_QUERY_ADAPTER;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query adapter!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_adapter

    //------------------------------------------------------------------------------
    // func name     : query_dev_lim
    // function      : query device limit information
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_dev_lim();
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_QUERY_DEV_LIM;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query dev lim!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_dev_lim

    task sw2hw_mpt(mpt mpt_item);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.mpt_item = mpt_item;
        assert(pcie_item.randomize() with {hcr_op == `CMD_SW2HW_MPT;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in sw2hw mpt!");
        end
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: sw2hw_mpt

    task post_db(doorbell db);
        pcie_item = hca_pcie_item::type_id::create("db_item", this);
        pcie_item.item_type = DOORBELL;
        pcie_item.db = db;
        vseq.comm_item_que[0].push_back(pcie_item);
    endtask: post_db

    task test_read_no_param();
        wqe drv_wqe;
        doorbell db;
        qp_context qpc;
        cq_context cqc;
        mpt cq_mpt;
        mpt qp_mpt;
        mpt send_mr_mpt;
        mpt recv_mr_mpt;
        addr eqc_icm_addr;
        addr qpc_icm_addr;
        addr cqc_icm_addr;
        addr mpt_icm_addr;
        addr mtt_icm_addr;
        addr send_mr_mtt_index;
        addr recv_mr_mtt_index;
        addr temp_phys_addr;
        addr send_data_phys_addr;
        addr sq_phys_addr;
        bit [31:0] temp_key;
        hca_virt_addr virt_addr;
        bit [31:0] pd = $urandom();
        bit [31:0] recv_pd;
        int mtt_item_offset = 0;
        bit [`DATA_WIDTH - 1 : 0] raw_data;
        int data_page_num;

        virt_addr = hca_virt_addr::type_id::create("virt_addr");
        // drv_wqe = set_drv_wqe();
        
        // set doorbell
        db.opcode = `VERBS_RDMA_READ;
        db.f0 = 0;
        db.sq_head = 0;
        db.size0 = 3;
        db.qp_num = 2;

        // set qp context
        qpc.opt_param_mask              = $urandom();
        qpc.flags                       = {16'h3000, 16'b0};
        qpc.mtu_msgmax                  = 8'b1011_1111;
        qpc.local_qpn                   = 2;
        qpc.remote_qpn                  = 2;
        qpc.port_pkey                   = 0;
        qpc.rnr_retry                   = 0;
        qpc.pd                          = pd;
        qpc.wqe_lkey                    = 1;
        qpc.next_send_psn               = 5;
        qpc.cqn_snd                     = 0;
        qpc.snd_wqe_base_l              = 1;
        qpc.last_acked_psn              = 5;
        qpc.rnr_nextrecvpsn             = 5;
        qpc.rcv_wqe_base_l              = 0;

        // set cq context
        cqc.flags = 32'h0004_0000;
        cqc.start = 0;
        cqc.logsize = 8'h06;
        cqc.usrpage = 0;
        cqc.comp_eqn = 0;
        cqc.pd = pd;
        cqc.lkey = 0;
        cqc.cqn = 0;
        
        // set cq memory region
        cq_mpt.flags = 32'hf002_0d00;
        cq_mpt.page_size = 0;
        cq_mpt.key = 0;
        cq_mpt.pd = pd;
        cq_mpt.start = 1234;
        cq_mpt.length = 64'h0000_0000_0000_0800;
        cq_mpt.mtt_seg = 0;

        // set qp memory region
        qp_mpt.flags = 32'hf002_0500;
        qp_mpt.page_size = 0; 
        qp_mpt.key = 1;
        qp_mpt.pd = pd;
        qp_mpt.start = 0;
        qp_mpt.length = 64'h0000_0000_0000_1000;
        qp_mpt.mtt_seg = 1;
        
        query_adapter();
        query_dev_lim();
        init_hca();
        eqc_icm_addr = map_icm(`ICM_EQC_TYP, 1);
        qpc_icm_addr = map_icm(`ICM_QPC_TYP, 64);
        cqc_icm_addr = map_icm(`ICM_CQC_TYP, 64);
        mtt_icm_addr = map_icm(`ICM_MTT_TYP, 64);
        mpt_icm_addr = map_icm(`ICM_MPT_TYP, 64);

        // create cq
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset); // why >> 3? because input is not address of mtt item, is mtt item number
        mtt_item_offset++;
        sw2hw_mpt(cq_mpt);
        sw2hw_cq(cqc);

        // create qp
        sq_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset);
        mtt_item_offset++;
        sw2hw_mpt(qp_mpt);
        modify_qp(qpc);

        // create send memory region
        send_data_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset);
        send_mr_mtt_index = ((mtt_icm_addr - `MTT_OFFSET) >> 3) + mtt_item_offset;
        mtt_item_offset++;
        
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset);
        mtt_item_offset++;

        virt_addr.randomize();
        send_mr_mpt.flags = 32'b11110000_00000010_00000001_10000100; // 32'hf002_0180;
        send_mr_mpt.page_size = 0;
        send_mr_mpt.key = 2;
        send_mr_mpt.pd = pd;
        send_mr_mpt.start = {virt_addr.page_align_addr_hi, virt_addr.page_align_addr_lo};
        send_mr_mpt.length = {32'b0, data_count};
        send_mr_mpt.mtt_seg = send_mr_mtt_index;
        sw2hw_mpt(send_mr_mpt);
    
        write_test_data(send_data_phys_addr, data_count);

        // create receive memory region
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset);
        recv_mr_mtt_index = ((mtt_icm_addr - `MTT_OFFSET) >> 3) + mtt_item_offset;
        mtt_item_offset++;
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET) >> 3 + mtt_item_offset);
        virt_addr.randomize();
        recv_mr_mpt.flags = 32'b11110000_00000010_00000001_10000011; // 32'hf002_0183;
        recv_mr_mpt.page_size = 0;
        recv_mr_mpt.key = 3;
        recv_mr_mpt.pd = pd;
        recv_mr_mpt.start = {virt_addr.page_align_addr_hi, virt_addr.page_align_addr_lo};
        recv_mr_mpt.length = {32'b0, data_count};
        recv_mr_mpt.mtt_seg = recv_mr_mtt_index;
        sw2hw_mpt(recv_mr_mpt);

        drv_wqe.next_seg.next_opcode = 0;
        drv_wqe.next_seg.next_wqe = {8'b0, 8'b0, 8'b0, 2'b0};
        drv_wqe.next_seg.next_wqe_size = 0;
        drv_wqe.next_seg.next_fence = 0;
        drv_wqe.next_seg.next_dbd = 0;
        drv_wqe.next_seg.next_ee = 0;
        drv_wqe.next_seg.solicit = 0;
        drv_wqe.next_seg.evt = 0;
        drv_wqe.next_seg.cq = 0;
        drv_wqe.next_seg.imm_data = 0;
        drv_wqe.raddr_seg.raddr = send_mr_mpt.start;
        drv_wqe.raddr_seg.rkey = send_mr_mpt.key;
        drv_wqe.data_seg.byte_count = data_count;
        drv_wqe.data_seg.lkey = recv_mr_mpt.key;
        drv_wqe.data_seg.addr = recv_mr_mpt.start;

        // write wqe
        raw_data = 0;
        data_fifo.clean();
        raw_data[127:0] = {
            drv_wqe.next_seg.imm_data,
            {28'b0}, drv_wqe.next_seg.cq, drv_wqe.next_seg.evt, drv_wqe.next_seg.solicit, 1'b0,
            drv_wqe.next_seg.next_ee, drv_wqe.next_seg.next_dbd, drv_wqe.next_seg.next_fence, drv_wqe.next_seg.next_wqe_size,
            drv_wqe.next_seg.next_wqe, 1'b0, drv_wqe.next_seg.next_opcode
        };
        raw_data[255:128] = {
            32'b0,
            drv_wqe.raddr_seg.rkey,
            drv_wqe.raddr_seg.raddr
        };
        data_fifo.push(trans2comb(raw_data));
        raw_data = 0;
        drv_wqe.data_seg.addr = send_mr_mpt.start;
        drv_wqe.data_seg.lkey = send_mr_mpt.key;
        drv_wqe.data_seg.byte_count = data_count;
        raw_data[127:0] = {
            drv_wqe.data_seg.addr,
            drv_wqe.data_seg.lkey,
            drv_wqe.data_seg.byte_count
        };
        data_fifo.push(trans2comb(raw_data));
        env.mem[0].write_block(sq_phys_addr, data_fifo, 48);
        post_db(db);
    endtask: test_read_no_param

    task test_write();
        wqe drv_wqe;
        doorbell db;
        qp_context qpc;
        cq_context cqc;
        mpt cq_mpt;
        mpt qp_mpt;
        mpt send_mr_mpt;
        mpt recv_mr_mpt;
        addr eqc_icm_addr;
        addr qpc_icm_addr;
        addr cqc_icm_addr;
        addr mpt_icm_addr;
        addr mtt_icm_addr;
        addr send_mr_mtt_index;
        addr recv_mr_mtt_index;
        addr temp_phys_addr;
        addr send_data_phys_addr;
        addr sq_phys_addr;
        bit [31:0] temp_key;
        hca_virt_addr virt_addr;
        bit [31:0] send_pd = $urandom();
        bit [31:0] recv_pd;
        int mtt_item_addr_offset = 0;
        bit [`DATA_WIDTH - 1 : 0] raw_data;
        int data_page_num;

        virt_addr = hca_virt_addr::type_id::create("virt_addr");
        // drv_wqe = set_drv_wqe();
        
        db = set_drv_db();
        qpc = set_drv_qpc();
        qpc.pd = send_pd;
        cqc = set_drv_cqc();
        cqc.pd = send_pd;
        cq_mpt = set_drv_cq_mpt();
        cq_mpt.pd = send_pd;
        qp_mpt = set_qp_mpt();
        qp_mpt.pd = send_pd;
        
        query_adapter();
        query_dev_lim();
        init_hca();
        eqc_icm_addr = map_icm(`ICM_EQC_TYP, 1);
        qpc_icm_addr = map_icm(`ICM_QPC_TYP, 64);
        cqc_icm_addr = map_icm(`ICM_CQC_TYP, 64);
        mtt_icm_addr = map_icm(`ICM_MTT_TYP, 64);
        mpt_icm_addr = map_icm(`ICM_MPT_TYP, 64);

        // create cq
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3); // why >> 3? because input is not address of mtt item, is mtt item number
        mtt_item_addr_offset += 8;
        sw2hw_mpt(cq_mpt);
        sw2hw_cq(cqc);

        // create qp
        sq_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3);
        mtt_item_addr_offset += 8;
        sw2hw_mpt(qp_mpt);
        modify_qp(qpc);

        // create send memory region
        send_data_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3);
        send_mr_mtt_index = (mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3;
        mtt_item_addr_offset += 8;
        
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3);
        mtt_item_addr_offset += 8;

        virt_addr.randomize();
        send_mr_mpt.flags = 32'hf002_0180;
        send_mr_mpt.page_size = 0;
        send_mr_mpt.key = 2;
        send_mr_mpt.pd = send_pd;
        send_mr_mpt.start = {virt_addr.page_align_addr_hi, virt_addr.page_align_addr_lo};
        send_mr_mpt.length = {32'b0, data_count};
        send_mr_mpt.mtt_seg = send_mr_mtt_index;
        sw2hw_mpt(send_mr_mpt);
    
        write_test_data(send_data_phys_addr, data_count);

        // create receive memory region
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3);
        recv_mr_mtt_index = (mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3;
        mtt_item_addr_offset += 8;
        temp_phys_addr = write_mtt((mtt_icm_addr - `MTT_OFFSET + mtt_item_addr_offset) >> 3);
        // recv_mr_mpt = set_recv_mr_mpt();
        virt_addr.randomize();
        recv_mr_mpt.flags = 32'hf002_0183;
        recv_mr_mpt.page_size = 0;
        recv_mr_mpt.key = 3;
        recv_mr_mpt.pd = send_pd;
        recv_mr_mpt.start = {virt_addr.page_align_addr_hi, virt_addr.page_align_addr_lo};
        recv_mr_mpt.length = {32'b0, data_count};
        recv_mr_mpt.mtt_seg = recv_mr_mtt_index;
        sw2hw_mpt(recv_mr_mpt);

        drv_wqe.next_seg.next_opcode = 0;
        drv_wqe.next_seg.next_wqe = {8'b0, 8'b0, 8'b0, 2'b0};
        drv_wqe.next_seg.next_wqe_size = 0;
        drv_wqe.next_seg.next_fence = 0;
        drv_wqe.next_seg.next_dbd = 0;
        drv_wqe.next_seg.next_ee = 0;
        drv_wqe.next_seg.solicit = 0;
        drv_wqe.next_seg.evt = 0;
        drv_wqe.next_seg.cq = 0;
        drv_wqe.next_seg.imm_data = 0;
        drv_wqe.raddr_seg.raddr = recv_mr_mpt.start;
        drv_wqe.raddr_seg.rkey = recv_mr_mpt.key;
        drv_wqe.data_seg.byte_count = data_count;
        drv_wqe.data_seg.lkey = send_mr_mpt.key;
        drv_wqe.data_seg.addr = send_mr_mpt.start;

        // write wqe
        raw_data = 0;
        data_fifo.clean();
        raw_data[127:0] = {
            drv_wqe.next_seg.imm_data,
            {28'b0}, drv_wqe.next_seg.cq, drv_wqe.next_seg.evt, drv_wqe.next_seg.solicit, 1'b0,
            drv_wqe.next_seg.next_ee, drv_wqe.next_seg.next_dbd, drv_wqe.next_seg.next_fence, drv_wqe.next_seg.next_wqe_size,
            drv_wqe.next_seg.next_wqe, 1'b0, drv_wqe.next_seg.next_opcode
        };
        raw_data[255:128] = {
            32'b0,
            drv_wqe.raddr_seg.rkey,
            drv_wqe.raddr_seg.raddr
        };
        data_fifo.push(trans2comb(raw_data));
        raw_data = 0;
        drv_wqe.data_seg.addr = send_mr_mpt.start;
        drv_wqe.data_seg.lkey = send_mr_mpt.key;
        drv_wqe.data_seg.byte_count = data_count;
        raw_data[127:0] = {
            drv_wqe.data_seg.addr,
            drv_wqe.data_seg.lkey,
            drv_wqe.data_seg.byte_count
        };
        data_fifo.push(trans2comb(raw_data));
        env.mem[0].write_block(sq_phys_addr, data_fifo, 48);
        post_db(db);
    endtask: test_write

    task driver_mon;
        wqe drv_wqe;
        doorbell db;
        qp_context qpc;
        cq_context cqc;
        mpt cq_mpt;
        mpt qp_mpt;
        mpt send_mr_mpt;
        mpt recv_mr_mpt;
        addr eqc_index;
        addr qpc_index;
        addr cqc_index;
        addr mpt_index;
        addr mtt_index;
        addr temp_phys_addr;
        addr sq_phys_addr;
        bit [`DATA_WIDTH - 1 : 0] raw_data;
        drv_wqe = set_drv_wqe();
        db = set_drv_db();
        qpc = set_drv_qpc();
        cqc = set_drv_cqc();
        cq_mpt = set_drv_cq_mpt();
        qp_mpt = set_qp_mpt();
        send_mr_mpt = set_send_mr_mpt();
        recv_mr_mpt = set_recv_mr_mpt();

        query_adapter();
        query_dev_lim();
        init_hca();
        eqc_index = map_icm(`ICM_EQC_TYP, 1);
        qpc_index = map_icm(`ICM_QPC_TYP, 64);
        cqc_index = map_icm(`ICM_CQC_TYP, 64);
        mtt_index = map_icm(`ICM_MTT_TYP, 64);
        mpt_index = map_icm(`ICM_MPT_TYP, 64);
        // create cq
        temp_phys_addr = write_mtt(mtt_index >> 3);
        sw2hw_mpt(cq_mpt);
        sw2hw_cq(cqc);
        // create qp
        sq_phys_addr = write_mtt((mtt_index + 8) >> 3);
        sw2hw_mpt(qp_mpt);
        modify_qp(qpc);
        // create send memory region
        temp_phys_addr = write_mtt((mtt_index + 16) >> 3);
        sw2hw_mpt(send_mr_mpt);
        data = 0;
        for (int i = 0; i < 12; i++) begin
            data[i] = i;
        end
        data_fifo.push(data);
        `uvm_info("DATA_NOTICE", $sformatf("data: %h", data), UVM_LOW);
        // `uvm_info("TEST_NOTICE", $sformatf("send data physical addr: %h", temp_phys_addr));
        env.mem[0].write_block(temp_phys_addr, data_fifo, 12);
        // create receive memory region
        temp_phys_addr = write_mtt((mtt_index + 24) >> 3);
        sw2hw_mpt(recv_mr_mpt);

        // write wqe
        raw_data = 0;
        data_fifo.clean();
        raw_data[127:0] = {
            drv_wqe.next_seg.imm_data,
            {28'b0}, drv_wqe.next_seg.cq, drv_wqe.next_seg.evt, drv_wqe.next_seg.solicit, 1'b0,
            drv_wqe.next_seg.next_ee, drv_wqe.next_seg.next_dbd, drv_wqe.next_seg.next_fence, drv_wqe.next_seg.next_wqe_size,
            drv_wqe.next_seg.next_wqe, 1'b0, drv_wqe.next_seg.next_opcode
        };
        raw_data[255:128] = {
            32'b0,
            drv_wqe.raddr_seg.rkey,
            drv_wqe.raddr_seg.raddr
        };
        data_fifo.push(trans2comb(raw_data));
        raw_data = 0;
        drv_wqe.data_seg.addr = send_mr_mpt.start;
        drv_wqe.data_seg.lkey = send_mr_mpt.key;
        drv_wqe.data_seg.byte_count = 12;
        raw_data[127:0] = {
            drv_wqe.data_seg.addr,
            drv_wqe.data_seg.lkey,
            drv_wqe.data_seg.byte_count
        };
        data_fifo.push(trans2comb(raw_data));
        env.mem[0].write_block(sq_phys_addr, data_fifo, 48);
        post_db(db);
    endtask: driver_mon

    function mpt set_recv_mr_mpt();
        mpt recv_mr_mpt;
        recv_mr_mpt.flags = 32'hf002_0183;
        recv_mr_mpt.page_size = 0;
        recv_mr_mpt.key = 3;
        recv_mr_mpt.pd = 0;
        recv_mr_mpt.start = 64'hffff_9e3c_9ffd_1000;
        recv_mr_mpt.length = {32'b0, data_count};
        recv_mr_mpt.lkey = 0;
        recv_mr_mpt.window_count = 0;
        recv_mr_mpt.window_count_limit = 0;
        recv_mr_mpt.mtt_seg = 3;
        recv_mr_mpt.mtt_sz = 0;
        return recv_mr_mpt;
    endfunction: set_recv_mr_mpt

    function mpt set_send_mr_mpt();
        mpt send_mr_mpt;
        send_mr_mpt.flags = 32'hf002_0180;
        send_mr_mpt.page_size = 0;
        send_mr_mpt.key = 2;
        send_mr_mpt.pd = 0;
        send_mr_mpt.start = 64'hffff_9e3c_9b90_c000;
        send_mr_mpt.length = {32'b0, data_count};
        send_mr_mpt.lkey = 0;
        send_mr_mpt.window_count = 0;
        send_mr_mpt.window_count_limit = 0;
        send_mr_mpt.mtt_seg = 2;
        send_mr_mpt.mtt_sz = 0;
        return send_mr_mpt;
    endfunction: set_send_mr_mpt

    function mpt set_qp_mpt();
        mpt qp_mpt;
        qp_mpt.flags = 32'hf002_0500;
        qp_mpt.page_size = 0; 
        qp_mpt.key = 1;
        qp_mpt.pd = 0;
        qp_mpt.start = 0;
        qp_mpt.length = 64'h0000_0000_0000_1000;
        qp_mpt.lkey = 0;
        qp_mpt.window_count = 0;
        qp_mpt.window_count_limit = 0;
        qp_mpt.mtt_seg = 1;
        qp_mpt.mtt_sz = 0;
        return qp_mpt;
    endfunction: set_qp_mpt

    function mpt set_drv_cq_mpt();
        mpt cq_mpt;
        cq_mpt.flags = 32'hf002_0d00;
        cq_mpt.page_size = 0;
        cq_mpt.key = 0;
        cq_mpt.pd = 0;
        cq_mpt.start = 0;
        cq_mpt.length = 64'h0000_0000_0000_0800;
        cq_mpt.lkey = 0;
        cq_mpt.window_count = 0;
        cq_mpt.window_count_limit = 0;
        cq_mpt.mtt_seg = 0;
        cq_mpt.mtt_sz = 0;
        return cq_mpt;
    endfunction: set_drv_cq_mpt

    function cq_context set_drv_cqc();
        cq_context cqc;
        cqc.flags = 32'h0004_0000;
        cqc.start = 0;
        cqc.logsize = 8'h06;
        cqc.usrpage = 0;
        cqc.comp_eqn = 0;
        cqc.pd = 0;
        cqc.lkey = 0;
        cqc.cqn = 0;
        return cqc;
    endfunction: set_drv_cqc

    function qp_context set_drv_qpc();
        qp_context qpc;
        qpc.opt_param_mask              = $urandom();
        qpc.flags                       = {16'h3000, 16'b0};
        qpc.mtu_msgmax                  = 8'b1011_1111;
        qpc.rq_size_stride              = 0; // no use
        qpc.sq_size_stride              = 0; // no use
        qpc.rlkey_arbel_sched_queue     = 0; // no use
        qpc.usr_page                    = 0; // no use
        qpc.local_qpn                   = 0;
        qpc.remote_qpn                  = 0;
        qpc.port_pkey                   = 0;
        qpc.rnr_retry                   = 0;
        qpc.g_mylmc                     = 0; // no use
        qpc.rlid                        = 0; // no use
        qpc.ackto                       = 0; // no use
        qpc.mgid_index                  = 0; // no use
        qpc.static_rate                 = 0; // no use
        qpc.hop_limit                   = 0; // no use
        qpc.sl_tclass_flowlabel         = 0; // no use
        qpc.rgid                        = 0; // no use
        qpc.pd                          = 0;
        qpc.wqe_base                    = 0; // no use
        qpc.wqe_lkey                    = 1;
        qpc.next_send_psn               = 5;
        qpc.cqn_snd                     = 0;
        qpc.snd_wqe_base_l              = 1;
        qpc.snd_db_index                = 0; // no use
        qpc.last_acked_psn              = 5;
        qpc.ssn                         = 0; // no use
        qpc.rnr_nextrecvpsn             = 5;
        qpc.ra_buff_indx                = 0; // no use
        qpc.cqn_rcv                     = 0; // no use
        qpc.rcv_wqe_base_l              = 0;
        qpc.rcv_db_index                = 0; // no use
        qpc.qkey                        = 0; // no use
        qpc.rmsn                        = 0; // no use
        qpc.rq_wqe_counter              = 0; // no use
        qpc.sq_wqe_counter              = 0; // no use
        return qpc;
    endfunction: set_drv_qpc

    function doorbell set_drv_db();
        doorbell db;
        db.opcode = `VERBS_RDMA_WRITE;
        db.f0 = 0;
        db.sq_head = 0;
        db.size0 = 3;
        db.qp_num = 0;
        return db;
    endfunction: set_drv_db

    function wqe set_drv_wqe();
        wqe drv_wqe;
        drv_wqe.next_seg.next_opcode = 0;
        drv_wqe.next_seg.next_wqe = {8'b0, 8'b0, 8'b0, 2'b0};
        drv_wqe.next_seg.next_wqe_size = 0;
        drv_wqe.next_seg.next_fence = 0;
        drv_wqe.next_seg.next_dbd = 0;
        drv_wqe.next_seg.next_ee = 0;
        drv_wqe.next_seg.solicit = 0;
        drv_wqe.next_seg.evt = 0;
        drv_wqe.next_seg.cq = 0;
        drv_wqe.next_seg.imm_data = 0;
        drv_wqe.raddr_seg.raddr = 64'hffff_9e3c_9ffd_1000;
        drv_wqe.raddr_seg.rkey = 32'h0000_0003;
        drv_wqe.data_seg.byte_count = data_count;
        drv_wqe.data_seg.lkey = 32'h0000_0002;
        drv_wqe.data_seg.addr = 64'hffff_9e3c_9b90_c000;
        return drv_wqe;
    endfunction: set_drv_wqe

    function bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] trans2comb(bit [255:0] raw_data);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] result;
        for (int i = 0; i < 32; i++) begin
            result[i] = raw_data[i * 8 + 7 -: 8];
        end
        return result;
    endfunction

    function write_test_data(addr phys_addr, bit [31:0] data_cnt);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] write_data;
        int beat_num;
        write_data = 0;
        if (data_cnt[4:0] == 0) begin
            beat_num = data_cnt[31:5];
        end
        else begin
            beat_num = data_cnt[31:5] + 1;
        end
        for (int i = 0; i < beat_num; i++) begin
            for (int j = 0; j < 32; j++) begin
                write_data[j] = (i * 32 + j) % 256;
            end
            data_fifo.push(write_data);
            `uvm_info("DATA_NOTICE", $sformatf("write data: %h", write_data), UVM_LOW);
            write_data = 0;
        end
        env.mem[0].write_block(phys_addr, data_fifo, data_cnt);
        `uvm_info("TEST_NOTICE", $sformatf("send data physical addr: %h, data count: %0d", phys_addr, data_cnt), UVM_LOW);
        data_fifo.clean();
    endfunction: write_test_data
    
endclass: test_drv
`endif