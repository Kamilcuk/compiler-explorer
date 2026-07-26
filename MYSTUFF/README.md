# MYSTUFF — Yio CE Deployment

Deployment infrastructure for the Compiler Explorer fork running the Yio C library.

## VM Management

```bash
./manage.sh start         # Start the VM
./manage.sh stop          # Graceful shutdown
./manage.sh ssh           # SSH as ce user
./manage.sh admin         # SSH as admin (sudo)
./manage.sh ansible ...   # Run an Ansible playbook
```

## Playbooks

```bash
./manage.sh ansible playbooks/provision.yml       # Full provision
./manage.sh ansible playbooks/config_ce.yml        # Restart CE
./manage.sh ansible playbooks/reinstall_yio.yml    # Rebuild Yio extensions
```

## VM Config

- The 9p mount tag `godbolt` maps the repo root into the VM at `/mnt/compiler-explorer`
- CE source is available at `/mnt/compiler-explorer` inside the VM
- Yio source is at `/mnt/compiler-explorer/libs/yio`
- The provision playbook creates a git worktree from the 9p mount into `/opt/compiler-explorer`
