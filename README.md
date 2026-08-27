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

Running `ai-sessions` on a terminal opens an interactive picker over your
recent sessions — select one and it resumes in its original project
directory. Typing in the picker searches what was *said* in those sessions,
not just the titles on screen, so you can start from the list and narrow to
the session you actually mean. When output is piped (or with `--json`), it
prints the table instead, same as `ai-sessions list`:

```console
$ ai-sessions list
   LAST ACTIVE  PROJECT               TITLE                            ID
 ● 5m ago      ~/work/my-project     Fix flaky integration test       3f9f264f
 ✗ 2h ago      ~/dotfiles            Refactor install script          6b42ce33
   1d ago      ~                     Debug docker networking          3ab7bed7

1 session was open when the machine last went down — 'ai-sessions crashed' to review
```

- `●` (green) — session is running right now
- `✗` (yellow) — session was still open when the machine went down or the
  process died; it never exited cleanly

Full-text search finds the session where something was discussed — on a
terminal the results open in the picker, piped they print with snippets:

```console
$ ai-sessions search flaky cache | cat
   LAST ACTIVE  PROJECT               TITLE                        MATCHES  ID
 ✗ 2h ago      ~/work/my-project     Fix flaky integration test   2/2·12   3f9f264f
     …the flaky test only fails when the cache is cold…
```

Every term has to appear somewhere in the session; quote a group to match it
as a phrase (`search "flaky test"`). If nothing mentions all of them, the best
partial matches are shown instead, with a note. The `MATCHES` column reads
`terms matched / terms searched · matching messages`.

Results are ranked by relevance, not date. Ordered by, roughly in order of
weight: how many of your terms the session covers (rare terms count for more
than common ones), whether the whole query appears verbatim, whether a single
message hits several terms at once, terms in the session title, how often the
terms recur in your own prompts, and — as a nudge, not the ordering — how
recently the session was active. `--recent` restores plain reverse-chronological
order.

By default search matches conversation text (your prompts, the assistant's
replies, session titles). Add `--everything` to also match tool output —
command results and file contents — for "which session touched this
host/file?" hunts.

### When the words are wrong: `ask`

`search` can only find words you can spell. When the results are not what you
meant — the session said "certbot" and you typed "letsencrypt", or you only
remember the shape of the problem — `ask` hands the hunt to a Claude Code
session. It greps and reads the transcripts itself, and returns the sessions it
believes you meant, which then open in the picker like any other result:

```console
$ ai-sessions ask "where did I sort out the cert that keeps expiring"
» starting a claude session…
· thinking… (148 tokens)
» Bash grep -lic "certbot\|renew" ~/.claude/projects/*/*.jsonl
↳ ~/.claude/projects/-home-me-work/8c2f10ab-….jsonl (+13 more)  → Staging TLS renewal
· thinking… (255 tokens)
» Bash python3 - <<'EOF' import json path=…  → Staging TLS renewal
↳ 308 (+42 more)
· This is confirmed as the right session. (10s)
» writing up the answer
· done in 29s · $0.19

The session is 8c2f10ab — "Staging TLS renewal", three weeks ago. The renewal
hook fired before the reload, so the new cert sat on disk unused; it was fixed
by moving the reload into the deploy hook…

   LAST ACTIVE  PROJECT            TITLE                 MATCHES  ID
   3w ago      ~/work/my-project   Staging TLS renewal    high    8c2f10ab
     the hook ordering was worked out here
```

