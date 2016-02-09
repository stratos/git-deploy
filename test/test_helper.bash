if which docker-machine > /dev/null; then
	export DOCKER_HOST_IP=$(docker-machine ip `docker-machine active`)
else
	export DOCKER_HOST_IP="localhost"
fi

destroy_data_volume(){
	docker rm -f test-git-deploy-data  &> /dev/null || return 0
}

create_data_volume(){
	docker run \
		-v /backup_volume \
		--name test-git-deploy-data \
		pebble/test-git-deploy \
		true &> /dev/null
}

build_container(){
	docker build -t pebble/test-git-deploy .
}

run_container(){
	local hook_repo=${1-}
	local hook_repo_keys=${2}
	if [ -z "$hook_repo_keys" ]; then
		HOOK_REPO_VERIFY=false
	else
		HOOK_REPO_VERIFY=true
	fi
	docker run \
		-d \
		--name test-git-deploy \
		-e DEST=file:///backup_volume \
		-e PASSPHRASE=a_test_passphrase \
		-e HOOK_REPO=$hook_repo \
		-e HOOK_REPO_VERIFY=$HOOK_REPO_VERIFY \
		-e DEPLOY_TIMEOUT_TERM=10s \
		-e DEPLOY_TIMEOUT_KILL=12s \
		--volumes-from test-git-deploy-data \
		-v /dev/urandom:/dev/random \
		-p 2222:2222 \
		pebble/test-git-deploy
		#pebble/test-git-deploy &> /dev/null
	sleep 5
	gen_sshkey
	import_sshkey
	for key_id in $hook_repo_keys; do
		import_gpgkey $key_id
	done	
}

destroy_container(){
	docker rm -f test-git-deploy &> /dev/null || return 0
}

make_hook_repo(){
	local hook_repo=${1-testhookrepo}
	docker exec test-git-deploy bash -c "git init --bare $hook_repo"
}

gen_sshkey(){
	if [ ! -f /tmp/git-deploy-test/sshkey ]; then
		ssh-keygen -b 2048 -t rsa -f /tmp/git-deploy-test/sshkey -q -N ""
	fi
}

import_sshkey(){
	docker \
		exec \
		-i test-git-deploy \
		bash -c 'cat >> .ssh/authorized_keys' \
			< /tmp/git-deploy-test/sshkey.pub
}

import_gpgkey(){
	local key_id=${1-}
	docker \
		exec \
		-i test-git-deploy \
		bash -c 'cat | gpg --import' \
			< ${PWD}/test/test-keys/${key_id}.key
	docker \
		exec \
		-i test-git-deploy \
		bash -c 'cat >> /tmp/trustfile; gpg --import-ownertrust /tmp/trustfile' \
			< ${PWD}/test/test-keys/${key_id}.key.trust
}

container_command(){
	docker \
		exec \
		-i test-git-deploy \
		$* <&0
}

git(){
	if [ ! -f /tmp/git-deploy-test/gitssh ]; then
		cat <<- "EOF" > /tmp/git-deploy-test/gitssh
			#!/bin/bash
			exec /usr/bin/ssh \
				-o UserKnownHostsFile=/dev/null \
				-o StrictHostKeyChecking=no \
				-i /tmp/git-deploy-test/sshkey $*
		EOF
		chmod +x /tmp/git-deploy-test/gitssh
	fi
	GIT_SSH="/tmp/git-deploy-test/gitssh" /usr/bin/git "$@"
}

clone_repo(){
	oldpwd=$(pwd)
	cd
	rm -rf /tmp/git-deploy-test/$1
	git clone ssh://git@${DOCKER_HOST_IP}:2222/git/${1} /tmp/git-deploy-test/$1
	cd $oldpwd
}

ssh_command(){
	ssh \
		-p2222 \
		-i /tmp/git-deploy-test/sshkey \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		git@${DOCKER_HOST_IP} \
		$1
}

set_config() {
	local repo=${1-testrepo}
	local key=${2-foo}
	local value=${3-bar}
	local repo_folder="/tmp/git-deploy-test/$1"
	if [ -d "$repo_folder" ]; then
		echo "export $key=$value" >> $repo_folder/config.env
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "test commit"
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_test_commit() {
	local repo=${1-testrepo}
	local file_name=${2-test}
	local repo_folder="/tmp/git-deploy-test/$1"
	if [ -d "$repo_folder" ]; then
		file_dir=$(dirname ${file_name})
		if [ "${file_dir}" != "." ]; then
			mkdir -p ${repo_folder}/${file_dir}
		fi
		date >> ${repo_folder}/${file_name}
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} add .
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} commit -m "test commit"
		git --git-dir=${repo_folder}/.git --work-tree=${repo_folder} push origin master
	else
		echo "/tmp/git-deploy-test/$1 does not exist"
		exit 1
	fi
}

push_hook() {
	local repo=${1-testrepo}
	local branch=${2-master}
	local hook_file=${3-test}
	local sign_key=${4}
	local hook_name=$(basename $hook_file)
	local hook_folder=$(dirname $hook_file)
	local repo_folder="/tmp/git-deploy-test/$repo/"
	if [ -d "$repo_folder" ]; then
		mkdir -p $repo_folder/$hook_folder
		cp $PWD/test/test-hooks/$hook_name $repo_folder/$hook_file
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder checkout -B $branch
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder add .
		if [[ ! -z "$sign_key" ]]; then
			export GNUPGHOME="/tmp/git-deploy-test/gpg"
			rm -rf $GNUPGHOME
			mkdir -p $GNUPGHOME
			echo gpg --import test/test-keys/${sign_key}.key
			gpg --import test/test-keys/${sign_key}.key
			git \
				--git-dir=${repo_folder}/.git \
				--work-tree=${repo_folder} \
					commit \
						-m "add $hook_name hook" \
						--gpg-sign=${sign_key}
			unset GNUPGHOME
		else
			git --git-dir=$repo_folder/.git --work-tree=$repo_folder commit -m "add $hook_name hook"
		fi
		git --git-dir=$repo_folder/.git --work-tree=$repo_folder push origin $branch
	else
		echo "/tmp/git-deploy-test/$repo does not exist"
		exit 1
	fi
}
