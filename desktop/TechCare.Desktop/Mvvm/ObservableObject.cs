using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace TechCare.Desktop.Mvvm;

/// <summary>
/// Base dos ViewModels (padrão OBSERVER via INotifyPropertyChanged): quando uma propriedade
/// muda, a tela que está ligada a ela (data binding) é avisada e se atualiza sozinha.
/// </summary>
public abstract class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected void OnPropertyChanged([CallerMemberName] string? nome = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nome));

    protected bool SetProperty<T>(ref T campo, T valor, [CallerMemberName] string? nome = null)
    {
        if (EqualityComparer<T>.Default.Equals(campo, valor)) return false;
        campo = valor;
        OnPropertyChanged(nome);
        return true;
    }
}
