//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-12
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_math_func.sv
//  VERSION  : v1.0
//  FUNCTION : This file supplies the common mathematics functions. 
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-12    v1.0             modified from chpp_math_func
//
//----------------------------------------------------------------------------

`ifndef __HCA_MATH_FUNC__
`define __HCA_MATH_FUNC__

//------------------------------------------------------------------------------
//
// CLASS: hca_math_func
//
//------------------------------------------------------------------------------

class hca_math_func extends uvm_object;

    // variables
    // user define
    typedef hca_math_func this_typ;

    `uvm_object_utils(hca_math_func)

    // functions and tasks
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : be invoked when instantiates hca_math_func 
    //------------------------------------------------------------------------------
    function new(string name = "hca_math_func");
        super.new(name);
    endfunction

    //------------------------------------------------------------------------------
    // function name : log_func
    // function      : supplies the logarithm for one int, base number is 2
    // invoked       : be invoked by user
    //------------------------------------------------------------------------------
    function int log_func(int y);
        int x = 0;
        int f;
        f = y;
        // `CHPP_ERR_ASSERT(this_typ, (f > 0));
        while (f > 0) begin
            f >>= 1;
            x++;
        end
        return (x-1);
    endfunction: log_func

endclass : hca_math_func

`endif
