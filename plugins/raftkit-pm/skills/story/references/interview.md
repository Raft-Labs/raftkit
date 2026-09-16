# Interview — when the sources are thin

Ask in batches of up to eight related questions per turn, recommendation first ("I'd assume X unless you say otherwise"), and skip anything an earlier answer settled. No explain-it-back turn, no recap turn: the draft is the recap. Two answers that contradict are named together and asked once more.

Depth: **quick** covers the headline of each lens; **exhaustive** adds the follow-ups. Default quick unless the idea is going to be built; say which is running. An answer that names money, personal data, auth, deletion or an external service gets the follow-ups even on quick.

| Lens | Headline |
|---|---|
| Business | What should this let someone do that they cannot today, and who benefits? Success in a number? |
| User | Walk it working, start to finish, for one real person. First visit, second run, undo. |
| Product | Where does it live (web, mobile, admin, email, API)? Screens, actions, empty/loading/error/success copy. |
| Permissions | Who uses it, who is explicitly blocked, and what does the blocked person see? Server-enforced or hidden? |
| Admin | Can the team see, change or reverse it afterwards? History, approval, reporting, support. |
| Rules | What must always hold, even when inconvenient? Limits per person, plan, period; contract or regulation constraints. |
| Data | What gets stored, what is personal, how long it is kept, what happens on delete, what must be unique. |
| Side effects | Emails, push, scheduled jobs, other systems told. Who, when, can they turn it off? |
| Edge cases | For each row the template lists (waiting, empty, error, success, limits, defaults): what happens? The error row needs the exact message and the next step. |
| Dependencies | What must exist first: features, teams, services, accounts, contracts? Behaviour when it is unavailable. |
| Scope | What is deliberately not in this? What gets cut if the deadline moves? Now versus later. |

Every answer lands in the draft as a fact with its source: "you said, <date>". Anything still unknown after the interview is a numbered question at the top of the draft, never an assumption inside an `[AC]`.
