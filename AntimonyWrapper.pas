unit AntimonyWrapper;

{*******************************************************************************
  AntimonyWrapper.pas

  High-level Delphi OOP wrapper around the low-level AntimonyAPI static binding.

  Usage overview
  --------------
    var
      Ant  : TAntimony;
      SBML : string;
    begin
      Ant := TAntimony.Create;
      try
        Ant.LoadAntimonyString('model test; S1 -> S2; k1*S1; k1=0.1; S1=10; end');
        SBML := Ant.GetSBMLString('test');
        WriteLn(SBML);
      finally
        Ant.Free;  // calls freeAll internally
      end;
    end;

  Memory management
  -----------------
  Every C string / array returned by libAntimony is *immediately* copied into
  a Delphi-owned string or TArray<T>.  The original C-side allocation therefore
  stays alive but unreferenced until the object is destroyed (or until you call
  FreeAllAllocations explicitly), at which point freeAll() is called once.

  IMPORTANT: Do not mix raw AntimonyAPI calls with this wrapper in the same
  program.  If you free individual pointers yourself anywhere, freeAll() in the
  destructor will crash.  Either use this wrapper exclusively or use the raw
  binding exclusively.

  Error handling
  --------------
  * LoadXxx functions raise EAntimonyError when the C function returns -1.
  * Single-string query functions raise EAntimonyError when the C function
    returns nil (which indicates an out-of-range index or bad module name).
  * Array-returning functions return an empty array rather than raising when
    the element count is zero.
  * Boolean and numeric functions return the C value directly; on unexpected
    zero/false returns you can read GetLastError.
  * Use GetLastError at any time to read the most recent error message.

  Delphi version
  --------------
  Targets Delphi XE2+ (uses System.SysUtils).  Compiles under FPC
  with (*$MODE DELPHI*) as well.

  Author : binding and wrapper generated for Herbert Sauro.
  Source : https://antimony.sourceforge.net/antimony__api_8h.html
*******************************************************************************}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  AntimonyAPI;  // low-level static binding unit

// ---------------------------------------------------------------------------
//  Exception
// ---------------------------------------------------------------------------
type
  { Raised for load failures and for nil returns from single-value queries. }
  EAntimonyError = class(Exception);

// ---------------------------------------------------------------------------
//  Helper record – one symbol-synchronisation (replacement) pair
// ---------------------------------------------------------------------------
type
  { Represents a (former-name → replacement-name) pair produced by an
    Antimony 'is' construct or a module-interface connection. }
  TSymbolPair = record
    Former      : string;  // the symbol that was replaced / synchronised away
    Replacement : string;  // the symbol it was replaced / synchronised with
    class function Make(const AFormer, AReplacement: string): TSymbolPair;
      static; inline;
  end;

