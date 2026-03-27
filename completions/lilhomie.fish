# fish completion for lilhomie
#
# Install:
#   cp lilhomie.fish ~/.config/fish/completions/lilhomie.fish
#
# Or if you have a custom completions directory:
#   cp lilhomie.fish /usr/local/share/fish/vendor_completions.d/lilhomie.fish

# Disable file completions globally for lilhomie
complete -c lilhomie -f

# ---------------------------------------------------------------------------
# Global flags (available everywhere)
# ---------------------------------------------------------------------------
complete -c lilhomie -l json  -s j -d 'Output raw JSON (pipe into jq, etc)'
complete -c lilhomie -l help  -s h -d 'Show help message'

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------
complete -c lilhomie -n '__fish_use_subcommand' -a list       -d 'List all HomeKit devices grouped by room'
complete -c lilhomie -n '__fish_use_subcommand' -a ls         -d 'Alias for list'
complete -c lilhomie -n '__fish_use_subcommand' -a devices    -d 'Alias for list'
complete -c lilhomie -n '__fish_use_subcommand' -a scenes     -d 'List all HomeKit scenes'
complete -c lilhomie -n '__fish_use_subcommand' -a status     -d 'Get status of a device'
complete -c lilhomie -n '__fish_use_subcommand' -a get        -d 'Alias for status'
complete -c lilhomie -n '__fish_use_subcommand' -a toggle     -d 'Toggle a device on/off'
complete -c lilhomie -n '__fish_use_subcommand' -a on         -d 'Turn a device on'
complete -c lilhomie -n '__fish_use_subcommand' -a off        -d 'Turn a device off'
complete -c lilhomie -n '__fish_use_subcommand' -a set        -d 'Set device brightness (0-100)'
complete -c lilhomie -n '__fish_use_subcommand' -a scene      -d 'Trigger a scene'
complete -c lilhomie -n '__fish_use_subcommand' -a info       -d 'Show Homie app status'
complete -c lilhomie -n '__fish_use_subcommand' -a status-all -d 'Alias for info'
complete -c lilhomie -n '__fish_use_subcommand' -a help       -d 'Show help message'

# ---------------------------------------------------------------------------
# Helper: detect which subcommand is active
# ---------------------------------------------------------------------------
function __lilhomie_subcommand
    set -l cmd (commandline -opc)
    set -l subcmds list ls devices scenes status get toggle on off set scene info status-all help
    for word in $cmd[2..]
        if contains -- $word $subcmds
            echo $word
            return 0
        end
    end
    return 1
end

function __fish_lilhomie_using_subcommand
    set -l sub (__lilhomie_subcommand)
    contains -- $sub $argv
end

# ---------------------------------------------------------------------------
# Subcommand-specific flag completions
# (--json / -j already added globally above; add any subcommand-only flags here)
# ---------------------------------------------------------------------------

# set: brightness argument hint
complete -c lilhomie -n '__fish_lilhomie_using_subcommand set' \
    -a '0 10 20 25 30 40 50 60 70 75 80 90 100' \
    -d 'Brightness level'
