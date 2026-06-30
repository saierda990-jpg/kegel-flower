namespace KikuKegel.Windows;

internal sealed class ReminderPopupForm : Form
{
    private readonly System.Windows.Forms.Timer _dismissTimer = new();

    public ReminderPopupForm()
    {
        Width = 260;
        Height = 118;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        MaximizeBox = false;
        MinimizeBox = false;
        BackColor = Color.FromArgb(42, 44, 49);
        ForeColor = Color.White;
        Font = new Font("Microsoft YaHei UI", 9f);

        _dismissTimer.Tick += (_, _) =>
        {
            _dismissTimer.Stop();
            Hide();
        };
    }

    public void ShowMessage(
        string title,
        string subtitle,
        string? primaryTitle,
        Action? primaryAction,
        string? secondaryTitle,
        Action? secondaryAction,
        int durationMilliseconds)
    {
        Controls.Clear();

        var titleLabel = new Label
        {
            Text = title,
            Left = 22,
            Top = 14,
            Width = 214,
            Height = 28,
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 15f, FontStyle.Bold)
        };
        Controls.Add(titleLabel);

        var subtitleLabel = new Label
        {
            Text = subtitle,
            Left = 22,
            Top = 42,
            Width = 214,
            Height = 22,
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = Color.FromArgb(190, 225, 228, 236),
            Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Bold)
        };
        Controls.Add(subtitleLabel);

        if (!string.IsNullOrWhiteSpace(primaryTitle))
        {
            var primary = MakeButton(primaryTitle, true);
            primary.SetBounds(36, 74, 96, 30);
            primary.Click += (_, _) =>
            {
                Hide();
                primaryAction?.Invoke();
            };
            Controls.Add(primary);
        }

        if (!string.IsNullOrWhiteSpace(secondaryTitle))
        {
            var secondary = MakeButton(secondaryTitle, false);
            secondary.SetBounds(144, 74, 76, 30);
            secondary.Click += (_, _) =>
            {
                Hide();
                secondaryAction?.Invoke();
            };
            Controls.Add(secondary);
        }

        var area = Screen.PrimaryScreen?.WorkingArea ?? Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(area.Right - Width - 18, area.Bottom - Height - 18);
        Show();
        Activate();

        _dismissTimer.Stop();
        _dismissTimer.Interval = durationMilliseconds;
        _dismissTimer.Start();
    }

    private static Button MakeButton(string text, bool primary)
    {
        return new Button
        {
            Text = text,
            FlatStyle = FlatStyle.Flat,
            BackColor = primary ? Color.FromArgb(0, 122, 255) : Color.FromArgb(64, 69, 80),
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold),
            Cursor = Cursors.Hand
        };
    }
}
