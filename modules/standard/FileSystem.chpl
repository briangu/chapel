/*
 * Copyright 2004-2014 Cray Inc.
 * Other additional copyright holders may be indicated within.
 * 
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * 
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
use Error;

extern proc chpl_fs_chdir(name: c_string):syserr;
extern proc chpl_fs_chown(name: c_string, uid: c_int, gid: c_int):syserr;
extern proc chpl_fs_cwd(ref working_dir:c_string):syserr;
extern proc chpl_fs_is_dir(ref result:c_int, name: c_string):syserr;
extern proc chpl_fs_is_file(ref result:c_int, name: c_string):syserr;
extern proc chpl_fs_mkdir(name: c_string, mode: int, parents: bool):syserr;
extern proc chpl_fs_rename(oldname: c_string, newname: c_string):syserr;
extern proc chpl_fs_remove(name: c_string):syserr;


/* Change the current working directory of the current locale to the specified
   name. Returns any errors that occurred via an out parameter.
   err: a syserr used to indicate if an error occurred
   name: a string indicating a new directory

   Note: this is not safe within a parallel context.  A chdir call in one task
   will affect the current working directory of all tasks for that locale.
*/
proc chdir(out err: syserr, name: string) {
  err = chpl_fs_chdir(name.c_str());
}

/* Change the current working directory of the current locale to the specified
   name. Generates an error message if one occurred.
   name: a string indicating a new directory

   Note: this is not safe within a parallel context.  A chdir call in one task
   will affect the current working directory of all tasks for that locale.
*/
proc chdir(name: string) {
  var err: syserr = ENOERR;
  chdir(err, name);
  if err then ioerror(err, "in chdir", name);
}

/* Changes one or both of the owner and group id of the named file to the
   specified values.  If uid or gid are -1, the value in question will remain
   unchanged.
   err: a syserr used to indicate if an error occurred
   name: the name of the file to be changed.
   uid: user id to use as new owner, or -1 if it should remain the same.
   gid: group id to use as the new group owner, or -1 if it should remain the
        same.
*/
proc chown(out err: syserr, name: string, uid: int, gid: int) {
  err = chpl_fs_chown(name.c_str(), uid:c_int, gid:c_int);
}

/* Changes one or both of the owner and group id of the named file to the
   specified values.  If uid or gid are -1, the value in question will remain
   unchanged. Generates an error message if one occurred.
   name: the name of the file to be changed.
   uid: user id to use as new owner, or -1 if it should remain the same.
   gid: group id to use as the new group owner, or -1 if it should remain the
        same.
*/
proc chown(name: string, uid: int, gid: int) {
  var err: syserr = ENOERR;
  chown(err, name, uid, gid);
  if err then ioerror(err, "in chown", name);
}

/* Returns the current working directory for the current locale.
   err: a syserr used to indicate if an error occurred

   Note: another task on this locale can change the current working
   directory from underneath this task, so use caution when making use
   of this function in a parallel environment.
*/
proc cwd(out err: syserr): string {
  var tmp:c_string, ret:string;
  err = chpl_fs_cwd(tmp);
  if err then return "";
  ret = toString(tmp);
  chpl_free_c_string(tmp);
  return ret;
}

/* Returns the current working directory for the current locale. Generates an
   error message if one occurred.

   Note: another task on this locale can change the current working
   directory from underneath this task, so use caution when making use
   of this function in a parallel environment.
*/
proc cwd(): string {
  var err: syserr = ENOERR;
  var ret = cwd(err);
  if err then ioerror(err, "in cwd");
  return ret;
}

/* Returns true if the name corresponds to a directory, false otherwise.
   err: a syserr used to indicate if an error occurred
   name: a string that could be the name of a directory.
*/
proc isDir(out err:syserr, name:string):bool {
  var ret:c_int;
  err = chpl_fs_is_dir(ret, name.c_str());
  return ret != 0;
}

/* Returns true if the name corresponds to a directory, false otherwise.
   Generates an error message if one occurs.
   name: a string that could be the name of a directory.
*/
proc isDir(name:string):bool {
  var err:syserr;
  var ret = isDir(err, name);
  if err then ioerror(err, "in isDir", name);
  return ret;
}

/* Returns true if the name corresponds to a file, false otherwise.
   err: a syserr used to indicate if an error occurred
   name: a string that could be the name of a file.
*/
proc isFile(out err:syserr, name:string):bool {
  var ret:c_int;
  err = chpl_fs_is_file(ret, name.c_str());
  return ret != 0;
}

