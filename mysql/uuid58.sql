-- uuid58 for MySQL and MariaDB: https://github.com/nakanoasaservice/uuid58
-- Implements uuid58 specification 1.1.0. MIT License.
--
-- Stored functions in one file; no extension needed. Requires MySQL 8.4 or
-- later, or MariaDB 10.11 or later. Run it in the database you want the
-- functions in, for example: mysql -D mydb < uuid58.sql. Running it again
-- replaces them.
--
-- On a server with binary logging enabled, creating a stored function needs
-- the SUPER privilege or log_bin_trust_function_creators = 1. Without either,
-- this file fails with error 1419.
--
-- MySQL has no function overloading, so the byte encoder is uuid58_encode_bytes
-- rather than a second uuid58_encode. MySQL has no native UUID type: pass the
-- 36-character text form, or 16 bytes in RFC 9562 order (UUID_TO_BIN without
-- the swap flag). Pass a MariaDB UUID value to uuid58_encode_bytes.
--
-- These servers reject stored functions in generated columns. Call the
-- functions from queries or views instead.
--
-- 128-bit values are two BIGINT UNSIGNED halves. 2^64 = 58 * 318047311615681924
-- + 24, so division and multiplication by 58 stay inside 64-bit arithmetic.
--
-- String parameters are LONGBLOB, so the functions read the bytes of the
-- argument as they are. With a character set on the parameter, the server
-- would convert the argument first, under the caller's sql_mode: a strict
-- session raises error 1366 for bytes that are not valid UTF-8, and a
-- non-strict MySQL session cuts the value at the first such byte, which
-- turns a valid string followed by junk into a valid string. Length is
-- therefore measured in bytes, and any byte 0x80 or above is rejected. Pass
-- utf16, ucs2, or utf32 values through CONVERT(... USING utf8mb4).
--
-- Errors (SQLSTATE -> spec error kind):
--   22026 string data, length mismatch -> invalid_length
--   22018 invalid character value for cast -> invalid_character
--   22003 numeric value out of range -> overflow
--
-- The functions are created under a strict sql_mode, then the session mode is
-- restored. The mode in effect at CREATE is the one their bodies run with.

SET @uuid58_install_sql_mode = @@SESSION.sql_mode;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

DROP FUNCTION IF EXISTS uuid58_encode;
DROP FUNCTION IF EXISTS uuid58_decode;
DROP FUNCTION IF EXISTS uuid58_encode_bytes;
DROP FUNCTION IF EXISTS uuid58_decode_bytes;
DROP FUNCTION IF EXISTS is_uuid58;

DELIMITER $$

-- Encodes 16 bytes (big-endian) as a 22-character uuid58 string.
CREATE FUNCTION uuid58_encode_bytes(b LONGBLOB)
RETURNS VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
COMMENT 'Encode 16 big-endian bytes as uuid58'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE alphabet VARCHAR(58) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
    DEFAULT '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  DECLARE result VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT '';
  DECLARE hi BIGINT UNSIGNED;
  DECLARE lo BIGINT UNSIGNED;
  DECLARE qhi BIGINT UNSIGNED;
  DECLARE qlo BIGINT UNSIGNED;
  DECLARE pow64_div_58 BIGINT UNSIGNED DEFAULT 318047311615681924;
  DECLARE i INT;
  DECLARE hi_mod INT;
  DECLARE lo_div BIGINT UNSIGNED;
  DECLARE lo_mod INT;
  DECLARE extra INT;
  DECLARE digit INT;
  DECLARE msg VARCHAR(128);

  IF b IS NULL THEN
    RETURN NULL;
  END IF;
  IF LENGTH(b) <> 16 THEN
    SET msg = CONCAT('uuid58: expected 16 bytes, got ', LENGTH(b));
    SIGNAL SQLSTATE '22026' SET MESSAGE_TEXT = msg;
  END IF;

  -- CONV works with 64-bit precision, so each half converts in one step.
  SET hi = CAST(CONV(HEX(SUBSTRING(b, 1, 8)), 16, 10) AS UNSIGNED);
  SET lo = CAST(CONV(HEX(SUBSTRING(b, 9, 8)), 16, 10) AS UNSIGNED);

  -- Least-significant digit first, prepended, so the string is big-endian.
  SET i = 0;
  WHILE i < 22 DO
    SET hi_mod = hi MOD 58;
    SET lo_div = lo DIV 58;
    SET lo_mod = lo MOD 58;
    SET extra = (hi_mod * 24 + lo_mod) DIV 58;
    SET digit = (hi_mod * 24 + lo_mod) MOD 58;
    SET qhi = hi DIV 58;
    SET qlo = hi_mod * pow64_div_58 + lo_div + extra;
    SET hi = qhi;
    SET lo = qlo;
    SET result = CONCAT(SUBSTRING(alphabet, digit + 1, 1), result);
    SET i = i + 1;
  END WHILE;
  RETURN result;
END$$

