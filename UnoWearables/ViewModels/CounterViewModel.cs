using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace UnoWearables;

internal partial class CounterViewModel : ObservableObject
{
    [ObservableProperty]
    private int _count = 0;

    [RelayCommand]
    private void Increment() => Count++;
}