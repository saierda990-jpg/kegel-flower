using System.Text.Json;

namespace KikuKegel.Windows;

internal sealed class DailyCheckInSummary
{
    public required bool[] CompletedSlots { get; init; }
    public required int TodayCount { get; init; }
    public required int YesterdayCount { get; init; }
    public int TotalCount => CompletedSlots.Length;

    public string ComparisonText
    {
        get
        {
            var delta = (int)Math.Round((TodayCount - YesterdayCount) / (double)TotalCount * 100);
            if (delta > 0)
            {
                return $"比昨天 +{delta}%，真棒";
            }

            if (delta < 0)
            {
                return $"比昨天 {delta}%，再接再厉";
            }

            return "和昨天持平，继续保持";
        }
    }
}

internal sealed class DailyCheckInStore
{
    public const int SlotCount = 15;
    private readonly string _storagePath = StoragePaths.File("daily-check-in.json");
    private Dictionary<string, HashSet<int>> _records;

    public DailyCheckInStore()
    {
        _records = Load();
    }

    public bool MarkCompletion(DateTime? date = null, int? preferredSlotIndex = null)
    {
        var now = date ?? DateTime.Now;
        var key = DateKey(now);
        var slotIndex = preferredSlotIndex.HasValue
            ? Math.Clamp(preferredSlotIndex.Value, 0, SlotCount - 1)
            : NearestSlotIndex(now);

        if (!_records.TryGetValue(key, out var slots))
        {
            slots = new HashSet<int>();
            _records[key] = slots;
        }

        if (!slots.Add(slotIndex))
        {
            return false;
        }

        Save();
        return true;
    }

    public int NearestSlotIndex(DateTime? date = null)
    {
        var now = date ?? DateTime.Now;
        var firstSlot = now.Date.AddHours(9);
        var lastSlot = firstSlot.AddMinutes((SlotCount - 1) * 45);

        if (now <= firstSlot)
        {
            return 0;
        }

        if (now >= lastSlot)
        {
            return SlotCount - 1;
        }

        var minutes = Math.Abs((now - firstSlot).TotalMinutes);
        return Math.Clamp((int)Math.Round(minutes / 45), 0, SlotCount - 1);
    }

    public DailyCheckInSummary Summary(DateTime? date = null)
    {
        var now = date ?? DateTime.Now;
        var todayKey = DateKey(now);
        var yesterdayKey = DateKey(now.AddDays(-1));
        var todaySlots = _records.TryGetValue(todayKey, out var today) ? today : new HashSet<int>();
        var yesterdaySlots = _records.TryGetValue(yesterdayKey, out var yesterday) ? yesterday : new HashSet<int>();

        return new DailyCheckInSummary
        {
            CompletedSlots = Enumerable.Range(0, SlotCount).Select(todaySlots.Contains).ToArray(),
            TodayCount = todaySlots.Count,
            YesterdayCount = yesterdaySlots.Count
        };
    }

    private Dictionary<string, HashSet<int>> Load()
    {
        try
        {
            if (!File.Exists(_storagePath))
            {
                return new Dictionary<string, HashSet<int>>();
            }

            var decoded = JsonSerializer.Deserialize<Dictionary<string, int[]>>(File.ReadAllText(_storagePath));
            return decoded?.ToDictionary(
                pair => pair.Key,
                pair => pair.Value.Where(index => index >= 0 && index < SlotCount).ToHashSet()
            ) ?? new Dictionary<string, HashSet<int>>();
        }
        catch
        {
            return new Dictionary<string, HashSet<int>>();
        }
    }

    private void Save()
    {
        var encoded = _records.ToDictionary(pair => pair.Key, pair => pair.Value.OrderBy(index => index).ToArray());
        File.WriteAllText(_storagePath, JsonSerializer.Serialize(encoded));
    }

    private static string DateKey(DateTime date) => date.ToString("yyyy-MM-dd");
}
