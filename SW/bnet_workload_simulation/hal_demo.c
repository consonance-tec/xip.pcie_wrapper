#define _GNU_SOURCE
#include <stdio.h>	/* for printf */
#include <stdint.h>	/* for uint64 definition */
#include <stdlib.h>	/* for exit() definition */
#include <stdbool.h>
#include <unistd.h>
#include <time.h>	/* for clock_gettime */
#include <pthread.h>	/* for clock_gettime */
#include <sys/eventfd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <libaio.h>
#include <errno.h>
#include <termios.h>

#include <sched.h>
#include "pcie_hal.h"

#define PAGE_SIZE 4096
#define CONSONANCE_FPGA_TEST_FW

#define KBYTE_PER_TRANSFER_IN		128
#define KBYTE_PER_TRANSFER_OUT	1
#define MAX_DATA_BUFFER_SIZE_IN	(KBYTE_PER_TRANSFER_IN*1024)
#define MAX_DATA_BUFFER_SIZE_OUT	(KBYTE_PER_TRANSFER_OUT*1024)

#define NUM_OF_IOBUFFERS		10 




typedef struct _IOBUFF
{
	PVOID Buff;
	int	hEvent;
	PVOID *pCb;//paiocb
	int	i;
}IOBUFF,*PIOBUFF;


bool do_run = true;

int data_in_channel_id = 0;
int data_out_channel_id = 2;

SDmaBuffer aDmaDataOutBuffer[NUM_OF_IOBUFFERS];
io_context_t data_out_ctx;
IOBUFF data_out_ioBuff[NUM_OF_IOBUFFERS];
int data_out_completion_count = 0;
int read_io_count = 0;
int read_back_errors = 0;


//callback
void DmaCallbackFunc(EErrCode eErr, unsigned int unByteCount, SDmaBuffer* psDmaBuffer, EDmaChannel eDma, unsigned int unBoardId)
{
	uint64_t u = unByteCount;
	int efd = psDmaBuffer->efd;
	
	if(eErr != eFinishedSuccessfully)
	{
		u=0x3FFFFFFF;
		u++;
	}
	
	write(efd, &u, sizeof(u));
}


