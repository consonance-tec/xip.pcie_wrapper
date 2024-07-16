/*********************************************************************
	Component		: PcieHal 
	Model Element		: CPcieHal
	Version			: 1.1
	Company			: RAFAEL
*********************************************************************/ 

#ifndef PcieHal_H
#define PcieHal_H

#include <stdint.h>     /* for uint64 and uint32_t   definition */
#include <libaio.h>

#ifdef __cplus_plus
extern "C"
{
#endif	// __cplus_plus


#include "pcie_types.h"

	//###################################    Callbck functions type definition ####################################

	// ///////////////////////////////////////////////////////////////////////////
	// pfnDmaCallbackFunc
	// ///////////////////////////////////////////////////////////////////////////
	// Description :	Notifys the applicaiton that a DMA trasfer is completed 
	// Return type :	void
	// Arguments:		uDma: DAM channel number
	//					nBoardId:		Board Number
	//					err: 0 on success, error code on failure	
	//					uBytesCount:	Number of Bytes Read or Written
	//					psDmaBuffer:	Buffer supplied by the user
	// // ////////////////////////////////////////////////////////////////////////////
	typedef void(* pfnDmaCallbackFunc)(EErrCode eErr, unsigned int unByteCount, SDmaBuffer* psDmaBuffer, EDmaChannel eDma, unsigned int unBoardId);


	// ///////////////////////////////////////////////////////////////////////////
	// pfnInterruptCallback
	// ///////////////////////////////////////////////////////////////////////////
	// Description :	Notifys the applicaiton that a User Interrupt was triggerd 
	// Return type :	void
	// Arguments:		unsigned int iIndex
	//					nBoardId:		Board Number
	// // ////////////////////////////////////////////////////////////////////////////
	typedef void(* pfnInterruptCallback)(unsigned int unIndex, unsigned int unBoardId);


	/////////////////////////////////////////////////////////////////////////////
	// PciHalInit
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Initializes the driver and registers the default 
	// Return:
	// Arguments:
	// // ////////////////////////////////////////////////////////////////////////////
	bool PciHalInit();
    
	/////////////////////////////////////////////////////////////////////////////
	// PciHalCleanup
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Uninitializes the driver 
	// Return:
	// Arguments:
	// // ////////////////////////////////////////////////////////////////////////////
	bool PciHalCleanup();


	// ///////////////////////////////////////////////////////////////////////////
	// AbortDma
	// ///////////////////////////////////////////////////////////////////////////
	// Description:	Aborts specific DMA transaction
	// Return:		0 on success or an error code
	// Arguments    : unsigned int uDma - DMA channel number
	//                unsigned int nBoardId - The board-id. default value 
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode AbortDma(EDmaChannel eDma, unsigned int unBoardId);

	
	// ///////////////////////////////////////////////////////////////////////////
	// OpenDmaChannle
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Opens a channel for DMA transactions
	// Return:		 0 on success or an error code
	// Arguments     unsigned int uDma - DMA channel number
	//				 pfnDmaCallbackFunc pCallback - completion callbck for DMA transacctions	
	//               unsigned int nBoardId - The board-id. default value 
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode  OpenDmaChannel(pfnDmaCallbackFunc pCallback, EDmaChannel eDma, unsigned int unBoardId);


	// ///////////////////////////////////////////////////////////////////////////
	// CloseDmaChannle
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Opens a channel for DMA transactions
	// Return:		 0 on success or an error code
	// Arguments     unsigned int uDma - DMA channel number
	//               unsigned int nBoardId - The board-id. default value 
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode  CloseDmaChannel(EDmaChannel eDma, unsigned int unBoardId);

	// ///////////////////////////////////////////////////////////////////////////
	// StartDma
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Start DMA requests
	// Return:		 0 on success or an error code
	// Arguments     unsigned int uDma - DMA channel number
	//               unsigned int nBoardId - The board-id. default value 
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode StartDma(EDmaChannel eDma, unsigned int unBoardId);

	// ///////////////////////////////////////////////////////////////////////////
	// StartAllDma
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Intiates all DMA channels on the given board
	// Return:		 0 on success or an error code
	// Arguments     unsigned int nBoardId - The board-id. default value 
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode StartAllDma(unsigned int unBoardId);

	
    
     
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
	EErrCode DoDirectDma(unsigned int unByteCount, SDmaBuffer* psDmaBuffer, EDmaChannel eDma, unsigned int unBoardId);
    
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
	EErrCode DoDirectRead(unsigned int unBarIndex, unsigned int unOffset, unsigned int unDwordsCount, unsigned long * pulBuffer, unsigned int unBoardId );
    
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
	EErrCode DoDirectWrite(unsigned int unBarIndex, unsigned int unOffset, unsigned int unDwordsCount, unsigned long* pulBuffer, unsigned int unBoardId );
    
     	///////////////////////////////////////////////////////////////////////////
	// SetMaxReadReq
	// ///////////////////////////////////////////////////////////////////////////
	// Description : Set the Max Read Request parameter for a channel
	// Return:	  0 on success or an error code
	// Arguments:    unsigned int max_req - Max Read Request
	// ///////////////////////////////////////////////////////////////////////////
	EErrCode SetMaxReadReq(EDmaChannel eDma, unsigned int unBoardId, unsigned int max_req);
    
    
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
    EErrCode DoSGDma(SDmaBuffer* psDmaBuffer, unsigned int unByteCount, EDmaChannel eDma, unsigned int unBoardId );
    
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
    //## operation LockSGDmaBuffer(SDmaBuffer*)
    EErrCode LockSGDmaBuffer(SDmaBuffer* psDmaBuffer);


    // ///////////////////////////////////////////////////////////////////////////
    // UnLockDirectDmaBuffer
    // ///////////////////////////////////////////////////////////////////////////
    // Description : UnLock physical address after DMA SG transaction
    // Return type : EErrCode - eDmaIsNotBusy - if the DMA channel was already released
    //                          eFinishedSuccessfully - otherwise
    // Arguments:    SDmaBuffer* psDmaBuffer - this struct contains the buffer for the transaction (read from /write to)    
    //                  and the internal meta-data for dma transaction.
    // ///////////////////////////////////////////////////////////////////////////
    //## operation UnLockSGDmaBuffer(SDmaBuffer* psDmaBuffer)
    EErrCode UnLockSGDmaBuffer(SDmaBuffer* psDmaBuffer);

    
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
    EErrCode GetPciEHalVersion(unsigned long* pulHalVersion, unsigned long* pulHalDate);
    
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
    EErrCode GetDriverVersion(unsigned long* pulKernelDriverVersion);
    
   
    // ///////////////////////////////////////////////////////////////////////////
    // IsInitialized
    // ///////////////////////////////////////////////////////////////////////////
    // Description :  Returns true if the driver is initialized, false otherwise
    // Return type :  bool
    // Arguments    : unsigned int* puNumOfInitializedBoards - will hold number of initialized boards.
    // 
    // Note: The boards are being initialized in order of their physical location.
    // ////////////////////////////////////////////////////////////////////////////
    bool IsInitialized(unsigned int* punNumOfInitializedBoards);

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
    EErrCode GetChannelInfo(IN unsigned int unBoardId,IN EDmaChannel eDma,OUT SChannelInfo* psChannelInfo);
    
    // ///////////////////////////////////////////////////////////////////////////
    // GetBoardInfo
    // ///////////////////////////////////////////////////////////////////////////
    // Description :  return information on a specific board
    // Return type :  
    // Arguments    : unBoardId - specific board ID
    // 			psBoardInfo - return info on the board
    // Note: 
    // ////////////////////////////////////////////////////////////////////////////
    EErrCode	GetBoardInfo(IN unsigned int unBoardId, OUT SBoardInfo* psBoardInfo);
  
    // ///////////////////////////////////////////////////////////////////////////
    // RegisterInterruptHanlder
    // ///////////////////////////////////////////////////////////////////////////
    // Description	: For a specific user interrupt, attaches its handler
    // Return type	: EErrCode
    // Arguments    :unsigned int iIndex - interrupt index
    //               pfnInterruptCallback pCallback - interrupt handler function pointer
    //               unsigned long nBoardId - The board-id. default value 
    // ////////////////////////////////////////////////////////////////////////////////////
    EErrCode RegisterInterruptHandler(unsigned int unIndex, pfnInterruptCallback pCallback, unsigned int unBoardId);
    
   
    // // ///////////////////////////////////////////////////////////////////////////
    // // ResetSystem
    // // ///////////////////////////////////////////////////////////////////////////
    // // Description : Performs a full reset to the firmware
    // // Return type : EErrCode
    // // Argument    : unsigned int nBoardId - The board-id. default value  
    // // ///////////////////////////////////////////////////////////////////////////
	EErrCode ResetSystem(unsigned int unBoardId);
    

    // // ///////////////////////////////////////////////////////////////////////////
    // // Send a Debug Query request to the driver
    // // ///////////////////////////////////////////////////////////////////////////
    // // Description : Performs a full reset to the firmware
    // // Return type : EErrCode
    // // Argument    : unsigned int nBoardId - The board-id. 
    // //		unsigned int DbgVal 
    // // ///////////////////////////////////////////////////////////////////////////
	EErrCode QueryDebug(unsigned int unBoardId,unsigned int unDbgVal);
    
    // ///////////////////////////////////////////////////////////////////////////
    // UnRegisterInterruptHanlder
    // ///////////////////////////////////////////////////////////////////////////
    // Description : For a specific user interrupt, remove its handler
    // Return type : EErrCode
    // Arguments    :unsigned int iIndex
    //               unsigned int iIndex nBoardId - The board-id. default value  
    // ////////////////////////////////////////////////////////////////////////////////////
    EErrCode UnRegisterInterruptHandler(unsigned int unIndex, unsigned int unBoardId );


	void dbg_dbb(unsigned int);

#ifdef __cplus_plus
}
#endif	// __cplus_plus

#endif	// PcieHal_H
