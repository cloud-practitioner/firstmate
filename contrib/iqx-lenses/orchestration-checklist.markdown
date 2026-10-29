# Orchestration checklist (run-proof lens and panel)

Fork-only. IQX Bitbucket work only. Never offered upstream. See `README`.

This file is the lessons of earlier run-proof runs, sent to the lens before its work starts.
The generator embeds all of it in a run-proof brief, and embeds only the "Known S4P facts" block in a panel or shadow brief.
It is for the Orchestration module first.
Another module gets its own file in this folder when it has its own lessons.

Upkeep rule: every entry has a "Leaves the list when" line.
When a repository test covers a class, remove the entry in the same change that adds the test.
After each ticket, add the new classes the run found and drop what no longer earns its place.
An entry with no finding in five runs moves to "Retired" with a one-line condition to bring it back.

Evidence labels used below: `simulator-tested`, `S4P-seen consequence`, `needs a live check` (the lens text defines them).

## 1. Seeds

A seed is an attack class that the lens tries on every plan in scope.
Seeds made for the ticket (section 1.9) come from the plan's own premises and test list, and found most of the defects in the first runs.

### 1.1 A success answer when nothing was applied

- Attack: find a call where the answer is `success` but SAP did not change. Check "already there", "nothing to end", "already absent", and a model with no row left.
- Probe: assert the SAP state after the call, not only the answer.
- Found on: every ticket in the first runs.
- Leaves the list when: a repository test runs each Scenario outcome against the simulator state and fails when `success` leaves SAP unchanged without a named reason.

### 1.2 A Resume after an unknown outcome, with a corrected request

- Attack: a create gets no answer (lost, `unknown`, `@retryable: true`). Before the Resume, the source corrects the value under the same row id. Does the Resume create a second record that no Run Log names?
- Probe: lose the answer and the key re-read, correct the value, Resume. Print SAP after each call.
- Found on: three bundles; the same gap is in older Scenarios (a runner-wide follow-up).
- Leaves the list when: a runner-wide repository test covers a lost create followed by a corrected request on every keyed create.

### 1.3 A Resume after the target changed

- Attack: between the first call and the Resume, the partner or supplier the run points at is another one. Does the Resume write to the new target, or split one run across two targets?
- Probe: change the target in the model or in SAP, Resume, list every write with its URL.
- Found on: one bundle (a blocker on the shared runner).
- Leaves the list when: a runner-wide repository test covers a changed target on Resume for every bundle step.

### 1.3a A Resume after a newer opposite event

- Attack: an older event whose write has not succeeded yet is Resumed after a newer opposite event (a deactivation after a reactivation, an end after a create). Does the Resume undo the newer one?
- Probe: run the newer event to success, then Resume the older one. Check the last-change guard covers every state of the older run: not reached, failed, unknown, deadline stop.
- Found on: one bundle (a blocker; no cheap fix in the module, so it was named as a limit).
- Leaves the list when: a repository test covers an older Resume after a newer opposite event for every state of the older run.

### 1.4 A bundle splits or joins atomic calls

- Attack: a bundle puts Nodes in other calls than the atomic Scenario did. List the guards that each atomic Scenario applies across one call (reserved keys, all-or-nothing end checks, call-wide target checks, one read for the whole call). Ask what each guard does after the split or the join.
- Probe: one probe for each guard, with the split or join the plan describes.
- Found on: three tickets.
- Leaves the list when: a repository test lists the call-wide guards of each atomic Scenario and runs them under a split and a join.

### 1.5 SAP's state read as proof of our own action

- Attack: the plan reads a SAP flag, row or date and treats it as proof that this module did something earlier. Probe both ways: someone else set the flag; our action's other effects are there without the flag.
- Found on: one ticket (a deletion flag read as "our deactivation").
- Leaves the list when: a repository test covers each state read that a Scenario treats as proof of its own earlier write.

### 1.6 A published outcome against the runner's rule

