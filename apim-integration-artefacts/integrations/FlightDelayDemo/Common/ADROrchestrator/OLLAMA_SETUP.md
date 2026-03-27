# Ollama Setup Guide for ADR Orchestrator

## What is Ollama?

Ollama is a local LLM (Large Language Model) runtime that allows you to run AI models on your own hardware. Unlike cloud-based services like OpenAI, Ollama:

✅ **Runs completely locally** - No internet required  
✅ **100% free** - No API costs or usage limits  
✅ **Private** - Your data never leaves your server  
✅ **Fast** - No network latency  
✅ **Offline-capable** - Works without internet  

## Installation

### macOS
```bash
# Using Homebrew
brew install ollama

# Or download from https://ollama.ai
```

### Linux
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Windows
Download the installer from https://ollama.ai/download/windows

### Docker
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

## Verify Installation

```bash
# Check Ollama is running
ollama --version

# List available models
ollama list

# Check service is accessible
curl http://localhost:11434/api/tags
```

## Pull Models

### Recommended Models for ADR Orchestrator

#### 1. **llama3.2** (Default - Recommended)
```bash
ollama pull llama3.2
```
- **Size**: 2GB
- **RAM**: 4GB minimum
- **Speed**: Fast
- **Quality**: Good for most tasks
- **Best for**: Production use with balanced performance

#### 2. **llama3.2:1b** (Lightweight)
```bash
ollama pull llama3.2:1b
```
- **Size**: 1.3GB
- **RAM**: 2GB minimum
- **Speed**: Very fast
- **Quality**: Good for simple queries
- **Best for**: Resource-constrained environments

#### 3. **llama3.1:8b** (High Quality)
```bash
ollama pull llama3.1:8b
```
- **Size**: 4.7GB
- **RAM**: 8GB minimum
- **Speed**: Moderate
- **Quality**: Better reasoning and accuracy
- **Best for**: Complex recovery scenarios

#### 4. **llama3.1:70b** (Best Quality)
```bash
ollama pull llama3.1:70b
```
- **Size**: 40GB
- **RAM**: 48GB minimum
- **Speed**: Slow
- **Quality**: Excellent reasoning
- **Best for**: High-stakes decisions, research

## Configuration

### Update Config.toml

```toml
# Ollama Configuration
ollamaServiceUrl = "http://localhost:11434"
ollamaModel = "llama3.2"

# For Docker deployments
# ollamaServiceUrl = "http://ollama:11434"
```

### Model Selection Guide

Choose based on your requirements:

| Use Case | Model | RAM | Speed | Quality |
|----------|-------|-----|-------|---------|
| Development/Testing | llama3.2:1b | 2GB | ⚡⚡⚡ | ⭐⭐ |
| Production (Standard) | llama3.2 | 4GB | ⚡⚡ | ⭐⭐⭐ |
| Production (High Quality) | llama3.1:8b | 8GB | ⚡ | ⭐⭐⭐⭐ |
| Enterprise/Research | llama3.1:70b | 48GB | 🐌 | ⭐⭐⭐⭐⭐ |

## Testing Ollama

### 1. Test Basic Functionality
```bash
ollama run llama3.2 "Hello, how are you?"
```

### 2. Test Function Calling
```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    {
      "role": "user",
      "content": "What is the weather like?"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get the current weather",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "The city name"
            }
          },
          "required": ["location"]
        }
      }
    }
  ]
}'
```

### 3. Test with ADR Agent
```bash
# Start your ADR services
bal run

# Test AI agent
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "List all recovery plans"}'
```

## Performance Tuning

### 1. GPU Acceleration (Optional)

If you have an NVIDIA GPU:

```bash
# Install CUDA toolkit
# Then Ollama will automatically use GPU

# Verify GPU usage
nvidia-smi
```

### 2. Memory Management

```bash
# Set memory limit (in GB)
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1

# Restart Ollama
ollama serve
```

### 3. Context Window

Larger context = more memory but better understanding:

```bash
# Default: 2048 tokens
# Increase for complex conversations
export OLLAMA_NUM_CTX=4096
```

## Troubleshooting

### Ollama Not Starting

**Problem**: `ollama serve` fails
**Solution**:
```bash
# Check if port 11434 is in use
lsof -i :11434

# Kill existing process
pkill ollama

# Restart
ollama serve
```

### Model Not Found

**Problem**: "model not found" error
**Solution**:
```bash
# List available models
ollama list

# Pull the model
ollama pull llama3.2

# Verify
ollama list
```

### Slow Response Times

**Problem**: AI agent takes too long to respond
**Solution**:
1. Use a smaller model: `llama3.2:1b`
2. Enable GPU acceleration
3. Increase RAM allocation
4. Reduce context window