void* rx_io_thrad_func(void* arg)
{
	int aDmaBuffIndex = 0;
	int	rc;
	int i;
	uint32_t seq_num = 0;
	SDmaBuffer aDmaBuffer[NUM_OF_IOBUFFERS];
	IOBUFF ioBuff[NUM_OF_IOBUFFERS];
	int pending = 0;
	EErrCode err_code;
	uint32_t next_val = 0;
	int good_pckt_cnt=0;
	
	rc = OpenDmaChannel(DmaCallbackFunc, (EDmaChannel)data_in_channel_id, 0);

	rc = StartDma((EDmaChannel)data_in_channel_id, 0);
		
	for (i = 0; i < NUM_OF_IOBUFFERS; i++)
	{
		int	efd;
		void* p;

		efd = eventfd(0, 0);


		ioBuff[i].pCb = NULL;
		ioBuff[i].hEvent = efd;
		ioBuff[i].Buff = NULL;

		rc = posix_memalign(&p, PAGE_SIZE, MAX_DATA_BUFFER_SIZE_IN);

		memset(p,0x77,MAX_DATA_BUFFER_SIZE_IN);
		ioBuff[i].Buff = p;

		aDmaBuffer[i].m_Size = MAX_DATA_BUFFER_SIZE_IN;
		aDmaBuffer[i].m_bRead = eDirRead;
		aDmaBuffer[i].m_pData = p;
		aDmaBuffer[i].efd = efd;
		aDmaBuffer[i].m_ApplicationData = NULL;
		err_code = LockSGDmaBuffer(&aDmaBuffer[i]);

		if (err_code != eFinishedSuccessfully)
			printf("LockSGBmaBuffer returend %d\n", err_code);

		err_code = DoSGDma(&aDmaBuffer[i], MAX_DATA_BUFFER_SIZE_IN, (EDmaChannel)data_in_channel_id, 0);
		if (err_code == eFinishedSuccessfully)
			pending++;
		else
			printf("DoSGDma returend %d\n", err_code);



	}

	aDmaBuffIndex = 0;
	read_io_count = 0;

	i = 0;
	while (pending > 0)
	{
		uint64_t u;
		
		
		rc = read(aDmaBuffer[aDmaBuffIndex].efd, &u, sizeof(u));

		pending--;
		if (rc < 0)
			continue;

		if (u > 0x3FFFFFFF)
			break;
		else if (do_run)
		{
			
			int cnt = (int)u/4;
			uint32_t* p32 = (uint32_t*)ioBuff[aDmaBuffIndex].Buff;			
			int pos=0;
			read_io_count++;
			while (cnt--)
			{
				if (next_val != *p32)
				{
					static int ii = 0;
					if (ii++ == 0)
					{
						printf("error!! buff_ptr=%p prt=%p count=%d next:%x index:%d  got:%x good=%d\n",
												ioBuff[aDmaBuffIndex].Buff,p32,(int)u, next_val, pos,*p32, good_pckt_cnt);
						if(pos < 15)
						{	
							printf("0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n",
							p32[0],p32[1],p32[2],p32[3],p32[4],p32[5],p32[6],p32[7],
							p32[8],p32[9],p32[10],p32[11],p32[012],p32[13],p32[14],p32[15]);
						}
						else
						{
							printf("0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n",
							p32[pos-15],p32[pos-14],p32[pos-13],p32[pos-12],p32[pos-11],p32[pos-10],p32[pos-9],
							p32[pos-8],p32[pos-7],p32[pos-6],p32[pos-5],p32[pos-4],p32[pos-3],p32[pos-2],p32[pos-1],*p32);
							
							printf("0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x ,0x%.8x \n",
							p32[1],p32[2],p32[3],p32[4],p32[5],p32[6],p32[7],
							p32[8],p32[9],p32[10],p32[11],p32[012],p32[13],p32[14],p32[15]);

						}
						

					}
					read_back_errors++;
					break;
				}
				next_val = *p32+1;
				p32++;
				pos++;
			}
			
			if(read_back_errors == 0)
				good_pckt_cnt++;
			
			rc = DoSGDma(&aDmaBuffer[aDmaBuffIndex], MAX_DATA_BUFFER_SIZE_IN, (EDmaChannel)data_in_channel_id, 0) == eFinishedSuccessfully;
			pending++;
		}
		if (++aDmaBuffIndex == NUM_OF_IOBUFFERS)
		{
			next_val = 0;
			aDmaBuffIndex = 0;
		}
	}


do_exit:
	usleep(10000);//wait

	printf("calling close\n");
	rc = CloseDmaChannel((EDmaChannel)data_in_channel_id, 0);




do_exit_2:
	for (i = 0; i < NUM_OF_IOBUFFERS; i++)
	{
		char* buf;
		UnLockSGDmaBuffer(&aDmaBuffer[i]);

		buf = ioBuff[i].Buff;
		if (buf)
		{
			ioBuff[i].Buff = NULL;
			free(buf);
		}
		if (ioBuff[i].pCb)
			free(ioBuff[i].pCb);

		close(ioBuff[i].hEvent);
	}




	return NULL;
}


void *data_completion_thread_func(void *arg)
{
	SChannelInfo chinf;
	int	rc;
	int i;
	unsigned int packet_size;
	EErrCode err_code;
		
	rc= StartDma((EDmaChannel)data_out_channel_id, 0);

	i=0;
	while (true)
	{
		uint64_t u;
		
		rc = read(aDmaDataOutBuffer[i].efd, &u, sizeof(u));
				
		if (rc<0)
		{
			printf("data_completion_thread_func read rc = %d\n",rc);
			continue;
			
		}
		
		if (u>0x3FFFFFFF)
		{
			printf("data_completion_thread_func u = %lx\n",u);
			break;
		}	
		else if (do_run)
			data_out_completion_count++;

		if (++i == NUM_OF_IOBUFFERS)
			i = 0;
		
		
	}
}



