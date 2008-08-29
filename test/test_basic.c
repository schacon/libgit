/* file minunit_basic.c */

#include <stdio.h>
#include "minunit.h"
#include "../src/git.h"

int tests_run = 0;

/* TESTS */

static char * test_git_version() {
  mu_assert("libGit version not returned", libgit_version() == "0.1");
  return 0;
}

static char * test_git_setup() {
  git_setup("/tmp/git.git");
  mu_assert("git setup failed", get_git_repo_dir() == "/tmp/git.git");
  return 0;
}

static char * test_loose_path_from_sha() {
  git_setup("/tmp/git.git");
  mu_assert("git loose sha failed", \
	    strcmp(git_loose_path_from_sha("34197fb6abac000a2af7482f4876de45ba33d1f0"), "/tmp/git.git/objects/34/197fb6abac000a2af7482f4876de45ba33d1f0") == 0);
  return 0;
}

static char * test_pack_unpack_sha() {
  unsigned char rawsha[20];
  char sha[41];
  char tester[] = "a600f1d158be31b96cb4502b8768b202c358ad20";

  git_pack_hex(tester, rawsha);
  git_unpack_hex(rawsha, sha);

  //printf("1: [%s]\n", tester);
  //printf("2: [%s]\n", sha);

  mu_assert("git pack/unpack sha failed", strcmp(sha, tester) == 0);
  return 0;
}

/* TEST RUNNING STUFF */

static char * all_tests() {
    mu_run_test(test_git_version);
    mu_run_test(test_git_setup);
    mu_run_test(test_pack_unpack_sha);
    mu_run_test(test_loose_path_from_sha);
    return 0;
}

int main(int argc, char **argv) {
    char *result = all_tests();
    if (result != 0) {
        printf("%s\n", result);
    }
    else {
        printf("ALL TESTS PASSED\n");
    }
    printf("Tests run: %d\n", tests_run);

    return result != 0;
}