- Attack: take each outcome sentence, table or `@status` / `@retryable` value that the plan or the docs publish, and run the case it describes on the real runner. A rule such as "a failure of this kind stops the Resume loop" must hold for every pair of fixes that touch the same output field.
- Probe: run each published row. Run each pair of fixes that write the same output field together.
- Found on: three tickets.
- Leaves the list when: a repository test generates the published outcome table from the runner's rules, or checks each documented row against the runner.

### 1.7 Identity unit, target check and PATCH from a whole row (narrowed)

- Attack: a key not checked again between steps; a write to the wrong partner; a PATCH that changes a key field.
- Seed these only when the plan changes the identity unit, changes the target check, or builds a PATCH body from a whole row. The shared code is mature, and these found nothing when the plan did none of those.
- Leaves the list when: a repository test covers each of the three on the shared code and the plan does not change it.

### 1.8 Retired seed: a Resume sends a succeeded write again

- Result: no finding in five runs; ten probes dropped.
- Brought back only when the plan touches the runner's Resume path or adds a hook that writes.
- Replaced by the three Resume seeds above (1.2, 1.3, 1.3a).

### 1.9 Seeds made for the ticket

- For each premise the plan states about stored data or SAP behaviour, and each test the plan lists, make one attack.
- Do not drop a hypothesis because of the threat model when the plan lists it as a test.
- Leaves the list when: never; this is the method, not a class.

## 2. Fixed checklist for every run

Run each item on every plan in scope, even when no seed points at it.
It costs a few minutes.
The point of each item is the check, and the probe asserts the intent.

### 2.1 A padded SAP number on every view

- Check: a supplier or partner number in SAP's padded form (leading zeros) on every row, view and comparison the plan adds. Compare with the same-number rule, never `!==`.
- Found on: three tickets; still present in older code.
- Leaves the list when: a repository conformance test sends the padded form to every place that compares a supplier or partner number.

### 2.2 A blank value from a second writer of the same field

