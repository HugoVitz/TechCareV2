using System.Windows.Input;

namespace TechCare.Desktop.Mvvm;

/// <summary>Padrão COMMAND: o botão da tela executa uma ação do ViewModel sem conhecer a lógica.</summary>
public class RelayCommand : ICommand
{
    private readonly Action _executar;
    private readonly Func<bool>? _podeExecutar;

    public RelayCommand(Action executar, Func<bool>? podeExecutar = null)
    {
        _executar = executar;
        _podeExecutar = podeExecutar;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter) => _podeExecutar?.Invoke() ?? true;
    public void Execute(object? parameter) => _executar();
}

/// <summary>Comando assíncrono: não trava a tela enquanto chama a API e evita clique duplo.</summary>
public class AsyncRelayCommand : ICommand
{
    private readonly Func<Task> _executar;
    private readonly Func<bool>? _podeExecutar;
    private bool _executando;

    public AsyncRelayCommand(Func<Task> executar, Func<bool>? podeExecutar = null)
    {
        _executar = executar;
        _podeExecutar = podeExecutar;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter) => !_executando && (_podeExecutar?.Invoke() ?? true);

    public async void Execute(object? parameter)
    {
        if (!CanExecute(parameter)) return;
        _executando = true;
        CommandManager.InvalidateRequerySuggested();
        try
        {
            await _executar();
        }
        finally
        {
            _executando = false;
            CommandManager.InvalidateRequerySuggested();
        }
    }
}
