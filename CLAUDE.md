# Dataverse Integration Redesign — BC AL Extension (Greenfield)

A from-scratch Business Central AL extension that **redesigns Microsoft's Dataverse integration layer**
(CDS, Dynamics 365 Sales/CRM, Dynamics 365 Field Service) around the polymorphic pattern. It is a new
implementation, not a Navision/NAV port. **This repository is public.**

## Authoritative rules live elsewhere — read them first

This project follows the owner's private BC conventions, wired in locally as directory junctions
(gitignored) that **override this file** if the two disagree:

| Need | File |
|---|---|
| Coding standards (naming, namespaces, cops, labels, **no custom publishers** §4b) | `.bc-conventions/instructions/02-al-coding-standards.md` |
| Folder + file naming | `.bc-conventions/instructions/03-source-folder-layout.md` |
| Per-object-type authoring guide | `.bc-conventions/al-object-types/<type>.md` |
| Polymorphic table logic (**mandatory**) | `.bc-conventions/al-object-types/_patterns/polymorphic-table-logic.md` |
| Event subscriber proxies | `.bc-conventions/al-object-types/_members/event-subscribers.md` |
| Feature setup + `Enabled` toggle | `.bc-conventions/al-object-types/_patterns/feature-setup-and-toggle.md` |
| Testing | `.bc-conventions/instructions/05-testing-standards.md` |
| Greenfield feature workflow | `.greenfield/instructions/02-feature-workflow.md` |
| Definition of done | `.greenfield/checklists/feature-ready.md` |

`.bc-conventions` points at the base (customer-project) template and `.greenfield` at the greenfield template
of the conventions repository. A clone without them cannot build (`tools/build.ps1` needs the shared ruleset).

**Public-repo rule:** never commit content of the private conventions (no copied guides, no ruleset copy, no
repository name) and nothing from the owner's private product repositories.

## Project-specific values

| What | Value |
|---|---|
| App | `Dataverse Integration Redesign`, publisher `matr` |
| Affix | `DVI` (`app/AppSourceCop.json`, `test/AppSourceCop.json`) |
| Namespace root | `DataverseIntegration.<Feature>` — `Core`, `CDS`, `CRM`, `FieldService`; tests `DataverseIntegration.Test` |
| Object IDs | app `80000..83999` (Core 80000–80199, CDS 80200–80399, CRM 80400–80799, Field Service 80800–81199; 81200–83999 free); test `84000..84999`. Block 7 of the owner's ID range registry; never use IDs outside it |
| BC target | **29.0** W1 (`application` 29.0.0.0, runtime 18.0), artifact `sandbox/29.0.54011.55616/w1` |
| Dependency | Microsoft **Field Service Integration** 29.0 (`1ba1031e-eae9-4f20-b9d2-d19b6d1e3f29`); CDS and CRM are in the Base Application |
| Distribution | Per-tenant extension, `target: Cloud` |

## Environment

| | |
|---|---|
| Dev container | `bc29loc` — BC 29.0.54011.55616 W1, Field Service Integration installed |
| Auth | NavUserPassword (`"authentication": "UserPassword"` in `launch.json`) |
| Dev endpoint | `http://bc29loc:7049/BC/dev`, web client `http://bc29loc/BC/?tenant=default` |

`app/.vscode/launch.json` and `test/.vscode/launch.json` are committed and target bc29loc, so **AL: Download Symbols**
works right after cloning (VS Code prompts for the container credentials; none are stored in the repo).

## Symbols and building

Symbols come either from the container (VS Code **AL: Download Symbols**, prompts for the container
credentials) or from the local artifact cache, which holds the identical build. `tools/build.ps1` uses the cache:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1            # app + test
powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Project app
```

`tools\test.ps1` publishes both packages to bc29loc and runs the test app (BcContainerHelper, elevated PowerShell,
prompts for the container user).

`tools\build.ps1` refreshes `.alpackages`, compiles with CodeCop, UICop, AppSourceCop and PerTenantExtensionCop using
`dvi.ruleset.json` (which includes the shared ruleset), then copies the fresh app package into
`test/.alpackages`. **Zero errors and zero warnings** is the bar.

## Reading Microsoft's code

Read Microsoft objects from the symbols or from the source archives in the artifact cache
(`platform/Applications/BaseApp/Source/Base Application.Source.zip`,
`platform/Applications/FieldServiceIntegration/Source/Field Service Integration.Source.zip`). Never assume an
event name or signature.

## Git

- Branch per change, created with `git checkout -b <branch> --no-track origin/main`; push with
  `git push -u origin <branch>`; open a PR to `main`. **Only the owner merges PRs.**
- Git identity and the `gh` credential helper are repo-local (global config is kept empty).