// ---------------------------------------------------------------------------
//  Main wrapper class
// ---------------------------------------------------------------------------
type
  TAntimony = class
  private

    // -----------------------------------------------------------------------
    //  Internal conversion helpers
    // -----------------------------------------------------------------------

    { Convert a C null-terminated string to a Delphi string.  Returns '' for nil. }
    function CStr(p: PAnsiChar): string; inline;

    { Convert a C char** of ACount elements to TArray<string>. }
    function CStrArr(pp: PPAnsiChar; ACount: Integer): TArray<string>;

    { Convert a C char*** (jagged) to TArray<TArray<string>>.
      ACounts[i] is the length of inner array i. }
    function CStr2DArr(ppp: PPPAnsiChar;
      const ACounts: TArray<Integer>): TArray<TArray<string>>;

    { Convert a C double* of ACount elements to TArray<Double>. }
    function CDblArr(pd: PDouble; ACount: Integer): TArray<Double>;

    { Convert a C double** (jagged) to TArray<TArray<Double>>.
      ACounts[i] is the length of inner array i. }
    function CDbl2DArr(ppd: PPDouble;
      const ACounts: TArray<Integer>): TArray<TArray<Double>>;

    { Convert a C unsigned-long* of ACount elements to TArray<Cardinal>. }
    function CCardArr(pc: PCardinal; ACount: Integer): TArray<Cardinal>;

    { Decode a char** pair [former, replacement] into a TSymbolPair.
      Raises EAntimonyError if pp is nil. }
    function CPairToSymbolPair(pp: PPAnsiChar;
      const AContext: string): TSymbolPair;

    { Raise EAntimonyError with the current last-error text when AResult < 0. }
    procedure CheckLoad(AResult: LongInt; const AContext: string);

    { Raise EAntimonyError with the current last-error text when APtr = nil. }
    procedure CheckPtr(APtr: Pointer; const AContext: string);

    { Build a TArray<Integer> with ACount elements all set to AValue. }
    function UniformCounts(ACount, AValue: Integer): TArray<Integer>; inline;

    { Build inner-count array for reactions: counts[i] = f(moduleName, i).
      AFn is called for each reaction index. }
    { Typed cdecl function pointer matching getNumReactants / getNumProducts /
      getNumInteractors / getNumInteractees – used by ReactionInnerCounts. }
    type TCountByIndexFn = function(moduleName: PAnsiChar;
                                    index: Cardinal): Cardinal; cdecl;

    function ReactionInnerCounts(const AModuleName: AnsiString;
      ANumItems: Cardinal;
      AGetCount: TCountByIndexFn): TArray<Integer>;

  public

    destructor Destroy; override;

    { Release every C-side allocation made by libAntimony.
      Safe to call at any time because the wrapper has already copied all
      returned data into Delphi-owned memory.  Also called automatically by
      the destructor. }
    procedure FreeAllAllocations;

    // ======================================================================
    //  INPUT
    // ======================================================================

    { Load a file of any format libAntimony supports (Antimony / SBML / CellML).
      Returns the non-negative index of the loaded module set.
      Raises EAntimonyError on failure. }
    function LoadFile(const AFilename: string): LongInt;

    { Load a string of any recognised format.
      Returns the non-negative index on success.
      Raises EAntimonyError on failure. }
    function LoadString(const AModel: string): LongInt;

    { Load a file in Antimony format.
      Raises EAntimonyError on failure. }
    function LoadAntimonyFile(const AFilename: string): LongInt;

    { Load a string in Antimony format.
      Raises EAntimonyError on failure. }
    function LoadAntimonyString(const AModel: string): LongInt;

    { Load a file in SBML format.
      Raises EAntimonyError on failure. }
    function LoadSBMLFile(const AFilename: string): LongInt;

    { Load a string in SBML format.
      Raises EAntimonyError on failure. }
    function LoadSBMLString(const AModel: string): LongInt;

    { Load an SBML string together with its originating file path (used to
      resolve relative imports).
      Raises EAntimonyError on failure. }
    function LoadSBMLStringWithLocation(const AModel,
      ALocation: string): LongInt;

    { Load a file in CellML format.
      Raises EAntimonyError on failure. }
    //function LoadCellMLFile(const AFilename: string): LongInt;

    { Load a string in CellML format.
      Raises EAntimonyError on failure. }
    //function LoadCellMLString(const AModel: string): LongInt;

    { Returns the number of file/string sets currently held in memory. }
    function GetNumFiles: Cardinal;

    { Makes the module set at the given load index active.
      Returns True on success, False otherwise. }
    function RevertTo(AIndex: LongInt): Boolean;

    { Clears all loaded files/strings from memory. }
    procedure ClearPreviousLoads;

    { Adds a directory to the search path used when resolving imported files. }
    procedure AddDirectory(const ADirectory: string);

    { Clears all directories added with AddDirectory. }
    procedure ClearDirectories;

    // ======================================================================
    //  OUTPUT
    // ======================================================================

    { Write an Antimony-formatted file for the named module.
      Returns True on success, False on failure. }
    function WriteAntimonyFile(const AFilename,
      AModuleName: string): Boolean;

    { Returns the Antimony representation of the named module as a string.
      Raises EAntimonyError on failure. }
    function GetAntimonyString(const AModuleName: string): string;

    { Write a flattened SBML file for the named module.
      Returns True on success, False on failure. }
    function WriteSBMLFile(const AFilename, AModuleName: string): Boolean;

    { Returns the flattened SBML XML for the named module as a string.
      Raises EAntimonyError on failure. }
    function GetSBMLString(const AModuleName: string): string;

    { Write a hierarchical (Hierarchical Model Composition) SBML file for the
      named module.  Returns True on success, False on failure. }
    function WriteCompSBMLFile(const AFilename, AModuleName: string): Boolean;

    { Returns the hierarchical SBML XML for the named module as a string.
      Raises EAntimonyError on failure. }
    function GetCompSBMLString(const AModuleName: string): string;

    { Write a CellML file for the named module.
      Returns True on success, False on failure. }
    //function WriteCellMLFile(const AFilename, AModuleName: string): Boolean;

    { Returns the CellML representation of the named module as a string.
      Raises EAntimonyError on failure. }
    //function GetCellMLString(const AModuleName: string): string;

    { Prints all stored data for the named module to stdout.
      Intended as a diagnostic / example output. }
    procedure PrintAllDataFor(const AModuleName: string);

    // ======================================================================
    //  ERRORS AND WARNINGS
    // ======================================================================

    { Returns True when the named module exists in the current active set. }
    function CheckModule(const AModuleName: string): Boolean;

    { Returns the most recent error message set by libAntimony ('' if none). }
    function GetLastError: string;

    { Returns translation warnings accumulated since the last load ('' if none). }
    function GetWarnings: string;

    { Returns libSBML 'info' messages for the named module ('' if none). }
    function GetSBMLInfoMessages(const AModuleName: string): string;

    { Returns libSBML 'warning' messages for the named module ('' if none). }
    function GetSBMLWarnings(const AModuleName: string): string;

    // ======================================================================
    //  MODULES
    // ======================================================================

    { Returns the number of modules in the currently active set. }
    function GetNumModules: Cardinal;

    { Returns the names of all modules in the currently active set. }
    function GetModuleNames: TArray<string>;

    { Returns the name of the Nth module (0-based).
      Raises EAntimonyError when N is out of range. }
    function GetNthModuleName(N: Cardinal): string;

    { Returns the name of the top-level ('main') module.
      Raises EAntimonyError when no modules are loaded. }
    function GetMainModuleName: string;

    // ======================================================================
    //  MODULE INTERFACE
    // ======================================================================

    { Returns the number of symbols in the interface of the named module.
      e.g. 'module M(x, y, z)' → 3. }
    function GetNumSymbolsInInterfaceOf(const AModuleName: string): Cardinal;

    { Returns the list of interface symbol names for the named module. }
    function GetSymbolNamesInInterfaceOf(
      const AModuleName: string): TArray<string>;

    { Returns the Nth interface symbol name (0-based).
      Raises EAntimonyError when N is out of range. }
    function GetNthSymbolNameInInterfaceOf(const AModuleName: string;
      N: Cardinal): string;

    // ======================================================================
    //  REPLACEMENTS  (symbol synchronisation via 'is')
    // ======================================================================

    { Returns the number of symbol-synchronisation (replacement) pairs in the
      named module. }
    function GetNumReplacedSymbolNames(const AModuleName: string): Cardinal;

    { Returns all replacement pairs for the named module. }
    function GetAllReplacementSymbolPairs(
      const AModuleName: string): TArray<TSymbolPair>;

    { Returns the Nth replacement pair (0-based). }
    function GetNthReplacementSymbolPair(const AModuleName: string;
      N: Cardinal): TSymbolPair;

    { Returns the Nth former (replaced) symbol name (0-based). }
    function GetNthFormerSymbolName(const AModuleName: string;
      N: Cardinal): string;

    { Returns the Nth replacement symbol name (0-based). }
    function GetNthReplacementSymbolName(const AModuleName: string;
      N: Cardinal): string;

    { Returns the number of replacement pairs between two named sub-modules. }
    function GetNumReplacedSymbolNamesBetween(const AModuleName,
      AFormerSubmodName, AReplacementSubmodName: string): Cardinal;

    { Returns all replacement pairs between two named sub-modules. }
    function GetAllReplacementSymbolPairsBetween(const AModuleName,
      AFormerSubmodName, AReplacementSubmodName: string;
      N: Cardinal): TArray<TSymbolPair>;

    { Returns the Nth replacement pair between two named sub-modules. }
    function GetNthReplacementSymbolPairBetween(const AModuleName,
      AFormerSubmodName, AReplacementSubmodName: string;
      N: Cardinal): TSymbolPair;

    { Returns the Nth former symbol name between two named sub-modules. }
    function GetNthFormerSymbolNameBetween(const AModuleName,
      AFormerSubmodName, AReplacementSubmodName: string;
      N: Cardinal): string;

    { Returns the Nth replacement symbol name between two named sub-modules. }
    function GetNthReplacementSymbolNameBetween(const AModuleName,
      AFormerSubmodName, AReplacementSubmodName: string;
      N: Cardinal): string;

    // ======================================================================
    //  SYMBOLS AND SYMBOL INFORMATION
    // ======================================================================

    { Returns the number of symbols of the given return type in the module. }
    function GetNumSymbolsOfType(const AModuleName: string;
      ARType: TReturnType): Cardinal;

    { Returns the names (SBML 'id') of all symbols of the given type. }
    function GetSymbolNamesOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the display names (SBML 'name' attribute) of all symbols of the
      given type. }
    function GetSymbolDisplayNamesOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the equations / initial values for all symbols of the given type.
      An empty string means no equation is set for that symbol. }
    function GetSymbolEquationsOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the initial-assignment equations for all symbols of the given type. }
    function GetSymbolInitialAssignmentsOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the assignment-rule equations for all symbols of the given type. }
    function GetSymbolAssignmentRulesOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the rate-rule equations for all symbols of the given type. }
    function GetSymbolRateRulesOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the compartment names for all symbols of the given type. }
    function GetSymbolCompartmentsOfType(const AModuleName: string;
      ARType: TReturnType): TArray<string>;

    { Returns the name (SBML 'id') of the Nth symbol of the given type (0-based).
      Raises EAntimonyError when not found. }
    function GetNthSymbolNameOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the display name (SBML 'name') of the Nth symbol of the given type.
      Raises EAntimonyError when not found. }
    function GetNthSymbolDisplayNameOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the equation / initial value of the Nth symbol of the given type.
      Returns '' when no equation is set; raises EAntimonyError when not found. }
    function GetNthSymbolEquationOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the initial assignment of the Nth symbol of the given type.
      Returns '' when none is set; raises EAntimonyError when not found. }
    function GetNthSymbolInitialAssignmentOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the assignment rule of the Nth symbol of the given type.
      Returns '' when none is set; raises EAntimonyError when not found. }
    function GetNthSymbolAssignmentRuleOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the rate rule of the Nth symbol of the given type.
      Returns '' when none is set; raises EAntimonyError when not found. }
    function GetNthSymbolRateRuleOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the compartment of the Nth symbol of the given type.
      Returns 'default_compartment' when not explicitly set.
      Raises EAntimonyError when not found. }
    function GetNthSymbolCompartmentOfType(const AModuleName: string;
      ARType: TReturnType; N: Cardinal): string;

    { Returns the most specific TReturnType available for the named symbol. }
    function GetTypeOfSymbol(const AModuleName,
      ASymbolName: string): TReturnType;

    { Returns the TFormulaType that characterises the named symbol's equation
      (initial assignment, assignment rule, rate rule, or plain value). }
    function GetTypeOfEquationForSymbol(const AModuleName,
      ASymbolName: string): TFormulaType;

    { Returns the compartment that the named symbol belongs to.
      Returns 'default_compartment' when not explicitly set. }
    function GetCompartmentForSymbol(const AModuleName,
      ASymbolName: string): string;

    // ======================================================================
    //  REACTIONS
    // ======================================================================

    { Returns the number of reactions (including gene reactions) in the module. }
    function GetNumReactions(const AModuleName: string): Cardinal;

    { Returns the number of reactants for the Nth reaction (0-based). }
    function GetNumReactants(const AModuleName: string;
      ARxn: Cardinal): Cardinal;

    { Returns the number of products for the Nth reaction (0-based). }
    function GetNumProducts(const AModuleName: string;
      ARxn: Cardinal): Cardinal;

    { Returns all reactant-name arrays for all reactions.
      Result[i] is the array of reactant names for reaction i. }
    function GetReactantNames(
      const AModuleName: string): TArray<TArray<string>>;

    { Returns the reactant names for the Nth reaction (0-based). }
    function GetNthReactionReactantNames(const AModuleName: string;
      ARxn: Cardinal): TArray<string>;

    { Returns the name of the Mth reactant of the Nth reaction (both 0-based).
      Raises EAntimonyError when not found. }
    function GetNthReactionMthReactantName(const AModuleName: string;
      ARxn, AReactant: Cardinal): string;

    { Returns all product-name arrays for all reactions.
      Result[i] is the array of product names for reaction i. }
    function GetProductNames(
      const AModuleName: string): TArray<TArray<string>>;

    { Returns the product names for the Nth reaction (0-based). }
    function GetNthReactionProductNames(const AModuleName: string;
      ARxn: Cardinal): TArray<string>;

    { Returns the name of the Mth product of the Nth reaction (both 0-based).
      Raises EAntimonyError when not found. }
    function GetNthReactionMthProductName(const AModuleName: string;
      ARxn, AProduct: Cardinal): string;

    { Returns all reactant-stoichiometry arrays for all reactions.
      Result[i][j] is the stoichiometry of the jth reactant of reaction i. }
    function GetReactantStoichiometries(
      const AModuleName: string): TArray<TArray<Double>>;

    { Returns all product-stoichiometry arrays for all reactions.
      Result[i][j] is the stoichiometry of the jth product of reaction i. }
    function GetProductStoichiometries(
      const AModuleName: string): TArray<TArray<Double>>;

    { Returns the reactant stoichiometries for the Nth reaction. }
    function GetNthReactionReactantStoichiometries(const AModuleName: string;
      ARxn: Cardinal): TArray<Double>;

    { Returns the product stoichiometries for the Nth reaction. }
    function GetNthReactionProductStoichiometries(const AModuleName: string;
      ARxn: Cardinal): TArray<Double>;

    { Returns the stoichiometry of the Mth reactant of the Nth reaction.
      Returns 0 (and sets an error) when not found. }
    function GetNthReactionMthReactantStoichiometry(const AModuleName: string;
      ARxn, AReactant: Cardinal): Double;

    { Returns the stoichiometry of the Mth product of the Nth reaction.
      Returns 0 (and sets an error) when not found. }
    function GetNthReactionMthProductStoichiometry(const AModuleName: string;
      ARxn, AProduct: Cardinal): Double;

    // ======================================================================
    //  INTERACTIONS
    // ======================================================================

    { Returns the number of interactions in the module. }
    function GetNumInteractions(const AModuleName: string): Cardinal;

    { Returns the number of interactors (LHS species) for interaction Rxn (0-based). }
    function GetNumInteractors(const AModuleName: string;
      ARxn: Cardinal): Cardinal;

    { Returns the number of interactees (RHS reactions) for interaction Rxn (0-based). }
    function GetNumInteractees(const AModuleName: string;
      ARxn: Cardinal): Cardinal;

    { Returns all interactor-name arrays for all interactions.
      Result[i] is the array of interactor names for interaction i. }
    function GetInteractorNames(
      const AModuleName: string): TArray<TArray<string>>;

    { Returns the interactor names for interaction Rxn (0-based). }
    function GetNthInteractionInteractorNames(const AModuleName: string;
      ARxn: Cardinal): TArray<string>;

    { Returns the name of the Mth interactor of the given interaction (both 0-based).
      Raises EAntimonyError when not found. }
    function GetNthInteractionMthInteractorName(const AModuleName: string;
      AInteraction, AInteractor: Cardinal): string;

    { Returns all interactee-name arrays for all interactions.
      Result[i] is the array of interactee names for interaction i. }
    function GetInteracteeNames(
      const AModuleName: string): TArray<TArray<string>>;

    { Returns the interactee names for interaction Rxn (0-based). }
    function GetNthInteractionInteracteeNames(const AModuleName: string;
      ARxn: Cardinal): TArray<string>;

    { Returns the name of the Mth interactee of the given interaction (both 0-based).
      Raises EAntimonyError when not found. }
    function GetNthInteractionMthInteracteeName(const AModuleName: string;
      AInteraction, AInteractee: Cardinal): string;

    { Returns the interaction-divider type for every interaction in the module.
      Length = GetNumInteractions. }
    function GetInteractionDividers(
      const AModuleName: string): TArray<TRdType>;

    { Returns the interaction-divider type for the Nth interaction (0-based). }
    function GetNthInteractionDivider(const AModuleName: string;
      N: Cardinal): TRdType;

    // ======================================================================
    //  STOICHIOMETRY MATRIX
    // ======================================================================

    { Returns the N × M stoichiometry matrix where N = variable-species count
      and M = reaction count.
      Result[i] is row i (variable species i); Result[i][j] is column j
      (reaction j).  Equivalent to the standard N_r matrix. }
    function GetStoichiometryMatrix(
      const AModuleName: string): TArray<TArray<Double>>;

    { Returns the row labels (variable-species names) for the stoichiometry
      matrix. }
    function GetStoichiometryMatrixRowLabels(
      const AModuleName: string): TArray<string>;

    { Returns the column labels (reaction names) for the stoichiometry matrix. }
    function GetStoichiometryMatrixColumnLabels(
      const AModuleName: string): TArray<string>;

    { Returns the number of rows (= variable-species count) in the stoichiometry
      matrix. }
    function GetStoichiometryMatrixNumRows(
      const AModuleName: string): Cardinal;

    { Returns the number of columns (= reaction count) in the stoichiometry
      matrix. }
    function GetStoichiometryMatrixNumColumns(
      const AModuleName: string): Cardinal;

    { Returns the number of reactions (= reaction-rates count) in the module.
      Equivalent to GetStoichiometryMatrixNumColumns. }
    function GetNumReactionRates(const AModuleName: string): Cardinal;

    { Returns the reaction-rate formula strings for all reactions in the module.
      Equivalent to GetSymbolEquationsOfType(AModuleName, allReactions). }
    function GetReactionRates(const AModuleName: string): TArray<string>;

    { Returns the reaction-rate formula string for the Nth reaction (0-based).
      Returns '' when the rate is not set.
      Raises EAntimonyError when the reaction does not exist. }
    function GetNthReactionRate(const AModuleName: string;
      ARxn: Cardinal): string;

    // ======================================================================
    //  EVENTS
    // ======================================================================

    { Returns the number of events in the module. }
    function GetNumEvents(const AModuleName: string): Cardinal;

    { Returns the names of all events in the module. }
    function GetEventNames(const AModuleName: string): TArray<string>;

    { Returns the name of the Nth event (0-based). }
    function GetNthEventName(const AModuleName: string;
      AEvent: Cardinal): string;

    { Returns the number of variable-assignment pairs inside the given event. }
    function GetNumAssignmentsForEvent(const AModuleName: string;
      AEvent: Cardinal): Cardinal;

    { Returns the trigger condition (boolean equation) for the given event.
      Raises EAntimonyError when the event does not exist. }
    function GetTriggerForEvent(const AModuleName: string;
      AEvent: Cardinal): string;

    { Returns the delay equation for the given event, or '' when there is none.
      Raises EAntimonyError when the module or event does not exist. }
    function GetDelayForEvent(const AModuleName: string;
      AEvent: Cardinal): string;

    { Returns True when the given event has a delay. }
    function GetEventHasDelay(const AModuleName: string;
      AEvent: Cardinal): Boolean;

    { Returns the priority equation for the given event, or '' when there is
      none.  Raises EAntimonyError when the module or event does not exist. }
    function GetPriorityForEvent(const AModuleName: string;
      AEvent: Cardinal): string;

    { Returns True when the given event has a priority. }
    function GetEventHasPriority(const AModuleName: string;
      AEvent: Cardinal): Boolean;

    { Returns the value of the persistence flag for the given event
      (SBML default: False). }
    function GetPersistenceForEvent(const AModuleName: string;
      AEvent: Cardinal): Boolean;

    { Returns the initial trigger value (T0) for the given event
      (SBML default: True). }
    function GetT0ForEvent(const AModuleName: string;
      AEvent: Cardinal): Boolean;

    { Returns the 'fromTrigger' flag for the given event trigger
      (SBML default: True). }
    function GetFromTriggerForEvent(const AModuleName: string;
      AEvent: Cardinal): Boolean;

    { Returns the variable name targeted by the Nth assignment in the given
      event (both 0-based). }
    function GetNthAssignmentVariableForEvent(const AModuleName: string;
      AEvent, N: Cardinal): string;

    { Returns the formula string for the Nth assignment in the given event. }
    function GetNthAssignmentEquationForEvent(const AModuleName: string;
      AEvent, N: Cardinal): string;

    // ======================================================================
    //  DNA STRANDS
    // ======================================================================

    { Returns the number of unique expanded DNA strands in the module. }
    function GetNumDNAStrands(const AModuleName: string): Cardinal;

    { Returns the component count for each expanded DNA strand.
      Length = GetNumDNAStrands. }
    function GetDNAStrandSizes(const AModuleName: string): TArray<Cardinal>;

    { Returns the component count of the Nth expanded DNA strand (0-based). }
    function GetSizeOfNthDNAStrand(const AModuleName: string;
      N: Cardinal): Cardinal;

    { Returns all expanded DNA strands as arrays of component-name strings.
      Result[i] is the component-name list of the ith strand. }
    function GetDNAStrands(const AModuleName: string): TArray<TArray<string>>;

    { Returns the component names in the Nth expanded DNA strand (0-based). }
    function GetNthDNAStrand(const AModuleName: string;
      N: Cardinal): TArray<string>;

    { Returns True when the Nth expanded DNA strand has an open (attachable)
      end at the upstream (AUpstream=True) or downstream (AUpstream=False) end. }
    function GetIsNthDNAStrandOpen(const AModuleName: string;
      N: Cardinal; AUpstream: Boolean): Boolean;

    { Returns the number of modular (separately-defined) DNA strands. }
    function GetNumModularDNAStrands(const AModuleName: string): Cardinal;

    { Returns the component count for each modular DNA strand.
      Length = GetNumModularDNAStrands. }
    function GetModularDNAStrandSizes(
      const AModuleName: string): TArray<Cardinal>;

    { Returns all modular DNA strands as arrays of component-name strings.
      Result[i] is the component-name list of the ith modular strand. }
    function GetModularDNAStrands(
      const AModuleName: string): TArray<TArray<string>>;

    { Returns the component names in the Nth modular DNA strand (0-based). }
    function GetNthModularDNAStrand(const AModuleName: string;
      N: Cardinal): TArray<string>;

    { Returns True when the Nth modular DNA strand has an open end at the
      upstream (AUpstream=True) or downstream (AUpstream=False) end. }
    function GetIsNthModularDNAStrandOpen(const AModuleName: string;
      N: Cardinal; AUpstream: Boolean): Boolean;

    // ======================================================================
    //  DEFAULTS
    // ======================================================================

    { Adds default initial values to the named module:
        parameters and compartments → 1.0
        species and reaction rates  → 0.0
      Returns True when no such module exists, False on success. }
    function AddDefaultInitialValues(const AModuleName: string): Boolean;

    { Set whether bare numbers in the model are dimensionless (True) or
      of undefined units (False). }
    procedure SetBareNumbersAreDimensionless(ADimensionless: Boolean);

  end; // TAntimony

