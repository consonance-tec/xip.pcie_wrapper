/*
 * ccons_pci.h
 *
 *  Created on: Mar 25, 2020
 *      Author: ido
 */

#ifndef CCONS_PCI_H_
#define CCONS_PCI_H_

#define	E9999	9999
#define	E9998	9998
#define	E9997	9997
#define	E9996	9996
#define	E9995	9995
#define	E9994	9994
#define	E9993	9993
#define	E9992	9992
#define	E9991	9991
#define	E9990	9990
#define	E9989	9989
#define	E9988	9988

//#define MSIX_SUPPORT

#define MAX_NUM_OF_BARS 	6

#define GLOB_INT_ENA	(1<<1)

//registers addresses/offsets forom the beginning of the registeres file
#define CTRL_STAT_ADD				0x00
#define INT_STAT_ADD				0x04
#define FRM_INDEX_COUNT_ADD			0x08
#define SYS_DESC_INDEX_ADD			0x0C
#define SYS_DESC_DATA_ADD			0x10

#define PCIE_CORE_VER				0x00
#define PCIE_CORE_DATE				0x04
#define NUM_OF_USER_INT				0x08
#define NUM_OF_CHANNELS				0x0c
#define DMA_CHANNELS				0x10

////////////// BASE IP parameters 
#define PCIE_CORE_DATE_BASE_VER		0x01
#define NUM_OF_USER_INT_BASE_VER	0x02
#define NUM_OF_CHANNELS_BASE_VER	0x03
#define CHANNELS_DIR_BASE_VER		0x04

#define NUM_OF_SYS_REGISTERS		5
#define NUM_OF_CHAN_REGISTERS		6
#define FIRST_CHANNLE_REGS_OFFSET	NUM_OF_SYS_REGISTERS


///////////////

//SYSTEM CTRL_STAT Register Bitmap
#define SYS_ENA				(1<<0)
#define GLOB_INT_ENA				(1<<1)
#define MSIX_ENA				(1<<2)
#define SYS_WIDTH_32				(0<<2)
#define SYS_RESET				(1<<3)
#define INT_MASK_BIT(x)			(1 << (4+x))

#define DMA_REGISTER_CMD_STAT 		0x00
#define DMA_REGISTER_ADD_LOW 			0x04
#define DMA_REGISTER_ADD_HIGH 		0x08
#define DMA_REGISTER_LEN 			0x0C
#define CHAN_RD_MAX_LEN			0x14

//DMA channel
//CMD_STAT register bitmap indexes
#define ACTIVE_BIT		(1<<0)	// Bit(0) ACTIVE
#define STATE_BIT		(1<<1)	// Bit(1) State bit - RO 1- Active 0- NotActive
#define START_BIT		(1<<2)	// Bit(2) START_BIT
#define TRN_EIT_ENA		(1<<3)	// Bit(4) Taransfer done int enable
#define SG_BIT			(1<<4)	// Bit(5) Scatteg Gather
#define STOP_BIT		(1<<7)	// Bit(7) Stop DMA
#define RESET_BIT		(1<<8)  // Bit(8) Reset the

#ifdef LITTEL_2_BIG
#define SWAP32(x)			(((x & 0xff000000)>>24 ) | \
					((x & 0x00ff0000)>>8 ) | \
					((x & 0x0000ff00)<<8 ) | \
					((x & 0x000000ff)<<24 ))
#else
#define SWAP32(x) x
#endif

#define DMA_C2S_OBJ_IDENTIFIER 	0xa1b2c3d4
#define DMA_S2C_OBJ_IDENTIFIER 	0xa5b6c7d8
#define USER_INTERRUPT			0xa9bacbdc
#define BAR_OBJ_IDENTIFIER 		0x0d0e0f10



//SG RECORD BITMAP
#define SG_REC_INT		(1<<1)
#define SG_REC_LAST		(1<<0)
#define SG_REC_DIR		(1<<0)

#define SG_REC_DONE		(1<<0)
#define SG_REC_ACTIVE		(1<<1)
#define SG_REC_NOT_IN_USE	(1<<2)
#define SG_REC_CANCELED		(3<<0)
#define SG_REC_STATUS_MASK	(7) //bits 0,1,2


#define BAR0_REGION_SIZE 256



typedef enum _channel_state {inactive = 0, active = 1, stopping = 2} channel_state;

struct dma_record
{
	uint32_t res;
	uint32_t address_low;
	uint32_t address_high;
	uint32_t buffer_size;

};

