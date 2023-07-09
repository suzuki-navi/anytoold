
set -Ceu

for i in $(seq 100); do
    pwd=$(pwd)

    if [[ $pwd == $HOME ]]; then
        exit
    fi

    if [[ $pwd == "/" ]]; then
        exit
    fi

    if [[ -d ".git" ]]; then
        echo $pwd
        exit
    fi

    if [[ -d ".npm/.anytoold" ]]; then
        echo $pwd
        exit
    fi

    if [[ -d ".venv/.anytoold" ]]; then
        echo $pwd
        exit
    fi

    if [[ -d ".sbt-docker-cache" ]]; then
        echo $pwd
        exit
    fi

    cd ..
done