// ===========================================================================
implementation
// ===========================================================================

{ TSymbolPair }

class function TSymbolPair.Make(const AFormer,
  AReplacement: string): TSymbolPair;
begin
  Result.Former      := AFormer;
  Result.Replacement := AReplacement;
end;

{ TAntimony – private helpers }

function TAntimony.CStr(p: PAnsiChar): string;
begin
  if p = nil then
    Result := ''
  else
    Result := string(AnsiString(p));
end;

function TAntimony.CStrArr(pp: PPAnsiChar; ACount: Integer): TArray<string>;
var
  i  : Integer;
  Ptr: PPAnsiChar;
begin
  SetLength(Result, ACount);
  if (pp = nil) or (ACount <= 0) then
    Exit;
  Ptr := pp;
  for i := 0 to ACount - 1 do
  begin
    Result[i] := CStr(Ptr^);
    Inc(Ptr);
  end;
end;

function TAntimony.CStr2DArr(ppp: PPPAnsiChar;
  const ACounts: TArray<Integer>): TArray<TArray<string>>;
var
  i       : Integer;
  OuterPtr: PPPAnsiChar;
begin
  SetLength(Result, Length(ACounts));
  if ppp = nil then
    Exit;
  OuterPtr := ppp;
  for i := 0 to High(ACounts) do
  begin
    Result[i] := CStrArr(OuterPtr^, ACounts[i]);
    Inc(OuterPtr);
  end;
