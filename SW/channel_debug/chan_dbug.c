/*
 * atp.c
 *
 *  Created on: Mar 31, 2020
 *      Author: ido
 */

#define CURSUS
#define _GNU_SOURCE
#include <stdio.h>	/* for printf */
#include <stdint.h>	/* for uint64 definition */
#include <stdlib.h>	/* for exit() definition */
#include <string.h>
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




#define BAR0_REGION_SIZE 256

#define CHANNEL_OFFSET(x) ((2+x)*BAR0_REGION_SIZE)



int	main(int argc,char *argv[])
{

	int num_of_channels;
	int num_of_c2s_channels;
	int num_of_s2c_channels;
	int chan_id;
	int dir;
	int i;
	uint32_t chan_base_addr;
	int fd;

	uint32_t ch_state = 0xdeadbeef;	
	uint32_t statu_int_state = 0xdeadbeef;	


	num_of_channels = pcieio_get_num_of_dma_channels(0);

	fd = pcieio_open_bar(0,0);
	

	for(i = 0; i < num_of_channels; i ++)
	{
		pcieio_get_channel_direction(0, i, &dir);
		if(dir == 1)
			num_of_c2s_channels++;
		else
			num_of_s2c_channels++;
	}
	
	
	if(argc > 1)
	{
		if(strcmp(argv[1],"c2s")==0)
			dir = 1;
		else if(strcmp(argv[1],"s2c")==0)
			dir = 0;
		else
		{
			printf("Input Error: first argument must be channel type s2c or c2s\n");
			exit(0);
		}
		
		if(argc > 2)
		{
			sscanf(argv[2],"%d",&chan_id);	
		}
		else
		{
			printf("Input Error: second argument must be the channel number\n");
			exit(0);
		
		}		
	}
	else
	{
		printf("Input Error: no arguments\n");
		exit(0);
		
	}
	
	printf("Num of c2s channels: %d, Num of s2c channels: %d chan_id: %d  \n",num_of_c2s_channels,num_of_s2c_channels, chan_id);	
	
	
	chan_base_addr = dir == 1 ? CHANNEL_OFFSET(chan_id) : CHANNEL_OFFSET((chan_id+num_of_c2s_channels));
	pcieio_read_register(fd, chan_base_addr, &ch_state);	
	pcieio_read_register(fd, chan_base_addr+4, &statu_int_state);
	
	printf("%s[%d] dbg regs: state:%x int_state %x %x\n",dir ? "c2s": "s2c",chan_id, ch_state, statu_int_state,chan_base_addr);
	 

	pcieio_close_bar(fd);
	
	return 0;
}


