#include "librdma.h"
#include "test.h"

int clt_update_qps(struct rdma_resc *resc, uint16_t svr_lid) {

    /* Modify Local QP */
    uint32_t qpn_bia = (resc->ctx->lid - svr_lid);
    for (int i = 0; i < resc->num_qp; ++i) {
        // RDMA_PRINT(Client, "clt_update_qps: start modify_qp, sum %d, cq sum %d\n", 
        // i, i % TEST_CQ_NUM);
        struct ibv_qp *qp = resc->qp[i];
        qp->ctx = resc->ctx;
        qp->flag = 0;
        qp->type = QP_TYPE_RC;
        qp->cq = resc->cq[i % TEST_CQ_NUM];// 
        qp->snd_wqe_offset = 0;
        qp->rcv_wqe_offset = 0;
        qp->lsubnet.llid = resc->ctx->lid;
        // qp->dest_qpn = (cpu_id << RESC_LIM_LOG) + qpn_bia + i * num_client; // cr_rcv[i].dst_qpn;
        qp->dest_qpn = qp->qp_num; //WARNING!
        qp->snd_psn = 0;
        qp->ack_psn = 0;
        qp->exp_psn = 0;
        qp->dsubnet.dlid = svr_lid;
        qp->indicator = BW_QP;
        qp->group_id = resc->qos_group[0]->id;
        // ibv_modify_qp(resc->ctx, qp);
        RDMA_PRINT(Client, "clt_update_qps: modify_qp, src_qpn %d, dst_qpn %d, lid %d\n", 
                qp->qp_num, qp->dest_qpn, resc->ctx->lid);
    }
    ibv_modify_batch_qp(resc->ctx, resc->qp[0], resc->num_qp);

    return 0;
}

int clt_update_info(struct rdma_resc *resc, uint16_t svr_lid) {
    RDMA_PRINT(Client, "start clt_update_info\n");
    int num = 0;
    struct rdma_cr *cr_snd;
    uint16_t *dest_info = (uint16_t *)malloc(sizeof(uint16_t));
    struct rdma_cr *cr_rcv;

    cr_snd = (struct rdma_cr *)malloc(sizeof(struct rdma_cr));
    memset(cr_snd, 0, sizeof(struct rdma_cr));

    cr_snd->flag    = CR_TYPE_REQ;
    cr_snd->src_lid = resc->ctx->lid;
    cr_snd->rkey    = resc->mr[0]->lkey; /* only use one mr in our design */
    cr_snd->raddr   = (uintptr_t)resc->mr[0]->addr; /* only use one mr in our design */
    dest_info[0]    = svr_lid;
    rdma_connect(resc, cr_snd, dest_info, 1); /* post connection request to server (QP0) */
    RDMA_PRINT(Client, "clt_update_info: send raddr %ld, rkey 0x%x\n", cr_snd->raddr, cr_snd->rkey);

    while (num == 0) {
        cr_rcv = rdma_listen(resc, &num); /* listen connection request from client (QP0) */
    }
    RDMA_PRINT(Client, "clt_update_info: rdma_listen end, recved %d CR data\n", num);

    /* get remote addr information */
    resc->rinfo->dlid  = svr_lid;
    resc->rinfo->raddr = cr_rcv->raddr;
    resc->rinfo->rkey  = cr_rcv->rkey;
    RDMA_PRINT(Client, "clt_update_info: raddr %ld, rkey 0x%x\n", resc->rinfo->raddr, resc->rinfo->rkey);

    /* modify qp in client side */
    clt_update_qps(resc, svr_lid);

    return 0;
}

static void usage(const char *argv0) {
    printf("Usage:\n");
    printf("  %s            start a client and build connection\n", argv0);
    printf("  %s <host>     connect to server at <host>\n", argv0);
    printf("\n");
    printf("Options:\n");
    printf("  -l, --llid=<lid>                  local lid (default 0x1)\n");
    printf("  -s, --svr-lid=<lid>               server's lid (default 0x0)\n");
    printf("  -t, --num-client=<num_client>     number of clients (default 1)\n");
    printf("  -c, --cpu-id=<cpu_id>             id of the cpu (default 0)\n");
    printf("  -m, --op-mode=<op_mode>           opcode mode (default 0, which is RDMA Write)\n");
}

int clt_fill_mr(struct ibv_mr *mr, uint32_t offset) {

#define TRANS_WRDMA_DATA "Hello World!  Hello RDMA Write! Hello World!  Hello RDMA Write!"
#define TRANS_RRDMA_DATA "Hello World!  Hello RDMA Read ! Hello World!  Hello RDMA Read !"
    
    char *string = (char *)(mr->addr + offset);
    memcpy(string, TRANS_RRDMA_DATA, sizeof(TRANS_RRDMA_DATA));

    return 0;
}

