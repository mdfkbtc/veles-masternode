#!/bin/bash
# Makes snapshot from dev machine to files directory
ROOT_PREFIX=""	# could be "" for /, "/srv", "/var/local" ...
DIST_PREFIX="/root/veles-masternode/dist"
DIST_OVER_PREFIX="/root/veles-masternode/dist-overlay"

unparse_ports() {
        while read line; do
		port=$(echo $line | awk '{print $1}')
		service=$(echo $line | awk '{print $2}')

		if $(echo $line | grep -v '#' > /dev/null); then	# just ignore whole line if comment is present
			#echo -e "${port} => {{svc-port:${service}}}"
			find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/${port}/{{svc-port:${service}}}/" "{}" +;
		fi
        done < snapshot/ports.cf
}

parse_ports() {
        while read line; do
		port=$(echo $line | awk '{print $1}')
		service=$(echo $line | awk '{print $2}')

		if $(echo $line | grep -v '#' > /dev/null); then	# just ignore whole line if comment is present
			#echo -e "{{svc-port:${service}}} => ${port}"
			find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/{{svc-port:${service}}}/${port}/" "{}" +;
		fi
        done < snapshot/ports.cf
}

unparse_users() {
        while read line; do
                user=$(echo $line | awk '{print $1}')
                service=$(echo $line | awk '{print $2}')

                if $(echo $line | grep -v '#' > /dev/null) && [ "${line}" != "" ]; then        # just ignore whole line if comment is present
			#echo "${user} => {{svc-user:${service}}}"
                        find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/${user}/{{svc-user:${service}}}/" "{}" +;
                fi
        done < snapshot/users.cf
}

parse_users() {
        while read line; do
                user=$(echo $line | awk '{print $1}')
                service=$(echo $line | awk '{print $2}')

                if $(echo $line | grep -v '#' > /dev/null) && [ "${line}" != "" ]; then        # just ignore whole line if comment is present
			#echo "{{svc-user:${service}}} => ${user}"
                        find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/{{svc-user:${service}}}/${user}/" "{}" +;
                fi
        done < snapshot/users.cf
}

install_users() {
        while read line; do
                user=$(echo $line | awk '{print $1}')
                service=$(echo $line | awk '{print $2}')

                if $(echo $line | grep -v '#' > /dev/null) && [ "${line}" != "" ]; then
			#echo "+ ${user}"
			useradd -d "${ROOT_PREFIX}/var/lib/veles" -c "${service}" "${user}"
                fi
        done < snapshot/users.cf
}

parse_vars() {
        while read line; do
		name=$(echo $line | awk '{print $1}')
		value=$(echo $line | awk '{print $2}')

		if $(echo $line | grep -v '#' > /dev/null); then	# just ignore whole line if comment is present
			#echo -e "{{${name}}} => ${value}"
			find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/{{${name}}}/${value}/" "{}" +;
		fi
        done < snapshot/vars.cf

	# Parse other kind of vars
	parse_ports
	parse_users
}

unparse_vars() {
        while read line; do
		name=$(echo $line | awk '{print $1}')
		value=$(echo $line | awk '{print $2}')

		if $(echo $line | grep -v '#' > /dev/null); then	# just ignore whole line if comment is present
			#echo -e "${value} => {{${name}}}"
			find "${DIST_PREFIX}" -type f -iname "*.*" -exec sed -i "s/${value}/{{${name}}}/" "{}" +;
		fi
        done < snapshot/vars.cf

	# Parse other kind of vars
	unparse_ports
	unparse_users
}

apply_privileges() {
        while read line; do
                file=$(echo $line | awk '{print $1}')
                mode=$(echo $line | awk '{print $2}')
                owner=$(echo $line | awk '{print $3}')

                if $(echo $line | grep -v '#' > /dev/null); then
			echo "[set permissions] ${file}: ${mode}"
			echo "[set owner] ${file}: ${owner}"
			chmod -R "${mode}" "${DIST_PREFIX}${file}"
			chown -R "${owner}" "${DIST_PREFIX}${file}"
                fi
        done < snapshot/privileges.list
}

install_apt_deps() {
	installed=$(dpkg --get-selections | awk '{print $1}')
	to_install=""

	echo " * Checking installed apt dependencies ..."
        while read line; do
		if $(echo $line | grep '#' > /dev/null); then
			continue
		fi

		echo -n "   ${line} ... "

		if echo "${installed}" | grep "${line}" > /dev/null; then
			echo "yes"
		else
			to_install="${to_install} ${line}"
			echo "no"
		fi
        done < snapshot/apt.dep

	if [ "${to_install}" == "" ]; then
		echo " * Nothing to install, all apt dependencies satisfied"
	else
		echo " * Installing following apt packages: ${to_install}"
		apt-get install --no-install-recommends -y "${to_install}"
	fi
}

