using GitOpen.Application.DependencyInjection;
using GitOpen.Application.Workspaces;
using GitOpen.Infrastructure.DependencyInjection;
using GitOpen.Infrastructure.Persistence;
using GitOpen.Ui;
using GitOpen.Ui.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Photino.Blazor;
using Serilog;

namespace GitOpen.Ui;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.Console(formatProvider: null)
            .WriteTo.File(
                path: Path.Combine(PathProvider.LogDirectory(), "gitopen-.log"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 7,
                formatProvider: null)
            .CreateLogger();

        try
        {
            var builder = PhotinoBlazorAppBuilder.CreateDefault(args);
            builder.Services
                .AddLogging(lb => lb.AddSerilog())
                .AddGitOpenApplication()
                .AddGitOpenInfrastructure()
                .AddSingleton<IFolderPicker, PhotinoFolderPicker>();
            builder.RootComponents.Add<App>("app");

            var app = builder.Build();

            using (var scope = app.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<GitOpenDbContext>();
                db.Database.Migrate();
            }

            RehydrateWorkspaces(app.Services);

            var manager = app.Services.GetRequiredService<IWorkspaceManager>();
            manager.Opened    += _ => PersistAsync(app.Services);
            manager.Closed    += _ => PersistAsync(app.Services);
            manager.Reordered += _ => PersistAsync(app.Services);

            app.MainWindow
                .SetTitle("GitOpen")
                .SetSize(1400, 900)
                .SetResizable(true)
                .SetChromeless(true)
                .SetContextMenuEnabled(true)
                .SetDevToolsEnabled(true);

            var maximized = false;
            app.MainWindow.RegisterWebMessageReceivedHandler((sender, message) =>
            {
                try { HandleWebMessage((Photino.NET.PhotinoWindow)sender!, message, ref maximized); }
                catch (Exception ex) { Log.Warning(ex, "Failed handling web message {Message}", message); }
            });

            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
                Log.Fatal(e.ExceptionObject as Exception, "Unhandled exception");

            app.Run();
            return 0;
        }
        finally
        {
            Log.CloseAndFlush();
        }
    }

    private static void RehydrateWorkspaces(IServiceProvider sp)
    {
        using var scope = sp.CreateScope();
        var persistence = scope.ServiceProvider.GetRequiredService<IWorkspacePersistence>();
        var manager = scope.ServiceProvider.GetRequiredService<IWorkspaceManager>();
        var paths = persistence.GetOpenPathsAsync(default).GetAwaiter().GetResult();
        foreach (var p in paths)
        {
            if (!Directory.Exists(p))
            {
                Log.Warning("Workspace path no longer exists, skipping: {Path}", p);
                continue;
            }
            try
            {
                manager.OpenAsync(p, default).GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Failed to reopen workspace {Path}", p);
            }
        }
    }

    private const int MinWidth = 600;
    private const int MinHeight = 400;

    private static void HandleWebMessage(Photino.NET.PhotinoWindow window, string message, ref bool maximized)
    {
        if (message.StartsWith("drag:", StringComparison.Ordinal))
        {
            var parts = message.AsSpan(5);
            var sep = parts.IndexOf(':');
            if (sep < 0) return;
            if (!int.TryParse(parts[..sep], System.Globalization.CultureInfo.InvariantCulture, out var dx)) return;
            if (!int.TryParse(parts[(sep + 1)..], System.Globalization.CultureInfo.InvariantCulture, out var dy)) return;
            window.SetLeft(window.Left + dx);
            window.SetTop(window.Top + dy);
            return;
        }

        if (message.StartsWith("resize:", StringComparison.Ordinal))
        {
            var rest = message.AsSpan(7);
            var firstSep = rest.IndexOf(':');
            if (firstSep < 0) return;
            var edge = new string(rest[..firstSep]);
            var deltas = rest[(firstSep + 1)..];
            var secondSep = deltas.IndexOf(':');
            if (secondSep < 0) return;
            if (!int.TryParse(deltas[..secondSep], System.Globalization.CultureInfo.InvariantCulture, out var dx)) return;
            if (!int.TryParse(deltas[(secondSep + 1)..], System.Globalization.CultureInfo.InvariantCulture, out var dy)) return;
            ApplyResize(window, edge, dx, dy);
            return;
        }

        if (message == "toggleMax")
        {
            maximized = !maximized;
            window.SetMaximized(maximized);
            return;
        }
    }

    private static void ApplyResize(Photino.NET.PhotinoWindow window, string edge, int dx, int dy)
    {
        var left = window.Left;
        var top = window.Top;
        var width = window.Width;
        var height = window.Height;

        if (edge.Contains('w'))
        {
            var newW = Math.Max(MinWidth, width - dx);
            left += width - newW;
            width = newW;
        }
        if (edge.Contains('e'))
        {
            width = Math.Max(MinWidth, width + dx);
        }
        if (edge.Contains('n'))
        {
            var newH = Math.Max(MinHeight, height - dy);
            top += height - newH;
            height = newH;
        }
        if (edge.Contains('s'))
        {
            height = Math.Max(MinHeight, height + dy);
        }

        window.SetLeft(left);
        window.SetTop(top);
        window.SetSize(width, height);
    }

    private static void PersistAsync(IServiceProvider sp)
    {
        _ = Task.Run(async () =>
        {
            using var scope = sp.CreateScope();
            var p = scope.ServiceProvider.GetRequiredService<IWorkspacePersistence>();
            var m = scope.ServiceProvider.GetRequiredService<IWorkspaceManager>();
            var paths = m.All.Select(w => w.Location.Path).ToList();
            try
            {
                await p.SaveOpenPathsAsync(paths, default);
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Failed to persist workspaces");
            }
        });
    }
}
