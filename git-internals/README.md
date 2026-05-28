# Git from the Inside Out

> Git is much smaller than its UI makes it look. Once you see the data model, the commands stop being scary.

A 90-minute hands-on session on the data model under Git: the object store, the index, refs and HEAD, the reflog. We deliberately stay below the porcelain —  the goal isn't more commands, it's a *map* of the moving parts beneath them.

## What's here

- [exercises.md](exercises.md) —  the main exercises (Ex 1, 2, 3) plus self-paced sidebar challenges.
- [setup-prepared-repo.sh](setup-prepared-repo.sh) —  creates `./prepared-repo/`, used from Ex 3 onward. Re-runnable: if you wreck your state mid-exercise, `rm -rf prepared-repo && bash setup-prepared-repo.sh` and you're back.

## How to use

1. Once at the start: `bash setup-prepared-repo.sh`
2. Open [exercises.md](exercises.md) and work Ex 1 → Ex 2 → Ex 3 in order.
3. Hints and partial-solutions are hidden behind `<details>` blocks. Try first, peek if stuck.
4. Sidebar challenges are optional —  pick one up if you finish a main exercise early.

## Going further

- **[*Pro Git*](https://git-scm.com/book) by Chacon & Straub** —  the comprehensive free reference. Chapter 10 ("Git Internals") dovetails directly with everything in this session.
- **[*Git from the Inside Out*](https://maryrosecook.com/blog/post/git-from-the-inside-out) by Mary Rose Cook** —  the cleanest written treatment of the data-model-first view; this directory's namesake.
- **`man gittutorial`, `man gittutorial-2`, `man gitcore-tutorial`** —  built-in deep dives. `gitcore-tutorial` is essentially "build git with plumbing," written by the project itself.
