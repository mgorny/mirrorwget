#!/bin/bash
# Support downloading from 'mirror://' links from within wget.
# (C) 2010 Michał Górny <gentoo@mgorny.alt.pl>
# Released under the terms of the 3-clause BSD license.

getmirrors() {
	local arg=$1
	local portdir=$(portageq portdir)
	local overlays=$(portageq portdir_overlay)

	local splitarg=${arg#mirror://}
	local mirrorname=${splitarg%%/*}
	local mirrorpath=${splitarg#*/}

	local mirrorfiles i=0

	for repo in "${portdir}" ${overlays}; do
		local fn="${repo}"/profiles/thirdpartymirrors
		if [[ -f ${fn} ]]; then
			mirrorfiles[$i]=${fn}
			(( i++ ))
		fi
	done

	# we need to call awk twice in order to get the 'gentoo' mirrors first
	local awkscript='
$1 == "_MIRROR_" {
	for (i = 2; i < NF; i++)
		print $i
	exit(64)
}'

	local gmirrors=( $(awk "${awkscript/_MIRROR_/gentoo}" "${mirrorfiles[0]}") )
	local umirrors=( $(awk "${awkscript/_MIRROR_/${mirrorname}}" "${mirrorfiles[@]}") )
	if [[ ${PIPESTATUS} -ne 64 ]]; then
		echo "Warning: mirror '${mirrorname}' not found in thirdpartymirrors!" >&2
		echo ${gmirrors[@]} # XXX: shuffle
	else
		echo ${gmirrors[$(( RANDOM % ${#gmirrors[@]}))]}
		echo ${umirrors[@]} # XXX: shuffle
	fi
}

main() {
	local wgetargv i
	local gotnc=0 gotm=0

	for (( i = 1; i <= $#; i++ )); do
		local arg=${!i}
		
		if [[ ${arg} == mirror://*/* ]]; then
			local mirror
			for mirror in $(getmirrors "${arg}"); do
				wgetargv[$i]=${mirror}
				(( i++ ))
			done
			gotm=1
		else
			[[ ${arg} = -nc || ${arg} = --no-clobber ]] && gotnc=1
			[[ ${arg} = -c || ${arg} = --continue ]] && gotnc=1
			wgetargv[$i]=${arg}
		fi
	done

	if [[ ${gotnc} -ne 1 && ${gotm} -eq 1 ]]; then
		echo 'Prepending wget arguments with --no-clobber.' >&2
		wgetargv[0]='--no-clobber'
	fi

	exec wget "${wgetargv[@]}"
}

main "$@"
