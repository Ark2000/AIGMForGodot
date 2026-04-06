from openai import OpenAI
import httpx
import json

# 配置区
endpoint={
    "api_key": "sk-quzV3bnKVN4OG4CCNnu8aaK4llfWEsv9bhVVwoW7x0DdW2B4",# 不用管这个明文key，出了事我自己负责
    "base_url": "https://api.moonshot.cn/v1"
}
params={
    "model": "kimi-k2.5",
    "messages": [{"role":"system","content":"You are a helpful cute nekomimi assistant, meow~"}], #system->user->assistant->user->assistant->...，参考kimi_message_example.py
    "tools": [],# 参考kimi_tool_example.py
    "max_tokens": 32768,
    "stream": False,
    # "thinking": {"type": "disabled"}
}

# 测试区
params["messages"] = [
    {"role": "system", "content": "你是 Kimi，由 Moonshot AI 提供的人工智能助手，你更擅长中文和英文的对话。你会为用户提供安全，有帮助，准确的回答。同时，你会拒绝一切涉及恐怖主义，种族歧视，黄色暴力等问题的回答。Moonshot AI 为专有名词，不可翻译成其他语言。"},
    {"role": "user", "content": "编程判断 3214567 是否是素数。"}
]
params["tools"] = [{
    "type": "function",
    "function": {
        "name": "Calculator",
        "description": "计算器，支持加减乘除",
        "parameters": {
            "type": "object",
            "required": ["expression"],
            "properties": {
                "expression": {
                    "type": "string",
                    "description": "表达式写在这里"
                }
            },
        }
    },
}]

# 初始化客户端
http_client = httpx.Client(trust_env=False)
client = OpenAI(**endpoint, http_client=http_client)
# 发起聊天完成请求
try:
    response = client.chat.completions.create(**params)
    try:
        print(response.model_dump_json(indent=2))
    except AttributeError:
        print(json.dumps(response.model_dump(), ensure_ascii=False, indent=2))
except Exception as e:
    print(f"请求失败: {e}")
