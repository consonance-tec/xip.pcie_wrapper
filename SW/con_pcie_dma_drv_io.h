/*********************************************************************
	Component		: con_pcie_dma_drv_io_h
	Model Element	: con_pcie_dma_drv_io
	Version			: 1.1
	Company			: CONSONANCE
*********************************************************************/

#ifndef __con_pcie_dma_drv_io_h__
#define __con_pcie_dma_drv_io_h__

#pragma pack (push,1)

struct buffer_descriptor
{
	struct iocb iocb[1];
	struct iocb *pcb;
	int io_req_size;
	struct buffer_descriptor * pnext;
	void * user_buffer;
	uint64_t user_tag;
	int buffer_size;
	bool direction;
	bool is_pending;
	void *drv_data;
	void* user_data;
	uint32_t hw_param0;
	uint32_t hw_param1;
	uint32_t hw_param2;
	uint32_t hw_param3;
};


struct wr_param
{
	unsigned long direction;
	unsigned long address;
	unsigned long value;
	unsigned long reg_val;
	unsigned long bw;

};

struct usr_int_info
{
	uint32_t int_id;
	int usr_event;
	int pid;
};


struct bnet_header{
	uint32_t  msg_length_bytes;
	uint16_t  module_id;
	uint16_t  msg_id;
	uint32_t  seq_num;
	uint16_t  dpu_num;
	uint16_t  board_id;
	uint32_t  output_time_lsb;
	uint32_t  output_time_msb;
	uint32_t  input_time_lsb;
	uint32_t  input_time_msb;
};
#pragma pack (pop)


#define MAX_DBG_STR	256


#define CXF_FC_SET_IO_RESOURCES_NUM			1
#define CXF_FREE_IO_RESOURCES_NUM			2
#define CXF_SET_USER_INTERRUPT			3
#define CXF_CLEAR_USER_INTERRUPT			4
#define CXF_DEBUG_QUERY				5
#define CXF_WAIT_ON_USER_INTERRUPT			6
#define CXF_CANCCEL_USER_INTERRUPT			7
#define CXF_REG_WR_REQUEST				8
#define CXF_ENA_CHANNEL_INTERRUPT			9
#define CXF_DIS_CHANNEL_INTERRUPT			10
#define CXF_START					11
#define CXF_STOP					12
#define CXF_GET_PCIE_CORE_VER				13
#define CXF_GET_DRIVER_VER				14
#define CXF_GET_NUM_OF_CHAN				15
#define CXF_QUERY_CHAN_INFO				16
#define CXF_QUERY_NUM_OF_BOARD			17
#define CXF_LOCK_BUFFER				18
#define CXF_UNLOCK_BUFFER				19
#define CXF_SYSTEM_RESET				20
#define CXF_RESET_CHANNEL				21
#define CXF_QUERY_NUM_OF_USR_INT			22
#define CXF_DBG_MSG					23
#define CXF_GET_CHANNLE_STATE				24
#define CXF_SET_MAX_READ_REQ				25

////////////////////////////////////// RAVIV START //////////////////////////////////////
#define CXF_GET_UI_TIME_TAG				35

typedef struct  ui_time_tag
{
        unsigned long   ui;
        long int                        sec;
        long int                        usec;
        long int                        mono_sec;
        long int                        mono_usec;
}	ui_time_tag_t;
////////////////////////////////////// RAVIV END ////////////////////////////////////////



//error codes
#define DMA_DONE						(0)
#define DMA_STOPPED						(-113)
#define LOCK_BUFFER_FAILED					(-100)
#define SG_ALLOC_FAILED						(-101)
#define DMA_MAP_SG_FAILED					(-102)
#define REC_ARRAY_ALLOC_FAILED					(-103)


#endif // __con_pcie_dma_drv_io_h__
