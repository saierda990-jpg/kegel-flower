using System.Text.Json;

namespace KikuKegel.Windows;

internal sealed class PetStatusSnapshot
{
    public required double Fullness { get; init; }
    public required double Hydration { get; init; }
    public required double Energy { get; init; }
    public required double Exercise { get; init; }
    public required int Level { get; init; }
    public required int Experience { get; init; }
    public required string MoodText { get; init; }
}

internal sealed class PetStatusStore
{
    private readonly string _storagePath = StoragePaths.File("pet-status.json");
    private State _state;

    public PetStatusStore()
    {
        _state = Load();
        MigrateLegacyCareValues(DateTime.Now);
    }

    public void RecordExercise()
    {
        UpdateWellnessTracking(DateTime.Now);
        _state.ExerciseCount += 1;
        Save();
    }

    public void RecordFeed()
    {
        var now = DateTime.Now;
        UpdateWellnessTracking(now);
        _state.FullnessValue = ReplenishedValue(Fullness(now), 0.16, _state.LastFeedActionAt, now);
        _state.FullnessUpdatedAt = now;
        _state.LastFeedActionAt = now;
        _state.LastFedAt = now;
        _state.FeedCount += 1;
        UpdateWellnessTracking(now);
        Save();
    }

    public void RecordDrink()
    {
        var now = DateTime.Now;
        UpdateWellnessTracking(now);
        _state.HydrationValue = ReplenishedValue(Hydration(now), 0.18, _state.LastDrinkActionAt, now);
        _state.HydrationUpdatedAt = now;
        _state.LastDrinkActionAt = now;
        _state.LastDrinkAt = now;
        _state.DrinkCount += 1;
        UpdateWellnessTracking(now);
        Save();
    }

    public void RecordRest()
    {
        var now = DateTime.Now;
        UpdateWellnessTracking(now);
        _state.EnergyValue = ReplenishedValue(Energy(now), 0.20, _state.LastRestActionAt, now);
        _state.EnergyUpdatedAt = now;
        _state.LastRestActionAt = now;
        _state.LastRestedAt = now;
        _state.RestCount += 1;
        UpdateWellnessTracking(now);
        Save();
    }

    public PetStatusSnapshot Snapshot(int todayExerciseCount)
    {
        var now = DateTime.Now;
        var fullness = Fullness(now);
        var hydration = Hydration(now);
        var energy = Energy(now);
        var exercise = Math.Clamp(todayExerciseCount / (double)DailyCheckInStore.SlotCount, 0, 1);
        var xp = _state.ExerciseCount * 18
            + _state.FeedCount * 3
            + _state.DrinkCount * 3
            + _state.RestCount * 2
            + (int)(EffectiveWellnessSeconds(now).TotalMinutes / 10) * 2;
        var average = (fullness + hydration + energy + exercise) / 4;

        return new PetStatusSnapshot
        {
            Fullness = fullness,
            Hydration = hydration,
            Energy = energy,
            Exercise = exercise,
            Experience = xp,
            Level = Math.Clamp(xp / 60 + 1, 1, 99),
            MoodText = MoodText(average)
        };
    }

    private void UpdateWellnessTracking(DateTime now)
    {
        if (IsFullWellness(now))
        {
            _state.WellnessStartedAt ??= now;
            return;
        }

        if (_state.WellnessStartedAt.HasValue)
        {
            _state.AccumulatedWellnessSeconds += Math.Max(0, (now - _state.WellnessStartedAt.Value).TotalSeconds);
            _state.WellnessStartedAt = null;
        }
    }

    private TimeSpan EffectiveWellnessSeconds(DateTime now)
    {
        if (_state.WellnessStartedAt.HasValue && IsFullWellness(now))
        {
            return TimeSpan.FromSeconds(
                _state.AccumulatedWellnessSeconds + Math.Max(0, (now - _state.WellnessStartedAt.Value).TotalSeconds)
            );
        }

        return TimeSpan.FromSeconds(_state.AccumulatedWellnessSeconds);
    }

    private bool IsFullWellness(DateTime now)
    {
        return Fullness(now, 0) >= 0.95
            && Hydration(now, 0) >= 0.95
            && Energy(now, 0) >= 0.95;
    }

