unit TaskInterface;

interface

uses
  System.Classes, System.SysUtils;

type
  // Статусы задачи
  TTaskStatus = (tsReady, tsRunning, tsCompleted, tsCanceled, tsError);

// Информация о прогрессе выполнения
  TProgressInfo = record
    Current: Integer;
    Total: Integer;
    Message: string;
  end;

// Базовый интерфейс для всех задач
  ITask = interface
    ['{7D5D0F5E-4A30-4B8C-9E5D-0D5A5F5E5D5F}']
    function GetName: string;
    function GetStatus: TTaskStatus;
    function GetProgress: TProgressInfo;
    function GetResult: string;
    procedure Execute(Params: array of string);
    procedure Cancel;
  end;

// Функция создания экземпляра задачи
  TCreateTaskFunc = function: ITask; stdcall;

implementation

end.
