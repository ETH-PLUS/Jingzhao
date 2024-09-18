
#include "libhgrnic.h"

#define SLEEP_CNT 1000

void wait(uint32_t n) {
    for (uint32_t i = 0; i < n; ++i);
}

int cpu_sync(struct ibv_context *context) {

    // HGRNIC_PRINT("Start cpu_sync!\n");

    struct hghca_context *dvr = context->dvr;

    /* post completion to sync reg */
    dvr->sync[0] = 1;

    /* Wait for other CPUs comming */
    do {
        get_time(context);
        // wait(SLEEP_CNT);
    } while (dvr->sync[0] != 1);
    // HGRNIC_PRINT("cpu_sync: wait for other CPUs comming!\n");

    /* post exit to sync reg */
    dvr->sync[0] = 0;

    /* Wait for other CPUs exit */
    do {
        get_time(context);
        // wait(SLEEP_CNT);
    } while (dvr->sync[0] != 0);

    // HGRNIC_PRINT("cpu_sync: out!\n");
    return 0;
}


void trans_wait(struct ibv_context *context) {

    struct hghca_context *dvr = (struct hghca_context *)context->dvr;

    ioctl(dvr->fd, HGKFD_IOC_CHECK_GO, NULL);
}

uint8_t write_cmd(int fd, unsigned long request, void *args) {
    while (ioctl(fd, request, (void *)args)) {
        // HGRNIC_PRINT(" %ld ioctl failed try again\n", request);
        wait(SLEEP_CNT);
        // usleep(1);
    }
    do {
        wait(SLEEP_CNT);
    } while (ioctl(fd, HGKFD_IOC_CHECK_GO, NULL));

    return 0;
}


int ibv_open_device(struct ibv_context *context, uint16_t lid) {

    context->lid = lid;
    
    /* Init fd */
    context->dvr = malloc(sizeof(struct hghca_context));
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    char file_name[100];
    sprintf(file_name, KERNEL_FILE_NAME "%d", cpu_id);
    dvr->fd = open(file_name, O_RDWR);
    // HGRNIC_PRINT(" open /dev/hangu_rnic success!\n");

    /* map doorbell to user space */
    dvr->doorbell = mmap(NULL, DB_LEN, PROT_READ | PROT_WRITE, 
            MAP_SHARED, dvr->fd, 0);
    dvr->sync     = (void *)((uint64_t)dvr->doorbell + 8);
    // HGRNIC_PRINT(" get dvr->doorbell 0x%lx\n", (uint64_t)dvr->doorbell);
    
    /* Init ICM */
    struct kfd_ioctl_init_dev_args *args = 
            (struct kfd_ioctl_init_dev_args *)malloc(sizeof(struct kfd_ioctl_init_dev_args));
    args->qpc_num_log = 16; /* useless here */
    args->cqc_num_log = 16; /* useless here */
    args->mpt_num_log = 19; /* useless here */
    args->mtt_num_log = 19; /* useless here */
    write_cmd(dvr->fd, HGKFD_IOC_INIT_DEV, (void *)args);
    free(args);

    /* create group for CM */
    int cm_group_weight = 10;
    struct ibv_qos_group *cm_group = create_qos_group(context, cm_group_weight);
    // int cm_weight = 1024;
    // uint16_t *cm_weight = (uint16_t*)malloc(sizeof(uint16_t));
    // *cm_weight = 20;
    // set_qos_group(context, cm_group, 1, cm_weight);
    // free(cm_weight);

    /* Init communication management */
    struct ibv_mr_init_attr mr_attr;
    mr_attr.length = PAGE_SIZE;
    mr_attr.flag = MR_FLAG_RD | MR_FLAG_WR | MR_FLAG_LOCAL;
    context->cm_mr = ibv_reg_mr(context, &mr_attr);

    struct ibv_cq_init_attr cq_attr;
    cq_attr.size_log = PAGE_SIZE_LOG;
    context->cm_cq = ibv_create_cq(context, &cq_attr);
    // HGRNIC_PRINT(" ibv_open_device cq lkey: 0x%x, vaddr 0x%lx, mtt_index 0x%x, paddr 0x%lx\n", 
            context->cm_cq->mr->lkey, (uint64_t)context->cm_cq->mr->addr, context->cm_cq->mr->mtt->mtt_index, context->cm_cq->mr->mtt->paddr);

    struct ibv_qp_create_attr qp_attr;
    qp_attr.sq_size_log = PAGE_SIZE_LOG;
    qp_attr.rq_size_log = PAGE_SIZE_LOG;
    context->cm_qp = ibv_create_qp(context, &qp_attr);

    context->cm_qp->ctx = context;
    context->cm_qp->type = QP_TYPE_UD;
    context->cm_qp->cq = context->cm_cq;
    context->cm_qp->snd_wqe_offset = 0;
    context->cm_qp->rcv_wqe_offset = 0;
    context->cm_qp->lsubnet.llid = context->lid;
    context->cm_qp->qkey = QKEY_CM;

    context->cm_qp->indicator = BANDWIDTH;
    context->cm_qp->weight = 10;
    context->cm_qp->group_id = cm_group->id;
    // cm_group->total_qp_weight += context->cm_qp->weight;
    ibv_modify_qp(context, context->cm_qp);

    // HGRNIC_PRINT("CM QP created! QPN: %d, indicator: %d, weight: %d, group id: %d\n", 
        context->cm_qp->qp_num, context->cm_qp->indicator, context->cm_qp->weight, context->cm_qp->group_id);
    // HGRNIC_PRINT("CM group created! group_id: %d, group weight: %d\n", cm_group->id, cm_group->weight);

    context->cm_rcv_posted_off = RCV_WR_BASE;
    context->cm_rcv_acked_off  = RCV_WR_BASE;
    context->cm_snd_off        = SND_WR_BASE;
    context->cm_rcv_num        = 0;

    // HGRNIC_PRINT(" Exit ibv_open_device: out!\n");
    return 0;
}