/* Returns true if the name corresponds to a file, false otherwise.
   Generates an error message if one occurs.
   name: a string that could be the name of a file.
*/
proc isFile(name:string):bool {
  var err:syserr;
  var ret = isFile(err, name);
  if err then ioerror(err, "in isFile", name);
  return ret;
}

/* These are constant values of the form S_I[R | W | X][USR | GRP | OTH],
   S_IRWX[U | G | O], S_ISUID, S_ISGID, or S_ISVTX, where R corresponds to
   readable, W corresponds to writable, X corresponds to executable, USR and
   U correspond to user, GRP and G correspond to group, OTH and O correspond
   to other, directly tied to the C idea of these constants.  They are intended
   for use with functions that alter the permissions of files or directories.
*/
extern const S_IRUSR: int;
extern const S_IWUSR: int;
extern const S_IXUSR: int;
extern const S_IRWXU: int;

extern const S_IRGRP: int;
extern const S_IWGRP: int;
extern const S_IXGRP: int;
extern const S_IRWXG: int;

extern const S_IROTH: int;
extern const S_IWOTH: int;
extern const S_IXOTH: int;
extern const S_IRWXO: int;

extern const S_ISUID: int;
extern const S_ISGID: int;
extern const S_ISVTX: int;

/* Attempt to create a directory with the given path.  If parents is true,
   will attempt to create any directory in the path that did not previously
   exist.  Returns any errors that occurred via an out parameter
   err: a syserr used to indicate if an error occurred
   name: the name of the directory to be created, fully specified.
   mode: an integer representing the permissions desired for the file
         in question.  See description of the provided constants for potential
         values.
   parents: a boolean indicating if parent directories should be created.
            If set to false, any nonexistent parent will cause an error to
            occur.

   Important note: In the case where parents is true, there is a potential
   security vulnerability.  The existence of each parent directory is checked
   before attempting to create it, and it is possible for an attacker to create
   the directory in between the check and the intentional creation.  If this
   should occur, an error about creating a directory that already exists will
   be stored in err.
*/
proc mkdir(out err: syserr, name: string, mode: int = 0o777,
           parents: bool=false) {
  err = chpl_fs_mkdir(name.c_str(), mode, parents);
}

/* Attempt to create a directory with the given path.  If parents is true,
   will attempt to create any directory in the path that did not previously
   exist.  Generates an error message if one occurred.
   name: the name of the directory to be created, fully specified.
   mode: an integer representing the permissions desired for the file
         in question.  See description of the provided constants for potential
         values.
   parents: a boolean indicating if parent directories should be created.
            If set to false, any nonexistent parent will cause an error to
            occur.

   Important note: In the case where parents is true, there is a potential
   security vulnerability.  The existence of each parent directory is checked
   before attempting to create it, and it is possible for an attacker to create
   the directory in between the check and the intentional creation.  If this
   should occur, an error message about creating a directory that already exists
   will be generated.
*/
proc mkdir(name: string, mode: int = 0o777, parents: bool=false) {
  var err: syserr = ENOERR;
  mkdir(err, name, mode, parents);
  if err then ioerror(err, "in mkdir", name);
}

/* Renames the file specified by oldname to newname, returning an error
   if one occurred.  The file is not opened during this operation.
   error: a syserr used to indicate if an error occurred during renaming.
   oldname: current name of the file
   newname: name which should refer to the file in the future.*/
proc rename(out error: syserr, oldname, newname: string) {
  error = chpl_fs_rename(oldname.c_str(), newname.c_str());
}

/* Renames the file specified by oldname to newname, generating an error message
   if one occurred.  The file is not opened during this operation.
   oldname: current name of the file
   newname: name which should refer to the file in the future.*/
proc rename(oldname, newname: string) {
  var err:syserr = ENOERR;
  rename(err, oldname, newname);
  if err then ioerror(err, "in rename", oldname);
}

/* Removes the file or directory specified by name, returning an error
   if one occurred via an out parameter.
   err: a syserr used to indicate if an error occurred during removal
   name: the name of the file/directory to remove */
proc remove(out err: syserr, name: string) {
  err = chpl_fs_remove(name.c_str());
}

/* Removes the file or directory specified by name, generating an error message
   if one occurred.
   name: the name of the file/directory to remove */
proc remove(name: string) {
  var err:syserr = ENOERR;
  remove(err, name);
  if err then ioerror(err, "in remove", name);
}