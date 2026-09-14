# Time columns — what each engine actually stores

> Last verified: not fetched — written 2026-09-10 from training knowledge (model cutoff
> June 2026); MySQL 8.0/8.4, MariaDB 10.6–11.x, PostgreSQL 14–17 assumed. Version-pinned
> claims are marked; confirm on the installed server before relying on one.

Standing: **recorded** — loaded with the sql skill (via the `/code-review:review` fan-in or the router) for a diff touching a
`TIMESTAMP`/`DATETIME`/`timestamptz` column, a default, or a date-range predicate.

## The one rule, and what it does not cover

Store UTC, convert at the edge — the rule `mariadb-best-practices` already states in
"Time, charset, replication". This file is what that line does not have room for: the
column types that DO convert without being asked, the arithmetic that is wrong in
every zone but UTC (so the test suite never sees it), and the two things UTC cannot
represent — a calendar date and a recurring local time.

- A calendar date (birthday, invoice date, "the 29th") is a `DATE`, never a
  timestamp at midnight: `2026-03-29 00:00:00Z` is the 28th in every zone west of UTC.
- A "local wall-clock" value the user typed and expects back unchanged needs the
  wall-clock **and** the zone name stored beside it; UTC alone loses which day they meant.

## MySQL / MariaDB: `TIMESTAMP` converts, `DATETIME` does not

- `TIMESTAMP` is stored as UTC and **converted through the session `time_zone` on
  every write and read**. Two clients with different session zones read different
  wall-clocks from one row; a connection pool where one connection ran `SET
  time_zone` and the rest did not returns shifted rows at random. Fix at the server
  (`default_time_zone = '+00:00'`) and again on every connection — an ORM's
  `timezone` option (Laravel's `DB_TIMEZONE`, Django's `USE_TZ`) issues that `SET`.
- `TIMESTAMP` ends at **2038-01-19 03:14:07 UTC** and starts at 1970-01-01 00:00:01 —
  a 20-year loan, a retention date, or a "never expires" sentinel of 9999-12-31 fails
  the insert. (MariaDB ≥ 11.5 extends the range to 2106 for NEW tables only; confirm on
  the installed version before assuming it.) `DATETIME` spans 1000–9999 and is naive:
  no conversion, whatever wall-clock you insert comes back.
- The first `TIMESTAMP` column in a table gets an implicit `NOT NULL DEFAULT
  CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` when `explicit_defaults_for_timestamp`
  is OFF — MySQL 8 defaults it ON; MariaDB flipped the default only in **10.10**. On an
  older MariaDB an `updated_at`-shaped column silently rewrites itself on every UPDATE
  of any other column. Declare defaults explicitly; never rely on the implicit one.
- `CONVERT_TZ(ts, 'UTC', 'Europe/Berlin')` returns **NULL, not an error**, when the
  server's time-zone tables are unloaded (`mysql_tzinfo_to_sql` never ran — the default
  on most container images). Offsets (`'+01:00'`) work without the tables, and are
  wrong for half the year.
- A `DATETIME` holding local wall-clock cannot represent the DST gap or fold:
  `2026-03-29 02:30` in Berlin does not exist and `2026-10-25 02:30` happens twice. The
  engine stores both without complaint; the meaning is lost at insert.
- Sub-second precision is opt-in: `DATETIME(6)` — the mariadb skill already says so.

## PostgreSQL: neither type stores a zone

- `timestamptz` stores a UTC instant (8 bytes, **no zone**); the offset in the input
  literal is consumed on the way in and the session `TimeZone` is applied on the way
  out. `timestamp` (without zone) **silently discards** an offset in the literal:
  `'2026-03-29 10:00+02'::timestamp` is `10:00`, not `08:00`. That is the type a
  migration gets from an ORM's `dateTime()` / `DateTimeField` unless it asks for the
  zone-aware one; check the generated DDL, not the model file.
- Comparing a `timestamp` column against a `timestamptz` value (`created_at > now() -
  interval '1 day'`) casts the **column**, and the cast is STABLE (depends on
  `TimeZone`), so a btree on the column is unusable. Match the types at the schema.
