
#ifndef __con_pcie_dma_h__
#define __con_pcie_dma_h__

struct buffer_descriptor;


struct dma_channel_descriptor
{
	int fd;
	io_context_t ctx;
	int efd;
	bool is_read;
	int id;
	bool is_active;
	pthread_t io_thread;
	
	struct dma_channel_descriptor * next;
};

//--------------------------- Registers Access Functions -------------------------------------------------

/// @brief Opens a file descriptor to one of the memory bars on the device
/// @param [in] device_id The devie number
/// @param [in] device_id The devie number
/// @param [in] bar number 0...6 (depending on the number of bars implemented and addressing 32 or 64 bit)
/// @return file descriptor on success, -1 on error 
int pcieio_open_bar(int device_id, int bar);



/// @brief close a file descriptor opend by  pcieio_open_bar 
/// @param [in] fd, file descripto to close
/// @return zero on success and -1 on error 
int pcieio_close_bar(int fd);


/// @brief Write the data to register (used when has to be board configuration)
/// @param [in] fd, file descriptor
/// @param [in] reg_add  The address of the register
/// @param [in] value  The data to be written in register
/// @return Zero on success and -1 on error 
int pcieio_write_bar_register(int fd, uint32_t reg_addr, uint32_t value);

/// @brief Read the data from register (used when has to be board configuration)
/// @param [in] fd, file descriptor
/// @param [in] reg_add  The address of the register
/// @param [in] value  Pointer to set the data from the register
/// @return Zero on success and -1 on error 
int pcieio_read_register(int fd, uint32_t reg_add, uint32_t *value);


//------------------- DMA Functions -----------------------------------------------------------------------
/// @brief Opens a file descriptor to a dma channle
/// @param [in] device_id The devie number 
/// @param [in] chan_id The channle id 0...number of IN or OUT-1 channels
/// @param [in] chan_id max_penging_buffers
/// @param [in] is_read ture form IN channle, false for OUT channnel
/// @param [out] struct dma_channel_descriptor *dma_chan_desc
/// @return pointer to a dma_channel_descriptor success, null on error 
int pcieio_open_dma_channel(int device_id, int chan_id,
				int max_penging_buffers ,bool is_read,
				struct dma_channel_descriptor *dma_chan_desc);

/// @brief close and cleans up a dma channel opend by pcieio_open_dma_channle 
/// @param [in] fd, file descripto to close
/// @return zero on success and -1 on error 
int pcieio_close_dma_channel(struct dma_channel_descriptor *dma_chan);

/// @brief pin a buffer for DAM operation
/// @param [in] dev_id
/// @param [in] buff buffer to pin
/// @param [in] size buffer size
/// @param [in] tag for debug
/// @return pointer to a struct buffer_descriptor on success, null on error 
struct buffer_descriptor *pcieio_pin_buffer(int dev_id, void *buff, int size, bool dir,uint64_t tag);

/// @brief relese a pind buffer
/// @param [in] dev_id
/// @param [in] pbd, buffer_descriptor
/// @return Zero on success and -1 on error 
int pcieio_release_buffer(int dev_id, struct buffer_descriptor *pbd);

/// @brief Starts the operation of the DMA channel
/// @param [in] dma_chan
/// @return Zero on success and -1 on error 
int pcieio_start_channel(struct dma_channel_descriptor *dma_chan);

/// @brief Stops the operation of the DMA channel
/// @param [in] dma_chan
/// @return Zero on success and -1 on error 
int pcieio_stop_channel(struct dma_channel_descriptor *dma_chan);

/// @brief Submit a dma request 
/// @param [in] dma_chan
/// @param [in] pbd, buffer_descriptor
/// @param [in] size, number of bytes to transffer
/// @return The number off the submitted buffers
int pcieio_submit_io_request(struct dma_channel_descriptor *dma_chan, struct buffer_descriptor *pbd, int  size);

/// @brief Wait for io completion
/// @param [in] dma_chan
/// @param [in] count
/// @param [in] res
/// @return buffer descriptor
struct buffer_descriptor *pcieio_wait_for_io_completion(struct dma_channel_descriptor *dma_chan, uint64_t *count, uint64_t *res);
//-----------------------User Interrupts Functions -----------------------------------------------------------------
/// @brief returns the number of user interrtups implemented in the device 
/// @param [in] device id
/// @nuber of user interrupts on success,  -1 on error 
int pcieio_get_num_of_user_interrupts(int device);

/// @brief registers a user supplied envet on an interrtup
/// @param [in] device id
/// @param [in] interrupts id
/// @ returns the event file descriptor on success,  -1 on error 
int pcieio_register_interrupt_event(int device, int int_id);

/// @brief releases a previosly registered event
/// @param [in] device id
/// @param [in] interrupts id
/// @0 on success,  -1 on error 
int pcieio_release_interrupt_event(int device, int int_id);

//---------------------- Managment Functions -----------------------------------------------------------------------

/// @brief returns the number of  dma channels implemented in the device 
/// @param [in] device id
/// @return Zero on success and -1 on error 
int pcieio_get_num_of_dma_channels(int device);

/// @brief returns the direction of a channel by index 
/// @param [in] device id
/// @param [in] index
/// @param [out] dir
/// @return Zero on success and -1 on error 
int pcieio_get_channel_direction(int device,int index ,int *dir);


/// @brief returns the diver version 
/// @param [out] ver driver version 
/// @return Zero on success and -1 on error 
int pcieio_get_driver_version(uint32_t *ver);

/// @brief returns the fpga fw version
/// @param [in] device id
/// @param [out] ver fpga fw version 
/// @return Zero on success and -1 on error 
int pcieio_get_fpga_version(int device, uint32_t *ver);



#endif


