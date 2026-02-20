program AntimonyExample;

{*******************************************************************************
  AntimonyExample.pas

  Demonstrates the TAntimony wrapper by loading a sample Antimony model and
  printing a structured report of:
    - All species (variable and boundary), with compartment and initial value
    - All parameters, with initial value
    - All reactions, with reactants, products, stoichiometries, and rate law

  Build (Delphi):
    Add AntimonyAPI.pas and AntimonyWrapper.pas to the project.
    Ensure libantimony.dll (Windows) / libantimony.so (Linux) /
    libantimony.dylib (macOS) is on the library path.

  Build (FPC / Lazarus):
    (*$MODE DELPHI*) is set in both binding units; compile as normal.
*******************************************************************************}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AntimonyAPI in 'AntimonyAPI.pas',
  AntimonyWrapper in 'AntimonyWrapper.pas';

// ---------------------------------------------------------------------------
//  The sample model – a simple two-step linear pathway with one boundary
//  species, one event, and one parameter defined by an assignment rule.
// ---------------------------------------------------------------------------
const
  MODEL =
    'model pathway'                           + #10 +
    ''                                        + #10 +
    '  // Compartment'                        + #10 +
    '  compartment cell = 1;'                 + #10 +
    ''                                        + #10 +
    '  // Species'                            + #10 +
    '  var species S1 in cell = 10;'          + #10 +
    '  var species S2 in cell = 0;'           + #10 +
    '  var species S3 in cell = 0;'           + #10 +
    '  const species S0 in cell = 5;'         + #10 +
    ''                                        + #10 +
    '  // Reactions'                          + #10 +
    '  J1: S0 -> S1;  k1 * S0;'              + #10 +
    '  J2: S1 -> S2;  k2 * S1;'              + #10 +
    '  J3: S2 -> S3;  k3 * S2;'              + #10 +
    ''                                        + #10 +
    '  // Parameters'                         + #10 +
    '  k1 = 0.1;'                             + #10 +
    '  k2 = 0.2;'                             + #10 +
    '  k3 = 0.3;'                             + #10 +
    ''                                        + #10 +
    '  // Assignment rule – total flux'       + #10 +
    '  totalFlux := k1*S0 + k2*S1 + k3*S2;'  + #10 +
    ''                                        + #10 +
    '  // Event – halve k2 when S2 exceeds 2' + #10 +
    '  E1: at (S2 > 2): k2 = k2 / 2;'        + #10 +
    ''                                        + #10 +
    'end';

// ---------------------------------------------------------------------------
//  Formatting helpers
// ---------------------------------------------------------------------------

procedure PrintSeparator(const ATitle: string);
begin
  WriteLn;
  WriteLn('=== ', ATitle, ' ===');
end;

procedure PrintLine(const ALabel, AValue: string;
  AIndent: Integer = 2);
begin
  WriteLn(StringOfChar(' ', AIndent), ALabel, AValue);
end;

// ---------------------------------------------------------------------------
//  Report sections
// ---------------------------------------------------------------------------

procedure ReportSpecies(Ant: TAntimony; const AModule: string);
var
  nVar, nConst, i : Integer;
  Names, Eqs, Comps: TArray<string>;
  sVal            : string;
begin
  PrintSeparator('SPECIES');

  // --- variable (floating) species ---
  nVar := Integer(Ant.GetNumSymbolsOfType(AModule, varSpecies));
  WriteLn('  Variable species: ', nVar);
  if nVar > 0 then
  begin
    Names := Ant.GetSymbolNamesOfType(AModule, varSpecies);
    Eqs   := Ant.GetSymbolEquationsOfType(AModule, varSpecies);
    Comps := Ant.GetSymbolCompartmentsOfType(AModule, varSpecies);
    for i := 0 to nVar - 1 do
    begin
      sVal := Eqs[i];
      if sVal = '' then sVal := '(not set)';
      WriteLn('    [', i, '] ', Names[i]);
      PrintLine('Compartment : ', Comps[i], 8);
      PrintLine('Initial val : ', sVal, 8);
    end;
  end;

  // --- constant (boundary) species ---
  nConst := Integer(Ant.GetNumSymbolsOfType(AModule, constSpecies));
  WriteLn;
  WriteLn('  Boundary (constant) species: ', nConst);
  if nConst > 0 then
  begin
    Names := Ant.GetSymbolNamesOfType(AModule, constSpecies);
    Eqs   := Ant.GetSymbolEquationsOfType(AModule, constSpecies);
    Comps := Ant.GetSymbolCompartmentsOfType(AModule, constSpecies);
    for i := 0 to nConst - 1 do
    begin
      sVal := Eqs[i];
      if sVal = '' then sVal := '(not set)';
      WriteLn('    [', i, '] ', Names[i]);
      PrintLine('Compartment : ', Comps[i], 8);
      PrintLine('Initial val : ', sVal, 8);
    end;
  end;
