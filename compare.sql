CREATE OR REPLACE PROCEDURE track_customer_changes IS
    v_current_date   DATE;
    v_previous_date  DATE;
    
    -- 定义需要比较的表及其字段
    TYPE table_config IS RECORD (
        table_name    VARCHAR2(30),    -- 表名
        fields        SYS.ODCIVARCHAR2LIST  -- 字段列表
    );
    
    -- 配置表和字段（示例）
    TYPE table_config_list IS TABLE OF table_config;
    v_tables table_config_list := table_config_list(
        table_config(
            'CUSTOMERS', 
            SYS.ODCIVARCHAR2LIST('customer_name', 'address', 'phone', 'email', 'status')
        ),
        table_config(
            'CUSTOMER_CONTACTS', 
            SYS.ODCIVARCHAR2LIST('contact_name', 'contact_phone', 'email', 'position')
        ),
        table_config(
            'CUSTOMER_COMPANIES', 
            SYS.ODCIVARCHAR2LIST('company_name', 'industry', 'website', 'revenue')
        )
    );

BEGIN
    -- 获取当前和前一数据日期
    SELECT MAX(data_date) INTO v_current_date FROM customers;
    SELECT MAX(data_date) INTO v_previous_date 
    FROM customers 
    WHERE data_date < v_current_date;

    -- 清理30天前的日志
    DELETE FROM customer_change_log 
    WHERE change_date < SYSDATE - 30;

    -- 遍历每张表
    FOR i IN 1..v_tables.COUNT LOOP
        DECLARE
            v_table_name  VARCHAR2(30) := v_tables(i).table_name;
            v_fields     SYS.ODCIVARCHAR2LIST := v_tables(i).fields;
        BEGIN
            -- 步骤1: 使用 MINUS 找到变化的客户号
            FOR cust IN (
                SELECT customer_id FROM (
                    SELECT customer_id 
                    FROM (SELECT customer_id FROM customers WHERE data_date = v_current_date)
                    MINUS
                    SELECT customer_id 
                    FROM (SELECT customer_id FROM customers WHERE data_date = v_previous_date)
                )
            LOOP
                -- 步骤2: 比较每个字段的新旧值
                FOR j IN 1..v_fields.COUNT LOOP
                    DECLARE
                        v_old_value VARCHAR2(4000);
                        v_new_value VARCHAR2(4000);
                    BEGIN
                        -- 动态获取新旧值
                        EXECUTE IMMEDIATE '
                            SELECT curr.' || v_fields(j) || ', prev.' || v_fields(j) || '
                            FROM ' || v_table_name || ' curr
                            JOIN ' || v_table_name || ' prev 
                                ON curr.customer_id = prev.customer_id
                            WHERE curr.data_date = :curr_date
                                AND prev.data_date = :prev_date
                                AND curr.customer_id = :cust_id'
                            INTO v_new_value, v_old_value
                            USING v_current_date, v_previous_date, cust.customer_id;

                        -- 插入日志（如果值不同）
                        IF NVL(v_old_value, '##NULL##') != NVL(v_new_value, '##NULL##') THEN
                            INSERT INTO customer_change_log (
                                customer_id, change_type, change_field,
                                old_value, new_value, change_date
                            ) VALUES (
                                cust.customer_id, 
                                v_table_name, 
                                v_fields(j),
                                v_old_value, 
                                v_new_value, 
                                SYSDATE
                            );
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL; -- 无新旧数据时不处理
                    END;
                END LOOP;
            END LOOP;
        END;
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END track_customer_changes;
/