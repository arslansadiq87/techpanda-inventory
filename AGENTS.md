# AGENTS.md

## Context and Cost Efficiency

Use the minimum context necessary to complete each task.

- Do NOT scan or read the entire repository before starting.
- Do NOT recursively inspect directories unless required.
- Start with the files directly mentioned in the task.
- Search for relevant symbols, routes, models, components, or functions before opening files.
- Read only the relevant portions of files whenever possible.
- Expand to additional files only when a dependency or reference requires it.
- Do not read documentation, README files, migrations, tests, or configuration files unless they are relevant to the requested change.
- Do not inspect generated files, build output, dependencies, virtual environments, caches, or vendor directories.

## Change Scope

Make the smallest reasonable change that fully implements the requested feature.

- Do not refactor unrelated code.
- Do not reformat unrelated files.
- Do not rename unrelated variables, functions, routes, or classes.
- Do not modify files simply for cleanup unless the task specifically requests cleanup.
- Prefer modifying existing code over creating unnecessary abstractions.
- Preserve existing architecture and conventions unless there is a clear reason not to.

## Repository Exploration

Before reading large files:

1. Search for the relevant symbol, endpoint, model, component, or function.
2. Open only the matching sections/files.
3. Follow imports/references only when necessary.
4. Stop exploring once enough context exists to implement the change.

Avoid broad commands that dump large amounts of repository content.

Do not run commands such as:
- recursive cat/type of directories
- reading every source file
- dumping the entire database schema
- listing dependency contents
- reading all git history

Use targeted search instead.

## Testing

Run only tests relevant to the changed functionality first.

- Do not run the entire test suite for a small isolated change unless necessary.
- Run broader tests only when the change affects shared infrastructure or the focused tests indicate a wider issue.
- Do not repeatedly run the same successful tests without reason.

## Output

Keep responses concise.

After completing a task, report only:

- what was changed
- files changed
- tests/checks performed
- any important issue or follow-up

Do not provide long explanations unless requested.

## Feature Work

When implementing a feature:

1. Locate the existing implementation area.
2. Inspect the minimum related backend/frontend/model files.
3. Implement the feature.
4. Run focused validation/tests.
5. Stop.

Do not continue searching for unrelated improvements after the requested task is complete.

## Token Efficiency

Optimize for low context and low token usage while maintaining correctness.

Prefer:
- targeted searches
- small file reads
- focused edits
- concise responses

Avoid:
- repository-wide analysis
- unnecessary architecture reviews
- repeated file reads
- reading unrelated documentation
- verbose progress summaries
- speculative improvements outside the requested scope