end;

procedure ReportParameters(Ant: TAntimony; const AModule: string);
var
  nConst, nVar, i  : Integer;
  Names, Eqs       : TArray<string>;
  AssignRules       : TArray<string>;
  sVal             : string;
begin
  PrintSeparator('PARAMETERS');

  // --- constant parameters ---
  nConst := Integer(Ant.GetNumSymbolsOfType(AModule, constFormulas));
  WriteLn('  Constant parameters: ', nConst);
  if nConst > 0 then
  begin
    Names := Ant.GetSymbolNamesOfType(AModule, constFormulas);
    Eqs   := Ant.GetSymbolEquationsOfType(AModule, constFormulas);
    for i := 0 to nConst - 1 do
    begin
      sVal := Eqs[i];
      if sVal = '' then sVal := '(not set)';
      WriteLn('    [', i, '] ', Names[i], ' = ', sVal);
    end;
  end;

  // --- variable formulas (assignment-rule driven parameters / observables) ---
  nVar := Integer(Ant.GetNumSymbolsOfType(AModule, varFormulas));
  WriteLn;
  WriteLn('  Variable formulas (assignment rules etc.): ', nVar);
  if nVar > 0 then
  begin
    Names       := Ant.GetSymbolNamesOfType(AModule, varFormulas);
    AssignRules := Ant.GetSymbolAssignmentRulesOfType(AModule, varFormulas);
    Eqs         := Ant.GetSymbolEquationsOfType(AModule, varFormulas);
    for i := 0 to nVar - 1 do
    begin
      WriteLn('    [', i, '] ', Names[i]);
      sVal := AssignRules[i];
      if sVal <> '' then
        PrintLine('Assignment rule : ', sVal, 8)
      else
      begin
        sVal := Eqs[i];
        if sVal = '' then sVal := '(not set)';
        PrintLine('Initial value   : ', sVal, 8);
      end;
    end;
  end;
end;

procedure ReportReactions(Ant: TAntimony; const AModule: string);
var
  nRxn, nR, nP, i, j : Integer;
  RxnName             : string;
  RNames, PNames      : TArray<string>;
  RStoich, PStoich    : TArray<Double>;
  RateStr             : string;
  LHS, RHS, Term      : string;
begin
  PrintSeparator('REACTIONS');

  nRxn := Integer(Ant.GetNumReactions(AModule));
  WriteLn('  Total reactions: ', nRxn);

  for i := 0 to nRxn - 1 do
  begin
    RxnName := Ant.GetNthSymbolNameOfType(AModule, allReactions, Cardinal(i));
    WriteLn;
    WriteLn('  Reaction [', i, '] : ', RxnName);

    // --- reactants ---
    nR     := Integer(Ant.GetNumReactants(AModule, Cardinal(i)));
    RNames := Ant.GetNthReactionReactantNames(AModule, Cardinal(i));
    RStoich:= Ant.GetNthReactionReactantStoichiometries(AModule, Cardinal(i));

    LHS := '';
    for j := 0 to nR - 1 do
    begin
      if RStoich[j] = 1.0 then
        Term := RNames[j]
      else
        Term := Format('%g %s', [RStoich[j], RNames[j]]);
      if j = 0 then LHS := Term
      else          LHS := LHS + ' + ' + Term;
    end;
    if LHS = '' then LHS := '∅';

    // --- products ---
    nP     := Integer(Ant.GetNumProducts(AModule, Cardinal(i)));
    PNames := Ant.GetNthReactionProductNames(AModule, Cardinal(i));
    PStoich:= Ant.GetNthReactionProductStoichiometries(AModule, Cardinal(i));

    RHS := '';
    for j := 0 to nP - 1 do
    begin
      if PStoich[j] = 1.0 then
        Term := PNames[j]
      else
        Term := Format('%g %s', [PStoich[j], PNames[j]]);
      if j = 0 then RHS := Term
      else          RHS := RHS + ' + ' + Term;
    end;
    if RHS = '' then RHS := '∅';

    PrintLine('Equation  : ', LHS + ' -> ' + RHS, 4);

    // --- individual reactant details ---
    if nR > 0 then
    begin
      PrintLine('Reactants :', '', 4);
      for j := 0 to nR - 1 do
        PrintLine(Format('  %-12s stoich = %g', [RNames[j], RStoich[j]]), '', 4);
    end;

    // --- individual product details ---
    if nP > 0 then
    begin
      PrintLine('Products  :', '', 4);
      for j := 0 to nP - 1 do
        PrintLine(Format('  %-12s stoich = %g', [PNames[j], PStoich[j]]), '', 4);
    end;

    // --- rate law ---
    RateStr := Ant.GetNthReactionRate(AModule, Cardinal(i));
    if RateStr = '' then RateStr := '(not set)';
    PrintLine('Rate law  : ', RateStr, 4);
  end;
