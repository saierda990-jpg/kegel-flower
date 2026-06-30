namespace KikuKegel.Windows;

internal sealed class MainPanelForm : Form
{
    private readonly KegelSession _session;
    private readonly Func<PetStatusSnapshot> _petStatus;
    private readonly Action _startNow;
    private readonly Action _snooze;
    private readonly Action _feed;
    private readonly Action _drink;
    private readonly Action _rest;

    private readonly Panel _content = new();
    private readonly PillTabButton _kegelTab = new() { Text = "提肛" };
    private readonly PillTabButton _statusTab = new() { Text = "状态" };
    private PanelTab _selectedTab = PanelTab.Kegel;

    public MainPanelForm(
        KegelSession session,
        Func<PetStatusSnapshot> petStatus,
        Action startNow,
        Action snooze,
        Action feed,
        Action drink,
        Action rest)
    {
        _session = session;
        _petStatus = petStatus;
        _startNow = startNow;
        _snooze = snooze;
        _feed = feed;
        _drink = drink;
        _rest = rest;

        Width = 330;
        Height = 358;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        Text = "提肛小花";
        BackColor = Color.FromArgb(31, 34, 42);
        ForeColor = Color.White;
        Font = new Font("Microsoft YaHei UI", 9f);

        BuildShell();
        UpdateView();
    }

    public void ShowNearTray()
    {
        var area = Screen.PrimaryScreen?.WorkingArea ?? Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(area.Right - Width - 18, area.Bottom - Height - 18);
        Show();
        Activate();
        UpdateView();
    }

    public void UpdateView()
    {
        _kegelTab.Selected = _selectedTab == PanelTab.Kegel;
        _statusTab.Selected = _selectedTab == PanelTab.Status;
        _kegelTab.ShowDot = _session.Mode == ReminderMode.Reminding;
        _statusTab.ShowDot = ShouldShowStatusDot(_petStatus());

        _content.SuspendLayout();
        foreach (Control control in _content.Controls.Cast<Control>().ToArray())
        {
            control.Dispose();
        }
        _content.Controls.Clear();
        if (_selectedTab == PanelTab.Kegel)
        {
            BuildKegelPage();
        }
        else
        {
            BuildStatusPage();
        }
        _content.ResumeLayout();
    }

    private void BuildShell()
    {
        var tabBackground = new Panel
        {
            Left = 18,
            Top = 18,
            Width = 276,
            Height = 36,
            BackColor = Color.FromArgb(36, 255, 255, 255)
        };
        Controls.Add(tabBackground);

        _kegelTab.SetBounds(4, 4, 132, 28);
        _statusTab.SetBounds(140, 4, 132, 28);
        _kegelTab.Click += (_, _) => SelectTab(PanelTab.Kegel);
        _statusTab.Click += (_, _) => SelectTab(PanelTab.Status);
        tabBackground.Controls.Add(_kegelTab);
        tabBackground.Controls.Add(_statusTab);

        _content.SetBounds(18, 66, 276, 250);
        _content.BackColor = Color.Transparent;
        Controls.Add(_content);
    }

    private void SelectTab(PanelTab tab)
    {
        _selectedTab = tab;
        UpdateView();
    }

    private void BuildKegelPage()
    {
        using var icon = FlowerIconRenderer.CreateIcon(expression: FlowerExpression.Normal);
        var iconBox = new PictureBox
        {
            Image = icon.ToBitmap(),
            SizeMode = PictureBoxSizeMode.StretchImage,
            Left = 0,
            Top = 8,
            Width = 76,
            Height = 76
        };
        _content.Controls.Add(iconBox);

        var title = new Label
        {
            Text = KegelTitle(),
            Left = 94,
            Top = 8,
            Width = 172,
            Height = 32,
            Font = new Font("Microsoft YaHei UI", 18f, FontStyle.Bold),
            ForeColor = Color.White
        };
        _content.Controls.Add(title);

        var subtitle = new Label
        {
            Text = KegelSubtitle(),
            Left = 96,
            Top = 44,
            Width = 176,
            Height = 52,
            Font = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold),
            ForeColor = Color.FromArgb(180, 214, 218, 228)
        };
        _content.Controls.Add(subtitle);

