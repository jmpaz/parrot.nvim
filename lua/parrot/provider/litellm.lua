local OpenAI = require("parrot.provider.openai")
local Ollama = require("parrot.provider.ollama")
local logger = require("parrot.logger")
local utils = require("parrot.utils")

---@class LiteLLM
---@field endpoint string
---@field api_key string|table
---@field name string
local LiteLLM = {}
LiteLLM.__index = LiteLLM

setmetatable(LiteLLM, {
  __index = function(t, k)
    return OpenAI[k] or Ollama[k] or rawget(t, k)
  end
})

-- Creates a new LiteLLM instance
---@param endpoint string
---@param api_key string|table
---@return LiteLLM
function LiteLLM:new(endpoint, api_key)
  return setmetatable({
    endpoint = endpoint,
    api_key = api_key,
    name = "litellm",
  }, self)
end

-- Override the get_available_models function to fetch models from litellm
---@param online boolean Whether to fetch models online
---@return string[]
function LiteLLM:get_available_models(online)
  if online and self:verify() then
    local job = require("plenary.job"):new({
      command = "curl",
      args = {
        self.endpoint:gsub("/chat/completions$", "/models"),
        "-H",
        "Authorization: Bearer " .. self.api_key,
      },
      on_exit = function(job)
        local parsed_response = utils.parse_raw_response(job:result())
        self:process_onexit(parsed_response)
        local ids = {}
        local success, decoded = pcall(vim.json.decode, parsed_response)
        if success and decoded.data then
          for _, item in ipairs(decoded.data) do
            table.insert(ids, item.id)
          end
        else
          logger.error("Failed to fetch models from litellm")
        end
        return ids
      end,
    })
    job:start()
    job:wait()
  end
  
  -- Fallback to a default list if online fetching fails
  return {
    "claude-haiku",
    "claude-sonnet",
  }
end

return LiteLLM