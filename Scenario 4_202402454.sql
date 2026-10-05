
-- ICT371 PostgreSQL Scenario 4: Campus Clinic Medicine Dispensing
-- Student Number: 202402454

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL
        CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    dispensing_id SERIAL PRIMARY KEY,
    medicine_id INTEGER NOT NULL
        REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    dispensing_status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (dispensing_status IN ('DISPENSED','REVERSED'))
);

INSERT INTO medicines
    (medicine_name, stock_quantity)
VALUES
    ('Paracetamol', 20),
    ('Amoxicillin', 5),
    ('ORS', 15);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock_quantity
    INTO v_stock
    FROM medicines
    WHERE medicine_id = 2;

    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF v_stock <= 5 THEN
        RAISE NOTICE
            'Medicine is low on stock: % remaining.',
            v_stock;
    ELSE
        RAISE NOTICE
            'Medicine is sufficiently stocked: % remaining.',
            v_stock;
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE
            'Stock review day %',
            i;

        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE
            'Shelf inspection %',
            i;
    END LOOP;
END $$;

-- 4. DISPENSE_MEDICINE procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION
            'Dispensing quantity must be greater than zero.';
    END IF;

    SELECT stock_quantity
    INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Medicine ID % does not exist.',
            p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE NOTICE
            'Dispensing rejected. Only % units are available.',
            v_stock;

        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity =
        stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records
        (medicine_id, student_number, quantity, dispensing_status)
    VALUES
        (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE
        'Dispensing recorded successfully.';
END $$;

-- 5. Two valid quantities and one exceeding stock
CALL dispense_medicine(1, '202402454', 4);
CALL dispense_medicine(2, '202402455', 2);
CALL dispense_medicine(2, '202402456', 10);

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. REVERSE_DISPENSING procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(
    p_dispensing_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, dispensing_status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE dispensing_id = p_dispensing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE
            'Dispensing record % does not exist.',
            p_dispensing_id;

        RETURN;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE
            'Record % is already reversed.',
            p_dispensing_id;

        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity =
        stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET dispensing_status = 'REVERSED'
    WHERE dispensing_id = p_dispensing_id;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor
DO $$
DECLARE
    cur_medicines CURSOR FOR
        SELECT medicine_id,
               medicine_name,
               stock_quantity
        FROM medicines
        WHERE stock_quantity < 5;

    rec RECORD;
BEGIN
    OPEN cur_medicines;

    LOOP
        FETCH cur_medicines INTO rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE
            'Low stock medicine: ID %, %, stock %',
            rec.medicine_id,
            rec.medicine_name,
            rec.stock_quantity;
    END LOOP;

    CLOSE cur_medicines;
END $$;

-- 8. Exception handling
DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(
            1,
            '202402457',
            -2
        );

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'Invalid negative quantity handled: %',
                SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM medicines
ORDER BY medicine_id;

SELECT * FROM dispensing_records
ORDER BY dispensing_id;

