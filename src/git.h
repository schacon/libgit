#define LIBGIT_VERSION "0.1"

#define NULL_SHA = '0000000000000000000000000000000000000000'

#define OBJ_NONE = 0
#define OBJ_COMMIT = 1
#define OBJ_TREE = 2
#define OBJ_BLOB = 3
#define OBJ_TAG = 4
#define OBJ_OFS_DELTA = 6
#define OBJ_REF_DELTA = 7


typedef struct {
  char	        type;
  int		size;
  unsigned char	rawsha[20];
} git_object;
	
typedef struct {
  char		      mode[7];
  struct git_object  *object;
  char		      name[255];
} git_tree_node;

typedef struct {
  char		     *author_name;
  int		      author_date;
  char		     *committer_name;
  int                 committer_date;
  struct git_object  *tree;
  struct git_parent  *parent;
  char		     *message;
} git_commit_data;

typedef struct {
  struct git_object  *object;
  struct git_parent  *parent;
} git_parent;


void git_setup(char *git_directory);

git_object git_object_from_sha(char *sha1);

int git_object_is_loose(char *sha);

char *git_loose_path_from_sha(char *sha1);

char *git_get_contents(git_object obj);

char *libgit_version();

char *get_git_repo_dir();

int git_unpack_hex(const unsigned char *rawsha, char *sha1);

int git_pack_hex(const char *sha1, unsigned char *rawsha);

int is_alpha(unsigned char n);
