/*********************************************************************
	Component		: PcieTypes ******
	Model Element	: PcieTypes
	Version			: 1.1
	Company			: RAFAEL
*********************************************************************/ 

#ifndef __PCI_E_TYPES_H__
#define __PCI_E_TYPES_H__


typedef	void	VOID,*PVOID;
typedef	uint32_t	ULONG	;
typedef	unsigned	char	BOOL,BOOLEAN,*PUCHAR	;
typedef	int	HANDLE					;
typedef	ULONG	*PULONG,DWORD,*PDWORD;
typedef	unsigned	int	UINT		;
typedef	unsigned	long long	ULONGLONG	;
typedef	        	long long	__int64  	;

typedef unsigned int PCIE_UINT32;
typedef signed int PCIE_SINT32;


#ifndef FALSE
	#define	FALSE	0
#endif	// FALSE
#ifndef TRUE
	#define	TRUE	1
#endif	// TRUE
#define	INVALID_HANDLE_VALUE	-1


#define IN
#define OUT


    // Interrupts
    enum EInterruptTypes           
    {
		eUserInterrupt0		= 0,
        eUserInterrupt1   	= 1,
        eUserInterrupt2   	= 2,
        eUserInterrupt3   	= 3,
        eUserInterrupt4   	= 4,
        eUserInterrupt5   	= 5,
        eUserInterrupt6   	= 6,
        eUserInterrupt7   	= 7,
        eUserInterrupt8   	= 8,
        eUserInterrupt9   	= 9,
        eUserInterrupt10  	= 10,
        eUserInterrupt11   	= 11,
        eUserInterrupt12   	= 12,
        eUserInterrupt13   	= 13,
        eUserInterrupt14   	= 14,
        eUserInterrupt15   	= 15,
        eUserInterrupt16   	= 16,
        eUserInterrupt17   	= 17,
        eUserInterrupt18   	= 18,
        eUserInterrupt19   	= 19,
        eUserInterrupt20   	= 20,
        eUserInterrupt21   	= 21,
        eUserInterrupt22   	= 22,
        eUserInterrupt23   	= 23,
        eUserInterrupt24   	= 24
    };

   typedef enum _EErrCode
    {
	   eFinishedSuccessfully,
	   eDmaIsBusy,
	   eDmaIsNotBusy,
	   eFailedLockingPhysicalAddress,
	   eBufferIsNull,
	   eNotDataPathAligned,
	   eIllegalInput,
	   eFailed,
	   eTimeout,
	   eIllegalBufferId,
	   eNoFreeBufferId,
	   eBufferWasNotPreAllocated,
	   eDeviceNotFound,
	   eInvalidChannelId,
	   eInvalidDataSize,
	   eCanceled

	}EErrCode;

    // DMAs number
    typedef enum _EDmaChannel
    {
        eDma1       = 1,
        eDma2       = 2,
        eDma3       = 3,
        eDma4       = 4,
        eDma5       = 5,
        eDma6       = 6,
        eDma7       = 7,
        eDmasNum
	}EDmaChannel;


	typedef enum _EDirection
	{
		eDirWrite = 0,
		eDirRead = 1
	}EDirection;


	typedef struct SChannelInfo
	{
		EDirection m_eDir; // read/write
		unsigned int m_unMaxNumOfPendingBuffer; // max number of requests at the same time
		unsigned int m_unMaxPacketSize; // max packet size supported by FW for both downstream & upstream
		unsigned int m_bInUse; // for future use.
		unsigned int m_bActive;
		unsigned int debug;
	}	SChannelInfo;

    typedef struct SDmaBuffer
    {
    	struct buffer_descriptor *pbd;
	int		m_Size;
	bool		m_bRead;
	int efd;

	void*       	m_pMetaData;        
	void*       	m_pData;
	void*		m_ApplicationData;
    }SDmaBuffer;

	 
    typedef struct SBoardInfo
    {
	unsigned int  m_unNumOfDmaChannel; // max of supported DMA on the board
	unsigned int m_unNumOfUserInterrupts;
	uint32_t m_ulFpgaPciEIpVersion; // PCI IP Version, format: major|minor (16bit each)
	uint32_t m_ulFpgaPciEIpDate;
	unsigned int  m_unSpare; // for future use.
    }SBoardInfo;




#endif // __PCI_E_TYPES_H__