-- Encodes a UUID string: 36-character hyphenated form or 32 hex digits, any case.
CREATE FUNCTION uuid58_encode(s LONGBLOB)
RETURNS VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
COMMENT 'Encode a UUID string as uuid58'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE hex_digits VARBINARY(22) DEFAULT _binary'0123456789abcdefABCDEF';
  DECLARE plain VARBINARY(32);
  DECLARE i INT;
  DECLARE len INT;
  DECLARE msg VARCHAR(128);

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  SET len = LENGTH(s);
  IF len <> 32 AND len <> 36 THEN
    SET msg = CONCAT('uuid58: expected a UUID string of 32 or 36 characters, got ', len, ' bytes');
    SIGNAL SQLSTATE '22026' SET MESSAGE_TEXT = msg;
  END IF;

  -- Every byte is checked here, so UNHEX below never sees anything else.
  SET i = 1;
  WHILE i <= len DO
    IF len = 36 AND i IN (9, 14, 19, 24) THEN
      IF SUBSTRING(s, i, 1) <> _binary'-' THEN
        SET msg = CONCAT('uuid58: invalid character in UUID string at position ', i);
        SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
      END IF;
    ELSEIF LOCATE(SUBSTRING(s, i, 1), hex_digits) = 0 THEN
      SET msg = CONCAT('uuid58: invalid character in UUID string at position ', i);
      SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
    END IF;
    SET i = i + 1;
  END WHILE;

  IF len = 36 THEN
    SET plain = CONCAT(
      SUBSTRING(s, 1, 8),
      SUBSTRING(s, 10, 4),
      SUBSTRING(s, 15, 4),
      SUBSTRING(s, 20, 4),
      SUBSTRING(s, 25, 12)
    );
  ELSE
    SET plain = s;
  END IF;
  RETURN uuid58_encode_bytes(UNHEX(plain));
END$$

-- Decodes a uuid58 string to 16 bytes (big-endian).
CREATE FUNCTION uuid58_decode_bytes(s LONGBLOB)
RETURNS BINARY(16)
COMMENT 'Decode uuid58 to 16 big-endian bytes'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE alphabet VARBINARY(58)
    DEFAULT _binary'123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  DECLARE hi BIGINT UNSIGNED DEFAULT 0;
  DECLARE lo BIGINT UNSIGNED DEFAULT 0;
  DECLARE lo_l BIGINT UNSIGNED;
  DECLARE lo_h BIGINT UNSIGNED;
  DECLARE prod_l BIGINT UNSIGNED;
  DECLARE prod_h BIGINT UNSIGNED;
  DECLARE pow32 BIGINT UNSIGNED DEFAULT 4294967296;
  DECLARE i INT;
  DECLARE digit INT;
  DECLARE carry INT;
  DECLARE msg VARCHAR(128);

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  IF LENGTH(s) <> 22 THEN
    SET msg = CONCAT('uuid58: expected 22 characters, got ', LENGTH(s), ' bytes');
    SIGNAL SQLSTATE '22026' SET MESSAGE_TEXT = msg;
  END IF;

  SET i = 1;
  WHILE i <= 22 DO
    SET digit = LOCATE(SUBSTRING(s, i, 1), alphabet) - 1;
    IF digit < 0 THEN
      SET msg = CONCAT('uuid58: invalid character at position ', i);
      SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
    END IF;

    -- (hi, lo) = (hi, lo) * 58 + digit. A carry out of hi means the value
    -- is >= 2^128. For a 22-character alphabet string this cannot happen
    -- before the last digit, which has already been checked.
    SET lo_l = lo MOD pow32;
    SET lo_h = lo DIV pow32;
    SET prod_l = lo_l * 58 + digit;
    SET prod_h = lo_h * 58 + prod_l DIV pow32;
    SET lo = (prod_h MOD pow32) * pow32 + (prod_l MOD pow32);
    SET carry = prod_h DIV pow32;

    SET lo_l = hi MOD pow32;
    SET lo_h = hi DIV pow32;
    SET prod_l = lo_l * 58 + carry;
    SET prod_h = lo_h * 58 + prod_l DIV pow32;
    IF prod_h DIV pow32 <> 0 THEN
      SIGNAL SQLSTATE '22003'
        SET MESSAGE_TEXT = 'uuid58: value exceeds 128 bits';
    END IF;
    SET hi = (prod_h MOD pow32) * pow32 + (prod_l MOD pow32);
    SET i = i + 1;
  END WHILE;

  RETURN UNHEX(CONCAT(LPAD(HEX(hi), 16, '0'), LPAD(HEX(lo), 16, '0')));
END$$

-- Decodes a uuid58 string to the lowercase hyphenated UUID form.
CREATE FUNCTION uuid58_decode(s LONGBLOB)
RETURNS VARCHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
COMMENT 'Decode uuid58 to a lowercase hyphenated UUID'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE h VARCHAR(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  SET h = LOWER(HEX(uuid58_decode_bytes(s)));
  RETURN (
    CONCAT(
      SUBSTRING(h, 1, 8), '-',
      SUBSTRING(h, 9, 4), '-',
      SUBSTRING(h, 13, 4), '-',
      SUBSTRING(h, 17, 4), '-',
      SUBSTRING(h, 21, 12)
    )
  ) COLLATE utf8mb4_bin;
END$$

-- True if s is a valid uuid58 string. Never raises.
CREATE FUNCTION is_uuid58(s LONGBLOB)
RETURNS TINYINT(1)
COMMENT 'True when s is a valid uuid58 string'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE alphabet VARBINARY(58)
    DEFAULT _binary'123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  DECLARE i INT;

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  IF LENGTH(s) <> 22 THEN
    RETURN 0;
  END IF;
  SET i = 1;
  WHILE i <= 22 DO
    IF LOCATE(SUBSTRING(s, i, 1), alphabet) = 0 THEN
      RETURN 0;
    END IF;
    SET i = i + 1;
  END WHILE;
  IF s <= _binary'YcVfxkQb6JRzqk5kF2tNLv' THEN
    RETURN 1;
  END IF;
  RETURN 0;
END$$

DELIMITER ;

SET SESSION sql_mode = @uuid58_install_sql_mode;
