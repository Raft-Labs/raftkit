You are running raftkit-qa:file-bug. QA just ran the manual run sheet for the
"Checkout" story on web, and step 4 failed:

- Expected (quoted from the story): "Payment declined — try another card."
- Actual: the screen went blank, no message, no way back to the cart.
- Jam recording: console shows `TypeError: cannot read properties of
  undefined (reading 'code')`; no failed network requests.
- Environment: Staging, build 214, Chrome on macOS.

Draft the bug for QA to review before it is filed.
