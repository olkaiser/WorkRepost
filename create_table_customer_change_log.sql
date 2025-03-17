CREATE TABLE customer_change_log (
    log_id         NUMBER PRIMARY KEY,          -- 主键
    customer_id    NUMBER NOT NULL,            -- 客户ID
    change_type    VARCHAR2(20) NOT NULL,      -- 变动类型（客户/联系人/公司信息）
    change_field   VARCHAR2(50),               -- 变动字段
    old_value      VARCHAR2(4000),             -- 旧值
    new_value      VARCHAR2(4000),             -- 新值
    change_date    DATE DEFAULT SYSDATE,       -- 变动时间
    operator       VARCHAR2(50)                -- 操作人
);