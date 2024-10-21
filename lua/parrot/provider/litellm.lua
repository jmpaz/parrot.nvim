local OpenAI = require("parrot.provider.openai")
local logger = require("parrot.logger")
local utils = require("parrot.utils")

local LiteLLM = setmetatable({}, { __index = OpenAI })
LiteLLM.__index = LiteLLM

function LiteLLM:new(endpoint, api_key)
  local obj = setmetatable(OpenAI:new(endpoint, api_key), self)
  obj.name = "litellm"
  return obj
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