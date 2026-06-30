using System.Drawing.Drawing2D;

namespace KikuKegel.Windows;

internal sealed class PillTabButton : Control
{
    private bool _selected;
    private bool _showDot;
    private bool _hovered;

    public bool Selected
    {
        get => _selected;
        set
        {
            _selected = value;
            Invalidate();
        }
    }

    public bool ShowDot
    {
        get => _showDot;
        set
        {
            _showDot = value;
            Invalidate();
        }
    }

    public PillTabButton()
    {
        Cursor = Cursors.Hand;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        _hovered = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        _hovered = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        var rect = new RectangleF(0, 0, Width - 1, Height - 1);
        using var path = new GraphicsPath();
        var radius = Height / 2f;
        path.AddArc(rect.X, rect.Y, radius * 2, radius * 2, 180, 90);
        path.AddArc(rect.Right - radius * 2, rect.Y, radius * 2, radius * 2, 270, 90);
        path.AddArc(rect.Right - radius * 2, rect.Bottom - radius * 2, radius * 2, radius * 2, 0, 90);
        path.AddArc(rect.X, rect.Bottom - radius * 2, radius * 2, radius * 2, 90, 90);
        path.CloseFigure();

        var alpha = _selected ? 42 : (_hovered ? 22 : 0);
        using (var brush = new SolidBrush(Color.FromArgb(alpha, 255, 255, 255)))
        {
            e.Graphics.FillPath(brush, path);
        }

        using var font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);
        TextRenderer.DrawText(
            e.Graphics,
            Text,
            font,
            ClientRectangle,
            _selected ? Color.White : Color.FromArgb(188, 214, 218, 228),
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding
        );

        if (!_showDot)
        {
            return;
        }

        var dotRect = new RectangleF(Width - 22, 6, 8, 8);
        using var dotBrush = new LinearGradientBrush(dotRect, Color.FromArgb(255, 100, 96), Color.FromArgb(220, 0, 28), LinearGradientMode.ForwardDiagonal);
        e.Graphics.FillEllipse(dotBrush, dotRect);
        using var dotPen = new Pen(Color.FromArgb(180, 255, 255, 255), 1);
        e.Graphics.DrawEllipse(dotPen, dotRect);
    }
}
