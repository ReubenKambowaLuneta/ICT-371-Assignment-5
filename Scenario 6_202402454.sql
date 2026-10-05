
-- ICT371 PostgreSQL Scenario 6: University Event Seat Booking
-- Student Number: 202402454

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(150) NOT NULL,
    available_seats INTEGER NOT NULL
        CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL
        REFERENCES events(event_id),
    student_number VARCHAR(30) NOT NULL,
    number_of_seats INTEGER NOT NULL,
    booking_status VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
        CHECK (booking_status IN ('BOOKED','CANCELLED'))
);

INSERT INTO events
    (event_name, available_seats)
VALUES
    ('ICT Career Day', 50),
    ('Science Seminar', 20),
    ('University Cultural Night', 100);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    v_seats INTEGER;
BEGIN
    SELECT available_seats
    INTO v_seats
    FROM events
    WHERE event_id = 2;

    IF v_seats = 0 THEN
        RAISE NOTICE 'Event is full.';
    ELSIF v_seats <= 10 THEN
        RAISE NOTICE
            'Event is nearly full: % seats remain.',
            v_seats;
    ELSE
        RAISE NOTICE
            'Event has plenty of seats: % remain.',
            v_seats;
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Booking reminder day %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Entrance check %',
            i;
    END LOOP;
END $$;

-- 4. BOOK_SEATS procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INTEGER,
    p_student_number VARCHAR,
    p_number_of_seats INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_number_of_seats <= 0 THEN
        RAISE EXCEPTION
            'Number of seats must be greater than zero.';
    END IF;

    SELECT available_seats
    INTO v_available
    FROM events
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Event ID % does not exist.',
            p_event_id;
    END IF;

    IF v_available < p_number_of_seats THEN
        RAISE NOTICE
            'Booking rejected. Only % seats are available.',
            v_available;

        RETURN;
    END IF;

    UPDATE events
    SET available_seats =
        available_seats - p_number_of_seats
    WHERE event_id = p_event_id;

    INSERT INTO bookings
        (event_id, student_number, number_of_seats, booking_status)
    VALUES
        (p_event_id, p_student_number, p_number_of_seats, 'BOOKED');

    RAISE NOTICE
        'Booking recorded successfully.';
END $$;

-- 5. Two valid bookings and one exceeding request
CALL book_seats(1, '202402454', 5);
CALL book_seats(2, '202402455', 8);
CALL book_seats(2, '202402456', 20);

SELECT * FROM events;
SELECT * FROM bookings;

-- 6. CANCEL_BOOKING procedure
CREATE OR REPLACE PROCEDURE cancel_booking(
    p_booking_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INTEGER;
    v_seats INTEGER;
    v_status VARCHAR;
BEGIN
    SELECT event_id, number_of_seats, booking_status
    INTO v_event_id, v_seats, v_status
    FROM bookings
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE
            'Booking % does not exist.',
            p_booking_id;

        RETURN;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE
            'Booking % is already cancelled.',
            p_booking_id;

        RETURN;
    END IF;

    UPDATE events
    SET available_seats =
        available_seats + v_seats
    WHERE event_id = v_event_id;

    UPDATE bookings
    SET booking_status = 'CANCELLED'
    WHERE booking_id = p_booking_id;
END $$;

CALL cancel_booking(1);
CALL cancel_booking(1);

-- 7. Explicit cursor
DO $$
DECLARE
    cur_events CURSOR FOR
        SELECT event_id,
               event_name,
               available_seats
        FROM events
        WHERE available_seats <= 10;

    rec RECORD;
BEGIN
    OPEN cur_events;

    LOOP
        FETCH cur_events INTO rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Full or nearly full event: ID %, %, seats %',
            rec.event_id,
            rec.event_name,
            rec.available_seats;
    END LOOP;

    CLOSE cur_events;
END $$;

-- 8. Exception handling
DO $$
BEGIN
    BEGIN
        CALL book_seats(
            1,
            '202402457',
            0
        );

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'Invalid zero-seat request handled: %',
                SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM events
ORDER BY event_id;

SELECT * FROM bookings
ORDER BY booking_id;

