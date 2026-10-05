using System.ComponentModel;

namespace UnoWearables;

public sealed partial class WalkPage : Page
{
    private readonly WalkViewModel _viewModel = new();

    public WalkPage()
    {
        this.InitializeComponent();
        DataContext = _viewModel;
        _viewModel.PropertyChanged += OnViewModelPropertyChanged;
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);

        // Leaving the page ends the walk so no sensor listener or timer keeps running.
        _viewModel.Stop();
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(WalkViewModel.IsWalking))
        {
            return;
        }

        if (_viewModel.IsWalking)
        {
            WalkStoryboard.Begin();
            ToggleButton.Background = (Brush)Application.Current.Resources["WatchStopBrush"];
        }
        else
        {
            // Stop() snaps the figure back to its standing pose.
            WalkStoryboard.Stop();
            ToggleButton.Background = (Brush)Application.Current.Resources["WatchWalkBrush"];
        }
    }

    private void OnBackClick(object sender, RoutedEventArgs e) => Frame.GoBack();
}