A hunt takes tens of seconds, so it narrates itself on stderr while it runs:
finished steps scroll, the step in flight stays on one line with a spinner and
the elapsed clock, and a step slower than 3s says how long it took. `»` is work
starting — a command, a file being read — `↳` is the head of what it found, and
`·` is the model's own commentary, or a wait on it with the reasoning tokens
ticking up so a long pause reads as thinking rather than as a hang. Whenever a
line mentions a session uuid, the session's title is appended (`→ Staging TLS
renewal`), so you can see which of your sessions is being dug through. Piped or
redirected, the same steps print as plain lines with nothing rewritten, and
stdout stays clean either way.

The summary above the rows carries the concrete details it found — decisions,
addresses, file paths — so a hunt often ends without reopening anything. The
`MATCHES` column shows how sure it is rather than a match count, and a session
id it cannot find on disk is dropped rather than offered.

**In the picker, Alt-Enter asks with whatever you have typed** (**Ctrl-G** does
the same, for terminals that swallow Alt-Enter) — so the normal path is to type
words, look at the ranked hits, and escalate the same query to `ask` when they
miss. Scope flags carry over (`--here`, `--project`), but `-n` does not: a query
that came up short should widen to every session in scope, not stay inside the
rows on screen. Pressing it with an empty query says so and returns you to the
picker.

`ask` runs `claude -p` in your home directory with a read-only toolset
(`Bash,Read,Glob,Grep` — the session has no Write or Edit tool at all), no MCP
servers, and `--no-session-persistence`, so searching for a session never adds
a session to the list you are searching. Otherwise it is a plain Claude Code
session: your model, your `CLAUDE.md`, no prompt surgery. `--model` picks a
cheaper model for the search, `--json` prints the answer and hits instead of
opening the picker, and `AI_SESSIONS_ASK_TIMEOUT` (default 600s) bounds it.
It costs a normal API turn or two — a typical hunt is well under a minute.

```console
$ ai-sessions crashed        # only the sessions left open at the last shutdown
$ ai-sessions search <terms> # find sessions by content, then resume one
$ ai-sessions ask <question> # let a claude session find it, then resume one
$ ai-sessions --here         # only sessions under the current directory
$ ai-sessions --project ~/work/my-project
$ ai-sessions -n 50          # show more rows
$ ai-sessions --json         # machine-readable output (full session ids, ISO timestamps)
```

`pick` uses [fzf](https://github.com/junegunn/fzf) if available and falls back
to a numbered prompt otherwise. Selecting a session changes into its original
working directory and execs the backend's resume command
(e.g. `claude --resume <session-id>`).

Inside the picker, **Alt-Enter** (or **Ctrl-G**) hands your typed query to
`ask` (see above) when the ranked hits miss, and **Ctrl-/** toggles a preview
pane showing the highlighted session's conversation — your prompts and the assistant's replies, with tool
output and metadata filtered out — so you can confirm it's the right session
before resuming.

Typing runs the same ranked search as `ai-sessions search`, over every
message rather than the visible row, and the `MATCHES` column and snippets
appear as soon as you have a query.

**Typing searches the sessions the picker is holding, and only those.** The
plain picker holds a recent window, so `-n` sets how far back both the list
and the search reach — `ai-sessions -n 200` searches 200 sessions, the
default searches 20. `--here` and `--project` narrow it the same way, and the
header names the population you are searching. `search <terms>` instead
populates from every session in scope, so a picker opened that way keeps
searching broadly; it also arrives holding your query, so you can keep
editing it rather than re-running the command.

Two consequences of searching content rather than the row: matching is by
whole terms, so fzf's fuzzy title matching (`sdgi` for
`synthetic-defect-generation-investigation`) no longer applies, and a query
that only matches a session's directory is listed after the content hits,
labelled `path`. Without `fzf` the picker falls back to a static numbered
prompt, which cannot search.

## Shell keybinding

To open the picker with a hotkey (here Alt+A), add a small ZLE widget to your
`~/.zshrc`:

```zsh
_ai_sessions_picker() {
  command -v ai-sessions >/dev/null 2>&1 || { zle reset-prompt; return }
  zle push-input        # stash any half-typed command line
  BUFFER="ai-sessions"
  zle accept-line
}
zle -N _ai_sessions_picker
bindkey '\ea' _ai_sessions_picker   # Alt+A (overrides accept-and-hold)
```

## Install

```console
$ git clone https://github.com/j-nordin/ai-sessions
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
- **Search** needs no index: one `grep -liF` pass per term narrows to the
  candidate transcripts and doubles as the document frequency behind the
  IDF weights, so rare terms outrank common ones. The candidates are then
  streamed line by line to match only conversation text (or everything, with
  `--everything`) and scored. Matching is case-insensitive fixed-string
  throughout — query case never affects results or ranking.

- **Ask from the picker** does not use fzf's `become`: fzf's stdout and stderr
  are the pipes the selection is read through, so a command that replaces fzf
  narrates itself into a pipe and looks like nothing happening. fzf reports
  the pressed key and the query instead (`--expect` plus `--print-query`), and
  the process re-execs itself as `ai-sessions ask` — on the terminal the
  picker was on.
- **Ask** spawns `claude -p` with a JSON-schema'd answer (`session_id`, `why`,
  `confidence` per hit, plus a prose `answer`), streams the session's tool
  calls to stderr as progress, and maps the returned ids back onto real
  transcripts — so the agent picks the session, but only ever from what is
  actually on disk. The candidate list (uuid, last-active, project, title) is
  handed to it in the prompt so it can shortlist before grepping.

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
