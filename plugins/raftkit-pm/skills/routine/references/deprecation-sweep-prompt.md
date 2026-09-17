# Deprecation-sweep routine prompt

Fill the four `<ALL-CAPS>` blanks. Email needs no blank: the routine reads whatever inbox its own account can reach, so schedule it under the right account.

```text
Read, do not write. Create nothing, edit nothing, send nothing, file nothing —
in Asana, Slack, email, or anywhere else. Your only output is this run's report.

Sweep these three surfaces for anything needing attention:
  - Asana: the projects <ASANA PROJECT NAMES>
  - Slack: the channels <SLACK CHANNEL NAMES>
  - Email: the inbox this account can read

You are looking for third-party service notices: deprecations and end-of-support
or end-of-life dates, forced or recommended migrations, API-version sunsets,
price and plan changes, expiring certificates, domains, or credentials, and
security notices marked action-required. A vendor email that reads as routine
marketing is not a flag; a date with a consequence is.

For each flag report:
  - what the notice says, in one line
  - the deadline it names, and how far away that is
  - the source, cited exactly: email subject and date, Slack message link, or
    Asana task link — never a paraphrase without the source
  - which project it belongs to, if that is identifiable
  - the suggested next step:
      <ACTIVELY MAINTAINED PROJECTS>    -> "schedule the upgrade in this project"
      <NOT-MAINTAINED PROJECT NAMES>    -> "forward to the client — 'you may have
                                           missed this' — and offer a quote if
                                           they want it done"
  - anything touching budget, pricing, contracts, or a commitment to a client:
    label it FOUNDER REVIEW in capitals. Never present it as decided.

If a surface is unreachable, say which one and continue with the others. If a
sweep finds nothing, say exactly that — an empty report is a good report, and
you never invent a flag to have something to show.
```
