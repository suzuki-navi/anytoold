set -Ceu

# The first script to be executed inside Docker

# thanks to
# https://qiita.com/kawaz/items/f8d68f11d31aa3ea3d1c
sh-escape() {
  local s a=() q="'" qq='"'
  for s in "$@"; do
    a+=("'${s//$q/$q$qq$q$qq$q}'")
  done
  echo "${a[*]}"
}

command="$(sh-escape "$@")"

HOST_UID=${HOST_UID:-0}
HOST_GID=${HOST_GID:-0}
HOST_USER=${HOST_USER:-}

# Create a user with the same UID and GID as the user running on the host side
groupadd -g $HOST_GID -o $HOST_USER
useradd  -u $HOST_UID -g $HOST_GID -o $HOST_USER
usermod -aG sudo $HOST_USER
export HOME=/home/$HOST_USER
chown $HOST_USER $HOME

# Execute sbt command or other specified command
if [ -z "$command" ]; then
    exec su $HOST_USER -c sbt
elif [ -t 1 ]; then
    exec su -P $HOST_USER -c "$command"
else
    exec su $HOST_USER -c "$command"
fi

