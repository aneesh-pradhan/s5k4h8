# SPDX-License-Identifier: GPL-2.0
# Out-of-tree build of the S5K4H8 sensor driver.
# In-tree builds use drivers/media/i2c/Makefile inside the kernel tree.

obj-m += s5k4h8.o

KDIR ?= /lib/modules/$(shell uname -r)/build

.PHONY: all modules clean

all modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
