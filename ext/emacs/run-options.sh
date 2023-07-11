if [ -e $HOME/.emacs ]; then
    docker_run_options="$docker_run_options -v $HOME/.emacs:$HOME/.emacs"
fi
if [ -e $HOME/.emacs.d ]; then
    docker_run_options="$docker_run_options -v $HOME/.emacs.d:$HOME/.emacs.d"
fi
