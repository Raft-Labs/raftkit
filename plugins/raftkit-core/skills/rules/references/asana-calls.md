# Asana and Jam calls — ask only for what the run uses

Tool names drift; each call is named by what it does.

- **Fields.** Name the fields each read returns. Read a template or the Project Profile with comments off; a task read otherwise brings 10 comments and every follower.
- **Subtasks.** A task read lists subtask names, never bodies. Read every body the run needs, such as all Profile sections or a story's `[AC]`s, in one message of parallel reads.
- **Activity in a range.** One task-list read with completed-since at the range start returns every open task plus those completed since. Then read comments only for the open tasks touched in the range. Modified-since misses a change made only in a subtask.
- **Names.** Look up a member, tag or project with the workspace object search, never the task search, which needs Asana Premium.
- **Tools.** Load every connector tool the run needs in one tool search.
- **Writes.** Batch creates and updates into one call each, unless a write needs another's result.
- **Jam.** Console at error and warn. Network with its default bodies and no status filter, so a request that never got a status stays in view. Frames only for a visual defect.
