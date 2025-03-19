# WorkRepost


写一个oracle的存储：
存储变动数据的表结构如下：
CREATE TABLE customer_change_log (
    customer_no    VARCHAR2(50),            -- 客户ID
    change_type    VARCHAR2(20) NOT NULL,      -- 变动类型（客户/联系人/公司信息）
    change_field   VARCHAR2(50),               -- 变动字段
    old_value      VARCHAR2(4000),             -- 旧值
    new_value      VARCHAR2(4000),             -- 新值
    data_date    DATE DEFAULT SYSDATE    -- 变动时间

);
要求：
1.用minus比对表的不同
2.使用all_tab_columns读取该表的字段，把数据有变动的字段写入customer_change_log 中，
3.比对的数据是RRA_SIDS.S_FLC_STTM_CUSTMOER的当天和前一天的数据，字段为DATA_DATE


