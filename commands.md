# `sed`

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
