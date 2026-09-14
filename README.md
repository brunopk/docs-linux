# Docs Linux
Practical Linux guides and documentation covering common sysadmin tasks such as networking, permissions, services, and virtualization.

## `sed`

Example of how to use `sed` for string replacing into a function :

```bash
sed_replace() {
  local search="$1"
  local replace="$2"
  local file="$3"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD sed needs -i '')
    sed -i '' "s|$search|$replace|" "$file"
  else
    # Linux (GNU sed)
    sed -i "s|$search|$replace|" "$file"
  fi
}

sed_replace "ARG DB_USER=your_user" "ARG DB_USER=$DB_USER" build/Dockerfile
```

## `rsync`

For all the examples below, asume there exist src (source) and dest (destination) folders.

**Example 1**

```
rsync --recursive --delete src dest
```

`--delete`: to delete files/folders which exist in dest/ but don't exist in src/ 

**Example 2**


```
rsync --recursive --delete src/ dest
```

Same as 1 but without creating dest/src/ folder (just copying src content to dest):

**Example 3**

```
$ rsync -aP --delete src/ dest
```

`-a`: archive mode, which is necessary for rsync to identify modified files requiring copying.

`-P`: show progress.

**Example 4**

Over SSH and using custom keys ($HOME/.ssh/somekey):

```
rsync -Pav -e "ssh -i $HOME/.ssh/somekey" username@hostname:/from/dir/ /to/dir/
```

`-P`: show progress.

`-v`: verbosity.


**Example 5**

```
rsync --recursive \
  --progress \
  --archive \
  --exclude-from=.gitignore \
  --exclude=.git \
  --exclude=.gitignore \
   folder user@ipaddress:~/dest/
```

Similar to previous examples to copy over SSH.

`--exclude-from`: receives a file path with a format similar to CVS ignore files, such as the .gitignore file in Git, to indicate which files and directories should be excluded.

`--exclude`: indicates a folder or file to exclude.

**More information**

- [Specify identity file (id_rsa) with rsync](https://unix.stackexchange.com/questions/127352/specify-identity-file-id-rsa-with-rsync)
- [Rsync man](https://download.samba.org/pub/rsync/rsync.1)

## `date`

Get an UTC date in ISO format :

```
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

## `dd`

With progress

```bash
dd if=/path/to/input of=/path/to/output status=progress
```

Without copying errors (blocks with errors will be copied as 0s)

```
dd if=/path/to/input of=/path/to/output conv=noerrors
```
## `du`

List folders inside a specific directory, sorted biggest → smallest

```
du -h --max-depth=1 /path/to/folder | sort -hr
```
