# bash completion for lilhomie
# Install: source this file in your ~/.bashrc or ~/.bash_profile
#   echo 'source /usr/local/share/lilhomie/completions/lilhomie.bash' >> ~/.bashrc
#
# Or copy to the bash_completion.d directory:
#   sudo cp lilhomie.bash /etc/bash_completion.d/lilhomie

_lilhomie_completions() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    }

    local commands="list ls devices scenes status get toggle on off set scene info status-all help"
    local global_flags="--json -j --help -h"

    # First argument: complete subcommands
    if [[ "${COMP_CWORD}" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands} ${global_flags}" -- "${cur}") )
        return 0
    fi

    local cmd="${COMP_WORDS[1]}"

    # After a subcommand, offer --json / -j (and -h / --help)
    case "${cmd}" in
        list|ls|devices|scenes|info|status-all)
            COMPREPLY=( $(compgen -W "--json -j --help -h" -- "${cur}") )
            ;;
        status|get|toggle|on|off|set|scene)
            # Offer flag completions alongside any in-progress text
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=( $(compgen -W "--json -j --help -h" -- "${cur}") )
            fi
            ;;
    esac

    return 0
}

complete -F _lilhomie_completions lilhomie
