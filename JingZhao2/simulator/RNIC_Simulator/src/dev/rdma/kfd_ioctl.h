/*
 *======================= START OF LICENSE NOTICE =======================
 *  Copyright (C) 2021 Kang Ning, NCIC, ICT, CAS.
 *  All Rights Reserved.
 *
 *  NO WARRANTY. THE PRODUCT IS PROVIDED BY DEVELOPER "AS IS" AND ANY
 *  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL DEVELOPER BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 *  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 *  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 *  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE PRODUCT, EVEN
 *  IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *======================== END OF LICENSE NOTICE ========================
 *  Primary Author: Kang Ning
 *  <kangning18z@ict.ac.cn>
 */

#ifndef KFD_IOCTL_H_INCLUDED
#define KFD_IOCTL_H_INCLUDED

#include <linux/types.h>
#include <linux/ioctl.h>

/* -------software-hardware interface{begin}------- */

#define MAX_MR_BATCH 512
#define MAX_QPC_BATCH 256

/* Resource LIMIT for one process */
#define RESC_LIM_LOG  16
#define RESC_LIM_MASK ((1 << RESC_LIM_LOG)-1)

/* Maximum width of the Resource. We supports 16 process in maximum */
#define RESC_LEN_LOG  (RESC_LIM_LOG + 4)

/* Valid bit in QPN, higher bits are process id */
#define QPN_MASK  RESC_LIM_MASK

/* min number of resource entries in one page, we use QPC (256 bytes) to make the calculation */
#define MIN_ENTRY_NUM_LOG 4

/* Maximum ICM Page num */
#define ICM_MAX_PAGE_NUM ((1 << RESC_LEN_LOG) >> MIN_ENTRY_NUM_LOG)

/* allocated page num one time */
#define ICM_ALLOC_PAGE_NUM (MAX_QPC_BATCH >> MIN_ENTRY_NUM_LOG)

/* mailbox page number */
#define MAILBOX_PAGE_NUM 32

/* max group number*/
#define MAX_GROUP_NUM 128
/* -------software-hardware interface{end}------- */

struct kfd_ioctl_init_dev_args {

    // Input
    uint8_t qpc_num_log;
    uint8_t cqc_num_log;
    uint8_t mpt_num_log;
    uint8_t mtt_num_log;
};

struct kfd_ioctl_init_mtt_args {
    
    // Input
    uint32_t batch_size;
    uint8_t* vaddr[MAX_MR_BATCH];
    
    // Output
    uint32_t mtt_index;
    uint64_t paddr[MAX_MR_BATCH];
};

// struct kfd_ioctl_alloc_mtt_args {
    
//     // Input
//     void* vaddr;
    
//     // Output
//     uint32_t mtt_index;
//     uint64_t paddr    ;
// };

// struct kfd_ioctl_write_mtt_args {

//     // Input
//     void* vaddr;
//     uint32_t mtt_index;
//     uint64_t paddr    ;
// };

struct kfd_ioctl_init_mpt_args {
    
    // Input
    uint8_t  flag     ;
    uint64_t addr     ;
    uint64_t length   ;
    uint32_t mtt_index; // Start index of mpt attached mtt resource

    // Output
    uint32_t mpt_index;
};

struct kfd_ioctl_alloc_mpt_args {
    
    /* Input */
    uint32_t batch_size;

    /* Output */
    uint32_t mpt_index;
};

struct kfd_ioctl_write_mpt_args {
    
    /* Input */
    uint32_t batch_size;
    uint8_t  flag     [MAX_MR_BATCH];
    uint64_t addr     [MAX_MR_BATCH];
    uint64_t length   [MAX_MR_BATCH];
    uint32_t mtt_index[MAX_MR_BATCH]; /* Start index of mpt attached mtt resource */
    uint32_t mpt_index[MAX_MR_BATCH];
};

struct kfd_ioctl_alloc_cq_args {

    /* Output */
    uint32_t cq_num;
};

struct kfd_ioctl_write_cqc_args {

    /* Input */
    uint32_t cq_num  ;
    uint32_t offset  ; /* The offset of CQ (0-4KB) */
    uint32_t lkey    ; /* lkey of the CQ */
    uint32_t size_log; /* The size of CQ. (It is now fixed at 4KB) */
};

struct kfd_ioctl_alloc_qp_args {

    /* Input */
    uint32_t batch_size;

    /* Output */
    uint32_t qp_num;
};

struct kfd_ioctl_write_qpc_args {

