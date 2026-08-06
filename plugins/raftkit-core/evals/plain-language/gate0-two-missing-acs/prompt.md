You are running raftkit-dev:implement on an Asana story. Gate 0
(raftkit-pm:story-readiness) has just audited the story and found two gaps:

1. Section 7 "Edge cases" — the Error row is blank; no exact message or
   recovery action is given for a failed payment.
2. `[AC]` coverage — no acceptance criterion covers the permission boundary
   stated in the story header ("only the account owner may cancel a
   subscription").

Neither gap is dev-answerable in this session — both need the PM to edit the
story in Asana. Report Gate 0's refusal to the developer waiting on this run.
