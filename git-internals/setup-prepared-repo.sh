#!/usr/bin/env bash
# Creates ./prepared-repo/ with a small git history for the
# "Git from the Inside Out" exercises.
#
# Re-run to reset:  rm -rf prepared-repo && bash setup-prepared-repo.sh

set -euo pipefail

REPO="prepared-repo"

if [[ -e "$REPO" ]]; then
  echo "Error: $REPO already exists." >&2
  echo "Remove it first:  rm -rf $REPO" >&2
  exit 1
fi

mkdir "$REPO"
cd "$REPO"

git init -q -b main
git config user.email "alice@example.com"
git config user.name "Alice"

c() { git commit -q -m "$1"; }

# --- main: linear history ---

echo "# Project" > README.md
git add README.md
c "Initial commit"

mkdir src
cat > src/main.py <<'EOF'
def greet(name):
    return f"Hello, {name}!"

if __name__ == "__main__":
    print(greet("world"))
EOF
git add src/main.py
c "Add main.py with greet()"

cat > src/utils.py <<'EOF'
def capitalize(s):
    return s.upper()
EOF
git add src/utils.py
c "Add utils.py"

# Executable script -- shows mode 100755 in the tree.
cat > run.sh <<'EOF'
#!/usr/bin/env bash
python src/main.py
EOF
chmod +x run.sh
git add run.sh
c "Add run.sh (executable)"

# Symlink -- shows mode 120000 in the tree.
ln -s src/main.py main.py
git add main.py
c "Add main.py symlink"

echo "MIT" > LICENSE
git add LICENSE
c "Add LICENSE"

# --- feature-x: branch off, merge back ---

git checkout -q -b feature-x
cat >> src/main.py <<'EOF'

def shout(name):
    return greet(name).upper()
EOF
git add src/main.py
c "feature-x: add shout()"

echo "- write tests" > TODO.md
git add TODO.md
c "feature-x: add TODO"

git checkout -q main
git merge -q --no-ff feature-x -m "Merge feature-x into main"

# --- a couple more on main after the merge ---

cat >> README.md <<'EOF'

## Usage

    ./run.sh
EOF
git add README.md
c "Document usage"

cat >> src/utils.py <<'EOF'

def lower(s):
    return s.lower()
EOF
git add src/utils.py
c "Add utils.lower()"

# --- old-experiment: a dangling-ish branch off an older commit ---

git checkout -q -b old-experiment HEAD~3
cat > experiment.md <<'EOF'
# Old experiment

This branch isn't reachable from main's tip.
Practice material for finding orphaned commits.
EOF
git add experiment.md
c "old-experiment: start"

echo "More notes." >> experiment.md
git add experiment.md
c "old-experiment: more notes"

git checkout -q main

echo
echo "Done. Created ./$REPO/"
echo
git log --oneline --graph --all