- `AT TIME ZONE` flips the type both ways: `timestamptz AT TIME ZONE 'Europe/Berlin'`
  → a naive wall-clock; `timestamp AT TIME ZONE 'Europe/Berlin'` → an instant, reading
  the naive value AS Berlin time. Getting it backwards shifts every row by the offset.
- `now()` is the **transaction start** time, constant across a whole batch —
  `clock_timestamp()` moves. A backfill that stamps `updated_at = now()` in one
  transaction gives every row the same instant, which breaks any "latest by
  updated_at" tiebreak later.
- `date_trunc('day', ts_tz)` truncates in the session zone; pass the zone explicitly
  (`date_trunc('day', ts_tz, 'Europe/Berlin')`, PG14+) or the report changes with the
  connection's `TimeZone`.

## DST arithmetic on wall-clock columns

`+ interval '1 day'` and `+ interval '24 hours'` are different values on 2026-03-29
in every zone that observes DST — and identical in a UTC session, which is why the
test suite passes and production is off by an hour twice a year:

    SET TimeZone = 'Europe/Berlin';
    SELECT '2026-03-28 12:00+01'::timestamptz + interval '1 day';    -- 2026-03-29 12:00+02 (23h later)
    SELECT '2026-03-28 12:00+01'::timestamptz + interval '24 hours'; -- 2026-03-29 13:00+02

Postgres adds the `days` part of an interval in the session zone (calendar
semantics) and the `hours` part as elapsed time. MySQL `DATE_ADD` on a naive
`DATETIME` has no zone at all — `INTERVAL 1 DAY` is pure wall-clock arithmetic, right
for UTC columns and wrong for local ones. Decide which semantics the domain wants
("same time tomorrow" vs "24 hours from now") and write the interval that says it.

## `now()` in migrations and fixtures

- `DEFAULT CURRENT_TIMESTAMP` / `DEFAULT now()` is evaluated per row — fine. A default
  computed in the migration's host language (`->default(now())`; Django's
  `default=timezone.now()` **called** instead of passed as `timezone.now`; a literal
  `DEFAULT '2026-09-10 08:14:02'` in a generated DDL dump) bakes migration time into the schema: every future row gets the day the
  migration ran. Read the generated DDL for a literal where a function should be.
- A backfill migration's `now()` is one instant for the whole batch (Postgres) or
  per statement (MySQL); if the column feeds ordering, stamp from source data instead.
- Seeded fixtures with `now()` make the seed depend on when it ran; a fixture that
  must be "30 days old" is `now() - interval '30 days'` at seed time and a test
  written against it flakes on the 31st day. Seed fixed instants; freeze the
  application clock in tests (the testing plugin's `references/clock.md`).

## Range queries across a zone boundary

"Orders on 2026-03-29 for a Berlin customer" is an instant range computed in the
customer's zone and compared in UTC — half-open, never `BETWEEN`, never a function on
the column (`sql-best-practices` "Sargable predicates"):

    WHERE created_at >= ('2026-03-29'::date::timestamp AT TIME ZONE 'Europe/Berlin')
      AND created_at <  ('2026-03-30'::date::timestamp AT TIME ZONE 'Europe/Berlin')

- `DATE(created_at) = '2026-03-29'` is wrong twice: it scans, and it answers in the
  session zone, so the same query returns different rows from different connections.
- On a DST day the range is 23 or 25 hours long. A report that assumes 24-hour
  buckets double-counts or drops one hour of rows.
- The UTC day and the local day disagree for up to 14 hours either side of midnight;
  a "daily" job keyed on UTC midnight fires at 01:00 or 02:00 local depending on the
  season, which is a bug only if the spec said local.

## Recurring events need the zone name, not the offset

A weekly 09:00 Berlin meeting is `09:00` + `Europe/Berlin`, from which the next
instant is computed each time. Stored as `+01:00` it drifts to 10:00 the day DST
starts, and stored as a precomputed UTC series it is wrong the moment a government
changes its rules (`America/Sao_Paulo` dropped DST in 2019; stored offsets from 2018
are still wrong today). Store the rule and the IANA zone; materialise only the next
occurrence in UTC for the scheduler, and recompute after each fire. That also means
tzdata is a dependency — the OS, the database, ICU and the language runtime each
carry their own copy, and they disagree until all are updated.