int main (int argc, char **argv) {

    int num_mr, num_cq, num_qp;
    // uint16_t dlid;
    int res;
    uint16_t llid = 1, svr_lid = 0;
    num_client = 1;
    uint8_t op_mode = OPMODE_RDMA_WRITE;
    sprintf(id_name, "%d", llid);

    while (1) {
        int c;

        static struct option long_options[] = {
            { .name = "local-lid" ,   .has_arg = 1, .val = 'l' },
            { .name = "server-lid",   .has_arg = 1, .val = 's' },
            { .name = "num-client",   .has_arg = 1, .val = 't' },
            { .name = "cpu-id"    ,   .has_arg = 1, .val = 'c' },
            { .name = "op-mode"   ,   .has_arg = 1, .val = 'm' },
            { 0 }
        };

        c = getopt_long(argc, argv, "s:l:t:c:m:", long_options, NULL);
        if (c == -1)
            break;

        switch (c) {
        case 'l':
            if (!sscanf(optarg, "%hd", &llid)) {
                RDMA_PRINT(Client, "Error in llid parser. Exit.\n");
                exit(-1);
            }
            break;

        case 's':
            if (!sscanf(optarg, "%hd", &svr_lid)) {
                RDMA_PRINT(Client, "Error in svr_lid parser. Exit.\n");
                exit(-1);
            }
            break;

        case 't':
            if (!sscanf(optarg, "%d", &num_client)) {
                RDMA_PRINT(Client, "Error in num client parser. Exit.\n");
                exit(-1);
            }
            break;
        case 'c':
            if (!sscanf(optarg, "%hhd", &cpu_id)) {
                RDMA_PRINT(Server, "Error in cpu id parser. Exit.\n");
                exit(-1);
            }
            break;
        case 'm':
            if (!sscanf(optarg, "%hhd", &op_mode)) {
                RDMA_PRINT(Server, "Error in op-mode parser. Exit.\n");
                exit(-1);
            }
            break;

        default:
            usage(argv[0]);
            return 1;
        }
    }

    sprintf(id_name, "%d", llid);
    RDMA_PRINT(Client, "num_client %d\n", num_client);
    RDMA_PRINT(Client, "llid is 0x%x\n", llid);
    RDMA_PRINT(Client, "dlid is 0x%x\n", svr_lid);
    
    num_mr = 1;
    num_cq = TEST_CQ_NUM;
    num_qp = TEST_QP_NUM;

    struct ibv_context *ib_context = (struct ibv_context *)malloc(sizeof(struct ibv_context));

    /* device initialization */
    ibv_open_device(ib_context, llid);

    RDMA_PRINT(Client, "Open device!\n");

    // int group_num = 4;
    int *group_qp_num = (int *)malloc(sizeof(int) * group_num);
    int *group_weight = (int *)malloc(sizeof(int) * group_num);
    struct rdma_resc **grp_resc = (struct rdma_resc**)malloc(sizeof(struct rdma_resc *) * group_num);

    for (int i = 0; i < group_num; i++) {
        group_qp_num[i] = qp_per_group;
        group_weight[i] = 10;
        grp_resc[i] = rdma_resc_init(ib_context, num_mr, num_cq, group_qp_num[i], llid, 1);
        struct ibv_qos_group *group = create_comm_group(ib_context, group_weight[i]);
        grp_resc[i]->qos_group[0] = group;
        RDMA_PRINT(Client, "group[%d] resouce initialized! i: %d, cpu id: %d\n", grp_resc[i]->qos_group[0]->id, i, cpu_id);
    }

    RDMA_PRINT(Client, "client ready to update info! cpu id: %d\n", cpu_id);

    /* Connect QPs to server's QP */
    for (int i = 0; i < group_num; i++) {
        clt_update_info(grp_resc[i], svr_lid);
        RDMA_PRINT(Client, "group [%d] update info! i: %d, cpu id: %d\n", grp_resc[i]->qos_group[0]->id, i, cpu_id);
    }

    /* sync to make sure that we could get start */
    rdma_send_sync(grp_resc[0]);
    RDMA_PRINT(Client, "ready for server send RDMA write\n");

    /* Wait for Completion of rdma write processing */
    rdma_send_sync(grp_resc[0]);

    /* close the fd */
    RDMA_PRINT(Client, "fd : %d\n", ((struct hghca_context*)grp_resc[0]->ctx->dvr)->fd);
    close(((struct hghca_context*)grp_resc[0]->ctx->dvr)->fd);
    
    return 0;
}