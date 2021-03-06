all:

clean:
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml down --remove-orphans

build:
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml build

test-env:
	docker-compose -f docker-compose.yml -f ./test/docker-compose.test.yml up -d
	docker exec --user root -i git-deploy-test sh -c "cp -R /git /git-initial"
	docker exec --user root -i git-deploy-test-exthooks sh -c "cp -R /git /git-initial"
	docker exec --user root -i git-deploy-test-exthooks-sig sh -c "cp -R /git /git-initial"

test: clean build test-env
	chmod 0600 test/test-keys/test-sshkey*
	docker exec --user root -i git-deploy-test-runner bats test.bats

develop: clean build test-env
	docker exec -it git-deploy-test-runner bash

.PHONY: all develop test test-env
