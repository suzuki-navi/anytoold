set -Ceu

function error {
  echo "$1" >&2
  exit 1
}

JAVA_VERSION=
SCALA_VERSION=

rebuild=
build_opts=()
run_opts=()

while [ "$#" != 0 ]; do
    case $1 in
        --java    ) build_opts+=($1); shift; build_opts+=($1); JAVA_VERSION=$1;;
        --scala   ) build_opts+=($1); shift; build_opts+=($1); SCALA_VERSION=$1;;
        --rebuild ) rebuild=1;;
        --        ) shift; run_opts+=($@); break;;
        -* | --*  ) error "$1 : Illegal option" ;;
        *         ) run_opts+=($@); break;;
    esac
    shift
done

docker_image_name=anytoold

if [ -z "$JAVA_VERSION" ] && [ -n "$SCALA_VERSION" ]; then
    JAVA_VERSION=17.0.7
fi

if [ -n "$JAVA_VERSION" ]; then
    docker_image_name="${docker_image_name}-java${JAVA_VERSION}"
fi

if [ -n "$SCALA_VERSION" ]; then
    docker_image_name="${docker_image_name}-scala${SCALA_VERSION}"
fi

# If the specified Docker image has not been built yet
if [ -n "$rebuild" ] || [ -z "$(docker images -q $docker_image_name)" ]; then
    (
        mkdir -p var/$docker_image_name

        (
            cat Dockerfile
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
            echo "COPY entrypoint.sh /usr/local/entrypoint.sh"
        ) >| var/$docker_image_name/Dockerfile

        cp entrypoint.sh var/$docker_image_name/

        cd var/$docker_image_name/
        docker build -t $docker_image_name .
    )
fi

# To inherit the user ID and group ID of the host inside Docker
user=$(whoami)
uid=$(id -u $user)
gid=$(id -g $user)

if [ -t 0 ] && [ -t 1 ]; then
    term_opt="-it"
else
    term_opt="-i"
fi

# directory for persistant sbt cache
#mkdir -p .sbt-docker-cache/.sbt
#mkdir -p .sbt-docker-cache/.cache

#work_dirs="-v $(pwd):$(pwd) -v $(pwd)/.sbt-docker-cache/.sbt:$HOME/.sbt -v $(pwd)/.sbt-docker-cache/.cache:$HOME/.cache"

# HOST_UID, HOST_GID, HOST_USER are referenced in entrypoint.sh
docker_run_options="$term_opt -v $(pwd):$(pwd) -e HOST_UID=$uid -e HOST_GID=$gid -e HOST_USER=$user -w $(pwd)"

docker run --rm $docker_run_options $docker_image_name bash /usr/local/entrypoint.sh "$@"

