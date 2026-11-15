-- Conformance test against spec/vectors.json. Run from postgres/:
--   psql -v ON_ERROR_STOP=1 -f test.sql
-- Installs uuid58.sql into a temporary schema, so it leaves nothing behind.
-- Run it in both a UTF8 and a SQL_ASCII database: in SQL_ASCII, text can
-- hold bytes that are not valid UTF-8 (SPEC.md Section 8).

\set QUIET on
BEGIN;
CREATE SCHEMA uuid58_test;
SET LOCAL search_path = uuid58_test;
\i uuid58.sql

\set vectors `cat ../spec/vectors.json`
-- PostgreSQL text cannot hold U+0000, and a SQL_ASCII database cannot read
-- \u escapes for non-ASCII characters. Escape the backslash of those escapes
-- (vectors.json has no other backslashes) so the JSON parses, and skip() then
-- leaves out the cases that contain them. The ill-formed byte tests below
-- cover non-ASCII input in SQL_ASCII.
CREATE TABLE vectors AS SELECT regexp_replace(:'vectors',
  CASE current_setting('server_encoding')
    WHEN 'SQL_ASCII' THEN '\\u(0000|(?!00[0-7]))'
    ELSE '\\u0000'
  END, '\\\&', 'g')::jsonb AS v;

