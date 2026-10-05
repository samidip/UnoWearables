using Windows.Devices.Sensors;

// Pedometer is implemented on Android and iOS only; other targets get a null default and fall back.
#pragma warning disable Uno0001

namespace UnoWearables;

/// <summary>
/// Wraps the platform pedometer. On Wear OS (and Android phones) this is backed by the
/// hardware step counter; elsewhere <see cref="StartAsync"/> returns false and the caller
/// falls back to a time-based estimate.
/// </summary>
internal sealed class StepSource
{
    private Pedometer? _pedometer;
    private int? _baseline;

    /// <summary>Raised with the number of steps taken since <see cref="StartAsync"/>. May fire off the UI thread.</summary>
    public event Action<int>? StepsChanged;

    public async Task<bool> StartAsync(CancellationToken ct)
    {
        if (!await EnsurePermissionAsync(ct))
        {
            return false;
        }

        try
        {
            _pedometer = await Pedometer.GetDefaultAsync();
        }
        catch (Exception)
        {
            // Not implemented on this platform.
            _pedometer = null;
        }

        if (_pedometer is null)
        {
            return false;
        }

        _baseline = null;
        _pedometer.ReadingChanged += OnReadingChanged;
        return true;
    }

    public void Stop()
    {
        if (_pedometer is not null)
        {
            _pedometer.ReadingChanged -= OnReadingChanged;
            _pedometer = null;
        }
    }

    private void OnReadingChanged(Pedometer sender, PedometerReadingChangedEventArgs args)
    {
        // The Android step counter is cumulative since boot, so measure from the first reading.
        var total = args.Reading.CumulativeSteps;
        _baseline ??= total;
        StepsChanged?.Invoke(total - _baseline.Value);
    }

    private static async Task<bool> EnsurePermissionAsync(CancellationToken ct)
    {
#if __ANDROID__
        // Below API 29 the step counter needs no runtime permission.
        if (OperatingSystem.IsAndroidVersionAtLeast(29))
        {
            return await Windows.Extensions.PermissionsHelper.TryGetPermission(
                ct, Android.Manifest.Permission.ActivityRecognition);
        }
#endif
        await Task.CompletedTask;
        return true;
    }
}
