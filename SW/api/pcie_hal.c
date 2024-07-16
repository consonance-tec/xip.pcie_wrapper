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
#include "pcie_hal.h"
#include "con_pcie_dma_drv_io.h"
#include "con_pcie_dma.h"




#define	NL	19
#define	EL	20
#define	RL	10
#define	DL	22
#define	EC	32
#define	RC	32
#define	DC	32

#define VER_MJ	1
#define VER_MN	0

#define YY	22
#define MM	07
#define DD	22

#define HAL_VER ((VER_MJ << 16) | VER_MN)
#define HAL_DATE ((YY<<16) | (MM << 8) | DD)

#define MAX_NUM_OF_CHANNELS			8
#define MAX_NUM_OF_BOARDS			10
#define MAX_NUM_OF_USER_INTERRUPTS	32



#define NO_BUFF_LOCK

//#define DBG_PRINT





typedef	struct	str_q
{
	struct kiocb *iocb;
	int	num_pages;
	loff_t pos;
	int	b_read;
	int	ifn;
	int	pid;
	int	efd;
	int	b_aio;
	struct	page	**p_user;
	int	t_len;
	int rem;
}	str_q_t, *pstr_q_t;

typedef struct  SDmaChannel
{
	struct dma_channel_descriptor dcd;
	struct buffer_descriptor* pbd_first;
	bool		m_bValid;
	int		m_Handle;
	bool		m_InUse;
	bool		m_Active;
	int		m_Pending;
	bool		m_bAborting;


	EDirection		m_eDir;
	int			m_BoardId;
	int			m_Id;
	io_context_t 		m_ctx;
	int			m_efd;
	pthread_t		m_hIOthread;
	unsigned int	 	m_unMaxNumOfPendingBuffer;
	unsigned int 		m_unMaxPacketSize;
	pfnDmaCallbackFunc 	pUsrCallback;
	uint32_t 		m_Id_for_drv;		
}SDmaChannel;

struct  SBoard;

typedef struct  SUserInterrupt
{
	pfnInterruptCallback pIntCallbak;
	int handle;
	uint32_t Id;
	bool active;
	pthread_t hInterruptthread;
	int board_id;
}SUserInterrupt;

typedef struct  SBoard
{
	int board_id;
	uint32_t ulFpgaPciEIpVersion;
	uint32_t ulFpgaPciEIpDate;
	//int int_efd;
	//pthread_t hInterruptthread;
	int iNumOfChannels;
	int iNumOfUserInterrupts;
	SDmaChannel ChannelArray[MAX_NUM_OF_CHANNELS];
	uint32_t ulIntMask;
	//pfnInterruptCallback pIntCallbaks[MAX_NUM_OF_USER_INTERRUPTS];
	SUserInterrupt UserInterrupts[MAX_NUM_OF_USER_INTERRUPTS];
}SBoard;



void * IOThreadAio(void *);
void * InterruptThread(void *);

static SBoard BoardArray[MAX_NUM_OF_BOARDS] = {0};
static int giNumOfBoards = 0;
static bool gbInitDone = false;

extern int	X3FFFFFFF;