-- The spec error kind for the error raised by sql, or NULL if none.
CREATE FUNCTION error_kind(sql text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE sql;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN CASE SQLSTATE
    WHEN '22026' THEN 'invalid_length'
    WHEN '22P02' THEN 'invalid_character'
    WHEN '22003' THEN 'overflow'
    ELSE 'unexpected ' || SQLSTATE || ': ' || SQLERRM
  END;
END
$$;

CREATE TABLE failures (description text);
CREATE TABLE skipped (description text);

CREATE FUNCTION skip(c jsonb) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
  IF strpos(c->>'input', '\u') > 0 THEN
    INSERT INTO skipped VALUES (c->>'description');
    RETURN true;
  END IF;
  RETURN false;
END
$$;

DO $$
DECLARE
  v jsonb := (SELECT v FROM vectors);
  c jsonb;
  kind text;
  hex text;
BEGIN
  IF v->>'spec_version' <> '1.0.0' THEN
    RAISE EXCEPTION 'unexpected spec_version %', v->>'spec_version';
  END IF;

  FOR c IN SELECT jsonb_array_elements(v->'roundtrip') LOOP
    hex := replace(c->>'uuid', '-', '');
    IF uuid58_encode(c->>'uuid') IS DISTINCT FROM c->>'uuid58'
       OR uuid58_encode(hex) IS DISTINCT FROM c->>'uuid58'
       -- Compare against the hex digits, not a uuid parsed by PostgreSQL,
       -- so a byte-order mistake cannot cancel itself out.
       OR uuid58_encode(decode(hex, 'hex')) IS DISTINCT FROM c->>'uuid58'
       OR uuid58_encode((c->>'uuid')::uuid) IS DISTINCT FROM c->>'uuid58'
       OR uuid58_decode(c->>'uuid58')::text IS DISTINCT FROM c->>'uuid'
       OR encode(uuid58_decode_bytes(c->>'uuid58'), 'hex') IS DISTINCT FROM hex
       OR NOT is_uuid58(c->>'uuid58') THEN
      INSERT INTO failures VALUES ('roundtrip: ' || (c->>'description'));
    END IF;
  END LOOP;

  FOR c IN SELECT jsonb_array_elements(v->'encode'->'valid') LOOP
    IF uuid58_encode(c->>'input') IS DISTINCT FROM c->>'output' THEN
      INSERT INTO failures VALUES ('encode valid: ' || (c->>'description'));
    END IF;
  END LOOP;

  -- Includes the lenient cases: this implementation is strict.
  FOR c IN SELECT jsonb_array_elements(v->'encode'->'invalid') LOOP
    CONTINUE WHEN skip(c);
    kind := error_kind(format('SELECT uuid58_encode(%L::text)', c->>'input'));
    IF kind IS NULL OR NOT (c->'errors' ? kind) THEN
      INSERT INTO failures VALUES ('encode invalid: ' || (c->>'description') || ': ' || coalesce(kind, 'no error'));
    END IF;
  END LOOP;

  FOR c IN SELECT jsonb_array_elements(v->'encode'->'invalid_bytes') LOOP
    kind := error_kind(format('SELECT uuid58_encode(decode(%L, ''hex''))', c->>'bytes'));
    IF kind IS NULL OR NOT (c->'errors' ? kind) THEN
      INSERT INTO failures VALUES ('encode invalid_bytes: ' || (c->>'description') || ': ' || coalesce(kind, 'no error'));
    END IF;
  END LOOP;

  -- encode.invalid_integers does not apply: there is no integer API.

  FOR c IN SELECT jsonb_array_elements(v->'decode'->'invalid') LOOP
    CONTINUE WHEN skip(c);
    kind := error_kind(format('SELECT uuid58_decode(%L)', c->>'input'));
    IF kind IS NULL OR NOT (c->'errors' ? kind)
       OR kind IS DISTINCT FROM error_kind(format('SELECT uuid58_decode_bytes(%L)', c->>'input'))
       OR is_uuid58(c->>'input') THEN
      INSERT INTO failures VALUES ('decode invalid: ' || (c->>'description') || ': ' || coalesce(kind, 'no error'));
    END IF;
  END LOOP;

  -- NULL in, NULL out.
  IF uuid58_encode(NULL::text) IS NOT NULL OR uuid58_encode(NULL::uuid) IS NOT NULL
     OR uuid58_encode(NULL::bytea) IS NOT NULL OR uuid58_decode(NULL) IS NOT NULL
     OR uuid58_decode_bytes(NULL) IS NOT NULL OR is_uuid58(NULL) IS NOT NULL THEN
    INSERT INTO failures VALUES ('NULL handling');
  END IF;

  -- An unknown-type literal resolves to the strict text overload.
  IF error_kind('SELECT uuid58_encode(''{f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf}'')') IS DISTINCT FROM 'invalid_length' THEN
    INSERT INTO failures VALUES ('untyped literal uses the text overload');
  END IF;

  -- Ordering holds under the C collation, whatever the database default.
  IF NOT (uuid58_encode('00000000-0000-0000-0000-00000000003a'::uuid) COLLATE "C"
          > uuid58_encode('00000000-0000-0000-0000-000000000039'::uuid) COLLATE "C") THEN
    INSERT INTO failures VALUES ('ordering');
  END IF;

  -- Inputs that are not valid UTF-8 (SPEC.md Section 8). Only a SQL_ASCII
  -- database can hold them in text.
  IF current_setting('server_encoding') = 'SQL_ASCII' THEN
    -- [function, input bytes in hex]
    FOR c IN SELECT * FROM jsonb_array_elements('[
        ["uuid58_decode", "58445939646d4262634d425871635276597738784aff"],
        ["uuid58_decode", "58445939646d4262634d425871635276597738784a80"],
        ["uuid58_decode", "58445939646d4262634d42587163527659773878c14a"],
        ["uuid58_encode", "66346232343766642d316638372d343564342d616130362d3163366663306138646661ff"],
        ["uuid58_encode", "6634623234376664316638373435643461613036316336666330613864666180"]
      ]'::jsonb) LOOP
      kind := error_kind(format('SELECT %I(convert_from(%L::bytea, ''SQL_ASCII''))', c->>0, '\x' || (c->>1)));
      -- Each input has a length the format allows (22, 36 or 32 bytes), so the
      -- only right kind is invalid_character.
      IF kind IS DISTINCT FROM 'invalid_character'
         OR is_uuid58(convert_from(('\x' || (c->>1))::bytea, 'SQL_ASCII')) THEN
        INSERT INTO failures VALUES ('ill-formed ' || (c->>0) || ' ' || (c->>1) || ': ' || coalesce(kind, 'no error'));
      END IF;
    END LOOP;
  END IF;
END
$$;

\set QUIET off
SELECT description AS skipped FROM skipped;
SELECT description AS failure FROM failures;
DO $$
DECLARE
  n int := (SELECT count(*) FROM failures);
BEGIN
  IF n > 0 THEN
    RAISE EXCEPTION '% failure(s)', n;
  END IF;
  RAISE NOTICE 'all applicable vectors passed (server_encoding %, % skipped)',
    current_setting('server_encoding'), (SELECT count(*) FROM skipped);
END
$$;
ROLLBACK;
