const STORAGE_KEY = 'healthguard_ai_demo_config_v2';

export const BAKED_API_KEY = 'eyJ4NXQjUzI1NiI6Ik4yTmlZVFkxT1RWaE9UTmhPVEV6T1dKbU1qaGlPVEUwTm1ZMFl6RTJOVFUzTUdJeE9EZ3lPRFU0WlRCaVpHRXdNalZoT0RFNE1qaGpObVl4TVdKbFpRPT0iLCJraWQiOiJnYXRld2F5X2NlcnRpZmljYXRlX2FsaWFzIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYifQ==.eyJzdWIiOiJhZG1pbkBjYXJib24uc3VwZXIiLCJhcHBsaWNhdGlvbiI6eyJpZCI6NiwidXVpZCI6IjE4ODg4ZWJmLWVmMGYtNDVjNy1hYmQxLWZkMmU0N2ZiNzdiYiJ9LCJpc3MiOiJodHRwczpcL1wvY3Aud3NvMi5jb206NDQzXC9vYXV0aDJcL3Rva2VuIiwia2V5dHlwZSI6IlBST0RVQ1RJT04iLCJwZXJtaXR0ZWRSZWZlcmVyIjoiIiwidG9rZW5fdHlwZSI6ImFwaUtleSIsInBlcm1pdHRlZElQIjoiIiwiaWF0IjoxNzc1MDUyNTgyLCJqdGkiOiI3OGU5MDhkZS00NjkyLTQyOTEtOGM3ZC01YmMzYmU3YmNkODcifQ==.GRKm6VKBaKcYVF7xOs48eLDuesyTVYrBtnmns31DB-ldZf2YIAx1h7E6G6oTrFLFaHJHv3_IwPITUI6Wld7K_vgzjxJVjBP4DOT_r94BHlEryZrT97QPe4rXh4fySZi8bNpSO4urrhVMvN_RQeve8eMoXbBt88YPhF_q3TiObpt6Sy9HRE6KPgpo-pdXnjxjlQiALc2GZ2SJ8xr84w6EfyCFxr5bVd_q_G-FhKtfArI0qjMpBldeTE_a4Wei5QohZFvr1VLxo97RpDWcVGDKDpRgwBhlWv-qlIXmHm5WpbZj195x3KBoUQzwU9Fwfe29xudwP6E_19gNLoIQPn8yMQ==';

export const GW_BASE = 'https://gw.wso2.com/azureopenaiserviceapi/2025-04-01-preview/openai/responses';

export const DEFAULT_CONFIG = {
  apiKey: BAKED_API_KEY,
  endpoints: {
    promptTemplate:    "https://gw.wso2.com/mistralpromtandgrtestapi/0.0.2/v1/chat/completions",
    promptDecorator:   "https://gw.wso2.com/airatelimandpromtdecmistralapi/0.0.2/v1/chat/completions",
    rateLimiting:      "https://gw.wso2.com/airatelimandpromtdecmistralapi/0.0.2/v1/chat/completions",
    semanticCache:     "https://gw.wso2.com/mistralpromtandgrtestapi/0.0.2/v1/chat/completions",
    azureGuardrail:    GW_BASE,
    contentLength:     "https://gw.wso2.com/mistralpromtandgrtestapi/0.0.2/v1/chat/completions",
    semanticGuardrail: "https://gw.wso2.com/mistralpromtandgrtestapi/0.0.2/v1/chat/completions",
    urlGuardrail:      "https://gw.wso2.com/mistralpromtandgrtestapi/0.0.2/v1/chat/completions",
  },
};

export function loadConfig() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const p = JSON.parse(saved);
      // Only restore apiKey from localStorage; endpoints always come from DEFAULT_CONFIG
      return { ...DEFAULT_CONFIG, apiKey: p.apiKey || DEFAULT_CONFIG.apiKey };
    }
  } catch {}
  return { ...DEFAULT_CONFIG };
}

export function saveConfig(config) {
  // Only persist apiKey; endpoints are managed in config.js
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ apiKey: config.apiKey }));
}
