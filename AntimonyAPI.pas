unit AntimonyAPI;

{*******************************************************************************
  AntimonyAPI.pas

  Delphi Object Pascal static (load-time) binding for libAntimony.
  Covers every function declared in antimony_api.h (libAntimony 2.8).

  Reference:
    https://antimony.sourceforge.net/antimony__api_8h.html
    https://github.com/sys-bio/antimony

  Calling convention : cdecl (matches the C library on all platforms)

  On Windows  link against:  libantimony.dll  (or antimony.dll)
  On macOS    link against:  libantimony.dylib
  On Linux    link against:  libantimony.so

  Memory management note
  ~~~~~~~~~~~~~~~~~~~~~~
  Most functions that return pointers (PAnsiChar, PPAnsiChar, etc.) return
  malloc-allocated memory that the *caller* owns.  You must either free each
  pointer yourself, or call freeAll() once at the very end of your program
  (but never mix the two strategies – see freeAll() for details).

  Enum values
  ~~~~~~~~~~~
  return_type   – symbol category passed to the getSymbol*/getNthSymbol* family
  formula_type  – equation category returned by getTypeOfEquationForSymbol
  rd_type       – reaction/interaction divider returned by getInteractionDividers

  Author note: Herbert Sauro – binding generated from the official API docs.
*******************************************************************************}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

// ---------------------------------------------------------------------------
//  Platform-specific library name
// ---------------------------------------------------------------------------
const
{$IFDEF MSWINDOWS}
  LIBANTIMONY = 'libantimony.dll';
{$ENDIF}
{$IFDEF DARWIN}
  LIBANTIMONY = 'libantimony.dylib';
{$ENDIF}
{$IFDEF LINUX}
  LIBANTIMONY = 'libantimony.so';
{$ENDIF}

// ---------------------------------------------------------------------------
//  Helper pointer types
// ---------------------------------------------------------------------------
type
  PPAnsiChar  = ^PAnsiChar;   // char**   – array of C strings
  PPPAnsiChar = ^PPAnsiChar;  // char***  – array of arrays of C strings
  PDouble     = ^Double;      // double*  – array of doubles
  PPDouble    = ^PDouble;     // double** – 2-D array of doubles
  PCardinal   = ^Cardinal;    // unsigned long* – array of unsigned longs

