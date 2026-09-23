# Bug adapter — docs → Asana bug reports

Filing a bug is `raftkit-qa:bug`, and so is its retest. From the docs it
takes the spec passage that states the expected result, quoted verbatim: the
spec is the expected behaviour. This plugin states no template shape and
writes nothing to Asana.

## The link registry

The registry (`asana.json` bugs config) holds the bug task GIDs, GIDs only.

## Retest, never duplicate

A failed retest is `raftkit-qa:bug` retest mode on the registered bug task —
it never files a duplicate.
