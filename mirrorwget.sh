#!/bin/bash
# Support downloading from 'mirror://' links from within wget.
# (C) 2010 Michał Górny <gentoo@mgorny.alt.pl>
# Released under the terms of the 3-clause BSD license.

getmirrors() {
	local mirrorname=$1
	local portdir=$(portageq portdir)
	local overlays=$(portageq portdir_overlay)

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
	local argcount gotnc gotm arg mirroruri mirrorname mirrorpath mirror
	argcount=${#}
	gotnc=0
	gotm=0

	while [ ${argcount} -gt 0 ]; do
		arg=${1}
		mirroruri=${arg#mirror://}
		shift
		: $(( argcount -= 1 ))

		if [ ${mirroruri} != ${arg} ]; then
			# Get the mirrors here, and happily append them.
			mirrorname=${mirroruri%%/*}
			mirrorpath=${mirroruri#*/}

			for mirror in $(getmirrors "${mirrorname}"); do
				set -- "${@}" "${mirror}/${mirrorpath}"
			done

			gotm=1
		else
			# Not a mirror, maybe an important option?
			[ "${arg}" = -nc -o "${arg}" = --no-clobber ] && gotnc=1
			[ "${arg}" = -c -o "${arg}" = --continue ] && gotnc=1

			# Anyway, reappend it.
			set -- "${@}" "${arg}"
		fi
	done

	if [ ${gotnc} -ne 1 -a ${gotm} -eq 1 ]; then
		echo 'Prepending the wget arguments with --no-clobber.' >&2
		set -- --no-clobber "${@}"
	fi

	exec wget "${@}"
}

main "${@}"
