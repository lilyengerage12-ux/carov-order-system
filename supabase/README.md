# 云端接入准备

1. 在 Supabase 创建 `carov-flow` 项目。
2. 打开 SQL Editor，将 `schema.sql` 全部粘贴并执行。
3. 从项目 Connect 窗口复制 Project URL 与 Publishable key。
4. 仅将 Project URL 与 Publishable key 配置到网页端；严禁把 Secret key 或 service_role 放进 GitHub。
5. 为第一位管理员在 Authentication 中创建账号，再在 profiles 表中将角色设为 owner。

正式接入时必须启用 RLS。销售/设计可以查看订单计划；各部门只能修改自己负责的节点；只有老板和财务可操作收付款。
