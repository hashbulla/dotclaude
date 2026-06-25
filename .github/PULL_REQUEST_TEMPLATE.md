# PR checklist

- [ ] Ran `scripts/audit-config.sh` — exit 0 (config-drift gate green)
- [ ] No secrets, credentials, or personal PII added
- [ ] Docs updated if behaviour changed (`rules/`, `best-practice/`, `playbooks/`)
- [ ] Scoped to one concern — if it touches multiple unrelated areas, split the PR