        if (_session.Mode == ReminderMode.Exercising)
        {
            var bar = new GradientBar
            {
                Left = 0,
                Top = 118,
                Width = 276,
                Value = _session.ExerciseProgress,
                Colors = new[] { Color.FromArgb(170, 235, 190), Color.FromArgb(55, 195, 102), Color.FromArgb(16, 138, 58) }
            };
            _content.Controls.Add(bar);

            var cycle = new Label
            {
                Text = $"第 {Math.Min(_session.CompletedCycles + 1, _session.TotalCycles)} / {_session.TotalCycles} 组",
                Left = 0,
                Top = 142,
                Width = 140,
                Height = 24,
                ForeColor = Color.FromArgb(170, 214, 218, 228),
                Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Bold)
            };
            _content.Controls.Add(cycle);

            var seconds = new Label
            {
                Text = FormatSeconds(_session.RemainingExerciseSeconds),
                Left = 200,
                Top = 142,
                Width = 76,
                Height = 24,
                TextAlign = ContentAlignment.TopRight,
                ForeColor = Color.FromArgb(170, 214, 218, 228),
                Font = new Font("Consolas", 10f, FontStyle.Bold)
            };
            _content.Controls.Add(seconds);
        }
        else
        {
            var minutes = Math.Max(1, (int)Math.Ceiling((_session.NextReminderAt - DateTime.Now).TotalMinutes));
            var next = new Label
            {
                Text = $"大约 {minutes} 分钟后提醒。",
                Left = 0,
                Top = 118,
                Width = 276,
                Height = 24,
                ForeColor = Color.FromArgb(170, 214, 218, 228),
                Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Bold)
            };
            _content.Controls.Add(next);
        }

        var start = MakeButton(_session.Mode == ReminderMode.Exercising ? "重新开始" : "开始", true);
        start.SetBounds(0, 190, 84, 36);
        start.Click += (_, _) => _startNow();
        _content.Controls.Add(start);

        var snooze = MakeButton("稍后", false);
        snooze.SetBounds(96, 190, 84, 36);
        snooze.Click += (_, _) =>
        {
            _snooze();
            Hide();
        };
        _content.Controls.Add(snooze);
    }

    private void BuildStatusPage()
    {
        var snapshot = _petStatus();
        using var icon = FlowerIconRenderer.CreateIcon(expression: FlowerExpression.Normal);
        var iconBox = new PictureBox
        {
            Image = icon.ToBitmap(),
            SizeMode = PictureBoxSizeMode.StretchImage,
            Left = 0,
            Top = 0,
            Width = 58,
            Height = 58
        };
        _content.Controls.Add(iconBox);

        var title = new Label
        {
            Text = $"Lv.{snapshot.Level} 小花",
            Left = 74,
            Top = 0,
            Width = 160,
            Height = 26,
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 15f, FontStyle.Bold)
        };
        _content.Controls.Add(title);

        var mood = new Label
        {
            Text = $"{snapshot.MoodText}  ·  经验 {snapshot.Experience}",
            Left = 76,
            Top = 30,
            Width = 190,
            Height = 22,
            ForeColor = Color.FromArgb(172, 214, 218, 228),
            Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Bold)
        };
        _content.Controls.Add(mood);

        AddStatusRow("饱腹", snapshot.Fullness, 76, new[] { Color.FromArgb(255, 184, 194), Color.FromArgb(250, 72, 92), Color.FromArgb(190, 30, 54) }, "喂一下", _feed);
        AddStatusRow("水分", snapshot.Hydration, 112, new[] { Color.FromArgb(174, 219, 255), Color.FromArgb(58, 140, 255), Color.FromArgb(12, 72, 210) }, "喝一下", _drink);
        AddStatusRow("精神", snapshot.Energy, 148, new[] { Color.FromArgb(210, 190, 255), Color.FromArgb(136, 92, 232), Color.FromArgb(88, 46, 180) }, "休息", _rest);
        AddStatusRow("运动", snapshot.Exercise, 184, new[] { Color.FromArgb(166, 242, 190), Color.FromArgb(62, 190, 96), Color.FromArgb(20, 130, 56) }, _session.Mode == ReminderMode.Exercising ? "进行中" : "开始", _startNow, _session.Mode == ReminderMode.Exercising);

        var version = new Label
        {
            Text = "版本 0.2.0",
            Left = 182,
            Top = 226,
            Width = 94,
            Height = 18,
            TextAlign = ContentAlignment.TopRight,
            ForeColor = Color.FromArgb(105, 214, 218, 228),
            Font = new Font("Microsoft YaHei UI", 7.5f, FontStyle.Bold)
        };
        _content.Controls.Add(version);
    }

    private void AddStatusRow(string title, double value, int y, Color[] colors, string buttonText, Action action, bool disabled = false)
    {
        var label = new Label
        {
            Text = title,
            Left = 0,
            Top = y - 4,
            Width = 36,
            Height = 24,
            ForeColor = Color.FromArgb(170, 214, 218, 228),
            Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Bold)
        };
        _content.Controls.Add(label);

        var bar = new GradientBar
        {
            Left = 42,
            Top = y + 4,
            Width = 104,
            Value = value,
            Colors = colors
        };
        _content.Controls.Add(bar);

        var percent = new Label
        {
            Text = $"{Math.Round(value * 100):0}%",
            Left = 150,
            Top = y - 3,
            Width = 38,
            Height = 20,
            TextAlign = ContentAlignment.TopRight,
            ForeColor = Color.FromArgb(128, 214, 218, 228),
            Font = new Font("Consolas", 8.5f, FontStyle.Bold)
        };
        _content.Controls.Add(percent);

        var button = MakeButton(buttonText, false);
        button.SetBounds(198, y - 8, 76, 28);
        button.Enabled = !disabled;
        button.Click += (_, _) =>
        {
            action();
            UpdateView();
        };
        _content.Controls.Add(button);
    }

    private static Button MakeButton(string text, bool primary)
    {
        return new Button
        {
            Text = text,
            FlatStyle = FlatStyle.Flat,
            BackColor = primary ? Color.FromArgb(0, 122, 255) : Color.FromArgb(56, 62, 74),
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold),
            Cursor = Cursors.Hand
        };
    }

    private string KegelTitle()
    {
        return _session.Mode switch
        {
            ReminderMode.Reminding => "到时间了",
            ReminderMode.Exercising => _session.Phase == KegelPhase.Contract ? "收缩" : "放松",
            _ => "下一次提肛"
        };
    }

    private string KegelSubtitle()
    {
        return _session.Mode switch
        {
            ReminderMode.Reminding => "点击开始后，跟着节奏收缩和放松。",
            ReminderMode.Exercising => _session.Phase == KegelPhase.Contract ? "轻柔收紧，保持呼吸。" : "完全放松，准备下一次。",
            _ => "默认每 45 分钟提醒一次。"
        };
    }

    private static string FormatSeconds(int seconds)
    {
        return $"{seconds / 60}:{seconds % 60:00}";
    }

    private static bool ShouldShowStatusDot(PetStatusSnapshot snapshot)
    {
        return snapshot.Fullness < 0.34
            || snapshot.Hydration < 0.34
            || snapshot.Energy < 0.34
            || snapshot.Exercise < 0.12;
    }

    private enum PanelTab
    {
        Kegel,
        Status
    }
}
