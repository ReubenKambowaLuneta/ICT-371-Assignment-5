
-- ICT371 PostgreSQL Scenario 3: Student Hostel Room Allocation
-- Student Number: 202402454

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_name VARCHAR(50) NOT NULL,
    available_bed_spaces INTEGER NOT NULL
        CHECK (available_bed_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL,
    room_id INTEGER NOT NULL
        REFERENCES hostel_rooms(room_id),
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'ALLOCATED'
        CHECK (allocation_status IN ('ALLOCATED','COMPLETED'))
);

INSERT INTO hostel_rooms
    (room_name, available_bed_spaces)
VALUES
    ('Room A', 3),
    ('Room B', 1),
    ('Room C', 5);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    v_spaces INTEGER;
BEGIN
    SELECT available_bed_spaces
    INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = 2;

    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE
            'Room has several spaces: % available.',
            v_spaces;
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Hostel inspection day %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Room check %',
            i;
    END LOOP;
END $$;

-- 4. ALLOCATE_ROOM procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_student_number IS NULL
       OR btrim(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Student number cannot be blank.';
    END IF;

    SELECT available_bed_spaces
    INTO v_available
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Room ID % does not exist.',
            p_room_id;
    END IF;

    IF v_available < 1 THEN
        RAISE NOTICE
            'Allocation rejected. Room is full.';

        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces =
        available_bed_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations
        (student_number, room_id, allocation_status)
    VALUES
        (p_student_number, p_room_id, 'ALLOCATED');

    RAISE NOTICE
        'Student allocated successfully.';
END $$;

-- 5. Two valid allocations and one allocation to a full room
CALL allocate_room('202402454', 1);
CALL allocate_room('202402455', 2);
CALL allocate_room('202402456', 2);

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. CHECK_OUT procedure
CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INTEGER;
    v_status VARCHAR;
BEGIN
    SELECT room_id, allocation_status
    INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE
            'Allocation % does not exist.',
            p_allocation_id;

        RETURN;
    END IF;

    IF v_status = 'COMPLETED' THEN
        RAISE NOTICE
            'Allocation % is already completed.',
            p_allocation_id;

        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces =
        available_bed_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET allocation_status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;
END $$;

CALL check_out(1);
CALL check_out(1);

-- 7. Explicit cursor
DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_id,
               room_name,
               available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;

    rec RECORD;
BEGIN
    OPEN cur_rooms;

    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Full or nearly full room: ID %, %, spaces %',
            rec.room_id,
            rec.room_name,
            rec.available_bed_spaces;
    END LOOP;

    CLOSE cur_rooms;
END $$;

-- 8. Exception handling
DO $$
BEGIN
    BEGIN
        CALL allocate_room('   ', 3);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'Invalid student number handled: %',
                SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM hostel_rooms
ORDER BY room_id;

SELECT * FROM allocations
ORDER BY allocation_id;
