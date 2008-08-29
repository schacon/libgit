#include <stdlib.h>
#include <stdio.h>

#include "git.h"

/*
 * libgit test driver
 */
int main(int argc, char *argv[])
{
  unsigned char rawsha[20];
  char sha[41];
  char tester[] = "a600f1d158be31b96cb4502b8768b202c358ad20";

  git_setup("/tmp/gittest/.git");

  git_pack_hex(tester, rawsha);
  printf("raw: (%s)\n", rawsha);
  git_unpack_hex(rawsha, sha);
  printf("sha: (%s)\n", sha);
  return 0;
}
