/*
 * libGit
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "git.h"

struct git_object {
	char	type;
	int		size;
	char	sha[40];
};
	
struct git_tree_node {
	char				mode[7];
	struct git_object	*object;
	char				name[255];
};

struct git_commit_data {
	char				*author_name;
	int					author_date;
	char				*committer_name;
	int					committer_date;
	struct git_object	*tree;
	struct git_parent	*parent;
	char				*message;
};

struct git_parent {
	struct git_object	*object;
	struct git_parent	*parent;
};
	
static const char *git_repo_dir;

/*
 * sets up git environment for the rest of the methods
 */
void git_setup(char *git_directory)
{
	git_repo_dir = git_directory;
}

/*
 * return git_object struct of object pointed to by sha
 */
struct git_object git_get_object(char *sha)
{
	struct git_object object;
	strcpy(object.sha, sha);
	return object;
}

char *git_get_contents(struct git_object obj)
{
	return "contents";
}

/*
 * return version of libgit
 */
char *libgit_version()
{
  return LIBGIT_VERSION;
}

/*
 * return git repository directory
 */
const char *get_git_repo_dir()
{
  return git_repo_dir;
}