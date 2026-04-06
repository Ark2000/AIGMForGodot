本文件将作为此项目的核心指导，AI的任何修改都不能与此文件冲突，项目的一切行为以此文件为准。**此文件仅限人类修改更新，AI只能读取此文件，不可修改**


# portable agent

核心理念。lua编写的超轻量级llm agent，适合嵌入到游戏运行时中，并且更新维护非常灵活。

# 架构

- lua层负责核心的agent逻辑编排。
- 由于lua不擅长网络通信，暂时使用python来处理和llm provider的交互
- 预期后面可以很轻松将该框架嵌入到godot，并且将python替换为godot的网络层。
- 使用 NDJSON + 管道通信

具体来说，网络层（Python）负责：
连接、协议、流、密钥、网络日志等。不负责业务tool叫什么，怎么执行、agent状态等。

Lua负责：
会话，包括历史上下文管理，messages列表，system prompt, 多轮和tool轮次等。编排，何时向模型发请求，何时执行tool，何时结束。工具，tool的schema，名字，参数，怎么执行等。

NDJSON怎么发：

1. Lua -> Json（请求）

上下文，工具，prompt，stream:true/false等。

2. python -> lua (响应）

流：一行一个事件，比如
{"v":1,"kind":"delta","role":"assistant","text":"..."}
{"v":1,"kind":"tool_delta",...}（若供应商把 tool 拆在流里）
{"v":1,"kind":"error","code":"...","message":"..."}
{"v":1,"kind":"done","usage":{...}}

加 v（协议版本） 很重要，以后换 Godot 网络层只要 实现同一套 NDJSON 即可

 刻意不划给某一侧的（避免扯皮）

JSON 解析：Lua/Python 各解析自己的 NDJSON 行即可；模型返回的 JSON（tool arguments） 建议在 Lua 里和编排在一起（Python 只传字符串也行）。
Token 计数：可只在 Python（若 provider 返回 usage），Lua 只展示/记录。

# llm provider

暂时支持支