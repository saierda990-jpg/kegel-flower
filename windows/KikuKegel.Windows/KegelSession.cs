using System.Text.Json;

namespace KikuKegel.Windows;

internal enum ReminderMode
{
    Idle,
    Reminding,
    Exercising
}

internal enum KegelPhase
{
    Contract,
    Relax
}

internal sealed class KegelSession
{
    private const int ReminderIntervalMinutes = 45;
    private const int ContractSeconds = 5;
    private const int RelaxSeconds = 5;
    private const int CycleCount = 12;
    private readonly string _settingsPath = StoragePaths.File("kegel-session.json");
    private DateTime _nextExerciseTickAt = DateTime.MinValue;

    public event EventHandler? StateChanged;
    public event EventHandler? ReminderDue;
    public event EventHandler? ExerciseFinished;

    public ReminderMode Mode { get; private set; } = ReminderMode.Idle;
    public KegelPhase Phase { get; private set; } = KegelPhase.Contract;
    public int SecondsLeftInPhase { get; private set; } = ContractSeconds;
    public int CompletedCycles { get; private set; }
    public DateTime NextReminderAt { get; private set; }

    public int TotalCycles => CycleCount;
    public int TotalExerciseSeconds => CycleCount * (ContractSeconds + RelaxSeconds);

    public int RemainingExerciseSeconds
    {
        get
        {
            var cycleSeconds = ContractSeconds + RelaxSeconds;
            var remainingCurrentCycle = SecondsLeftInPhase + (Phase == KegelPhase.Contract ? RelaxSeconds : 0);
            var remainingFullCycles = Math.Max(0, CycleCount - CompletedCycles - 1) * cycleSeconds;
            return remainingCurrentCycle + remainingFullCycles;
        }
    }

    public string ShortStatusText
    {
        get
        {
            if (Mode != ReminderMode.Exercising)
            {
                return string.Empty;
            }

            return $"{(Phase == KegelPhase.Contract ? "收" : "放")} {SecondsLeftInPhase}s";
        }
    }

    public double ExerciseProgress
    {
        get
        {
            if (TotalExerciseSeconds <= 0)
            {
                return 0;
            }

            return Math.Clamp(1 - RemainingExerciseSeconds / (double)TotalExerciseSeconds, 0, 1);
        }
    }

    public void Start()
    {
        NextReminderAt = LoadNextReminderAt() ?? DateTime.Now.AddMinutes(ReminderIntervalMinutes);
        if (NextReminderAt <= DateTime.Now)
        {
            TriggerReminderNow();
        }
        else
        {
            NotifyChanged();
        }
    }

    public void Tick(DateTime now)
    {
        if (Mode == ReminderMode.Idle && now >= NextReminderAt)
        {
            TriggerReminderNow();
            return;
        }

        if (Mode != ReminderMode.Exercising || now < _nextExerciseTickAt)
        {
            return;
        }

        AdvanceExercise(now);
    }

    public void TriggerReminderNow()
    {
        Mode = ReminderMode.Reminding;
        ReminderDue?.Invoke(this, EventArgs.Empty);
        NotifyChanged();
    }

    public void StartExercise()
    {
        Mode = ReminderMode.Exercising;
        Phase = KegelPhase.Contract;
        SecondsLeftInPhase = ContractSeconds;
        CompletedCycles = 0;
        _nextExerciseTickAt = DateTime.Now.AddSeconds(1);
        ClearPersistedReminder();
        NotifyChanged();
    }

    public void Snooze(int minutes)
    {
        Mode = ReminderMode.Idle;
        ScheduleNextReminder(DateTime.Now.AddMinutes(minutes - ReminderIntervalMinutes));
        NotifyChanged();
    }

    private void AdvanceExercise(DateTime now)
    {
        _nextExerciseTickAt = now.AddSeconds(1);

        if (SecondsLeftInPhase > 1)
        {
            SecondsLeftInPhase -= 1;
            NotifyChanged();
            return;
        }

        if (Phase == KegelPhase.Contract)
        {
            Phase = KegelPhase.Relax;
            SecondsLeftInPhase = RelaxSeconds;
            NotifyChanged();
            return;
        }

        CompletedCycles += 1;
        if (CompletedCycles >= CycleCount)
        {
            StopAndReschedule();
            return;
        }

        Phase = KegelPhase.Contract;
        SecondsLeftInPhase = ContractSeconds;
        NotifyChanged();
    }

    private void StopAndReschedule()
    {
        Mode = ReminderMode.Idle;
        ScheduleNextReminder(DateTime.Now);
        ExerciseFinished?.Invoke(this, EventArgs.Empty);
        NotifyChanged();
    }

    private void ScheduleNextReminder(DateTime from)
    {
        NextReminderAt = from.AddMinutes(ReminderIntervalMinutes);
        PersistNextReminderAt();
    }

    private DateTime? LoadNextReminderAt()
    {
        try
        {
            if (!File.Exists(_settingsPath))
            {
                return null;
            }

            var state = JsonSerializer.Deserialize<SessionState>(File.ReadAllText(_settingsPath));
            return state?.NextReminderAt;
        }
        catch
        {
            return null;
        }
    }

    private void PersistNextReminderAt()
    {
        var state = new SessionState { NextReminderAt = NextReminderAt };
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(state));
    }

    private void ClearPersistedReminder()
    {
        if (File.Exists(_settingsPath))
        {
            File.Delete(_settingsPath);
        }
    }

    private void NotifyChanged() => StateChanged?.Invoke(this, EventArgs.Empty);

    private sealed class SessionState
    {
        public DateTime NextReminderAt { get; set; }
    }
}