/////////////////////////////////////////////////////////////////////////////
// PciHalInit
// ///////////////////////////////////////////////////////////////////////////
// Description : Initializes the driver and registers the default
// Return:
// Arguments:
// // ////////////////////////////////////////////////////////////////////////////
bool PciHalInit()
{

	
#ifdef DBG_PRINT
	printf("PciHalInit() is called\n");
#endif
	int b, c;
	bool ret = true;

		
	uint32_t ulFpgaPciEIpVersion; 
	uint32_t ulFpgaPciEIpDate;
	uint32_t unNumOfDmaChannel;
	uint32_t unNumOfUserInterrupts;


	X3FFFFFFF=0x3fffffff;
	X3FFFFFFF*=0x4000;
	//rest parameters that are to be retrived form the ko
	giNumOfBoards = 0;

	giNumOfBoards = pcieio_get_num_of_devices();

	//printf("PciHalInit() ***** number of Boards = %d %d\n",giNumOfBoards, ret);
	if(giNumOfBoards == -1)
		return false; 

	
	int bi;
	int chi;
	for (bi = 0; ret && bi < giNumOfBoards; bi++)
	{
			
		

		unNumOfDmaChannel = 0;
		unNumOfDmaChannel = pcieio_get_num_of_dma_channels(bi);
		//printf("PciHalInit() ***** number of DMA Channels = %d \n",unNumOfDmaChannel);
		

		unNumOfUserInterrupts = pcieio_get_num_of_user_interrupts(bi);
		//printf("PciHalInit() ***** unNumOfUserInterrupts = %d\n",unNumOfUserInterrupts);

		ret = 1; 


		pcieio_get_fpga_version(bi,&ulFpgaPciEIpVersion);

		
		if (ret)
		{
			//EDirection temp[4] = {eDirRead,eDirRead,eDirRead,eDirWrite};
			uint32_t Id_for_drv_write = 0;
			uint32_t Id_for_drv_read = 0;

			BoardArray[bi].iNumOfChannels = unNumOfDmaChannel;
			BoardArray[bi].iNumOfUserInterrupts = unNumOfUserInterrupts;
			BoardArray[bi].ulFpgaPciEIpVersion = ulFpgaPciEIpVersion;
			BoardArray[bi].ulFpgaPciEIpDate = 0;
			BoardArray[bi].ulIntMask = 0;
			BoardArray[bi].board_id = bi;
			

			for (chi = 0; ret && chi < BoardArray[bi].iNumOfChannels; chi++)
			{
				
				int dir;
				pcieio_get_channel_direction(bi, chi, &dir);
				
				BoardArray[bi].ChannelArray[chi].m_eDir = dir ? eDirRead : eDirWrite;
				BoardArray[bi].ChannelArray[chi].m_bValid = true;
				BoardArray[bi].ChannelArray[chi].m_Handle = 0;
				BoardArray[bi].ChannelArray[chi].m_InUse = false;
				BoardArray[bi].ChannelArray[chi].m_Active = false;
				BoardArray[bi].ChannelArray[chi].m_unMaxNumOfPendingBuffer = 10; 
				BoardArray[bi].ChannelArray[chi].m_unMaxPacketSize = (5*1024*1024); 
				BoardArray[bi].ChannelArray[chi].pUsrCallback = NULL;
				BoardArray[bi].ChannelArray[chi].m_BoardId = bi;
				BoardArray[bi].ChannelArray[chi].m_Id = chi;
				if(dir)
					BoardArray[bi].ChannelArray[chi].m_Id_for_drv = Id_for_drv_read++;
				else	
					BoardArray[bi].ChannelArray[chi].m_Id_for_drv = Id_for_drv_write++;
				
				
			}


		}

		if (ret)
		{
			int ui = 0;
			for(ui=0;ui<unNumOfUserInterrupts;ui++)
			{
				BoardArray[bi].UserInterrupts[ui].pIntCallbak = NULL;
				BoardArray[bi].UserInterrupts[ui].Id = ui;
				BoardArray[bi].UserInterrupts[ui].board_id = bi;
				BoardArray[bi].UserInterrupts[ui].active = false;
				pthread_create(&BoardArray[bi].UserInterrupts[ui].hInterruptthread, NULL, InterruptThread, (void *)&BoardArray[bi].UserInterrupts[ui]);
			}
		}
		
	}
	

	gbInitDone = ret;


	return ret;

}


/////////////////////////////////////////////////////////////////////////////
// PciHalCleanup
// ///////////////////////////////////////////////////////////////////////////
// Description : Uninitializes the driver
// Return:
// Arguments:
// // ////////////////////////////////////////////////////////////////////////////
bool PciHalCleanup()
{
	int bi;

#ifdef DBG_PRINT
	printf("PciHalCleanup() is called giNumOfBoards=%d\n",giNumOfBoards);
#endif

	
	
	for (bi = 0; bi < giNumOfBoards; bi++)
	{
		PVOID	pv;
		int ui;
		int chi;

		
		for(ui=0;ui<BoardArray[bi].iNumOfUserInterrupts;ui++)
		{
			if(BoardArray[bi].UserInterrupts[ui].active)
			{
				BoardArray[bi].UserInterrupts[ui].active = false;
				pcieio_release_interrupt_event(bi, ui);	
				pthread_join(BoardArray[bi].UserInterrupts[ui].hInterruptthread, &pv);
			}
		}
		
		for (chi = 0; chi < BoardArray[bi].iNumOfChannels; chi++)
		{
			if (BoardArray[bi].ChannelArray[chi].m_Active)
			{
			
				pcieio_stop_channel((struct dma_channel_descriptor *)&BoardArray[bi].ChannelArray[chi]);
				pcieio_close_dma_channel((struct dma_channel_descriptor *)&BoardArray[bi].ChannelArray[chi]);
			}
		}
	}
	return true;
}



/////////////////////////////////////////////////////////////////////////////
// IsInitialized
// ///////////////////////////////////////////////////////////////////////////
// Description :  Returns true if the driver is initialized, false otherwise
// Return type :  bool
// Arguments    : unsigned int* puNumOfInitializedBoards - will hold number of initialized boards.
//
// Note: The boards are being initialized in order of their physical location.
// ////////////////////////////////////////////////////////////////////////////
bool IsInitialized(unsigned int *punNumOfInitializedBoards)
{
#ifdef DBG_PRINT
	printf("IsInitialized() is called\n");
#endif
	if (gbInitDone && punNumOfInitializedBoards != NULL)
		*punNumOfInitializedBoards = giNumOfBoards;

	return gbInitDone;
}

