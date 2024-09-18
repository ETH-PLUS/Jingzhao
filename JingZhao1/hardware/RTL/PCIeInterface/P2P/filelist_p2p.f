//****************************************************************
// include_file
//****************************************************************
+incdir+../../../Include/PCIeI_Include
../../../Include/PCIeI_Include/p2p_include_h.vh

//****************************************************************
// Lib_file
//****************************************************************
//-F ../../../Lib/pciei_lib_file/filelist_pciei_lib.f

//****************************************************************
// rtl_file
//****************************************************************
./P2P.v
./ini_dev2addr_table.v
./ini_dst_nic_proc.v
./ini_pyld_split_proc.v
./p2p_initiator.v
./p2p_target.v
./tgt_pyld_buf.v
./tgt_pyld_recv_proc.v
./tgt_pyld_send_proc.v
./tgt_queue_struct.v
./tgt_desc_queue.v