struct ibv_cq * ibv_create_cq(struct ibv_context *context, struct ibv_cq_init_attr *cq_attr) {

    // HGRNIC_PRINT(" enter ibv_create_cq!\n");
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct ibv_cq *cq = (struct ibv_cq *)malloc(sizeof(struct ibv_cq));

    /* Allocate CQ */
    struct kfd_ioctl_alloc_cq_args *create_cq_args = 
            (struct kfd_ioctl_alloc_cq_args *)malloc(sizeof(struct kfd_ioctl_alloc_cq_args));
    write_cmd(dvr->fd, HGKFD_IOC_ALLOC_CQ, (void *)create_cq_args);
    cq->cq_num  = create_cq_args->cq_num;
    cq->ctx     = context;
    cq->offset  = 0;
    cq->cpl_cnt = 0;
    free(create_cq_args);
    
    
    /* Init (Allocate and write) MTT && MPT */
    struct ibv_mr_init_attr *mr_attr = 
            (struct ibv_mr_init_attr *)malloc(sizeof(struct ibv_mr_init_attr));
    mr_attr->flag   = MR_FLAG_RD | MR_FLAG_LOCAL;
    mr_attr->length = (1 << cq_attr->size_log); // (PAGE_SIZE << 2); // !TODO: Now the size is a fixed number of 1 page
    cq->mr = ibv_reg_mr(context, mr_attr);
    free(mr_attr);

    /* write CQC */
    struct kfd_ioctl_write_cqc_args *write_cqc_args = 
            (struct kfd_ioctl_write_cqc_args *)malloc(sizeof(struct kfd_ioctl_write_cqc_args));
    write_cqc_args->cq_num   = cq->cq_num;
    write_cqc_args->offset   = cq->offset;
    write_cqc_args->lkey     = cq->mr->lkey;
    write_cqc_args->size_log = PAGE_SIZE_LOG;
    write_cmd(dvr->fd, HGKFD_IOC_WRITE_CQC, (void *)write_cqc_args);
    free(write_cqc_args);
    return cq;
}

/**
 * @note Allocate a batch of QP, with conntinuous qpn and the same qp_attr
 */
struct ibv_qp * ibv_create_batch_qp(struct ibv_context *context, struct ibv_qp_create_attr *qp_attr, uint32_t batch_size) {

    // HGRNIC_PRINT(" enter ibv_create_batch_qp!\n");

    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct ibv_qp *qp = (struct ibv_qp *)malloc(sizeof(struct ibv_qp) * batch_size);
    memset(qp, 0, sizeof(struct ibv_qp));

