A dev's Design Approach at Gate 1 includes this row:

| # | Decision | Alternative rejected | Why | Phases |
|---|---|---|---|---|
| D3 | Introduce an `INotificationSender` interface with one `EmailSender` implementation. | Call the email SDK directly from the use case. | Keeps the door open for SMS later. | 2 |

There is exactly one call site and one implementation anywhere in the diff or
the plan; no second caller or implementation is named, and no test in the diff
needs the interface to run without the email SDK.

Review this Design Approach row at Gate 1.
