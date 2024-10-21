local OpenAI = require("parrot.provider.openai")
local logger = require("parrot.logger")
local utils = require("parrot.utils")
local Job = require("plenary.job")

local LiteLLM = setmetatable({}, { __index = OpenAI })
LiteLLM.__index = LiteLLM

function LiteLLM:new(endpoint, api_key)
  local obj = setmetatable(OpenAI:new(endpoint, api_key), self)
  obj.name = "litellm"
  return obj
end

function LiteLLM:get_available_models(online)
  if online and self:verify() then
    local models = {}
    local job = Job:new({
      command = "curl",
      args = {
        "-s",
        "-H", "Authorization: Bearer " .. self.api_key,
        self.endpoint:gsub("/v1/chat/completions$", "/v1/models"),
      },
      on_exit = function(j, return_val)
        if return_val == 0 then
          local result = table.concat(j:result(), "\n")
          local success, decoded = pcall(vim.json.decode, result)
          if success and decoded.data then
            for _, model in ipairs(decoded.data) do
              table.insert(models, model.id)
            end
          else
            logger.error("Failed to parse models response: " .. result)
          end
        else
          logger.error("Failed to fetch models from LiteLLM")
        end
      end
    })
    job:sync()
    return models
  else
    -- Fallback models
    return {
      "claude-haiku",
      "claude-sonnet",
    }
  end
end

function LiteLLM:process_stdout(response)
  logger.debug("LiteLLM received response: " .. response)
  if response:match("chat%.completion%.chunk") or response:match("chat%.completion") then
    local success, content = pcall(vim.json.decode, response)
    if success and content.choices and content.choices[1] then
      if content.choices[1].delta and content.choices[1].delta.content then
        return content.choices[1].delta.content
      elseif content.choices[1].message and content.choices[1].message.content then
        return content.choices[1].message.content
      end
    end
    logger.debug("LiteLLM parsed content: " .. vim.inspect(content))
  end
  logger.debug("LiteLLM could not process response: " .. response)
end

function LiteLLM:process_onexit(res)
  local success, parsed = pcall(vim.json.decode, res)
  if success then
    if parsed.error then
      local error_message = vim.inspect(parsed.error)
      logger.error(string.format("LiteLLM - Error: %s", error_message))
    elseif parsed.choices and parsed.choices[1] and parsed.choices[1].message then
      return parsed.choices[1].message.content
    else
      logger.error("LiteLLM - Unexpected response structure: " .. vim.inspect(parsed))
    end
  else
    logger.error("LiteLLM - Failed to parse JSON response: " .. res)
  end
end

return LiteLLM