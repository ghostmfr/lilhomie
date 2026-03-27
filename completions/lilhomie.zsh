#compdef lilhomie
# zsh completion for lilhomie
#
# Install (pick one):
#
# Option A — copy to a directory already in your $fpath:
#   sudo cp lilhomie.zsh /usr/local/share/zsh/site-functions/_lilhomie
#
# Option B — add the completions directory to $fpath in ~/.zshrc:
#   fpath=(/usr/local/share/lilhomie/completions $fpath)
#   autoload -Uz compinit && compinit
#
# Option C — Oh-My-Zsh:
#   cp lilhomie.zsh ~/.oh-my-zsh/completions/_lilhomie

_lilhomie() {
    local -a commands global_flags

    global_flags=(
        '--json[Output raw JSON (pipe into jq, etc)]'
        '-j[Output raw JSON (alias for --json)]'
        '--help[Show help]'
        '-h[Show help (short)]'
    )

    commands=(
        'list:List all HomeKit devices grouped by room'
        'ls:Alias for list'
        'devices:Alias for list'
        'scenes:List all HomeKit scenes'
        'status:Get status of a device'
        'get:Alias for status'
        'toggle:Toggle a device on/off'
        'on:Turn a device on'
        'off:Turn a device off'
        'set:Set device brightness (0-100)'
        'scene:Trigger a scene'
        'info:Show Homie app status'
        'status-all:Alias for info'
        'help:Show help message'
    )

    # Complete the first positional argument (subcommand)
    if (( CURRENT == 2 )); then
        _describe 'command' commands
        _arguments $global_flags
        return
    fi

    # Complete flags and arguments for each subcommand
    local cmd="${words[2]}"
    case "${cmd}" in
        list|ls|devices|scenes|info|status-all|help)
            _arguments $global_flags
            ;;
        status|get)
            _arguments \
                $global_flags \
                ':device name: '
            ;;
        toggle|on|off)
            _arguments \
                $global_flags \
                ':device name: '
            ;;
        set)
            _arguments \
                $global_flags \
                ':device name: ' \
                ':brightness (0-100): '
            ;;
        scene)
            _arguments \
                $global_flags \
                ':scene name: '
            ;;
        *)
            _arguments $global_flags
            ;;
    esac
}

_lilhomie "$@"
