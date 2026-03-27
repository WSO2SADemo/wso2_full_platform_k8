const config = {
  isBaseUrl: import.meta.env.VITE_IS_BASE_URL || 'https://is.wso2.com',
  isClientId: import.meta.env.VITE_IS_CLIENT_ID || 'wQ0k7VuhwKxaO5Y68fTcffFd9u8a',
  agentApiBase: import.meta.env.VITE_AGENT_API_BASE || 'https://gw.wso2.com/insuranceagentapi/1.0.0',
  chatApiBase: import.meta.env.VITE_CHAT_API_BASE || 'https://gw.wso2.com/insuranceagentchatapi/1.0.0/insurance_agent',
  oboChatApiBase: import.meta.env.VITE_OBO_CHAT_API_BASE || 'https://gw.wso2.com/insuranceagentchatapi/1.0.0/insurance_obo',
};

export default config;