// ///////////////////////////////////////////////////////////////////////////
// GetChannelInfo
// ///////////////////////////////////////////////////////////////////////////
// Description :  return information on a specific channel
// Return type :
// Arguments    : unBoardId - specific board ID
// 			eDma    - specific DMA channel
//			psChannelInfo - return info on a specific channel
// Note:
// ////////////////////////////////////////////////////////////////////////////
EErrCode GetChannelInfo(IN unsigned int unBoardId, IN EDmaChannel eDma, OUT SChannelInfo * psChannelInfo)
{
#ifdef DBG_PRINT
	printf("GetChannelInfo() is called for unBoardId %d, eDma = %d \n", unBoardId, (int)eDma);
#endif
	unsigned int tt;
	EErrCode ret = eFinishedSuccessfully;

	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;


	if (BoardArray[unBoardId].iNumOfChannels < (int)eDma)
		return eInvalidChannelId;

	psChannelInfo->m_bActive = BoardArray[unBoardId].ChannelArray[eDma].m_Active;
	psChannelInfo->m_bInUse = BoardArray[unBoardId].ChannelArray[eDma].m_InUse;
	psChannelInfo->m_unMaxNumOfPendingBuffer	= BoardArray[unBoardId].ChannelArray[eDma].m_unMaxNumOfPendingBuffer;
	psChannelInfo->m_unMaxPacketSize			= BoardArray[unBoardId].ChannelArray[eDma].m_unMaxPacketSize;
	psChannelInfo->m_eDir						= BoardArray[unBoardId].ChannelArray[eDma].m_eDir;
	psChannelInfo->debug = BoardArray[unBoardId].ChannelArray[eDma].m_Pending;

	return ret;
}

// ///////////////////////////////////////////////////////////////////////////
// GetBoardInfo
// ///////////////////////////////////////////////////////////////////////////
// Description :  return information on a specific board
// Return type :
// Arguments    : unBoardId - specific board ID
// 			psBoardInfo - return info on the board
// Note:
// ////////////////////////////////////////////////////////////////////////////
EErrCode GetBoardInfo(IN unsigned int unBoardId, OUT SBoardInfo* psBoardInfo)
{
	EErrCode ret = eDeviceNotFound;

	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;

	psBoardInfo->m_unNumOfDmaChannel = BoardArray[unBoardId].iNumOfChannels;
	psBoardInfo->m_unNumOfUserInterrupts = BoardArray[unBoardId].iNumOfUserInterrupts;
	psBoardInfo->m_ulFpgaPciEIpVersion = BoardArray[unBoardId].ulFpgaPciEIpVersion;
	psBoardInfo->m_ulFpgaPciEIpDate = BoardArray[unBoardId].ulFpgaPciEIpDate;

	return eFinishedSuccessfully;
}


// ///////////////////////////////////////////////////////////////////////////
// AbortDma
// ///////////////////////////////////////////////////////////////////////////
// Description:	Aborts specific DMA transaction
// Return:		0 on success or an error code
// Arguments    : unsigned int uDma - DMA channel number
//                unsigned int nBoardId - The board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode AbortDma(EDmaChannel eDma, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("AbortDma() is called, Dma = %d, BoardId = %d\n", eDma, unBoardId);
#endif
	SDmaChannel *pChan;
	uint64_t u=X3FFFFFFF;
	int i;
	EErrCode ret = eFinishedSuccessfully;
	int rc;
	
	u++;

	
	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;
	
	if (BoardArray[unBoardId].iNumOfChannels < (int)eDma)
		return eInvalidChannelId;
	
	pChan = &BoardArray[unBoardId].ChannelArray[(int)eDma];
	pChan->m_bAborting = true;
		
	if (pChan->m_Active)
	{
		PVOID	pv;
		pcieio_stop_channel((struct dma_channel_descriptor *)pChan);
		pthread_join(pChan->m_hIOthread,&pv);
	}


	pChan->m_bAborting = false;

	pChan->m_Active = false;

		
	return ret;
}


