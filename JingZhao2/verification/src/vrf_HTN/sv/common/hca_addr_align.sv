//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-12
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_addr_align.sv
//  VERSION  : v1.0
//  FUNCTION : This file supplies the function of address aligns, other
//             component or object can use the common object. 
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-12    v1.0             modified from chpp_addr_align
//
//----------------------------------------------------------------------------

`ifndef __HCA_ADDR_ALIGN__
`define __HCA_ADDR_ALIGN__

//------------------------------------------------------------------------------
//
// CLASS: hca_addr_align
//
//------------------------------------------------------------------------------

class hca_addr_align #(type T = addr64_typ) extends uvm_object;

    // variables
    typedef hca_addr_align #(T) this_typ;
    T addr;
    hca_math_func math;

    // provide implementations of virtual methods such as get_type_name and create
    `uvm_object_param_utils_begin(hca_addr_align #(T))
        `uvm_field_object(math, UVM_DEFAULT)
    `uvm_object_utils_end

    // functions and tasks
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : be invoked when instantiates hca_addr_align 
    //------------------------------------------------------------------------------
    function new(string name = "hca_addr_align");
        super.new(name);
        math = hca_math_func::type_id::create("math");
    endfunction

    //------------------------------------------------------------------------------
    // function name : addr_align_1byte
    // function      : judge whether the address is 1 byte aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_1byte(T addr);
        return TRUE;
    endfunction : addr_align_1byte

    //------------------------------------------------------------------------------
    // function name : addr_align_2byte
    // function      : judge whether the address is 2 bytes aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_2byte(T addr);
        if (addr[0] == 'b0) begin
            return TRUE;
        end
        else begin
            return FALSE;
        end
    endfunction : addr_align_2byte

    //------------------------------------------------------------------------------
    // function name : addr_align_4byte
    // function      : judge whether the address is 4 bytes aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_4byte(T addr);
        if (addr[1:0] == 'b0) begin
            return TRUE;
        end
        else begin
            return FALSE;
        end
    endfunction : addr_align_4byte

    //------------------------------------------------------------------------------
    // function name : addr_align_8byte
    // function      : judge whether the address is 8 bytes aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_8byte(T addr);
        if (addr[2:0] == 'b0) begin
            return TRUE;
        end
        else begin
            return FALSE;
        end
    endfunction : addr_align_8byte

    //------------------------------------------------------------------------------
    // function name : addr_align_dw
    // function      : judge whether the address is DW aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_dw(T addr);
        if (addr[`DW_ALIGNED_WIDTH-1:0] == 'b0) begin
            return TRUE;
        end
        else begin
            return FALSE;
        end
    endfunction : addr_align_dw

    //------------------------------------------------------------------------------
    // function name : addr_align_line
    // function      : judge whether the address is line aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_line(int line_size, T addr);
        bit zero = 0;
        int align_bits;
        align_bits = math.log_func(line_size/`BYTE_BIT_WIDTH);
        //if ((addr & {align_bits{1'b1}}) == 'b0) begin
        //  return TRUE;
        //end
        //else begin
        //  return FALSE;
        //end
        for (int i = 0; i < align_bits; i++) begin
            zero |= addr[i];
        end
        return zero ? FALSE : TRUE;
    endfunction : addr_align_line

    //------------------------------------------------------------------------------
    // function name : addr_align_border
    // function      : judge whether the address is line aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function bool addr_align_border(int border_size, T addr);
        bit zero = 0;
        int align_bits;
        align_bits = math.log_func(border_size/`BYTE_BIT_WIDTH);
        //if ((addr & {align_bits{1'b1}}) == 'b0) begin
        //  return TRUE;
        //end
        //else begin
        //  return FALSE;
        //end
        for (int i = 0; i < align_bits; i++) begin
            zero |= addr[i];
        end
        return zero ? FALSE : TRUE;
    endfunction : addr_align_border

    //------------------------------------------------------------------------------
    // function name : next_border_align_addr
    // function      : judge whether the address is DW aligned
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function T next_border_align_addr(int border_size, T addr);
        T addr_tmp;
        int align_bits;
        align_bits = math.log_func(border_size);
        addr_tmp = addr >> align_bits;
        addr_tmp++;
        addr_tmp <<= align_bits;
        return addr_tmp;
    endfunction : next_border_align_addr

endclass : hca_addr_align

`endif
