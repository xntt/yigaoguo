-- 用户由 Supabase Auth 管理(auth.users)create table profiles (
  id uuid primary key references auth.users,
  free_quota int default 1,          -- 注册送1次
  paid_quota int default 0,          -- 次数包余额
  plan text default 'free',          -- free / pro99
  plan_expire timestamptz,
  created_at timestamptz default now()
);

-- 工单模板(管理后台可编辑, 先手动插数据)
create table templates (
  id text primary key,               -- 'yanjiang' / 'jianli'
  name text not null,
  fields jsonb not null,             -- 字段定义(见下)
  sys_prompt text not null,          -- 拼装模板
  active bool default true
);

-- 工单+订单合一
create table orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users,
  tpl_id text references templates(id),
  form_data jsonb not null,          -- 工单填写内容
  status text default 'pending',     -- pending/paid/generating/done/checked
  fee int default 990,               -- 单位:分
  pay_no text,
  drafts jsonb,                      -- 三版初稿
  review jsonb,                      -- 审稿结果(事实清单+质检)
  final_text text,                   -- 定稿
  created_at timestamptz default now()
);

-- 口径库: 同一用户的身份档案, 二次下单自动带出
create case when false then null as dossiers (
  user_id uuid references auth.users,
  key text,                          -- '我的身份' '领导风格' '雷区'
  value text,
  updated_at timestamptz default now(),
  unique(user_id, key)
);

-- 模板字段示例(演讲稿)
insert into templates (id, name, fields, sys_prompt) values
('yanjiang', '演讲稿/发言稿', '{
  "required": [
    {"key":"occasion","label":"什么场合","type":"select","options":["年度总结大会发言","个人先进典型发言","竞聘演讲","开幕/致辞","表态发言"]},
    {"key":"who","label":"您的身份(单位+职务+年限)","type":"textarea","ph":"例:镇农业服务中心一般干部,工作6年"},
    {"key":"audience","label":"讲给谁听","type":"text","ph":"例:镇党委书记、镇长及全镇干部100余人"},
    {"key":"length","label":"时长/字数","type":"select","options":["3分钟约900字","5分钟约1500字","8分钟约2400字"]},
    {"key":"points","label":"要讲的几件事(有数字写数字)","type":"textarea","ph":"例:1、灌溉项目提前1月完工,覆盖4个村;2、汛期值守20天转移30多人"},
    {"key":"taste","label":"想要的味道","type":"select","options":["稳重大气","亲民朴实,像自己说的话","亮眼出彩"]}
  ],
  "optional": [
    {"key":"style","label":"领导风格(爱什么厌什么)","type":"text","ph":"例:书记爱用排比句,喜欢实字,讨厌空话"},
    {"key":"taboo","label":"绝不提的雷区","type":"text"},
    {"key":"note","label":"其他要求(称呼/开头结尾格式等)","type":"text"}
  ]}'::jsonb,
  '你是资深公文写手。根据工单信息写{length}。要求:1.所有事实和数据只能来自工单,严禁编造任何数字、事件、场景细节;2.语言贴合用户身份和文化水平,{taste};3.开头称呼和结尾表态按用户要求;4.领导风格:{style};雷区:{taboo};5.正文以结束语为终点,结束语之后绝对禁止输出任何说明、建议、追问或服务性语言。'
);

-- 会员/次数扣减在API层判断
