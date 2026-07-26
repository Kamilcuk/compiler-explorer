# Compiler Explorer — Bash Compiler & Deployment

## Project Structure

```
.
├── lib/compilers/bash.ts          # Bash compiler class (minimal — just key())
├── etc/scripts/
│   ├── bash-compile.sh            # Compiler executable (handles -o output -S input)
│   └── bash-execute.sh            # Execution wrapper (executionWrapper, drops first arg)
├── etc/config/
│   ├── bash.defaults.properties   # Bash compiler config
│   └── execution.defaults.properties  # Global sandbox config
├── etc/nsjail/
│   ├── user-execution.cfg         # Generic execution sandbox (restrictive seccomp)
│   ├── bash-user-execution.cfg    # Bash execution sandbox (clone/fork allowed)
│   ├── compilers-and-tools.cfg    # Compilation sandbox (has /bin, /opt/compiler-explorer)
│   └── bash-compilers-and-tools.cfg # Bash compilation sandbox
├── MYSTUFF/
│   ├── manage.sh                  # VM management (qemu, ansible, SSH)
│   ├── playbooks/
│   │   ├── config_ce.yml          # Sync config + restart
│   │   ├── rsync_config_ce.yml    # Sync config only (no restart)
│   │   ├── provision.yml          # Full VM provisioning
│   │   └── tasks/
│   │       ├── sync_config_ce.yml # Shared rsync task
│   │       ├── restart_ce.yml     # Shared restart + wait task
│   │       ├── deploy_ce.yml      # Full deploy (build + restart)
│   │       └── wait_for_godbolt.yml
│   ├── test-bash.sh               # CE API test (curl compile)
│   └── test-nsjail.sh             # nsjail sandbox test (runs in VM via manage.sh)
```

## Bash Compiler

### Architecture

- **`lib/compilers/bash.ts`** — just `static get key() { return 'bash'; }`. No overrides.
- **`compiler.bash.exe`** points to `etc/scripts/bash-compile.sh` — the script IS the compiler binary.
- **`compiler.bash.executionWrapper`** points to `etc/scripts/bash-execute.sh` — wraps execution.

### Compilation flow

1. CE calls `compiler.exe` (the script) with gcc-style flags: `-g -o <output> -S <input>`
2. `bash-compile.sh` parses `-o <output>`, skips all other flags, collects positional args
3. Runs `bash -n -r "$input"` for syntax check in restricted mode
4. `cat "$input" > "$output"` to produce source as "assembly" output

### Execution flow

1. `handleInterpreting` writes user source to temp file, calls `fixExecuteParametersForInterpreting`
2. Base class adds the output filename to args
3. `runExecutable` → `executionWrapper` replaces executable with `bash-execute.sh`
4. `bash-execute.sh` drops the first arg (original compiler exe), runs `exec /bin/bash -r "$@"`

### `-o` handling

The first `-o` flag sets the output file. Subsequent `-o` flags are treated as bash options (e.g., `-o nounset`).

## nsjail Configuration

### Config files

| Config | Used for | Mounts | seccomp |
|---|---|---|---|
| `user-execution.cfg` | Generic execution | libs, /tmp, /dev | Restrictive (write only fd 1/2, no clone/fork) |
| `bash-user-execution.cfg` | Bash execution | Same + /bin/bash, bash-execute.sh | Permissive (write unrestricted, clone/fork allowed) |
| `compilers-and-tools.cfg` | Compilation | /bin, /usr, /lib, /opt/compiler-explorer | None |
| `bash-compilers-and-tools.cfg` | Bash compilation | Same as above | None |

### Global routing (from `execution.defaults.properties`)

```
nsjail.config.sandbox=etc/nsjail/user-execution.cfg
nsjail.config.execute=etc/nsjail/compilers-and-tools.cfg
```

The `sandbox` config is used for the execution sandbox (via `executionWrapper`). The `execute` config is used for compilation. These are global — there's no per-compiler override mechanism in the CE code.

### Manual testing

```bash
./MYSTUFF/test-nsjail.sh
```

Runs inside the VM via `manage.sh root`. The test script creates a temp dir with a sample script, then runs nsjail with the config + runtime flags CE adds (`--time_limit`, `--cwd`, `--bindmount` for temp dir).

## Deployment

### Make targets

| Target | What it does |
|---|---|
| `make config_ce` | Stop godbolt, sync config/scripts/nsjail/examples, restart |
| `make rsync_config_ce` | Sync only (no stop, no restart) |
| `make rebuild_ce` | Full deploy: git pull, npm ci, webpack, TS compile, restart |
| `make provision` | Full VM provisioning (packages, nsjail, users, cgroups) |
| `make restart` | Restart godbolt + wait for healthy |

### VM management

- VM runs via QEMU with 9p mounts for source code
- SSH: `manage.sh ssh` (port 40022, user `ce`)
- Admin: `manage.sh admin` (user `admin2`, sudo access)
- Root: `manage.sh root` (SSH + sudo -ni)
- `ce_dir: /opt/compiler-explorer` inside the VM
- `ce_source_dir: /opt/godbolt/compiler-explorer` (9p mount)

## Common Issues

- **nsjail exit 255**: Usually means the command or a dependency isn't mounted in the sandbox. Check the config file's mount list.
- **Config changes not taking effect**: Run `make config_ce` (sync + restart). `rsync_config_ce` only syncs files — the running process has stale config.
- **TS changes not taking effect**: Need `make rebuild_ce` or at least `make prebuild` (compiles TS to JS).