- Check: another writer of the same SAP field (the model view, an onboarding call, a re-screening). A blank value must never mean delete (the module's rule that a delete is explicit).
- Found on: one ticket.
- Leaves the list when: a repository test sends a blank value through each writer of each shared field.

### 2.3 `@delete: false` where "omitted" means false

- Check: a row with `"@delete": false` must behave as a row without `@delete`, in every endpoint that reads the row.
- Found on: one ticket (a 400).
- Leaves the list when: a repository test sends `"@delete": false` to every endpoint that reads `@delete`.

### 2.4 The customer's local date against UTC

- Check: a date the source means as the customer's local date, against the UTC run date, in both directions around local midnight and UTC midnight. A queued event may run after UTC midnight.
- Found on: one ticket (a refusal for about 11 hours each day in one time zone).
- Leaves the list when: a repository test runs date rules with a local date one day ahead of and one day behind UTC.

### 2.5 History rows that the caller sends again

- Check: a source that sends the full history with every event. A history row SAP does not hold, or holds with another value, must not block a plain end or make every later event `partial`.
- Found on: one ticket.
- Leaves the list when: a repository test sends history rows again with each event type.

### 2.6 Personal data in a shared sentence

- Check: a sentence that goes to the Run Log, to ICS or to a shared channel must not print a key or value that is personal data or a business secret (a tax number, an identification number, a name).
- Found on: one ticket.
- Leaves the list when: a repository test scans every sentence a Scenario can publish for the values of the request.

### 2.7 For each acceptance test, the simulator switch or value list it needs

- Check: for each acceptance test the plan lists, write down the simulator switch, value list or entity it needs (section 3). A test that needs one the simulator lacks is a finding of its own: either "needs a live check" or a simulator change in the plan.
- Found on: three tickets.
- Leaves the list when: each acceptance test carries its simulator requirements in the repository, and the plan template has a field for them.

## 3. Simulator switches and gaps

Update the simulator list from the repository before each run; this section is the last known state.

### 3.1 `strictDefaultUsage` is off by default

- Effect: with it off, the default-usage class gives a false pass.
- Action: turn it on in every probe for that class and say so in the report.
- Leaves the list when: it is on by default in the test world.

### 3.2 `dropFields` is needed for "accepted but not stored"

- Effect: S4P can answer 2xx for a field and not store it. The simulator stores it unless `dropFields` names it.
- Action: use `dropFields` for each field the plan says SAP might not store.
- Leaves the list when: the simulator drops the known fields without a switch.

### 3.3 No `BUT_TDTRANS` table

- Effect: the simulator cannot show the due rows that stop the nightly business-partner job. The run proves the write; cited S4P evidence proves the consequence. Label it `S4P-seen consequence`.
- Leaves the list when: the simulator models `BUT_TDTRANS`.

### 3.4 No `TQ02B` value list

- Effect: the simulator does not check the value list, so a value that S4P refuses passes offline.
- Action: label anything that depends on the value list `needs a live check`, and give the check as an option.
- Leaves the list when: the simulator checks the value list.

### 3.5 No `A_BuPaIdentification` entity until it is built

- Effect: a plan that uses identifications has no simulator entity. The lens adds a scratch entity (list with `$filter`, key read, POST that refuses a repeated key, PATCH) and says so.
- Leaves the list when: the entity is in the simulator.

### 3.6 Wall clock against the fixed simulator date

- Effect: some model rules use the wall clock while the simulator date is fixed (2027-01-15 in the first runs). A date rule can pass or fail only because of today's date.
- Action: pin both clocks in the probe, or print both.
- Leaves the list when: the model rules read the simulator clock.

### 3.7 Put the plan's S4P data shapes into the simulator first

- Action: for each stored-data premise in the plan (an empty end date, an empty country on every row, a default flag), set the simulator to that shape before probing.
- Found on: two tickets (two findings came only from this).
- Leaves the list when: the simulator seed data matches S4P for the shapes in section 4.

## 4. Known S4P facts

These are the facts about S4P that an offline run cannot see.
Give them to every reviewer.
A finding or a recommendation that depends on one of them says `needs a live check` or `S4P-seen consequence`.
Each fact leaves the list when the simulator models it, or when a live check disproves it.

<!-- BEGIN known-s4p-facts -->
- **Nightly business-partner job.** The job `SAP_BUPA_BUPTDTRANSMIT` aborts when due rows exist for dated changes (the `BUT_TDTRANS` rows). A dated end on an address or a bank row can create one. SAP Notes 3761403 and 3721395 are implemented on S4P. The simulator has no `BUT_TDTRANS`. (S4P-seen.)
- **Value lists.** S4P checks value lists that the simulator does not, for example `TQ02B`. A value that passes offline can be refused on S4P. (needs a live check.)
- **How S4P stores an open date.** An open validity end is stored as an empty value, not as a far-future date. A reader that treats an initial date (year 1) as "ended" gets an open record wrong. (S4P-seen.)
- **Empty fields on stored rows.** Rows that SAP holds can have fields empty that the source always sends (for example the country on an identification). A rule that compares all fields treats the held row as "other values". (S4P-seen.)
- **Equal addresses.** S4P accepts two addresses with the same fields. A rule of "refuse a duplicate" does not match what S4P does. S4P has no address usage values for remit-to or ordering. (S4P-seen.)
- **2xx without storing.** S4P can answer a PATCH with 2xx and not store a field (seen for bank data). Read after write. (S4P-seen.)
- **Padded numbers.** SAP returns business partner and supplier numbers in padded form; the source sends them unpadded or padded. Compare with the same-number rule.
<!-- END known-s4p-facts -->

## 5. Plan-author cross-check (before each revision)

This is a rule for the plan author, not for a reviewer.
Before each plan revision, list the fixes that touch the same output field, and the fixes that touch the same SAP field from two writers.
Probe each pair together.
Two accepted fixes from two reviewers collided on the same output field in a first run, and no single reviewer saw both.
Where recurring classes of section 1 and 2 have a repository test, the plan cites it instead of re-arguing the class.
