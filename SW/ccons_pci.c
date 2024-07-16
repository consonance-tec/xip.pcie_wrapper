#include <linux/version.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <linux/err.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <linux/aio.h>
#include <linux/uio.h>
#include <linux/fs.h>
#include <linux/module.h>                         // MOD_DEVICE_TABLE,
#include <linux/init.h>
#include <linux/pci.h>                            // pci_device_id,
#include <linux/dma-mapping.h>
#include <linux/scatterlist.h>
#include <linux/interrupt.h>
#include <asm/uaccess.h>                          // copy_to_user,
#include <linux/version.h>                        // KERNEL_VERSION,
#include <iso646.h>
#include <asm/uaccess.h>
#include <linux/pagemap.h>
//#include <asm/msr.h>
#include <linux/pid.h>
#include <linux/sched.h>
#include <linux/fdtable.h>
#include <linux/rcupdate.h>
#include <linux/eventfd.h>
#include <linux/fdtable.h>
#include <linux/timer.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/list.h>
#include <linux/ioctl.h>
#include <linux/msi.h>
#include <linux/workqueue.h>
#include "con_pcie_dma_drv_io.h"
#include "ccons_pci.h"

///////////////////////////////////////////////////////////////////////////////////////////
// debug flag on/off
//#define DEBUG_IOCTL
//#define DEBUG_INTERRUPT
//#define DEBUG_TM
///////////////////////////////////////////////////////////////////////////////////////////


//TODO:
//0) add the stop event
//1) handle the case of buffers that the (number of record)*(size of record) is not a multiple of 128
//2) handle short c2s packets (with last)
//3) add msix support
//4) add user interrupts support
//5) add multiple msi support
//6) check with 256 bit bus
//7) check with 64 bit bus

MODULE_AUTHOR("ia");
MODULE_LICENSE("GPL");


#define DINAMIC_USER_MAPPING
#define LOG(x)

#define CCONS_DEVICE_BAR_NAME "ccons_pcie_bar" //device for each bar
#define CCONS_DEVICE_C2S_NAME "ccons_pcie_c2s" //device for each dma card to system (IN)
#define CCONS_DEVICE_S2C_NAME "ccons_pcie_s2c" //device for each dma system to card (out)


#define HW_REG_READ(base ,offset) ioread32(((unsigned char *)base)+offset)
#define HW_REG_WRITE(base, offset, value) {iowrite32(value,((unsigned char *)base)+offset);}


#define SIZE_OF_MSG_BUFFER		32
#define USER_MESG_INDECATION	0xaaaaaaaa

#define MAX_BUFF_PER_DESCRIPTOR (5*1024*1024)

#define NUM_OF_DESCRIPTORS 		10

typedef enum _device_type {c2s, s2c, bar} device_type;

#define GET_CONTAINER(c,ct,it) ((ct*)(((uintptr_t)(c)) - offsetof(ct, it)))

/* ================================================================ */

// note : this bloc must be extended to support multiple cards //( made into an array of # of possible cards )

void disable_interrupt(struct pcie_device *pcie_device);
struct pcie_device *create_new_pcie_dev(struct pci_dev *dev);
unsigned int read_reg(void *base, unsigned int offset);
void write_reg(void *base, unsigned long long offset, unsigned int value);
static int init_channel(struct channel *channel, struct pcie_device *pcie_device, bool dir, unsigned int id, uint32_t chan_regs_offset, int num_of_desc);
static void del_channel_resources(struct channel *channel);
int channels_init(struct pcie_device * pcie_device);
u8 get_revision(struct pci_dev *dev);
static irqreturn_t pci_isr(int irq, void *dev_id, struct pt_regs *regs);
static int device_init(struct pci_dev *pci_dev, const struct pci_device_id *p_id);
static void device_deinit(struct pci_dev *pci_dev);
static ssize_t start_io(struct channel *chan, struct kiocb *iocb ,struct loocked_user_buffer *lub, int req_len, uint32_t param0, uint32_t param1, uint32_t param2, uint32_t param3);
static int __init ccons_init_module(void);
static void __exit ccons_exit_module(void);
int create_logical_devices(struct pcie_device *pcie_device);
int	isr_callback_thr(void *arg);
void interrupt_handler(struct pcie_device *pcie_device);
static void ccons_cleanup_module(struct pcie_device *pcie_device);
static void ccons_destroy_device(struct pcie_device *pcie_device, int devnode,struct ccons_dev *dev, int minor, struct class *class, device_type type);
static int ccons_construct_device(struct pcie_device *pcie_device, int devnode_id ,struct ccons_dev *dev, int minor, struct class *class, device_type type);
static int lock_user_buffer(struct pcie_device *pcie_device,struct buffer_descriptor *buf_desc);
static int unlock_user_buffer(struct pcie_device *pcie_device, struct buffer_descriptor *buf_desc);
static int map_user_buffer(struct pcie_device *pcie_device,struct  loocked_user_buffer *lub);
static int unmap_user_buffer(struct pcie_device *pcie_device, struct  loocked_user_buffer *lub);
static void copy_descriptor(struct dma_descriptor *dest, struct dma_descriptor *src);
static void copy_channel_descriptors(struct channel* channel);
#ifdef MSIX_SUPPORT
static struct channel* find_channle(struct pcie_device* pcie_device, int chan_dir, int chan_id);
#endif
static uint32_t get_channel_offset(struct pcie_device* pcie_device, int chan_id);
static void chan_do_tasklet(struct work_struct* wk);
static void ui_do_tasklet(struct work_struct* wk);
int stop_channel(struct channel *channel);
void close_channel(struct channel *channel);
int flush_desc_list(struct channel *channel);
void delete_channels(struct list_head *head);
int ccons_open(struct inode *inode, struct file *filp);
long ccons_ioctl(struct file * file, unsigned int cmd, unsigned long arg);
ssize_t ccons_read_write_iter (struct kiocb *iocb, struct iov_iter *iov_iter);
int ccons_close(struct inode *inode, struct file *filp);
int start_channel(struct channel *channel);
void open_channel(struct channel *channel);


static struct
pci_device_id pci_drv_ids[] =
{
  { PCI_DEVICE(0x1172, 0xE003), },
  { PCI_DEVICE(0x10EE, 0x7021), },
  { PCI_DEVICE(0x10EE, 0x7024), },
  { PCI_DEVICE(0x1172, 0x0004), },
  { PCI_DEVICE(0x1172, 0xE001), },
  { PCI_DEVICE(0x1234, 0x5678), },
  { PCI_DEVICE(0x1234, 0x3456), },
  { PCI_DEVICE(0x1234, 0xa104), },
  { PCI_DEVICE(0x1234, 0xa108), },
  { PCI_DEVICE(0x4040, 0x3131), },
  { PCI_DEVICE(0x4040, 0x3030), },
  { PCI_DEVICE(0x1234, 0x2828), },
  { PCI_DEVICE(0x1234, 0x9034), },
  { PCI_DEVICE(0x1234, 0x4321), },
  { PCI_DEVICE(0x1234, 0x1234), },
  { PCI_DEVICE(0x1234, 0xa1a1), },
  { 0, }
};
MODULE_DEVICE_TABLE(pci, pci_drv_ids);
uint32_t ver_mg = 0x00000005;
uint32_t ver_mn = 0x00000000;

static struct class *ccons_class_bar = NULL;
static struct class *ccons_class_c2s = NULL;
static struct class *ccons_class_s2c = NULL;
static int probed = 0;
static int no_devs=1;

static int open_fds = 0;


static unsigned int ccons_major = 0;

static struct
pci_driver ccons_pci_data =
{
  .name= "ccons_pci",
  .id_table = pci_drv_ids,
  .probe = device_init,
  .remove = device_deinit,
};

struct file_operations ccons_fops = {
	.owner = THIS_MODULE,
	.open = ccons_open,
	.release = ccons_close,
	.unlocked_ioctl = ccons_ioctl,
	.read_iter =  ccons_read_write_iter,
	.write_iter = ccons_read_write_iter
	/*
	.read =     ccons_read,
	.write =    ccons_write,


	*/
};

int ccons_close(struct inode *inode, struct file *filp)
{

	struct ccons_dev *dev = (struct ccons_dev *)filp->private_data;
	struct object *obj = (struct object *)dev->object;

	//printk("ccons:close called -->\n");

	if(obj->object_identifier != BAR_OBJ_IDENTIFIER)
	{
		close_channel((struct channel *)dev->object);
	}
	else
	{
#ifdef DEBUG_IOCTL
		printk("ccons:close called for a bar obj=%p  pcie_dev = %p-->\n",obj,((struct pcie_bar *)obj)->pcie_dev);
#endif
	}

	open_fds--;
	//printk("ccons:close called <-- %d\n",open_fds);	
#ifdef DEBUG_IOCTL
	printk("ccons:ccons_close called <------obj %p\n\n",obj);
#endif

	return 0;
}


int ccons_open(struct inode *inode, struct file *filp)
{
	//unsigned int mj = imajor(inode);
	//unsigned int mn = iminor(inode);

	struct ccons_dev *dev =  (struct ccons_dev *)container_of(inode->i_cdev, struct ccons_dev, cdev);
	struct object *obj = (struct object *)dev->object;

	//printk("ccons:open >>> %s %p\n", obj->name, dev);
#ifdef DEBUG_IOCTL
	printk("ccons:ccons_open called ------> obj %p\n",obj);
#endif


	filp->private_data = dev;

	if (inode->i_cdev != &dev->cdev)
	{
		printk(KERN_WARNING "[target] open: internal error\n");
		return -ENODEV; /* No such device */
	}
	

	if(obj->object_identifier != BAR_OBJ_IDENTIFIER)
		open_channel((struct channel *)dev->object);
	else {
#ifdef DEBUG_IOCTL
		struct pcie_bar *bar =  (struct pcie_bar *)dev->object;
		printk("ccons:ccons_open BAR %p pcie_dev %p\n",bar, bar->pcie_dev);
#endif

//		open_channel((struct channel *)dev->object);
//		printk("ccons:ccons_open BAR %p pcie_dev %p after open channel\n",bar, bar->pcie_dev);

	}

	open_fds++;
	//printk("ccons:open called ret ok  <--\n");
	return 0;
}



struct eventfd_ctx *find_user_efd(int pid,int efd)
{
struct task_struct * userspace_task = NULL; //...to userspace program's task struct
struct file * efd_file = NULL;          //...to eventfd's file struct
struct eventfd_ctx * efd_ctx = NULL;        //...and finally to eventfd context

    printk(KERN_ALERT "~~~Received from userspace: pid=%d efd=%d\n",pid,efd);

    userspace_task = pid_task(find_vpid(pid), PIDTYPE_PID);
    printk(KERN_ALERT "~~~Resolved pointer to the userspace program's task struct: %p\n",userspace_task);

    printk(KERN_ALERT "~~~Resolved pointer to the userspace program's files struct: %p\n",userspace_task->files);

#if (LINUX_VERSION_CODE < KERNEL_VERSION(5, 8, 0))    
    rcu_read_lock();
    efd_file = fcheck_files(userspace_task->files, efd);
    rcu_read_unlock();
#else
    efd_file = files_lookup_fd_locked(userspace_task->files, efd);
#endif

    printk(KERN_ALERT "~~~Resolved pointer to the userspace program's eventfd's file struct: %p\n",efd_file);


    efd_ctx = eventfd_ctx_fileget(efd_file);
    if (!efd_ctx)
	{
        printk(KERN_ALERT "~~~eventfd_ctx_fileget() Jhol, Bye.\n");
    }
	//else
    	printk(KERN_ALERT "~~~Resolved pointer to the userspace program's eventfd's context: %p\n",efd_ctx);

   return efd_ctx;


}


