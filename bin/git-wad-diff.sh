#!/bin/bash

# git-wad-diff.sh - Using GIT generate a diff image for each WAD file that has
#                   changed.
# by Steven Elliott <selliott512@gmail.com>
#
# Generate images depicting the differences in WAD files in a particula
# directory ($levels_dir). The set of changed WAD files and the changes
# included in them is driven by the optional "commit" argument. The commit
# argument is similar to commit argument that may be passed to "git diff". Like
# with "git diff" by default the comparison is from HEAD to the workspace. If a
# single revision commit argument (no "..") is specified then that becomes the
# from revision instead of HEAD. If a two revision commit argument (with a
# "..") is specified then the difference is between those two revisions, making
# the workspace irrelevant.
#
# The set of WAD files considered can be further reduced by the optional
# "wad-regex" argument. For example, if a diff would be produced for both map05
# and map07 but you only want to see the diff for map05 you could pass "05" for
# wad-regex.

# Globals

dname="${0%/*}"
bname="${0##*/}"
tmp_dir="/tmp/$bname.$$"
top_dir="$dname/../../.."
levels_dir="levels"
scripts_dir="$top_dir/scripts"
wad_images_dir="$top_dir/wad-images"

# Functions

# Clean up anything that would otherwise be left.
function cleanup()
{
    # Cleanup $tmp_dir safely.
    if [[ -d $tmp_dir ]]
    then
        rm -f "$tmp_dir"/*
        rmdir "$tmp_dir"
    fi
}

# Write the path to the WAD file given the revision to stdout.
function get_wad_path()
{
    local rev="$1"
    local wad="$2"

    if [[ $rev == "workspace" ]]
    then
        wad_file="$levels_dir/$wad"
        if [[ -f $wad_file ]]
        then
            echo "$wad_file"
        fi
    else
        local name="${wad%.wad}"
        local rev_path="$tmp_dir/$name-$rev.wad"
        if ! git -C "$levels_dir" show "$rev:./$wad" > "$rev_path"
        then
            # TODO: Try do destinguish between errors due to the file not
            # existing in the requested revision, and git failing for some
            # other reason.
            echo "Could not get revision $rev for \"$wad\"." 1>&2
            return
        fi
        echo "$rev_path"
    fi
}

# Main

if [[ ($1 == "-h") || ($# -lt 1) || ($# -gt 3) ]]
then
    echo "Usage: $bname do-show [commit [wad-regex]]" 1>&2
    exit 0
fi

if [[ ${1,,} == t* ]]
then
    do_show=t
    show_arg="-s"
else
    unset do_show
    unset show_arg
fi
if [[ $# -ge 2 ]]
then
    commit="$2"
fi
if [[ $# -ge 3 ]]
then
    wad_regex="$3"
else
    # Anything by default.
    wad_regex=".*"
fi

if ! mkdir -m 700 "$tmp_dir"
then
    echo "Could not create temporary directory \"$tmp_dir\"." 1>&2
    exit 1
fi
trap cleanup EXIT

# Assume that the levels are in ../levels relative to this script. $commit is
# intentionally not quoted 
level_wads=$(git -C "$levels_dir" diff --name-only $commit . | \
    grep -iP "$wad_regex")

if [[ -z $level_wads ]]
then
    echo "No differences found."
    exit 0
fi

# Default with no "commit" argument.
from_rev="HEAD"
to_rev="workspace"

# It's possible to have a git parse the commit argument with a hook, but it's
# easy enough to do so here. This probably misses some advanced usages.
set ${commit/../ } nil # "nil" to avoid a "set" without arguments.
if [[ $# -ge 2 ]]
then
    from_rev="$1"
    if [[ $# -ge 3 ]]
    then
        to_rev="$2"
    fi
fi

unset from_paths to_paths
for level_wad in $level_wads
do
    wad="${level_wad##*/}"
    name="${wad%.wad}"

    from_path=$(get_wad_path $from_rev $wad)
    to_path=$(get_wad_path $to_rev $wad)
    echo "Generating diff for \"$wad\" from \"$from_rev\" to \"$to_rev\"."

    # Either $from_path or $to_path being empty is a noop.
    from_paths="$from_paths $from_path"
    to_paths="$to_paths $to_path"
done

echo "Running wad2image in diff-only mode."
"$dname"/wad2image.py -v $show_arg -d colors --diff-only $from_paths $to_paths
