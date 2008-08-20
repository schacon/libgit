#define LIBGIT_VERSION "0.1"

#define NULL_SHA = '0000000000000000000000000000000000000000'

#define OBJ_NONE = 0
#define OBJ_COMMIT = 1
#define OBJ_TREE = 2
#define OBJ_BLOB = 3
#define OBJ_TAG = 4
#define OBJ_OFS_DELTA = 6
#define OBJ_REF_DELTA = 7

void git_setup(char *git_directory);

struct git_object git_get_object(char *sha);

char *git_get_contents(struct git_object obj);

char *libgit_version();

const char *get_git_repo_dir();