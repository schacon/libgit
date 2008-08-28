/*
 * libGit
 */

/* NOTE : I use rawsha for the 20 char version, and sha1 for the 40 char version */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "git.h"

static char *git_repo_dir;

/*
 * sets up git environment for the rest of the methods
 */
void git_setup(char *git_directory)
{
	git_repo_dir = git_directory;
}

/*
 * return git_object struct of object pointed to by sha
git_object git_get_object(char *sha)
{
	git_object object;
	//strcpy(object.sha, sha);
	return object;
}
*/

char *git_get_contents(git_object obj)
{
	return "contents";
}

char *git_loose_path_from_sha(char *sha1)
{
	int len = strlen(git_repo_dir);
	char *file_path;
	file_path = (char *) malloc(len + 51); // sha + 'objects' + three '/'s + null byte
	memcpy(file_path, git_repo_dir, len);	
	memcpy(file_path + len, "/objects/", 9);
	memcpy(file_path + len + 9, sha1, 2);
	memcpy(file_path + len + 12, sha1 + 2, 38);
	file_path[len + 11] = '/';
	file_path[len + 50] = 0;
	return file_path;
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
char *get_git_repo_dir()
{
  return git_repo_dir;
}