    /* allocate QP */
    uint32_t batch_cnt = 0;
    uint32_t batch_left = batch_size;
    struct kfd_ioctl_alloc_qp_args *qp_args = 
            (struct kfd_ioctl_alloc_qp_args *)malloc(sizeof(struct kfd_ioctl_alloc_qp_args));
    while (batch_left > 0) {

        uint32_t sub_bsz = (batch_left > MAX_QPC_BATCH) ? MAX_QPC_BATCH : batch_left;
        
        qp_args->batch_size = sub_bsz;
        write_cmd(dvr->fd, HGKFD_IOC_ALLOC_QP, (void *)qp_args);
        for (uint32_t i = 0; i < sub_bsz; ++i) {
            qp[batch_cnt + i].qp_num = qp_args->qp_num + i;
            // // HGRNIC_PRINT(" Get out of HGKFD_IOC_ALLOC_QP! the %d-th qp, qpn is : 0x%x(%d)\n", batch_cnt + i, qp[batch_cnt + i].qp_num, qp[batch_cnt + i].qp_num&RESC_LIM_MASK);
        }

        batch_cnt  += sub_bsz;
        batch_left -= sub_bsz;
        assert(batch_cnt + batch_left == batch_size);
    }
    free(qp_args);

    // Init (Allocate and write) QP MTT && MPT
    struct ibv_mr_init_attr *mr_attr = 
            (struct ibv_mr_init_attr *)malloc(sizeof(struct ibv_mr_init_attr));
    mr_attr->flag   = MR_FLAG_WR | MR_FLAG_LOCAL;
    mr_attr->length = (1 << qp_attr->sq_size_log); // !TODO: Now the size is a fixed number of 1 page
    struct ibv_mr *tmp_mr = ibv_reg_batch_mr(context, mr_attr, batch_size * 2);
    for (uint32_t i = 0; i < batch_size; ++i) {
        qp[i].rcv_mr = &(tmp_mr[2 * i]);
        qp[i].snd_mr = &(tmp_mr[2 * i + 1]);
        // HGRNIC_PRINT(" Get out of ibv_reg_batch_mr in create_qp! qpn is : 0x%x rcv_mr 0x%x snd_mr 0x%x\n", 
                qp[i].qp_num, qp[i].rcv_mr->lkey, qp[i].snd_mr->lkey);
    }
    free(mr_attr);

    return qp;
}

/**
 * @note Now, SQ and RQ has their own MR respectively.
 */
struct ibv_qp * ibv_create_qp(struct ibv_context *context, struct ibv_qp_create_attr *qp_attr) {

    // HGRNIC_PRINT(" enter ibv_create_qp!\n");

    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct ibv_qp *qp = (struct ibv_qp *)malloc(sizeof(struct ibv_qp));
    memset(qp, 0, sizeof(struct ibv_qp));

    // allocate QP
    struct kfd_ioctl_alloc_qp_args *qp_args = 
            (struct kfd_ioctl_alloc_qp_args *)malloc(sizeof(struct kfd_ioctl_alloc_qp_args));
    qp_args->batch_size = 1;
    write_cmd(dvr->fd, HGKFD_IOC_ALLOC_QP, (void *)qp_args);
    qp->qp_num = qp_args->qp_num;
    // HGRNIC_PRINT(" Get out of HGKFD_IOC_ALLOC_QP! qpn is : 0x%x\n", qp->qp_num);
    free(qp_args);

    // Init (Allocate and write) SQ MTT && MPT
    struct ibv_mr_init_attr *mr_attr = 
            (struct ibv_mr_init_attr *)malloc(sizeof(struct ibv_mr_init_attr));
    mr_attr->flag   = MR_FLAG_WR | MR_FLAG_LOCAL;
    mr_attr->length = (1 << qp_attr->sq_size_log); // !TODO: Now the size is a fixed number of 1 page
    qp->snd_mr = ibv_reg_mr(context, mr_attr);

    // Init (Allocate and write) RQ MTT && MPT 
    mr_attr->flag   = MR_FLAG_WR | MR_FLAG_LOCAL;
    mr_attr->length = (1 << qp_attr->rq_size_log); // !TODO: Now the size is a fixed number of 1 page
    qp->rcv_mr = ibv_reg_mr(context, mr_attr);
    // HGRNIC_PRINT(" Get out of ibv_reg_mr in create_qp! qpn is : 0x%x\n", qp->qp_num);
    free(mr_attr);

    return qp;
}

