/*
 * libGit
 */

/* NOTE : I use rawsha for the 20 char version, 
          and sha1 for the 40 char version     */

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
 */
git_object git_object_from_sha(char *sha1)
{
  git_object object;
  char *git_object_path;

  // check for loose, then packfile 
  if(git_object_is_loose(sha1)) {
    git_object_path = git_loose_path_from_sha(sha1);
    //strcpy(object.sha1, sha1);
  } else {
    // !! TODO - PACKFILE !!
  }
  
  return object;
}

/*
 * returns 1 if the object for this sha is loose, 0 if it is in a packfile
 */
int git_object_is_loose(char *sha1) {
  return 1;
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
 * returns readable hex version of 20-char sha binary
 */
int git_unpack_hex(const unsigned char *rawsha, char *sha1)
{
  static const char hex[] = "0123456789abcdef";
  int i;

  for (i = 0; i < 20; i++) {          
    unsigned char n = rawsha[i];
    sha1[i * 2] = hex[((n >> 4) & 15)];
    n <<= 4;
    sha1[(i * 2) + 1] = hex[((n >> 4) & 15)];
  }
  sha1[40] = 0;

  return 1;   
}

/*
 * fills 20-char sha from 40-char hex version
 */
int git_pack_hex(const char *sha1, unsigned char *rawsha)
{
  unsigned char byte = 0;
  int i, j = 0;


  for (i = 1; i <= 40; i++) {
    unsigned char n = sha1[i - 1];
    
    if(is_alpha(n)) {
      byte |= ((n & 15) + 9) & 15;
    } else {
      byte |= (n & 15);
    }
    if(i & 1) {
      byte <<= 4;
    } else {
      rawsha[j] = (byte & 0xff);
      j++;
      byte = 0;
    }
  }
  return 1;
}

 
int is_alpha(unsigned char n) 
{
  if(n <= 102 && n >= 97) {
    return 1;
  }
  return 0;
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
