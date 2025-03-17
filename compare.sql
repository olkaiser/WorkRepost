CREATE OR REPLACE PROCEDURE track_customer_changes IS
    v_current_date DATE;
    v_previous_date DATE;
    
    -- 定义字段比较函数
    FUNCTION compare_and_log(
        p_customer_id IN NUMBER,
        p_change_type IN VARCHAR2,
        p_field_name IN VARCHAR2,
        p_old_value IN VARCHAR2,
        p_new_value IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        IF p_old_value IS NULL AND p_new_value IS NULL THEN
            RETURN FALSE;
        ELSIF NVL(p_old_value, 'NULL') != NVL(p_new_value, 'NULL') THEN
            INSERT INTO customer_change_log(customer_id, change_type, change_field, 
                                          old_value, new_value, change_date)
            VALUES(p_customer_id, p_change_type, p_field_name, 
                  p_old_value, p_new_value, SYSDATE);
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END;

    -- 定义字段比较过程
    PROCEDURE compare_fields(
        p_customer_id IN NUMBER,
        p_change_type IN VARCHAR2,
        p_fields IN SYS.ODCIVARCHAR2LIST
    ) IS
        v_sql VARCHAR2(4000);
        TYPE cur_type IS REF CURSOR;
        cur cur_type;
        v_old_value VARCHAR2(4000);
        v_new_value VARCHAR2(4000);
    BEGIN
        FOR i IN 1..p_fields.COUNT LOOP
            v_sql := 'SELECT curr.' || p_fields(i) || ' AS new_val, ' ||
                     'prev.' || p_fields(i) || ' AS old_val ' ||
                     'FROM ' || p_change_type || ' curr ' ||
                     'JOIN ' || p_change_type || ' prev ' ||
                     'ON curr.customer_id = prev.customer_id ' ||
                     'WHERE curr.data_date = :1 ' ||
                     'AND prev.data_date = :2 ' ||
                     'AND curr.customer_id = :3';
            
            OPEN cur FOR v_sql USING v_current_date, v_previous_date, p_customer_id;
            FETCH cur INTO v_new_value, v_old_value;
            CLOSE cur;
            
            compare_and_log(p_customer_id, p_change_type, p_fields(i), 
                          v_old_value, v_new_value);
        END LOOP;
    END;

BEGIN
    -- 获取日期
    SELECT MAX(data_date) INTO v_current_date FROM customers;
    SELECT MAX(data_date) INTO v_previous_date 
    FROM customers 
    WHERE data_date < v_current_date;

    -- 删除旧记录
    DELETE FROM customer_change_log 
    WHERE change_date < SYSDATE - 30;

    -- 定义需要比较的字段
    DECLARE
        customer_fields SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'customer_name', 'address', 'phone', 'email', 'status' -- 添加更多字段
        );
        contact_fields SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'contact_name', 'contact_phone', 'email', 'position' -- 添加更多字段
        );
        company_fields SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'company_name', 'industry', 'website', 'revenue' -- 添加更多字段
        );
    BEGIN
        -- 处理客户表
        FOR cust IN (SELECT customer_id FROM customers WHERE data_date = v_current_date) LOOP
            compare_fields(cust.customer_id, 'CUSTOMER', customer_fields);
        END LOOP;

        -- 处理联系人表
        FOR cont IN (SELECT customer_id FROM customer_contacts WHERE data_date = v_current_date) LOOP
            compare_fields(cont.customer_id, 'CONTACT', contact_fields);
        END LOOP;

        -- 处理公司信息表
        FOR comp IN (SELECT customer_id FROM customer_companies WHERE data_date = v_current_date) LOOP
            compare_fields(comp.customer_id, 'COMPANY', company_fields);
        END LOOP;
    END;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;