# uuid58 for MySQL and MariaDB

[![CI](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-mysql.yml/badge.svg)](https://github.com/nakanoasaservice/uuid58/actions/workflows/ci-mysql.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE)

Shorten UUIDs to 22-character Base58 strings, and back, in MySQL and MariaDB.
Stored functions in one file, with no extension to install, so they work on
managed databases such as Amazon RDS, Cloud SQL, and Azure Database for MySQL.

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

- **Fixed 22 characters**, using the Bitcoin Base58 alphabet: URL-safe, with
  no `0`, `O`, `I`, or `l`.
- **Sortable**: strings sort in the same order as the UUIDs they encode when
  compared byte by byte (see [Sorting](#sorting)), so UUIDv7 IDs stay
  time-ordered.
- **Stable spec, well tested**: implements uuid58 spec 1.1.0 and passes every
  applicable case of its 200+ shared test vectors, so the output matches
  every other language.
- **Keep your UUID keys**: expose short IDs in queries without changing the
  primary key.
- Requires MySQL 8.4 or later, or MariaDB 10.11 or later.

[Try it in your browser](https://nakanoasaservice.github.io/uuid58/) ·
[Specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md) ·
[Other languages](https://github.com/nakanoasaservice/uuid58#install)

## Install

Run [`uuid58.sql`](https://github.com/nakanoasaservice/uuid58/blob/main/mysql/uuid58.sql) in the database where you want the functions:

```bash
curl -fsSL https://raw.githubusercontent.com/nakanoasaservice/uuid58/main/mysql/uuid58.sql | mysql -D mydb
```

Running the file again replaces the functions, so you can use it as a
migration. It creates them under a strict `sql_mode`, then restores your
session mode. Calls between the functions are bound to this database.

On a server with binary logging enabled, creating a stored function needs the
`SUPER` privilege or `log_bin_trust_function_creators = 1`. Without either,
the file fails with error 1419. Binary logging is on by default in MySQL, and
usually on managed databases, where you set the variable in the parameter
group or database flags.

## Usage

```sql
SELECT uuid58_encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf');
-- XDY9dmBbcMBXqcRvYw8xJ2

SELECT uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2');
-- f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf

SELECT is_uuid58('XDY9dmBbcMBXqcRvYw8xJ2');  -- 1
SELECT is_uuid58('zzzzzzzzzzzzzzzzzzzzzz');  -- 0: exceeds 128 bits

-- Text UUID column.
SELECT uuid58_encode(id) AS short_id, name FROM users;
SELECT * FROM users WHERE id = uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2');

-- 16 bytes in RFC 9562 order. On MySQL, UUID_TO_BIN does that when its swap
-- flag is omitted; do not pass 1.
SELECT uuid58_encode_bytes(id) FROM users_bin;
SELECT * FROM users_bin WHERE id = uuid58_decode_bytes('XDY9dmBbcMBXqcRvYw8xJ2');

-- MariaDB UUID column: it reaches the functions as 16 bytes.
SELECT uuid58_encode_bytes(id) FROM users_uuid;
SELECT * FROM users_uuid WHERE id = uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2');
```

Generate new IDs with the server's own function, such as
`uuid58_encode(UUID())`.

These servers reject stored functions in generated columns. Expose the short
id from a view, or call the function in the query:

```sql
CREATE VIEW users_public AS
SELECT uuid58_encode(id) AS short_id, name FROM users;
```

## Functions

MySQL has no function overloading and no UUID type, so the text and byte
encoders have different names. All five functions are deterministic: NULL in,
NULL out.

| Function                                 | Description                                                                                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `uuid58_encode(text) → varchar(22)`      | Encode a UUID string: the 36-character hyphenated form or 32 hex digits, any case.                  |
| `uuid58_encode_bytes(blob) → varchar(22)` | Encode 16 bytes (big-endian, RFC 9562 order).                                                        |
| `uuid58_decode(text) → varchar(36)`      | Decode to the lowercase hyphenated UUID.                                                             |
| `uuid58_decode_bytes(text) → binary(16)` | Decode to 16 bytes.                                                                                  |
| `is_uuid58(text) → tinyint`              | 1 if the string is a valid uuid58 string: 22 alphabet characters, value below 2^128. No error. 0 otherwise. |

The encoded and decoded strings use the `utf8mb4_bin` collation.

String arguments are read as bytes, with no character set conversion. The
result therefore does not depend on the caller's `sql_mode`, and a byte that
is not valid UTF-8 is rejected like any other invalid character. Text in
`utf8mb4`, `latin1`, or another ASCII-compatible character set works as it
is. Convert `utf16`, `ucs2`, and `utf32` values first, with
`CONVERT(col USING utf8mb4)`.

`uuid58_encode` accepts only the two forms in the spec. It rejects braces,
a `urn:uuid:` prefix, and hyphens in the wrong places.

## Errors

Invalid input raises an error with one of these SQLSTATEs, one for each error
kind in the spec (Section 7). Messages are not part of the spec and may
change.

| SQLSTATE | Spec error kind     | Raised when                                                                 |
| -------- | ------------------- | --------------------------------------------------------------------------- |
| `22026`  | `invalid_length`    | a string whose length is not 32 or 36 (encode) or 22 (decode), or a byte string that is not 16 bytes |
| `22018`  | `invalid_character` | a character not allowed in its position (including non-ASCII)               |
| `22003`  | `overflow`          | a uuid58 string whose value is 2^128 or more                                |

```sql
CREATE PROCEDURE catch_uuid58()
BEGIN
  DECLARE EXIT HANDLER FOR SQLSTATE '22018'
  BEGIN
    SELECT 'not a uuid58 string' AS message;
  END;
  SELECT uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ0');
END;
```

Length is counted in bytes. Input with a non-ASCII character, or with a byte
that is not valid UTF-8, is always an error; its kind may be either of the
first two.

## Sorting

uuid58 strings sort in the same order as the UUIDs they encode, but only when
compared byte by byte. The functions return `utf8mb4_bin`, which does that, so
this order matches the UUIDs:

```sql
SELECT uuid58_encode(id) AS short_id FROM events ORDER BY short_id;
```

A column or variable with the database's usual case-insensitive collation does
not. Store copies with `utf8mb4_bin`:

```sql
ALTER TABLE events
  ADD COLUMN short_id VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
UPDATE events SET short_id = uuid58_encode(id);
```

Ordering by the UUID column gives the same result and is usually faster.

## Performance

Encoding and decoding use two 64-bit halves, not decimal arithmetic. That is
enough for converting IDs at the edge of a query. For bulk conversion of
millions of rows, convert in your application with one of the other
implementations instead.

## Compatibility

These functions implement [uuid58 spec 1.1.0](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md)
and pass every applicable case in the shared
[test vectors](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json). A string produced in the
database decodes to the same UUID in every other implementation, and the
other way around.

## Development

The conformance test loads [`spec/vectors.json`](https://github.com/nakanoasaservice/uuid58/blob/main/spec/vectors.json), installs the functions twice in a scratch database, and drops that database on success. Point it at a running server:

```bash
docker run -d --name uuid58-mysql -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:8.4
./test.sh
```

```bash
docker run -d --name uuid58-mariadb -p 3306:3306 \
  -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 mariadb:10.11
./test.sh
```

`MYSQL_HOST`, `MYSQL_PORT`, and `MYSQL_USER` override the defaults
(`127.0.0.1`, `3306`, `root`). Set `MYSQL_PWD` when the account has a
password. The script uses the `mysql` client, or `mariadb` when that is the
only client on `PATH`.

## License

MIT, see [LICENSE](https://github.com/nakanoasaservice/uuid58/blob/main/LICENSE).
