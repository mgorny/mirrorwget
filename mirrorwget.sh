#!/bin/sh
# Support downloading from 'mirror://' links from within wget.
# (C) 2010 Michał Górny <gentoo@mgorny.alt.pl>
# Released under the terms of the 3-clause BSD license.

getrandom() {
	# Ah, POSIX doesn't give us a ${RANDOM} but let's try...
	local rand limit

	limit=${1}
	rand=${RANDOM}
	if [ "${rand}" = "${RANDOM}" ]; then
		# If ${RANDOM} seems constant, fallback to /dev/urandom.
		rand=$(od -A n -N 2 -d /dev/urandom)
		if [ ${?} -ne 0 ]; then
			# Finally, fallback to using our PID.
			rand=${$}
		fi
	fi

	echo $(( rand % limit ))
}

getmirrors() {
	local mirrorname portdir overlays repo fn awkscript gmirrors umirrors i tmp
	mirrorname=${1}
	portdir=$(portageq portdir)
	overlays=$(portageq portdir_overlay)

	set --

	for repo in "${portdir}" ${overlays}; do
		fn="${repo}"/profiles/thirdpartymirrors
		[ -r "${fn}" ] && set -- "${@}" "${fn}"
	done

	if [ ${#} -eq 0 ]; then
		echo 'No repositories found, failing terribly.' >&2
		exit 1
	fi

	# We need to call awk twice in order to get the 'gentoo' mirrors first.
	awkscript='
$1 == mirror {
	for (i = 2; i < NF; i++)
		print $i
	exit(64)
}'

	[ "${mirrorname}" != gentoo ] && gmirrors=$(awk -v mirror=gentoo "${awkscript}" "${@}")
	umirrors=$(awk -v mirror="${mirrorname}" "${awkscript}" "${@}")

	if [ ${?} -ne 64 ]; then
		echo "Warning: mirror '${mirrorname}' not found in thirdpartymirrors!" >&2
		umirrors=${gmirrors}
	elif [ "${mirrorname}" != gentoo ]; then
		set -- ${gmirrors}

		# Shift to a random argument.
		i=$(getrandom ${#})
		while [ ${i} -gt 0 ]; do
			shift
			: $(( i -= 1 ))
		done

		echo ${1}
	fi

	# Shuffle them a little.
	set -- ${umirrors}

	while [ ${#} -gt 0 ]; do
		i=$(getrandom ${#})
		while [ ${i} -gt 0 ]; do
			tmp=${1}
			shift
			set -- "${@}" "${tmp}"
			: $(( i -= 1 ))
		done

		echo ${1}
		shift
	done
}

main() {
	local argcount gotnc gotm arg mirroruri mirrorname mirrorpath mirror mirrors
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

			mirrors=$(getmirrors "${mirrorname}")
			[ ${?} -eq 0 ] || exit 1

			for mirror in ${mirrors}; do
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
