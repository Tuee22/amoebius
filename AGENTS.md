## Git Restrictions

LLMs must not run `git add`, `git commit`, or `git push`.

Staging, committing, and pushing changes are reserved solely for the human user.

## Image Rebuild Prompt

The four `amoebius-base-{cpu,cuda}-{amd64,arm64}` tags are published artefacts, and a
consumer pulls them rather than rebuilding them. Their names are fixed rather than derived
from the recipe's content, so when the rendered image recipe or the bake catalog it
projects changes, the published tags no longer match the repository and nothing reports
that: a stale pull succeeds. So when a change touches the recipe or the catalog, prompt the
user to rebuild and repush all four tags before treating the change as landed.

Only the user runs the rebuild. An LLM may not push an image for the same reason it may
not push a commit — publication is an outward-facing act reserved to the human user.

This obligation is a consequence of the fixed names, not of publication itself, and it
retires when a tag becomes the recipe's content address: a changed recipe would then have
an address the registry does not hold, so a consumer rebuilds instead of pulling something
stale. That target is stated in `documents/engineering/image_build_doctrine.md` section
2.1; until a phase delivers it, the prompt above stands unchanged.