int ibv_modify_batch_qp(struct ibv_context *context, struct ibv_qp *qp, uint32_t batch_size) {
    // HGRNIC_PRINT(" enter ibv_modify_batch_qp!\n");
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;

    /* write QP */
    struct kfd_ioctl_write_qpc_args *qpc_args = 
            (struct kfd_ioctl_write_qpc_args *)malloc(sizeof(struct kfd_ioctl_write_qpc_args));
    memset(qpc_args, 0, sizeof(struct kfd_ioctl_write_qpc_args));
    uint32_t batch_cnt = 0;
    uint32_t batch_left = batch_size;
    while (batch_left > 0) {
        
        uint32_t sub_bsz = (batch_left > MAX_QPC_BATCH) ? MAX_QPC_BATCH : batch_left;
        // HGRNIC_PRINT(" ibv_modify_batch_qp! batch_cnt %d batch_left %d sub_bsz %d\n", batch_cnt, batch_left, sub_bsz);

        qpc_args->batch_size = sub_bsz;
        for (int i = 0; i < sub_bsz; ++i) {
            qpc_args->flag    [i] = qp[batch_cnt + i].flag;
            qpc_args->type    [i] = qp[batch_cnt + i].type;
            qpc_args->llid    [i] = qp[batch_cnt + i].lsubnet.llid;
            qpc_args->dlid    [i] = qp[batch_cnt + i].dsubnet.dlid;
            qpc_args->src_qpn [i] = qp[batch_cnt + i].qp_num;
            qpc_args->dest_qpn[i] = qp[batch_cnt + i].dest_qpn;
            qpc_args->snd_psn [i] = qp[batch_cnt + i].snd_psn;
            qpc_args->ack_psn [i] = qp[batch_cnt + i].ack_psn;
            qpc_args->exp_psn [i] = qp[batch_cnt + i].exp_psn;
            qpc_args->cq_num  [i] = qp[batch_cnt + i].cq->cq_num;
            qpc_args->snd_wqe_base_lkey[i] = qp[batch_cnt + i].snd_mr->lkey;
            qpc_args->rcv_wqe_base_lkey[i] = qp[batch_cnt + i].rcv_mr->lkey;
            qpc_args->snd_wqe_offset   [i] = qp[batch_cnt + i].snd_wqe_offset;
            qpc_args->rcv_wqe_offset   [i] = qp[batch_cnt + i].rcv_wqe_offset;
            qpc_args->qkey       [i] = qp[batch_cnt + i].qkey;
            qpc_args->sq_size_log[i] = PAGE_SIZE_LOG; // qp->snd_mr->length;
            qpc_args->rq_size_log[i] = PAGE_SIZE_LOG; // qp->rcv_mr->length;


            qpc_args->indicator[i]  = qp[batch_cnt + i].indicator;
            qpc_args->weight[i]     = qp[batch_cnt + i].weight;
            qpc_args->groupID[i]    = qp[batch_cnt + i].group_id;

            // HGRNIC_PRINT(" ibv_modify_batch_qp! qpn 0x%x, indicator: %d, weight: %d, group: %d\n", 
                qp[batch_cnt + i].qp_num, qp[batch_cnt + i].indicator, qp[batch_cnt + i].weight, qp[batch_cnt + i].group_id);
        }
        write_cmd(dvr->fd, HGKFD_IOC_WRITE_QPC, qpc_args);
        
        batch_cnt  += sub_bsz;
        batch_left -= sub_bsz;
        assert(batch_cnt + batch_left == batch_size);
        write_cmd(dvr->fd, HGKFD_IOC_UPDATE_QP_WEIGHT, qpc_args);
    }
    free(qpc_args);
    
    // update all QP granularity
    // update_all_group_granularity(context);
    
    // HGRNIC_PRINT(" ibv_modify_batch_qp: out!\n");
    return 0;
}

int ibv_modify_qp(struct ibv_context *context, struct ibv_qp *qp) {
    // HGRNIC_PRINT(" enter ibv_modify_qp!\n");
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;

    /* write QP */
    struct kfd_ioctl_write_qpc_args *qpc_args = 
            (struct kfd_ioctl_write_qpc_args *)malloc(sizeof(struct kfd_ioctl_write_qpc_args));
    memset(qpc_args, 0, sizeof(struct kfd_ioctl_write_qpc_args));
    qpc_args->batch_size = 1;
    qpc_args->flag    [0] = qp->flag;
    qpc_args->type    [0] = qp->type;
    qpc_args->llid    [0] = qp->lsubnet.llid;
    qpc_args->dlid    [0] = qp->dsubnet.dlid;
    qpc_args->src_qpn [0] = qp->qp_num;
    qpc_args->dest_qpn[0] = qp->dest_qpn;
    qpc_args->snd_psn [0] = qp->snd_psn;
    qpc_args->ack_psn [0] = qp->ack_psn;
    qpc_args->exp_psn [0] = qp->exp_psn;
    qpc_args->cq_num  [0] = qp->cq->cq_num;
    qpc_args->snd_wqe_base_lkey[0] = qp->snd_mr->lkey;
    qpc_args->rcv_wqe_base_lkey[0] = qp->rcv_mr->lkey;
    qpc_args->snd_wqe_offset   [0] = qp->snd_wqe_offset;
    qpc_args->rcv_wqe_offset   [0] = qp->rcv_wqe_offset;
    qpc_args->qkey       [0] = qp->qkey;
    qpc_args->sq_size_log[0] = PAGE_SIZE_LOG; // qp->snd_mr->length;
    qpc_args->rq_size_log[0] = PAGE_SIZE_LOG; // qp->rcv_mr->length;
    
    // added by mazhenlong
    qpc_args->indicator[0]  = qp->indicator;
    qpc_args->weight[0]     = qp->weight;
    qpc_args->groupID[0]    = qp->group_id;
    // HGRNIC_PRINT(" ibv_modify_qp! qpn 0x%x, indicator: %d, weight: %d, group: %d\n", 
                qp->qp_num, qp->indicator, qp->weight, qp->group_id);
    write_cmd(dvr->fd, HGKFD_IOC_WRITE_QPC, qpc_args);
    write_cmd(dvr->fd, HGKFD_IOC_UPDATE_QP_WEIGHT, qpc_args);
    free(qpc_args);
    // HGRNIC_PRINT(" ibv_modify_qp out! qpn: %d\n", qp->qp_num);

    // update group granularity
    // update_all_group_granularity(context);
    
    return 0;
}

