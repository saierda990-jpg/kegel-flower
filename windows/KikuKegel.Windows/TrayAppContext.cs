namespace KikuKegel.Windows;

internal sealed class TrayAppContext : ApplicationContext
{
    private readonly NotifyIcon _notifyIcon = new();
    private readonly KegelSession _session = new();
    private readonly DailyCheckInStore _checkInStore = new();
    private readonly PetStatusStore _petStatusStore = new();
    private readonly ReminderPopupForm _popup = new();
    private readonly System.Windows.Forms.Timer _timer = new();
    private readonly System.Windows.Forms.Timer _startupTimer = new();

    private MainPanelForm? _panel;
    private ContextMenuStrip? _contextMenu;
    private Icon? _currentIcon;
    private DateTime _nextBlinkAt = DateTime.Now.AddSeconds(2);
    private DateTime? _blinkStartedAt;
    private DateTime? _eatUntil;
    private DateTime? _sleepUntil;
    private DateTime? _reminderWiggleStartedAt;
    private int? _pendingCheckInSlotIndex;

    public TrayAppContext()
    {
        _notifyIcon.Text = "提肛小花";
        _notifyIcon.Visible = true;
        _notifyIcon.MouseClick += HandleTrayClick;

        _session.ReminderDue += (_, _) => ShowReminderPopup();
        _session.ExerciseFinished += (_, _) =>
        {
            _popup.Hide();
            _panel?.Hide();
        };
        _session.StateChanged += (_, _) => RefreshUi();

        _timer.Interval = 120;
        _timer.Tick += (_, _) => Tick();
        _timer.Start();

        _session.Start();
        RefreshIcon();

        _startupTimer.Interval = 800;
        _startupTimer.Tick += (_, _) =>
        {
            _startupTimer.Stop();
            ShowStartupPopup();
        };
        _startupTimer.Start();
    }

    private void Tick()
    {
        var now = DateTime.Now;
        _session.Tick(now);

        if (now >= _nextBlinkAt)
        {
            _blinkStartedAt = now;
            _nextBlinkAt = now.AddSeconds(Random.Shared.NextDouble() * 3.4 + 2.4);
        }

        if (_blinkStartedAt.HasValue && (now - _blinkStartedAt.Value).TotalMilliseconds > 220)
        {
            _blinkStartedAt = null;
        }

        if (_eatUntil.HasValue && now >= _eatUntil.Value)
        {
            _eatUntil = null;
        }

        if (_sleepUntil.HasValue && now >= _sleepUntil.Value)
        {
            _sleepUntil = null;
        }

        RefreshIcon();
        _panel?.UpdateView();
    }

    private void HandleTrayClick(object? sender, MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Right)
        {
            ShowContextMenu();
            return;
        }

        if (e.Button != MouseButtons.Left)
        {
            return;
        }

        if (_panel is { Visible: true })
        {
            _panel.Hide();
            return;
        }

