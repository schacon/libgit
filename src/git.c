/*
 * libGit
 */

#define LIBGIT_VERSION "0.1"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "git.h"

static const char *git_repo_dir;

/*
 * sets up git environment for the rest of the methods
 */
static void git_setup(char *git_directory)
{
	git_repo_dir = git_directory;
}


/*
 * return version
 */
char *libgit_version()
{
  return LIBGIT_VERSION;
}


/*
 * libgit test driver
 */
int main(int argc, char *argv[])
{
	git_setup(".git");
	fprintf(stderr, "gd: %s\n", git_repo_dir);
}