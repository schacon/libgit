#include <stdlib.h>
#include <stdio.h>

#include "git.h"

/*
 * libgit test driver
 */
int main(int argc, char *argv[])
{
	git_setup("/tmp/gittest/test.git");
	char *tester;
	tester = git_loose_path_from_sha("34197fb6abac000a2af7482f4876de45ba33d1f0");
	printf("test: %s\n", tester);
	return 0;
}