end;

function TAntimony.CDblArr(pd: PDouble; ACount: Integer): TArray<Double>;
var
  i  : Integer;
  Ptr: PDouble;
begin
  SetLength(Result, ACount);
  if (pd = nil) or (ACount <= 0) then
    Exit;
  Ptr := pd;
  for i := 0 to ACount - 1 do
  begin
    Result[i] := Ptr^;
    Inc(Ptr);
  end;
end;

function TAntimony.CDbl2DArr(ppd: PPDouble;
  const ACounts: TArray<Integer>): TArray<TArray<Double>>;
var
  i       : Integer;
  OuterPtr: PPDouble;
begin
  SetLength(Result, Length(ACounts));
  if ppd = nil then
    Exit;
  OuterPtr := ppd;
  for i := 0 to High(ACounts) do
  begin
    Result[i] := CDblArr(OuterPtr^, ACounts[i]);
    Inc(OuterPtr);
  end;
end;

function TAntimony.CCardArr(pc: PCardinal; ACount: Integer): TArray<Cardinal>;
var
  i  : Integer;
  Ptr: PCardinal;
begin
  SetLength(Result, ACount);
  if (pc = nil) or (ACount <= 0) then
    Exit;
  Ptr := pc;
  for i := 0 to ACount - 1 do
  begin
    Result[i] := Ptr^;
    Inc(Ptr);
  end;
end;

function TAntimony.CPairToSymbolPair(pp: PPAnsiChar;
  const AContext: string): TSymbolPair;
var
  Ptr: PPAnsiChar;
begin
  CheckPtr(pp, AContext);
  Ptr                := pp;
  Result.Former      := CStr(Ptr^);
  Inc(Ptr);
  Result.Replacement := CStr(Ptr^);
end;

procedure TAntimony.CheckLoad(AResult: LongInt; const AContext: string);
begin
  if AResult < 0 then
    raise EAntimonyError.CreateFmt('Antimony error in %s: %s',
      [AContext, CStr(AntimonyAPI.getLastError)]);
end;

procedure TAntimony.CheckPtr(APtr: Pointer; const AContext: string);
begin
  if APtr = nil then
    raise EAntimonyError.CreateFmt('Antimony error in %s: %s',
      [AContext, CStr(AntimonyAPI.getLastError)]);
end;

function TAntimony.UniformCounts(ACount, AValue: Integer): TArray<Integer>;
var
  i: Integer;
begin
  SetLength(Result, ACount);
  for i := 0 to ACount - 1 do
    Result[i] := AValue;
end;

function TAntimony.ReactionInnerCounts(const AModuleName: AnsiString;
  ANumItems: Cardinal;
  AGetCount: TCountByIndexFn): TArray<Integer>;
var
  i: Integer;
begin
  SetLength(Result, ANumItems);
  for i := 0 to Integer(ANumItems) - 1 do
    Result[i] := Integer(AGetCount(PAnsiChar(AModuleName), Cardinal(i)));
end;

{ TAntimony – public }

destructor TAntimony.Destroy;
begin
  AntimonyAPI.freeAll;
  inherited;
end;

procedure TAntimony.FreeAllAllocations;
begin
  AntimonyAPI.freeAll;
end;

// ============================================================================
//  INPUT
// ============================================================================