struct ibv_mr * ibv_reg_batch_mr(struct ibv_context *context, struct ibv_mr_init_attr *mr_attr, uint32_t batch_size) {
    // HGRNIC_PRINT(" ibv_reg_batch_mr!\n");
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct ibv_mr *mr =  (struct ibv_mr *)malloc(sizeof(struct ibv_mr) * batch_size);

    uint32_t batch_cnt = 0;
    uint32_t batch_left = batch_size;
    struct kfd_ioctl_init_mtt_args *mtt_args =
                (struct kfd_ioctl_init_mtt_args *)malloc(sizeof(struct kfd_ioctl_init_mtt_args));
    struct kfd_ioctl_alloc_mpt_args *mpt_alloc_args = 
                (struct kfd_ioctl_alloc_mpt_args *)malloc(sizeof(struct kfd_ioctl_alloc_mpt_args));
    struct kfd_ioctl_write_mpt_args *mpt_args = 
                (struct kfd_ioctl_write_mpt_args *)malloc(sizeof(struct kfd_ioctl_write_mpt_args));
    while (batch_left > 0) {
        uint32_t sub_bsz = 0;
        sub_bsz = (batch_left > MAX_MR_BATCH) ? MAX_MR_BATCH : batch_left;
        
        /* Init (Allocate and write) MTT */
        for (uint32_t i = 0; i < sub_bsz; ++i) {
            /* Calc needed number of pages */
            mr[batch_cnt + i].num_mtt = (mr_attr->length >> 12) + (mr_attr->length & 0xFFF) ? 1 : 0;
            assert(mr[batch_cnt + i].num_mtt == 1);
            
            /* !TODO: Now, we require allocated memory's start 
            * vaddr is at the boundry of one page */ 
            mr[batch_cnt + i].addr   = memalign(PAGE_SIZE, mr_attr->length);
            memset(mr[batch_cnt + i].addr, 0, mr_attr->length);
            mr[batch_cnt + i].ctx = context;
            mr[batch_cnt + i].flag   = mr_attr->flag;
            mr[batch_cnt + i].length = mr_attr->length;
            mr[batch_cnt + i].mtt    = (struct ibv_mtt *)malloc(sizeof(struct ibv_mtt) * mr->num_mtt);

            mr[batch_cnt + i].mtt[0].vaddr = (void *)(mr[batch_cnt + i].addr);
            mtt_args->vaddr[i] = mr[batch_cnt + i].mtt[0].vaddr;
        }
        mtt_args->batch_size = sub_bsz;
        write_cmd(dvr->fd, HGKFD_IOC_ALLOC_MTT, (void *)mtt_args);
        for (uint32_t i = 0; i < sub_bsz; ++i) {
            mr[batch_cnt + i].mtt[0].mtt_index = mtt_args->mtt_index + i;
            mr[batch_cnt + i].mtt[0].paddr = mtt_args->paddr[i];
        }
        mtt_args->batch_size = sub_bsz;
        write_cmd(dvr->fd, HGKFD_IOC_WRITE_MTT, (void *)mtt_args);

        /* Allocate MPT */
        mpt_alloc_args->batch_size = sub_bsz;
        write_cmd(dvr->fd, HGKFD_IOC_ALLOC_MPT, (void *)mpt_alloc_args);
        for (uint32_t i = 0; i < sub_bsz; ++i) {
            mr[batch_cnt + i].lkey = mpt_alloc_args->mpt_index + i;
            assert(mr[batch_cnt + i].lkey == mr[batch_cnt + i].mtt->mtt_index);
            // // HGRNIC_PRINT(" ibv_reg_batch_mr: mpt_idx 0x%x mtt_idx 0x%x\n", mr[batch_cnt + i].lkey, mr[batch_cnt + i].mtt->mtt_index);
        }

        /* Write MPT */
        mpt_args->batch_size = sub_bsz;
        for (uint32_t i = 0; i < sub_bsz; ++i) {
            mpt_args->flag[i]      = mr[batch_cnt + i].flag;
            mpt_args->addr[i]      = (uint64_t) mr[batch_cnt + i].addr;
            mpt_args->length[i]    = mr[batch_cnt + i].length;
            mpt_args->mtt_index[i] = mr[batch_cnt + i].mtt[0].mtt_index;
            mpt_args->mpt_index[i] = mr[batch_cnt + i].lkey;
        }
        write_cmd(dvr->fd, HGKFD_IOC_WRITE_MPT, (void *)mpt_args);

        /* update finished  */
        batch_left -= sub_bsz;
        batch_cnt += sub_bsz;
        assert(batch_cnt + batch_left == batch_size);
    }
    free(mtt_args);
    free(mpt_alloc_args);
    free(mpt_args);

