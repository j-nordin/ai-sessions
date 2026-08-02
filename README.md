# ai-sessions

Overview and crash recovery for AI CLI coding sessions.

When your laptop dies unexpectedly — or you just closed a bunch of terminals —
there's no easy way to see which AI coding sessions were recently active, what
they were about, and which ones were still open when everything went down.
`ai-sessions` answers exactly that, and reopens the one you pick.

Currently supported backends:

- **claude** — [Claude Code](https://code.claude.com)

The backend layer is pluggable, so other AI CLIs can be added later
(see [Adding a backend](#adding-a-backend)).

## Usage

```console
$ ai-sessions
   LAST ACTIVE  PROJECT               TITLE                            ID
 ● 5m ago      ~/work/my-project     Fix flaky integration test       3f9f264f
 ✗ 2h ago      ~/dotfiles            Refactor install script          6b42ce33
   1d ago      ~                     Debug docker networking          3ab7bed7

1 session was open when the machine last went down — 'ai-sessions crashed' to review
```

- `●` (green) — session is running right now
- `✗` (yellow) — session was still open when the machine went down or the
  process died; it never exited cleanly

```console
$ ai-sessions crashed        # only the sessions left open at the last shutdown
$ ai-sessions pick           # fzf picker → resumes the chosen session in its project dir
$ ai-sessions --here         # only sessions under the current directory
$ ai-sessions --project ~/work/my-project
$ ai-sessions -n 50          # show more rows
$ ai-sessions --json         # machine-readable output (full session ids, ISO timestamps)
```

`pick` uses [fzf](https://github.com/junegunn/fzf) if available and falls back
to a numbered prompt otherwise. Selecting a session changes into its original
working directory and execs the backend's resume command
(e.g. `claude --resume <session-id>`).

## Install

```console
$ git clone https://github.com/<user>/ai-sessions
$ cd ai-sessions
$ ./install.sh    # symlinks the script into ~/.local/bin
```

Requires Python 3.10+. No third-party Python dependencies. `fzf` is optional
but recommended for `pick`. Crash detection is most accurate on Linux (it uses
`/proc` to check process liveness and boot time); on other platforms it
degrades to a plain pid-liveness check.

## How it works (claude backend)

Claude Code stores one JSONL transcript per session under
`~/.claude/projects/<project-dir>/<session-uuid>.jsonl`, and keeps a registry
of currently running sessions in `~/.claude/sessions/<pid>.json`.

- **Last activity** is taken from the last transcript line that carries a
  timestamp. File mtime is deliberately *not* trusted: Claude Code rewrites
  timestamp-less metadata lines (title, last prompt) long after the last real
  interaction, so mtime can overstate activity by days.
- **Title** comes from the session's AI-generated title, falling back to the
  agent name, the last prompt, then the first user message.
- **Crash detection**: a registry entry whose process is gone (or whose last
  update predates the current boot) means that session never exited cleanly —
  it was open when the machine went down. If the transcript shows activity
  after the stale entry, the session was since resumed and is not flagged.
- Only bounded head/tail reads are performed per transcript, so listing stays
  fast even with multi-hundred-MB transcripts.

Everything is read-only: `ai-sessions` never writes to the backend's data
directories. Set `CLAUDE_DIR` to point the claude backend at a different
directory (useful for testing).

## Adding a backend

Backends subclass `Backend` in the `ai-sessions` script and implement two
methods:

```python
class MyToolBackend(Backend):
    name = "mytool"

    def discover(self) -> list[Session]:
        # return Session(backend, session_id, cwd, title, created,
        #                last_active, status) per stored session
        ...

    def resume_argv(self, session: Session) -> list[str]:
        return ["mytool", "resume", session.session_id]
```

Then add it to the `BACKENDS` registry. A `BACKEND` column appears in the
listing automatically once more than one backend reports sessions.

## License

MIT