### Out of Memory

**Problem**: Ollama crashes with OOM error
**Solution**:
```bash
# Use smaller model
ollama pull llama3.2:1b

# Or increase system RAM
# Or use swap space (slower)
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Connection Refused

**Problem**: Can't connect to Ollama
**Solution**:
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama
ollama serve

# Check firewall
sudo ufw allow 11434
```

## Docker Deployment

### docker-compose.yml

```yaml
version: '3.8'

services:
  ollama:
    image: ollama/ollama
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped
    # Optional: GPU support
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]

  adr-orchestrator:
    build: .
    container_name: adr-orchestrator
    ports:
      - "9094:9094"
      - "9095:9095"
    environment:
      - ollamaServiceUrl=http://ollama:11434
      - ollamaModel=llama3.2
    depends_on:
      - ollama
      - mysql
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    container_name: adr-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: adr_db
      MYSQL_USER: adr_user
      MYSQL_PASSWORD: adr_password
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped

volumes:
  ollama_data:
  mysql_data:
```

### Pull Model in Docker

```bash
# Start services
docker-compose up -d

# Pull model inside container
docker exec -it ollama ollama pull llama3.2

# Verify
docker exec -it ollama ollama list
```

## Production Considerations

### 1. Model Persistence

Models are stored in:
- **Linux**: `/usr/share/ollama/.ollama/models`
- **macOS**: `~/.ollama/models`
- **Docker**: Volume mount `/root/.ollama`

Ensure this directory is backed up or mounted to persistent storage.

### 2. High Availability

For production, consider:
- Multiple Ollama instances behind a load balancer
- Model caching on fast storage (SSD/NVMe)
- Dedicated GPU servers for faster inference

### 3. Monitoring

Monitor these metrics:
- Response time (should be < 5 seconds)
- Memory usage (should not exceed 80%)
- CPU/GPU utilization
- Request queue depth

### 4. Security

- Run Ollama behind a firewall
- Use internal network for service communication
- Don't expose port 11434 to the internet
- Implement rate limiting on AI agent endpoint

## Comparison: Ollama vs OpenAI

| Feature | Ollama | OpenAI |
|---------|--------|--------|
| **Cost** | Free | $0.15-$5 per 1M tokens |
| **Privacy** | 100% local | Data sent to OpenAI |
| **Internet** | Not required | Required |
| **Speed** | Fast (local) | Variable (network) |
| **Quality** | Good | Excellent |
| **Setup** | Install + pull model | API key only |
| **Hardware** | 4-8GB RAM | None |
| **Scaling** | Add servers | Automatic |

## Recommended Setup by Environment

### Development
```toml
ollamaServiceUrl = "http://localhost:11434"
ollamaModel = "llama3.2:1b"  # Fast, lightweight
```

### Staging
```toml
ollamaServiceUrl = "http://localhost:11434"
ollamaModel = "llama3.2"  # Balanced
```

### Production
```toml
ollamaServiceUrl = "http://ollama-cluster:11434"
ollamaModel = "llama3.1:8b"  # High quality
```

### Enterprise
```toml
ollamaServiceUrl = "http://ollama-gpu-cluster:11434"
ollamaModel = "llama3.1:70b"  # Best quality
```

## Advanced Configuration

### Custom Model Parameters

Create a `Modelfile`:

```dockerfile
FROM llama3.2

# Set temperature (0.0 = deterministic, 1.0 = creative)
PARAMETER temperature 0.7

# Set context window
PARAMETER num_ctx 4096

# Set top-p sampling
PARAMETER top_p 0.9

# Custom system prompt
SYSTEM """
You are an expert airline operations assistant specializing in disruption recovery.
Be concise, accurate, and action-oriented.
"""
```

Create custom model:
```bash
ollama create adr-assistant -f Modelfile
```

Use in Config.toml:
```toml
ollamaModel = "adr-assistant"
```

## Summary

Ollama provides a **free, private, and powerful** alternative to cloud-based LLMs. For the ADR Orchestrator:

✅ **Zero cost** - No API fees  
✅ **Complete privacy** - Data never leaves your infrastructure  
✅ **Offline capable** - Works without internet  
✅ **Fast** - No network latency  
✅ **Flexible** - Choose model based on your needs  

**Quick Start:**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull model
ollama pull llama3.2

# Update Config.toml
echo 'ollamaServiceUrl = "http://localhost:11434"' >> Config.toml
echo 'ollamaModel = "llama3.2"' >> Config.toml

# Start services
bal run

# Test
curl -X POST http://localhost:9095/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "List all recovery plans"}'
```

You're now running a fully autonomous AI-powered disruption recovery system - completely free and private! 🚀
