#include "\x\cba\addons\main\script_macros_common.hpp"
#include "\x\cba\addons\xeh\script_xeh.hpp"

// The unit being controlled, the player or whoever Zeus is remote controlling.
#define CURRENT_UNIT (call CBA_fnc_currentUnit)

// ACE3 is optional: all it adds is the interaction at a door, and these are only reached with it
// loaded - see XEH_postInit in the mirror component.
#define ACE_PREFIX ace
#define ACEGVAR(module,var)         TRIPLES(ACE_PREFIX,module,var)
#define ACEFUNC(module,function)    TRIPLES(DOUBLES(ACE_PREFIX,module),fnc,function)

#define ARR_SELECT(ARRAY,INDEX,DEFAULT) (if (count ARRAY > INDEX) then {ARRAY select INDEX} else {DEFAULT})

#ifdef DISABLE_COMPILE_CACHE
    #undef PREP
    #define PREP(fncName) DFUNC(fncName) = compile preprocessFileLineNumbers QPATHTOF(functions\DOUBLES(fnc,fncName).sqf)
#else
    #undef PREP
    #define PREP(fncName) [QPATHTOF(functions\DOUBLES(fnc,fncName).sqf), QFUNC(fncName)] call CBA_fnc_compileFunction
#endif
