source $argv[1]
set -l host $argv[2]
set -l home $argv[3]

function candidates
    complete -C "$argv[1]" | string replace -r '\t.*$' ''
end
function require_candidate
    set -l results (candidates "$argv[1]")
    if not contains -- "$argv[2]" $results
        printf 'Missing %s in completion for %s: %s\n' "$argv[2]" "$argv[1]" "$results" >&2
        exit 1
    end
end
require_candidate 'dot ' build
require_candidate 'dot bu' build
require_candidate 'dot pu' push
require_candidate 'dot ca' cache
require_candidate 'dot cache ' refresh
require_candidate 'dot cache re' refresh
require_candidate 'dot cache refresh --' --url
require_candidate 'dot --repo ' completion-dir/
if contains -- not-a-command (candidates 'dot ')
    exit 1
end
if contains -- not-a-command (candidates 'dot --repo ')
    exit 1
end
require_candidate 'dot --repo "/repo with spaces" ' build
require_candidate 'dot --repo "/repo; touch completion-injected" ' build
if test -e completion-injected
    printf 'Repository argument was evaluated as shell code\n' >&2
    exit 1
end
require_candidate 'dot --repo "/repo with spaces" build ' $host
for command in build switch boot test eval iso pull
    require_candidate "dot $command " $host
    require_candidate "dot $command "(string sub -l 1 -- $host) $host
    if contains -- build (candidates "dot $command ")
        exit 1
    end
end
for command in home eval-hm
    require_candidate "dot $command " $home
end
for input in "dot build $host " "dot pull $host " 'dot push ' 'dot fmt ' 'dot unknown ' 'dot cache refresh '
    if test (count (candidates "$input")) -ne 0
        printf 'Unexpected positional completions for %s\n' "$input" >&2
        exit 1
    end
end
require_candidate 'dot --' --repo
require_candidate 'dot build --' --help
