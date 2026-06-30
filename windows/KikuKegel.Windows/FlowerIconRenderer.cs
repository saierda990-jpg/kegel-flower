using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace KikuKegel.Windows;

internal enum FlowerExpression
{
    Normal,
    Contract,
    Relax,
    Eating,
    Sleeping
}

internal static class FlowerIconRenderer
{
    public static Icon CreateIcon(
        float scale = 1,
        float tiltDegrees = 0,
        FlowerExpression expression = FlowerExpression.Normal,
        float blink = 0,
        PointF lookOffset = default)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        graphics.TranslateTransform(16, 16);
        graphics.RotateTransform(tiltDegrees);
        graphics.ScaleTransform(scale, scale);
        graphics.TranslateTransform(-16, -16);

        DrawFlower(graphics);
        DrawExpression(graphics, expression, blink, lookOffset);

        var handle = bitmap.GetHicon();
        try
        {
            return (Icon)Icon.FromHandle(handle).Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    private static void DrawFlower(Graphics graphics)
    {
        using var brush = new SolidBrush(Color.White);
        using var shadow = new SolidBrush(Color.FromArgb(52, 0, 0, 0));
        var centers = new[]
        {
            new PointF(11.3f, 11.3f),
            new PointF(20.7f, 11.3f),
            new PointF(11.3f, 20.7f),
            new PointF(20.7f, 20.7f)
        };

        foreach (var center in centers)
        {
            graphics.FillEllipse(shadow, center.X - 7.4f, center.Y - 6.6f, 14.8f, 14.8f);
        }

        foreach (var center in centers)
        {
            graphics.FillEllipse(brush, center.X - 7.2f, center.Y - 7.2f, 14.4f, 14.4f);
        }
    }

    private static void DrawExpression(Graphics graphics, FlowerExpression expression, float blink, PointF lookOffset)
    {
        using var clearBrush = new SolidBrush(Color.FromArgb(235, 22, 24, 31));
        using var pen = new Pen(Color.FromArgb(235, 22, 24, 31), 2.2f)
        {
            StartCap = LineCap.Flat,
            EndCap = LineCap.Flat,
            LineJoin = LineJoin.Miter
        };

        switch (expression)
        {
            case FlowerExpression.Contract:
                graphics.DrawLines(pen, new[] { new PointF(12.0f, 12.4f), new PointF(15.0f, 16.0f), new PointF(12.0f, 19.6f) });
                graphics.DrawLines(pen, new[] { new PointF(20.0f, 12.4f), new PointF(17.0f, 16.0f), new PointF(20.0f, 19.6f) });
                break;
            case FlowerExpression.Relax:
                graphics.DrawLine(pen, 10.8f, 14.0f, 14.8f, 15.0f);
                graphics.DrawLine(pen, 17.2f, 15.0f, 21.2f, 14.0f);
                graphics.DrawLines(pen, new[] { new PointF(13.2f, 18.2f), new PointF(16.0f, 21.0f), new PointF(18.8f, 18.2f) });
                break;
            case FlowerExpression.Eating:
                DrawRoundedRect(graphics, clearBrush, 9.8f, 15.1f, 5.2f, 2.0f, 0.5f);
                DrawRoundedRect(graphics, clearBrush, 17.0f, 15.1f, 5.2f, 2.0f, 0.5f);
                break;
            case FlowerExpression.Sleeping:
                DrawRoundedRect(graphics, clearBrush, 8.9f, 18.4f, 5.7f, 1.9f, 0.5f);
                DrawRoundedRect(graphics, clearBrush, 17.4f, 18.4f, 5.7f, 1.9f, 0.5f);
                using (var zPen = new Pen(Color.FromArgb(205, 22, 24, 31), 2.1f) { StartCap = LineCap.Round, EndCap = LineCap.Round })
                {
                    graphics.DrawLines(zPen, new[] { new PointF(18.8f, 9.0f), new PointF(24.0f, 9.0f), new PointF(18.8f, 13.0f), new PointF(24.0f, 13.0f) });
                }
                break;
            case FlowerExpression.Normal:
            default:
                var clampedBlink = Math.Clamp(blink, 0, 1);
                var height = Math.Max(1.5f, 7.4f * (1 - clampedBlink));
                var width = 2.4f + 1.6f * clampedBlink;
                var xOffset = Math.Clamp(lookOffset.X, -2.0f, 2.0f);
                var yOffset = Math.Clamp(lookOffset.Y, -1.4f, 1.2f);
                DrawRoundedRect(graphics, clearBrush, 11.8f + xOffset - width / 2, 16f + yOffset - height / 2, width, height, width / 2);
                DrawRoundedRect(graphics, clearBrush, 20.2f + xOffset - width / 2, 16f + yOffset - height / 2, width, height, width / 2);
                break;
        }
    }

    private static void DrawRoundedRect(Graphics graphics, Brush brush, float x, float y, float width, float height, float radius)
    {
        using var path = new GraphicsPath();
        var diameter = radius * 2;
        path.AddArc(x, y, diameter, diameter, 180, 90);
        path.AddArc(x + width - diameter, y, diameter, diameter, 270, 90);
        path.AddArc(x + width - diameter, y + height - diameter, diameter, diameter, 0, 90);
        path.AddArc(x, y + height - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        graphics.FillPath(brush, path);
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);
}
