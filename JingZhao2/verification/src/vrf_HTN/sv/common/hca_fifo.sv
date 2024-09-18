//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-17
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_fifo.sv
//  FUNCTION : This file supplies the fifo of verification of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-17    v1.0             modified from chpp_fifo
//
//----------------------------------------------------------------------------

`ifndef __HCA_FIFO__
`define __HCA_FIFO__

//------------------------------------------------------------------------------
//
// CLASS: hca_fifo
//
//------------------------------------------------------------------------------

class hca_fifo #(int width=128) extends uvm_object;

    // variables
    // user define
    typedef hca_fifo #(width) this_typ;
    // memory unit
    bit [`BYTE_BIT_WIDTH-1:0] mem[$];
    // depth of memory
    int depth;

    // provide implementations of virtual methods such as get_type_name and create
    `uvm_object_param_utils_begin(hca_fifo #(width))
        `uvm_field_queue_int(mem, UVM_DEFAULT)
        `uvm_field_int(depth, UVM_DEFAULT|UVM_DEC)
    `uvm_object_utils_end

    // functions and tasks
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : be invoked when instantiates hca_fifo
    //------------------------------------------------------------------------------
    function new(string name = "hca_fifo");
        super.new(name);
    endfunction

    // declare extern functions and tasks
    extern function void push(bit[width/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    extern function void push_byte(byte_typ data);
    extern function void push_dw(bit[`DW_DATA_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    extern function void push_2dw(bit[`TWO_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    extern function void push_3dw(bit[`THR_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    extern function void push_4dw(bit[`FOU_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    extern function bit[width-1:0] pop();
    extern function byte_typ pop_byte();
    extern function dw_typ pop_dw();
    extern function two_dw_typ pop_2dw();
    extern function thr_dw_typ pop_3dw();
    extern function fou_dw_typ pop_4dw();

    extern function void clean();
    extern function void add_fifo(this_typ fifo);
    extern function int get_depth();

endclass : hca_fifo

//------------------------------------------------------------------------------
// function name : push
// function      : push data to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push(bit[width/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    for (int i = 0; i <width/`BYTE_BIT_WIDTH; i++) begin
        mem.push_back(data[i]);
    end
endfunction : push

//------------------------------------------------------------------------------
// function name : push_byte
// function      : push data to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push_byte(byte_typ data);
    mem.push_back(data);
endfunction : push_byte

//------------------------------------------------------------------------------
// function name : push_dw
// function      : push one dw to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push_dw(bit[`DW_DATA_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    for (int i = 0; i <`DW_DATA_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        mem.push_back(data[i]);
    end
endfunction : push_dw

//------------------------------------------------------------------------------
// function name : push_3dw
// function      : push three dw to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push_2dw(bit[`TWO_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    for (int i = 0; i <`TWO_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        mem.push_back(data[i]);
    end
endfunction : push_2dw

//------------------------------------------------------------------------------
// function name : push_3dw
// function      : push three dw to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push_3dw(bit[`THR_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    for (int i = 0; i <`THR_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        mem.push_back(data[i]);
    end
endfunction : push_3dw

//------------------------------------------------------------------------------
// function name : push_4dw
// function      : push four dw to mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::push_4dw(bit[`FOU_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data);
    for (int i = 0; i <`FOU_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        mem.push_back(data[i]);
    end
endfunction : push_4dw

//------------------------------------------------------------------------------
// function name : pop
// function      : pop data from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function bit[hca_fifo::width-1:0] hca_fifo::pop();
    bit [width/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    for (int i = 0; i < width/`BYTE_BIT_WIDTH; i++) begin
        //`CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
        data[i] = mem.pop_front();
    end
    return data;
endfunction : pop

//------------------------------------------------------------------------------
// function name : pop_byte
// function      : pop data from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function byte_typ hca_fifo::pop_byte();
    byte_typ data;
    //`CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
    data = mem.pop_front();
    return data;
endfunction : pop_byte

//------------------------------------------------------------------------------
// function name : pop_dw
// function      : pop one dw from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function dw_typ hca_fifo::pop_dw();
    bit [`DW_DATA_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    for (int i = 0; i < `DW_DATA_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        // `CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
        data[i] = mem.pop_front();
    end
    return data;
endfunction : pop_dw

//------------------------------------------------------------------------------
// function name : pop_2dw
// function      : pop two dw from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function two_dw_typ hca_fifo::pop_2dw();
    bit [`TWO_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    for (int i = 0; i < `TWO_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        // `CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
        data[i] = mem.pop_front();
    end
    return data;
endfunction : pop_2dw

//------------------------------------------------------------------------------
// function name : pop_3dw
// function      : pop three dw from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function thr_dw_typ hca_fifo::pop_3dw();
    bit [`THR_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    for (int i = 0; i < `THR_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        // `CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
        data[i] = mem.pop_front();
    end
    return data;
endfunction : pop_3dw

//------------------------------------------------------------------------------
// function name : pop_4dw
// function      : pop four dw from mem queue
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function fou_dw_typ hca_fifo::pop_4dw();
    bit [`FOU_DW_WIDTH/`BYTE_BIT_WIDTH-1:0][`BYTE_BIT_WIDTH-1:0] data;
    for (int i = 0; i < `FOU_DW_WIDTH/`BYTE_BIT_WIDTH; i++) begin
        // `CHPP_ERR_ASSERT(this_typ, (mem.size() != 0))
        data[i] = mem.pop_front();
    end
    return data;
endfunction : pop_4dw

//------------------------------------------------------------------------------
// function name : add_fifo 
// function      : add one fifo to the exist fifo
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::add_fifo(this_typ fifo);
    while (fifo.get_depth() != 0) begin
        this.push_byte(fifo.pop_byte());
    end
endfunction : add_fifo

//------------------------------------------------------------------------------
// function name : clean
// function      : clean the fifo
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function void hca_fifo::clean();
    while (mem.size() != 0) begin
        mem.pop_front();
    end
endfunction : clean

//------------------------------------------------------------------------------
// function name : get_depth
// function      : get the depth of the fifo
// invoked       : be invoked by user
//------------------------------------------------------------------------------
function int hca_fifo::get_depth();
    depth = int'(this.mem.size());
    return depth;
endfunction : get_depth

`endif
