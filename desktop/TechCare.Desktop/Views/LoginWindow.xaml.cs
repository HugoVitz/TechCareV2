using System.Windows;
using TechCare.Desktop.ViewModels;

namespace TechCare.Desktop.Views;

public partial class LoginWindow : Window
{
    private readonly LoginViewModel _vm;

    public LoginWindow(LoginViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;
    }

    // O PasswordBox não aceita binding (a senha não fica em propriedade pública); por isso é lido aqui.
    private async void Entrar_Click(object sender, RoutedEventArgs e)
    {
        IsEnabled = false;
        try
        {
            if (await _vm.EntrarAsync(SenhaBox.Password))
                DialogResult = true;
        }
        finally
        {
            IsEnabled = true;
        }
    }
}
