using System.Windows;
using TechCare.Desktop.ViewModels;

namespace TechCare.Desktop.Views;

public partial class MainWindow : Window
{
    public MainWindow(MainViewModel vm)
    {
        InitializeComponent();
        DataContext = vm;
        Loaded += async (_, _) => await vm.IniciarAsync();
    }
}
