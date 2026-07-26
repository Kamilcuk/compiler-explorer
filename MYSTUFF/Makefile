M = ./manage.sh
SHELL = bash

reprovision:
	$(M) stop
	$(M) distresetup
	$(M) start -m 8G
	$(M) wait || :
	$(MAKE) provision
	$(MAKE) rebuild_ce
	$(M) stop
	$(M) start
	$(M) wait
provision:
	$(M) ansible playbooks/provision.yml
config_ce:
	$(M) ansible playbooks/config_ce.yml
rsync_config_ce:
	$(M) ansible playbooks/rsync_config_ce.yml
rebuild_ce:
	$(M) ansible playbooks/rebuild_ce.yml
reinstall_yio:
	$(M) ansible playbooks/reinstall_yio.yml
restart:
	$(M) restart
	$(M) wait
install_nsjail:
	$(M) ansible playbooks/install_nsjail.yml
debug_ce:
	$(M) ansible playbooks/debug_ce.yml
cgroups:
	$(M) ansible playbooks/cgroups.yml
setup_apparmor:
	$(M) ansible playbooks/setup_apparmor.yml
cleanup:
	$(M) ansible playbooks/cleanup.yml

test-nsjail2: export ARGS ?= echo 123 > /dev/null; echo DONE
test-nsjail2:
	./manage.sh root sudo -u ce bash -s <<<' \
		id && stat /dev/null && \
		mkdir -vp /tmp/$$USER && \
		'"$$(declare -p ARGS)"' && \
		echo "$$ARGS" > /tmp/$$USER/output.s && \
		cd /opt/compiler-explorer && \
		grep outside_id etc/nsjail/bash-user-execution.cfg && \
		nsjail \
    		--config etc/nsjail/bash-user-execution.cfg \
    		--time_limit=101 \
    		--cwd /app \
    		--bindmount /tmp/$$USER:/app \
    		--env=LD_LIBRARY_PATH= \
    		--env=ASAN_OPTIONS=color=always \
    		--env=UBSAN_OPTIONS=color=always \
    		--env=MSAN_OPTIONS=color=always \
    		--env=LSAN_OPTIONS=color=always \
    		--env=HOME=/app \
    		-- \
    		/opt/compiler-explorer/etc/scripts/bash-runner.sh /app/output.s \
    '
