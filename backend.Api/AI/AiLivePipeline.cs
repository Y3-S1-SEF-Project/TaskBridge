using System;
using System.Collections.Generic;
using System.Linq;

namespace backend.Api.AI;

public sealed class AiPipelineLogItem
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public int Step { get; set; }
    public string Agent { get; set; } = string.Empty; // "planning" | "matching" | "coordination" | "review"
    public string Message { get; set; } = string.Empty;
    public bool IsHighlight { get; set; }
    public int LatencyMs { get; set; }
    public int Tokens { get; set; }
    public string Timestamp { get; set; } = string.Empty;
}

public static class AiLivePipeline
{
    private static readonly List<AiPipelineLogItem> _logs = new();
    private static readonly object _lock = new();

    public static int CurrentActiveStep { get; private set; } = 0;
    public static DateTimeOffset LastActivityAt { get; private set; } = DateTimeOffset.MinValue;

    public static void RecordEvent(
        int step,
        string agent,
        string message,
        bool isHighlight = false,
        int latencyMs = 0,
        int tokens = 0)
    {
        lock (_lock)
        {
            CurrentActiveStep = step;
            LastActivityAt = DateTimeOffset.UtcNow;

            _logs.Add(new AiPipelineLogItem
            {
                Id = Guid.NewGuid().ToString(),
                Step = step,
                Agent = agent.ToLowerInvariant(),
                Message = message,
                IsHighlight = isHighlight,
                LatencyMs = latencyMs,
                Tokens = tokens,
                Timestamp = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
            });

            if (_logs.Count > 200)
            {
                _logs.RemoveRange(0, _logs.Count - 200);
            }
        }
    }

    public static (int currentStep, List<AiPipelineLogItem> logs) GetState()
    {
        lock (_lock)
        {
            // If inactive for > 5 mins, show completed or idle
            var isRecent = (DateTimeOffset.UtcNow - LastActivityAt).TotalMinutes < 5;
            var step = isRecent ? CurrentActiveStep : (CurrentActiveStep > 0 ? CurrentActiveStep : 0);
            return (step, _logs.ToList());
        }
    }

    public static void Clear()
    {
        lock (_lock)
        {
            _logs.Clear();
            CurrentActiveStep = 0;
            LastActivityAt = DateTimeOffset.MinValue;
        }
    }
}
