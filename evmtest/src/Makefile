obj-m += basic_mod.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
	$(CC) simple_modload.c -o simple_modload
