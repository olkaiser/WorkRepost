CREATE OR REPLACE PROCEDURE transform_customer_accounts AS
  v_max_accounts NUMBER;
  v_sql VARCHAR2(4000);
  v_table_name VARCHAR2(100) := 'CUSTOMER_ACCOUNTS_TRANSFORMED';
  v_column_list VARCHAR2(4000) := '';
BEGIN
  -- 获取单个客户最大账户数量
  SELECT MAX(account_count) INTO v_max_accounts
  FROM (
    SELECT customer_id, COUNT(*) as account_count
    FROM customer_accounts
    GROUP BY customer_id
  );
  
  -- 从数据字典获取源表所有列(排除customer_id和rowid等特殊列)
  FOR col_rec IN (
    SELECT column_name 
    FROM all_tab_columns 
    WHERE table_name = 'CUSTOMER_ACCOUNTS'
    AND owner = USER
    AND column_name NOT IN ('CUSTOMER_ID', 'ROWID')
  LOOP
    v_column_list := v_column_list || col_rec.column_name || ',';
  END LOOP;
  
  -- 移除最后一个逗号
  v_column_list := RTRIM(v_column_list, ',');
  
  -- 先检查表是否存在，存在则删除
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name;
    DBMS_OUTPUT.PUT_LINE('已删除旧表 ' || v_table_name);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
        RAISE;
      END IF;
  END;
  
  -- 动态构建创建表语句
  v_sql := 'CREATE TABLE ' || v_table_name || ' AS 
            SELECT 
              customer_id,
              ''CUSTOMER_ACCOUNTS'' as source_table_name, ';
  
  -- 为每个可能的账户位置添加动态字段
  FOR i IN 1..v_max_accounts LOOP
    FOR col_rec IN (
      SELECT column_name 
      FROM all_tab_columns 
      WHERE table_name = 'CUSTOMER_ACCOUNTS'
      AND owner = USER
      AND column_name NOT IN ('CUSTOMER_ID', 'ROWID')
    )
    LOOP
      v_sql := v_sql || 
               'MAX(CASE WHEN rn = ' || i || ' THEN ' || col_rec.column_name || 
               ' END) AS ' || col_rec.column_name || '_tmp' || i || ', ';
    END LOOP;
  END LOOP;
  
  -- 移除最后一个逗号并完成SQL
  v_sql := RTRIM(v_sql, ', ') || ' 
            FROM (
              SELECT 
                ' || v_column_list || ',
                customer_id,
                ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY account_id) as rn
              FROM customer_accounts
            )
            GROUP BY customer_id';
  
  -- 执行转换
  EXECUTE IMMEDIATE v_sql;
  
  -- 输出结果统计
  DECLARE
    v_customer_count NUMBER;
    v_total_accounts NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_table_name INTO v_customer_count;
    SELECT COUNT(*) INTO v_total_accounts FROM customer_accounts;
    
    DBMS_OUTPUT.PUT_LINE('转换完成:');
    DBMS_OUTPUT.PUT_LINE('使用的列: ' || v_column_list);
    DBMS_OUTPUT.PUT_LINE('原始表记录数: ' || v_total_accounts || ' 条账户记录');
    DBMS_OUTPUT.PUT_LINE('新表记录数: ' || v_customer_count || ' 条客户记录');
    DBMS_OUTPUT.PUT_LINE('每个客户最多 ' || v_max_accounts || ' 个账户');
  END;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('错误: ' || SQLERRM);
END;
/