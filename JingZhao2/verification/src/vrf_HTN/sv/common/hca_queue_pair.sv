//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-09-01
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_queue_pair.sv
//  FUNCTION : This file supplies the env of verification of HCA.
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-09-01    v1.0             create
//  mazhenlong      2021-09-17    v1.1             add RQ support
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_QUEUE_PAIR__
`define __HCA_QUEUE_PAIR__

typedef class hca_queue_list;

//----------------------------------------------------------------------------
//
// CLASS: hca_queue_pair
//
//----------------------------------------------------------------------------
class hca_queue_pair extends uvm_object;

    qp_context ctx;
    hca_queue_pair remote_qp;
    hca_memory mem;

    int host_id;
    bit [10:0] proc_id;

    bit [31:0] sq_byte_size;
    bit [31:0] rq_byte_size;

    bit [15:0] sq_desc_byte_size;
    bit [15:0] rq_desc_byte_size;

    bool is_connect;

    // header: producer pointer, byte
    // tail: consumer pointer, byte
    addr    sq_header;
    addr    sq_tail;
    addr    sq_last_header;

    addr    rq_header;
    addr    rq_tail;
    addr    rq_last_header;

    wqe     sq[$];
    wqe     rq[$];

    `uvm_object_utils_begin(hca_queue_pair)
    `uvm_object_utils_end

    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_queue_pair");
        super.new(name);
        sq_header = 0;
        sq_tail = 0;
        sq_last_header = 0;
        rq_header = 0;
        rq_tail = 0;
        rq_last_header = 0;
        is_connect = FALSE;
    endfunction: new

    function bit connect(hca_queue_pair qp_b);
        remote_qp = qp_b;
        qp_b.remote_qp = this;
        this.ctx.remote_qpn = qp_b.ctx.local_qpn;
        qp_b.ctx.remote_qpn = this.ctx.local_qpn;
        this.ctx.rnr_nextrecvpsn = qp_b.ctx.next_send_psn;
        qp_b.ctx.rnr_nextrecvpsn = this.ctx.next_send_psn;
        this.is_connect = TRUE;
        qp_b.is_connect = TRUE;
    endfunction: connect

    //------------------------------------------------------------------------------
    // task name     : put_wqe
    // function      : create wqes of one doorbell and deliver them to both memory 
    //                 and q_list. 
    //                 If operation type is RECEIVE, this task puts WQEs to RQ of 
    //                 the remote QP.
    // invoked       : by create_and_write_wqes in test_direct_param
    //------------------------------------------------------------------------------
    task put_wqe(
        e_op_type op_que[$], // opcode of each WQE
        mpt local_mpt_que[$], // used in data_seg
        mpt remote_mpt_que[$], // used in raddr_seg or check queue of RECV
        addr local_addr_offset_que[$], // its length should be equal to local_mpt_que
        addr remote_addr_offset_que[$], // its length should be equal to remote_mpt_que
        hca_queue_list q_list,
        hca_check_mem_list check_list,
        int sg_num,
        int sg_data_cnt
    );
        addr desc_byte_len;
        e_op_type op_type;
        e_op_type next_op_type;
        mpt local_mpt;
        mpt remote_mpt;
        addr local_addr_offset;
        addr remote_addr_offset;
        // int queue_size = 512 * 1024;
        wqe_data_seg_unit data_seg_unit;
        mpt local_mpt_que_check[$];
        mpt remote_mpt_que_check[$];
        addr local_addr_offset_que_check[$];
        addr remote_addr_offset_que_check[$];
        int host_id;
        int remote_host_id;
        bit [10:0] proc_id;
        bit [10:0] remote_proc_id;
        hca_queue_pair qp;
        int wqe_num;

        qp = this;
        host_id = this.host_id;
        proc_id = this.proc_id;
        remote_host_id = remote_qp.host_id;
        remote_proc_id = remote_qp.proc_id;

        local_mpt_que_check = local_mpt_que;
        remote_mpt_que_check = remote_mpt_que;
        local_addr_offset_que_check = local_addr_offset_que;
        remote_addr_offset_que_check = remote_addr_offset_que;
        wqe_num = op_que.size();

        next_op_type = op_que.pop_front();

        if (local_mpt_que.size() != local_addr_offset_que.size()) begin
            `uvm_fatal("QUEUE_ERROR", $sformatf("local_mpt_que.size != local_addr_offset_que.size!"));
        end

        if (remote_mpt_que.size() != remote_addr_offset_que.size()) begin
            `uvm_fatal("QUEUE_ERROR", $sformatf("remote_mpt_que.size != remote_addr_offset_que.size!"));
        end
        
        qp.sq_last_header = qp.sq_header;

        for (int i = 0; i < wqe_num; i++) begin
            wqe temp_wqe;

            op_type = next_op_type;
            if (op_que.size() != 0) begin // is not the last WQE
                next_op_type = op_que.pop_front();
            end
            else begin
                next_op_type = OP_INIT;
            end
            
            // set WQE length
            desc_byte_len = 0;
            if (op_type == RECV) begin
                desc_byte_len[ctx.rq_entry_sz_log] = 1'b1;
            end
            else begin
                desc_byte_len[ctx.sq_entry_sz_log] = 1'b1;
            end

            // set next seg
            if (i + 1 == wqe_num) begin // is the last wqe
                if (op_type == RECV) begin
                    temp_wqe.next_seg.next_wqe = 0;
                    temp_wqe.next_seg.res_0 = 1;
                    temp_wqe.next_seg.next_opcode = 0;
                    temp_wqe.next_seg.next_ee = 0;
                    temp_wqe.next_seg.next_dbd = 0;
                    temp_wqe.next_seg.next_fence = 0;
                    temp_wqe.next_seg.next_wqe_size = 0;
                    temp_wqe.next_seg.cq = 0;
                    temp_wqe.next_seg.evt = 0;
                    temp_wqe.next_seg.solicit = 0;
                    temp_wqe.next_seg.res_1 = 1;
                    temp_wqe.next_seg.imm_data = 0;
                end
                else begin
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
            end
            else begin // is not the last wqe
                case (next_op_type)
                    WRITE: begin
                        temp_wqe.next_seg.next_wqe = ((sq_header + desc_byte_len) % sq_byte_size) >> 4;
                        temp_wqe.next_seg.next_opcode = `VERBS_RDMA_WRITE;
                        temp_wqe.next_seg.next_wqe_size = sg_num + 2;
                    end
                    READ: begin
                        temp_wqe.next_seg.next_wqe = ((sq_header + desc_byte_len) % sq_byte_size) >> 4;
                        temp_wqe.next_seg.next_opcode = `VERBS_RDMA_READ;
                        temp_wqe.next_seg.next_wqe_size = sg_num + 2;
                    end
                    SEND: begin
                        if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD) begin
                            temp_wqe.next_seg.next_wqe = ((sq_header + desc_byte_len) % sq_byte_size) >> 4;
                            temp_wqe.next_seg.next_opcode = `VERBS_SEND;
                            temp_wqe.next_seg.next_wqe_size = sg_num + 4;
                        end
                        else begin
                            temp_wqe.next_seg.next_wqe = ((sq_header + desc_byte_len) % sq_byte_size) >> 4;
                            temp_wqe.next_seg.next_opcode = `VERBS_SEND;
                            temp_wqe.next_seg.next_wqe_size = sg_num + 1;
                        end
                    end
                    RECV: begin
                        temp_wqe.next_seg.next_wqe = ((qp.rq_header + desc_byte_len) % rq_byte_size) >> 4;
                        temp_wqe.next_seg.next_wqe_size = sg_num + 2;
                    end
                    default: begin
                        `uvm_fatal("ILLEGAL_OPCODE", $sformatf("illegal op code in wqe! i: %d, op_que.size: %d.", i, op_que.size()));
                    end
                endcase
            end

            // set ud seg
            if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD) begin
                temp_wqe.ud_seg.port = 8'b0101_0101;
                temp_wqe.ud_seg.smac = 48'h0102_0304_0506;
                temp_wqe.ud_seg.dmac = 48'h0708_090a_0b0c;
                temp_wqe.ud_seg.sip = 32'h1234_0000;
                temp_wqe.ud_seg.dip = 32'h0000_1234;
                temp_wqe.ud_seg.dqpn = remote_qp.ctx.local_qpn;
                temp_wqe.ud_seg.qkey = 32'h1234_5678;
            end

            // set data seg
            for (int data_seg_id = 0; data_seg_id < sg_num; data_seg_id++) begin
                local_mpt = local_mpt_que.pop_front();
                local_addr_offset = local_addr_offset_que.pop_front();
                if (local_addr_offset > local_mpt.length) begin
                    `uvm_fatal("ADDR_ERROR", $sformatf("local address offset exceeds size of MPT! key: %h, offset: %h, size: %h", 
                        local_mpt.key, local_addr_offset, local_mpt.length)
                    );
                end
                data_seg_unit.byte_count = sg_data_cnt;
                data_seg_unit.lkey = local_mpt.key;
                data_seg_unit.addr = local_mpt.start + local_addr_offset;
                `uvm_info("WQE_INFO", $sformatf("wqe_id: %h, data_seg: byte count: %h, lkey: %h, addr: %h, op: %h, qpn: %h, serv_typ: %h, host_id: %h", 
                    i, data_seg_unit.byte_count, data_seg_unit.lkey, data_seg_unit.addr, op_type, ctx.local_qpn, ctx.flags[23:16], host_id), UVM_LOW
                );
                temp_wqe.data_seg.push_back(data_seg_unit);
            end
            
            // set raddr seg
            case (op_type)
                WRITE,
                READ: begin
                    remote_mpt = remote_mpt_que.pop_front();
                    remote_addr_offset = remote_addr_offset_que.pop_front();
                    if (remote_addr_offset > remote_mpt.length) begin
                        `uvm_fatal("ADDR_ERROR", $sformatf("remote address offset exceeds size of MPT! key: %h, offset: %h, size: %h", 
                            remote_mpt.key, remote_addr_offset, remote_mpt.length));
                    end
                    temp_wqe.raddr_seg.raddr = remote_mpt.start + remote_addr_offset;
                    temp_wqe.raddr_seg.rkey = remote_mpt.key;
                    `uvm_info("WQE_INFO", $sformatf("wqe_id: %h, raddr_seg: rkey: %h, addr: %h, qpn: %h, host_id: %h", 
                        i, temp_wqe.raddr_seg.rkey, temp_wqe.raddr_seg.raddr, ctx.local_qpn, host_id), UVM_LOW
                    );
                end
                SEND,
                RECV: begin
                    // No need to set raddr seg for SEND/RECV
                end
                default: begin
                    `uvm_fatal("OP_TYPE_ERR", $sformatf("Illegal op_type: %h", op_type));
                end
            endcase

            // set zero seg
            if (op_type == RECV) begin
                temp_wqe.zero_seg.zero = 0;
            end

            if (op_type == RECV) begin
                qp.rq.push_back(temp_wqe);
                `uvm_info("NOTICE", $sformatf("WQE pushed into rq_wqe_list! op_type: %h, raddr_seg.raddr: %h", op_type, temp_wqe.raddr_seg.raddr), UVM_LOW);
                write_wqe_to_mem(qp, temp_wqe, op_type, sg_num);
            end
            else begin
                qp.sq.push_back(temp_wqe);
                `uvm_info("NOTICE", $sformatf("WQE pushed into sq_wqe_list! op_type: %h, raddr_seg.raddr: %h", op_type, temp_wqe.raddr_seg.raddr), UVM_LOW);
                write_wqe_to_mem(qp, temp_wqe, op_type, sg_num);
            end

            // send source address, destination address and length to scoreboard, no need for SEND
            if (op_type != SEND) begin
                // mpt local_mpt_que_check_copy[$];
                mpt remote_mpt_que_check_copy[$];
                // addr local_addr_offset_que_check_copy[$];
                addr remote_addr_offset_que_check_copy[$];
                for (int data_seg_id = 0; data_seg_id < sg_num; data_seg_id++) begin
                    // local_mpt_que_check_copy.push_back(local_mpt_que_check.pop_front());
                    remote_mpt_que_check_copy.push_back(remote_mpt_que_check.pop_front());
                    // local_addr_offset_que_check_copy.push_back(local_addr_offset_que_check.pop_front());
                    remote_addr_offset_que_check_copy.push_back(remote_addr_offset_que_check.pop_front());
                end
                send_mem_check(
                    host_id, 
                    remote_host_id, 
                    proc_id, 
                    remote_qp.proc_id, 
                    temp_wqe, 
                    op_type, 
                    // local_mpt_que_check_copy, 
                    remote_mpt_que_check_copy, 
                    // local_addr_offset_que_check_copy,
                    remote_addr_offset_que_check_copy,
                    check_list
                );
            end

            // send cqe to scoreboard
            send_ref_cqe(q_list);

            // modify qp pointer
            if (op_type == RECV) begin
                qp.rq_header += desc_byte_len;
            end
            else begin
                qp.sq_header += desc_byte_len;
            end
            // if ((qp.sq_header - qp.sq_tail) > 2048) begin
            //     `uvm_fatal("QP_OVERLAY", "SQ header exceeds tail!");
            // end
            // if ((qp.rq_header - qp.rq_tail) > 2048) begin
            //     `uvm_fatal("QP_OVERLAY", "RQ header exceeds tail!");
            // end
        end
        // qp.sq_last_header = qp.sq_header;
        `uvm_info("NOTICE", "put_wqe finished!", UVM_HIGH);
    endtask: put_wqe

    //------------------------------------------------------------------------------
    // task name     : send_ref_cqe
    // function      : send reference CQE to scoreboard
    // invoked       : by put_wqe
    //------------------------------------------------------------------------------
    task send_ref_cqe(hca_queue_list q_list);
    // warning: need to improve
        hca_comp_queue snd_cq;
        hca_comp_queue rcv_cq;
        cqe temp_cqe;
        snd_cq = q_list.cq_list[host_id][0];
        snd_cq.put_cqe(temp_cqe);
        `uvm_info("NOTICE", "send_ref_cqe finished!", UVM_LOW);
    endtask: send_ref_cqe

    //-----------------------------------------------------------------------------------
    // task name     : send_mem_check
    // function      : put memory check information of every single WQE into check_list, 
    //                 which will be used by scoreboard.
    // invoked       : by put_wqe
    //-----------------------------------------------------------------------------------
    task send_mem_check(
        int host_id,
        int remote_host_id,
        bit [10:0] proc_id,
        bit [10:0] remote_proc_id,
        wqe input_wqe,
        e_op_type op_type,
        // mpt recv_dst_mpt_que[$],
        mpt recv_src_mpt_que[$],
        // addr recv_dst_addr_offset_que[$],
        addr recv_src_addr_offset_que[$],
        hca_check_mem_list check_list
    );
        check_mem_unit check_unit;
        wqe_data_seg_unit temp_data_seg;
        addr offset = 0;
        mpt recv_dst_mpt;
        mpt recv_src_mpt;
        addr recv_dst_addr_offset;
        addr recv_src_addr_offset;

        // if op is READ or WRITE, use WQE to check
        if (op_type == READ) begin
            while (input_wqe.data_seg.size() != 0) begin
                temp_data_seg = input_wqe.data_seg.pop_front();
                check_unit.src_host = remote_host_id;
                check_unit.dst_host = host_id;
                check_unit.length = temp_data_seg.byte_count;
                check_unit.src_addr = `PA(proc_id, input_wqe.raddr_seg.raddr) + offset;
                check_unit.dst_addr = `PA(proc_id, temp_data_seg.addr);
                `uvm_info("MEM_CHECK_NOTICE", $sformatf("send memory check unit, src_addr: %h, dst_addr: %h, length: %h, operation type: %0d", 
                                                 check_unit.src_addr, check_unit.dst_addr, check_unit.length, op_type), UVM_LOW);
                check_list.check_list[host_id].push_back(check_unit);
                offset += temp_data_seg.byte_count;
            end
        end
        else if (op_type == WRITE) begin
            while (input_wqe.data_seg.size() != 0) begin
                temp_data_seg = input_wqe.data_seg.pop_front();
                check_unit.src_host = host_id;
                check_unit.dst_host = remote_host_id;
                check_unit.length = temp_data_seg.byte_count;
                check_unit.src_addr = `PA(proc_id, temp_data_seg.addr);
                check_unit.dst_addr = `PA(proc_id, input_wqe.raddr_seg.raddr) + offset;
                `uvm_info("MEM_CHECK_NOTICE", $sformatf("send memory check unit, src_addr: %h, dst_addr: %h, operation type: %0d", 
                                                 check_unit.src_addr, check_unit.dst_addr, op_type), UVM_LOW);
                check_list.check_list[host_id].push_back(check_unit);
                offset += temp_data_seg.byte_count;
            end
        end
        // if op is RECV, use MPT and WQE to check
        else if (op_type == RECV) begin // WARNING
            if (input_wqe.data_seg.size() != recv_src_mpt_que.size() || input_wqe.data_seg.size() != recv_src_addr_offset_que.size()) begin
                `uvm_fatal("QUEUE_ERROR", $sformatf("queue size error! input_wqe.data_seg.size: %h, recv_src_mpt_que.size: %h, recv_src_addr_offset_que.size: %h",
                    input_wqe.data_seg.size(), recv_src_mpt_que.size(), recv_src_addr_offset_que.size())
                );
            end
            while (input_wqe.data_seg.size() != 0) begin
                temp_data_seg = input_wqe.data_seg.pop_front();
                recv_src_mpt = recv_src_mpt_que.pop_front();
                recv_src_addr_offset = recv_src_addr_offset_que.pop_front();
                check_unit.src_host = remote_host_id;
                check_unit.dst_host = host_id;
                check_unit.length = temp_data_seg.byte_count;
                check_unit.src_addr = `PA(remote_proc_id, recv_src_mpt.start) + recv_src_addr_offset;
                check_unit.dst_addr = `PA(proc_id, temp_data_seg.addr);
                `uvm_info("MEM_CHECK_NOTICE", $sformatf("send memory check unit, src_addr: %h, dst_addr: %h, operation type: %0d", 
                                                 check_unit.src_addr, check_unit.dst_addr, op_type), UVM_LOW);
                check_list.check_list[host_id].push_back(check_unit);
                offset += temp_data_seg.byte_count;
            end
        end
        else begin
            `uvm_fatal("OP_TYPE_ERR", "Illegal op_type!");
        end
    endtask: send_mem_check

    //------------------------------------------------------------------------------
    // task name     : write_wqe_to_mem
    // function      : write one wqe of an operation type into memory space of a 
    //                 given QP
    // invoked       : by put_wqe
    //------------------------------------------------------------------------------
    task write_wqe_to_mem(hca_queue_pair qp, wqe temp_wqe, e_op_type op_type, int sg_num); // write ONE wqe to memory
                                                                               // not support inline seg
        addr base_paddr;
        addr wqe_offset;
        bit [`DATA_WIDTH - 1 : 0] raw_data;
        wqe_data_seg_unit data_seg_unit;
        int sg_id;
        bit [10:0] proc_id;
        int host_id;
        bit [7 : 0] op;
        bit [7 : 0] desc_size;
        // int wqe_size;
        hca_fifo #(.width(256)) data_fifo;
        proc_id = qp.proc_id;
        host_id = qp.host_id;

        data_fifo = hca_fifo#(.width(256))::type_id::create("data_fifo");

        // set wqe_offset and base physical address 
        if (op_type == RECV) begin
            base_paddr = `PA_QP(proc_id, qp.ctx.local_qpn) + `SQ_RQ_GAP;
            wqe_offset = qp.rq_header % rq_byte_size;
        end
        else begin
            base_paddr = `PA_QP(proc_id, qp.ctx.local_qpn);
            wqe_offset = qp.sq_header % sq_byte_size;
        end

        // write wqe
        // WRITE/READ WQE:
        // next_seg(16B) + raddr_seg(16B) + data_seg(16B x n)
        if (op_type == WRITE || op_type == READ) begin
            if (op_type == WRITE) begin
                op = `VERBS_RDMA_WRITE;
            end
            else if (op_type == READ) begin
                op = `VERBS_RDMA_READ;
            end
            desc_size = 32 + sg_num * 16;
            raw_data = 0;
            data_fifo.clean();
            raw_data[127:0] = {
                temp_wqe.next_seg.imm_data,
                {8'b0}, op, desc_size >> 4, 2'b0, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, 1'b0,
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
            sg_id = 0;
            while (temp_wqe.data_seg.size() != 0) begin
                data_seg_unit = temp_wqe.data_seg.pop_front();
                if (sg_id % 2 == 0) begin
                    raw_data = 0;
                    raw_data[127:0] = {
                        data_seg_unit.addr,
                        data_seg_unit.lkey,
                        data_seg_unit.byte_count
                    };
                end
                else begin
                    raw_data[255:128] = {
                        data_seg_unit.addr,
                        data_seg_unit.lkey,
                        data_seg_unit.byte_count
                    };
                end
                if (temp_wqe.data_seg.size() == 0 || sg_id % 2 == 1) begin
                    data_fifo.push(trans2comb(raw_data));
                end
                sg_id++;
            end
            mem.write_block(base_paddr + wqe_offset, data_fifo, desc_size);
            if (32 + sg_num * 16 > `SQ_WQE_BYTE_LEN) begin
                `uvm_fatal("WQE_SZ_ERR", $sformatf("WRITE/READ WQE size error! sg_num: %0d", sg_num));
            end
        end
        else if (op_type == SEND) begin
            op = `VERBS_SEND;
            // RC/UC SEND_WQE:
            // next_seg(16B) + data_seg (16B x n)
            if (qp.ctx.flags[23:16] != `HGHCA_QP_ST_UD) begin // RC/UC
                desc_size = 16 + sg_num * 16;
                raw_data = 0;
                data_fifo.clean();
                raw_data[127:0] = {
                    temp_wqe.next_seg.imm_data,
                    {8'b0}, op, desc_size >> 4, 2'b0, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, temp_wqe.next_seg.res_1,
                    temp_wqe.next_seg.next_ee, temp_wqe.next_seg.next_dbd, temp_wqe.next_seg.next_fence, temp_wqe.next_seg.next_wqe_size,
                    temp_wqe.next_seg.next_wqe, temp_wqe.next_seg.res_0, temp_wqe.next_seg.next_opcode
                };
                sg_id = 0;
                while (temp_wqe.data_seg.size() != 0) begin
                    data_seg_unit = temp_wqe.data_seg.pop_front();
                    // 
                    if (sg_id % 2 == 0) begin
                        raw_data[255:128] = {
                            data_seg_unit.addr,
                            data_seg_unit.lkey,
                            data_seg_unit.byte_count
                        };
                        data_fifo.push(trans2comb(raw_data));
                    end
                    else begin
                        raw_data = 0;
                        raw_data[127:0] = {
                            data_seg_unit.addr,
                            data_seg_unit.lkey,
                            data_seg_unit.byte_count
                        };
                        if (temp_wqe.data_seg.size() == 0) begin
                            data_fifo.push(trans2comb(raw_data));
                        end
                    end
                    sg_id++;
                end
                mem.write_block(base_paddr + wqe_offset, data_fifo, desc_size);
                if (16 + sg_num * 16 > `SQ_WQE_BYTE_LEN) begin
                    `uvm_fatal("WQE_SZ_ERR", $sformatf("RC/UC SEND WQE size error! sg_num: %0d", sg_num));
                end
            end
            // UD SEND WQE:
            // next_seg(16B) + ud_seg(48B) + data_seg(16B x n)
            else if (qp.ctx.flags[23:16] == `HGHCA_QP_ST_UD) begin
                desc_size = 64 + sg_num * 16;
                raw_data = 0;
                data_fifo.clean();
                raw_data[127:0] = {
                    temp_wqe.next_seg.imm_data,
                    {8'b0}, op, desc_size >> 16, 2'b0, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, temp_wqe.next_seg.res_1,
                    temp_wqe.next_seg.next_ee, temp_wqe.next_seg.next_dbd, temp_wqe.next_seg.next_fence, temp_wqe.next_seg.next_wqe_size,
                    temp_wqe.next_seg.next_wqe, temp_wqe.next_seg.res_0, temp_wqe.next_seg.next_opcode
                };
                raw_data[255:128] = {
                    temp_wqe.ud_seg.dmac[47:16],
                    temp_wqe.ud_seg.smac[47:16],
                    temp_wqe.ud_seg.dmac[15:0], temp_wqe.ud_seg.smac[15:0],
                    24'b0, temp_wqe.ud_seg.port
                };
                data_fifo.push(trans2comb(raw_data));
                raw_data = {
                    32'b0,
                    32'b0,
                    temp_wqe.ud_seg.qkey,
                    temp_wqe.ud_seg.dqpn,
                    32'b0,
                    32'b0,
                    temp_wqe.ud_seg.dip,
                    temp_wqe.ud_seg.sip
                };
                data_fifo.push(trans2comb(raw_data));
                sg_id = 0;
                while (temp_wqe.data_seg.size() != 0) begin
                    data_seg_unit = temp_wqe.data_seg.pop_front();
                    if (sg_id % 2 == 0) begin
                        raw_data = 0;
                        raw_data[127:0] = {
                            data_seg_unit.addr,
                            data_seg_unit.lkey,
                            data_seg_unit.byte_count
                        };
                    end
                    else begin
                        raw_data[255:128] = {
                            data_seg_unit.addr,
                            data_seg_unit.lkey,
                            data_seg_unit.byte_count
                        };
                    end
                    if (temp_wqe.data_seg.size() == 0 || sg_id % 2 == 1) begin
                        data_fifo.push(trans2comb(raw_data));
                    end
                    sg_id++;
                end
                mem.write_block(base_paddr + wqe_offset, data_fifo, 64 + sg_num * 16);
                if (64 + sg_num * 16 > `SQ_WQE_BYTE_LEN) begin
                    `uvm_fatal("WQE_SZ_ERR", $sformatf("UD SEND WQE size error! sg_num: %0d", sg_num));
                end
            end
        end
        else if (op_type == RECV) begin
            desc_size = 32 + sg_num * 16;
            // RECV WQE:
            // next_seg(16B) + data_seg(16B x n) + zero_seg(16B)
            // if (qp.ctx.flags[23:16] != `HGHCA_QP_ST_UD) begin
            raw_data = 0;
            data_fifo.clean();
            raw_data[127:0] = {
                temp_wqe.next_seg.imm_data,
                {16'b0}, desc_size >> 4, 2'b0, temp_wqe.next_seg.cq, temp_wqe.next_seg.evt, temp_wqe.next_seg.solicit, temp_wqe.next_seg.res_1,
                temp_wqe.next_seg.next_ee, temp_wqe.next_seg.next_dbd, temp_wqe.next_seg.next_fence, temp_wqe.next_seg.next_wqe_size,
                temp_wqe.next_seg.next_wqe, temp_wqe.next_seg.res_0, temp_wqe.next_seg.next_opcode
            };
            sg_id = 0;
            while (temp_wqe.data_seg.size() != 0) begin
                data_seg_unit = temp_wqe.data_seg.pop_front();
                if (sg_id % 2 == 0) begin
                    raw_data[255:128] = {
                        data_seg_unit.addr,
                        data_seg_unit.lkey,
                        data_seg_unit.byte_count
                    };
                    data_fifo.push(trans2comb(raw_data));
                    if (temp_wqe.data_seg.size() == 0) begin
                        raw_data = 0;
                        raw_data[127:0] = temp_wqe.zero_seg.zero;
                        data_fifo.push(trans2comb(raw_data));
                    end
                end
                else begin
                    raw_data = 0;
                    raw_data[127:0] = {
                        data_seg_unit.addr,
                        data_seg_unit.lkey,
                        data_seg_unit.byte_count
                    };
                    if (temp_wqe.data_seg.size() == 0) begin
                        raw_data[255:128] = temp_wqe.zero_seg.zero;
                        data_fifo.push(trans2comb(raw_data));
                    end
                end
                sg_id++;
            end
            if (sg_id != sg_num) begin
                `uvm_fatal("SG_NUM_ERROR", $sformatf("RECV sg_id: %0d, sg_num: %0d", sg_id, sg_num));
            end
            mem.write_block(base_paddr + wqe_offset, data_fifo, desc_size);
            if (32 + sg_num * 16 > `RQ_WQE_BYTE_LEN) begin
                `uvm_fatal("WQE_SZ_ERR", $sformatf("RECV WQE size error! sg_num: %0d", sg_num));
            end
        end
        if (op_type == RECV) begin
            if (wqe_offset + desc_size > rq_byte_size) begin
                `uvm_fatal("QUEUE_OVERFLOW", $sformatf("RQ overflow! wqe_offset: %0d, wqe_size: %0d, rq_byte_size: %0d", 
                    wqe_offset, desc_size, rq_byte_size));
            end
        end
        else begin
            if (wqe_offset + desc_size > sq_byte_size) begin
                `uvm_fatal("QUEUE_OVERFLOW", $sformatf("SQ overflow! wqe_offset: %0d, wqe_size: %0d, rq_byte_size: %0d", 
                    wqe_offset, desc_size, sq_byte_size));
            end
        end
        `uvm_info("MEM_INFO", $sformatf("write wqe finished, host_id: %h, addr: %h, op_type: %h", qp.host_id, base_paddr + wqe_offset, op_type), UVM_LOW);
    endtask: write_wqe_to_mem

    //------------------------------------------------------------------------------
    // function name : trans2comb
    // function      : transfer an array to an combination array which can be used 
    //                 in hca_fifo
    // invoked       : by user
    //------------------------------------------------------------------------------
    function bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] trans2comb(bit [255:0] raw_data);
        bit [256/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] result;
        for (int i = 0; i < 32; i++) begin
            result[i] = raw_data[i * 8 + 7 -: 8];
        end
        return result;
    endfunction: trans2comb

    //------------------------------------------------------------------------------
    // function name : consume_wqe
    // function      : update tail pointer, 0: SQ, 1: RQ
    //                 RQ is not supported because of prefetch
    // invoked       : by user
    //------------------------------------------------------------------------------
    function consume_wqe(bit queue);
        // set WQE length
        addr desc_byte_len;
        desc_byte_len = 0;
        if (queue == 0) begin
            desc_byte_len[ctx.sq_entry_sz_log] = 1'b1;
            sq_tail = sq_tail + desc_byte_len;
            `uvm_info("QP_NOTICE", $sformatf("consume SQ WQE, qpn: %h, host_id: %h, sq_tail: %h, sq_header: %h, descriptor size: %h", 
                ctx.local_qpn, host_id, sq_tail, sq_header, desc_byte_len), UVM_LOW
            );
            if (sq_tail > sq_header) begin
                `uvm_fatal("QUE_ERR", $sformatf("sq_tail exceeds sq_header! qpn: %h, host_id: %h, sq_tail: %h, sq_header: %h", 
                    ctx.local_qpn, host_id, sq_tail, sq_header)
                );
            end
        end
        // else begin
        //     desc_byte_len[ctx.rq_entry_sz_log] = 1'b1;
        //     rq_tail = rq_tail + desc_byte_len;
        //     `uvm_info("QP_NOTICE", $sformatf("consume RQ WQE, qpn: %h, rq_tail: %h, rq_header: %h", ctx.local_qpn, rq_tail, rq_header), UVM_LOW);
        //     if (rq_tail > rq_header) begin
        //         `uvm_fatal("QUE_ERR", $sformatf("rq_tail exceeds rq_header! qpn: %h, rq_tail: %h, rq_header: %h", ctx.local_qpn, rq_tail, rq_header));
        //     end
        // end
    endfunction: consume_wqe
endclass: hca_queue_pair
`endif
