set -Ceu

function error {
  echo "$1" >&2
  exit 1
}

PYTHON_VERSION=${PYTHON_VERSION:-}
PYTHON_TOOLS=${PYTHON_TOOLS:-}
RUBY_VERSION=${RUBY_VERSION:-}
RUBY_TOOLS=${RUBY_TOOLS:-}
NODEJS_VERSION=${NODEJS_VERSION:-}
NODEJS_TOOLS=${NODEJS_TOOLS:-}
JAVA_VERSION=${JAVA_VERSION:-}
SCALA_VERSION=${SCALA_VERSION:-}
SBT_VERSION=${SBT_VERSION:-}

rebuild=
run_opts=()

while [ "$#" != 0 ]; do
    case $1 in
        --rebuild ) rebuild=1;;
        --        ) shift; run_opts+=($@); break;;
        -* | --*  ) error "$1 : Illegal option" ;;
        *         ) run_opts+=($@); break;;
    esac
    shift
done

docker_image_name=anytoold

if [ -z "$PYTHON_VERSION" ] && [ -n "$PYTHON_TOOLS" ]; then
    PYTHON_VERSION="*"
fi
if [ -z "$RUBY_VERSION" ] && [ -n "$RUBY_TOOLS" ]; then
    RUBY_VERSION="*"
fi
if [ -z "$NODEJS_VERSION" ] && [ -n "$NODEJS_TOOLS" ]; then
    NODEJS_VERSION="*"
fi
if [ -z "$JAVA_VERSION" ] && [ -n "$SBT_VERSION" ]; then
    JAVA_VERSION="*"
fi
if [ -z "$JAVA_VERSION" ] && [ -n "$SCALA_VERSION" ]; then
    JAVA_VERSION="*"
fi

if [ "$PYTHON_VERSION" = "*" ]; then
    PYTHON_VERSION=3.11.4
fi
if [ "$RUBY_VERSION" = "*" ]; then
    RUBY_VERSION=3.2.2
fi
if [ "$NODEJS_VERSION" = "*" ]; then
    NODEJS_VERSION=20.3.1
fi
if [ "$JAVA_VERSION" = "*" ]; then
    JAVA_VERSION=17.0.7
fi
if [ "$SCALA_VERSION" = "*" ]; then
    SCALA_VERSION=3.3.0
fi
if [ "$SBT_VERSION" = "*" ]; then
    SBT_VERSION=1.9.0
fi

if [ -n "$PYTHON_VERSION" ]; then
    docker_image_name="${docker_image_name}-python-${PYTHON_VERSION}"
fi
if [ -n "$PYTHON_TOOLS" ]; then
    docker_image_name="${docker_image_name}-python-tools"
fi
if [ -n "$RUBY_VERSION" ]; then
    docker_image_name="${docker_image_name}-ruby-${RUBY_VERSION}"
fi
if [ -n "$RUBY_TOOLS" ]; then
    docker_image_name="${docker_image_name}-ruby-tools"
fi
if [ -n "$NODEJS_VERSION" ]; then
    docker_image_name="${docker_image_name}-nodejs-${NODEJS_VERSION}"
fi
if [ -n "$NODEJS_TOOLS" ]; then
    docker_image_name="${docker_image_name}-nodejs-tools"
fi
if [ -n "$JAVA_VERSION" ]; then
    docker_image_name="${docker_image_name}-java-${JAVA_VERSION}"
fi
if [ -n "$SCALA_VERSION" ]; then
    docker_image_name="${docker_image_name}-scala-${SCALA_VERSION}"
fi
if [ -n "$SBT_VERSION" ]; then
    docker_image_name="${docker_image_name}-sbt-${SBT_VERSION}"
fi

