## Summary

<!-- What does this PR change and why? -->

## Scope

- [ ] `Docker/stacks/` (deployed state)
- [ ] `Docker/config/` (host-level config)
- [ ] `Migrations/` (staged, not yet deployed)
- [ ] `Scripts/`

Affected stack(s) / migration item:

## Verification

- [ ] `docker compose config` validated (no syntax errors) for any changed `compose.yaml`
- [ ] Tested on the host: `docker compose up -d` in the affected stack directory
- [ ] Proxied hostname(s) confirmed working through NPM, if applicable
- [ ] `.env.example` updated if new variables were introduced
- [ ] Relevant guide in the [`Homelab-wiki`](https://github.com/praclarush/Homelab-wiki) repo updated if deployed behavior changed

## Downtime

- [ ] No downtime expected
- [ ] Downtime required (describe below, including which stacks/services are affected)

## Rollback

<!-- How to revert if this causes a problem on the host -->
