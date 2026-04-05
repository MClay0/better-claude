# Global Claude Instructions

Always select and use the most appropriate agent from ~/.claude/agents/ for the current task. Do not default to a generic response when a specialized agent exists that fits the problem.

When a task looks like feature planning or starting a new project, ask if the user would like to use the `/prd` skill before proceeding.

When a task involves debugging or investigating a bug, ask if the user would like to use the `/systematic-debugging` skill before proceeding.

Never add `Co-Authored-By` trailers to commit messages.
