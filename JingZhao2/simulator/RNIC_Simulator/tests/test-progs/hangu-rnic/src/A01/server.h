#define TRANS_WRDMA_DATA "Hello World!  Hello RDMA Write! Hello World!  Hello RDMA Write!"
#define TRANS_RRDMA_DATA "Hello World!  Hello RDMA Read ! Hello World!  Hello RDMA Read !"

// #define TEST_QP_NUM   1
// #define TEST_CQ_NUM ((TEST_QP_NUM / (300 / num_client) ) + 1)
#define THPT_WR_NUM 50
#define BW_WR_NUM 1
// #define LATENCY_WR_NUM 1
#define TEST_TIME 10UL // milisecond

struct perf_record
{
    uint64_t *qp_data_count;
};

struct qp_comm_record
{
    uint64_t *qp_data_count;
    uint64_t *cqe_count;
};

// struct perf_record record;

void generate_wqe(struct rdma_resc *resc, uint8_t op_mode, uint32_t msg_size, uint32_t offset, int wr_num);
int judge_latency(uint8_t cpu_id);