install_pip3_deps() {
	installed=$(pip3 list --format=columns | awk '{print $1}')
	to_install=""

	echo " * Checking installed python3 dependencies ..."
        while read line; do
		if $(echo $line | grep '#' > /dev/null); then
			continue
		fi

		echo -n "   ${line} ... "

		if echo "${installed}" | grep "${line}" > /dev/null; then
			echo "yes"
		else
			to_install="${to_install} ${line}"
			echo "no"
		fi
        done < snapshot/pip3.dep

	if [ "${to_install}" == "" ]; then
		echo " * Nothing to install, all python3 dependencies satisfied"
	else
		echo " * Installing following python3 packages: ${to_install}"
		pip3 install "${to_install}"
	fi
}

install_git_deps() {
	echo " * Checking dependencies that need to be installed from source ..."
        while read line; do
		if $(echo $line | grep '#' > /dev/null); then
			continue
		fi

		repo=$(echo $line | awk '{print $1}')
		install_cmd=$(echo $line | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
		pwd=$(pwd)
		mkdir /tmp/veles.snapshot > /dev/null
		rm -r /tmp/veles.snapshot/*
		cd /tmp/veles.snapshot
		git clone "${repo}"
		cd $(basename "${repo}")
		bash -c "${install_cmd}"
		cd "$pwd"

        done < snapshot/git.dep
}

install_deps() {
	install_apt_deps
	install_pip3_deps
	install_git_deps
}

pre_install() {
	source snapshot/pre_install.sh
	do_pre_install
}

post_install() {
	# Now 'dist' dir is the same as new ROOT_DIR here
	DIST_PREFIX="${ROOT_PREFIX}"

	# Start post-install scripts
	source snapshot/post_install.sh
	do_post_install
}

setup_service() {
	systemctl enable veles-mn
}

launch_service() {
	systemctl start veles-mn
}


mn_backup() {
	rm -r "${DIST_PREFIX}/*"
	copy_snapshot "${ROOT_PREFIX}" "${DIST_PREFIX}" "backup"
	unparse_vars
}

mn_restore() {
	source "snapshot/config_dialog.sh"

	pre_config_wizard "snapshot/vars.cf" || exit 0
	parse_vars
	install_users
	apply_privileges > /dev/null
	pre_install
	copy_snapshot "${DIST_PREFIX}" "${ROOT_PREFIX}" "restore"
	post_install
	apply_privileges > /dev/null
	post_config_wizard || exit 0
	apply_privileges
	setup_service
	launch_service
	first_run_wizard || exit 0
}

copy_snapshot() {
	src_prefix="${1}"
	dst_prefix="${2}"

	while read path; do
		if [ -d "${src_prefix}${path}" ]; then
			mkdir -p "${dst_prefix}${path}" > /dev/null
			cp -av "${src_prefix}${path}/" $(dirname "${dst_prefix}${path}/")
		else
			mkdir -p $(dirname "${dst_prefix}${path}") > /dev/null
			cp -av "${src_prefix}${path}" $(dirname "${dst_prefix}${path}")
		fi
	done < snapshot/snapshot.list

	while read path; do
		if [ "${path}" == "" ] || [ "${path}" == "/" ] || [ "${path}" == "." ]; then
			continue
		fi

		# if dir exists, make it empty after backup
		if [ "${3}" == "backup" ] && [[ -d "${dst_prefix}${path}" ]]; then
			rm -r "${dst_prefix}${path}"
		fi
		mkdir -p "${dst_prefix}${path}" > /dev/null

	done < snapshot/empty-dirs.list
}

show_help() {
	echo "Veles Masternode snapshot installation manager"
	echo -e "Usage: snapshot.sh [action]\n\nActions:"
	echo -e "install\t\t\tinstalls Veles MN system snapshot to local system"
	echo -e "parse_vars\t\\treplace template variables to real values in snapshot"
	echo -e "unparse_vars\t\treplace real values to template variables in snapshot"
	echo -e "install_users\t\tadds neccessary user accounts"
	echo -e "apply_privileges\tapplies needed file/directory permissions and ownership"
}

if [ "$#" -ne 1 ] || [ "$1" == "--help" ]; then
	show_help

elif [ "$1" == "install" ]; then
	mn_restore

elif [ "$1" == "make_install" ]; then
	mn_backup

elif [ "$1" == "parse_ports" ]; then
	parse_ports

elif [ "$1" == "unparse_ports" ]; then
	unparse_ports

elif [ "$1" == "parse_vars" ]; then
	parse_vars

elif [ "$1" == "unparse_vars" ]; then
	unparse_vars

elif [ "$1" == "install_users" ]; then
	install_users

elif [ "$1" == "apply_privileges" ]; then
	apply_privileges

elif [ "$1" == "pre_install" ]; then
	post_install

elif [ "$1" == "post_install" ]; then
	post_install

elif [ "$1" == "install_deps" ]; then
	install_deps

else
	show_help
fi