# If the specified Docker image has not been built yet
(
    cd $(dirname $0)

    mkdir -p var/$docker_image_name

    (
        cat Dockerfile
        if [ -n "$PYTHON_VERSION" ] || [ -n "$RUBY_VERSION" ]; then
            cat Dockerfile-common
        fi
        if [ -n "$PYTHON_VERSION" ]; then
            PYTHON_VERSION_2=${PYTHON_VERSION%%[a-z]*}
            echo "ARG PYTHON_VERSION=$PYTHON_VERSION"
            echo "ARG PYTHON_VERSION_2=$PYTHON_VERSION_2"
            cat Dockerfile-python
        fi

        if [ -n "$PYTHON_TOOLS" ]; then
            cp etc/localserver.py var/$docker_image_name/
            cat Dockerfile-python-tools
        fi

        if [ -n "$RUBY_VERSION" ]; then
            echo "ARG RUBY_VERSION=$RUBY_VERSION"
            cat Dockerfile-ruby
        fi

        if [ -n "$RUBY_TOOLS" ]; then
            cat Dockerfile-ruby-tools
        fi

        if [ -n "$NODEJS_VERSION" ]; then
            echo "ARG NODEJS_VERSION=$NODEJS_VERSION"
            cat Dockerfile-nodejs
        fi

        if [ -n "$NODEJS_TOOLS" ]; then
            cat Dockerfile-nodejs-tools
        fi

        if [ -n "$JAVA_VERSION" ]; then
            JAVA_VERSION_MAJOR=${JAVA_VERSION%%.*}
            echo "ARG JAVA_VERSION=$JAVA_VERSION"
            echo "ARG JAVA_VERSION_MAJOR=$JAVA_VERSION_MAJOR"
            cat Dockerfile-java
        fi
        if [ -n "$SCALA_VERSION" ]; then
            echo "ARG SCALA_VERSION=$SCALA_VERSION"
            cat Dockerfile-scala
        fi
        if [ -n "$SBT_VERSION" ]; then
            echo "ARG SBT_VERSION=$SBT_VERSION"
            cat Dockerfile-sbt
        fi

        echo "COPY entrypoint.sh /usr/local/entrypoint.sh"
    ) >| var/$docker_image_name/Dockerfile

    cp entrypoint.sh var/$docker_image_name/

    (
        cd var/$docker_image_name/
        cat $(ls) | sha256sum | cut -b-64
    ) >| var/$docker_image_name.hash.new

    if [ -z "$(docker images -q $docker_image_name)" ] || [ ! -e var/$docker_image_name.hash ] || ! diff var/$docker_image_name.hash var/$docker_image_name.hash.new >/dev/null; then
        (
            cd var/$docker_image_name/
            echo docker build -t $docker_image_name .
            docker build -t $docker_image_name .
        )
        mv var/$docker_image_name.hash.new var/$docker_image_name.hash
    fi
) >&2

# To inherit the user ID and group ID of the host inside Docker
user=$(whoami)
uid=$(id -u $user)
gid=$(id -g $user)

if [ -t 0 ] && [ -t 1 ]; then
    term_opt="-it"
else
    term_opt="-i"
fi

docker_run_options=${docker_run_options:-}

docker_run_options="$docker_run_options $term_opt -v $(pwd):$(pwd) -w $(pwd)"

# HOST_UID, HOST_GID, HOST_USER are referenced in entrypoint.sh
docker_run_options="$docker_run_options -e HOST_UID=$uid -e HOST_GID=$gid -e HOST_USER=$user"

if [ -n "$PYTHON_TOOLS" ]; then
    docker_run_options="$docker_run_options -v $HOME/.aws:$HOME/.aws"
    docker_run_options="$docker_run_options -e OPENAI_API_KEY"
fi

# directory for persistant sbt cache
if [ -n "$SBT_VERSION" ]; then
    mkdir -p .sbt-docker-cache/.sbt
    mkdir -p .sbt-docker-cache/.cache
    docker_run_options="$docker_run_options -v $(pwd)/.sbt-docker-cache/.sbt:$HOME/.sbt -v $(pwd)/.sbt-docker-cache/.cache:$HOME/.cache"
fi

docker run --rm $docker_run_options $docker_image_name bash /usr/local/entrypoint.sh "$@"

