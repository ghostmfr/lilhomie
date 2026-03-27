# bash completion for lilhomie
# Install: source this file in your ~/.bashrc or ~/.bash_profile
#   echo 'source ~/.config/lilhomie/completions/lilhomie.bash' >> ~/.bashrc
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

    # First argument: complete subcommands and global flags
    if [[ "${COMP_CWORD}" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands} ${global_flags}" -- "${cur}") )
        return 0
    fi

    # Find the subcommand (first non-flag word after 'lilhomie')
    local cmd=""
    local i
    for (( i=1; i < COMP_CWORD; i++ )); do
        local word="${COMP_WORDS[i]}"
        case "${word}" in
            --json|-j|--help|-h) continue ;;
            *) cmd="${word}"; break ;;
        esac
    done

    # After a subcommand, offer --json / -j (and -h / --help)
    case "${cmd}" in
        list|ls|devices|scenes|info|status-all)
            COMPREPLY=( $(compgen -W "--json -j --help -h" -- "${cur}") )
            ;;
        status|get|toggle|on|off|scene)
            # Device/scene name argument — offer flags if current word starts with '-'
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=( $(compgen -W "--json -j --help -h" -- "${cur}") )
            fi
            # Multi-word device names are handled by the user quoting the argument;
            # no static list to complete against without querying the live API.
            ;;
        set)
            # Last positional is the brightness level; second-to-last is device name.
            # Offer brightness values once the device name token is already present.
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=( $(compgen -W "--json -j --help -h" -- "${cur}") )
            else
                # Count non-flag words after the subcommand
                local positionals=0
                for (( i=2; i < COMP_CWORD; i++ )); do
                    [[ "${COMP_WORDS[i]}" == -* ]] || (( positionals++ ))
                done
                if (( positionals >= 1 )); then
                    # At least device name present — complete brightness
                    COMPREPLY=( $(compgen -W "0 10 20 25 30 40 50 60 70 75 80 90 100" -- "${cur}") )
                fi
            fi
            ;;
        *)
            COMPREPLY=( $(compgen -W "${commands} ${global_flags}" -- "${cur}") )
            ;;
    esac

    return 0
}

complete -F _lilhomie_completions lilhomie
