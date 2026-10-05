#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
LAB=$ROOT/.validation-tmp/home
mkdir -p "$LAB"/{data,state,config,projects,tmp}
cp .tasks.toml "$LAB/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
printf 'kind=scout\nmode=scout\nharness=codex\n' > "$LAB/state/audit.meta"
export FM_HOME="$LAB" FM_STATE_OVERRIDE="$LAB/state" FM_DATA_OVERRIDE="$LAB/data" FM_CONFIG_OVERRIDE="$LAB/config" TMPDIR="$LAB/tmp"
cap() { "$ROOT/bin/fm-captain-hold.sh" "$@"; }
tasks() { (cd "$LAB" && tasks-axi "$@"); }
refuse() { local rc=0; "$@" || rc=$?; printf 'exit=%s (refusal required)\n' "$rc"; test "$rc" -ne 0; }
echo '=== Create, answer, and complete approval ==='
cap hold repair-approval --title 'Approve local security repair' --reason 'Approve bounded repair' --origin audit
printf 'zatwierdzam\n' > "$LAB/answer.txt"
cap answer repair-approval --decision-file "$LAB/answer.txt"
cap complete audit repair-approval
tasks prune --keep 0
refuse tasks show repair-approval
cp "$LAB/data/done-archive.md" "$LAB/original.md"
echo '=== Archived approval remains verifiable without altering records ==='
sha256sum "$LAB/data/"*.md > "$LAB/before"
cap verify audit
cap complete audit repair-approval
sha256sum "$LAB/data/"*.md > "$LAB/after"
cmp "$LAB/before" "$LAB/after"
cat "$LAB/data/done-archive.md"
echo '=== Reject invalid archived approvals ==='
for variant in absent mismatched unresolved unrecorded open duplicate mixed; do
  echo "--- $variant ---"
  case "$variant" in
    absent) : > "$LAB/data/done-archive.md" ;;
    mismatched) sed 's/Captain hold origin: audit/Captain hold origin: other/' "$LAB/original.md" > "$LAB/data/done-archive.md" ;;
    unresolved) sed 's/Resolution recorded by fm-captain-hold\./Unresolved record./' "$LAB/original.md" > "$LAB/data/done-archive.md" ;;
    unrecorded) sed '/Captain hold origin:/d' "$LAB/original.md" > "$LAB/data/done-archive.md" ;;
    open) sed 's/^- \[x\]/- [ ]/' "$LAB/original.md" > "$LAB/data/done-archive.md" ;;
    duplicate) cat "$LAB/original.md" "$LAB/original.md" > "$LAB/data/done-archive.md" ;;
    mixed) cat "$LAB/original.md" > "$LAB/data/done-archive.md"; sed 's/^- \[x\]/- [ ]/' "$LAB/original.md" >> "$LAB/data/done-archive.md" ;;
  esac
  refuse cap verify audit
  refuse cap complete audit repair-approval
done
cp "$LAB/original.md" "$LAB/data/done-archive.md"
echo '=== Active unresolved identity overrides archived approval ==='
tasks add repair-approval 'New unresolved approval' --kind captain --repo sample
refuse cap verify audit
refuse cap complete audit repair-approval
tasks rm repair-approval
echo '=== Archived entries cannot be mutated by answer ==='
refuse cap answer repair-approval --decision-file "$LAB/answer.txt"
echo '=== Relocated configured archive ==='
mkdir "$LAB/history"
mv "$LAB/data/done-archive.md" "$LAB/history/approved.md"
sed 's|archive = "data/done-archive.md"|archive = "history/approved.md"|' "$LAB/.tasks.toml" > "$LAB/new-config"
mv "$LAB/new-config" "$LAB/.tasks.toml"
cap verify audit
cap complete audit repair-approval
echo '=== Empty archive configuration refuses ==='
sed 's|archive = "history/approved.md"|archive = ""|' "$LAB/.tasks.toml" > "$LAB/new-config"
mv "$LAB/new-config" "$LAB/.tasks.toml"
refuse cap verify audit