    // HGRNIC_PRINT(" ibv_reg_batch_mr!: out!\n");
    return mr;
}

struct ibv_mr * ibv_reg_mr(struct ibv_context *context, struct ibv_mr_init_attr *mr_attr) {
    // HGRNIC_PRINT(" ibv_reg_mr!\n");
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct ibv_mr *mr =  (struct ibv_mr *)malloc(sizeof(struct ibv_mr));

    /* Calc needed number of pages */
    mr->num_mtt = (mr_attr->length >> 12) + (mr_attr->length & 0xFFF) ? 1 : 0;
    assert(mr->num_mtt == 1);
    
    /* !TODO: Now, we require allocated memory's start 
     * vaddr is at the boundry of one page */ 
    mr->addr   = memalign(PAGE_SIZE, mr_attr->length);
    memset(mr->addr, 0, mr_attr->length);
    mr->ctx = context;
    mr->flag   = mr_attr->flag;
    mr->length = mr_attr->length;
    mr->mtt    = (struct ibv_mtt *)malloc(sizeof(struct ibv_mtt) * mr->num_mtt);
    for (uint64_t i = 0; i < mr->num_mtt; ++i) {
        mr->mtt[i].vaddr = (void *)(mr->addr + (i << PAGE_SIZE_LOG));
    
        /* Init (Allocate and write) MTT */
        struct kfd_ioctl_init_mtt_args *mtt_args =
                (struct kfd_ioctl_init_mtt_args *)malloc(sizeof(struct kfd_ioctl_init_mtt_args));
        mtt_args->batch_size = 1;
        mtt_args->vaddr[0] = mr->mtt[i].vaddr;
        write_cmd(dvr->fd, HGKFD_IOC_ALLOC_MTT, (void *)mtt_args);
        mr->mtt[i].mtt_index = mtt_args->mtt_index;
        mr->mtt[i].paddr = mtt_args->paddr[0];
        write_cmd(dvr->fd, HGKFD_IOC_WRITE_MTT, (void *)mtt_args);
        free(mtt_args);
    }

    /* Allocate MPT */
    struct kfd_ioctl_alloc_mpt_args *mpt_alloc_args = 
            (struct kfd_ioctl_alloc_mpt_args *)malloc(sizeof(struct kfd_ioctl_alloc_mpt_args));
    mpt_alloc_args->batch_size = 1;
    write_cmd(dvr->fd, HGKFD_IOC_ALLOC_MPT, (void *)mpt_alloc_args);
    mr->lkey = mpt_alloc_args->mpt_index;
    free(mpt_alloc_args);

    /* Write MPT */
    struct kfd_ioctl_write_mpt_args *mpt_args = 
            (struct kfd_ioctl_write_mpt_args *)malloc(sizeof(struct kfd_ioctl_write_mpt_args));
    mpt_args->batch_size = 1;
    mpt_args->flag[0]      = mr->flag;
    mpt_args->addr[0]      = (uint64_t) mr->addr;
    mpt_args->length[0]    = mr->length;
    mpt_args->mtt_index[0] = mr->mtt[0].mtt_index;
    mpt_args->mpt_index[0] = mr->lkey;
    write_cmd(dvr->fd, HGKFD_IOC_WRITE_MPT, (void *)mpt_args);
    free(mpt_args);

