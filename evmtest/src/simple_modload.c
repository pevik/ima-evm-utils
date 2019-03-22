/* SPDX-License-Identifier: GPL-2.0 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syscall.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>

/*
 * finit_module - load a kernel module using the finit_module syscall
 * @fd: File Descriptor of the kernel module to be loaded
 */
int finit_module(int fd)
{
	return syscall(__NR_finit_module, fd,
			"evmtest_load_type=finit_module", 0);
}

/*
 * init_module - load a kernel module using the init_module syscall
 * @fd: File Descriptor of the kernel module to be loaded
 *
 * Adapted explanation from: https://github.com/cirosantilli/
 * linux-kernel-module-cheat/blob/
 * 91583552ba2c2d547c8577ac888ab9f851642b25/kernel_module/user/
 * myinsmod.c
 */
int init_module(int fd)
{

	struct stat st;

	int mod = fstat(fd, &st);

	if (mod != 0) {
		printf("[!] Failed to load module\n");
		return -1;
	}

	size_t im_size = st.st_size;
	void *im = malloc(im_size);

	if (im == NULL) {
		printf("[!] Failed to load module - MALLOC NULL\n");
		return -1;
	}
	read(fd, im, im_size);
	close(fd);

	int loaded = syscall(__NR_init_module, im, im_size,
			     "evmtest_load_type=init_module");
	free(im);

	return loaded;
}

/*
 * usage - print out a help message to the user
 */
void usage(void)
{
	printf("Usage: simple_modload <-p pathname> <-o | -n>\n");
	printf("	-p,--path	pathname of kernel module\n");
	printf("	-o,--old	old syscall (INIT_MODULE)\n");
	printf("	-n,--new	new syscall (FINIT_MODULE)\n");
}

int main(int argc, char **argv)
{

	int ret;
	int uid = getuid();
	char * path;
	char old = 0;
	char new = 0;

	// For getopt
	char * opt_path = 0;
	int next;

	const char * const short_opts = "p:on";
	const struct option long_opts[] =
		{
			{ "path", 1, NULL, 'p' },
			{ "old", 0, NULL, 'o' },
			{ "new", 0, NULL, 'n' },
			{ NULL, 0, NULL, 0 }
		};

	while (1) {
		next = getopt_long(argc, argv, short_opts, long_opts, NULL);

		if (next == -1) {
			break;
		}

		switch (next) {
			case 'p' :
				opt_path=optarg;
				int size = strlen(opt_path) + 1;
				path=(char *)malloc(sizeof(char) * size);
				strcpy(path,opt_path);
				break;

			case 'o' :
				old = 1;
				break;

			case 'n' :
				new = 1;
				break;

			case '?' :
			case -1 :
				break;

			default :
				return -1;
		}
	}

	if ( (old && new) || !(old || new) || path == NULL) {
		usage();
		return -1;
	}

	/* Root is required to try and load kernel modules */
	if (uid != 0) {
		printf("[!] simple_modload must be run as root\n");
		return -1;
	}

	int fd = open(path, O_RDONLY);
	if (fd == -1) {
		printf("[!] Could not open file for read.\n");
		return -1;
	}

	if (old == 1) {
		ret = init_module(fd);
	} else {
		ret = finit_module(fd);
	}

	return ret;
}
