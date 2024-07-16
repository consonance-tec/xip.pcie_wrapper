//#define _GNU_SOURCE
#include <stdio.h>	/* for printf */
#include <stdint.h>	/* for uint64 definition */
#include <stdlib.h>	/* for exit() definition */

#include <time.h>	/* for clock_gettime */
#include <pthread.h>	/* for clock_gettime */
#include <sys/eventfd.h>
#include <sys/types.h>
#include <stdbool.h>

#include <sys/ioctl.h>
#include <unistd.h>

#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <libaio.h>
#include <errno.h>
#include <termios.h>
#include <sched.h>
#include "con_pcie_dma_drv_io.h"
#include "con_pcie_dma.h"

#define	PAGE_SIZE	4096
#define	NONE	0
#define	Q_VAL	0xffff


unsigned long X3FFFFFFF = 0x3FFFFFFF;

//static void * aio_thread(void *arg);
static int get_dma_fd(int mj, int ifn, bool is_read);
static int get_bar_fd(int mj, int ifn);

//========================================================================================================================

int pcieio_open_dma_channel(int device_id, int chan_id,int 								max_num_of_pending_buffers ,bool is_read,
							struct dma_channel_descriptor *dma_chan_desc)
{
	int fd = -1;
	int rc = 0;

	fd = get_dma_fd(device_id, chan_id, is_read);

	if (fd >= 0)
	{
		dma_chan_desc->fd = fd;
		dma_chan_desc->is_read = is_read;
		dma_chan_desc->id = chan_id;
		dma_chan_desc->next = NULL;

		memset(&dma_chan_desc->ctx, 0, sizeof(io_context_t));
		rc = io_queue_init(max_num_of_pending_buffers, &dma_chan_desc->ctx);
		if (rc >= 0)
		{
			dma_chan_desc->efd = eventfd(0, 0);
			if (dma_chan_desc->efd < 0)
			{
				rc = -1;
				io_destroy(dma_chan_desc->ctx);
				close(dma_chan_desc->fd);
				free(dma_chan_desc);
			}
		}
	}

	return rc;
}

int pcieio_open_bar(int device_id, int bar)
{
	return get_bar_fd(device_id, bar);
}

int pcieio_close_bar(int fd)
{
	return close(fd);
}

int pcieio_close_dma_channel(struct dma_channel_descriptor *dma_chan)
{
	
	pcieio_stop_channel(dma_chan);
	io_destroy(dma_chan->ctx);
	close(dma_chan->fd);
	
	return 0;
}


int pcieio_write_bar_register(int fd, uint32_t reg_addr, uint32_t value)
{
	struct wr_param wrp_w;

	wrp_w.direction = false;
	wrp_w.address = reg_addr;
	wrp_w.value = value;

	return ioctl(fd, CXF_REG_WR_REQUEST, &wrp_w);
}

int pcieio_read_register(int fd, uint32_t reg_add, uint32_t *value)
{
	int ret = -1;

	struct wr_param wrp_w;

	wrp_w.direction = true;
	wrp_w.address = reg_add;
	wrp_w.value = 0;

	ret = ioctl(fd, CXF_REG_WR_REQUEST, &wrp_w);

	*value = wrp_w.reg_val;
	return ret;
}

struct buffer_descriptor *pcieio_pin_buffer(int dev_id,void *buff, int size, bool direction, uint64_t tag)
{
	struct buffer_descriptor *buff_desc = NULL;

	int fd = pcieio_open_bar(dev_id, 0);

	if (fd >= 0)
	{
		buff_desc = (struct buffer_descriptor *)malloc(sizeof(struct buffer_descriptor));

		if (buff_desc)
		{
			buff_desc->user_buffer = buff;
			buff_desc->buffer_size = size;
			buff_desc->direction = direction;
			buff_desc->user_tag = tag;
			buff_desc->pnext = NULL;


			if (ioctl(fd, CXF_LOCK_BUFFER, buff_desc) < 0)
			{
				free(buff_desc);
				buff_desc = NULL;
			}

		}

		pcieio_close_bar(fd);
	}
	return buff_desc;
}

int pcieio_release_buffer(int dev_id,struct buffer_descriptor *pbd)
{
	int ret = -1;

	int fd = pcieio_open_bar(dev_id, 0);

	if (fd >= 0)
	{
		ret = ioctl(fd, CXF_UNLOCK_BUFFER, pbd);
		if (ret >=  0)
			free(pbd);

		pcieio_close_bar(fd);
	}

	return ret;
}

int pcieio_start_channel(struct dma_channel_descriptor *dma_chan)
{
	int ret = -1;

	ret = ioctl(dma_chan->fd, CXF_START, NULL);

	return ret;
}