// ---------------------------------------------------------------------------
//  Enumerations  (values match the C enums in enums.h)
// ---------------------------------------------------------------------------

  {** return_type – specifies which category of symbol to query.
      Passed as the 'rtype' parameter in the getSymbolXxxOfType / 
      getNumSymbolsOfType families. *}
  TReturnType = (
    allSymbols      = 0,   // Every symbol of every type
    allSpecies      = 1,   // All species (const and variable)
    allFormulas     = 2,   // All formulas (const and variable)
    allDNA          = 3,   // All symbols defined as DNA (operators + genes)
    allOperators    = 4,   // All operator symbols
    allGenes        = 5,   // All gene symbols (reactions in a DNA strand)
    allReactions    = 6,   // All reactions (species conversion / creation)
    allInteractions = 7,   // All interactions
    allEvents       = 8,   // All events
    allCompartments = 9,   // All compartments (const and variable)
    allUnknown      = 10,  // Symbols with undefined/unused type
    varSpecies      = 11,  // Variable (floating) species
    varFormulas     = 12,  // Equations that can change (incl. via events)
    varOperators    = 13,  // Operators with variable values
    varCompartments = 14,  // Compartments with variable sizes
    constSpecies    = 15,  // Constant (border) species
    constFormulas   = 16,  // Formulas with constant values
    constOperators  = 17,  // Operators with constant values
    constCompartments = 18,// Compartments with constant sizes
    subModules      = 19,  // Sub-modules used within the current module
    expandedStrands = 20,  // Expanded DNA strands (no sub-strands)
    modularStrands  = 21   // All defined DNA strands including sub-strands
  );

  {** formula_type – describes how a symbol's equation is defined. *}
  TFormulaType = (
    formulaINITIAL    = 0, // Set by an initial assignment
    formulaASSIGNMENT = 1, // Defined by an assignment rule
    formulaRATE       = 2, // Defined by a rate rule (ODE)
    formulaVALUE      = 3  // A plain value / parameter
  );

  {** rd_type – reaction or interaction 'divider' arrow type.
      rdBecomes (0) is used for reactions; values > 0 are interaction types. *}
  TRdType = (
    rdBecomes        = 0,  // '->' used in reactions (invalid as interaction divider)
    rdActivates      = 1,  // '-o'  activation interaction
    rdInhibits       = 2,  // '-|'  inhibition interaction
    rdRawArrow       = 3,  // '-->' raw / unspecified arrow
    rdRawInhibition  = 4   // '--|' raw inhibition
  );

// ---------------------------------------------------------------------------
//  Input functions
// ---------------------------------------------------------------------------

{ Load a file of any format libAntimony knows about (Antimony, SBML, CellML).
  Returns a non-negative index on success, or -1 on failure. }
function loadFile(filename: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadFile';

{ Load a string of any format libAntimony knows about.
  Returns a non-negative index on success, or -1 on failure. }
function loadString(model: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadString';

{ Loads a file and parses it strictly as an Antimony file.
  Returns a non-negative index on success, or -1 on failure. }
function loadAntimonyFile(filename: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadAntimonyFile';

{ Loads a string and parses it strictly as Antimony.
  Returns a non-negative index on success, or -1 on failure. }
function loadAntimonyString(model: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadAntimonyString';

{ Load a file known to be SBML.
  Returns a non-negative index on success, or -1 on failure. }
function loadSBMLFile(filename: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadSBMLFile';

{ Load a string known to be SBML.
  Returns a non-negative index on success, or -1 on failure. }
function loadSBMLString(model: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadSBMLString';

{ Load a string known to be SBML together with its file location (used to
  resolve relative paths in the model).
  Returns a non-negative index on success, or -1 on failure. }
function loadSBMLStringWithLocation(model: PAnsiChar;
  location: PAnsiChar): LongInt; cdecl;
  external LIBANTIMONY name 'loadSBMLStringWithLocation';

{ Load a file known to be CellML.
  Returns a non-negative index on success, or -1 on failure.
  NOTE: Unavailable when compiled with -NCELLML. }
//function loadCellMLFile(filename: PAnsiChar): LongInt; cdecl;
//  external LIBANTIMONY name 'loadCellMLFile';

{ Load a string known to be CellML.
  Returns a non-negative index on success, or -1 on failure.
  NOTE: Unavailable when compiled with -NCELLML. }
//function loadCellMLString(model: PAnsiChar): LongInt; cdecl;
//  external LIBANTIMONY name 'loadCellMLString';

{ Returns the number of file/string sets currently held in memory. }
function getNumFiles: Cardinal; cdecl;
  external LIBANTIMONY name 'getNumFiles';

{ Makes the module set at the given index 'active'.  Returns True on success. }
function revertTo(index: LongInt): LongBool; cdecl;
  external LIBANTIMONY name 'revertTo';

{ Clears all loaded files/strings from memory. }
procedure clearPreviousLoads; cdecl;
  external LIBANTIMONY name 'clearPreviousLoads';

{ Adds a directory to search when resolving imported files. }
procedure addDirectory(directory: PAnsiChar); cdecl;
  external LIBANTIMONY name 'addDirectory';

{ Clears all directories previously added with addDirectory. }
procedure clearDirectories; cdecl;
  external LIBANTIMONY name 'clearDirectories';

// ---------------------------------------------------------------------------
//  Output functions
// ---------------------------------------------------------------------------

{ Writes an Antimony-formatted file for the named module.
  Returns 1 on success, 0 on failure. }
function writeAntimonyFile(filename: PAnsiChar;
  moduleName: PAnsiChar): Integer; cdecl;
  external LIBANTIMONY name 'writeAntimonyFile';

{ Returns the Antimony representation of the named module as a string.
  The caller owns the returned pointer. Returns NULL on failure. }
function getAntimonyString(moduleName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getAntimonyString';

{ Writes a flattened SBML XML file for the named module.
  Returns 1 on success, 0 on failure.
  NOTE: Unavailable when compiled with -NSBML. }
function writeSBMLFile(filename: PAnsiChar;
  moduleName: PAnsiChar): Integer; cdecl;
  external LIBANTIMONY name 'writeSBMLFile';

{ Returns the flattened SBML representation of the named module as a string.
  The caller owns the returned pointer. Returns NULL on failure.
  NOTE: Unavailable when compiled with -NSBML. }
function getSBMLString(moduleName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getSBMLString';

{ Writes a hierarchical (comp package) SBML XML file for the named module.
  Returns 1 on success, 0 on failure.
  NOTE: Unavailable when compiled with -NSBML or without USE_COMP. }
function writeCompSBMLFile(filename: PAnsiChar;
  moduleName: PAnsiChar): Integer; cdecl;
  external LIBANTIMONY name 'writeCompSBMLFile';

{ Returns the hierarchical SBML representation of the named module as a string.
  The caller owns the returned pointer. Returns NULL on failure.
  NOTE: Unavailable when compiled with -NSBML or without USE_COMP. }
function getCompSBMLString(moduleName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getCompSBMLString';

{ Writes a CellML XML file for the named module.
  Returns 1 on success, 0 on failure.
  NOTE: Unavailable when compiled with -NCELLML. }
//function writeCellMLFile(filename: PAnsiChar;
//  moduleName: PAnsiChar): Integer; cdecl;
//  external LIBANTIMONY name 'writeCellMLFile';

{ Returns the CellML representation of the named module as a string.
  The caller owns the returned pointer. Returns NULL on failure.
  NOTE: Unavailable when compiled with -NCELLML. }
//function getCellMLString(moduleName: PAnsiChar): PAnsiChar; cdecl;
//  external LIBANTIMONY name 'getCellMLString';

{ Prints all stored data for the named module to stdout.
  Useful as a diagnostic / example. }
procedure printAllDataFor(moduleName: PAnsiChar); cdecl;
  external LIBANTIMONY name 'printAllDataFor';

// ---------------------------------------------------------------------------
//  Errors and Warnings
// ---------------------------------------------------------------------------

{ Returns True if the module name exists in the current active set. }
function checkModule(moduleName: PAnsiChar): LongBool; cdecl;
  external LIBANTIMONY name 'checkModule';

{ Returns a longer description of the most recent error.
  The caller owns the returned pointer. }
function getLastError: PAnsiChar; cdecl;
  external LIBANTIMONY name 'getLastError';

{ Returns warning messages generated during translation (NULL if none).
  The caller owns the returned pointer. }
function getWarnings: PAnsiChar; cdecl;
  external LIBANTIMONY name 'getWarnings';

{ Returns libSBML 'info' messages for the named module.
  Returns an empty string if none exist.
  NOTE: Unavailable when compiled with -NSBML. }
function getSBMLInfoMessages(moduleName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getSBMLInfoMessages';

{ Returns libSBML 'warning' messages for the named module.
  Returns an empty string if none exist.
  NOTE: Unavailable when compiled with -NSBML. }
function getSBMLWarnings(moduleName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getSBMLWarnings';

// ---------------------------------------------------------------------------
//  Modules
// ---------------------------------------------------------------------------

{ Returns the number of modules in the currently active set. }
function getNumModules: Cardinal; cdecl;
  external LIBANTIMONY name 'getNumModules';

{ Returns a NULL-terminated array of all current module name strings.
  The caller owns the returned pointer. }
function getModuleNames: PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getModuleNames';

{ Returns the name of the Nth module (0-based).
  Returns NULL and sets an error if n is out of range. }
function getNthModuleName(n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthModuleName';

{ Returns the name of the 'main' (top-level) module.
  Returns NULL if no modules are loaded. }
function getMainModuleName: PAnsiChar; cdecl;
  external LIBANTIMONY name 'getMainModuleName';

// ---------------------------------------------------------------------------
//  Module Interface
// ---------------------------------------------------------------------------

{ Returns the number of symbols in the interface of the given module.
  e.g. 'module M(x, y, z)' returns 3. }
function getNumSymbolsInInterfaceOf(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumSymbolsInInterfaceOf';

{ Returns an array of interface symbol names for the given module.
  The caller owns the returned pointer. }
function getSymbolNamesInInterfaceOf(moduleName: PAnsiChar): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolNamesInInterfaceOf';

{ Returns the Nth interface symbol name (0-based).
  Returns NULL and sets an error if not found. }
function getNthSymbolNameInInterfaceOf(moduleName: PAnsiChar;
  n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolNameInInterfaceOf';

// ---------------------------------------------------------------------------
//  Replacements  (symbol synchronization via 'is' constructs)
// ---------------------------------------------------------------------------

{ Returns the number of symbol-replacement pairs in the given module. }
function getNumReplacedSymbolNames(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumReplacedSymbolNames';

{ Returns an array-of-pairs (char***) of all replacement pairs in the module.
  Each inner pair is [formerName, replacementName].
  The caller owns the returned pointer. }
function getAllReplacementSymbolPairs(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getAllReplacementSymbolPairs';

{ Returns the Nth replacement pair as a 2-element array [formerName, replacementName].
  The caller owns the returned pointer. }
function getNthReplacementSymbolPair(moduleName: PAnsiChar;
  n: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReplacementSymbolPair';

{ Returns the Nth former (replaced) symbol name in the given module. }
function getNthFormerSymbolName(moduleName: PAnsiChar;
  n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthFormerSymbolName';

{ Returns the Nth replacement symbol name in the given module. }
function getNthReplacementSymbolName(moduleName: PAnsiChar;
  n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReplacementSymbolName';

{ Returns the number of replacements between two specific sub-modules. }
function getNumReplacedSymbolNamesBetween(moduleName: PAnsiChar;
  formerSubmodName: PAnsiChar;
  replacementSubmodName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumReplacedSymbolNamesBetween';

{ Returns an array-of-pairs for all replacements between the two sub-modules.
  The caller owns the returned pointer. }
function getAllReplacementSymbolPairsBetween(moduleName: PAnsiChar;
  formerSubmodName: PAnsiChar;
  replacementSubmodName: PAnsiChar;
  n: Cardinal): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getAllReplacementSymbolPairsBetween';

{ Returns the Nth replacement pair between two specific sub-modules. }
function getNthReplacementSymbolPairBetween(moduleName: PAnsiChar;
  formerSubmodName: PAnsiChar;
  replacementSubmodName: PAnsiChar;
  n: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReplacementSymbolPairBetween';

{ Returns the Nth former symbol name between two sub-modules. }
function getNthFormerSymbolNameBetween(moduleName: PAnsiChar;
  formerSubmodName: PAnsiChar;
  replacementSubmodName: PAnsiChar;
  n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthFormerSymbolNameBetween';

{ Returns the Nth replacement symbol name between two sub-modules. }
function getNthReplacementSymbolNameBetween(moduleName: PAnsiChar;
  formerSubmodName: PAnsiChar;
  replacementSubmodName: PAnsiChar;
  n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReplacementSymbolNameBetween';

// ---------------------------------------------------------------------------
//  Symbols and symbol information
// ---------------------------------------------------------------------------

{ Returns the number of symbols of the given return type in the module. }
function getNumSymbolsOfType(moduleName: PAnsiChar;
  rtype: TReturnType): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumSymbolsOfType';

{ Returns an array of symbol names of the given type.
  The caller owns the returned pointer. }
function getSymbolNamesOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolNamesOfType';

{ Returns an array of display names (SBML 'name' attribute) of the given type.
  The caller owns the returned pointer. }
function getSymbolDisplayNamesOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolDisplayNamesOfType';

{ Returns an array of equations (initial value / formula) for symbols of the
  given type.  The caller owns the returned pointer. }
function getSymbolEquationsOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolEquationsOfType';

{ Returns an array of initial-assignment equations for symbols of the given type.
  The caller owns the returned pointer. }
function getSymbolInitialAssignmentsOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolInitialAssignmentsOfType';

{ Returns an array of assignment-rule equations for symbols of the given type.
  The caller owns the returned pointer. }
function getSymbolAssignmentRulesOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolAssignmentRulesOfType';

{ Returns an array of rate-rule equations for symbols of the given type.
  The caller owns the returned pointer. }
function getSymbolRateRulesOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolRateRulesOfType';

{ Returns an array of compartment names for symbols of the given type.
  The caller owns the returned pointer. }
function getSymbolCompartmentsOfType(moduleName: PAnsiChar;
  rtype: TReturnType): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getSymbolCompartmentsOfType';

{ Returns the name (SBML 'id') of the Nth symbol of the given type (0-based).
  Returns NULL and sets an error if not found. }
function getNthSymbolNameOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolNameOfType';

{ Returns the display name (SBML 'name') of the Nth symbol of the given type.
  Returns NULL and sets an error if not found. }
function getNthSymbolDisplayNameOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolDisplayNameOfType';

{ Returns the equation / initial value of the Nth symbol of the given type.
  Returns an empty string if no equation is set; NULL if the symbol is not found. }
function getNthSymbolEquationOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolEquationOfType';

{ Returns the initial assignment of the Nth symbol of the given type.
  Returns an empty string if none; NULL if not found. }
function getNthSymbolInitialAssignmentOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolInitialAssignmentOfType';

{ Returns the assignment rule of the Nth symbol of the given type.
  Returns an empty string if none; NULL if not found. }
function getNthSymbolAssignmentRuleOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolAssignmentRuleOfType';

{ Returns the rate rule of the Nth symbol of the given type.
  Returns an empty string if none; NULL if not found. }
function getNthSymbolRateRuleOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolRateRuleOfType';

{ Returns the compartment name of the Nth symbol of the given type.
  Returns "default_compartment" if not explicitly set; NULL if not found. }
function getNthSymbolCompartmentOfType(moduleName: PAnsiChar;
  rtype: TReturnType; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthSymbolCompartmentOfType';

{ Returns the most specific TReturnType available for the named symbol. }
function getTypeOfSymbol(moduleName: PAnsiChar;
  symbolName: PAnsiChar): TReturnType; cdecl;
  external LIBANTIMONY name 'getTypeOfSymbol';

{ Returns the TFormulaType that describes how the named symbol's equation is
  defined (initial assignment, assignment rule, rate rule, or plain value). }
function getTypeOfEquationForSymbol(moduleName: PAnsiChar;
  symbolName: PAnsiChar): TFormulaType; cdecl;
  external LIBANTIMONY name 'getTypeOfEquationForSymbol';

{ Returns the compartment name for the given symbol.
  Returns "default_compartment" if not set. }
function getCompartmentForSymbol(moduleName: PAnsiChar;
  symbolName: PAnsiChar): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getCompartmentForSymbol';

// ---------------------------------------------------------------------------
//  Reactions
// ---------------------------------------------------------------------------

{ Returns the number of reactions (including genes) in the module. }
function getNumReactions(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumReactions';

{ Returns the number of reactants (LHS species) for reaction rxn (0-based). }
function getNumReactants(moduleName: PAnsiChar;
  rxn: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumReactants';

{ Returns the number of products (RHS species) for reaction rxn (0-based). }
function getNumProducts(moduleName: PAnsiChar;
  rxn: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumProducts';

{ Returns all reactant names for all reactions as a jagged 2-D array (char***).
  Dimensions: [getNumReactions][getNumReactants(rxn)].
  The caller owns the returned pointer. }
function getReactantNames(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getReactantNames';

{ Returns an array of reactant names for reaction rxn.
  Length = getNumReactants(moduleName, rxn).
  The caller owns the returned pointer. }
function getNthReactionReactantNames(modulename: PAnsiChar;
  rxn: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReactionReactantNames';

{ Returns the name of the Mth reactant of reaction rxn (both 0-based).
  Returns NULL and sets an error if not found. }
function getNthReactionMthReactantName(modulename: PAnsiChar;
  rxn: Cardinal; reactant: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReactionMthReactantName';

{ Returns all product names for all reactions as a jagged 2-D array (char***).
  Dimensions: [getNumReactions][getNumProducts(rxn)].
  The caller owns the returned pointer. }
function getProductNames(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getProductNames';

{ Returns an array of product names for reaction rxn.
  Length = getNumProducts(moduleName, rxn).
  The caller owns the returned pointer. }
function getNthReactionProductNames(modulename: PAnsiChar;
  rxn: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReactionProductNames';

{ Returns the name of the Mth product of reaction rxn (both 0-based).
  Returns NULL and sets an error if not found. }
function getNthReactionMthProductName(modulename: PAnsiChar;
  rxn: Cardinal; product: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReactionMthProductName';

{ Returns a 2-D array of reactant stoichiometries for all reactions.
  Dimensions: [getNumReactions][getNumReactants(rxn)].
  The caller owns the returned pointer. }
function getReactantStoichiometries(moduleName: PAnsiChar): PPDouble; cdecl;
  external LIBANTIMONY name 'getReactantStoichiometries';

{ Returns a 2-D array of product stoichiometries for all reactions.
  Dimensions: [getNumReactions][getNumProducts(rxn)].
  The caller owns the returned pointer. }
function getProductStoichiometries(moduleName: PAnsiChar): PPDouble; cdecl;
  external LIBANTIMONY name 'getProductStoichiometries';

{ Returns an array of reactant stoichiometries for the Nth reaction.
  Length = getNumReactants(moduleName, rxn).
  Returns NULL and sets an error if the reaction does not exist. }
function getNthReactionReactantStoichiometries(moduleName: PAnsiChar;
  rxn: Cardinal): PDouble; cdecl;
  external LIBANTIMONY name 'getNthReactionReactantStoichiometries';

{ Returns an array of product stoichiometries for the Nth reaction.
  Length = getNumProducts(moduleName, rxn).
  Returns NULL and sets an error if the reaction does not exist. }
function getNthReactionProductStoichiometries(moduleName: PAnsiChar;
  rxn: Cardinal): PDouble; cdecl;
  external LIBANTIMONY name 'getNthReactionProductStoichiometries';

{ Returns the stoichiometry of the Mth reactant of the Nth reaction.
  Returns 0 and sets an error if not found. }
function getNthReactionMthReactantStoichiometries(moduleName: PAnsiChar;
  rxn: Cardinal; reactant: Cardinal): Double; cdecl;
  external LIBANTIMONY name 'getNthReactionMthReactantStoichiometries';

{ Returns the stoichiometry of the Mth product of the Nth reaction.
  Returns 0 and sets an error if not found. }
function getNthReactionMthProductStoichiometries(moduleName: PAnsiChar;
  rxn: Cardinal; product: Cardinal): Double; cdecl;
  external LIBANTIMONY name 'getNthReactionMthProductStoichiometries';

// ---------------------------------------------------------------------------
//  Interactions
// ---------------------------------------------------------------------------

{ Returns the number of interactions in the module. }
function getNumInteractions(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumInteractions';

{ Returns the number of interactors (LHS species) for interaction rxn (0-based). }
function getNumInteractors(moduleName: PAnsiChar;
  rxn: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumInteractors';

{ Returns the number of interactees (RHS reactions) for interaction rxn (0-based). }
function getNumInteractees(moduleName: PAnsiChar;
  rxn: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumInteractees';

{ Returns all interactor names for all interactions as a jagged 2-D array.
  The caller owns the returned pointer. }
function getInteractorNames(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getInteractorNames';

{ Returns an array of interactor names for interaction rxn.
  Returns NULL and sets an error if the interaction does not exist. }
function getNthInteractionInteractorNames(modulename: PAnsiChar;
  rxn: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthInteractionInteractorNames';

{ Returns the name of the Mth interactor of the given interaction (both 0-based).
  Returns NULL and sets an error if not found. }
function getNthInteractionMthInteractorName(modulename: PAnsiChar;
  interaction: Cardinal; interactor: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthInteractionMthInteractorName';

{ Returns all interactee names for all interactions as a jagged 2-D array.
  The caller owns the returned pointer. }
function getInteracteeNames(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getInteracteeNames';

{ Returns an array of interactee names for interaction rxn.
  Returns NULL and sets an error if the interaction does not exist. }
function getNthInteractionInteracteeNames(modulename: PAnsiChar;
  rxn: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthInteractionInteracteeNames';

{ Returns the name of the Mth interactee of the given interaction (both 0-based).
  Returns NULL and sets an error if not found. }
function getNthInteractionMthInteracteeName(modulename: PAnsiChar;
  interaction: Cardinal; interactee: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthInteractionMthInteracteeName';

{ Returns an array of all interaction divider types (TRdType) for the module.
  Length = getNumInteractions.  The caller owns the returned pointer. }
function getInteractionDividers(moduleName: PAnsiChar): PInteger; cdecl;
  external LIBANTIMONY name 'getInteractionDividers';

{ Returns the Nth interaction divider type (0-based).
  Returns rdBecomes (0) if no such interaction exists. }
function getNthInteractionDivider(moduleName: PAnsiChar;
  n: Cardinal): TRdType; cdecl;
  external LIBANTIMONY name 'getNthInteractionDivider';

// ---------------------------------------------------------------------------
//  Stoichiometry matrix
// ---------------------------------------------------------------------------

{ Returns the N x M stoichiometry matrix where N = number of variable species
  and M = number of reactions.
  The caller owns the returned pointer. }
function getStoichiometryMatrix(moduleName: PAnsiChar): PPDouble; cdecl;
  external LIBANTIMONY name 'getStoichiometryMatrix';

{ Returns the row labels (variable-species names) for the stoichiometry matrix.
  The caller owns the returned pointer. }
function getStoichiometryMatrixRowLabels(moduleName: PAnsiChar): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getStoichiometryMatrixRowLabels';

{ Returns the column labels (reaction names) for the stoichiometry matrix.
  The caller owns the returned pointer. }
function getStoichiometryMatrixColumnLabels(moduleName: PAnsiChar): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getStoichiometryMatrixColumnLabels';

{ Returns the number of rows in the stoichiometry matrix (= number of variable
  species). }
function getStoichiometryMatrixNumRows(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getStoichiometryMatrixNumRows';

{ Returns the number of columns in the stoichiometry matrix (= number of
  reactions). }
function getStoichiometryMatrixNumColumns(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getStoichiometryMatrixNumColumns';

{ Returns the number of reactions (= number of reaction rates) in the module. }
function getNumReactionRates(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumReactionRates';

{ Returns an array of reaction-rate formula strings for all reactions.
  Equivalent to getSymbolEquationsOfType(moduleName, allReactions).
  The caller owns the returned pointer. }
function getReactionRates(moduleName: PAnsiChar): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getReactionRates';

{ Returns the reaction-rate formula string for the Nth reaction (0-based).
  Returns an empty string if no rate is set; NULL if the reaction does not exist. }
function getNthReactionRate(moduleName: PAnsiChar;
  rxn: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthReactionRate';

// ---------------------------------------------------------------------------
//  Events
// ---------------------------------------------------------------------------

{ Returns the number of events in the module. }
function getNumEvents(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumEvents';

{ Returns an array of event name strings.
  Equivalent to getSymbolNamesOfType(moduleName, allEvents).
  The caller owns the returned pointer. }
function getEventNames(moduleName: PAnsiChar): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getEventNames';

{ Returns the name of the Nth event (0-based). }
function getNthEventName(moduleName: PAnsiChar;
  event: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthEventName';

{ Returns the number of variable-assignment pairs inside event (0-based). }
function getNumAssignmentsForEvent(moduleName: PAnsiChar;
  event: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumAssignmentsForEvent';

{ Returns the trigger condition equation for the given event.
  The caller owns the returned pointer. }
function getTriggerForEvent(moduleName: PAnsiChar;
  event: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getTriggerForEvent';

{ Returns the delay equation for the given event, or "" if there is no delay.
  Returns NULL and sets an error if the module or event does not exist. }
function getDelayForEvent(moduleName: PAnsiChar;
  event: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getDelayForEvent';

{ Returns True if the given event has a delay. }
function getEventHasDelay(moduleName: PAnsiChar;
  event: Cardinal): LongBool; cdecl;
  external LIBANTIMONY name 'getEventHasDelay';

{ Returns the priority equation for the given event, or "" if there is none.
  Returns NULL and sets an error if the module or event does not exist. }
function getPriorityForEvent(moduleName: PAnsiChar;
  event: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getPriorityForEvent';

{ Returns True if the given event has a priority. }
function getEventHasPriority(moduleName: PAnsiChar;
  event: Cardinal): LongBool; cdecl;
  external LIBANTIMONY name 'getEventHasPriority';

{ Returns the value of the persistence flag for the given event (default: False). }
function getPersistenceForEvent(moduleName: PAnsiChar;
  event: Cardinal): LongBool; cdecl;
  external LIBANTIMONY name 'getPersistenceForEvent';

{ Returns the initial trigger value (T0) for the given event (default: True). }
function getT0ForEvent(moduleName: PAnsiChar;
  event: Cardinal): LongBool; cdecl;
  external LIBANTIMONY name 'getT0ForEvent';

{ Returns the 'fromTrigger' flag for the given event trigger (default: True). }
function getFromTriggerForEvent(moduleName: PAnsiChar;
  event: Cardinal): LongBool; cdecl;
  external LIBANTIMONY name 'getFromTriggerForEvent';

{ Returns the variable name targeted by the Nth assignment inside the given event.
  The caller owns the returned pointer. }
function getNthAssignmentVariableForEvent(moduleName: PAnsiChar;
  event: Cardinal; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthAssignmentVariableForEvent';

{ Returns the formula string for the Nth assignment inside the given event.
  The caller owns the returned pointer. }
function getNthAssignmentEquationForEvent(moduleName: PAnsiChar;
  event: Cardinal; n: Cardinal): PAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthAssignmentEquationForEvent';

// ---------------------------------------------------------------------------
//  DNA strands
// ---------------------------------------------------------------------------

{ Returns the number of unique (expanded) DNA strands in the module. }
function getNumDNAStrands(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumDNAStrands';

{ Returns an array of sizes (component counts) for all expanded DNA strands.
  The caller owns the returned pointer. }
function getDNAStrandSizes(moduleName: PAnsiChar): PCardinal; cdecl;
  external LIBANTIMONY name 'getDNAStrandSizes';

{ Returns the size (component count) of the Nth expanded DNA strand. }
function getSizeOfNthDNAStrand(moduleName: PAnsiChar;
  n: Cardinal): Cardinal; cdecl;
  external LIBANTIMONY name 'getSizeOfNthDNAStrand';

{ Returns all expanded DNA strands as a jagged 2-D array of component name strings.
  The caller owns the returned pointer. }
function getDNAStrands(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getDNAStrands';

{ Returns an array of component name strings for the Nth expanded DNA strand.
  Returns NULL and sets an error if the strand does not exist. }
function getNthDNAStrand(moduleName: PAnsiChar;
  n: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthDNAStrand';

{ Returns True if the Nth expanded DNA strand has an open (attachable) end at
  the upstream end (upstream=True) or downstream end (upstream=False). }
function getIsNthDNAStrandOpen(moduleName: PAnsiChar;
  n: Cardinal; upstream: LongBool): LongBool; cdecl;
  external LIBANTIMONY name 'getIsNthDNAStrandOpen';

{ Returns the number of modular (separately-defined) DNA strands in the module. }
function getNumModularDNAStrands(moduleName: PAnsiChar): Cardinal; cdecl;
  external LIBANTIMONY name 'getNumModularDNAStrands';

{ Returns an array of sizes for all modular DNA strands.
  The caller owns the returned pointer. }
function getModularDNAStrandSizes(moduleName: PAnsiChar): PCardinal; cdecl;
  external LIBANTIMONY name 'getModularDNAStrandSizes';

{ Returns all modular DNA strands as a jagged 2-D array of component name strings.
  The caller owns the returned pointer. }
function getModularDNAStrands(moduleName: PAnsiChar): PPPAnsiChar; cdecl;
  external LIBANTIMONY name 'getModularDNAStrands';

{ Returns an array of component name strings for the Nth modular DNA strand.
  Returns NULL and sets an error if the strand does not exist. }
function getNthModularDNAStrand(moduleName: PAnsiChar;
  n: Cardinal): PPAnsiChar; cdecl;
  external LIBANTIMONY name 'getNthModularDNAStrand';

{ Returns True if the Nth modular DNA strand has an open end at the upstream
  (upstream=True) or downstream (upstream=False) end. }
function getIsNthModularDNAStrandOpen(moduleName: PAnsiChar;
  n: Cardinal; upstream: LongBool): LongBool; cdecl;
  external LIBANTIMONY name 'getIsNthModularDNAStrandOpen';

// ---------------------------------------------------------------------------
//  Memory management
// ---------------------------------------------------------------------------

{ Frees every pointer previously handed to you by libAntimony.
  WARNING: Do NOT call this if you have already freed any pointer yourself,
  and do NOT access any library-returned data after calling this function. }
procedure freeAll; cdecl;
  external LIBANTIMONY name 'freeAll';

// ---------------------------------------------------------------------------
//  Defaults
// ---------------------------------------------------------------------------

{ Adds default initial values to all parameters (1.0) and species/rates (0.0)
  in the named module.  Returns True if no such module exists, False otherwise. }
function addDefaultInitialValues(moduleName: PAnsiChar): LongBool; cdecl;
  external LIBANTIMONY name 'addDefaultInitialValues';

{ Controls whether bare numbers in the model are treated as dimensionless (True)
  or of undefined units (False). }
procedure setBareNumbersAreDimensionless(dimensionless: LongBool); cdecl;
  external LIBANTIMONY name 'setBareNumbersAreDimensionless';

implementation

end.
