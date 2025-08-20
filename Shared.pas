unit Shared;

interface

type
  TTaskInfo = record
    ID: string;
    Name: string;
    Description: string;
    Params: array of record
      Name: string;
      ParamType: string; // 'string', 'integer', 'boolean' и т.д.
      IsRequired: Boolean;
    end;
  end;

  TTaskExecuteCallback = procedure(const TaskID: string; const Params: array of Variant;
                                  Callback: TProc<string, Integer, string>) of object;

  // API функции, которые должны быть в DLL
  TGetTasksFunc = function: TArray<TTaskInfo>;
  TExecuteTaskFunc = procedure(const TaskID: string; const Params: array of Variant;
                              Callback: TProc<string, Integer, string>);
implementation

end.