// ///////////////////////////////////////////////////////////////////////////
// OpenDmaChannle
// ///////////////////////////////////////////////////////////////////////////
// Description : Opens a channel for DMA transactions
// Return:		 0 on success or an error code
// Arguments     unsigned int uDma - DMA channel number
//				 pfnDmaCallbackFunc pCallback - completion callbck for DMA transacctions
//               unsigned int nBoardId - The board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode  OpenDmaChannel(pfnDmaCallbackFunc pCallback, EDmaChannel eDma, unsigned int unBoardId)
{
	SDmaChannel *pChan;
	int rc;
	EErrCode ret = eFinishedSuccessfully;
	pChan = &BoardArray[unBoardId].ChannelArray[(int)eDma];
	
#ifdef DBG_PRINT
	printf("OpenDmaChannel() is called for Dma %d, unBoardId %d %p %p\n", eDma, unBoardId, pChan,pCallback);
#endif
	

	if (!(unBoardId < giNumOfBoards))
	{
#ifdef DBG_PRINT
		printf("OpenDmaChannel():   DeviceNotFound\n");
#endif
		return eDeviceNotFound;
	}

	if (BoardArray[unBoardId].iNumOfChannels < (int)eDma)
	{
#ifdef DBG_PRINT
		printf("OpenDmaChannel():   InvalidChannelId\n");
#endif
		return eInvalidChannelId;
	}

	if (BoardArray[unBoardId].ChannelArray[(int)eDma].m_InUse)
	{
#ifdef DBG_PRINT
		printf("OpenDmaChannel():   In Use\n");
#endif
		return eDmaIsBusy;
	}

	
	rc = pcieio_open_dma_channel(unBoardId, (int)pChan->m_Id_for_drv,
				pChan->m_unMaxNumOfPendingBuffer,
				pChan->m_eDir == eDirRead,
				(struct dma_channel_descriptor *)pChan);
				
	if(rc < 0)
	{
#ifdef DBG_PRINT
		printf("OpenDmaChannel():   pcieio_open_dma_channel ret=%d\n",rc);
#endif
		return eDmaIsBusy;
	}
		
	
	BoardArray[unBoardId].ChannelArray[(int)eDma].pUsrCallback = pCallback;
	BoardArray[unBoardId].ChannelArray[(int)eDma].m_InUse = true;
	
	
	

	return ret;
}


// ///////////////////////////////////////////////////////////////////////////
// CloseDmaChannle
// ///////////////////////////////////////////////////////////////////////////
// Description : Opens a channel for DMA transactions
// Return:	 0 on success or an error code
// Arguments     unsigned int uDma - DMA channel number
//               unsigned int nBoardId - The board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode  CloseDmaChannel(EDmaChannel eDma, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("CloseDmaChannel() is called, Dma = %d, BoardId = %d\n", eDma, unBoardId);
#endif


	EErrCode ret = eFinishedSuccessfully;

	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;
	
	if (BoardArray[unBoardId].iNumOfChannels < (int)eDma)
		return eInvalidChannelId;
	
	ret=AbortDma(eDma, unBoardId);
	
	BoardArray[unBoardId].ChannelArray[(int)eDma].m_InUse = false;

	return ret;
}

// ///////////////////////////////////////////////////////////////////////////
// SetMaxReadReq
// ///////////////////////////////////////////////////////////////////////////
// Description : Set the Max Read Request parameter for a channel
// Return:	  0 on success or an error code
// Arguments:    unsigned int max_req - Max Read Request
// ///////////////////////////////////////////////////////////////////////////
EErrCode SetMaxReadReq(EDmaChannel eDma, unsigned int unBoardId, unsigned int max_req) 
{
	return set_max_read_request(unBoardId,(int)eDma, max_req) >= 0 ? eFinishedSuccessfully : eFailed;
	
}

// ///////////////////////////////////////////////////////////////////////////
// StartDma
// ///////////////////////////////////////////////////////////////////////////
// Description : Start DMA requests
// Return:		 0 on success or an error code
// Arguments     unsigned int uDma - DMA channel number
//               unsigned int nBoardId - The board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode StartDma(EDmaChannel eDma, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("StartDma() is called for Dma %d, unBoardId %d\n", eDma, unBoardId);
#endif
	EErrCode ret = eFinishedSuccessfully;

	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;

	if (BoardArray[unBoardId].iNumOfChannels < (int)eDma)
		return eInvalidChannelId;

	if (!BoardArray[unBoardId].ChannelArray[(int)eDma].m_Active)
	{
		int rc;
		

		BoardArray[unBoardId].ChannelArray[(int)eDma].m_Active = true;
		BoardArray[unBoardId].ChannelArray[(int)eDma].m_Pending = 0;
		BoardArray[unBoardId].ChannelArray[(int)eDma].m_bAborting = false;
		rc = pthread_create(&BoardArray[unBoardId].ChannelArray[(int)eDma].m_hIOthread, NULL, IOThreadAio, (void *)&BoardArray[unBoardId].ChannelArray[(int)eDma]);

		if (rc < 0)
		{
			return eFailed;
		}
		
		
		rc = pcieio_start_channel((struct dma_channel_descriptor *)&BoardArray[unBoardId].ChannelArray[(int)eDma]);
		
		if (rc < 0)
		{
			printf("StartDma return eFailed (1) rc = %d\n",rc);
			return eFailed;
		}
		
		
		return ret;
			
			
	}
	else
		ret = eDmaIsBusy;

	printf("StartDma() returns %d\n", ret);
	return ret;

}