function TAntimony.LoadFile(const AFilename: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AFilename);
  Result := AntimonyAPI.loadFile(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadFile');
end;

function TAntimony.LoadString(const AModel: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AModel);
  Result := AntimonyAPI.loadString(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadString');
end;

function TAntimony.LoadAntimonyFile(const AFilename: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AFilename);
  Result := AntimonyAPI.loadAntimonyFile(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadAntimonyFile');
end;

function TAntimony.LoadAntimonyString(const AModel: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AModel);
  Result := AntimonyAPI.loadAntimonyString(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadAntimonyString');
end;

function TAntimony.LoadSBMLFile(const AFilename: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AFilename);
  Result := AntimonyAPI.loadSBMLFile(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadSBMLFile');
end;

function TAntimony.LoadSBMLString(const AModel: string): LongInt;
var
  aStr: AnsiString;
begin
  aStr   := AnsiString(AModel);
  Result := AntimonyAPI.loadSBMLString(PAnsiChar(aStr));
  CheckLoad(Result, 'LoadSBMLString');
end;

function TAntimony.LoadSBMLStringWithLocation(const AModel,
  ALocation: string): LongInt;
var
  aCModel, aCLoc: AnsiString;
begin
  aCModel := AnsiString(AModel);
  aCLoc   := AnsiString(ALocation);
  Result  := AntimonyAPI.loadSBMLStringWithLocation(
               PAnsiChar(aCModel), PAnsiChar(aCLoc));
  CheckLoad(Result, 'LoadSBMLStringWithLocation');
end;

//function TAntimony.LoadCellMLFile(const AFilename: string): LongInt;
//var
//  aStr: AnsiString;
//begin
//  aStr   := AnsiString(AFilename);
//  Result := AntimonyAPI.loadCellMLFile(PAnsiChar(aStr));
//  CheckLoad(Result, 'LoadCellMLFile');
//end;

//function TAntimony.LoadCellMLString(const AModel: string): LongInt;
//var
//  aStr: AnsiString;
//begin
//  aStr   := AnsiString(AModel);
//  Result := AntimonyAPI.loadCellMLString(PAnsiChar(aStr));
//  CheckLoad(Result, 'LoadCellMLString');
//end;

function TAntimony.GetNumFiles: Cardinal;
begin
  Result := AntimonyAPI.getNumFiles;
end;

function TAntimony.RevertTo(AIndex: LongInt): Boolean;
begin
  Result := AntimonyAPI.revertTo(AIndex);
end;

procedure TAntimony.ClearPreviousLoads;
begin
  AntimonyAPI.clearPreviousLoads;
end;

procedure TAntimony.AddDirectory(const ADirectory: string);
var
  aStr: AnsiString;
begin
  aStr := AnsiString(ADirectory);
  AntimonyAPI.addDirectory(PAnsiChar(aStr));
end;

procedure TAntimony.ClearDirectories;
begin
  AntimonyAPI.clearDirectories;
end;

// ============================================================================
//  OUTPUT
// ============================================================================

function TAntimony.WriteAntimonyFile(const AFilename,
  AModuleName: string): Boolean;
var
  aFN, aMN: AnsiString;
begin
  aFN    := AnsiString(AFilename);
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.writeAntimonyFile(PAnsiChar(aFN), PAnsiChar(aMN)) <> 0;
end;

function TAntimony.GetAntimonyString(const AModuleName: string): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getAntimonyString(PAnsiChar(aMN));
  CheckPtr(p, 'GetAntimonyString');
  Result := CStr(p);
end;

function TAntimony.WriteSBMLFile(const AFilename, AModuleName: string): Boolean;
var
  aFN, aMN: AnsiString;
begin
  aFN    := AnsiString(AFilename);
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.writeSBMLFile(PAnsiChar(aFN), PAnsiChar(aMN)) <> 0;
end;

function TAntimony.GetSBMLString(const AModuleName: string): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getSBMLString(PAnsiChar(aMN));
  CheckPtr(p, 'GetSBMLString');
  Result := CStr(p);
end;

function TAntimony.WriteCompSBMLFile(const AFilename,
  AModuleName: string): Boolean;
var
  aFN, aMN: AnsiString;
begin
  aFN    := AnsiString(AFilename);
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.writeCompSBMLFile(PAnsiChar(aFN), PAnsiChar(aMN)) <> 0;
end;

function TAntimony.GetCompSBMLString(const AModuleName: string): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getCompSBMLString(PAnsiChar(aMN));
  CheckPtr(p, 'GetCompSBMLString');
  Result := CStr(p);
end;

//function TAntimony.WriteCellMLFile(const AFilename,
//  AModuleName: string): Boolean;
//var
//  aFN, aMN: AnsiString;
//begin
//  aFN    := AnsiString(AFilename);
//  aMN    := AnsiString(AModuleName);
//  Result := AntimonyAPI.writeCellMLFile(PAnsiChar(aFN), PAnsiChar(aMN)) <> 0;
//end;

//function TAntimony.GetCellMLString(const AModuleName: string): string;
//var
//  aMN: AnsiString;
//  p  : PAnsiChar;
//begin
//  aMN := AnsiString(AModuleName);
//  p   := AntimonyAPI.getCellMLString(PAnsiChar(aMN));
//  CheckPtr(p, 'GetCellMLString');
//  Result := CStr(p);
//end;

procedure TAntimony.PrintAllDataFor(const AModuleName: string);
var
  aMN: AnsiString;
begin
  aMN := AnsiString(AModuleName);
  AntimonyAPI.printAllDataFor(PAnsiChar(aMN));
end;

// ============================================================================
//  ERRORS AND WARNINGS
// ============================================================================

function TAntimony.CheckModule(const AModuleName: string): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.checkModule(PAnsiChar(aMN));
end;

function TAntimony.GetLastError: string;
begin
  Result := CStr(AntimonyAPI.getLastError);
end;

function TAntimony.GetWarnings: string;
begin
  Result := CStr(AntimonyAPI.getWarnings);
end;

function TAntimony.GetSBMLInfoMessages(const AModuleName: string): string;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStr(AntimonyAPI.getSBMLInfoMessages(PAnsiChar(aMN)));
end;

function TAntimony.GetSBMLWarnings(const AModuleName: string): string;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStr(AntimonyAPI.getSBMLWarnings(PAnsiChar(aMN)));
end;

// ============================================================================
//  MODULES
// ============================================================================

function TAntimony.GetNumModules: Cardinal;
begin
  Result := AntimonyAPI.getNumModules;
end;

function TAntimony.GetModuleNames: TArray<string>;
var
  pp: PPAnsiChar;
begin
  pp     := AntimonyAPI.getModuleNames;
  Result := CStrArr(pp, Integer(AntimonyAPI.getNumModules));
end;

function TAntimony.GetNthModuleName(N: Cardinal): string;
var
  p: PAnsiChar;
begin
  p := AntimonyAPI.getNthModuleName(N);
  CheckPtr(p, 'GetNthModuleName');
  Result := CStr(p);
end;

function TAntimony.GetMainModuleName: string;
var
  p: PAnsiChar;
begin
  p := AntimonyAPI.getMainModuleName;
  CheckPtr(p, 'GetMainModuleName');
  Result := CStr(p);
end;

// ============================================================================
//  MODULE INTERFACE
// ============================================================================

function TAntimony.GetNumSymbolsInInterfaceOf(
  const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumSymbolsInInterfaceOf(PAnsiChar(aMN));
end;

function TAntimony.GetSymbolNamesInInterfaceOf(
  const AModuleName: string): TArray<string>;
var
  aMN: AnsiString;
  pp : PPAnsiChar;
begin
  aMN    := AnsiString(AModuleName);
  pp     := AntimonyAPI.getSymbolNamesInInterfaceOf(PAnsiChar(aMN));
  Result := CStrArr(pp,
              Integer(AntimonyAPI.getNumSymbolsInInterfaceOf(PAnsiChar(aMN))));
end;

function TAntimony.GetNthSymbolNameInInterfaceOf(const AModuleName: string;
  N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolNameInInterfaceOf(PAnsiChar(aMN), N);
  CheckPtr(p, 'GetNthSymbolNameInInterfaceOf');
  Result := CStr(p);
end;

// ============================================================================
//  REPLACEMENTS
// ============================================================================

function TAntimony.GetNumReplacedSymbolNames(
  const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumReplacedSymbolNames(PAnsiChar(aMN));
end;

function TAntimony.GetAllReplacementSymbolPairs(
  const AModuleName: string): TArray<TSymbolPair>;
var
  aMN   : AnsiString;
  ppp   : PPPAnsiChar;
  nPairs: Cardinal;
  pp2D  : TArray<TArray<string>>;
  i     : Integer;
begin
  aMN    := AnsiString(AModuleName);
  nPairs := AntimonyAPI.getNumReplacedSymbolNames(PAnsiChar(aMN));
  ppp    := AntimonyAPI.getAllReplacementSymbolPairs(PAnsiChar(aMN));
  SetLength(Result, nPairs);
  if (nPairs = 0) or (ppp = nil) then
    Exit;
  // Each inner pair has exactly 2 strings: [former, replacement]
  pp2D := CStr2DArr(ppp, UniformCounts(Integer(nPairs), 2));
  for i := 0 to Integer(nPairs) - 1 do
    Result[i] := TSymbolPair.Make(pp2D[i][0], pp2D[i][1]);
end;

function TAntimony.GetNthReplacementSymbolPair(const AModuleName: string;
  N: Cardinal): TSymbolPair;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CPairToSymbolPair(
              AntimonyAPI.getNthReplacementSymbolPair(PAnsiChar(aMN), N),
              'GetNthReplacementSymbolPair');
end;

function TAntimony.GetNthFormerSymbolName(const AModuleName: string;
  N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthFormerSymbolName(PAnsiChar(aMN), N);
  CheckPtr(p, 'GetNthFormerSymbolName');
  Result := CStr(p);
end;

function TAntimony.GetNthReplacementSymbolName(const AModuleName: string;
  N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthReplacementSymbolName(PAnsiChar(aMN), N);
  CheckPtr(p, 'GetNthReplacementSymbolName');
  Result := CStr(p);
end;

function TAntimony.GetNumReplacedSymbolNamesBetween(const AModuleName,
  AFormerSubmodName, AReplacementSubmodName: string): Cardinal;
var
  aMN, aFSN, aRSN: AnsiString;
begin
  aMN  := AnsiString(AModuleName);
  aFSN := AnsiString(AFormerSubmodName);
  aRSN := AnsiString(AReplacementSubmodName);
  Result := AntimonyAPI.getNumReplacedSymbolNamesBetween(
              PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN));
end;

function TAntimony.GetAllReplacementSymbolPairsBetween(const AModuleName,
  AFormerSubmodName, AReplacementSubmodName: string;
  N: Cardinal): TArray<TSymbolPair>;
var
  aMN, aFSN, aRSN: AnsiString;
  ppp            : PPPAnsiChar;
  nPairs         : Cardinal;
  pp2D           : TArray<TArray<string>>;
  i              : Integer;
begin
  aMN    := AnsiString(AModuleName);
  aFSN   := AnsiString(AFormerSubmodName);
  aRSN   := AnsiString(AReplacementSubmodName);
  nPairs := AntimonyAPI.getNumReplacedSymbolNamesBetween(
              PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN));
  ppp := AntimonyAPI.getAllReplacementSymbolPairsBetween(
           PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN), N);
  SetLength(Result, nPairs);
  if (nPairs = 0) or (ppp = nil) then
    Exit;
  pp2D := CStr2DArr(ppp, UniformCounts(Integer(nPairs), 2));
  for i := 0 to Integer(nPairs) - 1 do
    Result[i] := TSymbolPair.Make(pp2D[i][0], pp2D[i][1]);
end;

function TAntimony.GetNthReplacementSymbolPairBetween(const AModuleName,
  AFormerSubmodName, AReplacementSubmodName: string;
  N: Cardinal): TSymbolPair;
var
  aMN, aFSN, aRSN: AnsiString;
begin
  aMN  := AnsiString(AModuleName);
  aFSN := AnsiString(AFormerSubmodName);
  aRSN := AnsiString(AReplacementSubmodName);
  Result := CPairToSymbolPair(
              AntimonyAPI.getNthReplacementSymbolPairBetween(
                PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN), N),
              'GetNthReplacementSymbolPairBetween');
end;

function TAntimony.GetNthFormerSymbolNameBetween(const AModuleName,
  AFormerSubmodName, AReplacementSubmodName: string;
  N: Cardinal): string;
var
  aMN, aFSN, aRSN: AnsiString;
  p              : PAnsiChar;
begin
  aMN  := AnsiString(AModuleName);
  aFSN := AnsiString(AFormerSubmodName);
  aRSN := AnsiString(AReplacementSubmodName);
  p    := AntimonyAPI.getNthFormerSymbolNameBetween(
            PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN), N);
  CheckPtr(p, 'GetNthFormerSymbolNameBetween');
  Result := CStr(p);
end;

function TAntimony.GetNthReplacementSymbolNameBetween(const AModuleName,
  AFormerSubmodName, AReplacementSubmodName: string;
  N: Cardinal): string;
var
  aMN, aFSN, aRSN: AnsiString;
  p              : PAnsiChar;
begin
  aMN  := AnsiString(AModuleName);
  aFSN := AnsiString(AFormerSubmodName);
  aRSN := AnsiString(AReplacementSubmodName);
  p    := AntimonyAPI.getNthReplacementSymbolNameBetween(
            PAnsiChar(aMN), PAnsiChar(aFSN), PAnsiChar(aRSN), N);
  CheckPtr(p, 'GetNthReplacementSymbolNameBetween');
  Result := CStr(p);
end;

// ============================================================================
//  SYMBOLS AND SYMBOL INFORMATION
// ============================================================================

function TAntimony.GetNumSymbolsOfType(const AModuleName: string;
  ARType: TReturnType): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType);
end;

function TAntimony.GetSymbolNamesOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolNamesOfType(PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolDisplayNamesOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolDisplayNamesOfType(PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolEquationsOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolEquationsOfType(PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolInitialAssignmentsOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolInitialAssignmentsOfType(
                PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolAssignmentRulesOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolAssignmentRulesOfType(
                PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolRateRulesOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolRateRulesOfType(PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetSymbolCompartmentsOfType(const AModuleName: string;
  ARType: TReturnType): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getSymbolCompartmentsOfType(PAnsiChar(aMN), ARType),
              Integer(AntimonyAPI.getNumSymbolsOfType(PAnsiChar(aMN), ARType)));
end;

function TAntimony.GetNthSymbolNameOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolNameOfType(PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolNameOfType');
  Result := CStr(p);
end;

function TAntimony.GetNthSymbolDisplayNameOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolDisplayNameOfType(PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolDisplayNameOfType');
  Result := CStr(p);
end;

function TAntimony.GetNthSymbolEquationOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolEquationOfType(PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolEquationOfType');
  Result := CStr(p);   // '' is valid (no equation set)
end;

function TAntimony.GetNthSymbolInitialAssignmentOfType(
  const AModuleName: string; ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolInitialAssignmentOfType(
           PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolInitialAssignmentOfType');
  Result := CStr(p);
end;

function TAntimony.GetNthSymbolAssignmentRuleOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolAssignmentRuleOfType(
           PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolAssignmentRuleOfType');
  Result := CStr(p);
end;

function TAntimony.GetNthSymbolRateRuleOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolRateRuleOfType(PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolRateRuleOfType');
  Result := CStr(p);
end;

function TAntimony.GetNthSymbolCompartmentOfType(const AModuleName: string;
  ARType: TReturnType; N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthSymbolCompartmentOfType(PAnsiChar(aMN), ARType, N);
  CheckPtr(p, 'GetNthSymbolCompartmentOfType');
  Result := CStr(p);
end;

function TAntimony.GetTypeOfSymbol(const AModuleName,
  ASymbolName: string): TReturnType;
var
  aMN, aSN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  aSN    := AnsiString(ASymbolName);
  Result := AntimonyAPI.getTypeOfSymbol(PAnsiChar(aMN), PAnsiChar(aSN));
end;

function TAntimony.GetTypeOfEquationForSymbol(const AModuleName,
  ASymbolName: string): TFormulaType;
var
  aMN, aSN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  aSN    := AnsiString(ASymbolName);
  Result := AntimonyAPI.getTypeOfEquationForSymbol(
              PAnsiChar(aMN), PAnsiChar(aSN));
end;

function TAntimony.GetCompartmentForSymbol(const AModuleName,
  ASymbolName: string): string;
var
  aMN, aSN: AnsiString;
  p       : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  aSN := AnsiString(ASymbolName);
  p   := AntimonyAPI.getCompartmentForSymbol(PAnsiChar(aMN), PAnsiChar(aSN));
  // Returns 'default_compartment' even when nothing is set – nil means error
  CheckPtr(p, 'GetCompartmentForSymbol');
  Result := CStr(p);
end;

// ============================================================================
//  REACTIONS
// ============================================================================

function TAntimony.GetNumReactions(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumReactions(PAnsiChar(aMN));
end;

function TAntimony.GetNumReactants(const AModuleName: string;
  ARxn: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumReactants(PAnsiChar(aMN), ARxn);
end;

function TAntimony.GetNumProducts(const AModuleName: string;
  ARxn: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumProducts(PAnsiChar(aMN), ARxn);
end;

function TAntimony.GetReactantNames(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  nRxn  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN   := AnsiString(AModuleName);
  nRxn  := AntimonyAPI.getNumReactions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nRxn, AntimonyAPI.getNumReactants);
  Result := CStr2DArr(
              AntimonyAPI.getReactantNames(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthReactionReactantNames(const AModuleName: string;
  ARxn: Cardinal): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getNthReactionReactantNames(PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumReactants(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthReactionMthReactantName(const AModuleName: string;
  ARxn, AReactant: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthReactionMthReactantName(
           PAnsiChar(aMN), ARxn, AReactant);
  CheckPtr(p, 'GetNthReactionMthReactantName');
  Result := CStr(p);
end;

function TAntimony.GetProductNames(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  nRxn  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN    := AnsiString(AModuleName);
  nRxn   := AntimonyAPI.getNumReactions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nRxn, AntimonyAPI.getNumProducts);
  Result := CStr2DArr(
              AntimonyAPI.getProductNames(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthReactionProductNames(const AModuleName: string;
  ARxn: Cardinal): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getNthReactionProductNames(PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumProducts(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthReactionMthProductName(const AModuleName: string;
  ARxn, AProduct: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthReactionMthProductName(
           PAnsiChar(aMN), ARxn, AProduct);
  CheckPtr(p, 'GetNthReactionMthProductName');
  Result := CStr(p);
end;

function TAntimony.GetReactantStoichiometries(
  const AModuleName: string): TArray<TArray<Double>>;
var
  aMN   : AnsiString;
  nRxn  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN    := AnsiString(AModuleName);
  nRxn   := AntimonyAPI.getNumReactions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nRxn, AntimonyAPI.getNumReactants);
  Result := CDbl2DArr(
              AntimonyAPI.getReactantStoichiometries(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetProductStoichiometries(
  const AModuleName: string): TArray<TArray<Double>>;
var
  aMN   : AnsiString;
  nRxn  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN    := AnsiString(AModuleName);
  nRxn   := AntimonyAPI.getNumReactions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nRxn, AntimonyAPI.getNumProducts);
  Result := CDbl2DArr(
              AntimonyAPI.getProductStoichiometries(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthReactionReactantStoichiometries(
  const AModuleName: string; ARxn: Cardinal): TArray<Double>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CDblArr(
              AntimonyAPI.getNthReactionReactantStoichiometries(
                PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumReactants(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthReactionProductStoichiometries(
  const AModuleName: string; ARxn: Cardinal): TArray<Double>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CDblArr(
              AntimonyAPI.getNthReactionProductStoichiometries(
                PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumProducts(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthReactionMthReactantStoichiometry(
  const AModuleName: string; ARxn, AReactant: Cardinal): Double;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNthReactionMthReactantStoichiometries(
              PAnsiChar(aMN), ARxn, AReactant);
end;

function TAntimony.GetNthReactionMthProductStoichiometry(
  const AModuleName: string; ARxn, AProduct: Cardinal): Double;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNthReactionMthProductStoichiometries(
              PAnsiChar(aMN), ARxn, AProduct);
end;

// ============================================================================
//  INTERACTIONS
// ============================================================================

function TAntimony.GetNumInteractions(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumInteractions(PAnsiChar(aMN));
end;

function TAntimony.GetNumInteractors(const AModuleName: string;
  ARxn: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumInteractors(PAnsiChar(aMN), ARxn);
end;

function TAntimony.GetNumInteractees(const AModuleName: string;
  ARxn: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumInteractees(PAnsiChar(aMN), ARxn);
end;

function TAntimony.GetInteractorNames(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  nInt  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN    := AnsiString(AModuleName);
  nInt   := AntimonyAPI.getNumInteractions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nInt, AntimonyAPI.getNumInteractors);
  Result := CStr2DArr(
              AntimonyAPI.getInteractorNames(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthInteractionInteractorNames(const AModuleName: string;
  ARxn: Cardinal): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getNthInteractionInteractorNames(
                PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumInteractors(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthInteractionMthInteractorName(const AModuleName: string;
  AInteraction, AInteractor: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthInteractionMthInteractorName(
           PAnsiChar(aMN), AInteraction, AInteractor);
  CheckPtr(p, 'GetNthInteractionMthInteractorName');
  Result := CStr(p);
end;

function TAntimony.GetInteracteeNames(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  nInt  : Cardinal;
  counts: TArray<Integer>;
begin
  aMN    := AnsiString(AModuleName);
  nInt   := AntimonyAPI.getNumInteractions(PAnsiChar(aMN));
  counts := ReactionInnerCounts(aMN, nInt, AntimonyAPI.getNumInteractees);
  Result := CStr2DArr(
              AntimonyAPI.getInteracteeNames(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthInteractionInteracteeNames(const AModuleName: string;
  ARxn: Cardinal): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getNthInteractionInteracteeNames(
                PAnsiChar(aMN), ARxn),
              Integer(AntimonyAPI.getNumInteractees(PAnsiChar(aMN), ARxn)));
end;

function TAntimony.GetNthInteractionMthInteracteeName(const AModuleName: string;
  AInteraction, AInteractee: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthInteractionMthInteracteeName(
           PAnsiChar(aMN), AInteraction, AInteractee);
  CheckPtr(p, 'GetNthInteractionMthInteracteeName');
  Result := CStr(p);
end;

function TAntimony.GetInteractionDividers(
  const AModuleName: string): TArray<TRdType>;
var
  aMN  : AnsiString;
  nInt : Cardinal;
  pi   : PInteger;
  Ptr  : PInteger;
  i    : Integer;
begin
  aMN  := AnsiString(AModuleName);
  nInt := AntimonyAPI.getNumInteractions(PAnsiChar(aMN));
  pi   := AntimonyAPI.getInteractionDividers(PAnsiChar(aMN));
  SetLength(Result, nInt);
  if (pi = nil) or (nInt = 0) then
    Exit;
  Ptr := pi;
  for i := 0 to Integer(nInt) - 1 do
  begin
    Result[i] := TRdType(Ptr^);
    Inc(Ptr);
  end;
end;

function TAntimony.GetNthInteractionDivider(const AModuleName: string;
  N: Cardinal): TRdType;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNthInteractionDivider(PAnsiChar(aMN), N);
end;

// ============================================================================
//  STOICHIOMETRY MATRIX
// ============================================================================

function TAntimony.GetStoichiometryMatrix(
  const AModuleName: string): TArray<TArray<Double>>;
var
  aMN   : AnsiString;
  ppd   : PPDouble;
  nRows : Cardinal;
  nCols : Cardinal;
  counts: TArray<Integer>;
begin
  aMN   := AnsiString(AModuleName);
  nRows := AntimonyAPI.getStoichiometryMatrixNumRows(PAnsiChar(aMN));
  nCols := AntimonyAPI.getStoichiometryMatrixNumColumns(PAnsiChar(aMN));
  ppd   := AntimonyAPI.getStoichiometryMatrix(PAnsiChar(aMN));
  // Matrix is rectangular (not jagged): all rows have the same column count
  counts := UniformCounts(Integer(nRows), Integer(nCols));
  Result := CDbl2DArr(ppd, counts);
end;

function TAntimony.GetStoichiometryMatrixRowLabels(
  const AModuleName: string): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getStoichiometryMatrixRowLabels(PAnsiChar(aMN)),
              Integer(AntimonyAPI.getStoichiometryMatrixNumRows(PAnsiChar(aMN))));
end;

function TAntimony.GetStoichiometryMatrixColumnLabels(
  const AModuleName: string): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getStoichiometryMatrixColumnLabels(PAnsiChar(aMN)),
              Integer(AntimonyAPI.getStoichiometryMatrixNumColumns(
                PAnsiChar(aMN))));
end;

function TAntimony.GetStoichiometryMatrixNumRows(
  const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getStoichiometryMatrixNumRows(PAnsiChar(aMN));
end;

function TAntimony.GetStoichiometryMatrixNumColumns(
  const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getStoichiometryMatrixNumColumns(PAnsiChar(aMN));
end;

function TAntimony.GetNumReactionRates(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumReactionRates(PAnsiChar(aMN));
end;

function TAntimony.GetReactionRates(const AModuleName: string): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getReactionRates(PAnsiChar(aMN)),
              Integer(AntimonyAPI.getNumReactionRates(PAnsiChar(aMN))));
end;

function TAntimony.GetNthReactionRate(const AModuleName: string;
  ARxn: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthReactionRate(PAnsiChar(aMN), ARxn);
  CheckPtr(p, 'GetNthReactionRate');
  Result := CStr(p);  // '' is valid (rate not set)
end;

// ============================================================================
//  EVENTS
// ============================================================================

function TAntimony.GetNumEvents(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumEvents(PAnsiChar(aMN));
end;

function TAntimony.GetEventNames(const AModuleName: string): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getEventNames(PAnsiChar(aMN)),
              Integer(AntimonyAPI.getNumEvents(PAnsiChar(aMN))));
end;

function TAntimony.GetNthEventName(const AModuleName: string;
  AEvent: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthEventName(PAnsiChar(aMN), AEvent);
  CheckPtr(p, 'GetNthEventName');
  Result := CStr(p);
end;

function TAntimony.GetNumAssignmentsForEvent(const AModuleName: string;
  AEvent: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumAssignmentsForEvent(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetTriggerForEvent(const AModuleName: string;
  AEvent: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getTriggerForEvent(PAnsiChar(aMN), AEvent);
  CheckPtr(p, 'GetTriggerForEvent');
  Result := CStr(p);
end;

function TAntimony.GetDelayForEvent(const AModuleName: string;
  AEvent: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getDelayForEvent(PAnsiChar(aMN), AEvent);
  CheckPtr(p, 'GetDelayForEvent');
  Result := CStr(p);  // '' means no delay
end;

function TAntimony.GetEventHasDelay(const AModuleName: string;
  AEvent: Cardinal): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getEventHasDelay(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetPriorityForEvent(const AModuleName: string;
  AEvent: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getPriorityForEvent(PAnsiChar(aMN), AEvent);
  CheckPtr(p, 'GetPriorityForEvent');
  Result := CStr(p);  // '' means no priority
end;

function TAntimony.GetEventHasPriority(const AModuleName: string;
  AEvent: Cardinal): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getEventHasPriority(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetPersistenceForEvent(const AModuleName: string;
  AEvent: Cardinal): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getPersistenceForEvent(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetT0ForEvent(const AModuleName: string;
  AEvent: Cardinal): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getT0ForEvent(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetFromTriggerForEvent(const AModuleName: string;
  AEvent: Cardinal): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getFromTriggerForEvent(PAnsiChar(aMN), AEvent);
end;

function TAntimony.GetNthAssignmentVariableForEvent(const AModuleName: string;
  AEvent, N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthAssignmentVariableForEvent(
           PAnsiChar(aMN), AEvent, N);
  CheckPtr(p, 'GetNthAssignmentVariableForEvent');
  Result := CStr(p);
end;

function TAntimony.GetNthAssignmentEquationForEvent(const AModuleName: string;
  AEvent, N: Cardinal): string;
var
  aMN: AnsiString;
  p  : PAnsiChar;
begin
  aMN := AnsiString(AModuleName);
  p   := AntimonyAPI.getNthAssignmentEquationForEvent(
           PAnsiChar(aMN), AEvent, N);
  CheckPtr(p, 'GetNthAssignmentEquationForEvent');
  Result := CStr(p);
end;

// ============================================================================
//  DNA STRANDS
// ============================================================================

function TAntimony.GetNumDNAStrands(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumDNAStrands(PAnsiChar(aMN));
end;

function TAntimony.GetDNAStrandSizes(const AModuleName: string): TArray<Cardinal>;
var
  aMN: AnsiString;
  n  : Cardinal;
begin
  aMN    := AnsiString(AModuleName);
  n      := AntimonyAPI.getNumDNAStrands(PAnsiChar(aMN));
  Result := CCardArr(AntimonyAPI.getDNAStrandSizes(PAnsiChar(aMN)), Integer(n));
end;

function TAntimony.GetSizeOfNthDNAStrand(const AModuleName: string;
  N: Cardinal): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getSizeOfNthDNAStrand(PAnsiChar(aMN), N);
end;

function TAntimony.GetDNAStrands(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  n     : Cardinal;
  counts: TArray<Integer>;
  i     : Integer;
begin
  aMN    := AnsiString(AModuleName);
  n      := AntimonyAPI.getNumDNAStrands(PAnsiChar(aMN));
  SetLength(counts, n);
  for i := 0 to Integer(n) - 1 do
    counts[i] := Integer(
      AntimonyAPI.getSizeOfNthDNAStrand(PAnsiChar(aMN), Cardinal(i)));
  Result := CStr2DArr(AntimonyAPI.getDNAStrands(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthDNAStrand(const AModuleName: string;
  N: Cardinal): TArray<string>;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := CStrArr(
              AntimonyAPI.getNthDNAStrand(PAnsiChar(aMN), N),
              Integer(AntimonyAPI.getSizeOfNthDNAStrand(PAnsiChar(aMN), N)));
end;

function TAntimony.GetIsNthDNAStrandOpen(const AModuleName: string;
  N: Cardinal; AUpstream: Boolean): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getIsNthDNAStrandOpen(
              PAnsiChar(aMN), N, LongBool(AUpstream));
end;

function TAntimony.GetNumModularDNAStrands(const AModuleName: string): Cardinal;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getNumModularDNAStrands(PAnsiChar(aMN));
end;

function TAntimony.GetModularDNAStrandSizes(
  const AModuleName: string): TArray<Cardinal>;
var
  aMN: AnsiString;
  n  : Cardinal;
begin
  aMN    := AnsiString(AModuleName);
  n      := AntimonyAPI.getNumModularDNAStrands(PAnsiChar(aMN));
  Result := CCardArr(
              AntimonyAPI.getModularDNAStrandSizes(PAnsiChar(aMN)), Integer(n));
end;

function TAntimony.GetModularDNAStrands(
  const AModuleName: string): TArray<TArray<string>>;
var
  aMN   : AnsiString;
  n     : Cardinal;
  sizes : PCardinal;
  SizPtr: PCardinal;
  counts: TArray<Integer>;
  i     : Integer;
begin
  aMN   := AnsiString(AModuleName);
  n     := AntimonyAPI.getNumModularDNAStrands(PAnsiChar(aMN));
  sizes := AntimonyAPI.getModularDNAStrandSizes(PAnsiChar(aMN));
  SetLength(counts, n);
  if (n > 0) and (sizes <> nil) then
  begin
    SizPtr := sizes;
    for i := 0 to Integer(n) - 1 do
    begin
      counts[i] := Integer(SizPtr^);
      Inc(SizPtr);
    end;
  end;
  Result := CStr2DArr(
              AntimonyAPI.getModularDNAStrands(PAnsiChar(aMN)), counts);
end;

function TAntimony.GetNthModularDNAStrand(const AModuleName: string;
  N: Cardinal): TArray<string>;
var
  aMN   : AnsiString;
  sizes : PCardinal;
  SizPtr: PCardinal;
  nSize : Integer;
  i     : Integer;
begin
  aMN   := AnsiString(AModuleName);
  sizes := AntimonyAPI.getModularDNAStrandSizes(PAnsiChar(aMN));
  nSize := 0;
  if sizes <> nil then
  begin
    SizPtr := sizes;
    for i := 0 to Integer(N) do   // advance to Nth element
    begin
      if i = Integer(N) then
        nSize := Integer(SizPtr^);
      Inc(SizPtr);
    end;
  end;
  Result := CStrArr(
              AntimonyAPI.getNthModularDNAStrand(PAnsiChar(aMN), N), nSize);
end;

function TAntimony.GetIsNthModularDNAStrandOpen(const AModuleName: string;
  N: Cardinal; AUpstream: Boolean): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.getIsNthModularDNAStrandOpen(
              PAnsiChar(aMN), N, LongBool(AUpstream));
end;

// ============================================================================
//  DEFAULTS
// ============================================================================

function TAntimony.AddDefaultInitialValues(const AModuleName: string): Boolean;
var
  aMN: AnsiString;
begin
  aMN    := AnsiString(AModuleName);
  Result := AntimonyAPI.addDefaultInitialValues(PAnsiChar(aMN));
end;

procedure TAntimony.SetBareNumbersAreDimensionless(ADimensionless: Boolean);
begin
  AntimonyAPI.setBareNumbersAreDimensionless(LongBool(ADimensionless));
end;

end.