long ccons_ioctl(struct file * file, unsigned int cmd, unsigned long arg)
{
	struct ccons_dev *dev = (struct ccons_dev *)file->private_data;
	struct object *obj = (struct object *)dev->object;
	struct pcie_device *pcie_device;
	struct channel *chan;
	int num_of_channels;
	uint32_t v;
	uint32_t dw_arg;
	uint16_t channel_id;
	uint32_t dir;
	//unsigned long chan_dir_bitmap;
	void *bar0;
	int rc = -1;
	unsigned long ret;

	//printk("************ ccons_ioctl  %d\n",cmd);
#ifdef DEBUG_IOCTL
	if (obj->object_identifier == BAR_OBJ_IDENTIFIER)
	{
		printk("************ ccons_ioctl >>>>>  cmd %d obj %p obj_id %x pcie_dev %p\n",cmd , obj, obj->object_identifier, ((struct pcie_bar *)obj)->pcie_dev);
	}
	else
	{
		printk("************ ccons_ioctl >>>>>  cmd %d obj %p obj_id %x NOT A BAR\n",cmd , obj, obj->object_identifier);

		//printk("************ ccons_ioctl >>>>>  cmd %d obj %p obj_id %x pcie_dev %p NOT A BAR\n",cmd , obj, obj->object_identifier, ((struct pcie_bar *)obj)->pcie_dev);
	}
#endif
	switch (cmd)
	{
		case CXF_DEBUG_QUERY:
		{

			struct pcie_bar* bar = (struct pcie_bar*)dev->object;

			int i;
			struct channel * chan;
			struct list_head *listptr;
		
			pcie_device = (struct pcie_device*)bar->pcie_dev;

		
			printk("CXF_DEBUG_QUERY \n");

			list_for_each(listptr, &pcie_device->c2s_channels) {
				chan = list_entry(listptr, struct channel, list);
				if(chan->in_use && chan->state == active)
				{
					struct dma_descriptor *pdesc = chan->desc_ptr;
					uint64_t desc = (uint64_t)chan->desc_dma_handle;
					
					for(i=0;i<10;i++)
					{

						printk("ccons: desc[%d]: %.16lx  %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x\n\n\n",i,
							desc,
							pdesc->next_desc_address_low,
							pdesc->next_desc_address_high,
							pdesc->transfer_data_count,
							pdesc->status_control,
							pdesc->number_of_records,
							pdesc->records_list_address_low,
							pdesc->records_list_address_high,
							pdesc->res);				
						
						desc += sizeof(struct dma_descriptor);
						pdesc++;

					}				
				}
			}


			list_for_each(listptr, &pcie_device->s2c_channels) {
				chan = list_entry(listptr, struct channel, list);
				if(chan->in_use && chan->state == active)
				{
					struct dma_descriptor *pdesc = chan->desc_ptr;
					uint64_t desc = (uint64_t)chan->desc_dma_handle;
					
					for(i=0;i<10;i++)
					{

						printk("ccons: desc[%d]: phy addr:%.16lx  %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x\n\n\n",i,
							desc,
							pdesc->next_desc_address_low,
							pdesc->next_desc_address_high,
							pdesc->transfer_data_count,
							pdesc->status_control,
							pdesc->number_of_records,
							pdesc->records_list_address_low,
							pdesc->records_list_address_high,
							pdesc->res);				
						
						desc += sizeof(struct dma_descriptor);
						pdesc++;

					}				
				}	
			}			
			
			break;		
		}
		case CXF_DBG_MSG:
		{
			//int str_len;
			char* str[MAX_DBG_STR];
			ret = copy_from_user(str, (void*)arg, MAX_DBG_STR);

			printk("ccons: DBGSTR:  %s\n", (char*) str);
			break;
		}
		case CXF_QUERY_NUM_OF_BOARD:
			ret = copy_to_user((void *)arg, &probed, sizeof(probed));
			printk("ccons:CXF_QUERY_NUM_OF_BOARD (1) user_buffer %d\n",probed);
			rc = 0;
			break;
		case CXF_GET_CHANNLE_STATE: 
		{
			if (obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				
				uint32_t chan_id = 0;
				uint32_t chan_dir = 0;
				struct channel* chan;
				struct list_head* listptr;
				struct pcie_bar* bar = (struct pcie_bar*)dev->object;
				uint32_t num_of_channels;

				pcie_device = (struct pcie_device*)bar->pcie_dev;

				num_of_channels = pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels;
								
				if (chan_dir == 1)
				{
					list_for_each(listptr, &pcie_device->c2s_channels) {
						chan = list_entry(listptr, struct channel, list);
						if (chan->id == chan_id)
						{
							copy_channel_descriptors(chan);
							break;
						}
					}
				}
				else
				{

					list_for_each(listptr, &pcie_device->s2c_channels) {
						chan = list_entry(listptr, struct channel, list);
						if (chan->id == chan_id)
						{
							copy_channel_descriptors(chan);
							
							break;
						}

					}

					rc = 0;
				}
			}
		}
		break;

		case CXF_SYSTEM_RESET:
			if (obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				uint32_t w_2_reg;
				pcie_device = (struct pcie_device*)dev->object;
				w_2_reg = pcie_device->ctrl_shadow_reg | SYS_RESET;
				bar0 = pcie_device->bars_array[0].p_bar;
				write_reg(bar0, CTRL_STAT_ADD, w_2_reg);
				rc = 0;
			}
			break;
		case CXF_QUERY_NUM_OF_USR_INT:
			printk("ccons:CXF_QUERY_NUM_OF_USR_INT \n");
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				pcie_device = (struct pcie_device *)dev->object;
				num_of_channels = pcie_device->num_of_user_interrupts;
				ret = copy_to_user((void *)arg, &num_of_channels, sizeof(num_of_channels));
				printk("ccons:CXF_QUERY_NUM_OF_USR_INT (1) user_buffer %d\n",num_of_channels);
				rc = 0;
			}
		break;	
		case CXF_SET_USER_INTERRUPT:
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				struct usr_int_info uii;
				bool is_inuse;	
				uint32_t int_bit;
				rc = -1;
				pcie_device = (struct pcie_device *)dev->object;
				bar0 = pcie_device->bars_array[0].p_bar;
				ret = copy_from_user(&uii, (void*)arg, sizeof(struct usr_int_info));
				
				is_inuse = pcie_device->pui_array[uii.int_id].efd_ctx != NULL;
				printk("CXF_SET_USER_INTERRUPT %d %d %d INUSE:%s\n",uii.int_id,uii.usr_event,uii.pid, is_inuse ? "TRUE" : "FALSE");	
				if(uii.int_id <= pcie_device->num_of_user_interrupts-1 
						&& !pcie_device->pui_array[uii.int_id].efd_ctx)								
				{
					struct eventfd_ctx * efd_ctx = find_user_efd(uii.pid,uii.usr_event);
					if(efd_ctx)
					{
						pcie_device->pui_array[uii.int_id].efd = uii.usr_event; 
						pcie_device->pui_array[uii.int_id].pid = uii.pid;
						pcie_device->pui_array[uii.int_id].efd_ctx = efd_ctx; 		
						pcie_device->pui_array[uii.int_id].int_count = 0;

						if(pcie_device->is_base_ip_ver)
						{
							int_bit = uii.int_id+pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels;
							pcie_device->ctrl_shadow_reg |= INT_MASK_BIT(int_bit);
							write_reg(bar0, CTRL_STAT_ADD, pcie_device->ctrl_shadow_reg);
						}
						rc = 0;
						
						
					}
					else
					{
						rc = -2;
					}
				}
				printk("CXF_SET_USER_INTERRUPT rc=%d\n",rc);
			}
		break;
		case CXF_CLEAR_USER_INTERRUPT:
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				int ev_id;
				rc = -1;
								
				pcie_device = (struct pcie_device *)dev->object;
				ret = copy_from_user(&ev_id, (void*)arg, sizeof(int));
				
				printk("CXF_CLEAR_USER_INTERRUPT ev_id:%d num_of_usr_int:%d ctx:%p\n",ev_id, pcie_device->num_of_user_interrupts,pcie_device->pui_array[ev_id].efd_ctx);
				if(ev_id <= pcie_device->num_of_user_interrupts-1 
						&& pcie_device->pui_array[ev_id].efd_ctx)
				{
					struct eventfd_ctx * efd_ctx = pcie_device->pui_array[ev_id].efd_ctx;
					uint32_t int_bit = ev_id+pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels;
					
					if(pcie_device->is_base_ip_ver)
					{
						pcie_device->ctrl_shadow_reg &= ~INT_MASK_BIT(int_bit);
						write_reg(bar0, CTRL_STAT_ADD, pcie_device->ctrl_shadow_reg);
					}

					printk("CXF_CLEAR_USER_INTERRUPT ev_id:%d \n",ev_id);
					eventfd_signal(efd_ctx, 1);
					eventfd_ctx_put(efd_ctx);
					pcie_device->pui_array[ev_id].efd_ctx = NULL;
				}
				
				rc = 0;
			}		
		break;	
		break;
		
////////////////////////////////////// TM CODE START //////////////////////////////////////
			case CXF_GET_UI_TIME_TAG :
				{
					ui_time_tag_t time_tag;
					pcie_device = (struct pcie_device *)dev->object;

		                        ret = copy_from_user(&time_tag, (void*)arg, sizeof(time_tag));
#ifdef DEBUG_TM
                                        printk("ccons:got CXF_GET_UI_TIME_TAG \n");
					printk("ccons: ui= %d\n", time_tag.ui); 
					printk("ccons: pcie_device= 0x%X\n", pcie_device); 
					printk("ccons: pcie_device->uiTimeTag[time_tag.ui][0]= 0x%X\n", pcie_device->uiTimeTag[time_tag.ui][0]); 
					printk("ccons: pcie_device->uiTimeTag[time_tag.ui][1]= 0x%X\n", pcie_device->uiTimeTag[time_tag.ui][1]); 
					printk("ccons: pcie_device->uiTimeTag[time_tag.ui][2]= 0x%X\n", pcie_device->uiTimeTag[time_tag.ui][2]); 
					printk("ccons: pcie_device->uiTimeTag[time_tag.ui][3]= 0x%X\n", pcie_device->uiTimeTag[time_tag.ui][3]); 
#endif
					time_tag.sec = pcie_device->uiTimeTag[time_tag.ui][0];
					time_tag.usec = pcie_device->uiTimeTag[time_tag.ui][1];
					time_tag.mono_sec = pcie_device->uiTimeTag[time_tag.ui][2];
					time_tag.mono_usec = pcie_device->uiTimeTag[time_tag.ui][3];
					
					if (copy_to_user((ui_time_tag_t __user *)arg, &time_tag , sizeof(ui_time_tag_t) ) != 0)
					{
						printk("ccons: copy_to_user failed \n");
						return -1;
					}
					
				}
				break;
