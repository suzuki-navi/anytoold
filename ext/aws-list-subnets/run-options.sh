    if [ -e $HOME/.aws ]; then
        docker_run_options="$docker_run_options -v $HOME/.aws:$HOME/.aws"
    fi
