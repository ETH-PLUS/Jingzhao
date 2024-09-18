//CREATE INFORMATION
//-----------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-07
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_slave_driver.sv
//  FUNCTION : This file supplies the function of slave side of HCA verification.
//
//-----------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-07    v1.0             create
//  mazhenlong      2021-12-22    v1.1             add random gap when sending DMA response
//
//-----------------------------------------------------------------------------------------

`ifndef __HCA_SLAVE_DRIVER__
`define __HCA_SLAVE_DRIVER__

//------------------------------------------------------------------------------
//
// CLASS: hca_slave_driver
//
//------------------------------------------------------------------------------
class hca_slave_driver extends uvm_driver #(hca_pcie_item);

    hca_memory mem;

    virtual hca_interface v_if;

    uvm_analysis_port #(hca_pcie_item) port2rm;

    hca_pcie_item resp_item;

    `uvm_component_utils_begin(hca_slave_driver)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates sequencer and driver.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual hca_interface)::get(this, "", "virtual_if", v_if)) begin
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ",get_full_name(),".v_if!"});
        end
        port2rm = new("port2rm", this);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // task name     : run_phase
    // function      : run_phase in uvm library, sends the pcie items to DUT
    // invoked       : invoked by uvm automaticly
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("NOTICE", {"run_phase begin in ", get_full_name()}, UVM_LOW);
        @ (posedge v_if.veri_en);
        forever begin
            @ (posedge v_if.pcie_clk);
            seq_item_port.get_next_item(resp_item);
            if (resp_item.item_type == GLOBAL_STOP) begin
                `uvm_info("NOTICE", "global stop item received by slave driver!", UVM_LOW);
                seq_item_port.item_done();
                break;
            end
            drive_resp_item(resp_item);
            seq_item_port.item_done();
        end
        `uvm_info("NOTICE", "slave driver run_phase end!", UVM_LOW);
        phase.drop_objection(this);
    endtask: run_phase

    //------------------------------------------------------------------------------
    // task name     : drive_resp_item
    // function      : send the pcie items to DUT and reference model
    // invoked       : by run_phase
    //------------------------------------------------------------------------------
    //-------------------NOTICE: ONLY NO MORE THAN 2048 BYTES---------------------//
    task drive_resp_item(hca_pcie_item item);
        int sent_dw_num;
        int beat_num;
        bit [255:0] temp_data;
        int j, m, n;
        bit [31:0] parity;

        hca_pcie_item item2rm;
        item2rm = hca_pcie_item::type_id::create("item2rm", this);
        item2rm.copy(item);
        // port2rm.write(item2rm);
        
        if (item.item_type == DMA_RSP) begin
            // `uvm_info("NOTICE", "slv drv to scb sent!", UVM_LOW);
            sent_dw_num = 0;
            beat_num = 0;
            while (sent_dw_num < item.rc_dword_count) begin // NOTICE!! SHOULD USE DW COUNT INSDEAD OF BYTE COUNT!!!
                
                // set tlast
                if (beat_num == 0) begin // first beat
                    if (item.rc_dword_count > 5) begin
                        v_if.m_axis_rc_tlast = 0;
                    end
                    else begin
                        v_if.m_axis_rc_tlast = 1;
                    end
                end
                else begin // other beats
                    if (sent_dw_num + 8 < item.rc_dword_count) begin
                        v_if.m_axis_rc_tlast = 0;
                    end
                    else begin
                        v_if.m_axis_rc_tlast = 1;
                    end
                end

                // set tvalid and incontinuous gap
                if ($test$plusargs("VALID_GAP")) begin
                    for (int i = 0; i < $urandom_range(`VALID_GAP); i++) begin
                        v_if.m_axis_rc_tvalid = 0;
                        @ (posedge v_if.pcie_clk);
                    end
                end
                v_if.m_axis_rc_tvalid = 1;

                // set tkeep
                if (v_if.m_axis_rc_tlast != 1) begin // is not the last beat
                    v_if.m_axis_rc_tkeep = 8'b1111_1111;
                end
                else begin // is the last beat
                    if (item.rc_dword_count == 5) begin // fully fill the last beat(also is the first beat)
                        v_if.m_axis_rc_tkeep = 8'b1111_1111;
                    end
                    else if ((beat_num != 0) && (sent_dw_num + 8 == item.rc_dword_count)) begin // fully fill the last beat(not the first beat)
                        v_if.m_axis_rc_tkeep = 8'b1111_1111;
                    end
                    else begin // not fully fill the last beat
                        if (beat_num == 0) begin // is the first beat
                            v_if.m_axis_rc_tkeep[2:0] = 3'b111;
                            for (int i = 0; i < 5; i++) begin
                                if (i > item.rc_dword_count) begin
                                    v_if.m_axis_rc_tkeep[i + 3] = 0;
                                end
                                else begin
                                    v_if.m_axis_rc_tkeep[i + 3] = 1;
                                end
                            end
                        end
                        else begin // is not the first beat
                            for (int i = 0; i < 8; i++) begin
                                if (sent_dw_num + i > item.rc_dword_count) begin
                                    v_if.m_axis_rc_tkeep[i] = 0;
                                end
                                else begin
                                    v_if.m_axis_rc_tkeep[i] = 1;
                                end
                            end
                        end
                    end
                end

                // set tdata
                // set descriptor
                if (beat_num == 0) begin
                    v_if.m_axis_rc_tdata[11:0] = item.rc_addr;
                    v_if.m_axis_rc_tdata[15:12] = item.rc_error_code;
                    v_if.m_axis_rc_tdata[28:16] = item.rc_byte_count;
                    v_if.m_axis_rc_tdata[29] = item.rc_locked_read_completion;
                    v_if.m_axis_rc_tdata[30] = item.rc_request_completed;
                    v_if.m_axis_rc_tdata[31] = 0;
                    v_if.m_axis_rc_tdata[42:32] = item.rc_dword_count;
                    v_if.m_axis_rc_tdata[45:43] = item.rc_completion_status;
                    v_if.m_axis_rc_tdata[46] = item.rc_poisoned_completion;
                    v_if.m_axis_rc_tdata[47] = 0;
                    v_if.m_axis_rc_tdata[55:48] = item.rc_requester_device;
                    v_if.m_axis_rc_tdata[63:56] = item.rc_requester_bus;
                    v_if.m_axis_rc_tdata[71:64] = item.rc_tag;
                    v_if.m_axis_rc_tdata[79:72] = item.rc_completer_device;
                    v_if.m_axis_rc_tdata[87:80] = item.rc_completer_bus;
                    v_if.m_axis_rc_tdata[88] = 0;
                    v_if.m_axis_rc_tdata[91:89] = item.rc_tc;
                    v_if.m_axis_rc_tdata[94:92] = item.rc_attr;
                    v_if.m_axis_rc_tdata[95] = 0;
                end
                // set payload
                if (beat_num == 0) begin // first beat
                    temp_data = item.data_payload.pop_front;
                    v_if.m_axis_rc_tdata[255:96] = temp_data[159:0];
                end
                else begin // later beats
                    v_if.m_axis_rc_tdata[95:0] = temp_data[255:160];
                    // if (item.data_payload.size() != 0) begin
                    // if (sent_dw_num + 8 < item.rc_dword_count) begin
                    //     temp_data = item.data_payload.pop_front;
                    //     v_if.m_axis_rc_tdata[255:96] = temp_data[159:0];
                    // end
                    // else begin
                    //     v_if.m_axis_rc_tdata[255:96] = 0;
                    // end
                    if (sent_dw_num + 3 <= item.rc_dword_count) begin
                        temp_data = item.data_payload.pop_front;
                        v_if.m_axis_rc_tdata[255:96] = temp_data[159:0];
                    end
                    else begin
                        v_if.m_axis_rc_tdata[255:96] = 0;
                    end
                end
                `uvm_info("NOTICE", $sformatf("RC tdata: %h", v_if.m_axis_rc_tdata), UVM_LOW);

                // remember to check data amount

                // set start byte enable
                // v_if.m_axis_rc_tuser[31:0] = 32'hffff_ffff; // byte enable
                // if (beat_num == 0) begin
                //     v_if.m_axis_rc_tuser[15:0] = {item.rc_first_be, 12'hfff};
                // end
                
                // // set end byte enable
                // if (item.rc_last_be != 0) begin
                //     if (v_if.m_axis_rc_tlast == 1) begin
                //         int i = 7;
                //         while (v_if.m_axis_rc_tlast[i] == 0) begin
                //             i--;
                //         end
                //         v_if.m_axis_rc_tuser[i * 4 + 3 -: 4] = item.rc_last_be;
                //     end
                //     else begin
                //         if (beat_num == 0) begin
                //             v_if.m_axis_rc_tuser[31:16] = 16'hffff;
                //         end
                //         else begin
                //             v_if.m_axis_rc_tuser[31:0] = 32'hffff_ffff;
                //         end
                //     end
                // end
                // else begin
                //     v_if.m_axis_rc_tuser[31:16] = 0;
                // end
                
                // set byte enable
                // only ONE DW
                if (item.rc_last_be == 0) begin
                    // check correctness
                    if (item.rc_byte_count > 4 || beat_num != 0) begin
                        `uvm_fatal("BYTE_CNT_ERROR", $sformatf("rc_byte_count does not fit 1! rc_byte_count: %h, beat_num: %0d", item.rc_byte_count, beat_num));
                    end
                    // set start byte enable
                    v_if.m_axis_rc_tuser[31:0] = {16'h0000, item.rc_first_be, 12'hfff};
                end
                // multiple DW, only one beat
                else if (beat_num == 0 && v_if.m_axis_rc_tlast == 1) begin
                    int i;
                    // check correctness
                    if (item.rc_byte_count > 20 || beat_num != 0 || item.rc_byte_count <= 4) begin
                        `uvm_fatal("BYTE_CNT_ERROR", $sformatf("rc_byte_count does not fit 2! item.rc_byte_count: %h, beat_num: %0d", item.rc_byte_count, beat_num));
                    end
                    v_if.m_axis_rc_tuser[31:0] = 32'hffff_ffff;
                    // set start byte enable
                    v_if.m_axis_rc_tuser[15:0] = {item.rc_first_be, 12'hfff};
                    // set end byte enable
                    i = 7;
                    while (v_if.m_axis_rc_tkeep[i] == 0) begin
                        v_if.m_axis_rc_tuser[i * 4 + 3 -: 4] = 4'h0;
                        i--;
                    end
                    v_if.m_axis_rc_tuser[i * 4 + 3 -: 4] = item.rc_last_be;
                    if (i <= 4) begin
                        `uvm_fatal("I_ERROR", $sformatf("i error! i: %0d", i));
                    end
                end
                // multiple beats
                else begin
                    // the first beat
                    if (beat_num == 0) begin
                        v_if.m_axis_rc_tuser[31:0] = {16'hffff, item.rc_first_be, 12'hfff};
                    end
                    // the last beat
                    else if (v_if.m_axis_rc_tlast == 1) begin
                        int i;
                        i = 7;
                        v_if.m_axis_rc_tuser[31:0] = 32'hffff_ffff;
                        while (v_if.m_axis_rc_tkeep[i] == 0) begin
                            v_if.m_axis_rc_tuser[i * 4 + 3 -: 4] = 4'h0;
                            i--;
                        end
                        v_if.m_axis_rc_tuser[i * 4 + 3 -: 4] = item.rc_last_be;
                    end
                    // middle beat
                    else begin
                        v_if.m_axis_rc_tuser[31:0] = 32'hffff_ffff;
                    end
                end

                if (beat_num == 0) begin // is_sof_0
                    v_if.m_axis_rc_tuser[32] = 1;
                end
                else begin
                    v_if.m_axis_rc_tuser[32] = 0;
                end
                v_if.m_axis_rc_tuser[33] = 0; // is_sof_1, only when straddle is open, what is straddle?
                if (v_if.m_axis_rc_tlast == 0) begin // is_eof
                    v_if.m_axis_rc_tuser[37:34] = 0;
                    v_if.m_axis_rc_tuser[41:38] = 0;
                end
                else begin
                    v_if.m_axis_rc_tuser[37:34] = 4'b1111;
                    v_if.m_axis_rc_tuser[41:38] = 0;
                end
                v_if.m_axis_rc_tuser[42] = 0; // discontinue
                for (m = 0; m < 32; m++) begin
                    for (n = 0; n < 8; n++) begin
                        if (v_if.m_axis_rc_tdata[m * 8 + n] == 1'b1) begin
                            parity[m] = ~parity[m];
                        end
                    end
                end
                v_if.m_axis_rc_tuser[74:43] = parity;
                
                // set beat num and sent dw num
                if (beat_num == 0) begin
                    sent_dw_num = sent_dw_num + 5;
                end
                else begin
                    sent_dw_num = sent_dw_num + 8;
                end
                beat_num++;
                while (1) begin
                    @ (posedge v_if.pcie_clk);
                    if (v_if.m_axis_rc_tready == 1'b1) begin
                        break;
                    end
                end
            end
            v_if.m_axis_rc_tvalid = 0;
        end
        else begin
            `uvm_error("ITEM_TYPE_ERR", "received pcie item illegal!");
        end
    endtask: drive_resp_item
endclass: hca_slave_driver
`endif