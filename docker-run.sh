set -Ceu

function error {
  echo "$1" >&2
  exit 1
}

PYTHON_VERSION=${PYTHON_VERSION:-}
RUBY_VERSION=${RUBY_VERSION:-}
NODEJS_VERSION=${NODEJS_VERSION:-}
JAVA_VERSION=${JAVA_VERSION:-}
SCALA_VERSION=${SCALA_VERSION:-}
SBT_VERSION=${SBT_VERSION:-}
TERRAFORM_VERSION=${TERRAFORM_VERSION:-}

ANYTOOLD_EXTDIR=${ANYTOOLD_EXTDIR:-}

rebuild=
verbose=
run_opts=()

while [ "$#" != 0 ]; do
    case $1 in
        --rebuild ) rebuild=1;;
        -v        ) verbose=1;;
        --        ) shift; run_opts+=($@); break;;
        -* | --*  ) error "$1 : Illegal option" ;;
        *         ) run_opts+=($@); break;;
    esac
    shift
done

docker_image_name=anytoold

if [ -z "$JAVA_VERSION" ] && [ -n "$SBT_VERSION" ]; then
    JAVA_VERSION="*"
fi
if [ -z "$JAVA_VERSION" ] && [ -n "$SCALA_VERSION" ]; then
    JAVA_VERSION="*"
fi

if [ "$PYTHON_VERSION" = "*" ]; then
    # https://github.com/pyenv/pyenv/tree/master/plugins/python-build/share/python-build
    PYTHON_VERSION=3.11.4
fi
if [ "$RUBY_VERSION" = "*" ]; then
    # https://github.com/rbenv/ruby-build/tree/master/share/ruby-build
    RUBY_VERSION=3.2.2
fi
if [ "$NODEJS_VERSION" = "*" ]; then
    # https://nodejs.org/en/download/releases
    NODEJS_VERSION=20.4.0
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
if [ "$TERRAFORM_VERSION" = "*" ]; then
    TERRAFORM_VERSION=1.5.1
fi

if [ -n "$PYTHON_VERSION" ]; then
    docker_image_name="${docker_image_name}-python-${PYTHON_VERSION}"
fi
if [ -n "$RUBY_VERSION" ]; then
    docker_image_name="${docker_image_name}-ruby-${RUBY_VERSION}"
fi
if [ -n "$NODEJS_VERSION" ]; then
    docker_image_name="${docker_image_name}-nodejs-${NODEJS_VERSION}"
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
if [ -n "$TERRAFORM_VERSION" ]; then
    docker_image_name="${docker_image_name}-terraform-${TERRAFORM_VERSION}"
fi
if [ -n "$ANYTOOLD_EXTDIR" ]; then
    docker_image_name="${docker_image_name}-$(basename $ANYTOOLD_EXTDIR)"
fi

(
    cd $(dirname $0)

    mkdir -p var/$docker_image_name

    (
        cat Dockerfile
        if [ -n "$PYTHON_VERSION" ] || [ -n "$RUBY_VERSION" ] || [ -n "$TERRAFORM_VERSION" ]; then
            cat Dockerfile-build-common
        fi
        if [ -n "$PYTHON_VERSION" ]; then
            PYTHON_VERSION_2=${PYTHON_VERSION%%[a-z]*}
            echo "ARG PYTHON_VERSION=$PYTHON_VERSION"
            echo "ARG PYTHON_VERSION_2=$PYTHON_VERSION_2"
            cat Dockerfile-python
        fi

        if [ -n "$RUBY_VERSION" ]; then
            echo "ARG RUBY_VERSION=$RUBY_VERSION"
            cat Dockerfile-ruby
        fi

        if [ -n "$NODEJS_VERSION" ]; then
            echo "ARG NODEJS_VERSION=$NODEJS_VERSION"
            cat Dockerfile-nodejs
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

        if [ -n "$TERRAFORM_VERSION" ]; then
            echo "ARG TERRAFORM_VERSION=$TERRAFORM_VERSION"
            cat Dockerfile-terraform
        fi

        if [ -n "$ANYTOOLD_EXTDIR" ]; then
            if [ -e $ANYTOOLD_EXTDIR/Dockerfile ]; then
                cat $ANYTOOLD_EXTDIR/Dockerfile
            fi
        fi

        echo "COPY entrypoint.sh /usr/local/entrypoint.sh"
    ) >| var/$docker_image_name/Dockerfile

    cp entrypoint.sh var/$docker_image_name/

    if [ -n "$ANYTOOLD_EXTDIR" ]; then
        for f in $(ls $ANYTOOLD_EXTDIR | grep -v Dockerfile); do
            if [ ! -e var/$docker_image_name/$f ] || ! diff $ANYTOOLD_EXTDIR/$f var/$docker_image_name/$f >/dev/null; then
                cp $ANYTOOLD_EXTDIR/$f var/$docker_image_name/$f
            fi
        done
    fi

    (
        cd var/$docker_image_name/
        cat $(ls) | sha256sum | cut -b-64
    ) >| var/$docker_image_name.hash.new

    # If the specified Docker image has not been built yet
    if [ -z "$(docker images -q $docker_image_name)" ] || [ ! -e var/$docker_image_name.hash ] || ! diff var/$docker_image_name.hash var/$docker_image_name.hash.new >/dev/null; then
        (
            cd var/$docker_image_name/
            echo docker build -t $docker_image_name .
            docker build -t $docker_image_name .
        )
        mv var/$docker_image_name.hash.new var/$docker_image_name.hash
    else
        rm var/$docker_image_name.hash.new
    fi
) >&2