// ///////////////////////////////////////////////////////////////////////////
// StartAllDma
// ///////////////////////////////////////////////////////////////////////////
// Description : Intiates all DMA channels on the given board
// Return:		 0 on success or an error code
// Arguments     unsigned int nBoardId - The board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode StartAllDma(unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("StartAllDma() is called for unBoardId %d  (NOT Implemented !!!)\n", unBoardId);
#endif
	EErrCode ret = eFinishedSuccessfully;

	return ret;
}




// ///////////////////////////////////////////////////////////////////////////
// DoDirectDma
// ///////////////////////////////////////////////////////////////////////////
// Description : Initiates a Block DMA transaction.
// Return:		 0 on success or an error code
// Arguments    : unsigned int eDma - DMA channel number
//                unsigned int uByteCount- number of bytes in transaction
//                void *psDmaBuffer - data buffer
//                unsigned int nBoardId - board-id. default value
// ///////////////////////////////////////////////////////////////////////////
EErrCode DoDirectDma(unsigned int unByteCount, SDmaBuffer* psDmaBuffer, EDmaChannel eDma, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("DoDirectDma() is called for Dma %d, unBoardId %d  (NOT Implemented !!!)\n", eDma, unBoardId);
#endif
	EErrCode ret = eFinishedSuccessfully;




	return ret;
}

// ///////////////////////////////////////////////////////////////////////////
// DoDirectRead
// ///////////////////////////////////////////////////////////////////////////
// Description	: Performs direct read transaction
// Return		: unsigned int - if >0 - succeeded, 0 - failed, <0 - no deivce
// Arguments    :Punsigned int  uBarIndex - Wanted Bar index to read from
//               unsigned int  uOffset - the register offset to read from
//               unsigned int  uDwordsCount - number of 32bit words in puBuffer
//               unsigned long* puBuffer - the buffer to read into
//               unsigned int  nBoardId - The board-id. default value
// Note: The driver can send only one DWORD at a time, so if one sends more then
//  one DWORD it sends one DWORD after another and not a burst of DWORDs
// ////////////////////////////////////////////////////////////////////////////
EErrCode DoDirectRead(unsigned int unBarIndex, unsigned int unOffset, unsigned int unDwordsCount, unsigned long * pulBuffer, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("DoDirectRead() is called for unBoardId %d\n", unBoardId);
#endif
	int	rc;
	EErrCode ret = eFinishedSuccessfully;

	int h;
	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;

	h = pcieio_open_bar(unBoardId,unBarIndex);

	if (h >= 0)
	{
		unsigned int i;
		for (i = 0; i < unDwordsCount; i++)
		{
			pcieio_read_register(h, i * 4 + unOffset, (uint32_t *)&pulBuffer[i]);
			if ( !rc )
			{
			ret=eFailed;
			break;
			}
		}
		close(h);
	}
	else
		ret=eDeviceNotFound;

	return ret;
}

// ///////////////////////////////////////////////////////////////////////////
// DoDirectWrite
// ///////////////////////////////////////////////////////////////////////////
// Description : Performs direct write transaction
// Return		: unsigned int - if >0 - succeeded, 0 - failed, <0 - no deivce
// Arguments    :unsigned int  uBarIndex - Wanted Bar index to read from
//               unsigned int  uOffset - the register offset to read from
//               unsigned int  uDwordsCount - number of 32bit words in puBuffer
//               unsigned long* puBuffer - the buffer to read into
//               unsigned int  nBoardId - The board-id. default value
// Note: The driver can send only one DWORD at a time, so if one sends more then
// one DWORD it sends one DWORD after another and not a burst of DWORDs
// /////////////////////////////////////////////////////////////////////////////
EErrCode DoDirectWrite(unsigned int unBarIndex, unsigned int unOffset, unsigned int unDwordsCount, unsigned long* pulBuffer, unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("DoDirectWrite() is called for unBoardId %d\n", unBoardId);
#endif

	int	rc;
	EErrCode ret = eFinishedSuccessfully;

	int h;
	if (!(unBoardId < giNumOfBoards))
		return eDeviceNotFound;

	h = pcieio_open_bar(unBoardId,unBarIndex);

	if (h >= 0)
	{
		unsigned int i;
		for (i = 0; i < unDwordsCount; i++)
		{
			rc=pcieio_write_bar_register(h, i * 4 + unOffset , pulBuffer[i]);
			if ( !rc )
			{
				ret=eFailed;
				break;
			}
		}
		close(h);
	}
	else
		ret=eDeviceNotFound;
	return ret;
}


