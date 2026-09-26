# Scheduling surfaces — calendars, schedulers, Gantt and booking

Library choice is in the Scheduler row of `product-packages.md`. Format dates with
`Intl.DateTimeFormat`. For grid traversal, see "Keyboard traversal" in `dense-ui-patterns.md`.

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The "without it" failures are an inference, not a measurement.

## The time model

1. **DST-safe date maths.**
   - Never add 86,400,000 ms for "one day". A DST transition day lasts 23 or 25 hours.
   - Do calendar arithmetic in the event's zone with a zone-aware API:
     - Temporal's `ZonedDateTime`. It ships in Chrome 144+ and Firefox 139+, but Safari has it
       only in preview, so it is not Baseline and needs a polyfill.
     - `@date-fns/tz` (`TZDate`), or Luxon.
   - Build each day column from a calendar date, never from midnight plus n × 24 h.
   - *Without it:* after a DST change, every event in the week view shifts by an hour, and one
     day has a missing or doubled row.
   - `recorded`
2. **IANA zones.**
   - For anything a person schedules, store the instant plus the IANA zone name
     (`Europe/Berlin`). Never store only an offset (`+02:00`) or an abbreviation: both change
     with DST and with law.
   - All-day events are dates, not instants.
   - Show times in the viewer's zone, and show the event's own zone when it differs.
   - A booking page names the zone and lets the invitee change it.
   - `recorded`
3. **RRULE plus exceptions.**
   - Store recurrence as an RFC 5545 RRULE, plus EXDATE for deleted occurrences and a
     RECURRENCE-ID override for one moved or edited instance.
   - Expand the rule in the series' own zone, so a 09:00 standup stays at 09:00 across DST.
   - Expand only the visible window, never the whole series.
   - Editing asks: "this event", "this and following", or "all events".
   - The long-standing `rrule` package has not been published since 2023. Treat that as a
     maintenance signal, and check what your scheduler library bundles before adding it.
   - *Without it:* a hand-rolled "every week" loop that drifts after DST and cannot delete one
     occurrence.
   - `recorded`

## Interaction

4. **Drag-move and resize need two other routes.**
   - **Keyboard.** With an event focused, a key picks it up, arrows move it by one grid slot
     (Shift+arrows resize it), Enter drops it and Escape cancels. Each step is announced
     ("Tue 10:30–11:00").
   - **A non-drag dialog.** Enter opens an edit dialog with date, start, end or duration, and
     zone fields. This is the SC 2.5.7 route, and it is the one screen-reader users actually
     use.
   - **Creating.** Enter on an empty slot creates an event in that slot.
   - Libraries rarely ship keyboard moves: check the row before trusting one.
   - `agent-graded` (SC 2.1.1, 2.5.7)
5. **Overlap layout.**
   - Overlapping events split the column width: group them into clusters, lay each cluster out
     in columns, and let each event take the widest free span.
   - Never stack events on top of each other.
   - Past a readable count, show "+2 more", which opens a list. Month cells use "+N more" the
     same way.
   - `recorded`
6. **Conflicts are not shown by colour alone.**
   - A conflict gets an icon and text ("Conflicts with Design review"), and it is announced when
     a keyboard move or a drag creates it.
   - The server stays the authority on availability. When it rejects a claim, re-render fresh
     availability and say what changed.
   - `agent-graded` (SC 1.4.1, 4.1.3)
7. **One tab stop per grid.**
   - A month or week grid is one tab stop with roving focus:
     - arrows move by day or by slot;
     - Page Up and Page Down move by month or week;
     - Home and End go to the edges of the week.
   - The events in a focused cell are a second level: Enter goes into the cell, arrows move
     among its events, and Escape returns to the cell.
   - *Without it:* every day and every event is a tab stop, which makes a month view 42 or more
     stops before any event is reached.
   - `agent-graded` (SC 2.1.1, 2.4.3)
8. **Names and now.**
   - Each event's accessible name gives the title, date, time range and, when it differs, the
     zone: "Standup, Tue 3 Nov, 09:00–09:15". The time is also in `<time datetime>`.
   - Today is labelled in words.
   - A current-time line marks now, and the view opens scrolled to working hours, not to 00:00.
   - `agent-graded` (SC 4.1.2)

A booking hold that expires follows the holds rule in `live-surfaces.md` (SC 2.2.1).
