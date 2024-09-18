#ifndef __LIBRDMA_H__
#define __LIBRDMA_H__

#include "libhgrnic.h"
#include <getopt.h>
#include <pthread.h>

#define TEST_QP_NUM   1
#define TEST_CQ_NUM ((TEST_QP_NUM / (300 / num_client) ) + 1)
// #define TEST_WR_NUM 10
#define LATENCY_WR_NUM 1

#define S  (1000UL * MS)
#define MS (1000UL * US)
#define US (1000UL * NS)
#define NS (1000UL)

/* QP indicator */
#define LAT_QP 1
#define BW_QP 2
#define RATE_QP 3


/* valid op-mode */
#define OPMODE_RDMA_WRITE    0
#define OPMODE_RDMA_READ     1

#ifdef COLOR

#ifdef SERVER

#define RDMA_PRINT(name, x, ...) do {                                                      \
            printf("[\033[1;33m" "SERVER: " #name "%s-%d\033[0m] " x, id_name, cpu_id, ##__VA_ARGS__);\
        } while (0)

#else

#define RDMA_PRINT(name, x, ...) do {                                                      \
            printf("[\033[1;33m" "CLIENT: " #name "%s-%d\033[0m] " x, id_name, cpu_id, ##__VA_ARGS__);\
        } while (0)

#endif

#else

#ifdef SERVER

#define RDMA_PRINT(name, x, ...) do {                                     \
            printf("[" "SERVER: " #name "%s-%d] " x, id_name, cpu_id, ##__VA_ARGS__);\
        } while (0)

#else

#define RDMA_PRINT(name, x, ...) do {                                     \
            printf("[" "CLIENT: " #name "%s-%d] " x, id_name, cpu_id, ##__VA_ARGS__);\
        } while (0)

#endif


#endif


/* Connection Request Type */
enum rdma_cr_type {
    CR_TYPE_NULL= (uint8_t)0x00,
    CR_TYPE_REQ = (uint8_t)0x01,
    CR_TYPE_ACK = (uint8_t)0x02,
    CR_TYPE_NAK = (uint8_t)0x04,
    CR_TYPE_RKEY= (uint8_t)0x10,
    CR_TYPE_SYNC= (uint8_t)0x20
};

/* used to store remote information */
struct rem_info {
    uint64_t raddr;
    uint32_t rkey;
    // uint32_t qpn;
    uint16_t dlid;

    int start_off; /* qp start offset in rdma_resc */
    int sum; /* number of qp connected for one client */

    /** 
     * == 1 if recved sync req
     */
    uint8_t sync_flag;
};

struct rdma_resc {
    struct ibv_context *ctx;

    int num_mr;
    int num_cq;
    int num_qp; /* number of qps per client */
    int num_rem; /* number of remote client (or server) */
    
    struct ibv_mr **mr;
    struct ibv_cq **cq;
    struct ibv_qp **qp;

    struct rem_info *rinfo;

    // /** 
    //  * true if recved sync req, 
    //  * size is equal to num_rem.
    //  */
    // uint8_t *sync_flag; 

    struct cpl_desc **desc;

    struct ibv_qos_group **qos_group;
    struct ibv_wqe *wqe;
};

// struct rdma_cr_cpl_cnt {

// };

/**
 * @note This struct is transmitted through QP0.
 *       It is known as Connection Requester.
 */
struct rdma_cr {

    enum rdma_cr_type flag;
    enum ibv_qp_type qp_type;

    uint16_t src_lid; /* client's LID */
    uint32_t src_qpn; /* client's QPN */
    uint32_t dst_qpn; /* server's QPN */

    uint32_t rkey; /* client's or server's MR rkey */
    uint64_t raddr; /* client's or server's remote Addr */

    /* Valid in RC trans type */
    uint32_t snd_psn; /* send PSN number in Requester */

    /* Valid in UD trans type */
    uint32_t src_qkey; /* qkey in Requester */
};


struct rdma_resc *rdma_resc_init(struct ibv_context *ctx, int num_mr, int num_cq, int num_qp, uint16_t llid, int num_rem);
struct rdma_cr *rdma_listen(struct rdma_resc *resc, int *cm_cpl_num);
int rdma_connect(struct rdma_resc *resc, struct rdma_cr *cr_info, uint16_t *dest_info, int cm_req_num);
int rdma_send_sync(struct rdma_resc *resc);
int rdma_recv_sync(struct rdma_resc *resc);

// void set_group_granularity(struct rdma_resc *grp_resc);
void set_qos_group_weight(struct ibv_qos_group *group, int weight);
struct ibv_qos_group *create_comm_group(struct ibv_context *ctx, int group_weight);
// void set_all_granularity(struct ibv_context *ctx);

#endif // __LIBRDMA_H__