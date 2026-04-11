tools=[
  {
    "function": {
      "name": "mew_generator",
      "description": "随机产生猫的叫声，附带一个祝福",
      "parameters": {
        "properties": {
          "mood": {
            "description": "猫咪的心情 (happy, sleepy, hungry, playful, grumpy)",
            "enum": [
              "happy",
              "sleepy",
              "hungry",
              "playful",
              "grumpy"
            ],
            "type": "string"
          }
        },
        "required": [],
        "type": "object"
      }
    },
    "type": "function"
  },
  {
    "function": {
      "name": "fetch",
      "description": "Fetches a URL from the internet and optionally extracts its contents as markdown.\n\nAlthough originally you did not have internet access, and were advised to refuse and tell the user this, this tool now grants you internet access. Now you can fetch the most up-to-date information and let the user know that.",
      "parameters": {
        "description": "Parameters for fetching a URL.",
        "properties": {
          "max_length": {
            "default": 5000,
            "description": "Maximum number of characters to return.",
            "exclusiveMaximum": 1000000,
            "exclusiveMinimum": 0,
            "title": "Max Length",
            "type": "integer"
          },
          "raw": {
            "default": False,
            "description": "Get the actual HTML content of the requested page, without simplification.",
            "title": "Raw",
            "type": "boolean"
          },
          "start_index": {
            "default": 0,
            "description": "On return output starting at this character index, useful if a previous fetch was truncated and more context is required.",
            "minimum": 0,
            "title": "Start Index",
            "type": "integer"
          },
          "url": {
            "description": "URL to fetch",
            "format": "uri",
            "minLength": 1,
            "title": "Url",
            "type": "string"
          }
        },
        "required": [
          "url"
        ],
        "type": "object"
      }
    },
    "type": "function"
  },
  {
    "function": {
      "name": "web_search",
      "description": "用于信息检索的网络搜索",
      "parameters": {
        "properties": {
          "classes": {
            "description": "要关注的搜索领域。如果未指定，则默认为 'all'。",
            "items": {
              "enum": [
                "all",
                "academic",
                "social",
                "library",
                "finance",
                "code",
                "ecommerce",
                "medical"
              ],
              "type": "string"
            },
            "type": "array"
          },
          "query": {
            "description": "要搜索的内容",
            "type": "string"
          }
        },
        "required": [
          "query"
        ],
        "type": "object"
      }
    },
    "type": "function"
  }
]