// ///////////////////////////////////////////////////////////////////////////
// DoSGDma
// ///////////////////////////////////////////////////////////////////////////
// Description : Initiates DMA transaction (by Scatter-Gather command)
//				 This function completes asynchronously
// Return		 0 on success or an error code
// Arguments    :char* psDmaBuffer - this struct contains the data for the transaction (read from /write to)
// 					and the internal meta-data for dma transaction.
//   			 unsigned int uDma- DMA channel number
//   			 unsigned int uByteCount- number of bytes in transaction
//   			 unsigned int nBoardId - The PLDA board-id. default value
// Note: psDmaBuffer size must be aligned to the bus width.
// ////////////////////////////////////////////////////////////////////////////
EErrCode DoSGDma(SDmaBuffer* psDmaBuffer, unsigned int unByteCount, EDmaChannel eDma, unsigned int unBoardId)
{
	int rc;
	EErrCode ret = eFinishedSuccessfully;
	SDmaChannel *pChan = &BoardArray[unBoardId].ChannelArray[(int)eDma];

	if (pChan->m_bAborting)
	{
#ifdef DBG_PRINT
		printf("DoSGDma(): eDmaIsBusy\n");
#endif
		return eDmaIsBusy;
	}

	if (psDmaBuffer->m_Size < unByteCount)
	{
#ifdef DBG_PRINT
		printf("DoSGDma(): Fail because (psDmaBuffer->m_Size < unByteCount) \n");
#endif
		return eInvalidDataSize;
	}

	if ((pChan->m_eDir == eDirRead) && (false == psDmaBuffer->m_bRead))
	{
#ifdef DBG_PRINT
		printf("DoSGDma(): Fail because (ChDirection Is Read, but Buffer is for Write), Channel Number is %d\n", (int)eDma);
		return eInvalidDataSize;
#endif
	}

	if ((pChan->m_eDir == eDirWrite) && (true == psDmaBuffer->m_bRead))
	{
#ifdef DBG_PRINT
		printf("DoSGDma(): Fail because (ChDirection Is Write, but Buffer is for Read), Channel Number is %d\n", (int)eDma);
#endif
		return eInvalidDataSize;
	}
	
	rc = pcieio_submit_io_request((struct dma_channel_descriptor *)pChan, psDmaBuffer->pbd, unByteCount);


	if (rc < 0 )
	{
#ifdef DBG_PRINT
		printf("DoSGDma(): io_submit() failed (DMA %d) rc=%d\n", (int)eDma, rc);
#endif
		ret = eFailed;
	}
	else
	{
		pChan->m_Pending++;
		ret = eFinishedSuccessfully;
#ifdef DBG_PRINT
		printf("DoSGDma(): Success. psDmaBuffer = 0x%p, pChan->m_Pending = %d\n", psDmaBuffer, pChan->m_Pending);
#endif
	}

	return ret;
}


// ///////////////////////////////////////////////////////////////////////////
// LockSGDmaBuffer
// ///////////////////////////////////////////////////////////////////////////
// Description : Locks the buffer's physical address and creates a descriptor
//                     list for scatter-gather DMA transfer for a user-allocated buffer
//                     It also allocates the meta-data for DMA transaction.
// Return type : EErrCode - eBufferIsNull - if the buffer is null
//                          eFailedLockingPhysicalAddress - if failed to lock physical address
//                          eFinishedSuccessfully - otherwise
// Arguments    :   SDmaBuffer* psDmaBuffer - this struct will contain the buffer for the transaction (read from /write to)
//                   and the internal meta-data for dma transaction.
//                  PCIE_UINT32 uByteCount- number of bytes in transaction
// Note: Remember to use after receiving the END_DMA interrupt PostDirectDma to unlock the buffer
// Note: the buffer size must be aligned to the bus width.
// Note: Every lock creates a buffer descriptor + buffer id. It can be done up to
//  2^32-8 times.
// ////////////////////////////////////////////////////////////////////////////
//## operation LockSGDmaBuffer(SDmaBuffer*,PCIE_UINT32)
EErrCode LockSGDmaBuffer(SDmaBuffer* psDmaBuffer)
{
#ifdef DBG_PRINT
	printf("LockSGDmaBuffer() is called, psDmaBuffer = 0x%p, bufferDirection is %s\n", psDmaBuffer, psDmaBuffer->m_bRead? "Read" : "Write");
#endif
	
	int ret = 0;

	if (!psDmaBuffer->m_pData)
	{
#ifdef DBG_PRINT
		printf("LockSGDmaBuffer() failed - BufferIsNull\n");
#endif
		return eBufferIsNull;
	}

	//todo: the first parameter is const 0 but should it be the board id? 
	psDmaBuffer->pbd = pcieio_pin_buffer(0, psDmaBuffer->m_pData, psDmaBuffer->m_Size, psDmaBuffer->m_bRead, (uint64_t)psDmaBuffer);
	
	//printf("back form pcieio_pin_buffer psDmaBuffer->pbd=%p psDmaBuffer=%p &psDmaBuffer->pbd=%p\n",
	//	psDmaBuffer->pbd,psDmaBuffer,&psDmaBuffer->pbd);

	return  ret == 0 ? eFinishedSuccessfully : eFailedLockingPhysicalAddress;

}


