-- Conformance test against spec/vectors.json. Run mysql/test.sh, which loads
-- the vectors into @vectors, installs uuid58.sql, and sources this file in a
-- scratch database. Do not install this file into an application database.

DROP TABLE IF EXISTS failures;
DROP TABLE IF EXISTS roundtrip_got;
CREATE TABLE failures (description TEXT);
CREATE TABLE roundtrip_got (
  description TEXT NOT NULL,
  uuid VARCHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  got VARCHAR(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
);

DROP PROCEDURE IF EXISTS uuid58_test_error_kind;
DROP PROCEDURE IF EXISTS uuid58_test_expect_error;
DROP PROCEDURE IF EXISTS uuid58_run_tests;

DELIMITER $$

-- The spec error kind for the statement, or NULL if it does not raise.
-- The statement must be a single SET, so a successful call produces no result set.
CREATE PROCEDURE uuid58_test_error_kind(IN stmt LONGTEXT, OUT kind TEXT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      @uuid58_sqlstate = RETURNED_SQLSTATE,
      @uuid58_msg = MESSAGE_TEXT;
    SET kind = CASE @uuid58_sqlstate
      WHEN '22026' THEN 'invalid_length'
      WHEN '22018' THEN 'invalid_character'
      WHEN '22003' THEN 'overflow'
      ELSE CONCAT('unexpected ', @uuid58_sqlstate, ': ', @uuid58_msg)
    END;
    BEGIN
      DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;
      DEALLOCATE PREPARE uuid58_test_stmt;
    END;
  END;

  SET kind = NULL;
  SET @uuid58_test_sql = stmt;
  PREPARE uuid58_test_stmt FROM @uuid58_test_sql;
  EXECUTE uuid58_test_stmt;
  DEALLOCATE PREPARE uuid58_test_stmt;
END$$

CREATE PROCEDURE uuid58_test_expect_error(IN stmt LONGTEXT, IN errors JSON, IN label TEXT)
BEGIN
  DECLARE ok INT;
  CALL uuid58_test_error_kind(stmt, @kind);
  SET ok = JSON_CONTAINS(errors, JSON_QUOTE(@kind));
  IF @kind IS NULL OR ok IS NULL OR ok = 0 THEN
    INSERT INTO failures VALUES (CONCAT(label, ': ', IFNULL(@kind, 'no error')));
  END IF;
END$$

CREATE PROCEDURE uuid58_run_tests()
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE n INT;
  DECLARE input LONGTEXT;
  DECLARE expected LONGTEXT;
  DECLARE description TEXT;
  DECLARE errors JSON;
  DECLARE bytes TEXT;
  DECLARE uuid VARCHAR(36);
  DECLARE uuid58 VARCHAR(22);
  DECLARE hex VARCHAR(32);
  DECLARE stmt LONGTEXT;

  -- Every check is NULL-safe: a NULL @vectors, or a section that is missing,
  -- must fail here instead of running no cases and passing.
  IF @vectors IS NULL
     OR IFNULL(JSON_VALID(@vectors), 0) <> 1
     OR IFNULL(JSON_UNQUOTE(JSON_EXTRACT(@vectors, '$.spec_version')), '') <> '1.1.0'
     OR IFNULL(JSON_LENGTH(@vectors, '$.roundtrip'), 0) = 0
     OR IFNULL(JSON_LENGTH(@vectors, '$.encode.valid'), 0) = 0
     OR IFNULL(JSON_LENGTH(@vectors, '$.encode.invalid'), 0) = 0
     OR IFNULL(JSON_LENGTH(@vectors, '$.encode.invalid_bytes'), 0) = 0
     OR IFNULL(JSON_LENGTH(@vectors, '$.decode.invalid'), 0) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'unexpected or unreadable spec/vectors.json';
  END IF;

  SET n = JSON_LENGTH(@vectors, '$.roundtrip');
  WHILE i < n DO
    SET uuid = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.roundtrip[', i, '].uuid')));
    SET uuid58 = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.roundtrip[', i, '].uuid58')));
    SET description = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.roundtrip[', i, '].description')));
    SET hex = REPLACE(uuid, '-', '');
    -- <=> rather than <>: a function that returns NULL must count as a failure.
    IF NOT (uuid58_encode(uuid) COLLATE utf8mb4_bin <=> uuid58 COLLATE utf8mb4_bin)
       OR NOT (uuid58_encode(hex) COLLATE utf8mb4_bin <=> uuid58 COLLATE utf8mb4_bin)
       OR NOT (uuid58_encode_bytes(UNHEX(hex)) COLLATE utf8mb4_bin <=> uuid58 COLLATE utf8mb4_bin)
       OR NOT (uuid58_decode(uuid58) COLLATE utf8mb4_bin <=> uuid COLLATE utf8mb4_bin)
       OR NOT (LOWER(HEX(uuid58_decode_bytes(uuid58))) COLLATE utf8mb4_bin <=> hex COLLATE utf8mb4_bin)
       OR NOT (is_uuid58(uuid58) <=> 1) THEN
      INSERT INTO failures VALUES (CONCAT('roundtrip: ', description));
    END IF;
    INSERT INTO roundtrip_got VALUES (description, uuid, uuid58);
    SET i = i + 1;
  END WHILE;

  -- Consecutive UUIDs in integer order must encode in increasing binary order,
  -- using the collation the functions actually return. Columns are qualified
  -- because a bare description or uuid is the local variable of that name.
  INSERT INTO failures (description)
  SELECT CONCAT('ordering: ', pairs.description)
  FROM (
    SELECT r.description, r.uuid, LAG(r.uuid) OVER (ORDER BY r.uuid) AS prev_uuid
    FROM roundtrip_got AS r
  ) AS pairs
  WHERE pairs.prev_uuid IS NOT NULL
    AND NOT IFNULL(uuid58_encode(pairs.prev_uuid) < uuid58_encode(pairs.uuid), FALSE);

  IF COLLATION(uuid58_encode('00000000-0000-0000-0000-000000000000')) <> 'utf8mb4_bin' THEN
    INSERT INTO failures VALUES ('encode result collation');
  END IF;
  IF NOT (_utf8mb4'B' COLLATE utf8mb4_bin < _utf8mb4'a' COLLATE utf8mb4_bin) THEN
    INSERT INTO failures VALUES ('utf8mb4_bin is not byte order');
  END IF;

  SET i = 0;
  SET n = JSON_LENGTH(@vectors, '$.encode.valid');
  WHILE i < n DO
    SET input = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.valid[', i, '].input')));
    SET expected = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.valid[', i, '].output')));
    SET description = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.valid[', i, '].description')));
    SET @uuid58_test_out = NULL;
    SET stmt = CONCAT('SET @uuid58_test_out = uuid58_encode(', QUOTE(input), ')');
    CALL uuid58_test_error_kind(stmt, @kind);
    IF @kind IS NOT NULL
       OR @uuid58_test_out IS NULL
       -- CONVERT: a NULL user variable is binary, which MySQL will not collate.
       OR NOT (CONVERT(@uuid58_test_out USING utf8mb4) COLLATE utf8mb4_bin
                 <=> expected COLLATE utf8mb4_bin) THEN
      INSERT INTO failures VALUES (CONCAT(
        'encode valid: ', description, ': ', IFNULL(@kind, IFNULL(@uuid58_test_out, 'no output'))
      ));
    END IF;
    SET i = i + 1;
  END WHILE;

  -- Includes the lenient cases: this implementation is strict.
  SET i = 0;
  SET n = JSON_LENGTH(@vectors, '$.encode.invalid');
  WHILE i < n DO
    SET input = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid[', i, '].input')));
    SET description = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid[', i, '].description')));
    SET errors = JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid[', i, '].errors'));
    CALL uuid58_test_expect_error(
      CONCAT('SET @uuid58_test_out = uuid58_encode(', QUOTE(input), ')'),
      errors,
      CONCAT('encode invalid: ', description)
    );
    SET i = i + 1;
  END WHILE;

  SET i = 0;
  SET n = JSON_LENGTH(@vectors, '$.encode.invalid_bytes');
  WHILE i < n DO
    SET bytes = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid_bytes[', i, '].bytes')));
    SET description = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid_bytes[', i, '].description')));
    SET errors = JSON_EXTRACT(@vectors, CONCAT('$.encode.invalid_bytes[', i, '].errors'));
    -- UNHEX('') is NULL on some servers; an empty hex literal is an empty binary.
    IF bytes = '' THEN
      SET stmt = 'SET @uuid58_test_out = uuid58_encode_bytes(x'''')';
    ELSE
      SET stmt = CONCAT(
        'SET @uuid58_test_out = uuid58_encode_bytes(UNHEX(', QUOTE(bytes), '))'
      );
    END IF;
    CALL uuid58_test_expect_error(stmt, errors, CONCAT('encode invalid_bytes: ', description));
    SET i = i + 1;
  END WHILE;

  -- encode.invalid_integers does not apply: there is no integer API.

  SET i = 0;
  SET n = JSON_LENGTH(@vectors, '$.decode.invalid');
  WHILE i < n DO
    SET input = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.decode.invalid[', i, '].input')));
    SET description = JSON_UNQUOTE(JSON_EXTRACT(@vectors, CONCAT('$.decode.invalid[', i, '].description')));
    SET errors = JSON_EXTRACT(@vectors, CONCAT('$.decode.invalid[', i, '].errors'));
    CALL uuid58_test_expect_error(
      CONCAT('SET @uuid58_test_out = uuid58_decode(', QUOTE(input), ')'),
      errors,
      CONCAT('decode invalid: ', description)
    );
    CALL uuid58_test_error_kind(
      CONCAT('SET @uuid58_test_out = uuid58_decode_bytes(', QUOTE(input), ')'),
      @kind2
    );
    IF NOT (@kind2 <=> @kind) OR NOT (is_uuid58(input) <=> 0) THEN
      INSERT INTO failures VALUES (CONCAT(
        'decode invalid agreement: ', description,
        ': decode=', IFNULL(@kind, 'no error'),
        ' bytes=', IFNULL(@kind2, 'no error'),
        ' is_uuid58=', IFNULL(is_uuid58(input), 'null')
      ));
    END IF;
    SET i = i + 1;
  END WHILE;

  IF uuid58_encode(NULL) IS NOT NULL
     OR uuid58_encode_bytes(NULL) IS NOT NULL
     OR uuid58_decode(NULL) IS NOT NULL
     OR uuid58_decode_bytes(NULL) IS NOT NULL
     OR is_uuid58(NULL) IS NOT NULL THEN
    INSERT INTO failures VALUES ('NULL handling');
  END IF;

  IF NOT (uuid58_encode_bytes(UNHEX('f4b247fd1f8745d4aa061c6fc0a8dfaf'))
            COLLATE utf8mb4_bin <=> 'XDY9dmBbcMBXqcRvYw8xJ2')
     OR NOT (uuid58_decode_bytes('XDY9dmBbcMBXqcRvYw8xJ2')
               <=> UNHEX('f4b247fd1f8745d4aa061c6fc0a8dfaf')) THEN
    INSERT INTO failures VALUES ('binary example');
  END IF;

  -- Current MySQL and MariaDB reject stored functions in generated columns.
  -- A view can call them.
  CREATE TABLE uuid58_src (
    id VARCHAR(36) NOT NULL PRIMARY KEY
  );
  INSERT INTO uuid58_src (id) VALUES
    ('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'),
    ('00000000-0000-0000-0000-000000000000');
  CREATE VIEW uuid58_ids AS
  SELECT id, uuid58_encode(id) AS short_id FROM uuid58_src;
  IF NOT ((SELECT short_id FROM uuid58_ids WHERE id = 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf')
            COLLATE utf8mb4_bin <=> 'XDY9dmBbcMBXqcRvYw8xJ2')
     OR NOT ((SELECT id FROM uuid58_ids ORDER BY short_id LIMIT 1)
               <=> '00000000-0000-0000-0000-000000000000')
     OR NOT ((SELECT COLLATION(short_id) FROM uuid58_ids LIMIT 1) <=> 'utf8mb4_bin') THEN
    INSERT INTO failures VALUES ('view');
  END IF;

  -- MariaDB has a native UUID type. CREATE TABLE is prepared because MySQL
  -- cannot parse the column type.
  IF @@version LIKE '%MariaDB%' THEN
    SET @uuid58_test_sql = 'CREATE TABLE uuid58_native (id UUID NOT NULL PRIMARY KEY)';
    PREPARE uuid58_test_stmt FROM @uuid58_test_sql;
    EXECUTE uuid58_test_stmt;
    DEALLOCATE PREPARE uuid58_test_stmt;
    INSERT INTO uuid58_native VALUES ('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf');
    IF NOT ((SELECT uuid58_encode(id) FROM uuid58_native)
              COLLATE utf8mb4_bin <=> 'XDY9dmBbcMBXqcRvYw8xJ2')
       OR NOT ((SELECT uuid58_encode_bytes(id) FROM uuid58_native)
                 COLLATE utf8mb4_bin <=> 'XDY9dmBbcMBXqcRvYw8xJ2')
       OR NOT ((SELECT COUNT(*) FROM uuid58_native
                WHERE id = uuid58_decode('XDY9dmBbcMBXqcRvYw8xJ2')) <=> 1)
       OR NOT ((SELECT COUNT(*) FROM uuid58_native
                WHERE id = uuid58_decode_bytes('XDY9dmBbcMBXqcRvYw8xJ2')) <=> 1) THEN
      INSERT INTO failures VALUES ('MariaDB UUID column');
    END IF;
  END IF;

  SET @n = (SELECT COUNT(*) FROM failures);
  IF @n > 0 THEN
    SELECT f.description AS failure FROM failures AS f;
    SET @uuid58_failure_message = CONCAT(@n, ' uuid58 conformance failure(s)');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @uuid58_failure_message;
  END IF;
  SELECT CONCAT('all vectors passed (', @@version, ')') AS result;
END$$

DELIMITER ;

CALL uuid58_run_tests();