    /* Input */
    uint32_t batch_size;
    uint8_t  flag[MAX_QPC_BATCH]; /* QP state, not useed now */
    uint8_t  type[MAX_QPC_BATCH]; /* QP type */
    uint8_t  sq_size_log[MAX_QPC_BATCH]; /* The size of SQ in log (It is now fixed at 4KB, which is 12) */
    uint8_t  rq_size_log[MAX_QPC_BATCH]; /* The size of RQ in log (It is now fixed at 4KB, which is 12) */
    uint16_t snd_wqe_offset[MAX_QPC_BATCH]; /* Init offset of WQE in SQ */
    uint16_t rcv_wqe_offset[MAX_QPC_BATCH]; /* Init offset of WQE in RQ */
    uint16_t llid    [MAX_QPC_BATCH]; /* Local LID */
    uint16_t dlid    [MAX_QPC_BATCH]; /* Dest  LID */
    uint32_t src_qpn [MAX_QPC_BATCH]; /* Local qpn */
    uint32_t dest_qpn[MAX_QPC_BATCH]; /* Dest qpn  */
    uint32_t snd_psn [MAX_QPC_BATCH]; /* next send psn  */
    uint32_t ack_psn [MAX_QPC_BATCH]; /* last acked psn */
    uint32_t exp_psn [MAX_QPC_BATCH]; /* next receive (expect) psn */
    uint32_t cq_num  [MAX_QPC_BATCH]; /* CQ number */
    uint32_t snd_wqe_base_lkey[MAX_QPC_BATCH]; /* send wqe base lkey */
    uint32_t rcv_wqe_base_lkey[MAX_QPC_BATCH]; /* receive wqe base lkey */
    uint32_t qkey   [MAX_QPC_BATCH]; /* Queue key, used for UD incomming data validation */
    uint8_t  indicator [MAX_QPC_BATCH];
    uint8_t  weight    [MAX_QPC_BATCH];
    uint8_t  groupID   [MAX_QPC_BATCH];
};

struct kfd_ioctl_get_time_args {

    /* outut */
    uint64_t cur_time; /* current time of simulation */
};

struct kfd_ioctl_set_group_args {
    /* Input */
    uint8_t group_num;
    uint8_t group_id[MAX_GROUP_NUM];
    // uint16_t granularity[MAX_GROUP_NUM];
    uint16_t weight[MAX_GROUP_NUM];
};

struct kfd_ioctl_alloc_group_args {
    /* Input */
    uint8_t group_num;
    
    /* Output */
    uint8_t group_id[MAX_GROUP_NUM];
};

struct kfd_ioctl_update_group_args {
    /* Input */
    uint8_t group_id;
    uint16_t granularity;
};


#define HGKFD_IOCTL_BASE 'K'
#define HGKFD_IO(nr)			( _IO(HGKFD_IOCTL_BASE, nr)         )
#define HGKFD_IOR(nr, type)		( _IOR(HGKFD_IOCTL_BASE, nr, type)  )
#define HGKFD_IOW(nr, type)		( _IOW(HGKFD_IOCTL_BASE, nr, type)  )
#define HGKFD_IOWR(nr, type)    ( _IOWR(HGKFD_IOCTL_BASE, nr, type) )

#define HGKFD_IOC_INIT_DEV		\
		HGKFD_IOW(0x01, struct kfd_ioctl_init_dev_args)

#define HGKFD_IOC_ALLOC_MTT		\
		HGKFD_IOWR(0x02, struct kfd_ioctl_init_mtt_args)

#define HGKFD_IOC_WRITE_MTT		\
		HGKFD_IOW(0x03, struct kfd_ioctl_init_mtt_args)

#define HGKFD_IOC_ALLOC_MPT		\
		HGKFD_IOWR(0x04, struct kfd_ioctl_alloc_mpt_args)

#define HGKFD_IOC_WRITE_MPT		\
		HGKFD_IOW(0x05, struct kfd_ioctl_write_mpt_args)

#define HGKFD_IOC_ALLOC_CQ		\
		HGKFD_IOR(0x06, struct kfd_ioctl_alloc_cq_args)

#define HGKFD_IOC_WRITE_CQC		\
		HGKFD_IOW(0x07, struct kfd_ioctl_write_cqc_args)

#define HGKFD_IOC_ALLOC_QP		\
		HGKFD_IOR(0x08, struct kfd_ioctl_alloc_qp_args)

#define HGKFD_IOC_WRITE_QPC		\
		HGKFD_IOW(0x09, struct kfd_ioctl_write_qpc_args)

#define HGKFD_IOC_CHECK_GO		\
		HGKFD_IOW(0x0a, void)

#define HGKFD_IOC_GET_TIME		\
		HGKFD_IOW(0x0b, struct kfd_ioctl_get_time_args)

#define HGKFD_IOC_SET_GROUP  \
        HGKFD_IOW(0x0c, struct kfd_ioctl_set_group_args)

#define HGKFD_IOC_ALLOC_GROUP \
        HGKFD_IOWR(0x0d, struct kfd_ioctl_alloc_group_args)

#define HGKFD_IOC_UPDATE_QP_WEIGHT \
        HGKFD_IOWR(0x0e, struct kfd_ioctl_update_group_args)

#define HGKFD_COMMAND_START    0x01
#define HGKFD_COMMAND_END      0x0b

#endif
