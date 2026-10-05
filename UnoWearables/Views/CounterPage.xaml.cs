namespace UnoWearables;

public sealed partial class CounterPage : Page
{
    public CounterPage()
    {
        this.InitializeComponent();
    }

    private void OnBackClick(object sender, RoutedEventArgs e) => Frame.GoBack();
}
