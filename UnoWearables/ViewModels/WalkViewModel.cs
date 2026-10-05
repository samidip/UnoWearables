using System.Diagnostics;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Dispatching;

namespace UnoWearables;

internal partial class WalkViewModel : ObservableObject
{
    // Average adult stride and walking speed, used to derive distance.
    private const double StrideMeters = 0.762;
    private const double EstimatedSpeedMetersPerSecond = 1.4;

    private readonly DispatcherQueue _dispatcher = DispatcherQueue.GetForCurrentThread();
    private readonly DispatcherQueueTimer _timer;
    private readonly StepSource _steps = new();
    private readonly Stopwatch _stopwatch = new();
    private CancellationTokenSource? _cts;
    private bool _usingSensor;

    public WalkViewModel()
    {
        _timer = _dispatcher.CreateTimer();
        _timer.Interval = TimeSpan.FromMilliseconds(500);
        _timer.Tick += (_, _) => Refresh();
        _steps.StepsChanged += steps => _dispatcher.TryEnqueue(() =>
        {
            StepCount = steps;
            Refresh();
        });
    }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ToggleGlyph), nameof(ToggleLabel))]
    private bool _isWalking;

    [ObservableProperty]
    private string _elapsedText = "00:00";

    [ObservableProperty]
    private string _distanceText = "0.00 km";

    [ObservableProperty]
    private string _stepsText = "0 steps";

    [ObservableProperty]
    private int _stepCount;

    // Fluent glyphs: Stop / Play
    public string ToggleGlyph => IsWalking ? "" : "";

    public string ToggleLabel => IsWalking ? "Stop walk" : "Start walk";

    [RelayCommand]
    private async Task ToggleAsync()
    {
        if (IsWalking)
        {
            Stop();
            return;
        }

        StepCount = 0;
        _usingSensor = false;
        _stopwatch.Restart();
        _timer.Start();
        IsWalking = true;
        Refresh();

        _cts = new CancellationTokenSource();
        var sensorStarted = await _steps.StartAsync(_cts.Token);
        if (!IsWalking)
        {
            // Stopped while waiting on the permission prompt.
            _steps.Stop();
            return;
        }

        _usingSensor = sensorStarted;
        Refresh();
    }

    public void Stop()
    {
        if (!IsWalking)
        {
            return;
        }

        _cts?.Cancel();
        _steps.Stop();
        _timer.Stop();
        _stopwatch.Stop();
        IsWalking = false;
        Refresh();
    }

    private void Refresh()
    {
        var elapsed = _stopwatch.Elapsed;
        ElapsedText = elapsed.TotalHours >= 1
            ? elapsed.ToString(@"h\:mm\:ss")
            : elapsed.ToString(@"mm\:ss");

        double meters;
        int steps;
        if (_usingSensor)
        {
            steps = StepCount;
            meters = steps * StrideMeters;
        }
        else
        {
            // No step sensor (desktop, browser, emulator without sensors): estimate from time.
            meters = elapsed.TotalSeconds * EstimatedSpeedMetersPerSecond;
            steps = (int)(meters / StrideMeters);
        }

        DistanceText = $"{meters / 1000:0.00} km";
        StepsText = _usingSensor ? $"{steps:N0} steps" : $"~{steps:N0} steps (est.)";
    }
}
