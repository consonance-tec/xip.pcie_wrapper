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
#include "con_pcie_dma_drv_io.h"
#include "pcie_hal.h"

int interrupt_cnt[32];


void InterruptCallback(unsigned int unIndex, unsigned int unBoardId)
{
	interrupt_cnt[unIndex]++;
}


bool do_run = true;
void ctrlc_handler(sig_t s)
{
	do_run = false;
}

int	main(int argc,char *argv[])
{
	
	int i;
	
	signal(SIGINT, (__sighandler_t)ctrlc_handler);
	
		
	
		
	if (PciHalInit())
	{
		uint32_t val;
		
		int num_of_user_int;	
		SBoardInfo sBoardInfo;
		GetBoardInfo(0, &sBoardInfo);
		
		num_of_user_int = sBoardInfo.m_unNumOfUserInterrupts;	
		
		printf("num of user interrupts is: %d\n",num_of_user_int);
		
		for(i=0;i<num_of_user_int;i++)
		{
			EErrCode rc = RegisterInterruptHandler(i, InterruptCallback, 0);
			printf("RegisterInterruptHandler int[%d] rc = %d\n", i, rc);
			
		}
		
		for(i=1;i<num_of_user_int;i++)
		{
			val =  250*1000000;
			DoDirectWrite(2, (i*0x10000)+(2<<2), 1 , (unsigned long*)&val , 0 );
			val =  1;
			DoDirectWrite(2, (i*0x10000)+(1<<2), 1 , (unsigned long*)&val , 0 );		
		}
		
		while(do_run)
		{
			sleep(1);
			for(i=0;i<num_of_user_int;i++)
				printf("interrupt_cnt[%d] = %d \t", i, interrupt_cnt[i]);
			printf("\n");
		}
		
		val =  0;
		for(i=0;i<num_of_user_int;i++)
			DoDirectWrite(2, (i*0x10000)+(1<<2), 1 , (unsigned long*)&val , 0 );		
		
		sleep(1);
		for(i=0;i<num_of_user_int;i++)
			UnRegisterInterruptHandler(i,0);		
		
		
		PciHalCleanup();
	}

	return 0;


}