////////////////////////////////////// TM CODE END ////////////////////////////////////////

		case CXF_GET_NUM_OF_CHAN:
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				pcie_device = (struct pcie_device *)dev->object;
				num_of_channels = pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels;
				ret = copy_to_user((void *)arg, &num_of_channels, sizeof(num_of_channels));
				rc = 0;
			}
			break;

		case CXF_GET_DRIVER_VER:
			
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				pcie_device = (struct pcie_device *)dev->object;
				v = (ver_mg << 16) | ver_mn;
				ret = copy_to_user((void *)arg, &v,sizeof(uint32_t));
				rc = 0;
			}
			break;

		case CXF_GET_PCIE_CORE_VER:
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				pcie_device = (struct pcie_device *)dev->object;
				v = pcie_device->pcie_dma_core_ver;
				ret = copy_to_user((void *)arg, &v,sizeof(uint32_t));
				rc = 0;
			}
			break;

	   	case CXF_START:
	   		if(obj->object_identifier == DMA_C2S_OBJ_IDENTIFIER
	   				|| obj->object_identifier == DMA_S2C_OBJ_IDENTIFIER)
	   		{
	   			struct channel *channel;
	   			channel =(struct channel *)dev->object;
	   			printk("ccons:CXF_START called %p %d\n",channel, channel->id);
	   			rc = start_channel(channel);
	   		}
			break;
		case CXF_SET_MAX_READ_REQ:
			
	   		if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
	   			uint64_t val64;
	   			uint32_t max_rd_size;
	   			uint32_t chan_id;
	   			void *pbar0;
	   			int32_t reg_offset;
	   			
	   			printk("ccons: CXF_SET_MAX_READ_REQ called\n");
	   			
	   			pcie_device = (struct pcie_device *)dev->object;
	   			pbar0 = pcie_device->bars_array[0].p_bar;
	   			ret = copy_from_user(&val64, (void*)arg, sizeof(uint64_t));
	   			max_rd_size = (uint32_t)val64;
	   			chan_id = (uint32_t)(val64 >> 32);
	   			
	   			reg_offset = get_channel_offset(pcie_device,chan_id);
	   			
				write_reg(pbar0,reg_offset+CHAN_RD_MAX_LEN,max_rd_size);
				rc = 0;
			}
		break;
	   	case CXF_STOP:
	   		if(obj->object_identifier == DMA_C2S_OBJ_IDENTIFIER
	   				|| obj->object_identifier == DMA_S2C_OBJ_IDENTIFIER)
	   		{
	   			struct channel *channel;
	   			channel =(struct channel *)dev->object;
	   			printk("ccons:CXF_STOP called %p %d\n",channel, channel->id);
	   			rc = stop_channel(channel);
	   		}
			break;
	   	case CXF_LOCK_BUFFER:
	   	{
	   		struct buffer_descriptor buf_desc;

	   		if(obj->object_identifier != BAR_OBJ_IDENTIFIER)
	   		{
	   			chan = (struct channel *)dev->object;
	   			pcie_device = (struct pcie_device *)chan->pcie_dev;
	   		}
	   		else
	   		{
				struct pcie_bar* bar = (struct pcie_bar*)dev->object;
#ifdef DEBUG_IOCTL
	   			printk("ccons:CXF_LOCK_BUFFER BAR %p pcie_dev %p\n",bar, bar->pcie_dev);
#endif
				pcie_device = (struct pcie_device*)bar->pcie_dev;
			}

	   		ret = copy_from_user(&buf_desc, (void *)arg, sizeof(struct buffer_descriptor));

	   		//printk("ccons:CXF_LOCK_BUFFER user_buffer %p %d\n",buf_desc.user_buffer, buf_desc.buffer_size);

	   		rc = lock_user_buffer(pcie_device,&buf_desc);
	   		if(rc >= 0)
	   			ret = copy_to_user((void *)arg, &buf_desc,sizeof(struct buffer_descriptor));

			//printk("ccons:CXF_LOCK_BUFFER user_buffer %p %d rc=%d\n", buf_desc.user_buffer, buf_desc.buffer_size, rc);
	   	}
		break;
	   	case CXF_UNLOCK_BUFFER:
	   	{
	   		struct buffer_descriptor buf_desc;
   			//printk("ccons:CXF_UNLOCK_BUFFER \n");

	   		if(obj->object_identifier != BAR_OBJ_IDENTIFIER)
	   		{
	   			chan = (struct channel *)dev->object;
	   			pcie_device = (struct pcie_device *)chan->pcie_dev;
	   		}
	   		else
	   		{
				pcie_device = (struct pcie_device *)dev->object;
	   		}

	   		ret = copy_from_user(&buf_desc, (void *)arg, sizeof(struct buffer_descriptor));

			rc = unlock_user_buffer(pcie_device,&buf_desc);
	   	}
	   	break;
		case  CXF_QUERY_CHAN_INFO:
			if(obj->object_identifier == BAR_OBJ_IDENTIFIER)
			{
				pcie_device = (struct pcie_device *)dev->object;
				ret = copy_from_user(&dw_arg, (void *)arg, sizeof(dw_arg));
				channel_id = (uint16_t)(dw_arg >>16);

				
				if(channel_id < pcie_device->num_of_c2s_channels )
				{
					dir = 1;

					printk("ccons: CXF_QUERY_CHAN_INFO %d  %.8x %d\n",channel_id, dw_arg, dir);
					ret = copy_to_user((void *)arg, &dir, sizeof(uint32_t));

					rc = 0;
				}
				else if(channel_id < pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels)
				{
					
					dir = 0;

					printk("ccons: CXF_QUERY_CHAN_INFO %d  %.8x %d\n",channel_id, dw_arg, dir);
					ret = copy_to_user((void *)arg, &dir, sizeof(uint32_t));

					rc = 0;
				}
			}
			break;
			case CXF_REG_WR_REQUEST :
					

				//printk("ccons:got W/R Reg request\n");
				

				if(obj->object_identifier == BAR_OBJ_IDENTIFIER)	
		   		{
		   			struct pcie_bar *bar;
		   			struct wr_param wrp_r; 
		   			struct wr_param *wrp_r_back;
		   			bar =(struct pcie_bar *)dev->object;
			
					
					wrp_r_back =(struct wr_param *)arg;
					ret = copy_from_user(&wrp_r,(void *)arg,sizeof(struct wr_param));
					
					if (wrp_r.direction )
					{
						
						
						wrp_r.reg_val = read_reg(bar->p_bar, wrp_r.address);
						//printk("ccons:read reg bar=%d,addr=%x val=%d\n", bar->id, wrp_r.address, wrp_r.reg_val);
						ret = copy_to_user(wrp_r_back,(void *)&wrp_r,sizeof(struct wr_param));
						rc = 0;
					}
					else
					{
						printk("ccons: CXF_REG_WR_REQUEST write reg bar=%d,addr=%lx val=%lx\n",bar->id,wrp_r.address,wrp_r.value);	
						write_reg(bar->p_bar, wrp_r.address, wrp_r.value);
						rc=0;
					}
					
				}

			break;
		}

#ifdef DEBUG_IOCTL
	if (obj->object_identifier == BAR_OBJ_IDENTIFIER)
	{
			printk("************ ccons_ioctl <<<<<<<  cmd %d obj %p pcie_dev %p\n",cmd , obj, ((struct pcie_bar *)obj)->pcie_dev);
	}
#endif


	return rc;
}


ssize_t ccons_read_write_iter (struct kiocb *iocb, struct iov_iter *iov_iter)
{
	struct ccons_dev *dev = (struct ccons_dev *)iocb->ki_filp->private_data;
	struct channel *chan = (struct channel *)dev->object;
	int req_size = iov_iter->iov->iov_len;
	struct loocked_user_buffer *lub;
	void *arg = iov_iter->iov->iov_base;
	ssize_t rc = 0;
	uint32_t param0;
	uint32_t param1;
	uint32_t param2;
	uint32_t param3;
	unsigned long ret;


	struct buffer_descriptor buf_desc;


	//printk("ccons: ccons_read_write_iter >>\n");



	if (mutex_lock_killable(&chan->stop_mutex))
		return -EINTR;

	chan->started_count++;
	ret = copy_from_user(&buf_desc, arg, sizeof(struct buffer_descriptor));
	lub = buf_desc.drv_data;
	rc= start_io(chan,iocb,lub,req_size, param0, param1, param2, param3);

	mutex_unlock(&chan->stop_mutex);

	return rc;
}



void disable_interrupt(struct pcie_device *pcie_device)
{
	pcie_device->ctrl_shadow_reg &= ~GLOB_INT_ENA;
	HW_REG_WRITE(pcie_device->bars_array[0].p_bar, CTRL_STAT_ADD, SWAP32(pcie_device->ctrl_shadow_reg));
}

struct pcie_device *create_new_pcie_dev(struct pci_dev *dev)
{
	struct pcie_device *pcie_device = (struct pcie_device *)kzalloc(sizeof(struct pcie_device) , GFP_KERNEL);
	pcie_device->ctrl_shadow_reg = 0;
	pcie_device->linux_pci_dev = dev;

	return pcie_device;
}

unsigned int read_reg(void *base, unsigned int offset)
{
	
	unsigned long ul = HW_REG_READ(base, offset);
	return ul;
}

void write_reg(void *base, unsigned long long offset, unsigned int value)
{
	printk("ccons: write_reg base=%p offset=%llx value=%x \n", base,  offset, value);
	HW_REG_WRITE(base, offset, value);
}

void enable_interrupt(struct pcie_device *pcie_device)
{
	pcie_device->ctrl_shadow_reg |= GLOB_INT_ENA;
    	HW_REG_WRITE(pcie_device->bars_array[0].p_bar,CTRL_STAT_ADD, SWAP32(pcie_device->ctrl_shadow_reg));
}

void del_channel_resources(struct channel *channel)
{

	struct pci_dev *pdev = channel->pcie_dev->linux_pci_dev;
	if(channel->desc_ptr)
		pci_free_consistent(pdev, channel->desc_alloc_size, channel->desc_ptr,channel->desc_dma_handle);

	if(channel->pdesc_instance)
		kfree(channel->pdesc_instance);


}

int init_channel(struct channel *channel, struct pcie_device *pcie_device, bool dir, unsigned int id, uint32_t chan_regs_offset, int num_of_desc)
{
	int rc = 0;
	int desc_alloc_size = num_of_desc*sizeof(struct dma_descriptor);
	void *desc_ptr = NULL;
	dma_addr_t desc_dma_handle;
	struct pci_dev *pdev;
	struct dma_descriptor *pdesc;
	struct descriptor_instance *pdesc_inst;
	

	pdev = pcie_device->linux_pci_dev;
	channel->obj_ident.object_identifier = dir ? DMA_C2S_OBJ_IDENTIFIER : DMA_S2C_OBJ_IDENTIFIER;
	sprintf(channel->obj_ident.name,"%s%d",dir ? "C2S" : "S2C",id);
	mutex_init(&channel->stop_mutex);

	//printk("init_channel: channel = %p Init Object = %s \n",channel, channel->obj_ident.name);

	desc_ptr = pci_alloc_consistent(pdev,desc_alloc_size,&desc_dma_handle);
	if(desc_ptr)
	{
		int i;
		uint64_t next_desc;
		channel->id = id;
		channel->chan_regs_offset = chan_regs_offset;
		channel->pcie_dev = pcie_device;
		channel->dir = dir;
		channel->desc_alloc_size = desc_alloc_size;
		channel->desc_ptr = desc_ptr;
		channel->desc_dma_handle = desc_dma_handle;
		channel->state = inactive;
		channel->full = false;
		channel->completion_num = 0;

		channel->pdesc_instance = (struct descriptor_instance *)kmalloc(num_of_desc*sizeof(struct descriptor_instance),GFP_KERNEL);


		if(!channel->pdesc_instance)
		{
			printk("ccons: init_channel failed to alloc desc instance \n");
			pci_free_consistent(pdev, channel->desc_alloc_size, channel->desc_ptr,channel->desc_dma_handle);
			channel->desc_ptr = NULL;
			return -1;
		}


		channel->head = channel->tail = channel->pdesc_instance;

		pdesc = channel->desc_ptr;
		pdesc_inst = channel->pdesc_instance;

		next_desc = (uint64_t)channel->desc_dma_handle;
		for(i=0;i<num_of_desc;i++)
		{
			if(channel->dir == 0 && channel->id == 0)
				printk("%lx\n",next_desc);
			pdesc_inst->desc_phy_addr = next_desc; //set the phy address before incrementing to the next one
			next_desc = i == (num_of_desc-1) ? (uint64_t)channel->desc_dma_handle : (next_desc+sizeof(struct dma_descriptor));
			pdesc->next_desc_address_low = (uint32_t)next_desc | 2; // enable inteterrupt
			pdesc->res = 0;
			pdesc->next_desc_address_high = (uint32_t)(next_desc >> 32);
			pdesc->transfer_data_count = 0;
			pdesc->status_control = SG_REC_NOT_IN_USE;
			pdesc->records_list_address_low = 0;
			pdesc->records_list_address_high = 0;
			pdesc->number_of_records = 0;

			pdesc_inst->dec_id = i;

			pdesc_inst->pdmap_desc = pdesc;
			pdesc_inst->pnext = i == (num_of_desc-1) ? channel->pdesc_instance : (pdesc_inst+1);
			pdesc_inst++;
			pdesc++;

		}

		
		INIT_WORK(&channel->wq,  chan_do_tasklet);


		//printk("ccons: init_channel descriptor: ptr=%p size=%d  dma_handle=%llx\n",desc_ptr, desc_alloc_size, desc_dma_handle);
	}
	else
	{
		printk("ccons: init_channel descriptor pci_alloc_consistent failed\n");
		rc = -1;
	}

	return rc;
}
/*
udp.payload[6]==0x06	UpdateTimeManager
udp.payload[6]==0x1a	DpuStatus
udp.payload[6]==0x1b	RfStatus
udp.payload[6]==0x1e	TxDeviceConfig
udp.payload[6]==0x1f	TxDeviceData
udp.payload[6]==0x24	FwwfRxStream
*/

