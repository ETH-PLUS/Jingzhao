//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-07-30
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_direct.sv
//  FUNCTION : This file supplies the case for testing configuration of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-07-30    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __TEST_DIRECT__
`define __TEST_DIRECT__

//------------------------------------------------------------------------------
//
// CLASS: test_direct
//
//------------------------------------------------------------------------------
class test_direct extends uvm_test;
    string seq_name;
    hca_env env;
    hca_vsequence vseq;
    hca_pcie_item pcie_item;
    hca_fifo #(.width(256)) data_fifo;
    bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    int host_num;
    int proc_num;
    int qp_num;
    int db_num;
    int wqe_num;
    int page_num;
    hca_virt_addr virt_addr[];

    bit      [`ADDR_WIDTH - 1 : 0] qpc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] cqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] eqc_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mpt_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] mtt_virt_addr[][$];

    bit      [`ADDR_WIDTH - 1 : 0] data_virt_addr[][$];
    bit      [`ADDR_WIDTH - 1 : 0] data_phys_addr[][$];

    qp_context                     qp_ctx_list[][$];
    hca_queue_pair                 qp_list[][$];
    cq_context                     cq_ctx_list[][$];
    mpt                            mem_region[][$];
    mtt                            mem_table[][$];
    icm_map                        icm_addr_map[];

    bit      [31:0]                data_count;

    `uvm_component_utils(test_direct)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_direct", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates env and sequence.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!$value$plusargs("HCA_HOST_NUM=%d", host_num)) begin
            `uvm_fatal("PARAM_ERROR", "host num not get!");
        end
        if (host_num > `MAX_HOST_NUM) begin
            `uvm_fatal("PARAM_ERROR", "host num maximum exceeded!");
        end

        if (!$value$plusargs("HCA_PROC_NUM_NUM=%d", proc_num)) begin
            `uvm_fatal("PARAM_ERROR", "process num not get!");
        end
        if (proc_num > `MAX_PROC_NUM) begin
            `uvm_fatal("PARAM_ERROR", "process num maximum exceeded!");
        end

        if (!$value$plusargs("HCA_QP_NUM=%d", qp_num)) begin
            `uvm_fatal("PARAM_ERROR", "QP num not get!");
        end
        if (qp_num > `MAX_QP_NUM) begin
            `uvm_fatal("PARAM_ERROR", "QP num maximum exceeded!");
        end

        if (!$value$plusargs("HCA_DB_NUM=%d", db_num)) begin
            `uvm_fatal("PARAM_ERROR", "doorbell num not get!");
        end
        if (db_num > `MAX_DB_NUM) begin
            `uvm_fatal("PARAM_ERROR", "doorbell num maximum exceeded!");
        end

        if (!$value$plusargs("HCA_WQE_NUM=%d", wqe_num)) begin
            `uvm_fatal("PARAM_ERROR", "WQE num not get!");
        end
        if (wqe_num > `MAX_WQE_NUM) begin
            `uvm_fatal("PARAM_ERROR", "WQE num maximum exceeded!");
        end

        if (!$value$plusargs("HCA_PAGE_NUM=%d", page_num)) begin
            `uvm_fatal("PARAM_ERROR", "page num not get!");
        end
        if(page_num > `MAX_PAGE_NUM) begin
            `uvm_fatal("PARAM_ERROR", "page num maximum exceeded!");
        end
        if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
            `uvm_fatal("PARAM_ERROR", "seq name not get!");
        end
        qpc_virt_addr = new[host_num];
        cqc_virt_addr = new[host_num];
        eqc_virt_addr = new[host_num];
        mpt_virt_addr = new[host_num];
        mtt_virt_addr = new[host_num];
        data_phys_addr = new[host_num];
        cq_ctx_list = new[host_num];
        virt_addr = new[host_num];
        qp_ctx_list = new[host_num];
        qp_list = new[host_num];
        mem_region = new[host_num];
        mem_table = new[host_num];
        icm_addr_map = new[host_num];
        env = hca_env::type_id::create("env", this);
        vseq = hca_vsequence::type_id::create("vseq", this);
        data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");
        for (int i = 0; i < host_num; i++) begin
            virt_addr = hca_virt_addr::type_id::create($sformatf("virt_addr[%0d]", host_num));
        end
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
        gen_item_seq();
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
    task gen_item_seq();
        case (seq_name)
            "test_read": begin
                data_count = 32'h0000_000a;
                test_read();
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
        direct_test();
    endtask: gen_item_seq

    task init_hca(int host_id);
        hca_pcie_item init_hca_item;
        init_hca_item = hca_pcie_item::type_id::create($sformatf("init_hca_item[%0d]", host_id), this);
        assert (init_hca_item.randomize() with {hcr_op == `CMD_INIT_HCA;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in init hca!");
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
        vseq.cfg_item_que[host_id].push_back(init_hca_item);
    endtask: init_hca

    function bit [63:0] map_icm(int m_type, int page_num); // m_type: 1: qp context; 2: cq context; 3: mpt; 4: mtt;
                                             // return the virtual address of the mapped page in ICM space;
        hca_pcie_item map_icm_item;
        bit [63:0] temp_virt_addr;
        bit [63:0] temp_phys_addr;
        // addr start_virt_addr;
        int i;
        bit flag = 0;
        if (page_num > 12'b11111111) begin
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
        qp_ctx_list[0].push_back(qp_ctx);
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
        cq_ctx_list[0].push_back(cq_ctx);
    endtask: sw2hw_cq

    function bit [63:0] write_mtt(bit [63:0] start_index); // input is the ICM virtual address of mtt item
                                            // currently not support modify mtt item
        int i;
        bit [63:0] temp = `DATA_BASE;
        mtt temp_mtt_item;

        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        assert(pcie_item.randomize() with {hcr_op == `CMD_WRITE_MTT; num_mtt == 1;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in write mtt!");
        end

        pcie_item.mtt_item.start_index = start_index;
        temp_mtt_item.index = start_index;
        foreach (data_phys_addr[0][i]) begin
            if (temp == data_phys_addr[0][i]) begin
                temp += 4096;
            end
        end

        temp_mtt_item.phys_addr = temp;
        mem_table[0].push_back(temp_mtt_item);

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
        mem_region[0].push_back(mpt_item);
    endtask: sw2hw_mpt

    task post_db(doorbell db);
        pcie_item = hca_pcie_item::type_id::create("db_item", this);
        pcie_item.item_type = DOORBELL;
        pcie_item.db = db;
        vseq.comm_item_que[0].push_back(pcie_item);
    endtask: post_db

    task direct_test;
        configure();
        comm();
        
    endtask: direct_test

    task configure;
        addr qpc_index[][$];
        query_adapter();
        query_dev_lim();
        // init_hca();
        qpc_index = new[host_num];
        for (int i = 0; i < qp_num; i++) begin
            qpc_index[i] = map_icm(`ICM_QPC_TYP, 1);
        end
    endtask: configure

    function bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] trans2comb(bit [255:0] raw_data);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] result;
        for (int i = 0; i < 32; i++) begin
            result[i] = raw_data[i * 8 + 7 -: 8];
        end
        return result;
    endfunction: trans2comb

    task test_write();
        wqe drv_wqe;
        doorbell db[][$];
        qp_context qpc[][$];
        cq_context cqc[][$];
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
        // init_hca();
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

    task test_read();
        mpt data_mpt;
        mpt recv_mpt;
        addr data_start_phys_addr;
        addr data_vaddr;
        addr qp_vaddr;
        addr cq_vaddr;
        addr cqc_start_addr;
        addr qpc_start_addr;
        bit [31:0] cqn;
        bit [31:0] qpn;
        e_service_type serv_typ;
        e_op_type op_type;
        doorbell db;
        bit [31:0] pd;
        hca_queue_pair temp_qp;

        pd = $urandom();

        serv_type = RC;

        qpc_start_addr = map_icm(ICM_QPC_TYP, 8);
        qpn = create_qp(pd, serv_typ);

        data_vaddr = {12'b1000_0000_0000, qpn[13:0], 38'b0}; // 64G per QP


        data_mpt = create_mr(data_count, data_vaddr, pd, `PAGE_SIZE, data_start_phys_addr);
        write_test_data(data_start_phys_addr, data_count);
        recv_mpt = create_mr(data_count, data_vaddr + data_count, pd, `PAGE_SIZE, data_start_phys_addr);

        cqc_start_addr = map_icm(ICM_CQC_TYP, 8);
        cqn = create_cq();
        

        put_wqe(qpn, wqe_num, op_type, data_count, recv_mpt, data_mpt);
        for (int i = 0; i < qp_list[0].size(); i++) begin
            if (qp_list[0][i].ctx.local_qpn == qpn) begin
                temp_qp = qp_list[0][i];
                break;
            end
        end
        db.sq_head = {5'b0, temp_qp.header[10:0]};
        db.f0 = 0;
        db.opcode = `VERBS_RDMA_READ;
        db.qp_num = qpn;
        db.size0 = 3;
        post_db(db);
        
    endtask: test_read

    function put_wqe(bit [31:0] qpn, int wqe_num, e_op_type op_type, int data_count, mpt local_mpt, mpt remote_mpt);
        qp_context qp_ctx;
        hca_queue_pair qp;
        addr data_vaddr;
        addr buffer_vaddr;
        data_vaddr = {12'b1000_0000_0000, qpn[13:0], 38'b0};
        buffer_vaddr = data_vaddr + data_count;
        for (int i = 0; i < qp_ctx_list[0].size(); i++) begin
            if (qp_ctx_list[0][i].local_qpn == qpn) begin
                qp_ctx = qp_ctx_list[0][i];
                break;
            end
        end
        for (int i = 0; i < qp_list[0].size(); i++) begin
            if (qp_list[0][i].ctx.local_qpn == qpn) begin
                qp = qp_list[0][i];
                break;
            end
        end
        
        for (int i = 0; i < wqe_num; i++) begin
            wqe temp_wqe;
            // set next seg
            if (i + 1 == wqe_num) begin // is the last wqe
                temp_wqe.next_seg.next_wqe = 0;
                temp_wqe.next_seg.next_opcode = 0;
                temp_wqe.next_seg.next_ee = 0;
                temp_wqe.next_seg.next_dbd = 0;
                temp_wqe.next_seg.next_fence = 0;
                temp_wqe.next_seg.next_wqe_size = 0;
                temp_wqe.next_seg.cq = 0;
                temp_wqe.next_seg.evt = 0;
                temp_wqe.next_seg.solicit = 0;
                temp_wqe.next_seg.imm_data = 0;
            end
            else begin
                temp_wqe.next_seg.next_wqe = (qp.header + `MAX_DESC_SZ) % 2048;
                case (op_type)
                    WRITE: begin
                        temp_wqe.next_seg.next_opcode = `VERBS_RDMA_WRITE;
                        temp_wqe.next_seg.next_wqe_size = 3;
                    end
                    READ: begin
                        temp_wqe.next_seg.next_opcode = `VERBS_RDMA_READ;
                        temp_wqe.next_seg.next_wqe_size = 3;
                    end
                    SEND: begin
                        temp_wqe.next_seg.next_opcode = `VERBS_SEND;
                        temp_wqe.next_seg.next_wqe_size = 3;
                    end
                    RECV: begin
                        // send wqe to rq
                    end
                    default: begin
                        `uvm_fatal("ILLEGAL_OPCODE", "illegal op code in wqe!");
                    end
                endcase
            end
            // set data seg
            temp_wqe.data_seg.byte_count = data_count;
            temp_wqe.data_seg.lkey = local_mpt;
            temp_wqe.data_seg.addr = buffer_vaddr;
            temp_wqe.raddr_seg.raddr = data_vaddr;
            temp_wqe.raddr_seg.rkey = remote_mpt;
            qp.sq_wqe_list.push_back(temp_wqe);

            write_wqe(qp, temp_wqe);
        end

        qp.header = qp.header + wqe_num * `MAX_DESC_SZ;
        if ((qp.header - qp.tail) > 2048) begin
            `uvm_fatal("QP_OVERLAY", "header exceeds tail!");
        end

    endfunction: put_wqe

    function write_wqe(hca_queue_pair qp, wqe temp_wqe); // not support multipage wqe
        addr base_vaddr;
        addr base_paddr;
        mpt qp_mpt;
        bit [`DATA_WIDTH - 1 : 0] raw_data;
        base_vaddr ={38'b0, qp.ctx.local_qpn[13:0], qp.header[10:0]};
        for (int i = 0; i < mem_region[0].size(); i++) begin
            if (mem_region[0][i].key == qp.ctx.wqe_lkey) begin
                qp_mpt = mem_region[0][i];
                break;
            end
        end
        base_paddr = mem_table[0][qp_mpt.mtt_seg];

        // write wqe
        raw_data = 0;
        data_fifo.clean();
        raw_data[127:0] = {
            temp_wqe.next_seg.imm_data,
            {28'b0}, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, 1'b0,
            temp_wqe.next_seg.next_ee, temp_wqe.next_seg.next_dbd, temp_wqe.next_seg.next_fence, temp_wqe.next_seg.next_wqe_size,
            temp_wqe.next_seg.next_wqe, 1'b0, temp_wqe.next_seg.next_opcode
        };
        raw_data[255:128] = {
            32'b0,
            temp_wqe.raddr_seg.rkey,
            temp_wqe.raddr_seg.raddr
        };
        data_fifo.push(trans2comb(raw_data));
        raw_data = 0;
        temp_wqe.data_seg.addr = send_mr_mpt.start;
        temp_wqe.data_seg.lkey = send_mr_mpt.key;
        temp_wqe.data_seg.byte_count = data_count;
        raw_data[127:0] = {
            temp_wqe.data_seg.addr,
            temp_wqe.data_seg.lkey,
            temp_wqe.data_seg.byte_count
        };
        data_fifo.push(trans2comb(raw_data));
        env.mem[0].write_block(base_paddr, data_fifo, 48);
        
    endfunction: write_wqe

    function send_db(bit [31:0] qpn);

    endfunction: send_db

    function bit [31:0] create_qp(bit [31:0] pd, e_service_type serv_typ);
        bit [31:0] qp_num = 2;
        qp_context qp_ctx;
        mpt qp_mpt;
        addr qp_start_vaddr;
        int qp_vaddr_offset;
        addr temp_addr;
        hca_queue_pair qp;

        for (int i = 0; i < qp_ctx_list[0].size(); i++) begin
            if (qp_ctx_list[0][i].local_qpn == qp_num) begin
                qp_num++;
            end
        end

        qp_vaddr_offset = qp_num * MAX_DESC_SZ * MAX_QP_SZ;
        qp_start_vaddr = 64'h0000_0000_2000_0000 + qp_num * 20'h4_0000;
        // create qp mr
        qp_mpt = create_mr(4096 * 2048, qp_start_vaddr, pd, 4096, temp_addr);
        sw2hw_mpt(qp_mpt);

        qpc.opt_param_mask              = $urandom();
        case (serv_typ)
            RC: begin
                qpc.flags = {16'h3000, 16'b0};
            end
            UC: begin
                qpc.flags = {16'h3000, 16'h0001};
            end
            RD: begin
                qpc.flags = {16'h3000, 16'h0002};
            end
            UD: begin
                qpc.flags = {16'h3000, 16'h0003};
            end
            default: begin
                `uvm_fatal("CREATE_QP_ERR", "invalid service type!");
            end
        endcase
        qpc.mtu_msgmax                  = 8'b1011_1111;
        qpc.local_qpn                   = qp_num;
        qpc.remote_qpn                  = qp_num;
        qpc.port_pkey                   = 0;
        qpc.rnr_retry                   = 0;
        qpc.pd                          = pd;
        qpc.wqe_lkey                    = qp_mpt.key;
        qpc.next_send_psn               = $urandom();
        qpc.cqn_snd                     = 0;
        qpc.snd_wqe_base_l              = 1;
        qpc.last_acked_psn              = qpc.next_send_psn;
        qpc.rnr_nextrecvpsn             = qpc.next_send_psn;
        qpc.rcv_wqe_base_l              = 0;
        modify_qp(qpc);
        qp = hca_queue_pair::type_id::create($sformatf("qp%0d", qpc.local_qpn));
        qp.ctx = qpc;
        qp.header = 0;
        qp.tail = 0;
        qp_list[0].push_back(qp);
        return qp_num;
    endfunction: create_qp

    function bit [31:0] create_cq();
        cq_context cqc;
        cqc.flags = 32'h0004_0000;
        cqc.start = 64'h0000_0000_0000_0010;
        cqc.logsize = 8'h06;
        cqc.usrpage = 0;
        cqc.comp_eqn = 0;
        cqc.pd = pd;
        cqc.lkey = 0;
        cqc.cqn = 0;

        // create cq mr

        sw2hw_cq(cqc);
        return cqc.cqn;
    endfunction: create_cq

    function mpt create_mr(input bit [63:0] size, 
                           input addr start_vaddr, 
                           input bit [31:0] pd, 
                           input bit [31:0] page_size, 
                           output addr data_start_phys_addr
    );
        mpt new_mpt;
        int mtt_num;
        // addr data_start_phys_addr;
        addr temp_addr;
        addr mtt_icm_addr;
        addr mtt_icm_idx;
        addr mpt_icm_addr;
        mtt temp_mtt_item;

        new_mpt.flags = 32'hf002_0183;
        new_mpt.length = size;
        new_mpt.start = start_vaddr;
        new_mpt.pd = pd;
        for (int i = 0; i < 32; i++) begin
            if (page_size[i] == 1) begin
                if (i < 12) begin
                    `uvm_fatal("ILLEGAL_PAGESIZE", "page_size illegal in create_mr()!");
                end
                else begin
                    new_mpt.page_size = i - 12;
                end
            end
        end

        mtt_icm_addr = map_icm(`ICM_MTT_TYP, 1);
        mpt_icm_addr = map_icm(`ICM_MPT_TYP, 1);
        // mtt_icm_idx = mtt_icm_addr >> 3;
        temp_mtt_item.index = mtt_icm_addr >> 3;

        mtt_num = size / page_size;
        for (int i = 0; i < mtt_num; i++) begin
            temp_mtt_item.phys_addr = write_mtt(temp_mtt_item.index);
            if (i == 0) begin
                data_start_phys_addr = temp_mtt_item.phys_addr;
            end
            // mem_table.push_back(temp_mtt_item);
            // mtt_icm_idx++;
            temp_mtt_item.index++;
        end

        sw2hw_mpt(new_mpt);
        `uvm_info("CREATE_MR_NOTEICE", $sformatf("create mr success! size: %h, vaddr: %h, pd: %h, page size: %h", size, start_vaddr, pd, page_size), UVM_LOW);
        return new_mpt;
    endfunction: create_mr

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
endclass: test_direct
`endif