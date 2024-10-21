local OpenAI = require("parrot.provider.openai")
local utils = require("parrot.utils")

local LiteLLM = setmetatable({}, { __index = OpenAI })
LiteLLM.__index = LiteLLM

-- Available API parameters for LiteLLM
local AVAILABLE_API_PARAMETERS = {
    -- required
    messages = true,
    model = true,
    -- optional
    temperature = true,
    top_p = true,
    n = true,
    stream = true,
    stop = true,
    max_tokens = true,
    presence_penalty = true,
    frequency_penalty = true,
    logit_bias = true,
    user = true,
}

function LiteLLM:new(endpoint, api_key)
    local instance = OpenAI.new(self, endpoint, api_key)
    instance.name = "litellm"
    return setmetatable(instance, self)
end

function LiteLLM:preprocess_payload(payload)
    for _, message in ipairs(payload.messages) do
        message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
    end
    return utils.filter_payload_parameters(AVAILABLE_API_PARAMETERS, payload)
end

function LiteLLM:get_available_models(online)
    local ids = {}
    if online and self:verify() then
        local response = self:request("/v1/models", "GET")
        local success, decoded = pcall(vim.json.decode, response)
        if success and decoded.data then
            for _, item in ipairs(decoded.data) do
                table.insert(ids, item.id)
            end
        end
    end
    return ids
end

return LiteLLM