    private void MigrateLegacyCareValues(DateTime now)
    {
        if (!_state.FullnessValue.HasValue && _state.LastFedAt.HasValue)
        {
            _state.FullnessValue = Math.Min(ValueSince(_state.LastFedAt, TimeSpan.FromHours(6), 0.58, now), 0.82);
            _state.FullnessUpdatedAt = now;
        }

        if (!_state.HydrationValue.HasValue && _state.LastDrinkAt.HasValue)
        {
            _state.HydrationValue = Math.Min(ValueSince(_state.LastDrinkAt, TimeSpan.FromHours(3), 0.52, now), 0.82);
            _state.HydrationUpdatedAt = now;
        }

        if (!_state.EnergyValue.HasValue && _state.LastRestedAt.HasValue)
        {
            _state.EnergyValue = Math.Min(ValueSince(_state.LastRestedAt, TimeSpan.FromHours(8), 0.68, now), 0.86);
            _state.EnergyUpdatedAt = now;
        }
    }

    private double Fullness(DateTime now, double nilValue = 0.58)
    {
        return CareValue(_state.FullnessValue, _state.FullnessUpdatedAt, _state.LastFedAt, TimeSpan.FromHours(6), nilValue, now);
    }

    private double Hydration(DateTime now, double nilValue = 0.52)
    {
        return CareValue(_state.HydrationValue, _state.HydrationUpdatedAt, _state.LastDrinkAt, TimeSpan.FromHours(3), nilValue, now);
    }

    private double Energy(DateTime now, double nilValue = 0.68)
    {
        return CareValue(_state.EnergyValue, _state.EnergyUpdatedAt, _state.LastRestedAt, TimeSpan.FromHours(8), nilValue, now);
    }

    private static double CareValue(
        double? storedValue,
        DateTime? updatedAt,
        DateTime? legacyDate,
        TimeSpan maxAge,
        double nilValue,
        DateTime now)
    {
        if (!storedValue.HasValue)
        {
            return ValueSince(legacyDate, maxAge, nilValue, now);
        }

        var elapsed = Math.Max(0, (now - (updatedAt ?? now)).TotalSeconds);
        return Math.Clamp(storedValue.Value - elapsed / maxAge.TotalSeconds, 0, 1);
    }

    private static double ReplenishedValue(double current, double baseIncrement, DateTime? lastActionAt, DateTime now)
    {
        return Math.Min(1, current + PacedIncrement(baseIncrement, lastActionAt, now));
    }

    private static double PacedIncrement(double baseIncrement, DateTime? lastActionAt, DateTime now)
    {
        if (!lastActionAt.HasValue)
        {
            return baseIncrement;
        }

        var elapsed = Math.Max(0, (now - lastActionAt.Value).TotalSeconds);
        if (elapsed < 6) return baseIncrement * 0.20;
        if (elapsed < 18) return baseIncrement * 0.45;
        if (elapsed < 45) return baseIncrement * 0.75;
        return baseIncrement;
    }

    private static double ValueSince(DateTime? date, TimeSpan maxAge, double nilValue, DateTime now)
    {
        if (!date.HasValue)
        {
            return nilValue;
        }

        var age = Math.Max(0, (now - date.Value).TotalSeconds);
        return Math.Clamp(1 - age / maxAge.TotalSeconds, 0, 1);
    }

    private static string MoodText(double average)
    {
        if (average >= 0.82) return "状态很好";
        if (average >= 0.58) return "还不错";
        if (average >= 0.34) return "需要照顾一下";
        return "有点蔫了";
    }

    private State Load()
    {
        try
        {
            if (!File.Exists(_storagePath))
            {
                return new State();
            }

            return JsonSerializer.Deserialize<State>(File.ReadAllText(_storagePath)) ?? new State();
        }
        catch
        {
            return new State();
        }
    }

    private void Save()
    {
        File.WriteAllText(_storagePath, JsonSerializer.Serialize(_state));
    }

    private sealed class State
    {
        public DateTime? LastFedAt { get; set; }
        public DateTime? LastDrinkAt { get; set; }
        public DateTime? LastRestedAt { get; set; }
        public double? FullnessValue { get; set; }
        public DateTime? FullnessUpdatedAt { get; set; }
        public double? HydrationValue { get; set; }
        public DateTime? HydrationUpdatedAt { get; set; }
        public double? EnergyValue { get; set; }
        public DateTime? EnergyUpdatedAt { get; set; }
        public DateTime? LastFeedActionAt { get; set; }
        public DateTime? LastDrinkActionAt { get; set; }
        public DateTime? LastRestActionAt { get; set; }
        public int ExerciseCount { get; set; }
        public int FeedCount { get; set; }
        public int DrinkCount { get; set; }
        public int RestCount { get; set; }
        public double AccumulatedWellnessSeconds { get; set; }
        public DateTime? WellnessStartedAt { get; set; }
    }
}