    // HGRNIC_PRINT(" ibv_reg_mr: out!\n");
    return mr;
}


/**
 * @note    Post Send (Send/RDMA Write/RDMA Read) request (list) to hardware.
 *          Support any number of WQE posted.
 * 
 */
int ibv_post_send(struct ibv_context *context, struct ibv_wqe *wqe, struct ibv_qp *qp, uint8_t num) {
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    volatile uint64_t *doorbell = dvr->doorbell;

    struct send_desc *tx_desc;
    uint16_t sq_head = qp->snd_wqe_offset;
    uint8_t first_trans_type = wqe[0].trans_type;
    int snd_cnt = 0;
    for (int i = 0; i < num; ++i) {
        /* Get send Queue */
        tx_desc = (struct send_desc *) (qp->snd_mr->addr + qp->snd_wqe_offset);
        
        /* Add Base unit */
        // tx_desc->opcode = (i == num - 1) ? IBV_TYPE_NULL : wqe[i+1].trans_type;
        // tx_desc->flags  = 0;
        tx_desc->flags  = wqe[i].flag;
        tx_desc->opcode = wqe[i].trans_type;

        /* Add data unit */
        tx_desc->len = wqe[i].length;
        tx_desc->lkey = wqe[i].mr->lkey;
        tx_desc->lVaddr = (uint64_t)wqe[i].mr->addr + wqe[i].offset;

        /* Add RDMA unit */
        if (wqe[i].trans_type == IBV_TYPE_RDMA_WRITE || 
            wqe[i].trans_type == IBV_TYPE_RDMA_READ) {
            tx_desc->rdma_type.rkey = wqe[i].rdma.rkey;
            tx_desc->rdma_type.rVaddr_h = wqe[i].rdma.raddr >> 32;
            tx_desc->rdma_type.rVaddr_l = wqe[i].rdma.raddr & 0xffffffff;
        }

        /* Add UD Send unit */
        if (wqe[i].trans_type == IBV_TYPE_SEND &&
            qp->type == QP_TYPE_UD) {
            tx_desc->send_type.dest_qpn = wqe[i].send.dqpn;
            tx_desc->send_type.dlid = wqe[i].send.dlid;
            tx_desc->send_type.qkey = wqe[i].send.qkey;
        }
    
        /* update send queue */
        ++snd_cnt;
        qp->snd_wqe_offset += sizeof(struct send_desc);
        if (qp->snd_wqe_offset + sizeof(struct send_desc) > qp->snd_mr->length) { /* In case the remaining space 
                                                                                    * is not enough for one descriptor. */
            /* Post send doorbell */
            // tx_desc->opcode  = IBV_TYPE_NULL;
            uint32_t db_low  = (sq_head << 4) | first_trans_type;
            uint32_t db_high = (qp->qp_num << 8) | snd_cnt;
            *doorbell = ((uint64_t)db_high << 32) | db_low;
            
            sq_head = 0;
            first_trans_type = (i == num - 1) ? IBV_TYPE_NULL : wqe[i+1].trans_type;
            snd_cnt = 0;
            qp->snd_wqe_offset = 0; /* SQ MR is allocated in page, so 
                                     * the start address (offset) is 0 */
            
            // // HGRNIC_PRINT(" 1db_low is 0x%x, db_high is 0x%x\n", db_low, db_high);
            // HGRNIC_PRINT("Remaining space if not enough for one desc!\n");
        }

        // uint8_t *u8_tmp = (uint8_t *)tx_desc;
        // for (int i = 0; i < sizeof(struct send_desc); ++i) {
        //     // HGRNIC_PRINT(" data[%d] 0x%x\n", i, u8_tmp[i]);
        // }
        // // HGRNIC_PRINT("WQE opcode: %d\n", tx_desc->opcode);
        assert(tx_desc->opcode != 0);
    }

    if (snd_cnt) {
        /* Post send doorbell */
        uint32_t db_low  = (sq_head << 4) | first_trans_type;
        uint32_t db_high = (qp->qp_num << 8) | snd_cnt;
        *doorbell = ((uint64_t)db_high << 32) | db_low;

        // // HGRNIC_PRINT(" db_low is 0x%x, db_high is 0x%x\n", db_low, db_high);
    }

    return 0;
}

