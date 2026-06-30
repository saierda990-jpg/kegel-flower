using System.Drawing.Drawing2D;

namespace KikuKegel.Windows;

internal sealed class GradientBar : Control
{
    private double _value;
    private Color[] _colors = { Color.FromArgb(255, 110, 120), Color.FromArgb(210, 38, 60) };

    public double Value
    {
        get => _value;
        set
        {
            _value = Math.Clamp(value, 0, 1);
            Invalidate();
        }
    }

    public Color[] Colors
    {
        get => _colors;
        set
        {
            _colors = value.Length == 0 ? _colors : value;
            Invalidate();
        }
    }

    public GradientBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
        Height = 9;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        var rect = new RectangleF(0, 0, Width - 1, Height - 1);
        using (var path = RoundRect(rect, Height / 2f))
        using (var background = new SolidBrush(Color.FromArgb(38, 255, 255, 255)))
        {
            e.Graphics.FillPath(background, path);
        }

        if (_value <= 0)
        {
            return;
        }

        var fillRect = new RectangleF(0, 0, Math.Max(8, (float)(Width * _value)), Height - 1);
        using var fillPath = RoundRect(fillRect, Height / 2f);
        using var brush = new LinearGradientBrush(fillRect, _colors.First(), _colors.Last(), LinearGradientMode.Horizontal);
        if (_colors.Length > 2)
        {
            var blend = new ColorBlend
            {
                Colors = _colors,
                Positions = Enumerable.Range(0, _colors.Length)
                    .Select(index => index / (float)(_colors.Length - 1))
                    .ToArray()
            };
            brush.InterpolationColors = blend;
        }

        e.Graphics.FillPath(brush, fillPath);
        using var shine = new LinearGradientBrush(fillRect, Color.FromArgb(82, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), LinearGradientMode.Vertical);
        e.Graphics.FillPath(shine, fillPath);
    }

    private static GraphicsPath RoundRect(RectangleF rect, float radius)
    {
        var path = new GraphicsPath();
        var diameter = radius * 2;
        path.AddArc(rect.X, rect.Y, diameter, diameter, 180, 90);
        path.AddArc(rect.Right - diameter, rect.Y, diameter, diameter, 270, 90);
        path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rect.X, rect.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
