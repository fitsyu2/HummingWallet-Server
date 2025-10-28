# Performance Monitoring Guide

## Railway Hobby Plan Limits

### Hard Limits:
- **Memory**: 512MB RAM
- **Storage**: 1GB disk
- **CPU**: Shared vCPU
- **Cost**: $5/month

### Soft Limits (monitored):
- **Network bandwidth**: No hard limit, but monitored
- **Request rate**: No hard limit
- **Concurrent connections**: Limited by memory

## Current Architecture Capacity

### Real-time Updates (JSON):
```
Payload size: ~100-500 bytes
Memory per session: ~100-500 bytes
Theoretical capacity: 100K+ concurrent sessions
Practical capacity: 10K-50K concurrent sessions
```

### Video Stream Forwarding:
```
Memory per stream: ~1KB (metadata only)
Bandwidth per stream: 500Kbps - 5Mbps
Concurrent streams: 10-100 (depends on quality)
```

## Monitoring Endpoints

Add these to your server for monitoring:

### Memory Usage:
```swift
router.get("/metrics/memory") { _, _ in
    let memory = ProcessInfo.processInfo.physicalMemory
    let used = // Calculate used memory
    return ["total": memory, "used": used, "available": memory - used]
}
```

### Active Sessions:
```swift
router.get("/metrics/sessions") { _, _ in
    return [
        "activeSessions": activeStreams.count,
        "totalViewers": activeStreams.values.reduce(0) { $0 + $1.viewers.count }
    ]
}
```

## Scaling Strategies

### When to Scale:
1. **Memory usage > 80%** (410MB)
2. **Response time > 1 second**
3. **Active sessions > 10,000**

### Scaling Options:
1. **Railway Pro**: $20/month, 8GB RAM
2. **Multiple instances**: Load balancer + session affinity
3. **Redis**: External session storage
4. **CloudFlare**: CDN for static content

## Performance Optimization

### Current Optimizations:
- ✅ In-memory sessions (fast)
- ✅ JSON responses (lightweight)
- ✅ No file I/O (no disk bottleneck)
- ✅ Swift (efficient memory usage)

### Future Optimizations:
- [ ] Connection pooling
- [ ] Response caching
- [ ] Gzip compression
- [ ] Session cleanup (TTL)

## Alert Thresholds

### Critical:
- Memory usage > 90%
- Response time > 5 seconds
- Active sessions > 50,000

### Warning:
- Memory usage > 75%
- Response time > 2 seconds
- Active sessions > 25,000

### Info:
- Memory usage > 50%
- Active sessions > 10,000

## Load Testing

### Basic Load Test:
```bash
# Test concurrent connections
ab -n 1000 -c 100 http://your-server.railway.app/health

# Test real-time endpoints
ab -n 1000 -c 50 -p data.json http://your-server.railway.app/api/v1/stream/test/start
```

### Expected Results (Hobby Plan):
- **Health endpoint**: 1000+ requests/second
- **Stream start**: 100+ requests/second
- **Live updates**: 500+ requests/second

## Capacity Planning

### Small Scale (1-100 rides):
- Memory usage: < 50MB
- Network: < 1Mbps
- Performance: Excellent

### Medium Scale (100-1,000 rides):
- Memory usage: 50-200MB
- Network: 1-10Mbps
- Performance: Good

### Large Scale (1,000-10,000 rides):
- Memory usage: 200-400MB
- Network: 10-100Mbps
- Performance: Acceptable (monitor closely)

### Very Large Scale (10,000+ rides):
- **Requires upgrade** to Railway Pro or multi-instance setup
- Consider external session storage (Redis)
- Implement load balancing

## Real-world Examples

### Uber/Lyft Scale Comparison:
- **Uber**: Millions of concurrent rides
- **Your app**: Likely 10-1,000 concurrent rides
- **Railway Hobby**: Perfect for small-medium scale

### Cost Comparison:
- **10 rides**: $5/month (Railway Hobby)
- **100 rides**: $5/month (Railway Hobby)
- **1,000 rides**: $5-20/month (Hobby to Pro)
- **10,000+ rides**: $20+/month (Multi-instance)