
obj-m += conspciv3.o
conspciv3-objs += ccons_pci.o

build:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

load_man:
	#sudo cp -v 10-ccons_pci.rules /etc/udev/rules.d
	sudo insmod ./conspciv3.ko

unload_man:
	#sudo rm -v  /etc/udev/rules.d/10-ccons_pci.rules
	sudo rmmod ./conspciv3.ko

install:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
	sudo -- bash -c 'echo conspciv3 >> /etc/modules'	
	sudo cp conspciv3.ko /lib/modules/`uname -r`/kernel/drivers/pci
	sudo cp -v 10-ccons_pci.rules /etc/udev/rules.d
	sudo depmod
	reboot

uninstall:
	sudo sed -i "/conspciv3/d" /etc/modules	
	sudo rm /lib/modules/`uname -r`/kernel/drivers/pci/conspciv3.ko
	sudo rm /etc/udev/rules.d/10-ccons_pci.rules
	reboot
	
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