static ssize_t start_io(struct channel *chan, struct kiocb *iocb ,struct loocked_user_buffer *lub, int req_len, uint32_t param0, uint32_t param1, uint32_t param2, uint32_t param3)
{
	ssize_t rc;
	int i;

	//printk("ccons: start_io lub=%p req_len=%d\n",lub,req_len);

	if(!chan->full)
	{
		struct dma_descriptor *pdmap_desc = chan->tail->pdmap_desc;
		struct descriptor_instance *pdesc_inst = chan->tail;
		int records_in_transfer = 0;
		int accum_len=0;
		//struct scatterlist *sg;
		uint64_t status_addr;
		uint64_t first_record_address;
		struct dma_record *ra = lub->rec_array;
		uint32_t reg_len_32 = (uint32_t)req_len;
		
		#ifdef DINAMIC_USER_MAPPING
			rc = map_user_buffer(chan->pcie_dev,lub);
			if(rc < 0)
				return rc;
		#endif
		
		rc = -EIOCBQUEUED;

		reg_len_32 <<= 2;

		//iterate overe the records list, and find how many are needed for this transfer
		//for_each_sg(lub->user_sg.sgl,sg,lub->user_num_of_mapped_regions,i)
		for(i=0;i<lub->num_of_rec;i++)
		{

			//make sure the last bit is cleared form the last time
			ra->address_low &= ~0x00000001;
			//ra-> buffer_size =    sg_dma_len(sg) < (req_len-accum_len) ? sg_dma_len(sg) : (req_len-accum_len);
			//accum_len += sg_dma_len(sg);

			ra->buffer_size = (req_len - accum_len) > PAGE_SIZE  ? PAGE_SIZE : (req_len - accum_len);
			accum_len += ra->buffer_size;

			records_in_transfer++;
			if(accum_len >= req_len)
			{
				//set the last record bit
				ra->address_low |= 0x00000001;
				break;
			}
			ra++;

		}
		//if (accum_len != 65535) {
		if(chan->state == inactive) {
			struct timespec64 tv_timespec64;
			ktime_get_real_ts64(&tv_timespec64);
			//printk("%10d.%09d call count:%d start_io channel[%d] dir:%d num_of_rec:%d count+8:%d (inactive)\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec, chan->started_count, chan->id, chan->dir, lub->num_of_rec, accum_len+8);
		}
		else {
			struct timespec64 tv_timespec64;
			ktime_get_real_ts64(&tv_timespec64);
			//printk("%10d.%09d call count:%d start_io channel[%d] dir:%d num_of_rec:%d count+8:%d\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec, chan->started_count, chan->id, chan->dir, lub->num_of_rec, accum_len+8);
			if(chan->id == 0 && chan->dir == 0) 
			{
				
				struct bnet_header bh;
				int i;
					
				copy_from_user(&bh, (void*)lub->process_virtural_addr, sizeof(struct bnet_header));
				//if(bh.msg_id == 0x1E)
				//printk("seq_num = %d \n", bh.seq_num);
				pdesc_inst->msg_id = bh.msg_id;
				pdesc_inst->seq_num = bh.seq_num;

				
				
				
			}
		}

		//mark the firt record
		ra = lub->rec_array;
		ra->address_low |= 0x00000002;
		

		status_addr = 8+(uint64_t)chan->tail->desc_phy_addr;
		first_record_address = (uint64_t)lub->record_dma_handle;


		//printk("start io: chan[%d] tail=%p num_of_mapped_regions=%d accum len = %d req len = %d\n",
		//		chan->id,chan->tail,records_in_transfer, accum_len,req_len);

		
		pdmap_desc->number_of_records = sizeof(struct dma_record)*records_in_transfer;
		pdmap_desc->records_list_address_low = (uint32_t)first_record_address;
		pdmap_desc->records_list_address_high = (uint32_t)(first_record_address>>32);
		pdmap_desc->res = (uint32_t)(status_addr >> 32);
		pdmap_desc->transfer_data_count = (uint32_t)status_addr;
		pdmap_desc->param0 = param0;
		pdmap_desc->param1 = param1;
		pdmap_desc->param2 = param2;
		pdmap_desc->param3 = param3;
		
		// ================ must be last  =======================
		pdmap_desc->status_control  = reg_len_32 | SG_REC_ACTIVE;
		pdesc_inst->lub = lub;
		

		chan->tail->iocb = iocb;

		chan->tail = chan->tail->pnext;

		if(chan->tail == chan->head)
			chan->full = true;

#if 0
		printk("ccons: start io desc dup:  %x %x %x %x %x %x %x %x\n",
				pdmap_desc->next_desc_address_low,
				pdmap_desc->next_desc_address_high,
				pdmap_desc->transfer_data_count,
				pdmap_desc->status_control,
				pdmap_desc->number_of_records,
				pdmap_desc->records_list_address_low,
				pdmap_desc->records_list_address_high,
				pdmap_desc->res);
#endif

		/////////////////////////////////////////////////////////////////
		//printk("******************* start io  records dump *******************\n");
		//ra = lub->rec_array;
		//while(records_in_transfer--)
		//{
		//	printk("\t\t %x %x %x %x\n",
		//			ra->res,ra->address_low,ra->address_high,ra->buffer_size);
		//	ra++;
		//}
		///////////////////////////////////////////////////////////////


	}
	else {
		//
		struct timespec64 tv_timespec64;
		ktime_get_real_ts64(&tv_timespec64);
		printk("%10d.%09d call count:%d start_io channel[%d] dir:%d num_of_rec:%d count+8:%d (channel full)\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec, chan->started_count, chan->id, chan->dir, lub->num_of_rec, req_len+8);
		chan->started_count--;
	}

	return rc;
}


void set_channel_interrupt(struct pcie_device * pcie_device, uint32_t bit)
{
	
	//printk("ccons_pci: channels_init %d \n",bit);
	
	pcie_device->ctrl_shadow_reg  |= INT_MASK_BIT(bit);

	printk("ccons_pci: channels_init %d %08lx\n",bit, pcie_device->ctrl_shadow_reg);
}


uint32_t get_ip_date(void *bar0, bool is_base_ip_ver)
{
	uint32_t core_date;	
	if(!is_base_ip_ver)
	{
		core_date = read_reg(bar0, PCIE_CORE_DATE);
	}
	else
	{
		write_reg(bar0, SYS_DESC_INDEX_ADD, PCIE_CORE_DATE_BASE_VER);
		msleep(10);
		core_date = read_reg(bar0, SYS_DESC_DATA_ADD);
	}
	return core_date;
}

int get_num_of_user_int(void * bar0, bool is_base_ip_ver)
{
	uint32_t ui_num;	
	if(!is_base_ip_ver)
	{
		ui_num = read_reg(bar0, NUM_OF_USER_INT);
	}
	else
	{
		write_reg(bar0, SYS_DESC_INDEX_ADD, NUM_OF_USER_INT_BASE_VER);
		msleep(10);
		ui_num = read_reg(bar0, SYS_DESC_DATA_ADD);
	}
	return ui_num;
} 
	
int get_num_of_channels(void * bar0, bool is_base_ip_ver)
{
	uint32_t ch_num;	
	if(!is_base_ip_ver)
	{
		ch_num = read_reg(bar0, NUM_OF_CHANNELS);
	}
	else
	{
		write_reg(bar0, SYS_DESC_INDEX_ADD, NUM_OF_CHANNELS_BASE_VER);
		msleep(10);
		ch_num = read_reg(bar0, SYS_DESC_DATA_ADD);
	}
	return (int)ch_num;
} 
	
int get_num_of_c2s(void * bar0, bool is_base_ip_ver)
{
	uint32_t num_of_c2s=0;
	if(!is_base_ip_ver)
	{
		uint32_t ch;
		ch = read_reg(bar0, DMA_CHANNELS);
		num_of_c2s = (int)(ch & 0x0000ffff);
	}
	else
	{
		uint32_t chan_dir_bitmap;
		int num_of_ch;
		int i;
		
		write_reg(bar0, SYS_DESC_INDEX_ADD, NUM_OF_CHANNELS_BASE_VER);
		msleep(10);
		num_of_ch = (int)read_reg(bar0, SYS_DESC_DATA_ADD);
		msleep(10);
		write_reg(bar0, SYS_DESC_INDEX_ADD, CHANNELS_DIR_BASE_VER);
		msleep(10);
		chan_dir_bitmap = read_reg(bar0, SYS_DESC_DATA_ADD);

		for(i=0;i<num_of_ch;i++)
			if((chan_dir_bitmap >> i) & 1)
				num_of_c2s++;


	}
	return num_of_c2s;
} 	

int get_num_of_s2c(void *bar0, bool is_base_ip_ver)
{
	uint32_t num_of_s2c=0;
	if(!is_base_ip_ver)
	{
		uint32_t ch;
		ch = read_reg(bar0, DMA_CHANNELS);
		num_of_s2c = (int)(ch >> 16);
	}
	else
	{
		uint32_t chan_dir_bitmap;
		int num_of_ch;
		int i;
		write_reg(bar0, SYS_DESC_INDEX_ADD, NUM_OF_CHANNELS_BASE_VER);
		msleep(10);
		num_of_ch = (int)read_reg(bar0, SYS_DESC_DATA_ADD);
		msleep(10);
		write_reg(bar0, SYS_DESC_INDEX_ADD, CHANNELS_DIR_BASE_VER);
		msleep(10);
		chan_dir_bitmap = read_reg(bar0, SYS_DESC_DATA_ADD);

		for(i=0;i<num_of_ch;i++)
			if(!((chan_dir_bitmap >> i) & 1))
				num_of_s2c++;
		
	}
	return num_of_s2c;
} 	


int channels_init(struct pcie_device * pcie_device)
{

	int ret=0;
	
	//unsigned long chan_dir_bitmap;
	void *bar0;
	
	uint32_t pcie_ip_ver_mj,pcie_ip_ver_mn;
	int i;
	int num_of_chan = 0;
	int num_of_c2s = 0;
	int num_of_s2c = 0;
	uint32_t chan_int_bit = 0;

	INIT_LIST_HEAD(&pcie_device->c2s_channels);
	INIT_LIST_HEAD(&pcie_device->s2c_channels);


	pcie_device->num_of_c2s_channels = 0;
	pcie_device->num_of_s2c_channels = 0;

	bar0 = pcie_device->bars_array[0].p_bar;

	pcie_device->pcie_dma_core_ver =  read_reg(bar0, PCIE_CORE_VER);
	
	pcie_ip_ver_mj = pcie_device->pcie_dma_core_ver >> 16;
	pcie_ip_ver_mn = pcie_device->pcie_dma_core_ver & 0xfff;

	pcie_device->is_base_ip_ver = pcie_ip_ver_mj < 5 ? true : false;

	printk("ccons_pci: channels_init - Driver : %x.%X  FW Ver: %x.%x this is a %s pcie dma ip\n", ver_mg, ver_mn, pcie_ip_ver_mj,pcie_ip_ver_mn, pcie_device->is_base_ip_ver ? "base" : "new" );
	
	pcie_device->pcie_dma_core_date = get_ip_date(bar0, pcie_device->is_base_ip_ver);

	printk("ccons_pci: channels_init - calling get_num_of_user_int\n");

	msleep(10);
	pcie_device->num_of_user_interrupts = get_num_of_user_int(bar0, pcie_device->is_base_ip_ver);
	
	printk("ccons_pci: DevicInit - Num Of User Interrupts %d\n",pcie_device->num_of_user_interrupts);
	msleep(10);
	num_of_chan = (int)get_num_of_channels(bar0, NUM_OF_CHANNELS);
	
	printk("ccons_pci: DevicInit - Num Of Channels %08x\n",num_of_chan);
	msleep(10);
	num_of_s2c = get_num_of_s2c(bar0, pcie_device->is_base_ip_ver);
	num_of_c2s = get_num_of_c2s(bar0, pcie_device->is_base_ip_ver);

	printk("ccons_pci: DevicInit - Num of S2C: %d, Num of C2S %d \n",num_of_s2c,num_of_c2s);
	msleep(10);

	for(i=0;i<num_of_c2s && ret >= 0;i++)
	{
		struct channel *channel = (struct channel *)kmalloc(sizeof(struct channel), GFP_KERNEL);
		uint32_t chan_id  =(uint32_t)i;
		uint32_t chan_regs_offset;	
		chan_regs_offset = get_channel_offset(pcie_device,i);
		ret = init_channel(channel, pcie_device,true,chan_id,chan_regs_offset, NUM_OF_DESCRIPTORS);
		if(ret >= 0)			
			list_add(&channel->list, &pcie_device->c2s_channels);

		if(pcie_device->is_base_ip_ver)
			set_channel_interrupt(pcie_device, chan_int_bit);
		chan_int_bit++;
	}
	pcie_device->num_of_c2s_channels = num_of_c2s;


	for(i=0;i<num_of_s2c && ret >= 0;i++)
	{
		struct channel *channel = (struct channel *)kmalloc(sizeof(struct channel), GFP_KERNEL);
		uint32_t chan_id  = (uint32_t)i;
		uint32_t chan_regs_offset;	
		chan_regs_offset = get_channel_offset(pcie_device,i+num_of_c2s);
		ret = init_channel(channel, pcie_device,false,chan_id,chan_regs_offset, NUM_OF_DESCRIPTORS);
		if(ret >= 0)			
			list_add(&channel->list, &pcie_device->s2c_channels);

		if(pcie_device->is_base_ip_ver)
			set_channel_interrupt(pcie_device, chan_int_bit);
		chan_int_bit++;
	}
	pcie_device->num_of_s2c_channels = num_of_s2c;
	
	
	if(pcie_device->num_of_user_interrupts > 0)
	{
		struct pci_dev *pdev;
		int ui_alloc_size;
		uint32_t regs = get_channel_offset(pcie_device,(num_of_c2s+num_of_s2c));	
		pdev = pcie_device->linux_pci_dev;
		
		ui_alloc_size = sizeof(struct user_interrupt)*pcie_device->num_of_user_interrupts;
		pcie_device->pui_array = pci_alloc_consistent(pdev,ui_alloc_size,&pcie_device->ui_mem_alloc_handle);
		if(pcie_device->pui_array)
		{
			struct user_interrupt *pui = pcie_device->pui_array;
			uint64_t user_interrupt_phy = (uint64_t)pcie_device->ui_mem_alloc_handle;

#ifdef MSIX_SUPPORT			
				uint64_t status_qword_phy = user_interrupt_phy + sizeof(struct object);
#else
				uint64_t status_qword_phy = user_interrupt_phy;
#endif				
			
			for(i=0;i<pcie_device->num_of_user_interrupts;i++)
			{
				uint32_t phystat_low = (uint32_t)status_qword_phy;
				uint32_t phystat_high = (uint32_t)(status_qword_phy >> 32);
#ifdef MSIX_SUPPORT				
				pui->obj_ident.object_identifier = USER_INTERRUPT;
#endif				
				pui->int_count=0;
				pui->qstatus_word=0;
				pui->efd_ctx = NULL;
				pui->regs_offset = regs;
				INIT_WORK(&pui->wq,  ui_do_tasklet);
				
				printk("ccons_pci: DevicInit - pui->regs_offset[%d] %x %llx\n",i,pui->regs_offset, status_qword_phy);
								
				write_reg(bar0, pui->regs_offset, phystat_low);
				write_reg(bar0, pui->regs_offset+4, phystat_high);
				user_interrupt_phy += sizeof(struct user_interrupt);
				pui++;
				regs += 8;
				
				status_qword_phy += sizeof(struct user_interrupt);
				
				
			}
		}
	}
	else
	{
		pcie_device->pui_array = NULL;
	}

	printk("num_of_s2c = %d num_of_c2s = %d\n",pcie_device->num_of_s2c_channels,pcie_device->num_of_c2s_channels);

	return ret;
}

u8 get_revision(struct pci_dev *dev)
{
	u8 revision;

	pci_read_config_byte(dev, PCI_REVISION_ID, &revision);
	return (revision);
}

static irqreturn_t pci_isr(int irq, void *dev_id, struct pt_regs *regs)
{
	struct pci_dev *pci_dev = (struct pci_dev *)dev_id;
	struct pcie_device *pcie_device = (struct pcie_device *)dev_get_drvdata(&pci_dev->dev);

	if (pcie_device->ch_caller < 0)
	{
		pcie_device->ch_caller=0;
		wake_up_interruptible(&pcie_device->ch_wq);
	}

	return (IRQ_HANDLED);
}

int flush_desc_list(struct channel *channel)
{

    	
    while(channel->full || channel->head != channel->tail)
    {
    	printk("ccons: flush_desc_list calling ki_complete\n");
    	channel->head->iocb->ki_complete(channel->head->iocb, 0, DMA_STOPPED);
    	channel->head = channel->head->pnext;
    	channel->full = false;
    }


    channel->head = channel->tail = channel->pdesc_instance;
	return 0;
}

int start_channel(struct channel *channel)
{
	int ret = 0;

	printk("ccons:start channel called\n");
	if(channel->state == inactive)
	{
		void *pbar0 = channel->pcie_dev->bars_array[0].p_bar;
		uint32_t desc_low = (uint32_t)channel->desc_dma_handle;
		uint32_t desc_high = (uint32_t)(channel->desc_dma_handle >> 32);

/*
		printk("ccons: start_channel desc dup:  %x %x %x %x %x %x %x %x\n",
				channel->head->pdmap_desc->next_desc_address_low,
				channel->head->pdmap_desc->next_desc_address_high,
				channel->head->pdmap_desc->transfer_data_count,
				channel->head->pdmap_desc->status_control,
				channel->head->pdmap_desc->number_of_records,
				channel->head->pdmap_desc->records_list_address_low,
				channel->head->pdmap_desc->records_list_address_high,
				channel->head->pdmap_desc->res);
*/
		printk("ccons: start_channel first desc dump: %x %x\n", desc_high,desc_low);
		//write the descriptor low & high address
		write_reg(pbar0, channel->chan_regs_offset + DMA_REGISTER_ADD_LOW, desc_low);
		write_reg(pbar0, channel->chan_regs_offset + DMA_REGISTER_ADD_HIGH, desc_high);

		write_reg(pbar0,channel->chan_regs_offset+DMA_REGISTER_CMD_STAT,(uint32_t)(ACTIVE_BIT | START_BIT | SG_BIT));
		channel->state  = active;
		
		struct timespec64 tv_timespec64;
		ktime_get_real_ts64(&tv_timespec64);
		printk("%10d.%09d call count:%d start_channel channel[%d] dir:%d num_of_rec:%d count+8:%d (reseting counter)\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec, channel->started_count, channel->id, channel->dir);
		channel->started_count = 0;
	}

	return ret;
}


int stop_channel(struct channel *channel)
{
	unsigned long ret;
	printk("ccons:stopch called , active=%d,id=%d\n", channel->state == active, channel->id);

	ret = mutex_lock_killable(&channel->stop_mutex);

	if(channel->state == active)
	{
		channel->state = stopping;

		write_reg(channel->pcie_dev->bars_array[0].p_bar, channel->chan_regs_offset + DMA_REGISTER_CMD_STAT, (unsigned long)(STOP_BIT | SG_BIT));

		msleep(1);

		write_reg(channel->pcie_dev->bars_array[0].p_bar, channel->chan_regs_offset + DMA_REGISTER_CMD_STAT, (unsigned long)(RESET_BIT | SG_BIT));

		//return all pending buffers to the user


		channel->state = inactive;
	}

	printk("ccons:sch calling flush_desc_list \n");
	flush_desc_list(channel);

	mutex_unlock(&channel->stop_mutex);

	printk("ccons:stopch ret , active=%d\n", channel->state == active);

	return 0;
}

void open_channel(struct channel *channel)
{
	//printk("open channel entry,id=%d\n",channel->id);
	channel->comleted_count = 0;
	channel->started_count = 0;
	channel->in_use = true;
}

void close_channel(struct channel *channel)
{
	//printk("close channel entry,id=%d\n",channel->id);
	stop_channel(channel);
	channel->in_use = false;
	channel->full = false;
	channel->pending = 0;
	//printk("close channel ret\n");
}

void delete_channels(struct list_head *head)
{
	struct channel *channel;
	struct list_head *listptr;

    redo:
		list_for_each(listptr, head) {
			channel = list_entry(listptr, struct channel, list);
			list_del(&channel->list);
			del_channel_resources(channel);
			kfree(channel);
			goto redo;
		}
}

static void ccons_destroy_device(struct pcie_device *pcie_device, int devnode,struct ccons_dev *dev, int minor, struct class *class, device_type type)
{
	BUG_ON(dev == NULL || class == NULL);


	switch (type) {
		case bar:
			device_destroy(class, MKDEV(pcie_device->ccons_major, devnode)); //minor));
			break;
		case c2s:
			device_destroy(class, MKDEV(pcie_device->ccons_major, devnode)); //minor + 36));
			break;
		case s2c:
			device_destroy(class, MKDEV(pcie_device->ccons_major, devnode)); //minor + 32));
			break;
		default:
			break;
	}

	cdev_del(&dev->cdev);
	return;
}

static void ccons_cleanup_module(struct pcie_device *pcie_device)
{
	int i;
	struct channel *channel;
	struct list_head *listptr;
	void *ccons_device;
	int devnode = 0;

	printk(" ************* ccons_cleanup_module >>>>> \n");
	//msleep(1000);

	for (i = 0; i < MAX_NUM_OF_BARS; i++)
	{
		ccons_device = pcie_device->bars_array[i].ccons_device;
		if(ccons_device)
		{
			ccons_destroy_device(pcie_device,devnode++, ccons_device, i, ccons_class_bar, bar);
			kfree(ccons_device);
			pcie_device->bars_array[i].ccons_device = NULL;
		}
	}

	printk(" ************* ccons_cleanup_module 1\n");
	//msleep(1000);

	i = 0;
	list_for_each(listptr, &pcie_device->c2s_channels) {
		channel = list_entry(listptr, struct channel, list);
		ccons_device = channel->ccons_device;
		
		if(ccons_device)
		{
			//printk(" calling ccons_destroy_device on c2s[%d]\n",i);
			ccons_destroy_device(pcie_device,devnode++, ccons_device, i, ccons_class_c2s, c2s);
			kfree(ccons_device);
			channel->ccons_device = NULL;
			
		}
		i++;
	}
	



	i = 0;
	list_for_each(listptr, &pcie_device->s2c_channels) {
		channel = list_entry(listptr, struct channel, list);
		ccons_device = channel->ccons_device;
		if(ccons_device)
		{
			//printk(" calling ccons_destroy_device on s2c[%d]\n",i);
			ccons_destroy_device(pcie_device,devnode++, ccons_device, i, ccons_class_s2c, s2c);
			kfree(ccons_device);
			channel->ccons_device = NULL;
		}
		i++;
	}


	unregister_chrdev_region(MKDEV(pcie_device->ccons_major, 0), MAX_NUM_OF_BARS);
	unregister_chrdev_region(MKDEV(pcie_device->ccons_major, 0), pcie_device->num_of_c2s_channels);
	unregister_chrdev_region(MKDEV(pcie_device->ccons_major, 0), pcie_device->num_of_s2c_channels);


	kfree(pcie_device);


	return;
}

static int ccons_construct_device(struct pcie_device *pcie_device, int devnode_id ,struct ccons_dev *dev, int minor, struct class *class, device_type type)
{
	int err = 0;
	dev_t devno;
	struct device *device = NULL;
	

	BUG_ON(dev == NULL || class == NULL);

	dev->q_head = dev->q_tail = 0;
	atomic_set(&dev->q_cnt, 0);
	pcie_device->b_exit = false;

	mutex_init(&dev->ccons_mutex);
	cdev_init(&dev->cdev, &ccons_fops);
	dev->cdev.owner = THIS_MODULE;

	switch (type) {
		case bar:
			devno = MKDEV(pcie_device->ccons_major, devnode_id); //minor);
			err = cdev_add(&dev->cdev, devno, 1);
			if (err)
			{
				printk(KERN_WARNING "[target] Error %d while trying to add %s%d",
					err, CCONS_DEVICE_BAR_NAME, minor);
				return err;
			}
			

			device = device_create(class, NULL, devno, NULL, CCONS_DEVICE_BAR_NAME "%d.%d", ccons_major, minor);

			if (IS_ERR(device)) {
				err = PTR_ERR(device);
				printk(KERN_WARNING "[target] Error %d while trying to create %s%d",
									err, CCONS_DEVICE_BAR_NAME, minor);

				cdev_del(&dev->cdev);
				return err;
			}
			break;
		case c2s:
			devno = MKDEV(pcie_device->ccons_major, devnode_id); //minor + 36);
			err = cdev_add(&dev->cdev, devno, 1);
			if (err)
			{
				printk(KERN_WARNING "[target] Error %d while trying to add %s%d",
					err, CCONS_DEVICE_C2S_NAME, minor);
				return err;
			}
			

			device = device_create(class, NULL, devno, NULL, CCONS_DEVICE_C2S_NAME "%d.%d", ccons_major, minor);
			if (IS_ERR(device)) {
				err = PTR_ERR(device);
				printk(KERN_WARNING "[target] Error %d while trying to create %s%d",
									err, CCONS_DEVICE_C2S_NAME, minor);

				cdev_del(&dev->cdev);
				return err;
			}
			
			break;
		case s2c:

			

			devno = MKDEV(pcie_device->ccons_major, devnode_id); //minor + 32);
			err = cdev_add(&dev->cdev, devno, 1);
			if (err)
			{
				printk(KERN_WARNING "[target] Error %d while trying to add %s%d",
					err, CCONS_DEVICE_S2C_NAME, minor);
				
				return err;
			}

			
			device = device_create(class, NULL, devno, NULL, CCONS_DEVICE_S2C_NAME "%d.%d", ccons_major, minor);

			if (IS_ERR(device)) {
				err = PTR_ERR(device);
				printk(KERN_WARNING "[target] Error %d while trying to create %s%d",
									err, CCONS_DEVICE_S2C_NAME, minor);

				
				cdev_del(&dev->cdev);
				return err;
			}
		
			break;
		default:
			break;
	}

	return 0;
}

static void unlock_one_page(struct page *pp, bool b_dirty)
{
	if ( b_dirty & (!PageReserved(pp)))
   		SetPageDirty(pp);
	put_page(pp);
}

static void	unlock_pages(struct	page **p_user,int np, bool set_dirty)
{
	int	i;
	struct	page **pp = p_user;
	for ( i=0;i<np;i++,pp++)
		unlock_one_page(*pp,set_dirty);

}


static struct page **	lock_pages(char *buf,int num_pages,int *p_np, bool b_read)
{
	int	np=0;
	struct	page **pp;


	pp = (struct page **)kzalloc( num_pages * sizeof(struct page *), GFP_KERNEL);
	if ( pp==NULL )
	{
		printk("ccons:lock_pages enomem\n");
		return NULL;
	}
	
#if (LINUX_VERSION_CODE < KERNEL_VERSION(5, 8, 0))
 	down_read(&current->mm->mmap_sem);
#else
	mmap_read_lock(current->mm);
#endif	
	
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,9,0)
	np=get_user_pages(current,current->mm,(unsigned long)buf,num_pages,b_read,b_read,pp,NULL);
#else
	np=get_user_pages((unsigned long)buf,num_pages, b_read,pp,NULL);
#endif
#if (LINUX_VERSION_CODE < KERNEL_VERSION(5, 8, 0))
	up_read(&current->mm->mmap_sem);
#else
	mmap_read_unlock(current->mm);
#endif
	
	if ( !np )
	{
		printk("ccons:get_user_pages returned 0\n");
		kfree(pp);
		return NULL;
	}

	*p_np=np;
	return pp;
}

static void copy_descriptor(struct dma_descriptor* dest, struct dma_descriptor* src)
{
#if 0
	printk("ccons: desc:  %.8x %.8x %.8x %.8x %.8x %.8x %.8x %.8x\n",
		src->next_desc_address_low,
		src->next_desc_address_high,
		src->transfer_data_count,
		src->status_control,
		src->number_of_records,
		src->records_list_address_low,
		src->records_list_address_high,
		src->res);
#endif

}

static uint32_t get_channel_offset(struct pcie_device* pcie_device, int chan_id)
{
	uint32_t offset;

	if(!pcie_device->is_base_ip_ver)
		offset = ((2+chan_id)*BAR0_REGION_SIZE);
	else
		offset = (4*(FIRST_CHANNLE_REGS_OFFSET + chan_id*NUM_OF_CHAN_REGISTERS));

	return offset;
}
#ifdef MSIX_SUPPORT
static struct channel* find_channle(struct pcie_device* pcie_device, int chan_dir, int chan_id)
{
	struct list_head* listptr;
	struct channel* chan;
	if (chan_dir == 1)
	{
		list_for_each(listptr, &pcie_device->c2s_channels)
		{
			chan = list_entry(listptr, struct channel, list);
			if (chan->id == chan_id)
				return chan;
		}
	}
	else
	{

		list_for_each(listptr, &pcie_device->s2c_channels)
		{
			chan = list_entry(listptr, struct channel, list);
			if (chan->id == chan_id)
				return chan;
		}
	}
	return NULL;
}
#endif

static void copy_channel_descriptors(struct channel* chan)
{
	struct descriptor_instance* pdma_desc_inst = NULL;

	do
	{
		if(!pdma_desc_inst)
			pdma_desc_inst = chan->tail;
		else
			pdma_desc_inst = pdma_desc_inst->pnext;
		copy_descriptor(NULL, pdma_desc_inst->pdmap_desc);
	} while (pdma_desc_inst != chan->head);


}

static int unmap_user_buffer(struct pcie_device *pcie_device, struct  loocked_user_buffer *lub)
{
	int rc = 0;
		
	pci_unmap_sg(pcie_device->linux_pci_dev, lub->user_sg.sgl, lub->user_sg.nents,
						lub->dir ? DMA_FROM_DEVICE : DMA_TO_DEVICE);

	return rc;
}

static int map_user_buffer(struct pcie_device *pcie_dev, struct  loocked_user_buffer *lub)
{
	int num_of_mapped_regions=0;
	uint32_t rec_num = 0;
	struct scatterlist *sg;
	struct dma_record *next_ra;
	int i=0;
	int rc = 0;

	num_of_mapped_regions = pci_map_sg(pcie_dev->linux_pci_dev,lub->user_sg.sgl,
									lub->user_sg.nents, lub->dir ? DMA_FROM_DEVICE : DMA_TO_DEVICE);



	//must be grater then zero
	if(num_of_mapped_regions > 0)
	{
		next_ra = lub->rec_array;
		
		for_each_sg(lub->user_sg.sgl,sg,num_of_mapped_regions,i)
		{
			dma_addr_t dma_addr = sg_dma_address(sg);
			uint32_t seg_len = sg_dma_len(sg);


			while (seg_len)
			{
				next_ra->res = 0xabcd0000 | rec_num;
				next_ra->address_low = (uint32_t)dma_addr;
				next_ra->address_high = (uint32_t)(dma_addr >> 32);
				next_ra->buffer_size = seg_len > PAGE_SIZE ? PAGE_SIZE : seg_len;
				seg_len -= next_ra->buffer_size;
				dma_addr += next_ra->buffer_size;
				next_ra++;
			}
		}

		//printk("ccons: user buffers are mapped ulb = %p, # of mapped = %d, record phy addr=%llx \n",  lub, num_of_mapped_regions,lub->record_dma_handle);
		lub->user_num_of_mapped_regions = num_of_mapped_regions;

	}
	else
	{
		rc = DMA_MAP_SG_FAILED;
	}

	return rc;
}

static int unlock_user_buffer(struct pcie_device *pcie_dev, struct buffer_descriptor *buf_desc)
{
	int rc = 0;
	struct  loocked_user_buffer *lub = (struct  loocked_user_buffer *)buf_desc->drv_data;

	printk("ccons: unlock_user_buffer ****  \n");

	#ifndef DINAMIC_USER_MAPPING
		unmap_user_buffer(pcie_dev, lub);
	#endif
	
	
	sg_free_table(&lub->user_sg);


	unlock_pages(lub->user_pp,lub->user_num_of_locked_pages, false);


	kfree(lub->user_pp);

	if (lub->rec_array)
		dma_free_coherent(&pcie_dev->linux_pci_dev->dev,lub->record_array_size, lub->rec_array,lub->record_dma_handle);
	kfree(lub);

	return rc;
}



static int lock_user_buffer(struct pcie_device *pcie_device, struct buffer_descriptor *buf_desc)
{
	int rc = 0;
	//int i;
	int num_pages;
	int rem;
	int num_of_locked_pages=0;
	int record_array_size;
	struct	page **pp = NULL;
	struct dma_record *ra = NULL;
	struct  loocked_user_buffer *lub = NULL;


	//printk("ccons:lock_user_buffer >>>> buff=%p size=%d dir=%d \n",
	//		buf_desc->user_buffer, buf_desc->buffer_size, buf_desc->direction);


	lub = (struct loocked_user_buffer *)kzalloc( sizeof(struct loocked_user_buffer), GFP_KERNEL);


	if(buf_desc->buffer_size < PAGE_SIZE)
	{
		num_pages = 1;
	}
	else
	{
		num_pages=buf_desc->buffer_size/PAGE_SIZE;

		rem=buf_desc->buffer_size%PAGE_SIZE;
		if ( rem>0 )
			num_pages++;
	}


	pp = lock_pages((char *)buf_desc->user_buffer,num_pages,&num_of_locked_pages,buf_desc->direction);

	if(!pp)
	{
		rc = LOCK_BUFFER_FAILED;
		goto lock_user_buffer_error;

	}



	if(sg_alloc_table_from_pages(&lub->user_sg, pp,num_of_locked_pages,0,buf_desc->buffer_size, GFP_KERNEL)< 0)
	{
		rc = SG_ALLOC_FAILED;
		goto lock_user_buffer_error;
	}
	
	lub->record_dma_handle = 0;
	record_array_size = num_pages * sizeof(struct dma_record);


	ra = (struct dma_record *)dma_alloc_coherent(&pcie_device->linux_pci_dev->dev,
				record_array_size,	&lub->record_dma_handle, GFP_KERNEL);


	if(!ra)
	{
		rc = REC_ARRAY_ALLOC_FAILED;
		goto lock_user_buffer_error;
	}

	lub->user_pp = pp;
	lub->user_num_of_locked_pages = num_of_locked_pages;
	lub->num_of_rec = num_pages;
	lub->rec_array = ra;
	lub-> record_array_size = record_array_size;
	lub->user_tag = buf_desc->user_tag;
	lub->dir = buf_desc->direction;
#ifndef DINAMIC_USER_MAPPING
	if(map_user_buffer(pcie_device, lub) ==  DMA_MAP_SG_FAILED)
		goto lock_user_buffer_error;
#endif	
	buf_desc->drv_data = lub;
	
	lub->process_virtural_addr = buf_desc->user_buffer;

	return 0;

lock_user_buffer_error:


	if(pp)
	{
		unlock_pages(pp,num_of_locked_pages,false);
		kfree(pp);
	}

	if(ra)
		kfree(ra);


	if(lub)
		kfree(lub);


	printk("ccons:lock_user_buffer error %d\n",rc );
	return LOCK_BUFFER_FAILED;
}




int create_logical_devices(struct pcie_device *pcie_device)
{
	int inst = 0;
	struct ccons_dev *const_dev;
	dev_t dev = 0;
	int i;
	struct channel *channel;
	struct list_head *listptr;
	int err;
	int devnode_id = 0;



	/* Get a range of minor numbers (starting with 0) to work with */
	err = alloc_chrdev_region(&dev, 0, MAX_NUM_OF_BARS, CCONS_DEVICE_BAR_NAME);
	if (err < 0) {
		printk(KERN_WARNING "[target] alloc_chrdev_region() failed\n");
		return err;
	}

	err = alloc_chrdev_region(&dev, 0, pcie_device->num_of_c2s_channels, CCONS_DEVICE_C2S_NAME);
	if (err < 0) {
		printk(KERN_WARNING "[target] alloc_chrdev_region() failed\n");
		return err;
	}

	err = alloc_chrdev_region(&dev, 0, pcie_device->num_of_s2c_channels, CCONS_DEVICE_S2C_NAME);
	if (err < 0) {
		printk(KERN_WARNING "[target] alloc_chrdev_region() failed\n");
		return err;
	}

	pcie_device->ccons_major = MAJOR(dev);



	//loop over all bars and for the ones that are mapped, create a logical device
	for (i = 0; i < MAX_NUM_OF_BARS; i++)
	{
		if(pcie_device->bars_array[i].mapped)
		{
			void *ccons_device = kzalloc(sizeof(struct ccons_dev), GFP_KERNEL);

			if (ccons_device == NULL) {
				err = -ENOMEM;
				goto fail;
			}

			pcie_device->bars_array[i].ccons_device = ccons_device;

			const_dev = (struct ccons_dev *)ccons_device;
			const_dev->ifn = i;
			const_dev->inst = inst;
			const_dev->object = &pcie_device->bars_array[i];

				

			err = ccons_construct_device(pcie_device, devnode_id++,const_dev, i, ccons_class_bar, bar);

			if (err)
				goto fail;
		}
	}

	/////////

	//i = 0;
	list_for_each(listptr, &pcie_device->c2s_channels) {
		channel = list_entry(listptr, struct channel, list);
		channel->ccons_device = (struct ccons_dev *)kzalloc(sizeof(struct ccons_dev), GFP_KERNEL);
		if (channel->ccons_device == NULL) {
			err = -ENOMEM;
			goto fail;
		}

		const_dev = (struct ccons_dev *)channel->ccons_device;
		const_dev->ifn = channel->id;
		const_dev->inst = inst;
		const_dev->object = channel;


		

		err = ccons_construct_device(pcie_device, devnode_id++,const_dev, channel->id, ccons_class_c2s, c2s);
		if (err)
			goto fail;
		//i++;
	}

	//i = 0;
	list_for_each(listptr, &pcie_device->s2c_channels) {
		channel = list_entry(listptr, struct channel, list);
		channel->ccons_device = (struct ccons_dev *)kzalloc(sizeof(struct ccons_dev), GFP_KERNEL);
		if (channel->ccons_device == NULL) {
			err = -ENOMEM;
			goto fail;
		}

		const_dev = (struct ccons_dev *)channel->ccons_device;
		const_dev->ifn = channel->id;
		const_dev->inst = inst;
		const_dev->object = channel;

		

		err = ccons_construct_device(pcie_device, devnode_id++,const_dev, channel->id, ccons_class_s2c, s2c);
		if (err)
		{
				
			goto fail;
		}
		//i++;
	}

	return 0;

fail:
	
	

	ccons_cleanup_module(pcie_device);
	return err;
}




void handle_channel_completion(struct channel *chan)
{
	unsigned long ret;
	bool inc_comp_num = false;
	ret = mutex_lock_killable(&chan->stop_mutex);

	static int num_of_calls=0;
	//printk("handle_channel_completion >> num_of_calls =%d \n",num_of_calls++);	


	if(chan->state != active)
	{
		//printk("handle_channel_completion 1 : chan[%d]\n", chan->id);
		mutex_unlock(&chan->stop_mutex);
	    return;
	}

	
	//printk("handle_channel_completion: chan[%d] head: %p status control: %x\n",
	//			chan->id, chan->head, chan->head->pdmap_desc->status_control);
				
	//printk("handle_channel_completion 2: chan[%d]\n", chan->id);
	
	
	if((chan->head->pdmap_desc->status_control & SG_REC_DONE))
		inc_comp_num = true;
	
		
	while((chan->head->pdmap_desc->status_control & SG_REC_DONE) == SG_REC_DONE)
	{
		//int	i;
		//struct	page **pp;
		//int np;
		struct descriptor_instance *pdma_comleted = chan->head;
		struct  loocked_user_buffer *lub;
		chan->head = chan->head->pnext;
		chan->full = false;
		chan->comleted_count++;
		
		struct timespec64 tv_timespec64;
		ktime_get_real_ts64(&tv_timespec64);
		//printk("%10d.%09d call count:%d handle_channel_completion channel[%d] dir:%d count+8:%d\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec, chan->comleted_count, chan->id, chan->dir, pdma_comleted->pdmap_desc->transfer_data_count+8);
		
		//if(chan->dir == 0)
		//	printk("handle_channel_completion: chan[%d] (%p) status control: %x comp_count=%d (%p)\n",
		//		chan->id, chan,pdma_comleted->pdmap_desc->status_control,chan->comleted_count,pdma_comleted);
		//printk("handle_channel_completion: chan[%d] calling ki_complete started=%lld  completed=%lld h=%p t=%p\n",
		//		chan->id,chan->started_count,chan->comleted_count,chan->head,chan->tail);

		lub = pdma_comleted->lub;

	#ifdef DINAMIC_USER_MAPPING		
		unmap_user_buffer(chan->pcie_dev, lub);
	#endif	
	
		//if(chan->id == 0 && chan->dir == 0) 
		//{
		//	printk("handle_channel_completion: chan[%d] msg_id:%d seq_num:%d completion_num=%.8x \n",
		//	chan->id,pdma_comleted->msg_id,pdma_comleted->seq_num,(pdma_comleted->pdmap_desc->status_control)>>20);	
		//}
		
		pdma_comleted->pdmap_desc->status_control = SG_REC_NOT_IN_USE;
		pdma_comleted->iocb->ki_complete(pdma_comleted->iocb, pdma_comleted->pdmap_desc->transfer_data_count, DMA_DONE); //chan->comleted_count);

	}

	if(inc_comp_num)
		chan->completion_num++;

	mutex_unlock(&chan->stop_mutex);
}


void interrupt_handler(struct pcie_device *pcie_dev)
{
	struct channel * chan;
	struct list_head *listptr;
	struct user_interrupt *pui;
	int i;
	int int_cnt = 0;
////////////////////////////////////// TM CODE START //////////////////////////////////////
	struct timespec64 tv_time;
	struct timespec64 mono_time;
////////////////////////////////////// TM CODE END ////////////////////////////////////////
	
//	printk("interrupt_handler >>>\n");

	list_for_each(listptr, &pcie_dev->c2s_channels) {

		chan = list_entry(listptr, struct channel, list);

		
		//printk("interrupt_handler c2s channel[%d] in use:%d\n", chan->id, chan->in_use );

		if(chan->in_use)
			handle_channel_completion(chan);

	}


	list_for_each(listptr, &pcie_dev->s2c_channels) {
		chan = list_entry(listptr, struct channel, list);
		
		//printk("interrupt_handler s2c channel[%d] in use:%d\n", chan->id, chan->in_use );

		if(chan->in_use)
			handle_channel_completion(chan);
	}
	
	pui = pcie_dev->pui_array;
	for(i=0;i<pcie_dev->num_of_user_interrupts;i++)
	{
#ifdef DEBUG_INTERRUPT
		printk("ccons: interrupt_handler[%d] qstatus_word=%llx int_count=%x regs_offset=%d ef=%x pid=%d\n", i, 
			pui->qstatus_word, 
			pui->int_count, 
			pui->regs_offset, 
			pui->efd,
			pui->pid);
#endif
		int_cnt = 0;
		while((pui->qstatus_word & 0xff) != pui->int_count)
		{
#ifdef DEBUG_INTERRUPT
			printk("pui->qstatus_word: %llx pui->int_count:%x\n", pui->qstatus_word & 0xff, pui->int_count);
#endif
			pui->int_count++;
			if (pui->int_count > 0xFF)
				pui->int_count = 0;
			int_cnt++;
		}

		if(int_cnt > 0)
		{
			pui->int_count = pui->qstatus_word;
			
			if(pui->efd_ctx)
			{
////////////////////////////////////// TM CODE START ////////////////////////////////////////
				struct timespec64 tv_timespec64;
				ktime_get_real_ts64(&tv_timespec64);
							tv_time.tv_sec = tv_timespec64.tv_sec;
							tv_time.tv_nsec = tv_timespec64.tv_nsec; // hazerovich!!!
				ktime_get_raw_ts64(&mono_time);
				pcie_dev->uiTimeTag[i][0] = tv_time.tv_sec;
				pcie_dev->uiTimeTag[i][1] = tv_time.tv_nsec / 1000;
				pcie_dev->uiTimeTag[i][2] = mono_time.tv_sec;
				pcie_dev->uiTimeTag[i][3] = mono_time.tv_nsec/1000;
#ifdef DEBUG_TM
//				printk("ccons:got USER_INTERRUPT time_usec: %lld mono_time_usec: %ld\n", tv_time.tv_sec, tv_time.tv_nsec/1000); 
				printk("ccons:got USER_MESG_INDECATION ktime_get_real_ts64 tv_sec: %d tv_nsec: %d\n", tv_timespec64.tv_sec, tv_timespec64.tv_nsec);
				printk("ccons:got USER_MESG_INDECATION ktime_get_raw_ts64 tv_sec: %d tv_nsec: %d\n", mono_time.tv_sec, mono_time.tv_nsec);

#endif
////////////////////////////////////// TM CODE END ////////////////////////////////////////
#ifdef DEBUG_TM
				printk("calling  eventfd_signal %p\n", pui->efd_ctx);
#endif
				eventfd_signal(pui->efd_ctx, 1);
			}
			
			
		}
		pui++;
	}


}

static void ui_do_tasklet(struct work_struct* wk)
{
	struct user_interrupt* pui = GET_CONTAINER(wk, struct user_interrupt, wq);

	if(pui->efd_ctx)
	{
		//printk("calling  eventfd_signal %p\n", pui->efd_ctx);
		eventfd_signal(pui->efd_ctx, 1);
	}
}

static void chan_do_tasklet(struct work_struct* wk)
{
	struct channel* chann = GET_CONTAINER(wk, struct channel, wq);
	
	handle_channel_completion(chann);

	//printk("ccons_pci: chan_do_tasklet\n");
}

int	isr_callback_thr(void *arg)
{
	struct pcie_device *pcie_device = (struct pcie_device *)arg;
	printk("cconspci-int thr started %p\n", pcie_device);

	while (true)
	{
		bool b_exit;
		wait_event_interruptible(pcie_device->ch_wq, pcie_device->ch_caller!=-1);
		pcie_device->ch_caller=-1;
		b_exit = pcie_device->b_exit;
		if ( b_exit )
		{
			printk("cconspci-int thr done %p\n",pcie_device);
			pcie_device->b_exit = false;
			break;
		}

		if(!b_exit)
			interrupt_handler(pcie_device);
	}

	printk("cconspci-int thr ended %p\n", pcie_device);
	return 0;
}

static irqreturn_t pci_msi_isr(int irq, void *dev_id, struct pt_regs *regs)
{

	struct pci_dev *pci_dev = (struct pci_dev *)dev_id;
	struct pcie_device *pcie_device = (struct pcie_device *)dev_get_drvdata(&pci_dev->dev);

	//printk("pci_msi_isr\n");
	
	if (pcie_device->ch_caller < 0)
	{
		pcie_device->ch_caller=1;
		wake_up_interruptible(&pcie_device->ch_wq);
	}

	return (IRQ_HANDLED);
}

#ifdef MSIX_SUPPORT
static irqreturn_t pci_msix_isr(int irq, void* context, struct pt_regs* regs)
{

	struct object* obj = (struct object*)context;

	printk("!!!!!!!! pci_msix_isr\n");

	if (obj->object_identifier == DMA_C2S_OBJ_IDENTIFIER || obj->object_identifier == DMA_S2C_OBJ_IDENTIFIER)
	{
		struct channel* channel = (struct channel*)obj;
		schedule_work(&channel->wq);
	}
	else if(obj->object_identifier == USER_INTERRUPT)
	{
		struct user_interrupt* ui = (struct user_interrupt*)obj;
		schedule_work(&ui->wq);
	}

	return (IRQ_HANDLED);
}
#endif



static int device_init(struct pci_dev *pci_dev, const struct pci_device_id *id)
{
	int  i_result;
	int  rc,rc0;
	int  num_of_msi = pci_msi_vec_count(pci_dev);
	int i;
	struct pcie_device *pcie_device;
	int nun_of_msix_interrupts_requierd;
	unsigned long ret;

	printk("ccons_pci: device_init  %x %x\n", pci_dev->vendor, pci_dev->device);

	pcie_device = create_new_pcie_dev(pci_dev);

	rc = dma_set_mask_and_coherent(&pci_dev->dev, 0xffffffffffffffff);

	printk("dma_set_mask_and_coherent ret = %d\n", rc);

	if(!pcie_device)
		return -EIO;


	i_result = get_revision(pci_dev);
	printk("ccons_pci: org dev->irq %d.\n", pci_dev->irq);
	printk("ccons_pci: power state %d\n", pci_dev->current_state);
	rc = pci_set_power_state(pci_dev, PCI_D0);

	printk("ccons_pci: set_power ret=%d,enamsi calling.\n",rc);

	
	pcie_device->num_of_msix = pci_msix_vec_count(pci_dev);


	for (i = 0; i < MAX_NUM_OF_BARS; i++)
	{
		void* membase = NULL;
		unsigned long long memstart, memlen;

		//init the array element to all nulls
		pcie_device->bars_array[i].mapped = false;

		memstart = pci_resource_start(pci_dev, i);
		memlen = pci_resource_len(pci_dev, i);
		
		printk("pci_resource_start: %d=%lld,pci_resource_len=%llu\n", i, memstart, memlen);
		
		if (memlen)
		{
			if (NULL == request_mem_region(memstart, memlen, pci_dev->dev.kobj.name))
			{
				printk("I/O address conflict for device \"%s\", memstart0=%llu=0x%x, memlen0=%llu=0x%x\n",
					pci_dev->dev.kobj.name, memstart, (unsigned int)memstart, memlen, (unsigned int)memlen);
			}
			else
			{
				membase = ioremap(memstart, memlen);

				pcie_device->bars_array[i].obj_ident.object_identifier = BAR_OBJ_IDENTIFIER;
				sprintf(pcie_device->bars_array[i].obj_ident.name, "BAR%d", i);
				pcie_device->bars_array[i].id = i;
				pcie_device->bars_array[i].mapped = true;
				pcie_device->bars_array[i].p_bar = membase;
				pcie_device->bars_array[i].memlen = memlen;
				pcie_device->bars_array[i].memstart = memstart;
				pcie_device->bars_array[i].pcie_dev = pcie_device;
				
				printk("ccons_pci: mb%d=%p,l=%llu BAR %p pcie_dev %p\n", i, membase, memlen, &pcie_device->bars_array[i], pcie_device->bars_array[i].pcie_dev);
			}
		}
	}

	msleep(10);
	ret = pci_enable_device(pci_dev);
	msleep(10);





	rc = channels_init(pcie_device);
	if (rc < 0)
		goto cleanup_ports;



	nun_of_msix_interrupts_requierd = pcie_device->num_of_user_interrupts+pcie_device->num_of_c2s_channels+pcie_device->num_of_s2c_channels;

	if (pcie_device->num_of_msix < nun_of_msix_interrupts_requierd)
		LOG("num_of_msix supported by the device is less then the requierd nun of interrupts");
	else
		pcie_device->num_of_msix = nun_of_msix_interrupts_requierd;

	
	printk("ccons_pci: num of msix interrupt that will be used: %d \n", pcie_device->num_of_msix);

#ifdef MSIX_SUPPORT
	if (pcie_device->num_of_msix > 0)
	{

		pcie_device->msix_entry = (struct msix_entry*)kmalloc(sizeof(struct msix_entry) * pcie_device->num_of_msix,  GFP_KERNEL);
		memset(&pcie_device->msix_entry[0], 0x00, sizeof(struct msix_entry) * pcie_device->num_of_msix);
		for (i = 0; i < pcie_device->num_of_msix; i++)
			pcie_device->msix_entry[i].entry = i;

		printk("ccons_pci: calling pci_alloc_irq_vectors maxvect=%d \n", pcie_device->num_of_msix);
		pcie_device->num_of_msix = pci_alloc_irq_vectors(pci_dev, 1, pcie_device->num_of_msix, PCI_IRQ_MSIX);
		if (pcie_device->num_of_msix < 1)
		{
			printk("ccons_pci: aborting , pci_alloc_irq_vectors returned count %d \n", pcie_device->num_of_msix);
			return -EIO;
		}
				
		for (i = 0; i < pcie_device->num_of_msix; i++)
		{
			pcie_device->msix_entry[i].vector = pci_irq_vector(pci_dev, i);

		}


		for (i = 0; i < pcie_device->num_of_msix; i++)
		{
			void* context;
			//pcie_device->msix_entry[i].vector = pci_irq_vector(pci_dev, i);
			printk("ccons_pci: calling request_irq\n");

			if (i < pcie_device->num_of_c2s_channels)
				context = find_channle(pcie_device, 1, i);
			else if (i < pcie_device->num_of_c2s_channels + pcie_device->num_of_s2c_channels)
				context = find_channle(pcie_device, 0, i- pcie_device->num_of_c2s_channels);
			else
				context = &pcie_device->pui_array[i-(pcie_device->num_of_c2s_channels+pcie_device->num_of_s2c_channels)];

			if (request_irq(pcie_device->msix_entry[i].vector, (irq_handler_t)pci_msix_isr, IRQF_SHARED, pci_dev->dev.kobj.name, context))
			{
				printk("ccons_pci: msix IRQ %d not free\n", pcie_device->msix_entry[i].vector);
				pci_free_irq_vectors(pci_dev);
				pcie_device->num_of_msix = 0;
				return -EIO;
			}
			printk("ccons_pci: MSIX Vector[%d] allocated\n", pcie_device->msix_entry[i].vector);

		}

		pcie_device->ctrl_shadow_reg |= MSIX_ENA;

	}
	else
	{
#endif
		init_waitqueue_head(&pcie_device->ch_wq);
		init_waitqueue_head(&pcie_device->ui_wq);
		pcie_device->ch_caller = -1;
		pcie_device->ui_caller = -1;

		rc = pci_enable_msi(pci_dev);
		printk("ccons_pci: enamsi returned %d num of msi: %d.\n", rc, num_of_msi);


		if (rc < 0)
		{
			printk("ccons_pci: using legacy int %x\n", rc);
			rc0 = request_irq(pci_dev->irq, (irq_handler_t)pci_isr, IRQF_SHARED, pci_dev->dev.kobj.name, pci_dev);
			if ((pci_dev->irq) && rc0)
			{
				printk("ccons_pci: legacy IRQ %d not free.\n", pci_dev->irq);
				return -EIO;
			}

		}
		else
		{
			printk("ccons_pci: using msi %d\n", pci_dev->irq);
			rc0 = request_irq(pci_dev->irq, (irq_handler_t)pci_msi_isr, IRQF_SHARED, pci_dev->dev.kobj.name, pci_dev);
			if (rc0)
			{
				printk("ccons_pci: msi IRQ %d not free\n", pci_dev->irq);
				return -EIO;
			}
		}

		pcie_device->base_irq = pci_dev->irq;
		if (pci_dev->irq)
			printk("ccons_pci: IRQ %d.,rc0=%d\n", pci_dev->irq, rc0);
		else
			printk("ccons_pci: No irq required/requested.\n");

		kthread_run(isr_callback_thr, pcie_device, "cconspci_int_ch_thread");
#ifdef MSIX_SUPPORT
	}
#endif

	msleep(10);
	pci_set_master(pci_dev);
	msleep(10);

	pcie_device->ctrl_shadow_reg |= SYS_ENA;

	printk("c2s: %d s2c: %d\n", pcie_device->num_of_c2s_channels, pcie_device->num_of_s2c_channels);
	msleep(1000);



	pcie_device->ccons_major = ccons_major;
	create_logical_devices(pcie_device);
	ccons_major++;

	

	enable_interrupt(pcie_device);

	dev_set_drvdata(&pci_dev->dev, pcie_device);

	
	probed++;
	printk("ccons_pci: probe ret ok \n");

	write_reg(pcie_device->bars_array[0].p_bar, CTRL_STAT_ADD, pcie_device->ctrl_shadow_reg);

	return 0;

cleanup_ports:
	printk("ccons_pci: probe error\n");
	for(i = 0; i < MAX_NUM_OF_BARS; i++)
	{
		if (pcie_device->bars_array[i].memlen)
		release_mem_region( pcie_device->bars_array[i].memstart, pcie_device->bars_array[i].memlen);
	}

	kfree(pcie_device);
	return (-EIO);
}

static void device_deinit(struct pci_dev* pci_dev)
{
	int i;
	int	z;

	struct pcie_device* pcie_device;


	pcie_device = (struct pcie_device*)dev_get_drvdata(&pci_dev->dev);



	disable_interrupt(pcie_device);

	for (i = 0; i < MAX_NUM_OF_BARS; i++)
	{
		if (pcie_device->bars_array[i].mapped)
		{
			iounmap(pcie_device->bars_array[i].p_bar);                                                // device driver part
			pcie_device->bars_array[i].mapped = false;
			pcie_device->bars_array[i].p_bar = NULL;
			release_mem_region(pcie_device->bars_array[i].memstart, pcie_device->bars_array[i].memlen);
		}
	}

#ifdef MSIX_SUPPORT
	if (pcie_device->num_of_msix > 0)
	{
		for (i = 0; i < pcie_device->num_of_msix; i++)
		{
			void* context;
			printk("ccons_pci: dis msix irq %d \n", pcie_device->msix_entry[i].vector);

			if (i < pcie_device->num_of_c2s_channels)
				context = find_channle(pcie_device, 1, i);
			else if (i < pcie_device->num_of_c2s_channels + pcie_device->num_of_c2s_channels)
				context = find_channle(pcie_device, 0, i - pcie_device->num_of_c2s_channels);
			else
				context = pci_dev; //TODO: create an objet for user interrupt


			free_irq(pcie_device->msix_entry[i].vector, context); // pci_dev);
		}
		pci_disable_msix(pci_dev);

		pci_free_irq_vectors(pci_dev);
		pcie_device->num_of_msix = 0;
	}
	else
	{
#endif
		if (pci_dev->irq)
		{
			printk("ccons_pci: deinit free irq\n");
			free_irq(pci_dev->irq, pci_dev);
			printk("ccons_pci: disable msi\n");
			pci_disable_msi(pci_dev);

			pcie_device->b_exit = true;
			pcie_device->ch_caller = 2;
			pcie_device->ui_caller = 2;
			
			
			wake_up_interruptible(&pcie_device->ch_wq);
			wake_up_interruptible(&pcie_device->ui_wq);
			z = 0;
			
			while (pcie_device->b_exit && z < 100)
			{
				
				msleep(10);
				z++;

			}
			printk("after the loop , z=%d\n", z);

			
		}
#ifdef MSIX_SUPPORT
	}
#endif


	ccons_cleanup_module(pcie_device);
	delete_channels(&pcie_device->c2s_channels);
	delete_channels(&pcie_device->s2c_channels);

	probed--;
	return;
}

/*static char *ccons_class_devnode(struct device *dev, umode_t *mode)
{
	printk("ccons:ccons_class_devnode mode = %p\n", mode);
	if (mode)                  
		*mode = 0666;
	return NULL;	
}*/

static int __init ccons_init_module(void)
{
	int err = 0;
	int	old;
	printk("ccons:loading ver %x.%x\n", ver_mg, ver_mn);
  	old = probed;

	/* Create device class (before allocation of the array of devices) */
	ccons_class_bar = class_create(THIS_MODULE, CCONS_DEVICE_BAR_NAME);
	if (IS_ERR(ccons_class_bar)) {
		err = PTR_ERR(ccons_class_bar);
		goto fail;
	}
	
	//ccons_class_bar->devnode = ccons_class_devnode;

	ccons_class_c2s = class_create(THIS_MODULE, CCONS_DEVICE_C2S_NAME);
	if (IS_ERR(ccons_class_c2s)) {
		err = PTR_ERR(ccons_class_c2s);
		goto fail;
	}
	
	//ccons_class_c2s->devnode = ccons_class_devnode;

	ccons_class_s2c = class_create(THIS_MODULE, CCONS_DEVICE_S2C_NAME);
	if (IS_ERR(ccons_class_s2c)) {
		err = PTR_ERR(ccons_class_s2c);
		goto fail;
	}
	
	//ccons_class_s2c->devnode = ccons_class_devnode;

	no_devs = 0;
	printk("ccons_pci:device before , old=%d,probed-%d,err=%d\n",old,probed,err);

	err = pci_register_driver(&ccons_pci_data);
	if(err != 0)
	{
		return -E9991;
	}

	return 0;//success

fail:
	printk("ccons_pci:device failed , old=%d,probed-%d,err=%d\n",old,probed,err);

	if (ccons_class_bar)
	{
		class_destroy(ccons_class_bar);
		ccons_class_bar = NULL;
	}

	if (ccons_class_c2s)
	{
		class_destroy(ccons_class_c2s);
		ccons_class_c2s = NULL;
	}

	if (ccons_class_s2c)
	{
		class_destroy(ccons_class_s2c);
		ccons_class_s2c = NULL;
	}

	return err;
}

static void __exit
ccons_exit_module(void)
{
	
	
	pci_unregister_driver(&ccons_pci_data);

	


	if (ccons_class_bar)
	{
		class_destroy(ccons_class_bar);
		ccons_class_bar = NULL;
	}

	


	if (ccons_class_c2s)
	{
		class_destroy(ccons_class_c2s);
		ccons_class_c2s = NULL;
	}

	


	if (ccons_class_s2c)
	{
		class_destroy(ccons_class_s2c);
		ccons_class_s2c = NULL;
	}

	


	return;
}

module_init(ccons_init_module);
module_exit(ccons_exit_module);