int pcieio_stop_channel(struct dma_channel_descriptor *dma_chan)
{
	int ret = -1;

	ret = ioctl(dma_chan->fd, CXF_STOP, NULL);

	return ret;
}

int pcieio_submit_io_request(struct dma_channel_descriptor *dma_chan, struct buffer_descriptor *pbd, int  size)
{
	int ret = -1;

	memset(&pbd->iocb[0], 0, sizeof(struct iocb));

	if (pbd->direction)
		io_prep_pread(&pbd->iocb[0], dma_chan->fd, pbd, size, 0);
	else
		io_prep_pwrite(&pbd->iocb[0], dma_chan->fd, pbd, size, 0);

	io_set_eventfd(&pbd->iocb[0], dma_chan->efd);

	pbd->pcb = pbd->iocb;
	ret = io_submit(dma_chan->ctx, 1, (struct iocb **) &pbd->pcb);



	return ret;
}

struct buffer_descriptor *pcieio_wait_for_io_completion(struct dma_channel_descriptor *dma_chan, uint64_t *count, uint64_t *res)
{
	struct buffer_descriptor *buff_desc = NULL;
	struct io_event evt;
	int rc;



	rc = io_getevents(dma_chan->ctx, 1, 1, &evt, NULL);


	if(rc < 0)
		return NULL;

	buff_desc = (struct buffer_descriptor *)evt.obj;
	*count = evt.res;
	*res = evt.res2;

	return buff_desc;
}



int pcieio_get_num_of_dma_channels(int device)
{
	int ret = -1;

	int fd = get_bar_fd(device, 0);

	if (fd)
	{
		uint32_t num_of_chan;
		if(ioctl(fd, CXF_GET_NUM_OF_CHAN, &num_of_chan) >= 0)
			ret = (int)num_of_chan;
		close(fd);
	}	return ret;
}

int pcieio_get_channel_direction(int device, int index, int *dir)
{
	int ret = -1;
	uint32_t direction;
	int fd = get_bar_fd(device, 0);

	if (fd)
	{
		direction = ((uint32_t)index) << 16;
		if((ret = ioctl(fd, CXF_QUERY_CHAN_INFO, &direction)) >= 0)
			*dir = (bool)direction;
		close(fd);
	}

	return ret;
}

int pcieio_get_driver_version(uint32_t *ver)
{
	int ret = -1;

	int fd = get_bar_fd(0, 0);

	if (fd)
	{
		ret = ioctl(fd, CXF_GET_DRIVER_VER, ver);
		close(fd);
	}

	return ret;
}

int pcieio_get_fpga_version(int device, uint32_t *ver)
{
	int ret = -1;

	int fd = get_bar_fd(0, 0);

	if (fd)
	{
		ret = ioctl(fd, CXF_GET_PCIE_CORE_VER, ver);
		close(fd);
	}

	return ret;
}


int pcieio_get_num_of_user_interrupts(int device)
{
	int ret = -1;
	uint32_t num_of_ui;
	int fd = get_bar_fd(0, 0);

	if (fd)
	{
		ret = ioctl(fd, CXF_QUERY_NUM_OF_USR_INT, &num_of_ui);
		close(fd);
	}

	return ret >= 0 ? (int)num_of_ui : -1;

}

int pcieio_register_interrupt_event(int device, int int_id)
{
	int ret = -1;
	int fd = get_bar_fd(0, 0);
	int event = eventfd(0, 0);

	if (fd)
	{
		struct usr_int_info uii = {int_id, event,getpid()};
		ret = ioctl(fd, CXF_SET_USER_INTERRUPT, &uii);
		close(fd);
		if(ret >= 0)
			return event;
	}

	return ret;
}

int pcieio_release_interrupt_event(int device, int int_id)
{
	int ret = -1;
	int fd = get_bar_fd(0, 0);

	if (fd)
	{
		ret = ioctl(fd, CXF_CLEAR_USER_INTERRUPT, int_id);
		close(fd);
	}

	return ret;
}


/*=======================================================================================*/
static int get_dma_fd(int mj, int ifn, bool is_read)
{
	int rc = 0;
	char s[128];
	mode_t perms = S_IRWXU;


	
	if(is_read)
		sprintf(s, "/dev/ccons_pcie_c2s%d.%d", mj, ifn);
	else
		sprintf(s, "/dev/ccons_pcie_s2c%d.%d", mj, ifn);

	
	rc = open(s, O_RDWR | O_CREAT | O_NDELAY/*|O_DIRECT*/, perms);

	

	return rc;
}

static int get_bar_fd(int mj, int ifn)
{
	int ret;
	char s[128];
	mode_t perms = S_IRWXU;
	sprintf(s, "/dev/ccons_pcie_bar%d.%d", mj, ifn);

	ret =  open(s, O_RDWR | O_CREAT | O_NDELAY/*|O_DIRECT*/, perms);

	return ret;

}







