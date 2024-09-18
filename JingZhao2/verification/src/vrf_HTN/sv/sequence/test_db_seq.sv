//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-14
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : test_db_seq.sv
//  FUNCTION : This file supplies the task of verifying the doorbell register.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-14    v1.0             create
//
//----------------------------------------------------------------------------

`ifndef __TEST_DB_SEQ__
`define __TEST_DB_SEQ__

//------------------------------------------------------------------------------
//
// CLASS: test_db_seq
//
//------------------------------------------------------------------------------
class test_db_seq extends uvm_reg_sequence;
    string testname;
    
endclass
`endif