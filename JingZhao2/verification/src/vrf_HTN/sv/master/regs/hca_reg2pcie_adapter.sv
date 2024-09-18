//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-14
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_reg2pcie_adapter.sv
//  FUNCTION : This file supplies the adapter that transfers r/w of regs to 
//             pcie pkts.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-14    v1.0             create
//  mazhenlong      2021-04-09    v1.1             add hcr contents generation
//
//----------------------------------------------------------------------------

`ifndef __HCA_REG2PCIE_ADAPTER__
`define __HCA_REG2PCIE_ADAPTER__
//`include "hca_defines.sv"

//------------------------------------------------------------------------------
//
// CLASS: hca_reg2pcie_adapter
//
//------------------------------------------------------------------------------
class hca_reg2pcie_adapter extends uvm_reg_adapter;
    `uvm_object_utils_begin(hca_reg2pcie_adapter)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_reg2pcie_adapter");
        super.new(name);
    endfunction

    //------------------------------------------------------------------------------
    // function name : reg2bus
    // function      : transfer register items to pcie items
    // invoked       : invoked when read or write reg models
    //------------------------------------------------------------------------------
    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        string test_name;
        hca_pcie_item bus;
        bus = hca_pcie_item::type_id::create("hca_pcie_item");

        if (rw.kind == UVM_READ) begin
            bus.cq_addr = rw.addr;
            bus.cq_addr_type = 0;
            bus.cq_attr = 0; // not sure
            bus.cq_tc = 0; //not sure
            bus.cq_target_function = 0; //not sure
            bus.cq_tag = 0; //not sure
            bus.cq_bus = 0; //not sure
            bus.cq_device = 0; //not sure
            bus.cq_req_type = MEM_RD;
            bus.cq_dword_count = 7;
            bus.is_reg_req = 1;
            if (rw.addr == `HCR_BAR_ADDR) begin
                bus.cq_bar_id = 0;
                bus.cq_bar_aperture = 28;
                bus.cq_rd_dw_size = 7;
            end
            else if (rw.addr >= `DB_BAR_ADDR && rw.addr <= `DB_BAR_ADDR + 8 * 1024 * 1024) begin
                bus.cq_bar_id = 2;
                bus.cq_bar_aperture = 23;
            end
            bus.gen_cq_desc();
        end
        else if (rw.kind == UVM_WRITE) begin
            bus.cq_addr = rw.addr;
            bus.cq_addr_type = 0; //not sure
            bus.cq_attr = 0; //not sure
            bus.cq_tc = 0; //not sure
            bus.cq_target_function = 0; //not sure
            bus.cq_tag = 0; //not sure
            bus.cq_bus = 0; //not sure
            bus.cq_req_type = MEM_WR;
            bus.cq_dword_count = 7;
            bus.is_reg_req = 1;
            if (rw.addr == `HCR_BAR_ADDR) begin
                bus.cq_bar_id = 0;
                bus.cq_bar_aperture = 28;
            end
            else if (rw.addr >= `DB_BAR_ADDR && rw.addr <= `DB_BAR_ADDR + 8 * 1024 * 1024) begin
                bus.cq_bar_id = 2;
                bus.cq_bar_aperture = 23;
            end
            bus.data_payload.push_back({0, rw.data});
            bus.gen_cq_desc();
            
            // generate hcr contents
            bus.hcr_in_param[63:32]     = rw.data[31:0]   ;
            bus.hcr_in_param[31:0]      = rw.data[63:32]  ;
            bus.hcr_in_modifier         = rw.data[95:64]  ;
            bus.hcr_out_param[63:32]    = rw.data[127:96] ;
            bus.hcr_out_param[31:0]     = rw.data[159:128];
            bus.hcr_token               = rw.data[191:176];
            bus.hcr_e                   = rw.data[214]    ;
            bus.hcr_go                  = rw.data[215]    ;
            bus.hcr_op_modifier         = rw.data[211:204];
            bus.hcr_op                  = rw.data[203:192];
        end
        return bus;
    endfunction

    //------------------------------------------------------------------------------
    // function name : bus2reg
    // function      : transfer pcie items to reg items
    // invoked       : invoked when received read or write requests from DUT
    //------------------------------------------------------------------------------
    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        hca_pcie_item bus;
        if (!$cast(bus, bus_item)) begin
            `uvm_fatal("CAST_FAILED", "Failed to cast bus_item to bus!");
            return;
        end
        if (bus.cq_req_type == MEM_RD) begin
            rw.kind = UVM_READ;
            rw.addr = {bus.cq_addr, 2'b0};
            rw.data = bus.data_payload.pop_front();
            rw.status = UVM_IS_OK;
        end
    endfunction: bus2reg
endclass
`endif
