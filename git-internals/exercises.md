# Git from the Inside Out — Exercises

## Before you start

- Run `bash setup-prepared-repo.sh` once. It creates `./prepared-repo/`, used from Ex 3 onward.
- Hints and partial-solutions are hidden behind `<details>` blocks. Try first, peek if stuck.
- Stuck for real? Ask. Today, confusion is shared currency.

---

## Ex 1 — The minimum valid repo

**Goal:** discover how little `.git/` actually has to contain in order to still be a "real" repository.

### Stage (a) — minimum where `git status` succeeds

In a fresh scratch directory:

```bash
mkdir -p /tmp/scratch-a && cd /tmp/scratch-a
git init
ls -la .git
```

Now start **deleting** files and directories inside `.git/`, one at a time (or in batches), re-running `git status` after each deletion. Your job: figure out how much you can throw away while `git status` still exits 0 with no errors.

**You'll know it worked when:** `.git/` is at its irreducible minimum — every further deletion breaks `git status`.

<details>
<summary>Hint if you're stuck</summary>

Git's error messages will not help you here — they tell you something is wrong, not what's missing. Two tactics:

1. Delete in *batches first* (the obviously decorative things), then one-at-a-time as you get close to the bone.
2. If you really want git to tell on itself: `strace -e trace=file git status`.

Things worth poking at: `hooks/`, `description`, `info/`, `branches/`, the `config` file, `objects/info/`, `objects/pack/`.

</details>