// ///////////////////////////////////////////////////////////////////////////
// UnLockSGDmaBuffer
// ///////////////////////////////////////////////////////////////////////////
// Description : UnLock physical address after DMA SG transaction
// Return type : EErrCode - eFinishedSuccessfully
// Arguments:    SDmaBuffer* psDmaBuffer - this struct contains the buffer for the transaction (read from /write to)
//                  and the internal meta-data for dma transaction.
// ///////////////////////////////////////////////////////////////////////////
//## operation UnLockSGDmaBuffer(SDmaBuffer*)
EErrCode UnLockSGDmaBuffer(SDmaBuffer* psDmaBuffer)
{
#ifdef DBG_PRINT
	printf("UnLockSGDmaBuffer() is called, psDmaBuffer = 0x%p, bufferDirection is %s\n", psDmaBuffer, psDmaBuffer->m_bRead? "Read" : "Write");
#endif
#ifndef NO_BUFF_LOCK
	ioctl(BoardArray[0].handle, CXF_UNLOCK_BUFFER, psDmaBuffer->m_pMetaData);
#endif

	pcieio_release_buffer(0, psDmaBuffer->pbd);
	EErrCode ret = eFinishedSuccessfully;

	return ret;
}


// ///////////////////////////////////////////////////////////////////////////
// GetPciEHalVersion
// ///////////////////////////////////////////////////////////////////////////
// Description	: Returns the CPcieHal wrapper version
// Retur		: EErrCode - eIllegalInput if the buffer size is too small.
//                          eBufferIsNull - if the buffers' memory is not allocated
//                          eFinishedSuccessfully - otherwise.
// Arguments   : unsigned long* pchVersion - version number
// 				major | minor
//               char * pchDate -  version date in format:
//				00 | YY | MM | DD

// ////////////////////////////////////////////////////////////////////////////
EErrCode GetPciEHalVersion(unsigned long* pulHalVersion, unsigned long* pulHalDate)
{
#ifdef DBG_PRINT
	printf("GetPciEHalVersion() is called\n");
#endif
	EErrCode ret = eFinishedSuccessfully;

	*pulHalVersion = HAL_VER;
	*pulHalDate = HAL_DATE;

	return ret;
}

// ///////////////////////////////////////////////////////////////////////////
// GetDriverVersion
// ///////////////////////////////////////////////////////////////////////////
// Description : Returns the driver version number
// Return type : EErrCode - eBufferIsNull if the buffer memory was not allocated
//                          eFailed - if failed to read the driver version
//                          eFinishedSuccessfully - otherwise
// Arguments   : unsigned long* pulKernelDriverVersion - KO version
//	             Format: major | minor
// ////////////////////////////////////////////////////////////////////////////
EErrCode GetDriverVersion(unsigned long *pulKernelDriverVersion)
{
#ifdef DBG_PRINT
	printf("GetDriverVersion() is called (NOT Implemented !!!)\n");
#endif
	
	if (pcieio_get_driver_version((uint32_t *)pulKernelDriverVersion) < 0)
		return eFailed;
	
	return eFinishedSuccessfully;
}



// ///////////////////////////////////////////////////////////////////////////
// RegisterInterruptHanlder
// ///////////////////////////////////////////////////////////////////////////
// Description	: For a specific user interrupt, attaches its handler
// Return type	: EErrCode
// Arguments    :unsigned int iIndex - interrupt index
//               pfnInterruptCallback pCallback - interrupt handler function pointer
//               unsigned long nBoardId - The board-id. default value
// ////////////////////////////////////////////////////////////////////////////////////
EErrCode RegisterInterruptHandler(unsigned int unIndex, pfnInterruptCallback pCallback, unsigned int unBoardId)
{
	EErrCode ret = eFailed;
	uint32_t temp; 
#ifdef DBG_PRINT
	printf("RegisterInterruptHandler() is called \n");
#endif

	//if the interrupt is taken
	if(BoardArray[unBoardId].ulIntMask & (1 << unIndex))
		return ret;
 
		

	temp = BoardArray[unBoardId].ulIntMask | 1 << unIndex;

	//BoardArray[unBoardId].pIntCallbaks[unIndex] = pCallback;
	BoardArray[unBoardId].UserInterrupts[unIndex].pIntCallbak = pCallback;
	
	return eFinishedSuccessfully;
}