end;

procedure ReportEvents(Ant: TAntimony; const AModule: string);
var
  nEv, nAsgn, i, j : Integer;
  EvName, Trigger  : string;
  Delay            : string;
  AssignVar, AssignEq : string;
begin
  PrintSeparator('EVENTS');

  nEv := Integer(Ant.GetNumEvents(AModule));
  WriteLn('  Total events: ', nEv);

  for i := 0 to nEv - 1 do
  begin
    EvName  := Ant.GetNthEventName(AModule, Cardinal(i));
    Trigger := Ant.GetTriggerForEvent(AModule, Cardinal(i));
    WriteLn;
    WriteLn('  Event [', i, '] : ', EvName);
    PrintLine('Trigger     : ', Trigger, 4);

    if Ant.GetEventHasDelay(AModule, Cardinal(i)) then
    begin
      Delay := Ant.GetDelayForEvent(AModule, Cardinal(i));
      PrintLine('Delay       : ', Delay, 4);
    end;

    nAsgn := Integer(Ant.GetNumAssignmentsForEvent(AModule, Cardinal(i)));
    if nAsgn > 0 then
    begin
      PrintLine('Assignments :', '', 4);
      for j := 0 to nAsgn - 1 do
      begin
        AssignVar := Ant.GetNthAssignmentVariableForEvent(
                       AModule, Cardinal(i), Cardinal(j));
        AssignEq  := Ant.GetNthAssignmentEquationForEvent(
                       AModule, Cardinal(i), Cardinal(j));
        PrintLine(Format('  %s = %s', [AssignVar, AssignEq]), '', 4);
      end;
    end;
  end;
end;

// ---------------------------------------------------------------------------
//  Stoichiometry matrix
// ---------------------------------------------------------------------------

procedure ReportStoichiometryMatrix(Ant: TAntimony; const AModule: string);
var
  nRows, nCols : Cardinal;
  RowLabels    : TArray<string>;
  ColLabels    : TArray<string>;
  Matrix       : TArray<TArray<Double>>;
  i, j         : Integer;
  Header, Line : string;
  ColW         : Integer;
begin
  PrintSeparator('STOICHIOMETRY MATRIX  (rows = variable species, cols = reactions)');

  nRows := Ant.GetStoichiometryMatrixNumRows(AModule);
  nCols := Ant.GetStoichiometryMatrixNumColumns(AModule);

  if (nRows = 0) or (nCols = 0) then
  begin
    WriteLn('  (matrix is empty)');
    Exit;
  end;

  RowLabels := Ant.GetStoichiometryMatrixRowLabels(AModule);
  ColLabels := Ant.GetStoichiometryMatrixColumnLabels(AModule);
  Matrix    := Ant.GetStoichiometryMatrix(AModule);

  ColW := 10;  // fixed column width for display

  // header row
  Header := '  ' + StringOfChar(' ', 12);
  for j := 0 to Integer(nCols) - 1 do
    Header := Header + Format('%-*s', [ColW, ColLabels[j]]);
  WriteLn(Header);

  // data rows
  for i := 0 to Integer(nRows) - 1 do
  begin
    Line := '  ' + Format('%-12s', [RowLabels[i]]);
    for j := 0 to Integer(nCols) - 1 do
      Line := Line + Format('%-*g', [ColW, Matrix[i][j]]);
    WriteLn(Line);
  end;
end;

// ---------------------------------------------------------------------------
//  Main
// ---------------------------------------------------------------------------

var
  Ant       : TAntimony;
  ModuleName: string;

begin
  try
    Ant := TAntimony.Create;
    try
      // ----------------------------------------------------------------
      //  Load the model
      // ----------------------------------------------------------------
      WriteLn('Loading Antimony model...');
      Ant.LoadAntimonyString(MODEL);

      ModuleName := Ant.GetMainModuleName;
      WriteLn('Main module : ', ModuleName);
      WriteLn('Modules     : ', Ant.GetNumModules);

      // ----------------------------------------------------------------
      //  Print reports
      // ----------------------------------------------------------------
      ReportSpecies           (Ant, ModuleName);
      ReportParameters        (Ant, ModuleName);
      ReportReactions         (Ant, ModuleName);
      ReportEvents            (Ant, ModuleName);
      ReportStoichiometryMatrix(Ant, ModuleName);

      WriteLn;
      WriteLn('Done.');

    finally
      Ant.Free;   // calls freeAll internally
    end;

  except
    on E: EAntimonyError do
    begin
      WriteLn('Antimony error: ', E.Message);
      ExitCode := 1;
    end;
    on E: Exception do
    begin
      WriteLn('Unexpected error: ', E.ClassName, ' – ', E.Message);
      ExitCode := 1;
    end;
  end;

  {$IFDEF MSWINDOWS}
  Write('Press Enter to exit...'); ReadLn;
  {$ENDIF}
end.