<details>
<summary>What "minimum" looks like (peek after you've tried)</summary>

A minimal working `.git/` for `git status` needs essentially:

- `HEAD` — a text file pointing at a ref, e.g. `ref: refs/heads/main`
- `objects/` — a directory (git needs somewhere to write objects)
- `refs/` — a directory (refs: branches and tags will be stored here)

Even `refs/heads/` may not need to exist — without it, git just interprets "the ref isn't there" as "the branch has no commits yet," which is exactly what a fresh repo looks like. Everything else in `git init`'s default output is convenience or default.

</details>

### Stage (b) — minimum where `git log` shows a real commit

In your already trimmed directory, or in a freshly initialized git directory:

```bash
echo "Hello, world!" > hello.txt
git add hello.txt
git commit -m "first"
git log
```

Now trim again. Delete files and directories inside `.git/` and re-run `git log`. How little can you keep and still see your commit?

**You'll know it worked when:** `git log` shows your commit with the message "first", and `.git/` is at its irreducible minimum.

<details>
<summary>Hint if you're stuck</summary>

`git log` needs three things, traced through the data model:

1. A way to know where to start. (Think: HEAD.)
2. A way to follow that to a commit. (Think: refs.)
3. The commit object itself — and what does a commit reference, recursively?

</details>

<details>
<summary>What "minimum" looks like</summary>

Roughly:

- `HEAD` → `ref: refs/heads/main`
- `refs/heads/main` → the commit SHA (40 hex chars + newline)
- `objects/<xx>/<yyyy…>` for **three** loose objects: the commit, the tree it points at, and the blob the tree references. Each lives in a two-char directory keyed off the first two hex of its SHA.

You can throw away `info/`, `hooks/`, `description`, `config` (yes — even that), `objects/info/`, `objects/pack/`, and the `index` file (the index isn't needed to *read* history, only to build new commits).

</details>

---

## Ex 2 — Build a commit by hand

**Goal:** construct a complete, valid commit using only **plumbing** commands (`git hash-object`, `git update-index`, `git write-tree`, `git commit-tree`) and direct file writes. No `git add`, no `git commit`.

### Setup

```bash
mkdir -p /tmp/scratch-2 && cd /tmp/scratch-2
git init
```

From this point on, you are not allowed to touch anything outside of the `.git/` directory. At the end, there should be a branch named `handmade` with a valid commit, which you can check out and run `git log` on.

### Tools you'll need

1. **To make the blob:** `git hash-object -w --stdin`

2. **To stage it in the index:** `git update-index --add --cacheinfo ...`. The syntax of `--cacheinfo` is weird — see cheatsheet below if stuck.

3. **To create the tree** from the index: `git write-tree`

4. **To create the commit object:** `git commit-tree <tree-sha> -m <commit message>`

5. **To point a branch at the commit:** nothing, just write the SHA into the appropriate file (so, `echo`)

For all these it's a good idea to run `git help <command>`, especially for `update-index`.

**You'll know it worked when:** `git checkout handmade` succeeds and `cat hello.txt` prints `Hello, world!`. Your hand-built commit is indistinguishable from anything `git commit` would have produced.

<details>
<summary>Cheatsheet</summary>

```bash
# Step 1: blob
BLOB=$(echo 'Hello, world!' | git hash-object -w --stdin)
echo "blob:   $BLOB"

# Step 2: index -- note the comma-separated tuple. This is `git add`'s job.
git update-index --add --cacheinfo 100644,$BLOB,hello.txt
# 100644 = regular file. Executable would be 100755. Symlink: 120000.

# Step 3: tree
TREE=$(git write-tree)
echo "tree:   $TREE"

# Step 4: commit
COMMIT=$(git commit-tree $TREE -m handmade)
echo "commit: $COMMIT"

# Step 5: ref
echo $COMMIT > .git/refs/heads/handmade

# Step 6: cash out
git log --oneline --graph --all
git checkout handmade
cat hello.txt
```

</details>

<details>
<summary>Alternative paths (just so you know they exist)</summary>

- **`git mktree`** is an alternative to `update-index + write-tree`: it builds a tree directly from `mode SP type SP sha TAB name` lines on stdin, without touching the index. Cleaner for one-shot construction — but it skips the index lesson, so we went the index way today.
- **`git update-ref refs/heads/handmade <sha>`** is the "proper plumbing" way to do step 5. It also takes care of proper locking and history management, but in the end, everything is just a file.

</details>

### Additional questions

- What happens if you do this (say, exactly the steps in the cheatsheet) in a non-empty repo? Try it in the `prepared-repo`!
- What goes wrong, and can you fix it?

---

## Ex 3 — HEAD, refs, and the reflog safety net

**Goal:** land three things in one short arc — HEAD is a pointer, detached HEAD is HEAD-pointing-at-a-SHA, and the reflog means you almost can't lose work locally.

### Setup

```bash
cd prepared-repo
git log --oneline
```

### Beat 1 — inspect HEAD

```bash
cat .git/HEAD
cat .git/refs/heads/main
```

What's HEAD pointing at? What's `main` pointing at? Notice HEAD points at a *ref*, not a commit directly.

Note: originally in Git `HEAD` was just a symlink to a ref. And it still works today:

```bash
rm .git/HEAD
ln -s refs/heads/main .git/HEAD
git status
```

You can even create commits and it will stay like that (until you switch branches). Why do you think it was changed?

### Beat 2 — detached HEAD demystified

Pick any commit SHA from `git log --oneline` — say, three or four commits back. Check it out directly:

```bash
git checkout <some-old-sha>
cat .git/HEAD
```

What changed in `.git/HEAD`? **That's detached HEAD.** It's not a special mode — HEAD is just a pointer, and right now it's pointing at a raw SHA instead of a ref.

Get back:

```bash
git checkout main
cat .git/HEAD
```

### Beat 3 — break it, then recover it

The scary part. From `main`:

```bash
git log --oneline | head
git reset --hard HEAD~5
git log --oneline | head
```

Five commits, gone. `git log` shows you can't reach them anymore.

Now recover with the reflog:

```bash
git reflog
# Find the entry just before the reset -- it'll say something like
#   HEAD@{1}: commit: Add utils.lower()    (or whatever was the tip before)
git reset --hard HEAD@{1}
git log --oneline | head
```

**They're back.** Locally, your work is *extraordinarily* hard to lose.

**You'll know it worked when:** the commits visible before the reset are visible again after the recovery.

<details>
<summary>The same trick rescues a deleted branch</summary>

Try this on the prepared repo:

```bash
git branch -D old-experiment
# Git warns about unmerged commits, but deletes the ref anyway.
git reflog --all | head
# Find a reflog entry for the deleted branch.
git branch old-experiment <sha-from-reflog>
```

Reflog tracks moves of every ref, not just HEAD. Objects themselves aren't garbage-collected for weeks (default `gc.reflogExpireUnreachable` is 30 days).

</details>

<details>
<summary>And if even the reflog is gone?</summary>

`git fsck --lost-found` finds objects in the store that nothing points at. The **Find the orphan** sidebar challenge walks through that case.

</details>

---

## Sidebar challenges

Self-paced. Pick one up whenever you finish a main exercise and want to go deeper. Roughly easy → hard.

### S1 — Dedup detective

In a fresh directory, run these exactly as given:

```bash
mkdir -p /tmp/dedup && cd /tmp/dedup
git init
echo "Hello, world!" > greet.txt
git add greet.txt
git commit -m "first"
echo "Hello, world!" > hello.txt   # same content, different path
git add hello.txt
git commit -m "second"
```

Two commits. Two distinct files, with identical content.

**Predict before you check:** how many *loose object files* are now under `.git/objects/`?

Then count:

```bash
find .git/objects -type f | wc -l
```

Then inspect the second commit's tree:

```bash
git cat-file -p HEAD^{tree}
```

What blob SHA does each path point at?

<details>
<summary>The payoff</summary>

Naively you'd expect 6 objects (one commit + tree + blob per commit). The actual count is **5**: two commits, two trees, and **one** blob. Because the blob is content-addressed and both files have identical content, the same blob is referenced by both trees — `greet.txt` and `hello.txt` are different *paths* pointing at the same blob SHA.

Content-addressing buys you deduplication, for free, at the storage layer. It's also how git can hold millions of mostly-similar trees across a long history without space exploding.

</details>

### S2 — Cat-only archaeology

In `prepared-repo/`, pick any commit SHA from `git log --oneline`. Now reach the contents of a specific file at that commit using **only `git cat-file`** — no `git log`, no `git show`, no `git ls-tree`, no `git diff`, no `git checkout`.

For extra credit: do it for a file inside a subdirectory (e.g. `src/main.py`), so you have to descend through a subtree.

**You'll know it worked when:** you've reached the blob's contents via a chain of `cat-file -p` calls.

<details>
<summary>Structural hint</summary>

`git cat-file -p <commit-sha>` prints the commit object, which names a tree. `git cat-file -p <tree-sha>` prints the tree's entries (mode, type, sha, name). Find the path you want; if it's a subtree, descend; eventually `cat-file -p` the blob.

You may also like `git cat-file -t <sha>` to ask "what type is this object?" without printing it.

</details>

### S3 — Find the orphan

This is what `git fsck` is for. We're going to truly orphan some commits — beyond what `git reflog` can save — and then recover them anyway.

In `prepared-repo/`:

```bash
git log --oneline old-experiment       # note some SHAs from this branch
git branch -D old-experiment           # delete the branch
git reflog expire --expire=now --all   # nuke all reflog entries
git fsck --lost-found
```

`fsck` will print lines like `dangling commit <sha>` and may drop the SHAs into `.git/lost-found/`.

**Your job:** find the tip of the (former) `old-experiment` branch in the dangling list and recreate it as a new branch.

<details>
<summary>Structural hint</summary>

Use `git cat-file -p <sha>` on the dangling SHAs to read their commit messages and confirm the right one, then:

```bash
git branch recovered <sha>
git log --oneline recovered
```

</details>

<details>
<summary>The deeper point</summary>

The reflog is your *first* safety net. `fsck --lost-found` is the second — every object stays in `.git/objects` for weeks even when nothing references it (`gc.pruneExpire` defaults around two weeks). To lose work locally you have to *try*: delete the ref, expire the reflog, *and* run `git gc --prune=now`. Almost nobody does all three by accident.

</details>

### S4 — Tree-fanout bomb

Construct a tiny `.git/` whose `git checkout` produces an exponentially large working tree. One blob + N nested trees, each containing two references to the inner tree. With N = 10, that's 2¹⁰ = 1024 paths from a `.git/` of maybe a kilobyte.

**Your job:** build the layered tree using plumbing, point a branch at a commit on top of the outermost tree, then `git checkout` it and count the resulting files.

<details>
<summary>Structural hint</summary>

`git mktree` is the cleanest tool. Its input is one entry per line:

```
<mode> <type> <sha>\t<name>
```

- `<mode>` is `100644` for blobs, `040000` for trees (yes, no leading zero issue — git accepts both).
- `<type>` is `blob` or `tree`.

Loop: start with a blob's SHA (and mode `100644`, type `blob`). Each iteration, build a tree containing two entries named `a` and `b`, both pointing at the *current* SHA. Then update the current SHA to be the new tree's SHA, and switch the mode/type to `040000` / `tree` for the next iteration. After N iterations, you have a tree N levels deep with 2ⁿ leaves.

Finally: `git commit-tree <final-sha> -m bomb`, `echo <commit-sha> > .git/refs/heads/bomb`, `git checkout bomb`, and `find . -path ./.git -prune -o -type f -print` should print 2ⁿ.

Keep N modest (≤ 12). 2²⁰ paths will not be fun.

</details>

<details>
<summary>The payoff</summary>

Compare `du -sh .git` with `du -sh --exclude=.git .`. The *stored* state is tiny because of content addressing (one blob, N trees), while the *materialized* state explodes because the working tree has to instantiate every path. Same trick (in spirit) behind sparse checkouts and the way reproducible-build systems share content across artifacts.

</details>

### S5 — Pure no-git construction

For the masochists. Build a valid repo with at least one commit using *only* file writes, zlib, and SHA-1. No `git` commands except for verification at the end.

**You'll know it worked when:** `git log` shows your commit in a repo you created without ever running `git`.

<details>
<summary>Structural hint</summary>

Every object on disk is `zlib.compress(<header><body>)` written to `.git/objects/<sha[:2]>/<sha[2:]>`, where `sha = sha1(header + body)`.

- **Blob:** header is `blob <body-len>\0`; body is the file contents.
- **Tree:** header is `tree <body-len>\0`; body is a concatenation of entries `<mode> <name>\0<20 raw bytes of sha>` (raw bytes, *not* hex), entries sorted by name byte-wise.
- **Commit:** header is `commit <body-len>\0`; body is text:

  ```
  tree <hex-sha>
  author Name <email> <unix-ts> +0000
  committer Name <email> <unix-ts> +0000

  <message>
  ```

Python is the natural tool (`hashlib`, `zlib`, raw file IO). Don't forget `HEAD` and `refs/heads/main`.

It will take longer than you'd initially expect, but it's worth the time!

</details>
