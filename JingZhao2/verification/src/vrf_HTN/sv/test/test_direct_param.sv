//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-07-30
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_direct_param.sv
//  FUNCTION : This file supplies the case for testing configuration of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-07-30    v1.0             create
//  mazhenlong      2022-07-03    v1.1             fix wqe start address bug
//
//----------------------------------------------------------------------------

`ifndef __TEST_DIRECT_PARAM__
`define __TEST_DIRECT_PARAM__

//------------------------------------------------------------------------------
//
// CLASS: test_direct
//
//------------------------------------------------------------------------------
class test_direct_param extends uvm_test;
    string seq_name;
    // string serv_type;
    // string comm_type;
    string data_unit;
    hca_env env;
    hca_vsequence vseq;
    hca_pcie_item pcie_item;
    hca_fifo #(.width(256)) data_fifo;
    bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    int host_num;
    int proc_num;
    int db_num;
    int wqe_num;
    int page_num;
    int sg_num;
    int rc_qp_num;
    string case_id;
    int uc_qp_num;
    int ud_qp_num;
    int write_wqe_num;
    int read_wqe_num;
    int send_wqe_num;
    int recv_wqe_num;
    hca_queue_list q_list;
    hca_icm_vaddr icm_vaddr;
    hca_mem_info mem_info;
    hca_math_func math;
    hca_config_agent cfg_agt;
    hca_check_mem_list check_list;
    mailbox glb_stop_mbx;
    int max_sg_num = 6;
    string begin_time;
    string end_time;
    int fp;
    
    bit      [31:0]                wqe_data_count; // data amount in every WQE
    int raw_data_cnt;
    int sg_data_cnt; // data amount in every sg entry

    `uvm_component_utils(test_direct_param)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "test_direct_param", uvm_component parent=null);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates env and sequence.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        begin_time = get_sys_time();

        // if (!$value$plusargs("CASE_NAME=%s", seq_name)) begin
        //     `uvm_fatal("PARAM_ERROR", "seq name not get!");
        // end

        if (!$value$plusargs("HOST_NUM=%d", host_num)) begin
            `uvm_fatal("PARAM_ERROR", "host num not get!");
        end
        if (host_num > `MAX_HOST_NUM) begin
            `uvm_fatal("PARAM_ERROR", "host num maximum exceeded!");
        end

        if (!$value$plusargs("CASEID=%s", case_id)) begin
            `uvm_fatal("PARAM_ERROR", "case_id not get!");
        end

        if (!$value$plusargs("PROC_NUM=%d", proc_num)) begin
            `uvm_fatal("PARAM_ERROR", "process num not get!");
        end
        if (proc_num > `MAX_PROC_NUM) begin
            `uvm_fatal("PARAM_ERROR", "process num maximum exceeded!");
        end
        if (proc_num < 2) begin
            `uvm_fatal("PARAM_ERROR", "process num should be larger than 1!");
        end

        if (!$value$plusargs("DB_NUM=%d", db_num)) begin
            `uvm_fatal("PARAM_ERROR", "doorbell num not get!");
        end
        if (db_num > `MAX_DB_NUM) begin
            `uvm_fatal("PARAM_ERROR", "doorbell num maximum exceeded!");
        end

        // if (!$value$plusargs("HCA_PAGE_NUM=%d", page_num)) begin
        //     `uvm_fatal("PARAM_ERROR", "page num not get!");
        // end
        // if(page_num > `MAX_PAGE_NUM) begin
        //     `uvm_fatal("PARAM_ERROR", "page num maximum exceeded!");
        // end

        if (!$value$plusargs("DATA_CNT=%d", raw_data_cnt)) begin
            `uvm_fatal("PARAM_ERROR", "sg_data_count not get!");
        end

        if (!$value$plusargs("DATA_UNIT=%s", data_unit)) begin
            `uvm_fatal("PARAM_ERROR", "data_unit not get!");
        end
        if (data_unit == "B") begin
            sg_data_cnt = raw_data_cnt;
        end
        else if (data_unit == "KB") begin
            sg_data_cnt = raw_data_cnt * 1024;
        end
        else if (data_unit == "MB") begin
            sg_data_cnt = raw_data_cnt * 1024 * 1024;
        end
        else if (data_unit == "GB") begin
            sg_data_cnt = raw_data_cnt * 1024 * 1024 * 1024;
        end
        else begin
            `uvm_fatal("PARAM_ERROR", "Illegal data_unit!");
        end

        if (!$value$plusargs("SG_NUM=%d", sg_num)) begin
            `uvm_fatal("PARAM_ERROR", "sg num not get!");
        end
        if (sg_num > max_sg_num) begin
            `uvm_fatal("PARAM_ERROR", $sformatf("sg num exceeds maximum: %0d, set: %0d!", max_sg_num, sg_num));
        end

        if (!$value$plusargs("RC_QP_NUM=%d", rc_qp_num)) begin
            `uvm_fatal("PARAM_ERROR", "RC QP num not get!");
        end
        if (!$value$plusargs("UC_QP_NUM=%d", uc_qp_num)) begin
            `uvm_fatal("PARAM_ERROR", "UC QP num not get!");
        end
        if (!$value$plusargs("UD_QP_NUM=%d", ud_qp_num)) begin
            `uvm_fatal("PARAM_ERROR", "UD QP num not get!");
        end
        if (rc_qp_num + uc_qp_num + ud_qp_num > `MAX_QP_NUM) begin
            `uvm_fatal("PARAM_ERROR", $sformatf("Too many QPs!"));
        end

        if (!$value$plusargs("WRITE_WQE_NUM=%d", write_wqe_num)) begin
            `uvm_fatal("PARAM_ERROR", "WRITE WQE num not get!");
        end
        if (!$value$plusargs("READ_WQE_NUM=%d", read_wqe_num)) begin
            `uvm_fatal("PARAM_ERROR", "READ WQE num not get!");
        end
        if (!$value$plusargs("SEND_WQE_NUM=%d", send_wqe_num)) begin
            `uvm_fatal("PARAM_ERROR", "SEND WQE num not get!");
        end
        if (!$value$plusargs("RECV_WQE_NUM=%d", recv_wqe_num)) begin
            `uvm_fatal("PARAM_ERROR", "RECV WQE num not get!");
        end
        if (send_wqe_num != recv_wqe_num) begin
            `uvm_fatal("PARAM_ERROR", "send_wqe_num != recv_wqe_num!");
        end
        if (write_wqe_num + read_wqe_num + send_wqe_num > `MAX_WQE_NUM) begin
            `uvm_fatal("PARAM_ERROR", "Too many WQEs!");
        end

        wqe_num = write_wqe_num + recv_wqe_num + read_wqe_num + send_wqe_num;

        env = hca_env::type_id::create("env", this);
        env.host_num = this.host_num;
        vseq = hca_vsequence::type_id::create("vseq", this);
        vseq.init(this.host_num);
        data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");
        math = hca_math_func::type_id::create("math");

        q_list = hca_queue_list::type_id::create("q_list");
        q_list.init(host_num);

        icm_vaddr = hca_icm_vaddr::type_id::create("icm_vaddr");
        icm_vaddr.init(host_num);

        mem_info = hca_mem_info::type_id::create("mem_info");
        mem_info.init(host_num);

        cfg_agt = hca_config_agent::type_id::create("cfg_agt");
        cfg_agt.init(vseq, icm_vaddr, mem_info);

        check_list = hca_check_mem_list::type_id::create("check_list");
        check_list.init(host_num);

        glb_stop_mbx = new();
        uvm_config_db#(mailbox)::set(uvm_root::get(), "*.env.scb*", "glb_stop_mbx", glb_stop_mbx);
        `uvm_info("NOTICE", "global stop mailbox send finished!", UVM_LOW);

        uvm_config_db#(hca_queue_list)::set(uvm_root::get(), "*.env.rm*", "q_list", q_list);
        `uvm_info("NOTICE", "queue list sent to rm finished!", UVM_LOW);

        uvm_config_db#(hca_queue_list)::set(uvm_root::get(), "*.slv_*", "q_list", q_list);
        `uvm_info("NOTICE", "queue list sent to slave finished!", UVM_LOW);

        uvm_config_db#(hca_icm_vaddr)::set(uvm_root::get(), "*.env.rm*", "icm_vaddr", icm_vaddr);
        `uvm_info("NOTICE", "icm vaddr send finished!", UVM_LOW);

        uvm_config_db#(hca_mem_info)::set(uvm_root::get(), "*.env.rm*", "mem_info", mem_info);
        `uvm_info("NOTICE", "mem info send finished!", UVM_LOW);

        uvm_config_db#(hca_queue_list)::set(uvm_root::get(), "*.env.scb", "q_list", q_list);
        `uvm_info("NOTICE", "q_list send finished!", UVM_LOW);

        uvm_config_db#(hca_check_mem_list)::set(uvm_root::get(), "*.env.scb", "check_list", check_list);
        `uvm_info("NOTICE", "check_list send finished!", UVM_LOW);

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
            vseq.slv_seq[i].mem = env.mem[i];
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
        fork
            begin
                wqe_data_count = sg_num * sg_data_cnt;
                test_direct();
                `uvm_info("NOTICE", "generate item finished!", UVM_LOW)
            end
            begin
                vseq.starting_phase = phase;
                vseq.start(env.vsqr, , , 1);
                `uvm_info("NOTICE", "vseq finished!", UVM_LOW)
            end
        join
        phase.drop_objection(this);
    endtask: main_phase

    //------------------------------------------------------------------------------
    // function name : report_phase
    // function      : print result and time
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        end_time = get_sys_time();
        `uvm_info("TIME_INFO", $sformatf("begin time: %s", begin_time), UVM_LOW);
        `uvm_info("TIME_INFO", $sformatf("end time: %s", end_time), UVM_LOW);
    endfunction: report_phase

    function string get_sys_time();
        string sys_time;
        int fp;
        $system("date +%Y-%m-%d' '%H:%M:%S > sys_time");
        fp = $fopen("sys_time", "r");
        $fgets(sys_time, fp);
        $fclose(fp);
        $system("rm sys_time");
        return sys_time;
    endfunction: get_sys_time

    //------------------------------------------------------------------------------
    // task name     : test_direct
    // function      : initialize HCA, create CQs and QPs, connect QPs, write data, 
    //                 write WQEs, send doorbell
    // invoked       : by gen_item_seq
    //------------------------------------------------------------------------------
    task test_direct();
        int proc_id = 1;

        // initialize HCA
        for (int host_id = 0; host_id < host_num; host_id++) begin
			cfg_agt.query_adapter(host_id);
            cfg_agt.init_hca(host_id);
            // cfg_agt.write_ivt(host_id);
        end

        // create EQ, CQ and QP
        for (int host_id = 0; host_id < host_num; host_id++) begin
            fork
                automatic int a_host_id = host_id;
                begin
                    e_service_type service_type;
                    addr cqc_start_addr;
                    addr qpc_start_addr;
                    hca_queue_pair qp;
                    hca_comp_queue temp_cq;
                    bit [31:0] pd;

                    // create RC QPs
                    for (int i = 0; i < rc_qp_num; i++) begin
                        pd = $urandom();
                        service_type = RC;

                        // create CQ
                        // cqc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_CQC_TYP, 1); // is this enough?
                        temp_cq = create_cq(proc_id, a_host_id, pd);

                        // create QP, should data MR be created here?
                        // qpc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_QPC_TYP, 1); // is this enough?
                        qp = create_qp(proc_id, a_host_id, pd, service_type, temp_cq, temp_cq);
                    end

                    // create UC QPs
                    for (int i = 0; i < uc_qp_num; i++) begin
                        pd = $urandom();
                        service_type = UC;
                        
                        // create CQ
                        // cqc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_CQC_TYP, 1); // is this enough?
                        temp_cq = create_cq(proc_id, a_host_id, pd);

                        // create QP, should data MR be created here?
                        // qpc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_QPC_TYP, 1); // is this enough?
                        qp = create_qp(proc_id, a_host_id, pd, service_type, temp_cq, temp_cq);
                    end

                    // create UD QPs
                    for (int i = 0; i < ud_qp_num; i++) begin
                        pd = $urandom();
                        service_type = UD;
                        
                        // create CQ
                        // cqc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_CQC_TYP, 1); // is this enough?
                        temp_cq = create_cq(proc_id, a_host_id, pd);

                        // create QP, should data MR be created here?
                        // qpc_start_addr = cfg_agt.map_icm(a_host_id, `ICM_QPC_TYP, 1); // is this enough?
                        qp = create_qp(proc_id, a_host_id, pd, service_type, temp_cq, temp_cq);
                    end
                end
            join_none
        end
        wait fork;

        // connect QP, QP[2n] in host 0 is connected with QP[2n+1] in host 1 and vice versa
        // WARNING: only support TWO hosts
        // QPs of UD should not be connected, but this can be ignored here
        for (int i = 0; i < q_list.qp_list[0].size(); i++) begin
            hca_queue_pair qp_a;
            hca_queue_pair qp_b;
            int flag = 0;
            qp_a = q_list.qp_list[0][i];
            // if (qp_a.ctx.flags[15:0] != 16'h0000 || qp_a.ctx.flags[15:0] != 16'h0001) begin
            //     continue;
            // end
            if (qp_a.ctx.local_qpn % 2 == 0) begin
                for (int j = 0; j < q_list.qp_list[1].size(); j++) begin
                    if (q_list.qp_list[1][j].ctx.local_qpn == qp_a.ctx.local_qpn + 1) begin
                        qp_b = q_list.qp_list[1][j];
                        connect_qp(0, qp_a, 1, qp_b);
                        flag = 1;
                        break;
                    end
                end
                // if not found qp_b
                if (flag == 0) begin
                    `uvm_fatal("CONNECT_QP_ERR", $sformatf("qp_b not found! qp_a: %h", qp_a.ctx.local_qpn));
                end
            end
            else begin
                for (int j = 0; j < q_list.qp_list[1].size(); j++) begin
                    if (q_list.qp_list[1][j].ctx.local_qpn == qp_a.ctx.local_qpn - 1) begin
                        qp_b = q_list.qp_list[1][j];
                        connect_qp(0, qp_a, 1, qp_b);
                        flag = 1;
                        break;
                    end
                end
                // if not found qp_b
                if (flag == 0) begin
                    `uvm_fatal("CONNECT_QP_ERR", $sformatf("qp_b not found! qp_a: %h", qp_a.ctx.local_qpn));
                end
            end
            `ifdef QUERY_QP_TEST
                cfg_agt.query_qp(0, qp_a.ctx.local_qpn);
                cfg_agt.query_qp(1, qp_b.ctx.local_qpn);
            `endif
        end

        // write data into data region
        for (int host_id = 0; host_id < host_num; host_id++) begin
            for (int i = 0; i < q_list.qp_list[host_id].size(); i++) begin
                hca_queue_pair qp;
                addr data_paddr;
                addr data_vaddr;
                qp = q_list.qp_list[host_id][i];
                data_paddr = `PA_DATA(proc_id, qp.ctx.local_qpn);
                data_vaddr = `VA(data_paddr);
                write_test_data(host_id, data_paddr, db_num * wqe_data_count * wqe_num);
            end
            `uvm_info("NOTICE", "write test data finished!", UVM_LOW);
        end

        for (int db_id = 0; db_id < db_num; db_id++) begin
            // create data MR, create WQE and write
            for (int host_id = 0; host_id < host_num; host_id++) begin
                // for every QP
                for (int i = 0; i < q_list.qp_list[host_id].size(); i++) begin
                    fork
                        automatic int j = i;
                        begin
                            hca_queue_pair qp;
                            qp = q_list.qp_list[host_id][j];
                            create_and_write_wqes(qp, db_id, wqe_data_count, send_wqe_num, recv_wqe_num, read_wqe_num, write_wqe_num, sg_num, sg_data_cnt);
                        end
                    join_none
                end
                wait fork;
            end

            for (int host_id = 0; host_id < host_num; host_id++) begin
                hca_pcie_item batch_item;
                batch_item = hca_pcie_item::type_id::create("BATCH_ITEM", this);
                batch_item.item_type = BATCH;
                vseq.cfg_mbx[host_id].put(batch_item);
            end

            // write doorbell
            for (int host_id = 0; host_id < host_num; host_id++) begin

                //only host 0 can send
                if (host_id == 1) begin
                    break;
                end
                
                fork
                    automatic int a_host_id = host_id;
                    // for every host
                    begin
                        for (int i = 0; i < q_list.qp_list[a_host_id].size(); i++) begin
                            fork
                                automatic int j = i;
                                begin
                                    hca_queue_pair qp;
                                    bit [4:0] opcode;
                                    qp = q_list.qp_list[a_host_id][j];
                                    if (send_wqe_num != 0) begin
                                        opcode = `VERBS_SEND;
                                        send_db(a_host_id, proc_id, db_id, qp, opcode);
                                    end
                                    else if (write_wqe_num != 0 && qp.ctx.flags[23:16] != `HGHCA_QP_ST_UD) begin
                                        opcode = `VERBS_RDMA_WRITE;
                                        send_db(a_host_id, proc_id, db_id, qp, opcode);
                                    end
                                    else if (read_wqe_num != 0 && qp.ctx.flags[23:16] == `HGHCA_QP_ST_RC) begin
                                        opcode = `VERBS_RDMA_READ;
                                        send_db(a_host_id, proc_id, db_id, qp, opcode);
                                    end
                                    else begin
                                        `uvm_info("DB_INFO", $sformatf("useless QP! qpn: %h", qp.ctx.local_qpn), UVM_LOW);
                                    end
                                end
                            join_none
                        end
                        wait fork;
                    end
                join_none
            end
            wait fork;

            global_stop(db_id, db_num);
            for (int host_id = 0; host_id < host_num; host_id++) begin
                hca_pcie_item batch_item;
                batch_item = hca_pcie_item::type_id::create("BATCH_ITEM", this);
                batch_item.item_type = BATCH;
                vseq.comm_mbx[host_id].put(batch_item);
            end
        end
    endtask: test_direct

    //------------------------------------------------------------------------------
    // task name     : create_and_write_wqes
    // function      : create memory regions for data and generate WQEs of a certain 
    //                 communication type in one QP, cmd parameters should not be used
    //                 in this function.
    //                 this task should be implemented in hca_queue_pair
    // invoked       : by test_direct
    //------------------------------------------------------------------------------
    function create_and_write_wqes(
        hca_queue_pair qp,
        int db_id,
        bit [31:0] wqe_data_count,
        int send_wqe_num,
        int recv_wqe_num,
        int read_wqe_num,
        int write_wqe_num,
        int sg_num,
        bit [31:0] sg_entry_data_count
    );
        mpt local_mpt;
        mpt remote_mpt;
        mpt sq_local_mpt_que[$];    // sg entry mpt in SQ data seg
        mpt sq_remote_mpt_que[$];
        mpt rq_send_mpt_que[$];
        mpt rq_recv_mpt_que[$];
        addr sq_local_offset_que[$];
        addr sq_remote_offset_que[$];
        addr rq_send_offset_que[$];
        addr rq_recv_offset_que[$];
        e_op_type sq_op_que[$];
        e_op_type rq_op_que[$];
        hca_queue_pair remote_qp;
        bit [31:0] remote_qpn;

        int remote_host_id;
        int host_id;
        bit [10:0] proc_id;
        // int sq_wqe_num = send_wqe_num + read_wqe_num + write_wqe_num;

        host_id = qp.host_id;
        proc_id = qp.proc_id;
        remote_qp = qp.remote_qp;
        // remote_qpn = remote_qp.ctx.local_qpn;


        if (host_id == 0) begin
            remote_host_id = 1;
        end
        else begin
            remote_host_id = 0;
        end

        // host 1 is not sender
        if (host_id == 1) begin
            return;
        end

        /*------------------------------------------------------------------
        // MEMORY SPACE FOR NETWORK DATA
        // RC:
        // |    SEND    |  RECEIVE  |   WRITE   |   READ    |
        // UC:
        // |    SEND    |  RECEIVE  |   WRITE   |
        // UD:
        // |    SEND    |  RECEIVE  |
        ------------------------------------------------------------------*/
        // create data memory regions and put WQEs into mpt queue
        for (int wqe_id = 0; wqe_id < send_wqe_num + recv_wqe_num + write_wqe_num + read_wqe_num; wqe_id++) begin
            if (wqe_id < send_wqe_num) begin // SEND
                // start physical address of THIS DOORBELL
                addr src_paddr = `PA_DATA(proc_id, qp.ctx.local_qpn) + db_id * this.wqe_num * wqe_data_count; 
                addr src_vaddr = `VA(src_paddr);
                // start physical address of RECV buffer corresponding to SEND above
                addr dst_paddr = `PA_DATA(proc_id, qp.ctx.remote_qpn) + `DATA_RECV_BUFF_GAP + db_id * this.wqe_num * wqe_data_count;
                addr dst_vaddr = `VA(dst_paddr);
                for (int sg_id = 0; sg_id < sg_num; sg_id++) begin
                    // create MR for sending data
                    local_mpt = create_mr(
                        host_id, 
                        proc_id, 
                        sg_entry_data_count, 
                        src_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count, 
                        qp.ctx.pd, 
                        `PAGE_SIZE, 
                        FALSE, 
                        8'b1000_0111
                    );
                    sq_local_mpt_que.push_back(local_mpt);
                    rq_send_mpt_que.push_back(local_mpt);

                    // set sg entry address offset relative to start address of memory region
                    sq_local_offset_que.push_back(src_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count - local_mpt.start);
                    rq_send_offset_que.push_back(src_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count - local_mpt.start);
                end
                sq_op_que.push_back(SEND);
                for (int sg_id = 0; sg_id < sg_num; sg_id++) begin
                    // create MR for data buffer
                    remote_mpt = create_mr(
                        remote_host_id, 
                        proc_id, 
                        sg_entry_data_count, 
                        dst_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count, 
                        remote_qp.ctx.pd, 
                        `PAGE_SIZE, 
                        FALSE, 
                        8'b1000_0111
                    );
                    rq_recv_mpt_que.push_back(remote_mpt);
                    rq_recv_offset_que.push_back(dst_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count - remote_mpt.start);
                end
                rq_op_que.push_back(RECV);
            end
            else if (wqe_id < send_wqe_num + recv_wqe_num) begin // RECEIVE
                // no need to work here
            end
            else if (wqe_id < send_wqe_num + recv_wqe_num + write_wqe_num) begin // WRITE
                // start physical address of WRITE source data
                addr src_paddr = `PA_DATA(proc_id, qp.ctx.local_qpn) + db_id * this.wqe_num * wqe_data_count;
                addr src_vaddr = `VA(src_paddr);
                // start physical address of WRITE buffer in receiver side
                addr dst_paddr = `PA_DATA(proc_id, qp.ctx.remote_qpn) + `DATA_RECV_BUFF_GAP + db_id * this.wqe_num * wqe_data_count;
                addr dst_vaddr = `VA(dst_paddr);

                if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD) begin
                    break;
                end
                // create data mpt and recv mpt
                for (int sg_id = 0; sg_id < sg_num; sg_id++) begin
                    local_mpt = create_mr(
                        host_id, 
                        proc_id, 
                        sg_entry_data_count, 
                        src_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count,
                        qp.ctx.pd, 
                        `PAGE_SIZE, 
                        FALSE, 
                        8'b1000_0111
                    );
                    sq_local_mpt_que.push_back(local_mpt);
                    sq_local_offset_que.push_back(src_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count - local_mpt.start);
                end
                remote_mpt = create_mr(
                    remote_host_id,
                    proc_id,
                    wqe_data_count,
                    dst_vaddr + wqe_id * wqe_data_count,
                    remote_qp.ctx.pd,
                    `PAGE_SIZE,
                    FALSE,
                    8'b1000_0111
                );
                sq_remote_mpt_que.push_back(remote_mpt);
                sq_remote_offset_que.push_back(dst_vaddr + wqe_id * wqe_data_count - remote_mpt.start);

                sq_op_que.push_back(WRITE);
            end
            else if (wqe_id < send_wqe_num + recv_wqe_num + write_wqe_num + read_wqe_num) begin // READ
                // start physical address of READ source data
                addr src_paddr = `PA_DATA(proc_id, qp.ctx.remote_qpn) + db_id * this.wqe_num * wqe_data_count;
                addr src_vaddr = `VA(src_paddr);
                // start physical address of READ buffer
                addr dst_paddr = `PA_DATA(proc_id, qp.ctx.local_qpn) + `DATA_RECV_BUFF_GAP + db_id * this.wqe_num * wqe_data_count;
                addr dst_vaddr = `VA(dst_paddr);

                if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD || qp.ctx.flags[23:16] == `HGHCA_QP_ST_UC) begin
                    break;
                end

                // create data mpt and buffer mpt
                remote_mpt = create_mr(
                    remote_host_id, 
                    proc_id, 
                    wqe_data_count, 
                    src_vaddr + wqe_id * wqe_data_count, 
                    remote_qp.ctx.pd, 
                    `PAGE_SIZE, 
                    FALSE, 
                    8'b1000_0111
                );
                sq_remote_mpt_que.push_back(remote_mpt);
                sq_remote_offset_que.push_back(src_vaddr + wqe_id * wqe_data_count - remote_mpt.start);

                for (int sg_id = 0; sg_id < sg_num; sg_id++) begin
                    local_mpt = create_mr(
                        host_id, 
                        proc_id, 
                        sg_entry_data_count, 
                        dst_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count, 
                        qp.ctx.pd, 
                        `PAGE_SIZE, 
                        FALSE, 
                        8'b1000_0111
                    );
                    sq_local_mpt_que.push_back(local_mpt);
                    sq_local_offset_que.push_back(dst_vaddr + wqe_id * wqe_data_count + sg_id * sg_entry_data_count - local_mpt.start);
                end
                sq_op_que.push_back(READ);
            end
            else begin
                `uvm_fatal("WQE_ID_ERR", $sformatf("wqe_id error! wqe_id: %d", wqe_id));
            end
        end
        `uvm_info("INIT_INFO", $sformatf("data memory region created! QP number: %h.", qp.ctx.local_qpn), UVM_LOW);
        // put SQ WQEs
        qp.put_wqe(
            sq_op_que,
            sq_local_mpt_que,
            sq_remote_mpt_que,
            sq_local_offset_que,
            sq_remote_offset_que,
            q_list,
            check_list,
            sg_num,
            sg_entry_data_count
        );
        // put RQ WQEs
        remote_qp.put_wqe(
            rq_op_que,
            rq_recv_mpt_que,
            rq_send_mpt_que,
            rq_recv_offset_que,
            rq_send_offset_que,
            q_list,
            check_list,
            sg_num,
            sg_entry_data_count
        );
    endfunction: create_and_write_wqes

    //------------------------------------------------------------------------------
    // task name     : global_stop
    // function      : receive global stop signal from scoreboard and inform virtual
    //                 sequence of global stop 
    // invoked       : by test_direct
    //------------------------------------------------------------------------------
    task global_stop(int db_id, int db_num);
        int temp_num;
        hca_pcie_item glb_stop_item;
        `uvm_info("GLB_STOP_INFO", $sformatf("before getting global stop signal"), UVM_LOW);
        glb_stop_mbx.get(temp_num);
        if (db_id + 1 != db_num) begin
            `uvm_info("GLB_STOP_INFO", $sformatf("db_id: %h, db_num: %h", db_id, db_num), UVM_LOW)
            return;
        end
        else begin
            `uvm_info("GLB_STOP_INFO", $sformatf("global stop signal get in test! db_id: %h, db_num: %h", db_id, db_num), UVM_LOW);
            glb_stop_item = hca_pcie_item::type_id::create("glb_stop_item", this);
            glb_stop_item.item_type = GLOBAL_STOP;
            foreach(vseq.cfg_mbx[i]) begin
                hca_pcie_item glb_stop_item_cfg;
                glb_stop_item_cfg = hca_pcie_item::type_id::create($sformatf("glb_stop_item_cfg[%0d]", i), this);
                glb_stop_item_cfg.copy(glb_stop_item);
                vseq.cfg_mbx[i].put(glb_stop_item_cfg);
                `uvm_info("GLB_STOP_INFO", $sformatf("glb_stop_item sent to vseq.cfg_mbx[%0d]", i), UVM_LOW);
            end
            foreach(vseq.comm_mbx[i]) begin
                vseq.comm_mbx[i].put(glb_stop_item);
                `uvm_info("GLB_STOP_INFO", $sformatf("glb_stop_item sent to vseq.comm_mbx[%0d]", i), UVM_LOW);
            end
        end
    endtask: global_stop

    //------------------------------------------------------------------------------
    // task name     : connect_qp
    // function      : 1) modify QP context in q_list.qp_list
    //                 2) send modify_qp command to dut
    // invoked       : by single_process_cfg
    //------------------------------------------------------------------------------
    function bit connect_qp(int host_id_a, hca_queue_pair qp_a, int host_id_b, hca_queue_pair qp_b);
        // local.next_send_psn == local.unacked_psn == remote.next_recv_psn
        qp_a.ctx.remote_qpn = qp_b.ctx.local_qpn;
        qp_b.ctx.remote_qpn = qp_a.ctx.local_qpn;
        qp_a.ctx.rnr_nextrecvpsn = qp_b.ctx.next_send_psn;
        qp_b.ctx.rnr_nextrecvpsn = qp_a.ctx.next_send_psn;

        qp_a.connect(qp_b);

        cfg_agt.modify_qp(host_id_a, qp_a.ctx);
        cfg_agt.modify_qp(host_id_b, qp_b.ctx);
        `uvm_info("CONNECT_QP_INFO", 
            $sformatf("QP connected! host_a: %h, qp_a: %h, host_b: %h, qp_b: %h", 
                host_id_a, qp_a.ctx.local_qpn, host_id_b, qp_b.ctx.local_qpn), 
            UVM_LOW
        );
    endfunction: connect_qp

    //------------------------------------------------------------------------------
    // task name     : send_db
    // function      : create a doorbell and send it to virtual sequence
    // invoked       : by single_process
    //------------------------------------------------------------------------------
    task send_db(int host_id, bit [10:0] proc_id, int db_id, hca_queue_pair qp, bit [4:0] op_code);
        hca_pcie_item doorbell_item;
        bit [15:0] first_wqe_byte_offset;
        doorbell db;
        doorbell_item = hca_pcie_item::type_id::create("doorbell_item", this);
        first_wqe_byte_offset = qp.sq_last_header % qp.sq_byte_size;
        // What is this?
        if (first_wqe_byte_offset[3:0] != 0) begin
            `uvm_fatal("QP_ERR", $sformatf("first_wqe_byte_offset is not zero! host_id: %h, qpn: %h, sq_tail: %h", 
                host_id, qp.ctx.local_qpn, qp.sq_tail));
        end
        db.sq_head = first_wqe_byte_offset[15:4];
        // first_wqe_byte_offset = db_id * this.wqe_num * `SQ_WQE_BYTE_LEN;
        // db.sq_head = db_id * this.wqe_num * `SQ_WQE_BYTE_LEN;
        db.f0 = 0;
        db.opcode = op_code;
        db.qp_num = qp.ctx.local_qpn;
        // db.host_id = host_id;
        
        // set size0
        if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD) begin
            if (op_code == `VERBS_SEND) begin
                db.size0 = sg_num + 4;
            end
            else begin
                `uvm_fatal("OP TYPE ERROR", $sformatf("op type error! qpn: %h, host id: %h, op code: %h", qp.ctx.local_qpn, host_id, op_code));
            end
        end
        else begin
            if (op_code == `VERBS_SEND) begin
                db.size0 = sg_num + 1;
            end
            else begin
                db.size0 = sg_num + 2;
            end
        end
        db.proc_id = proc_id;
        doorbell_item.item_type = DOORBELL;
        doorbell_item.db = db;
        if (vseq.comm_mbx[host_id].try_put(doorbell_item) == 0) begin
            `uvm_fatal("MAILBOX_PUT_ERROR", "put comm item fail!")
        end
        `uvm_info("NOTICE", $sformatf("send doorbell finished! host id: %h, QP number: %h", host_id, db.qp_num), UVM_LOW);
    endtask: send_db

    function hca_queue_pair create_qp(
        bit [10:0] proc_id, 
        int host_id, 
        bit [31:0] pd, 
        e_service_type serv_typ, 
        hca_comp_queue send_cq, 
        hca_comp_queue recv_cq
    );
        //bit [31:0] qp_num = 0;
        bit [31:0] qp_num = 14;
        qp_context qpc;
        mpt sq_mpt;
        mpt rq_mpt;
        addr qp_start_vaddr;
        int qp_vaddr_offset;
        addr temp_addr;
        hca_queue_pair qp;

        for (int i = 0; i < q_list.qp_list[host_id].size(); i++) begin
            if (q_list.qp_list[host_id][i].ctx.local_qpn == qp_num) begin
                qp_num++;
            end
        end

        qp_vaddr_offset = qp_num * `MAX_DESC_SZ * `MAX_QP_SZ;
        qp_start_vaddr = `VA_QP(qp_num);
        // create qp mr
        `uvm_info("NOTICE", $sformatf("before create mr, qp_num: %h, start_vaddr: %h", qp_num, qp_start_vaddr), UVM_LOW);
        sq_mpt = create_mr(host_id, proc_id, `VRF_SQ_BYTE_SIZE, qp_start_vaddr, pd, `PAGE_SIZE, TRUE, 8'b1000_0011);
        rq_mpt = create_mr(host_id, proc_id, `VRF_RQ_BYTE_SIZE, qp_start_vaddr + `SQ_RQ_GAP, pd, `PAGE_SIZE, TRUE, 8'b1000_0011);

        if (icm_vaddr.qpc_cap_left[host_id] < `QPC_ENTRY_SZ) begin
            cfg_agt.map_icm(host_id, `ICM_QPC_TYP, 1);
        end
        icm_vaddr.qpc_cap_left[host_id] -= `QPC_ENTRY_SZ;
        if (icm_vaddr.qpc_cap_left[host_id] < 0) begin
            `uvm_fatal("ICM_ERR", $sformatf("ICM CAPACITY OUT!"));
        end
        // set QP context
        qpc.opt_param_mask = $urandom();
        qpc.flags[31:28] = 4'b0011;
        qpc.flags[27:24] = 4'b0000;
        qpc.flags[15:0] = 16'b0;
        case (serv_typ)
            RC: begin
                qpc.flags[23:16] = 8'h00;
            end
            UC: begin
                qpc.flags[23:16] = 8'h01;
            end
            RD: begin
                qpc.flags[23:16] = 8'h02;
            end
            UD: begin
                qpc.flags[23:16] = 8'h03;
            end
            default: begin
                `uvm_fatal("CREATE_QP_ERR", "invalid service type!");
            end
        endcase
        qpc.mtu_msgmax                  = {`QPC_MTU_4096, 5'b11111};
        qpc.rq_entry_sz_log             = math.log_func(`RQ_WQE_BYTE_LEN);
        qpc.sq_entry_sz_log             = math.log_func(`SQ_WQE_BYTE_LEN);
        qpc.local_qpn                   = qp_num;
        qpc.remote_qpn                  = qp_num;
        qpc.port_pkey                   = 0;
        qpc.rnr_retry                   = 0;
        qpc.smac                        = {48'h123456789abc};
        qpc.dmac                        = {48'hcba987654321};
        qpc.sip                         = {32'ha0b1c2d3};
        qpc.dip                         = {32'hd4c5b6a7};
        qpc.pd                          = pd;
        qpc.next_send_psn               = $urandom();
        qpc.cqn_snd                     = send_cq.ctx.cqn;
        qpc.cqn_rcv                     = recv_cq.ctx.cqn;
        qpc.snd_wqe_base_l              = sq_mpt.key;
        qpc.snd_wqe_len                 = `VRF_SQ_BYTE_SIZE;
        qpc.last_acked_psn              = qpc.next_send_psn;
        qpc.rnr_nextrecvpsn             = qpc.next_send_psn;
        qpc.rcv_wqe_base_l              = rq_mpt.key;
        qpc.rcv_wqe_len                 = `VRF_RQ_BYTE_SIZE;
        cfg_agt.modify_qp(host_id, qpc);

        qp = hca_queue_pair::type_id::create($sformatf("qp%0d", qpc.local_qpn));
        qp.ctx = qpc;
        qp.host_id = host_id;
        qp.proc_id = proc_id;
        qp.mem = env.mem[host_id];
        qp.sq_byte_size = `VRF_SQ_BYTE_SIZE;
        qp.rq_byte_size = `VRF_RQ_BYTE_SIZE;
        // qp.sq_header = 0;
        // qp.sq_tail = 0;
        q_list.qp_list[host_id].push_back(qp);
        `uvm_info("CREATE_QP_INFO", $sformatf("create QP finished! host_id: %h, QP num: %0d, PD: %h, SQ Key: %h, RQ Key: %h", 
            host_id, qp.ctx.local_qpn, qpc.pd, sq_mpt.key, rq_mpt.key), UVM_LOW);
        return qp;
    endfunction: create_qp

    function hca_comp_queue create_cq(bit [10:0] proc_id, int host_id, bit [31:0] pd);
        cq_context cqc;
        mpt cq_mpt;
        addr cq_start_vaddr;
        bit [31:0] cqn = 5;
        hca_comp_queue cq;
        
        // allocate cq number
        for (int i = 0; i < q_list.cq_list[host_id].size(); i++) begin
            if (q_list.cq_list[host_id][i].ctx.cqn == cqn) begin
                cqn++;
            end
        end

        cq_start_vaddr = `VA_CQ(cqn);

        cq_mpt = create_mr(host_id, proc_id, 4096, cq_start_vaddr, pd, `PAGE_SIZE, TRUE, 8'b1000_0011);

        cqc.flags = 32'h0004_0000;
        cqc.start = cq_start_vaddr;
        cqc.logsize = 8'h06;
        cqc.usrpage = 0;
        cqc.comp_eqn = 0;
        cqc.pd = cq_mpt.pd;
        cqc.lkey = cq_mpt.key;
        cqc.cqn = cqn;

        if (icm_vaddr.cqc_cap_left[host_id] < `CQC_ENTRY_SZ) begin
            cfg_agt.map_icm(host_id, `ICM_CQC_TYP, 1);
        end

        cq = hca_comp_queue::type_id::create($sformatf("cq%0d", cqn));
        cq.ctx = cqc;
        cq.header = 0;
        cq.tail = 0;
        q_list.cq_list[host_id].push_back(cq);

        cfg_agt.sw2hw_cq(host_id, cqc);
        return cq;
    endfunction: create_cq

    function mpt create_mr(
        int host_id,
        input bit [10:0] proc_id,
        input bit [63:0] size, 
        input addr start_vaddr,
        input bit [31:0] pd, 
        input bit [31:0] page_size, 
        input bool is_zbva,
        // 0, ON_DEMAND, ZERO_BASED, MW_BIND, REMOTE_ATOMIC, REMOTE_READ, REMOTE_WRITE, LOCAL_WRITE
        input bit [7:0] auth_flag
    );
        mpt new_mpt;
        int mtt_num;
        int mtt_page_num;
        addr temp_addr;
        addr mtt_icm_addr;
        addr mtt_icm_idx;
        addr mpt_icm_addr;
        addr mr_size;
        mtt temp_mtt_item;
        addr mtt_seg;

        for (int i = 0; i < 32; i++) begin
            if (page_size[i] == 1) begin
                if (i < 12) begin
                    `uvm_fatal("ILLEGAL_PAGESIZE", "page_size illegal in create_mr()!");
                end
                else begin
                    new_mpt.page_size = i - 12;
                    break;
                end
            end
        end

        // set amount of mtt entries and size of memory region
        // if (size % page_size == 0) begin
        //     mtt_num = size / page_size;
        // end
        // else begin
        //     mtt_num = size / page_size + 1;
        // end
        if ((size + start_vaddr[11:0]) % page_size == 0) begin
            mtt_num = (size + start_vaddr[11:0]) / page_size;
            mr_size = mtt_num * `PAGE_SIZE;
        end
        else begin
            mtt_num = (size + start_vaddr[11:0]) / page_size + 1;
            mr_size = mtt_num * `PAGE_SIZE;
        end

        // set amount of pages for mtt in ICM space
        if (mtt_num % 512 == 0) begin
            mtt_page_num = mtt_num / 512;
        end
        else begin
            mtt_page_num = mtt_num / 512 + 1;
        end

        // allocate space for MTT in ICM space
        if (icm_vaddr.mtt_cap_left[host_id] < mtt_num * 8) begin
            mtt_icm_addr = cfg_agt.map_icm(host_id, `ICM_MTT_TYP, mtt_page_num);
        end

        // allocate space for MPT in ICM space
        if (icm_vaddr.mpt_cap_left[host_id] < `MPT_ITEM_SIZE) begin
            mpt_icm_addr = cfg_agt.map_icm(host_id, `ICM_MPT_TYP, 1);
        end

        // write MTT entries of new MR
        // number of MTT entries should be no larger than 255, or otherwise configuration would fail
        for (int mtt_num_sent = 0; mtt_num_sent < mtt_num; mtt_num_sent = mtt_num_sent + 255) begin
            // mtt seg is the header index of the whole MR mtt entries
            if (mtt_num_sent == 0) begin
                if (mtt_num <= 255) begin
                    mtt_seg = cfg_agt.write_mtt(host_id, {5'b0, proc_id, start_vaddr[47:12], 12'b0}, mtt_num);
                end
                else begin
                    mtt_seg = cfg_agt.write_mtt(host_id, {5'b0, proc_id, start_vaddr[47:12], 12'b0}, 255);
                end
            end
            else if (mtt_num_sent + 255 <= mtt_num) begin
                cfg_agt.write_mtt(host_id, {5'b0, proc_id, start_vaddr[47:12], 12'b0} + mtt_num_sent * 4096, 255);
            end
            else begin
                cfg_agt.write_mtt(host_id, {5'b0, proc_id, start_vaddr[47:12], 12'b0} + mtt_num_sent * 4096, mtt_num - mtt_num_sent);
            end
        end

        /////////////////////////////////////////////////////////////////////////
        //   SW_OWNS  MIO  BIND_ENABLE  PHYSICAL  REGION  LOCAL_WRITE  REMOTE_WRITE  REMOTE_READ  REMOTE_ATOMIC  MW_BIND  ZERO_BASED  ON_DEMAND
        new_mpt.flags = {16'hf002, auth_flag}; // 32'b1111_0000_0000_0010_0000_0001_1000_0011
        new_mpt.length = mr_size;
        if (is_zbva == TRUE) begin
            new_mpt.start = 0;
        end
        else begin
            new_mpt.start = {start_vaddr[63:12], 12'b0};
        end
        new_mpt.pd = pd;
        new_mpt.mtt_seg = mtt_seg;
        new_mpt.key = mem_info.mem_region[host_id].size();

        cfg_agt.sw2hw_mpt(host_id, new_mpt);
        `uvm_info("CREATE_MR_NOTICE", 
            $sformatf("create mr success! host_id: %h, key: %h, input start vaddr: %h, MR start vaddr: %h, input size: %h, MR size: %h, pd: %h, page size: %h", 
                host_id, new_mpt.key, start_vaddr, new_mpt.start, size, mr_size, pd, page_size), UVM_LOW);
        return new_mpt;
    endfunction: create_mr

    function write_test_data(int host_id, addr phys_addr, bit [31:0] data_cnt);
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
                // write_data[j] = (i * 32 + j) % 256;
                write_data[j] = $urandom();
            end
            data_fifo.push(write_data);
            `uvm_info("DATA_NOTICE", $sformatf("write data: %h, phys_addr: %h, data count: %h, beat_id: %h, host id: %h", 
                write_data, phys_addr, data_cnt, i, host_id), UVM_LOW
            );
            write_data = 0;
        end
        env.mem[host_id].write_block(phys_addr, data_fifo, data_cnt);
        `uvm_info("TEST_NOTICE", $sformatf("send data start physical addr: %h, data count: %0d, host id: %h", phys_addr, data_cnt, host_id), UVM_LOW);
        data_fifo.clean();
    endfunction: write_test_data
endclass: test_direct_param
`endif
