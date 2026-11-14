# uuid58 for PostgreSQL

SQL functions that implement [uuid58](../spec/SPEC.md): a 22-character
Base58 text encoding for 128-bit UUIDs.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
```

- Plain SQL and PL/pgSQL functions in one file. No extension to install, so
  they work on managed databases such as Amazon RDS, Cloud SQL, Azure
  Database for PostgreSQL, Supabase, and Neon.
- Requires PostgreSQL 14 or later.
- Passes every applicable case in the shared
  [test vectors](../spec/vectors.json).

## Install

Run [`uuid58.sql`](uuid58.sql) in your database. The functions are created in
the first schema on your `search_path` (usually `public`):

```bash
curl -fsSL https://raw.githubusercontent.com/nakanoasaservice/uuid58/main/postgres/uuid58.sql | psql "$DATABASE_URL"
```

To put them in another schema, set `search_path` first, for example
`SET search_path = util;` and then `\i uuid58.sql` in psql. Running the file
again replaces the functions, so you can use it as a migration. Calls between
the functions are bound when they are created, so they keep working when the
schema is not on the caller's `search_path`.

## Usage

```sql
SELECT uuid58_encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'::uuid);
-- XDY9dmBbcMBXqcRvYw8xJ2

SELECT uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2');
-- f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf (type uuid)

SELECT is_uuid58('XDY9dmBbcMBXqcRvYw8xJ2');  -- true
SELECT is_uuid58('zzzzzzzzzzzzzzzzzzzzzz');  -- false: exceeds 128 bits

-- Expose short IDs without changing the uuid primary key.
SELECT uuid58_encode(id) AS short_id, name FROM users;
SELECT * FROM users WHERE id = uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2');
```

Generate new IDs with PostgreSQL's own functions, such as
`uuid58_encode(gen_random_uuid())` or, on PostgreSQL 18, `uuidv7()`.

## Functions

All functions are `IMMUTABLE`, `STRICT` (NULL in, NULL out), and
`PARALLEL SAFE`, so they can be used in indexes and generated columns.

| Function                            | Description                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| `uuid58_encode(uuid) → text`        | Encode a `uuid` value.                                                                            |
| `uuid58_encode(text) → text`        | Encode a UUID string: the 36-character hyphenated form or 32 hex digits, any case.                |
| `uuid58_encode(bytea) → text`       | Encode 16 bytes (big-endian, as from `uuid_send`).                                                |
| `uuid58_decode(text) → uuid`        | Decode to a `uuid`. Its text form is the lowercase hyphenated UUID.                               |
| `uuid58_decode_bytes(text) → bytea` | Decode to 16 bytes.                                                                               |
| `is_uuid58(text) → boolean`         | True if the string is a valid uuid58 string: 22 alphabet characters, value below 2^128. No error. |

`uuid58_encode(text)` follows the spec and is stricter than casting to
`uuid`, which also accepts braces and hyphens after any four digits. An
untyped string literal, as in `uuid58_encode('f4b247fd-…')`, uses this text
version. A `uuid` column or a value cast with `::uuid` uses the `uuid`
version, which cannot fail.

## Errors

Invalid input raises an error with one of these SQLSTATEs, one for each error
kind in the spec (Section 7). Messages are not part of the spec and may
change.

| SQLSTATE | Condition name                | Spec error kind     | Raised when                                                   |
| -------- | ----------------------------- | ------------------- | ------------------------------------------------------------- |
| `22026`  | `string_data_length_mismatch` | `invalid_length`    | a string of the wrong length, or `bytea` that is not 16 bytes |
| `22P02`  | `invalid_text_representation` | `invalid_character` | a character not allowed in its position (incl. non-ASCII)     |
| `22003`  | `numeric_value_out_of_range`  | `overflow`          | a uuid58 string whose value is 2^128 or more                  |

```sql
DO $$
BEGIN
  PERFORM uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ0');
EXCEPTION WHEN invalid_text_representation THEN
  RAISE NOTICE 'not a uuid58 string';
END
$$;
```

Length is counted in characters of the database encoding. Non-ASCII input is
always an error; its kind may be either of the first two.

## Sorting

uuid58 strings sort in the same order as the UUIDs they encode, but only when
compared byte by byte. Most databases use a locale-aware default collation,
which does not keep that order, so use the `C` collation:

```sql
SELECT uuid58_encode(id) AS short_id FROM events ORDER BY short_id COLLATE "C";

-- or store them with it:
ALTER TABLE events
  ADD COLUMN short_id text COLLATE "C"
  GENERATED ALWAYS AS (uuid58_encode(id)) STORED;
```

Ordering by the `uuid` column gives the same result and is usually faster.

## Performance

The functions use `numeric` for 128-bit arithmetic. On a laptop, encoding and
decoding a UUID takes tens of microseconds, which is fine for converting IDs
at the edge of a query. For bulk conversion of millions of rows, convert in
your application with one of the other implementations instead.

## Development

The conformance test loads `spec/vectors.json` and installs the functions in
a temporary schema inside a transaction that it rolls back. Run it from this
directory against a UTF8 database and a `SQL_ASCII` one (where text can hold
bytes that are not valid UTF-8):

```bash
psql -v ON_ERROR_STOP=1 -f test.sql
```

```bash
createdb -E SQL_ASCII -T template0 --lc-collate=C --lc-ctype=C uuid58_ascii
PGCLIENTENCODING=SQL_ASCII psql -d uuid58_ascii -v ON_ERROR_STOP=1 -f test.sql
```

PostgreSQL text cannot hold U+0000, so the vectors with NUL in the input do
not apply and are skipped. In the `SQL_ASCII` database, vectors with non-ASCII
characters are skipped too, and the test checks raw non-UTF-8 bytes instead.

## License

MIT