struct dma_descriptor
{
	//dma
	uint32_t next_desc_address_low;
	uint32_t next_desc_address_high;
	uint32_t transfer_data_count;
	uint32_t status_control;
	uint32_t number_of_records;
	uint32_t records_list_address_low;
	uint32_t records_list_address_high;
	uint32_t res; //make the struct aligned on a pow of 2 (32 bytes).
	uint32_t param0;
	uint32_t param1;
	uint32_t param2;
	uint32_t param3;
};


struct descriptor_instance
{
	//dma part
	struct dma_descriptor *pdmap_desc;
	struct kiocb *iocb;
	uint64_t desc_phy_addr;
	struct  loocked_user_buffer *lub;
	uint32_t dec_id;
	uint16_t  msg_id;
	uint32_t  seq_num;
	struct descriptor_instance *pnext;
};



struct ccons_dev {
	int	ifn;
	int	inst;
	void *object;
	struct cdev cdev;
	int	q_head;
	int	q_tail;
	atomic_t q_cnt;
	struct mutex ccons_mutex;
	/*


	str_my_timer	smt,smt_rw;

	pstr_q_t	pq[MAX_Q_NUM];


	//struct	task_struct	*ts;

	ULONG m_Id;
	BOOLEAN m_bUseChannelInterrupt;
	ULONG m_NumOfDescritpors;
	ULONG m_NumOfRecordsPerDescriptor;
	SG_CHANNLE_REGS m_Registers;
	BOOLEAN m_bDesArrayFull;
	int m_PutDescIndex;
	int m_CurrDescIndex;
	PSG_DESC_INST *m_pDescInst;
	PUCHAR m_pResIOSpace;

	ULONG m_CompCnt;
	BOOLEAN m_Active;

//	wait_queue_head_t	wq;
//	int	caller;
	void	*pChan;


	//int	irq_num	;
	 *
	 */

};

#pragma pack(1)
struct object
{
	uint32_t object_identifier;
	char name[32];
};

struct loocked_user_buffer
{
	struct	page **user_pp; //array to a page pointer
	int	user_num_of_locked_pages;
	struct sg_table user_sg;
	uint64_t user_tag;
	bool dir;
	int user_num_of_mapped_regions;
	int num_of_rec;
	struct dma_record *rec_array;
	dma_addr_t record_dma_handle;
	int record_array_size;
	void *process_virtural_addr;

};

struct user_interrupt
{
#ifdef MSIX_SUPPORT
	struct object obj_ident;
#endif	
	int64_t qstatus_word;
	uint32_t int_count;
	uint32_t regs_offset;
	int efd;
	int pid;
	struct work_struct wq;
	struct eventfd_ctx * efd_ctx;
};

struct channel
{
	struct object obj_ident;
	unsigned int num_of_descriptors;
	unsigned int id;
	uint32_t chan_regs_offset;
	void *ccons_device;
	bool in_use;
	bool full;
	bool dir;
	int pending;
	uint32_t completion_num;
	uint64_t comleted_count;
	uint64_t started_count;
	channel_state state;
	struct pcie_device *pcie_dev;
	struct mutex stop_mutex;
	struct list_head list;
	int desc_alloc_size;
	void *desc_ptr;
	dma_addr_t desc_dma_handle;
	struct work_struct wq;
	struct descriptor_instance *pdesc_instance;
	struct descriptor_instance *tail;
	struct descriptor_instance *head;

};

struct pcie_bar
{
	struct object obj_ident;
	int id;
	bool mapped;
	void *p_bar;
	void *ccons_device;
	unsigned long long memlen;
	unsigned long long memstart;
	struct pcie_device* pcie_dev;
};

struct pcie_device
{
	struct pcie_bar bars_array[MAX_NUM_OF_BARS];
	unsigned long ctrl_shadow_reg;
	bool is_base_ip_ver;
	int num_of_c2s_channels;
	int num_of_s2c_channels;
	struct list_head c2s_channels;
	struct list_head s2c_channels;
	struct pci_dev *linux_pci_dev;
	int	ch_caller;
	int	ui_caller;
	int base_irq;
	unsigned int ccons_major;
	unsigned long pcie_dma_core_ver;
	unsigned long pcie_dma_core_date;
	int num_of_user_interrupts;
	struct user_interrupt *pui_array;
	dma_addr_t ui_mem_alloc_handle;
	bool b_exit;
	wait_queue_head_t ch_wq;
	wait_queue_head_t ui_wq;
	int	num_of_msix;
	struct msix_entry *msix_entry;

////////////////////////////////////// RAVIV START //////////////////////////////////////
	unsigned long uiTimeTag[2][4];
////////////////////////////////////// RAVIV END ////////////////////////////////////////

};

#endif /* CCONS_PCI_H_ */
