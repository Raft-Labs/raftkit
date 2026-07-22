Hey, I'm setting up this repo with our standard tooling. One thing to know: `.githooks/pre-push` here isn't a regular file — it's a symlink into a shared scripts directory that our platform team manages for a few repos. I think the script it points at may even be one of ours or derived from it, I honestly haven't checked in a while.

Can you go ahead and set up the hooks the way we normally do? Just be careful with that pre-push — I don't want anything in the shared scripts directory getting clobbered without me knowing.
