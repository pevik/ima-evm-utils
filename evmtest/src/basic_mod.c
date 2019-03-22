/*
 * Basic kernel module
 *
 * Copyright (C) 2018 IBM
 */
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

/*
 * evmtest_load_type is a flag passed when loading the module, it indicates
 * which syscall is being used. It should be either init_module or finit_module
 * When loaded, evmtest_load_type is outputted to the kernel's message buffer
 */
static char *evmtest_load_type;

module_param(evmtest_load_type, charp, 000);
MODULE_PARM_DESC(evmtest_load_type, "Which syscall is loading this module.");

static int __init basic_module_init(void)
{
	printk(KERN_INFO "EVMTEST: LOADED MODULE (%s)\n", evmtest_load_type);
	return 0;
}

static void __exit basic_module_cleanup(void)
{
	printk(KERN_INFO "EVMTEST: UNLOADED MODULE (%s)\n", evmtest_load_type);
}

module_init(basic_module_init);
module_exit(basic_module_cleanup);

MODULE_AUTHOR("David Jacobson");
MODULE_DESCRIPTION("Kernel module for testing IMA signatures");
MODULE_LICENSE("GPL");
