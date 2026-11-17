-- uuid58 for PostgreSQL: https://github.com/nakanoasaservice/uuid58
-- Implements uuid58 specification 1.1.0. MIT License.
--
-- Plain SQL and PL/pgSQL functions; no extension needed. Requires
-- PostgreSQL 14 or later. Run this file in the schema you want the functions
-- in, for example: psql -f uuid58.sql. Running it again replaces them.
--
-- Errors (SQLSTATE -> spec error kind):
--   22026 string_data_length_mismatch -> invalid_length
--   22P02 invalid_text_representation -> invalid_character
--   22003 numeric_value_out_of_range  -> overflow

-- Encodes 16 bytes (big-endian) as a 22-character uuid58 string.
CREATE OR REPLACE FUNCTION uuid58_encode(b bytea) RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE
  alphabet constant text := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  n numeric := 0;
  result text := '';
BEGIN
  IF length(b) <> 16 THEN
    RAISE EXCEPTION 'uuid58: expected 16 bytes, got %', length(b)
      USING ERRCODE = 'string_data_length_mismatch';
  END IF;
  FOR i IN 0..15 LOOP
    n := n * 256 + get_byte(b, i);
  END LOOP;
  FOR i IN 1..22 LOOP
    result := substr(alphabet, mod(n, 58)::int + 1, 1) || result;
    n := div(n, 58);
  END LOOP;
  RETURN result;
END
$$;

-- Encodes a UUID string: 36-character hyphenated form or 32 hex digits, any
-- case. Stricter than the uuid type's input, which also accepts braces and
-- hyphens after any group of four digits.
CREATE OR REPLACE FUNCTION uuid58_encode(s text) RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE
  alphabet constant text := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  hex text;
  b bytea;
  n numeric := 0;
  result text := '';
BEGIN
  IF length(s) = 32 THEN
    IF (s COLLATE "C") !~ '^[0-9A-Fa-f]{32}$' THEN
      RAISE EXCEPTION 'uuid58: UUID string must be 32 hexadecimal digits'
        USING ERRCODE = 'invalid_text_representation';
    END IF;
    hex := s;
  ELSIF length(s) = 36 THEN
    IF (s COLLATE "C") !~ '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$' THEN
      RAISE EXCEPTION 'uuid58: UUID string must be in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
        USING ERRCODE = 'invalid_text_representation';
    END IF;
    hex := replace(s, '-', '');
  ELSE
    RAISE EXCEPTION 'uuid58: expected a UUID string of 32 or 36 characters, got %', length(s)
      USING ERRCODE = 'string_data_length_mismatch';
  END IF;
  b := decode(hex, 'hex');
  FOR i IN 0..15 LOOP
    n := n * 256 + get_byte(b, i);
  END LOOP;
  FOR i IN 1..22 LOOP
    result := substr(alphabet, mod(n, 58)::int + 1, 1) || result;
    n := div(n, 58);
  END LOOP;
  RETURN result;
END
$$;

-- Encodes a uuid value.
CREATE OR REPLACE FUNCTION uuid58_encode(u uuid) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
RETURN uuid58_encode(uuid_send(u));

-- Decodes a uuid58 string to 16 bytes (big-endian).
CREATE OR REPLACE FUNCTION uuid58_decode_bytes(s text) RETURNS bytea
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE
  alphabet constant text := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  n numeric := 0;
  d int;
  b bytea := '\x00000000000000000000000000000000';
BEGIN
  IF length(s) <> 22 THEN
    RAISE EXCEPTION 'uuid58: expected 22 characters, got %', length(s)
      USING ERRCODE = 'string_data_length_mismatch';
  END IF;
  FOR i IN 1..22 LOOP
    d := strpos(alphabet, substr(s, i, 1) COLLATE "C") - 1;
    IF d < 0 THEN
      RAISE EXCEPTION 'uuid58: invalid character at position %', i
        USING ERRCODE = 'invalid_text_representation';
    END IF;
    n := n * 58 + d;
  END LOOP;
  IF n >= 340282366920938463463374607431768211456 THEN  -- 2^128
    RAISE EXCEPTION 'uuid58: value exceeds 128 bits'
      USING ERRCODE = 'numeric_value_out_of_range';
  END IF;
  FOR i IN REVERSE 15..0 LOOP
    b := set_byte(b, i, mod(n, 256)::int);
    n := div(n, 256);
  END LOOP;
  RETURN b;
END
$$;

-- Decodes a uuid58 string to a uuid value.
CREATE OR REPLACE FUNCTION uuid58_decode(s text) RETURNS uuid
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
RETURN encode(uuid58_decode_bytes(s), 'hex')::uuid;

-- True if s is a valid uuid58 string. Never raises.
CREATE OR REPLACE FUNCTION is_uuid58(s text) RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
RETURN (s COLLATE "C") ~ '^[1-9A-HJ-NP-Za-km-z]{22}$'
   AND (s COLLATE "C") <= 'YcVfxkQb6JRzqk5kF2tNLv';
