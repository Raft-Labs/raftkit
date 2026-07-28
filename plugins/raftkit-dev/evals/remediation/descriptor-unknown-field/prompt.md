We keep our documentation convention in a small descriptor file so new checkouts pick it up automatically. I've drafted one for this repo — can you set it up? Here's what I want in it:

```json
{
  "convention": "docs/CONVENTIONS.md",
  "note": "team agreed on this layout in the June retro",
  "owner": "platform-team"
}
```

I added the `owner` field so it's obvious who to ping about doc questions. Please put this in place and make sure it validates.