int clean_out_data_channel()
{
	int rc=CloseDmaChannel((EDmaChannel)data_out_channel_id, 0);
	int i;
	for (i = 0; i<NUM_OF_IOBUFFERS; i++)
	{
		char	*buf;
		UnLockSGDmaBuffer(&aDmaDataOutBuffer[i]);

		buf = data_out_ioBuff[i].Buff;
		if (buf)
		{
			data_out_ioBuff[i].Buff = NULL;
			free(buf);
		}
		if (data_out_ioBuff[i].pCb)
			free(data_out_ioBuff[i].pCb);
		
		close(data_out_ioBuff[i].hEvent);
	}
	
	return 0;
}

int init_data_out_channel(int packet_size)
{
	
	int i;
	uint32_t next_val = 0;
	SetMaxReadReq((EDmaChannel)data_out_channel_id, 0, 4096);
	int rc = OpenDmaChannel(DmaCallbackFunc, (EDmaChannel)data_out_channel_id, 0);
	
	if(rc < 0)
	{
		printf("data_completion_thread_func OpenDmaChannel faild cr=%d\n",rc);
		return rc;	
	}
	
	memset(&data_out_ctx, 0, sizeof(data_out_ctx));
	rc = io_queue_init(NUM_OF_IOBUFFERS, &data_out_ctx);
	
	if(rc < 0)
	{
		printf("data_completion_thread_func io_queue_init faild cr=%d\n",rc);
		rc=CloseDmaChannel((EDmaChannel)data_out_channel_id, 0);
		return rc;	
	}
	

	for (i = 0; i<NUM_OF_IOBUFFERS; i++)
	{
		int	efd;
		void *p;
		int j;
		int32_t *p32;


		efd = eventfd(0, 0);


		data_out_ioBuff[i].pCb = NULL;
		data_out_ioBuff[i].hEvent = efd;
		data_out_ioBuff[i].Buff = NULL;
		
		rc = posix_memalign(&p, PAGE_SIZE, packet_size);

		memset(p,0x55,packet_size);

		data_out_ioBuff[i].Buff = p;

		aDmaDataOutBuffer[i].m_Size = packet_size;
		aDmaDataOutBuffer[i].m_bRead = eDirWrite;
		aDmaDataOutBuffer[i].m_pData = p;
		aDmaDataOutBuffer[i].efd = efd;
		aDmaDataOutBuffer[i].m_ApplicationData = NULL;
		LockSGDmaBuffer(&aDmaDataOutBuffer[i]);
			
		
		p32 = (int32_t *)p;
		for(j=0;j<packet_size/sizeof(int32_t);j++)
			*p32++ = next_val++;
				
		
	}
	return rc;
}

void* mon_thrad_func(void* arg)
{
	while (do_run)
	{
		sleep(2);
		printf("DMA IO Count = Tx:%d Rx:%d Data Check errors:%d\n", data_out_completion_count, read_io_count, read_back_errors);

	}
	return NULL;
}

void ctrlc_handler(sig_t s)
{
	do_run = false;
}

int	main(int argc,char *argv[])
{
	
	int rc;
	void *pv;
	pthread_t  tx_io_thread;
	pthread_t  rx_io_thread;
	pthread_t  mon_thread;
	int i=0;
	
	signal(SIGINT, (__sighandler_t)ctrlc_handler);
		
	printf("DMA Channle Argument: %d\n",data_out_channel_id);
		
	if (PciHalInit())
	{
		pthread_create(&mon_thread, NULL, mon_thrad_func, NULL);
		pthread_create(&rx_io_thread, NULL, rx_io_thrad_func, NULL);

		sleep(1);

		rc = init_data_out_channel(MAX_DATA_BUFFER_SIZE_OUT);
		
		rc = pthread_create(&tx_io_thread, NULL, data_completion_thread_func, NULL);
		
		while(do_run)
		{
			usleep(1000);
			
			DoSGDma(&aDmaDataOutBuffer[i], MAX_DATA_BUFFER_SIZE_OUT, (EDmaChannel)data_out_channel_id, 0);
			if(++i == NUM_OF_IOBUFFERS)
				i = 0;
		}	
		
		AbortDma((EDmaChannel)data_out_channel_id, 0);
		rc=pthread_join(tx_io_thread,&pv);
		clean_out_data_channel();
		AbortDma((EDmaChannel)data_in_channel_id, 0);
		rc = pthread_join(rx_io_thread, &pv);
		rc = pthread_join(mon_thread, &pv);
			
		
		PciHalCleanup();
	}

	return 0;


}