int ibv_post_recv(struct ibv_context *context, struct ibv_wqe *wqe, struct ibv_qp *qp, uint8_t num) {
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    // struct Doorbell *boorbell = dvr->doorbell;

    struct recv_desc *rx_desc;

    for (int i = 0; i < num; ++i) {
        /* Get Receive Queue */
        rx_desc = (struct recv_desc *) (qp->rcv_mr->addr + qp->rcv_wqe_offset);
        
        /* Add basic element */
        rx_desc->len = wqe[i].length;
        rx_desc->lkey = wqe[i].mr->lkey;
        rx_desc->lVaddr = (uint64_t)wqe[i].mr->addr + wqe[i].offset;
        
        // // HGRNIC_PRINT(" len is %d, lkey is %d, lvaddr is 0x%lx\n", rx_desc->len, rx_desc->lkey, rx_desc->lVaddr);
    
        /* update Receive Queue */
        qp->rcv_wqe_offset += sizeof(struct recv_desc);
        if (qp->rcv_wqe_offset  + sizeof(struct recv_desc) > qp->rcv_mr->length) { /* In case the remaining space 
                                                                                   * is not enough for one descriptor. */
            qp->rcv_wqe_offset = 0; /* RQ MR is allocated in page, so 
                                     * the start address (offset) is 0 */
        }
    }

    return 0;
}

/**
 * @note Poll at most 100 cpl one time
 * 
 */
int ibv_poll_cpl(struct ibv_cq *cq, struct cpl_desc **desc, int max_num) {
    int cnt = 0;

    for (cnt = 0; cnt < max_num; ++cnt) {
        struct cpl_desc *cq_desc = (struct cpl_desc *)(cq->mr->addr + cq->offset);
        if (cq_desc->byte_cnt != 0) {
            memcpy(desc[cnt], cq_desc, sizeof(struct cpl_desc));
            // memset(cq_desc, 0, sizeof(struct cpl_desc));
            cq_desc->byte_cnt = 0; /* clear CQ cpl */

            /* Update offset */
            ++cq->cpl_cnt;
            cq->offset += sizeof(struct cpl_desc);
            if (cq->offset + sizeof(struct cpl_desc) > cq->mr->length) {
                cq->offset = 0;
            }
            // // HGRNIC_PRINT("poll cpl! cqn: %d, cq offset: 0x%x, qpn: %d\n", cq->cq_num, cq->offset, cq_desc->qp_num);
        } else {
            break;
        }
    }

    return cnt;
}

/**
 * @note create one QoS group
*/
struct ibv_qos_group *create_qos_group(struct ibv_context *context, int weight)
{
    context->group_num++;
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    struct kfd_ioctl_alloc_group_args *args = (struct kfd_ioctl_alloc_group_args *)malloc(sizeof(struct kfd_ioctl_alloc_group_args));
    args->group_num = 1;
    write_cmd(dvr->fd, HGKFD_IOC_ALLOC_GROUP, args);
    
    // Allocate space for newly allocated group
    context->qos_group = (struct ibv_qos_group *)realloc(context->qos_group, (context->group_num) * sizeof(struct ibv_qos_group));
    struct ibv_qos_group *new_group = context->qos_group + (context->group_num - 1);
    new_group->weight = weight;
    new_group->id = args->group_id[0];
    // context->total_group_weight += weight;
    // HGRNIC_PRINT("QoS group created! id: %d, weight: %d\n", args->group_id[0], weight);
    uint16_t *weight_temp = (uint16_t*)malloc(sizeof(uint16_t));
    *weight_temp = weight;
    set_qos_group(context, new_group, 1, weight_temp);
    free(weight_temp);
    free(args);
    return new_group;
}

/**
 * @note set QoS group scheduling weight. This function updates all group granularity
*/
int set_qos_group(struct ibv_context *context, struct ibv_qos_group *group, uint8_t group_num, uint16_t *weight)
{
    struct kfd_ioctl_set_group_args *args = (struct kfd_ioctl_set_group_args *)malloc(sizeof(struct kfd_ioctl_set_group_args));
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    args->group_num = group_num;
    for (int i = 0; i < args->group_num; i++)
    {
        args->group_id[i] = group[i].id;
        args->weight[i] = weight[i];
        // HGRNIC_PRINT("QoS group granularity set! id: %d, weight: %d\n", group[i].id, weight[i]);
    }
    write_cmd(dvr->fd, HGKFD_IOC_SET_GROUP, args);
    free(args);
}

void update_all_group_granularity(struct ibv_context *context)
{
    struct kfd_ioctl_set_group_args *args = (struct kfd_ioctl_set_group_args *)malloc(sizeof(struct kfd_ioctl_set_group_args));
    struct hghca_context *dvr = (struct hghca_context *)context->dvr;
    args->group_num = 0;
    write_cmd(dvr->fd, HGKFD_IOC_SET_GROUP, args);
    free(args);
}