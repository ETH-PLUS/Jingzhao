//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-17
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_config.sv
//  FUNCTION : This file supplies the case for testing configuration of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-17    v1.0             create
//  mazhenlong      2021-04-29    v1.1             extend gen_item to all cmds
//  mazhenlong      2021-06-26    v1.2             add address management
//                                                 add communication test
//
//----------------------------------------------------------------------------

`ifndef __TEST_CONFIG__
`define __TEST_CONFIG__

//------------------------------------------------------------------------------
//
// CLASS: test_config
//
//------------------------------------------------------------------------------
class test_config extends uvm_test;
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
                // modify_qp(create_qpc());
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
            "test_random_comm": begin
                
            end
        endcase
    endtask: gen_item

    task init_hca();
        hca_pcie_item init_hca_item;
        init_hca_item = hca_pcie_item::type_id::create("init_hca_item", this);
        init_hca_item.randomize() with {hcr_op == `CMD_INIT_HCA;};
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
        pcie_item.qp_ctx = qp_ctx;
        pcie_item.randomize() with {hcr_op == `CMD_RST2INIT_QPEE;};// qp_num == 2;};
        
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: modify_qp

    //------------------------------------------------------------------------------
    // task name     : query_qp
    // function      : generate and send query qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_qp(int qpn);
        pcie_item = hca_pcie_item::type_id::create("pcie_item", this);
        pcie_item.randomize() with {hcr_op == `CMD_QUERY_QP; hcr_in_modifier == qpn;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: query_qp

    function bit [63:0] write_mtt(bit [63:0] start_index); // input is the ICM virtual address of mtt item
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
        `uvm_info("MTT_MOTICE", $sformatf("write_mtt phys addr: %h", temp), UVM_LOW);
        `uvm_info("MTT_MOTICE", $sformatf("write_mtt start index: %h", start_index), UVM_LOW);
        return temp;
    endfunction: write_mtt

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
        pcie_item.mpt_item = mpt_item;
        pcie_item.randomize() with {hcr_op == `CMD_SW2HW_MPT;};
        vseq.cfg_item_que[0].push_back(pcie_item);
    endtask: sw2hw_mpt

    task post_db(doorbell db);
        pcie_item = hca_pcie_item::type_id::create("db_item", this);
        pcie_item.item_type = DOORBELL;
        pcie_item.db = db;
        vseq.comm_item_que[0].push_back(pcie_item);
    endtask: post_db

    function bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] trans2comb(bit [255:0] raw_data);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] result;
        for (int i = 0; i < 32; i++) begin
            result[i] = raw_data[i * 8 + 7 -: 8];
        end
        return result;
    endfunction
endclass: test_config
`endif