        EnsurePanel();
        _popup.Hide();
        _panel?.ShowNearTray();
    }

    private void EnsurePanel()
    {
        if (_panel != null && !_panel.IsDisposed)
        {
            return;
        }

        _panel = new MainPanelForm(
            _session,
            () => _petStatusStore.Snapshot(_checkInStore.Summary().TodayCount),
            BeginExerciseFromUser,
            SnoozeTenMinutes,
            FeedPet,
            DrinkPet,
            RestPet
        );
    }

    private void BeginExerciseFromUser()
    {
        _popup.Hide();
        _reminderWiggleStartedAt = null;
        _sleepUntil = null;
        if (_checkInStore.MarkCompletion(preferredSlotIndex: _pendingCheckInSlotIndex))
        {
            _petStatusStore.RecordExercise();
        }

        _pendingCheckInSlotIndex = null;
        _session.StartExercise();
        RefreshUi();
    }

    private void SnoozeTenMinutes()
    {
        _popup.Hide();
        _reminderWiggleStartedAt = null;
        _session.Snooze(10);
        RefreshUi();
    }

    private void FeedPet()
    {
        _petStatusStore.RecordFeed();
        TriggerEatAnimation();
        RefreshUi();
    }

    private void DrinkPet()
    {
        _petStatusStore.RecordDrink();
        TriggerEatAnimation();
        RefreshUi();
    }

    private void RestPet()
    {
        if (_session.Mode == ReminderMode.Exercising)
        {
            return;
        }

        _petStatusStore.RecordRest();
        _sleepUntil = DateTime.Now.AddSeconds(10);
        RefreshUi();
    }

    private void TriggerEatAnimation()
    {
        _sleepUntil = null;
        _eatUntil = DateTime.Now.AddMilliseconds(1450);
        _blinkStartedAt = DateTime.Now;
    }

    private void ShowStartupPopup()
    {
        _popup.ShowMessage(
            "提肛小花已启动",
            "要不要现在来一次？",
            "立即运行一次",
            BeginExerciseFromUser,
            "稍后",
            () => _popup.Hide(),
            8000
        );
    }

    private void ShowReminderPopup()
    {
        _pendingCheckInSlotIndex = _checkInStore.NearestSlotIndex();
        _reminderWiggleStartedAt = DateTime.Now;
        var message = CurrentReminderMessage();
        _popup.ShowMessage(
            message.Title,
            message.Subtitle,
            "立即开始",
            BeginExerciseFromUser,
            "稍后",
            SnoozeTenMinutes,
            10000
        );
        RefreshUi();
    }

    private (string Title, string Subtitle) CurrentReminderMessage()
    {
        var summary = _checkInStore.Summary();
        var hour = DateTime.Now.Hour;
        if (summary.YesterdayCount > 0
            && summary.TodayCount == summary.YesterdayCount
            && summary.TodayCount < summary.TotalCount
            && hour < 20)
        {
            return ("再来一次就超过昨天", "现在完成一次，今天就比昨天更棒。");
        }

        return ("时间到", "现在开始还是稍后？");
    }

    private void ShowContextMenu()
    {
        _contextMenu?.Dispose();
        _contextMenu = BuildContextMenu();
        _contextMenu.Show(Cursor.Position);
    }

    private ContextMenuStrip BuildContextMenu()
    {
        var menu = new ContextMenuStrip
        {
            BackColor = Color.FromArgb(38, 40, 46),
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold)
        };

        var summary = _checkInStore.Summary();
        menu.Items.Add(DisabledItem($"今日打卡 {summary.TodayCount}/{summary.TotalCount}"));
        menu.Items.Add(DisabledItem(DotsText(summary.CompletedSlots)));
        menu.Items.Add(DisabledItem(summary.ComparisonText));
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(MenuItem("现在开始一次", (_, _) => BeginExerciseFromUser()));
        menu.Items.Add(MenuItem("稍后 10 分钟提醒", (_, _) => SnoozeTenMinutes()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(DisabledItem("版本 0.2.0"));
        menu.Items.Add(MenuItem("退出", (_, _) => ExitThread()));
        return menu;
    }

    private static ToolStripMenuItem MenuItem(string text, EventHandler handler)
    {
        var item = new ToolStripMenuItem(text);
        item.Click += handler;
        return item;
    }

    private static ToolStripMenuItem DisabledItem(string text)
    {
        return new ToolStripMenuItem(text) { Enabled = false };
    }

    private static string DotsText(bool[] completed)
    {
        return string.Join(" ", completed.Select(done => done ? "🟢" : "⚫"));
    }

    private void RefreshUi()
    {
        _panel?.UpdateView();
        RefreshIcon();
    }

    private void RefreshIcon()
    {
        var now = DateTime.Now;
        var blink = 0f;
        if (_blinkStartedAt.HasValue)
        {
            var progress = Math.Clamp((float)(now - _blinkStartedAt.Value).TotalMilliseconds / 220f, 0, 1);
            blink = MathF.Sin(progress * MathF.PI);
        }

        var scale = 1f;
        var tilt = 0f;
        var expression = FlowerExpression.Normal;
        if (_session.Mode == ReminderMode.Reminding && _reminderWiggleStartedAt.HasValue)
        {
            var elapsed = (float)(now - _reminderWiggleStartedAt.Value).TotalSeconds;
            tilt = MathF.Sin(elapsed * 2.8f * MathF.PI) * 15f;
        }

        if (_session.Mode == ReminderMode.Exercising)
        {
            expression = _session.Phase == KegelPhase.Contract ? FlowerExpression.Contract : FlowerExpression.Relax;
            scale = _session.Phase == KegelPhase.Contract ? 0.70f : 1.0f;
        }
        else if (_eatUntil.HasValue)
        {
            expression = FlowerExpression.Eating;
            var progress = 1f - Math.Clamp((float)(_eatUntil.Value - now).TotalMilliseconds / 1450f, 0, 1);
            scale = 1 + 0.16f * MathF.Abs(MathF.Sin(progress * MathF.PI * 6)) * MathF.Sin(progress * MathF.PI);
        }
        else if (_sleepUntil.HasValue)
        {
            expression = FlowerExpression.Sleeping;
        }

        var icon = FlowerIconRenderer.CreateIcon(scale, tilt, expression, blink);
        var oldIcon = _currentIcon;
        _currentIcon = icon;
        _notifyIcon.Icon = icon;
        _notifyIcon.Text = string.IsNullOrWhiteSpace(_session.ShortStatusText)
            ? "提肛小花"
            : $"提肛小花 · {_session.ShortStatusText}";
        oldIcon?.Dispose();
    }

    protected override void ExitThreadCore()
    {
        _timer.Stop();
        _startupTimer.Stop();
        _startupTimer.Dispose();
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _currentIcon?.Dispose();
        _contextMenu?.Dispose();
        _panel?.Dispose();
        _popup.Dispose();
        base.ExitThreadCore();
    }
}
