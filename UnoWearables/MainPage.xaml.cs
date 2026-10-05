namespace UnoWearables;

public sealed partial class MainPage : Page
{
    public MainPage()
    {
        this.InitializeComponent();
    }

    private void OnCounterClick(object sender, RoutedEventArgs e) => Frame.Navigate(typeof(CounterPage));

    private void OnWalkClick(object sender, RoutedEventArgs e) => Frame.Navigate(typeof(WalkPage));
}
