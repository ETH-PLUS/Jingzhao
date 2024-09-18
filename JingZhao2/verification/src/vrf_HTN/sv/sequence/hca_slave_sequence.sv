//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-22
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_slave_sequence.sv
//  FUNCTION : This file supplies the sequence of slave side in verification, 
//             including send DMA read response.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-22    v1.0             create
//  mazhenlong      2021-04-29    v1.1             add processing logic for
//                                                 mem write
//
//----------------------------------------------------------------------------

`ifndef __HCA_SLAVE_SEQUENCE__
`define __HCA_SLAVE_SEQUENCE__

//------------------------------------------------------------------------------
//
// CLASS: hca_slave_sequence
//
//------------------------------------------------------------------------------

class hca_slave_sequence extends uvm_sequence #(hca_pcie_item);
    hca_memory mem;
    hca_fifo #(`MEM_LINE_SIZE) fifo;
    // hca_pcie_item received_item;
    hca_pcie_item sent_item;
    int max_payload_size;
    int max_read_req_size;
    // virtual hca_interface v_if;
    bit stop = 0;
    hca_queue_list q_list;
    int host_id;

    bit [`MEM_LINE_SIZE-1: 0] temp_data;

    `uvm_object_utils_begin(hca_slave_sequence)
    `uvm_object_utils_end

    `uvm_declare_p_sequencer(hca_slave_sequencer)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : be invoked when instantiates hca_slave_sequence
    //------------------------------------------------------------------------------
    function new(string name = "hca_slave_sequence");
        super.new(name);
        case(`MAX_PAYLOAD) // write request, not read response
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

        // if(!uvm_config_db #(virtual hca_interface)::get(null, get_full_name(), "virtual_if", v_if))
        //     `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    endfunction: new

    virtual task pre_body();
        if(!uvm_config_db#(hca_queue_list)::get(null, get_full_name(), "q_list", q_list)) begin
            `uvm_fatal("GET_ERR", $sformatf("q_list not get in slave_sequence! full name: %s, m_sequencer: %s.", get_full_name(), m_sequencer.get_full_name()));
        end
    endtask: pre_body

    //------------------------------------------------------------------------------
    // function name : body
    // function      : receive items from sequencer and generate DMA response to DUV.
    // invoked       : be invoked by uvm
    //------------------------------------------------------------------------------
    virtual task body();
        while (1) begin
            hca_pcie_item received_item;
            `uvm_info("NOTICE", $sformatf("fifo used: %0d", p_sequencer.item_collected_fifo.used()), UVM_HIGH);
            p_sequencer.item_collected_fifo.get(received_item);
            if (received_item.item_type == GLOBAL_STOP) begin
                `uvm_info("NOTICE", "global stop item received in slave sequence!", UVM_LOW);
                sent_item = hca_pcie_item::type_id::create("sent_item");
                start_item(sent_item);
                sent_item.item_type = GLOBAL_STOP;
                finish_item(sent_item);
                `uvm_info("NOTICE", "global stop item sent to slave driver!", UVM_LOW);
                break;
            end
            if (received_item.rq_req_type == MEM_RD) begin
                int i;
                sent_item = hca_pcie_item::type_id::create("sent_item");
                start_item(sent_item);
                // `uvm_info("NOTICE", $sformatf("memory read process begin in slave sequence"), UVM_LOW);

                // set rc descriptor field values in sent_item
                sent_item.item_type                         = DMA_RSP;

                // set rc_addr
                i = 0;
                while (received_item.rq_first_be[i] == 0) begin
                    i++;
                end
                sent_item.rc_addr                           = received_item.rq_addr[11:0] + i;

                sent_item.rc_error_code                     = 0; // depends on memory read result
                sent_item.rc_byte_count                     = get_byte_count(received_item.rq_dword_count, received_item.rq_first_be, received_item.rq_last_be);
                sent_item.rc_locked_read_completion         = 0; // if is a resp to a locked read set to 1, otherwise 0
                sent_item.rc_request_completed              = 1; // indicates the end of the completions of a request
                sent_item.rc_dword_count                    = received_item.rq_dword_count;
                sent_item.rc_completion_status              = 3'b000;
                sent_item.rc_poisoned_completion            = 0; // unclear the use
                sent_item.rc_requester_device               = received_item.rq_requester_device;
                sent_item.rc_requester_bus                  = received_item.rq_requester_bus;
                sent_item.rc_tag                            = received_item.rq_tag;
                sent_item.rc_completer_device               = 0;
                sent_item.rc_completer_bus                  = 0;
                sent_item.rc_tc                             = 0;
                sent_item.rc_attr                           = 0;
                sent_item.rc_first_be                       = received_item.rq_first_be;
                sent_item.rc_last_be                        = received_item.rq_last_be;
                // read contents from mem
                fifo = mem.read_block(received_item.rq_addr, received_item.rq_dword_count * 4);
                `uvm_info("NOTICE", $sformatf("mem read finished. addr = %h, dword_count: %h, byte_count: %h, first_be: %h, last_be: %h", 
                    received_item.rq_addr, received_item.rq_dword_count, sent_item.rc_byte_count, sent_item.rc_first_be, sent_item.rc_last_be), UVM_LOW
                );
                while (fifo.get_depth() != 0) begin
                    temp_data = fifo.pop();
                    // `uvm_info("NOTICE", $sformatf("read data content: %h", temp_data), UVM_HIGH);
                    sent_item.data_payload.push_back(temp_data);
                end
                finish_item(sent_item);

                if (received_item.rq_addr[47:38] == 10'b1) begin
                    hca_queue_pair qp;
                    bit [31:0] qpn;
                    qpn = {18'b0, received_item.rq_addr[37:24]};
                    qp = q_list.get_qp(host_id, qpn);
                    //qp.consume_wqe(received_item.rq_addr[23]);
                    //`uvm_info("QP_NOTICE", $sformatf("consume WQE, host_id: %0d, addr: %h", host_id, received_item.rq_addr), UVM_LOW);
                end
            end
            else if (received_item.rq_req_type == MEM_WR) begin
                // do not need to send response to duv
                int length;
                addr start_addr;
                hca_fifo #(.width(256)) temp_fifo;
                temp_fifo = hca_fifo #(.width(256))::type_id::create("temp_fifo");
                while (received_item.data_payload.size() != 0) begin
                    temp_data = received_item.data_payload.pop_front();
                    temp_fifo.push(temp_data);
                    `uvm_info("NOTICE", $sformatf("write data: %h, addr: %h", temp_data, received_item.rq_addr), UVM_LOW);
                end

                // consider last_be and first_be
                length = received_item.rq_dword_count * 4;
                start_addr = received_item.rq_addr;
                // for (int idx = 0; idx < 4; idx++) begin
                //     if (received_item.rq_first_be[idx] == 0) begin
                //         start_addr++;
                //         length--;
                //         temp_fifo.pop_byte();
                //     end
                //     else begin
                //         break;
                //     end
                // end
                // for (int idx = 0; idx < 4; idx++) begin
                //     if (received_item.rq_first_be[3 - idx] == 0) begin

                //     end
                // end
                if (check_be(received_item.rq_first_be, received_item.rq_last_be) == 0) begin
                    `uvm_fatal("BE_ERR", $sformatf("RQ BE error! first_be: %b, last_be: %b", 
                        received_item.rq_first_be, received_item.rq_last_be));
                end

                case (received_item.rq_first_be)
                    4'b1111: begin
                        start_addr = received_item.rq_addr;
                        length = length;
                    end
                    4'b1110: begin
                        start_addr = received_item.rq_addr + 1;
                        temp_fifo.pop_byte();
                        length -= 1;
                    end
                    4'b1100: begin
                        start_addr = received_item.rq_addr + 2;
                        temp_fifo.pop_byte();
                        temp_fifo.pop_byte();
                        length -= 2;
                    end
                    4'b1000: begin
                        start_addr = received_item.rq_addr + 3;
                        temp_fifo.pop_byte();
                        temp_fifo.pop_byte();
                        temp_fifo.pop_byte();
                        length -= 3;
                    end
                    4'b0001: begin
                        start_addr = received_item.rq_addr;
                        length = 1;
                    end
                    4'b0011: begin
                        start_addr = received_item.rq_addr;
                        length = 2;
                    end
                    4'b0111: begin
                        start_addr = received_item.rq_addr;
                        length = 3;
                    end
                    4'b0110: begin
                        start_addr = received_item.rq_addr + 1;
                        length = 2;
                        temp_fifo.pop_byte();
                    end
                    4'b0010: begin
                        start_addr = received_item.rq_addr + 1;
                        length = 1;
                        temp_fifo.pop_byte();
                    end
                    4'b0100: begin
                        start_addr = received_item.rq_addr + 2;
                        length = 1;
                        temp_fifo.pop_byte();
                        temp_fifo.pop_byte();
                    end
                    default: begin
                        `uvm_fatal("BE_ERROR", $sformatf("rq_first_be error: %h", received_item.rq_first_be));
                    end
                endcase

                case (received_item.rq_last_be)
                    4'b1111: begin
                        length = length;
                    end
                    4'b0111: begin
                        length -= 1;
                    end
                    4'b0011: begin
                        length -= 2;
                    end
                    4'b0001: begin
                        length -= 3;
                    end
                    4'b0000: begin
                        if (length <= 4) begin
                        end
                        else begin
                            `uvm_fatal("BE_ERROR", $sformatf("rq_last_be error, last be: %h, first be: %h", received_item.rq_last_be, received_item.rq_first_be));
                        end
                    end
                    default: begin
                        `uvm_fatal("BE_ERROR", $sformatf("rq_last_be error: %h", received_item.rq_last_be));
                    end
                endcase

                mem.write_block(start_addr, temp_fifo, length);
            end
            else begin
                `uvm_error("PCIE_REQ_TYPE_ERR", "received item request type illegal in slave sequence!");
            end
        end
        `uvm_info("GLB_STOP_INFO", "slave sequence body end!", UVM_LOW);
    endtask: body

    function int get_byte_count(int dw_cnt, bit [3:0] first_be, bit [3:0] last_be);
        int byte_cnt = dw_cnt * 4;
        int i = 0;
        while (first_be[i] == 0) begin
            i++;
        end
        byte_cnt = byte_cnt - i;
        if (last_be == 0) begin
            return byte_cnt;
        end
        else begin
            i = 0;
            while (last_be[3 - i] == 0) begin
                i++;
            end
            byte_cnt = byte_cnt - i;
            return byte_cnt;
        end
    endfunction: get_byte_count

    function bit check_be(bit [3:0] first_be, bit [3:0] last_be);
        bit [7:0] be;
        int start = 0;
        int last = 7;
        be = {last_be, first_be};
        for (int i = 0; i < 8; i++) begin
            if (be[i] == 1) begin
                start = i;
                break;
            end
        end
        for (int i = 0; i < 8; i++) begin
            if (be[7 - i] == 1) begin
                last = 7 - i;
                break;
            end
        end
        for (int i = start; i < last; i++) begin
            if (be[i] == 0) begin
                return 0;
            end
        end

        if (first_be == 0) begin
            return 0;
        end
        return 1;
    endfunction: check_be
endclass: hca_slave_sequence
`endif
