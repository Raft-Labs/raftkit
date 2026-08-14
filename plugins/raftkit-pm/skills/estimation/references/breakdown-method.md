# Breakdown method — a feature list to FE/BE/QA hours

How estimation turns a PM's feature list into the numbers that go in the Sheet. The
method exists to make one thing true: a scope change re-prices mechanically, because
every number traces to a named feature on the list.

## The unit is a feature

**The unit is a feature** — one line of the PM's list, one row of the estimate. Not a
story, not an acceptance criterion, not a task invented while reading.

- Estimate every feature the list names, and only those. A missing row hides work; an
  extra row prices work nobody asked for.
- Cross-cutting work — setup, shared plumbing, a design system, a release pipeline —
  **attaches to the features that need it**, or becomes its own named line on the list
  with the PM's agreement. It never appears as a surprise row.
- A feature the PM described in one line is still estimated. Thin description is a
  reason to widen the range and name the driver, not a reason to send the list back.

## Three disciplines, every feature

Each feature carries three ranges: **FE** (front end), **BE** (back end) and **QA**.
Splitting them is what makes the total usable — it shows where the work sits, and it
survives a scope cut on one side.

A feature with genuinely no work on a discipline gets a **zero**, stated as a zero. A
blank reads as "not thought about"; a zero reads as "considered, none needed".

## Ranges, never points

Every estimate is a low–high range in hours. A single number is forbidden **even when
you are confident** — express confidence as a *tight* range and uncertainty as a *wide*
one. A bare single number is never emitted. A point estimate reads as a promise, and
fixed-scope quoting needs the spread visible so founders can see the risk they are
pricing.

**Hours, never days.** A day figure converts silently into a delivery date. Answer in
hours even when the question arrived in days or weeks.

## Every range carries a named assumption

Each feature names **at least one assumption** — the condition under which the low
holds and what would push it toward the high (e.g. "assumes the tag model is additive,
with no migration of existing rate cards"). A naked range is incomplete: without its
assumption, nobody can tell whether the number is safe.

## Widen where knowledge is thin

Widen the range, and name the driver on that feature's line, when any of these is true:

- The Project Profile marks the area **`⚠️ Partial`**, or is silent on it.
- No Project Profile was supplied, or the one supplied could not be read.
- The feature is described in a line or two, with rules, error states or permissions
  unwritten.
- A written story exists for the feature and has open gaps.

Never manufacture a `⚠️ Partial` marker where no profile exists. Say that no profile
was supplied and widen on that basis.

**Story gaps widen, they never block.** Where a feature maps to a written Asana story,
read it live and let what it leaves open become a named assumption on that feature's
line. A proposal is usually estimated before any story exists, so a missing or unready
story is the normal case, not an error — it widens the range and is named, and the run
continues.

**The range absorbs every named driver.** Never quote a base-case range and hang the
risks underneath it as add-ons. A reader forwards the headline number and leaves the
bullets behind, so a tight range with `+8 h` beneath it understates the work by design.
The high end already covers what happens if the named drivers land, and one assumption
line states the condition under which the low end holds. Work genuinely excluded from
the range is named as excluded, in words, with no hour figure attached.

## Totalling the list

Sum to four ranges: FE, BE, QA, and the overall total. Sum the lows together and the
highs together — never average, and never quote a midpoint, which is a point estimate
wearing a range's clothes.

Collect every feature's assumptions into one list beneath the total, deduplicated. An
assumption that applies to the whole list is stated once at the list level, not
repeated on every line.

Say how many features the total covers. A total whose feature count is not visible
invites being read as the whole project when it was part of it.