// // ///////////////////////////////////////////////////////////////////////////
// // Send a Debug Query request to the driver
// // ///////////////////////////////////////////////////////////////////////////
// // Description : Performs a full reset to the firmware
// // Return type : EErrCode
// // Argument    : unsigned int nBoardId - The board-id. 
// //		unsigned int DbgVal 
// // ///////////////////////////////////////////////////////////////////////////
EErrCode QueryDebug(unsigned int unBoardId,unsigned int unDbgVal)
{
	
	return eFailed;

}
// // ///////////////////////////////////////////////////////////////////////////
// // ResetSystem
// // ///////////////////////////////////////////////////////////////////////////
// // Description : Performs a full reset to the firmware
// // Return type : EErrCode
// // Argument    : unsigned int nBoardId - The board-id. default value
// // ///////////////////////////////////////////////////////////////////////////
EErrCode ResetSystem(unsigned int unBoardId)
{
#ifdef DBG_PRINT
	printf("ResetSystem() is called \n");
#endif
	return eFailed;
}


// ///////////////////////////////////////////////////////////////////////////
// UnRegisterInterruptHanlder
// ///////////////////////////////////////////////////////////////////////////
// Description : For a specific user interrupt, remove its handler
// Return type : EErrCode
// Arguments    :unsigned int iIndex
//               unsigned int iIndex nBoardId - The board-id. default value
// ////////////////////////////////////////////////////////////////////////////////////
EErrCode UnRegisterInterruptHandler(unsigned int unIndex, unsigned int unBoardId)
{
	EErrCode ret = eFinishedSuccessfully;
	uint32_t temp = BoardArray[unBoardId].ulIntMask | 1 << unIndex;

#ifdef DBG_PRINT
	printf("UnRegisterInterruptHandler() is called \n");
#endif
	ret = eFinishedSuccessfully;

	//if the interrupt taken BY US
	if(BoardArray[unBoardId].ulIntMask | temp != 0)
	{
		BoardArray[unBoardId].ulIntMask &= ~temp; 
		BoardArray[unBoardId].UserInterrupts[unIndex].pIntCallbak = NULL;
		
	}

	
	
	return ret;
}



/////////////////////////////// Local Functions //////////////////////////////////////////

void * InterruptThread(void *pArg)
{
	SUserInterrupt *pUserInterrupt = (SUserInterrupt *)pArg;
	uint64_t eftd_ctr;
	int ev_fd = pcieio_register_interrupt_event(0,pUserInterrupt->Id);
	
		
#ifdef DBG_PRINT
	printf("InterruptThread started.... %d\n", ev_fd);
#endif

	pUserInterrupt->active = true;
	
	
	while(pUserInterrupt->active)
	{
		int s = read(ev_fd, &eftd_ctr, sizeof(uint64_t));
				
		if(pUserInterrupt->pIntCallbak)
			(pUserInterrupt->pIntCallbak)(pUserInterrupt->Id,pUserInterrupt->board_id);
	}
	
	pcieio_release_interrupt_event(0,pUserInterrupt->Id);
	
	return NULL;
}

void * IOThreadAio(void *pArg)
{
#ifdef DBG_PRINT
	printf("IOThreadAio(): started....\n");
#endif
	int	Cnt=0;
	SDmaBuffer* sdb;
	SDmaChannel  *pChan = (SDmaChannel *)pArg;
	bool do_io_loop = true;
	uint64_t count; 
	uint64_t res;
	
	while(do_io_loop)
	{
		struct buffer_descriptor * cur;
#ifdef DBG_PRINT
		printf("IOThreadAio(): calling pcieio_wait_for_io_completion pChan=%p\n", pChan);
#endif
	
		cur = pcieio_wait_for_io_completion((struct dma_channel_descriptor *)pChan, &count, &res);
#ifdef DBG_PRINT
		printf("IOThreadAio(): after pcieio_wait_for_io_completion cur=%p count=%d res=%d\n", cur,count, res);
#endif
		
		if (pChan->pUsrCallback)
		{
			EErrCode ret;
			
			switch(res)
			{
				case DMA_DONE:
					ret = eFinishedSuccessfully;
				break;
				case DMA_STOPPED:
					ret = eCanceled;
				break;
				default:
					ret = eFailed;
				break;
			}
			
			sdb = (SDmaBuffer*)cur->user_tag;
#ifdef DBG_PRINT
				printf("IOThreadAio(): do callback, received size = %lu %p\n", res, pChan->pUsrCallback);
#endif
				
			(pChan->pUsrCallback)(ret, (uint32_t)count, sdb, (EDmaChannel)pChan->m_Id, pChan->m_BoardId);
					
					
		}
#ifdef DBG_PRINT		
		else
		{

			printf("IOThreadAio(): NO callback   !!!!\n");
		}
#endif			
		
		
		if(res != DMA_DONE)
		{
			do_io_loop = false;
		}
		

	}	
	return NULL;
}