project_home=$(
    bash $(dirname $0)/search-project-home-dir.sh
)

# To inherit the user ID and group ID of the host inside Docker
user=$(whoami)
uid=$(id -u $user)
gid=$(id -g $user)

if [ -t 0 ] && [ -t 1 ]; then
    term_opt="-it"
else
    term_opt="-i"
fi

docker_run_options=()

docker_run_options+=("$term_opt")
docker_run_options+=("-v")
if [ -n "$project_home" ]; then
    docker_run_options+=("$project_home:$project_home")
else
    docker_run_options+=("$(pwd):$(pwd)")
fi
docker_run_options+=("-w")
docker_run_options+=("$(pwd)")

# HOST_UID, HOST_GID, HOST_USER are referenced in entrypoint.sh
docker_run_options+=("-e")
docker_run_options+=("HOST_UID=$uid")
docker_run_options+=("-e")
docker_run_options+=("HOST_GID=$gid")
docker_run_options+=("-e")
docker_run_options+=("HOST_USER=$user")

if [ -n "${PORT:-}" ]; then
    docker_run_options+=("-p")
    docker_run_options+=("$PORT:$PORT")
fi


if [ -n "$TERRAFORM_VERSION" ]; then
    if [ -e $HOME/.aws ]; then
        docker_run_options+=("-v")
        docker_run_options+=("$HOME/.aws:$HOME/.aws")
    fi
fi

if [ -n "$project_home" ]; then
    # for npx
    if [ -n "$NODEJS_VERSION" ]; then
        mkdir -p $project_home/.npm/.anytoold
        docker_run_options+=("-v")
        docker_run_options+=("$project_home/.npm/.anytoold:$HOME/.npm")
    fi

    if [ -n "$PYTHON_VERSION" ]; then
        mkdir -p $project_home/.venv/.anytoold
        docker_run_options+=("-v")
        docker_run_options+=("$project_home/.venv/.anytoold:$HOME/.local")
        docker_run_options+=("-e")
        docker_run_options+=("PATH_EXT=$HOME/.local/bin")
    fi

    # directory for persistant sbt cache
    if [ -n "$SBT_VERSION" ]; then
        mkdir -p $project_home/.sbt-docker-cache/.sbt
        mkdir -p $project_home/.sbt-docker-cache/.cache
        docker_run_options+=("-v")
        docker_run_options+=("$project_home/.sbt-docker-cache/.sbt:$HOME/.sbt")
        docker_run_options+=("-v")
        docker_run_options+=("$project_home/.sbt-docker-cache/.cache:$HOME/.cache")
    fi
fi

if [ -n "$ANYTOOLD_EXTDIR" ]; then
    if [ -e $ANYTOOLD_EXTDIR/run-options.sh ]; then
        . $ANYTOOLD_EXTDIR/run-options.sh
    fi
fi

if [ -n "$verbose" ]; then
    echo docker run --rm ${docker_run_options[@]} $docker_image_name bash /usr/local/entrypoint.sh "$@"
fi

docker run --rm "${docker_run_options[@]}" $docker_image_name bash /usr/local/entrypoint.sh "$@"

