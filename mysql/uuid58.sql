-- uuid58 for MySQL and MariaDB: https://github.com/nakanoasaservice/uuid58
-- Implements uuid58 specification 1.1.0. MIT License.
--
-- Stored functions in one file; no extension needed. Requires MySQL 8.4 or
-- later, or MariaDB 10.11 or later. Run it in the database you want the
-- functions in, for example: mysql -D mydb < uuid58.sql. Running it again
-- replaces them.
--
-- MySQL has no function overloading, so the byte encoder is uuid58_encode_bytes
-- rather than a second uuid58_encode. There is no native UUID type: pass the
-- 36-character text form, or 16 bytes in RFC 9562 order (UUID_TO_BIN without
-- the swap flag, on servers that have it).
--
-- These servers reject stored functions in generated columns. Call the
-- functions from queries or views instead.
--
-- 128-bit values are two BIGINT UNSIGNED halves. 2^64 = 58 * 318047311615681924
-- + 24, so division and multiplication by 58 stay inside 64-bit arithmetic.
--
-- Length is measured in characters (Unicode code points), not bytes.
--
-- Errors (SQLSTATE -> spec error kind):
--   22026 string data, length mismatch -> invalid_length
--   22018 invalid character value for cast -> invalid_character
--   22003 numeric value out of range -> overflow
--
-- The functions are created under a strict sql_mode, then the session mode is
-- restored. The mode in effect at CREATE is the one they run with.

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
  DECLARE hi BIGINT UNSIGNED DEFAULT 0;
  DECLARE lo BIGINT UNSIGNED DEFAULT 0;
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

  SET i = 1;
  WHILE i <= 8 DO
    SET hi = hi * 256 + CAST(CONV(HEX(SUBSTRING(b, i, 1)), 16, 10) AS UNSIGNED);
    SET i = i + 1;
  END WHILE;
  WHILE i <= 16 DO
    SET lo = lo * 256 + CAST(CONV(HEX(SUBSTRING(b, i, 1)), 16, 10) AS UNSIGNED);
    SET i = i + 1;
  END WHILE;

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
CREATE FUNCTION uuid58_encode(s LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin)
RETURNS VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
COMMENT 'Encode a UUID string as uuid58'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE plain VARCHAR(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
  DECLARE ch VARCHAR(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
  DECLARE raw LONGBLOB;
  DECLARE i INT;
  DECLARE len INT;
  DECLARE msg VARCHAR(128);

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  SET len = CHAR_LENGTH(s);
  IF len = 32 THEN
    SET i = 1;
    WHILE i <= 32 DO
      SET ch = SUBSTRING(s, i, 1);
      IF NOT (
        (ch >= _utf8mb4'0' COLLATE utf8mb4_bin AND ch <= _utf8mb4'9' COLLATE utf8mb4_bin)
        OR (ch >= _utf8mb4'a' COLLATE utf8mb4_bin AND ch <= _utf8mb4'f' COLLATE utf8mb4_bin)
        OR (ch >= _utf8mb4'A' COLLATE utf8mb4_bin AND ch <= _utf8mb4'F' COLLATE utf8mb4_bin)
      ) THEN
        SET msg = CONCAT('uuid58: invalid character in UUID string at position ', i);
        SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
      END IF;
      SET i = i + 1;
    END WHILE;
    SET plain = s;
  ELSEIF len = 36 THEN
    SET i = 1;
    WHILE i <= 36 DO
      SET ch = SUBSTRING(s, i, 1);
      IF i IN (9, 14, 19, 24) THEN
        IF ch <> _utf8mb4'-' COLLATE utf8mb4_bin THEN
          SET msg = CONCAT('uuid58: invalid character in UUID string at position ', i);
          SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
        END IF;
      ELSEIF NOT (
        (ch >= _utf8mb4'0' COLLATE utf8mb4_bin AND ch <= _utf8mb4'9' COLLATE utf8mb4_bin)
        OR (ch >= _utf8mb4'a' COLLATE utf8mb4_bin AND ch <= _utf8mb4'f' COLLATE utf8mb4_bin)
        OR (ch >= _utf8mb4'A' COLLATE utf8mb4_bin AND ch <= _utf8mb4'F' COLLATE utf8mb4_bin)
      ) THEN
        SET msg = CONCAT('uuid58: invalid character in UUID string at position ', i);
        SIGNAL SQLSTATE '22018' SET MESSAGE_TEXT = msg;
      END IF;
      SET i = i + 1;
    END WHILE;
    SET plain = CONCAT(
      SUBSTRING(s, 1, 8),
      SUBSTRING(s, 10, 4),
      SUBSTRING(s, 15, 4),
      SUBSTRING(s, 20, 4),
      SUBSTRING(s, 25, 12)
    );
  ELSE
    SET msg = CONCAT('uuid58: expected a UUID string of 32 or 36 characters, got ', len);
    SIGNAL SQLSTATE '22026' SET MESSAGE_TEXT = msg;
  END IF;

  SET raw = UNHEX(plain);
  IF raw IS NULL OR LENGTH(raw) <> 16 THEN
    SIGNAL SQLSTATE '22018'
      SET MESSAGE_TEXT = 'uuid58: invalid character in UUID string';
  END IF;
  RETURN uuid58_encode_bytes(raw);
END$$

-- Decodes a uuid58 string to 16 bytes (big-endian).
CREATE FUNCTION uuid58_decode_bytes(s LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin)
RETURNS BINARY(16)
COMMENT 'Decode uuid58 to 16 big-endian bytes'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE alphabet VARCHAR(58) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
    DEFAULT '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  DECLARE hi BIGINT UNSIGNED DEFAULT 0;
  DECLARE lo BIGINT UNSIGNED DEFAULT 0;
  DECLARE lo_l BIGINT UNSIGNED;
  DECLARE lo_h BIGINT UNSIGNED;
  DECLARE prod_l BIGINT UNSIGNED;
  DECLARE prod_h BIGINT UNSIGNED;
  DECLARE pow32 BIGINT UNSIGNED DEFAULT 4294967296;
  DECLARE raw VARBINARY(16);
  DECLARE i INT;
  DECLARE digit INT;
  DECLARE carry INT;
  DECLARE msg VARCHAR(128);

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  IF CHAR_LENGTH(s) <> 22 THEN
    SET msg = CONCAT('uuid58: expected 22 characters, got ', CHAR_LENGTH(s));
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

  SET raw = x'00000000000000000000000000000000';
  SET i = 16;
  WHILE i >= 9 DO
    SET raw = INSERT(raw, i, 1, UNHEX(LPAD(HEX(lo MOD 256), 2, '0')));
    SET lo = lo DIV 256;
    SET i = i - 1;
  END WHILE;
  SET i = 8;
  WHILE i >= 1 DO
    SET raw = INSERT(raw, i, 1, UNHEX(LPAD(HEX(hi MOD 256), 2, '0')));
    SET hi = hi DIV 256;
    SET i = i - 1;
  END WHILE;
  RETURN raw;
END$$

-- Decodes a uuid58 string to the lowercase hyphenated UUID form.
CREATE FUNCTION uuid58_decode(s LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin)
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
CREATE FUNCTION is_uuid58(s LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin)
RETURNS TINYINT(1)
COMMENT 'True when s is a valid uuid58 string'
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE alphabet VARCHAR(58) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
    DEFAULT '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  DECLARE i INT;

  IF s IS NULL THEN
    RETURN NULL;
  END IF;
  IF CHAR_LENGTH(s) <> 22 THEN
    RETURN 0;
  END IF;
  SET i = 1;
  WHILE i <= 22 DO
    IF LOCATE(SUBSTRING(s, i, 1), alphabet) = 0 THEN
      RETURN 0;
    END IF;
    SET i = i + 1;
  END WHILE;
  IF s <= _utf8mb4'YcVfxkQb6JRzqk5kF2tNLv' COLLATE utf8mb4_bin THEN
    RETURN 1;
  END IF;
  RETURN 0;
END$$

DELIMITER ;

SET SESSION sql_mode = @uuid58_install_sql_mode;
