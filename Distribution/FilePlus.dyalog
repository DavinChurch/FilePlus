:Namespace FilePlus
⍝ === VARIABLES ===

AutoHold←0

TreeSize←100


⍝ === End of variables definition ===

(⎕IO ⎕ML ⎕WX)←1 1 3

∇ tieno←{reserved}Create file;⎕TRAP;cwd;relative
     ⍝ Create a new FilePlus component file and initialize it with an empty directory.
     ⍝ Supply a new file name to be created as the right argument.
     ⍝ If the file name given is a full path, then that is the full file name.
     ⍝ If only a partial path is specified, then it is assumed to be relative
     ⍝ to the directory in which ⎕WSID resides.
     ⍝
     ⍝ This utility is only required if a relative-path file name is being
     ⍝ created or if reserved component numbers are to be specified.
     ⍝ All the companion utilities will work correctly with a file that is
     ⍝ simply ⎕FCREATEd (and left empty).
     ⍝
     ⍝ This new file is exclusively tied upon creation.  If immediate sharing
     ⍝ is expected, then the file should be untied and retied right away.
     ⍝
     ⍝ Written 27 November 2005 by Davin Church of Creative Software Design
     ⍝ Converted to Dyalog APL 23 April 2021 by Davin Church of Creative Software Design
     ⍝ Last modified 4 April 2022 by Davin Church of Creative Software Design
     
 ⎕TRAP←,⊂0 'C' '→Crash' ⍝ Errors should exit via error-handling code
      ⍝ Clean up file name
 'Not a file name'⎕SIGNAL 22/⍨((,1)≢⍴⍴1/file)∨~0 2∊⍨10|⎕DR file
 'Missing file name'⎕SIGNAL 22/⍨0=≢file←∆dlt file
 :If ':'=⊃1↓⊃1 ⎕NPARTS'' ⍝ Are we running on a Windows system?
     relative←{~((⊃⍵)∊'/\')∨':'∊⊃1↓⍵}
 :Else ⍝ Unix-style naming
     relative←{'/'≠⊃⍵}
 :EndIf
 :If relative file ⋄ file←(⊃1 ⎕NPARTS ⎕WSID),file ⋄ :EndIf ⍝ It's not a full path, so make file name relative to WS directory
 file←⊃,/1 ⎕NPARTS file ⍝ Convert to a full name
     
      ⍝ Create the file (pass up any system errors)
 tieno←file ⎕FCREATE 0
     
 ⍬(0⍴⊂⍬)⎕FAPPEND tieno ⍝ Start with an empty directory structure in component #1
 :If 2=⎕NC'reserved' ⍝ Did they ask for some component numbers to be reserved?
     :If ~1 3∊⍨10|⎕DR reserved←∊reserved
     :OrIf ∨/reserved<2
         'Invalid reserved component numbers'⎕SIGNAL 11
     :EndIf
          ⍝ Reserved component #s are not necessarily pre-created, but can't be used either
     :While (2⊃⎕FSIZE tieno)∊reserved ⋄ :Until 0=''⎕FAPPEND tieno
     (,¨(reserved ⎕FAPPEND tieno)(⎕UCS 0))⎕FREPLACE tieno,1
 :EndIf
     
 :Return ⍝ Ok, we're ready for use
     
Crash:(⊃⎕DM)⎕SIGNAL ⎕EN ⍝ Pass any errors upwards to caller
∇

∇ result←function Dir file;io;untie;comp;tn;t;sub;sdir;emsg;dpath;spath;mlist;⎕TRAP;fixio;used;hold;sig;cn
     ⍝ Directory management for a FilePlus file.
     ⍝
     ⍝ Syntax:
     ⍝   [result] ← {function} Dir {file} [component]
     ⍝
     ⍝   {file} is either a file name (suitable for use with Tie) or a file tie number.
     ⍝       File names (that are not already tied) are tied & untied with each
     ⍝       call.  Use of file tie numbers (optionally from Tie) are most
     ⍝       efficient for multiple calls.
     ⍝       File names without full paths (drive specification) are assumed to be
     ⍝       relative to the directory in which ⎕WSID resides.
     ⍝   {function} is the operation to be performed, selected from:
     ⍝       '?'     Return a list of all (or selected) existing component names.
     ⍝               (Results includes [;…;] rank indications on array names)
     ⍝       '∊'     Return a boolean to indicate whether or not the named component
     ⍝               or array exists in the file.
     ⍝       '⍳'     Return the internal component # for a named component (0=None).
     ⍝               (Including subscripted names but not on whole arrays.)
     ⍝       '[?]'   Return a sorted list of all (or selected) defined subscript
     ⍝               names/numbers for a given array.
     ⍝       '[⍳]'   Return an array of internal component #s for all (or selected)
     ⍝               subscripts for a given array. This list is returned in the same
     ⍝               order as '[?]' for the same array name argument.
     ⍝       '[>]'   Return the value of the subscript immediately following (in ⍋
     ⍝               order) the subscript that is supplied, or ⍬ if none.
     ⍝       '[<]'   Return the value of the subscript immediately preceeding (in ⍋
     ⍝               order) the subscript that is supplied, or ⍬ if none.
     ⍝       '[+]'   Return a sorted list of all subscripts that use the
     ⍝               named component subscript(s) as a prefix (as if each ended in a
     ⍝               wild-card-matching character).
     ⍝       '↑'     Take control of the named component. An atomic operation that
     ⍝               returns 0 if the component already exists. Otherwise it defines
     ⍝               the component and returns a 1. Use as if it were a hardware-level
     ⍝               test-and-set synchronization operation.
     ⍝       '↓'     Delete the named (or numbered) component from the file.
     ⍝               Deleted components are then available for later re-use.
     ⍝?              (Future thought: Use ↓↓ to also empty the component contents?)
     ⍝       '≠'     Return a list of all user-reserved component numbers.
     ⍝       '⍬'     Return a list of all free-space component numbers.
     ⍝       '⌹'     Validate file directory structure & return unindexed component #s.
     ⍝       (More mnemonic function codes may be invented in the future.)
     ⍝   [component] is a component name, used for some {functions}.
     ⍝       See the description of IO for more details on component names.
     ⍝       The usage of [component] for the various functions is as follows:
     ⍝       '?'     Limit the list of component names to ones containing
     ⍝               (using (1∊⍷)) the given text.  (Optional)
     ⍝       '∊'     The array name or full component name to be checked.  An array name
     ⍝               is a subscripted name with an empty subscript indication ('[;…;]').
     ⍝       '⍳'     The full component name to be located (including complete
     ⍝               subscripts for array items).
     ⍝       '[?]'   Provide a component name to be queried for subscript values.
     ⍝               Include a subscript indication ('[;…;]') after the name with an
     ⍝               appropriate number of semicolons to indicate the rank of the array.
     ⍝               Any (optional) subscript value(s) included in this subscript are to
     ⍝               be used to limit the list of subscripts to those containing
     ⍝               (using (1∊⍷), not as an exact match) the given text.
     ⍝       '[⍳]'   Provide a component name to be queried for component numbers.
     ⍝               Include a subscript indication ('[;…;]') after the name with an
     ⍝               appropriate number of semicolons to indicate the rank of the array.
     ⍝               Any (optional) subscript value(s) included in this subscript are to
     ⍝               be used to limit the list of subscripts to those containing
     ⍝               (using (1∊⍷), not as an exact match) the given text.
     ⍝       '[>]'   The full component name, including subscript, to be used as the
     ⍝               predecessor item. (All-empty subscript requests the lowest key.)
     ⍝       '[<]'   The full component name, including subscript, to be used as the
     ⍝               successor item. (All-empty subscript requests the highest key.)
     ⍝       '[+]'   Provide a component name plus a subscript, but the subscript is
     ⍝               not expected to be an exact match. Instead, the provided subscript
     ⍝               is used as a prefix string and all defined subscripts that begin
     ⍝               with that prefix (using (⊃⍷) on each dimension) are returned.
     ⍝               (Numeric subscripts are matched in their entirety.)
     ⍝       '↑'     The full component name to be acquired.
     ⍝       '↓'     The full component name (or raw component number) to be deleted.
     ⍝               If subscript-notation is used without any subscript values
     ⍝               ('[;…;]'), then ALL subscripts for that name and rank
     ⍝               will be deleted, otherwise it applies only to a single scalar
     ⍝               component or array element.
     ⍝               Unnamed components can be deleted by their raw component number
     ⍝               and they will then be available for re-use.
     ⍝
     ⍝ Written 27 November 2005 by Davin Church of Creative Software Design
     ⍝ Converted to Dyalog APL 24 April 2021 by Davin Church of Creative Software Design
     ⍝ Last modified 21 May 2023 by Davin Church of Creative Software Design
     
 io←(⊃1⌽⎕RSI).⎕IO ⋄ untie←0
 ⎕TRAP←,⊂0 'C' '→Crash' ⍝ Errors should exit via error-handling code
 'Argument Length Error'⎕SIGNAL 5/⍨~(⊂⍴1/file)∊,¨⍳2
 (file comp)←2↑file,'' '' ⍝ Separate arguments
     
     ⍝ *** Process the file ID
 :Select 10|⎕DR file
 :CaseList 1 3 5 ⍝ They gave us a file tie number
     ⎕SIGNAL 18/⍨(1≠≢file)∨~(tn←|⊃∊file)∊⎕FNUMS
 :CaseList 0 2 ⍝ They gave us a file name - temporarily tie it
     untie←0⌈tn←Tie file ⋄ tn←|tn ⍝ Tied & ready for use
 :Else
     'Illegal file name or tie number'⎕SIGNAL 18
 :EndSelect
     
 hold←⌽2 2⊤⌊|⊃∊AutoHold ⍝ Are we providing automatic ⎕FHOLD/:Hold?
 :Hold hold[2]/⊂'FilePlus:',⍕tn ⍝ Conditionally :Hold across application threads
     :If hold[1] ⋄ ⎕FHOLD tn ⋄ :EndIf ⍝ ⎕FHOLD destroys previous ⎕FHOLDs
     
          ⍝ *** Check the file's master directory to make sure it at least appears to be in our file format
     :If 1≠1⊃⎕FSIZE tn ⋄ :GoTo Signal,sig←23 'Missing master file directory' ⋄ :EndIf
     :If 1=2⊃⎕FSIZE tn
         ⍬(0⍴⊂⍬)⎕FAPPEND tn ⍝ Automatically initialize an empty file
     :ElseIf (⊂t←⎕FREAD tn,1)∊⍬''
         ⍬(0⍴⊂⍬)⎕FREPLACE tn,1 ⍝ Correct empty user-created directory
     :ElseIf (,2)≢⍴t ⍝ Does it look about right?
     :OrIf ~(∧/1=(≢⍴)¨t)∧(1≤|≡2⊃t)∧(1=|≡1⊃t)∧1 3∊⍨10|⎕DR 1⊃t
         :GoTo Signal,sig←23 'Invalid master file directory'
     :EndIf
     
          ⍝ *** Component ID processing
     sub←⍬ ⍝ Allow subscript specifications after names...
     :If (0=≢⍴comp)∧5 7∊⍨10|⎕DR comp ⋄ :AndIf comp=⌊|comp ⋄ comp←⌊comp ⋄ :EndIf
     :If (0=≢⍴comp)∧1 3∊⍨10|⎕DR comp ⍝ They gave us a raw component number (for use like a normal file)
              ⍝ We don't need to do anything here - just leave it as-is
     :Else ⍝ They gave us a component name (almost any structure permitted)
              ⍝ *** Named component analysis
              ⍝ Simple scalars (of all non-integer types) are reserved for internal use
         :If 0=≡comp ⋄ comp←,comp ⋄ :EndIf ⍝ Force scalars to 1⍴ vectors
              ⍝ *** Pre-process component name (including subscripts)
         sub←io _subscript comp ⋄ comp←⊃sub ⋄ sub↓⍨←1 ⍝ Allow subscript specifications after names
     :EndIf
     :If (0=≢⍴comp)∧1 3∊⍨10|⎕DR comp ⍝ They gave us a raw component number
     :AndIf ~∨/'↓'∊function          ⍝ Raw component numbers may only be used with '↓'
         :GoTo Signal,sig←11 'A raw component number may not be used with this function'
     :EndIf
     
          ⍝ *** Process function
     :Select ⊃function←,function
     
     :Case '?'               ⍝ === Directory list (of master directory)
         :If ×≢sub ⋄ :GoTo Signal,sig←2 'Invalid use of subscripting' ⋄ :EndIf ⍝ Should we allow rank-searching??
         result←(2⊃1(tn _list 1)comp)~⎕UCS 0 127 ⍝ Return only master name list (optionally restricted by component-name content)
     
     :CaseList '∊⍳↑'         ⍝ === Check for existence; Locate cmp #; Take control of cmp
         :If 0∊⍴comp ⋄ :GoTo Signal,sig←2 'Component name missing' ⋄ :EndIf
         :If ∧/0 1∊×≢¨sub ⋄ :GoTo Signal,sig←2 'Incomplete component subscript' ⋄ :EndIf
         :If (0∊≢¨sub)∧'⍳'=⊃function ⋄ :GoTo Signal,sig←16 'Whole arrays do not have component numbers' ⋄ :EndIf
         :If (0∊≢¨sub)∧'↑'=⊃function ⋄ :GoTo Signal,sig←16 'Whole arrays cannot be acquired' ⋄ :EndIf
         :If 0=sdir←⊃result←dpath←(tn _find(¯1*~'↑'∊function))comp
             :If ~'↑'∊function ⋄ result←0 ⋄ :EndIf ⍝ This component name is not defined with that rank
         :Else
                  ⍝ *** Named component exists - locate it
             :If ×≢sub ⍝ If we've got subscripts, then we'll have a subdirectory
             :AndIf ∧/×≢¨sub ⍝ And they've specified an explicit subscript?
                 result←spath←(tn _find(-sdir))sub
             :EndIf
         :EndIf
         :Select ⊃function
         :Case '∊'          ⍝ Signal presence only
             result←×⊃result
         :Case '⍳'          ⍝ Return component # (or 0)
             result←⊃result
         :Case '↑'          ⍝ Take control of component
             :If 0=⊃result   ⍝ Not defined yet - define it to signal control
                 :If ×≢sub ⍝ Is this for a subdirectory?
                     :If 0=⊃dpath ⍝ We don't even have a subdirectory yet (not found in master directory)
                         cn←tn _append ⍬(0⍴⊂⍬) ⍝ Create a new (empty) subdirectory component
                         cn(tn _insert dpath)comp ⍝ And add it to the master directory
                         spath←(tn _find cn)sub ⍝ Get a not-found pointer into the new (empty) subdirectory
                     :EndIf
                     cn←tn _append ⍬ ⍝ Create a new data component
                     cn(tn _insert spath)sub ⍝ And add it to the (possibly new) subdirectory
                 :Else ⍝ Create a new scalar component
                     cn←tn _append ⍬ ⍝ Create a new data component
                     cn(tn _insert dpath)comp ⍝ And add it to the master directory
                 :EndIf
                 result←1 ⍝ Signal that component # has been acquired
             :Else           ⍝ Already defined - signal failure to take control
                 result←0
             :EndIf
         :EndSelect
     
     :Case '['               ⍝ === Functions for subscripted arrays
         :If 0∊⍴comp ⋄ :GoTo Signal,sig←2 'Component name missing' ⋄ :EndIf
         :If ×≢sub ⍝ Were there the required rank-indicators (at least) on the name?
             :If io=0 ⋄ fixio←{1 3∊⍨10|⎕DR ⍵:⍵-1 ⋄ ⍵} ⋄ :Else ⋄ fixio←⊢ ⋄ :EndIf ⍝ Report ⎕IO=0 back in that origin
             :If 0=sdir←⊃(tn _find ¯1)comp
                 result←⍬ ⍝ This component name is not defined with that rank
             :Else
                 :Select function ⍝ Perform the specifically-requested array function
                 :Case '[?]' ⍝ Are they asking for the entire key list?
                     result←2⊃(2×∨/×≢¨sub)(tn _list sdir)sub
                          ⍝ A list of key values is returned for this function:
                          ⍝   For a 1-D array this is a vector of single sub-values; For an n-D array this is Mixed to an n-column matrix
                     :If 1=≢⊃result ⋄ result←fixio¨⊃¨result ⋄ :Else ⋄ result←fixio¨↑result ⋄ :EndIf
                 :Case '[⍳]' ⍝ Are they asking for component #s only?
                     result←1⊃(2×∨/×≢¨sub)(tn _list sdir)sub
                          ⍝ This is a simple numeric vector
                 :Case '[>]' ⍝ Are they asking for a successor key from this list?
                     result←fixio¨(tn _successor sdir)sub
                          ⍝ Only a single key value is returned for this function:
                          ⍝   For a 1-D array this is Disclosed to a single simple value; For an n-D array this is a [nested] vector of sub-values
                     :If 1=≢result ⋄ result←⊃result ⋄ :EndIf
                 :Case '[<]' ⍝ Are they asking for a predecessor key from this list?
                     result←fixio¨(tn _predecessor sdir)sub
                          ⍝ Only a single key value is returned for this function:
                          ⍝   For a 1-D array this is Disclosed to a single simple value; For an n-D array this is a [nested] vector of sub-values
                     :If 1=≢result ⋄ result←⊃result ⋄ :EndIf
                 :Case '[+]' ⍝ Are they asking for a prefixed-key list?
                     result←2⊃¯2(tn _list sdir)sub
                          ⍝ A list of key values is returned for this function:
                          ⍝   For a 1-D array this is a vector of single sub-values; For an n-D array this is Mixed to an n-column matrix
                     :If 1=≢⊃result ⋄ result←fixio¨⊃¨result ⋄ :Else ⋄ result←fixio¨↑result ⋄ :EndIf
                 :Else
                     :GoTo Signal,sig←11 'Invalid array-subscripting function'
                 :EndSelect
             :EndIf
         :Else
             :GoTo Signal,sig←2 'Component subscript notation missing'
         :EndIf
     
     :Case '↓'               ⍝ === Delete component
         :If (0=≢⍴comp)∧1 3∊⍨10|⎕DR comp ⍝ They gave us a raw component number (when using unnamed components in the file)
                  ⍝ --- Deleting a raw component #
                  ⍝ Check to see if they're trying to delete something they're not supposed to
             :If comp=1
                 :GoTo Signal,sig←20 'Unable to delete master file index component'
             :ElseIf (comp<1⊃⎕FSIZE tn)∨comp≥2⊃⎕FSIZE tn
                 :GoTo Signal,sig←20 'Non-existent component number to delete'
             :ElseIf ×t←⊃(tn _find ¯1)⎕UCS 0 ⍝ Do we have any reserved components?
             :AndIf comp∊⎕FREAD tn,t
                 :GoTo Signal,sig←19 'Unable to delete reserved component number'
             :ElseIf ×t←⊃(tn _find ¯1)⎕UCS 127 ⍝ Do we have any freed components?
             :AndIf comp∊⎕FREAD tn,t
                 :GoTo Signal,sig←19 'Unable to delete unused component number'
             :ElseIf comp∊1⊃mlist←(tn _list 1)'' ⍝ Will be a slow check on big files with subscripts, but important for safety
                 :GoTo Signal,sig←19 'Unable to delete named component by number'
             :ElseIf ×≢t←(×1 _keyrank¨2⊃mlist)/2⊃mlist ⍝ Are any of these names subscripted arrays?
                 :For t :In t ⍝ Loop through all subscripted array names ⍝ This can take a while if they're big
                     :Trap 0
                         used←'∞' '∞'(tn _validate(((2⊃mlist){⎕CT←0 ⋄ ⍺⍳⍵}⊂t)⊃1⊃mlist))1 _keyrank t
                     :Else
                         :GoTo Signal,sig←23 'Unable to delete component number from damaged file'
                     :EndTrap
                     :If comp∊used
                         :GoTo Signal,sig←19 'Unable to delete named component array item by number'
                     :EndIf
                 :EndFor
             :EndIf
             tn _free comp ⍝ This component number is OK to release (it's not indexed anywhere)
         :Else
                  ⍝ --- Deleting a named component
             :If 0∊⍴comp ⋄ :GoTo Signal,sig←2 'Component name missing' ⋄ :EndIf
             :If ∧/0 1∊×≢¨sub ⋄ :GoTo Signal,sig←2 'Incomplete component subscript' ⋄ :EndIf
             :If 0=⊃dpath←(tn _find ¯1)comp ⋄ :GoTo Signal,sig←20 'Component Value Error' ⋄ :EndIf
             :If 0=≢sub
                 tn _free tn _delete dpath ⍝ Remove non-array component name from the master directory
             :Else
                 :If ∧/0=≢¨sub ⍝ Delete the entire array
                     :Trap 0
                         comp←'∞' '∞'(tn _validate(⊃dpath))≢sub ⍝ Get list of all array data & directory components for freeing
                     :Else
                         :GoTo Signal,sig←23 'Unable to delete array from damaged file'
                     :EndTrap
                     comp∪←tn _delete dpath ⍝ Remove the array name itself from the master directory
                     tn _free comp ⍝ Free all the loose pieces
                 :Else ⍝ Delete just one subscript from the array
                     :If 0=⊃spath←(tn _find(-⊃dpath))sub
                         :GoTo Signal,sig←20 'Component Value Error'
                     :Else
                         tn _free tn _delete spath ⍝ Remove and free B-tree entry and the data component
                              ⍝ If that was the last subscript in the array going away, we need to delete the array, too
                         :If (1=1-⍨≢dpath)∧1=2 2⊃dpath ⍝ Shortcut to avoid checking all cases
                         :AndIf 0=⊃(tn _lowest(⊃dpath))⍬ ⍝ See if there's an initial key available
                             tn _free tn _delete dpath ⍝ Get rid of the array name itself from the master directory
                         :EndIf
                     :EndIf
                 :EndIf
             :EndIf
         :EndIf
     
     :Case '≠'               ⍝ === Reserved component list
         :If (,0)≢⍴comp ⋄ :GoTo Signal,sig←2 'Component name not permitted' ⋄ :EndIf
         :If 0=t←⊃(tn _find ¯1)⎕UCS 0 ⍝ Do we have any reserved components?
             result←⍬ ⍝ Nope
         :Else
             result←⎕FREAD tn,t ⍝ These are they
         :EndIf
     
     :Case '⍬'               ⍝ === Free-space (available) component list
         :If (,0)≢⍴comp ⋄ :GoTo Signal,sig←2 'Component name not permitted' ⋄ :EndIf
         :If 0=t←⊃(tn _find ¯1)⎕UCS 127 ⍝ Do we have any free-space components?
             result←⍬ ⍝ Nope
         :Else
             result←{⍵[⍋⍵]}⎕FREAD tn,t ⍝ These are they (sorted)
         :EndIf
     
     :Case '⌹'               ⍝ === Validate directory; return unindexed cmp #s
         :If (,0)≢⍴comp ⋄ :GoTo Signal,sig←2 'Component name not permitted' ⋄ :EndIf
              ⍝ Validate B-tree file root and all connected trees, and return entire list of indexed file components
              ⍝ If an error is detected, _validate will ⎕SIGNAL the problem which will be passed upwards by ⎕TRAP
         result←'∞' '∞'(tn _validate 1)¯1 ⍝ Start at the top and walk all the trees in the file
              ⍝ Ok, we've got the list of all known-used component #s - check them for validity
         :If ∨/t←(result<1⊃⎕FSIZE tn)∨(result≥2⊃⎕FSIZE tn)∨(result≠⌊|result)∨~1 3∊⍨10|⎕DR result
             :GoTo Signal,sig←23('Damaged file!  Invalid component numbers: ',⍕t/result)
         :EndIf
         :If ∨/t←~≠result ⍝ Are there any duplicates?
             :GoTo Signal,sig←23('Damaged file!  Cross-linked components: ',⍕∪t/result)
         :EndIf
              ⍝ The final indexed list looks OK, so return the opposing list of all the (other) un-indexed (manual) component #s
         result~⍨←⍳¯1+2⊃⎕FSIZE tn
     
     :Else
         :GoTo Signal,sig←11 'Unknown function request'
     :EndSelect
 :EndHold
     
 ⎕FUNTIE untie ⍝ Untie any temporary file tie when we're done
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 :Return
     
Signal:⎕FUNTIE untie ⍝ Untie any temporary file tie when we exit with an error
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 ⎕SIGNAL/⌽sig ⍝ Produce a specific APL error (⎕EN,⎕DM)
     
Crash:⎕FUNTIE untie ⍝ Untie any temporary file tie when we get an error
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 (⊃⎕DM)⎕SIGNAL ⎕EN ⍝ Pass any errors upwards to caller
∇

∇ data←{newdata}IO item;cn;comp;file;read;sub;t;tn;untie;io;⎕TRAP;dpath;spath;hold;sig
     ⍝ Read or write a named (or numbered) component of an APL component file.
     ⍝ (File component #1 is reserved for holding the master file directory.)
     ⍝
     ⍝ Syntax:
     ⍝   Reading data:
     ⍝       <data> ← IO <file> <component>
     ⍝   Writing data (append or replace):
     ⍝       <newdata> IO <file> <component>
     ⍝   Append unnamed data directly to a new component:
     ⍝       <newcmpnum> ← <newdata> IO <file> 0
     ⍝
     ⍝ Originally written 27 November 2005 for APL+Win by Davin Church of Creative Software Design
     ⍝ Converted to Dyalog APL 23 April 2021 by Davin Church of Creative Software Design
     ⍝ Last modified 4 April 2022 by Davin Church of Creative Software Design
     
 io←(⊃1⌽⎕RSI).⎕IO ⋄ untie←0 ⋄ read←0=⊃⎕NC'newdata' ⍝ Initialize flags
 ⎕TRAP←,⊂0 'C' '→Crash' ⍝ Errors should exit via error-handling code
 'Argument Length Error'⎕SIGNAL 2/⍨(,2)≢⍴item
 (file comp)←item ⍝ We should always have these two arguments
     
      ⍝ *** Process the file ID
 :Select 10|⎕DR file
 :CaseList 1 3 5 ⍝ They gave us a file tie number
     ⎕SIGNAL 18/⍨(1≠≢file)∨~(tn←|⊃file)∊⎕FNUMS
 :CaseList 0 2 ⍝ They gave us a file name - temporarily tie it
     untie←0⌈tn←Tie file ⋄ tn←|tn ⍝ Tied & ready for use
 :Else
     'Illegal file name or tie number'⎕SIGNAL 18
 :EndSelect
     
 hold←⌽2 2⊤⌊|⊃∊AutoHold ⍝ Are we providing automatic ⎕FHOLD/:Hold?
 :Hold hold[2]/⊂'FilePlus:',⍕tn ⍝ Conditionally :Hold across application threads
     
          ⍝ *** Check the file's master directory
     :If (0=≢⍴comp)∧5 7∊⍨10|⎕DR comp ⋄ :AndIf comp=⌊|comp ⋄ comp←⌊comp ⋄ :EndIf ⍝ Normalize a raw component #
     :If (0=≢⍴comp)∧1 3∊⍨10|⎕DR comp ⍝ If they gave us a raw component number
     :AndIf comp>0 ⍝ (And not asking for an append)
     :AndIf comp<2⊃⎕FSIZE tn ⍝ And it's an existing component #
              ⍝ Then we don't need to spend time & space reading out and checking the main directory
         hold[1]←0 ⍝ And in that case, we don't need to ⎕FHOLD the file on this call either
     :Else ⍝ Pre-check the master directory to make sure it at least appears to be in our file format
         :If hold[1] ⋄ ⎕FHOLD tn ⋄ :EndIf ⍝ ⎕FHOLD destroys previous ⎕FHOLDs
         :If 1≠1⊃⎕FSIZE tn ⋄ :GoTo Signal,sig←23 'Missing master file directory' ⋄ :EndIf
         :If 1=2⊃⎕FSIZE tn
             ⍬(0⍴⊂⍬)⎕FAPPEND tn ⍝ Automatically initialize an empty file
         :ElseIf (⊂t←⎕FREAD tn,1)∊⍬''
             ⍬(0⍴⊂⍬)⎕FREPLACE tn,1 ⍝ Correct empty user-created directory
         :ElseIf (,2)≢⍴t ⍝ Does it look about right?
         :OrIf ~(∧/1=(≢⍴)¨t)∧(1≤|≡2⊃t)∧(1=|≡1⊃t)∧1 3∊⍨10|⎕DR 1⊃t
             :GoTo Signal,sig←23 'Invalid master file directory'
         :EndIf
     :EndIf
     
          ⍝ *** Component ID processing
     :If (0=≢⍴comp)∧1 3∊⍨10|⎕DR comp ⍝ They gave us a raw component number (for use like a normal file)
     
              ⍝ *** Raw component # processing
         :If read            ⍝ --- Read component (by raw number)
             :If comp>0
                 data←⎕FREAD tn,comp
             :Else
                 :GoTo Signal,sig←20 'Invalid raw component number'
             :EndIf
         :ElseIf comp>0      ⍝ --- Write (replace) component (by raw number)
             :If comp≥2⊃⎕FSIZE tn ⍝ If the component # doesn't exist yet
                 tn _fillto comp ⍝ Make sure that component # is the next one to be appended
                 comp←newdata ⎕FAPPEND tn ⍝ Store it new
             :Else
                 newdata ⎕FREPLACE tn,comp ⍝ Store it in-place
             :EndIf
         :ElseIf comp=0      ⍝ --- Append (numbered) component - return new number
             data←tn _append newdata ⍝ A logical append (reusing space if available)
         :Else
             :GoTo Signal,sig←20 'Invalid raw component number'
         :EndIf
     
     :Else ⍝ They gave us a component name (almost any structure permitted)
     
              ⍝ *** Named component analysis
              ⍝ Simple scalars (of all non-integer types) are reserved for internal use
         :If 0=≡comp ⋄ comp←,comp ⋄ :EndIf ⍝ Force scalars to 1⍴ vectors
     
         sub←io _subscript comp ⋄ comp←⊃sub ⋄ sub↓⍨←1 ⍝ Allow subscript specifications after names
         :If 0∊⍴comp ⍝ Empty arrays of any type are prohibited
             :GoTo Signal,sig←2 'Component name missing'
         :EndIf
         :If 0∊≢¨sub
             :GoTo Signal,sig←2 'Component subscript missing or incomplete'
         :EndIf
     
              ⍝ *** Locate/create component name (and any subscripts) in directory/subdirectory
         :If 0≠cn←⊃dpath←(tn _find(¯1*read))comp ⍝ Is this component name found in the master directory?
             :If ×≢sub ⍝ If we've got subscripts, then we'll have a subdirectory to follow
                 cn←⊃spath←(tn _find(cn×¯1*read))sub ⍝ Look up subscript in B-tree subdirectory
             :EndIf
         :EndIf
     
              ⍝ *** Named component processing
         :If read            ⍝ --- Read component (by name)
             :If cn>0
                 data←⎕FREAD tn,cn ⍝ Just read the data component and we're done
             :Else
                 :GoTo Signal,sig←20 'Component Value Error'
             :EndIf
         :Else               ⍝ --- Write [new] component (by name)
             :If cn>0 ⍝ Replace existing component
                 newdata ⎕FREPLACE tn,cn ⍝ Update the data component
             :Else ⍝ Append a new component
                 :If ×≢sub ⍝ Is this for a subdirectory?
                     :If 0=⊃dpath ⍝ We don't even have a subdirectory yet (not found in master directory)
                         cn←tn _append ⍬(0⍴⊂⍬) ⍝ Create a new (empty) subdirectory component
                         cn(tn _insert dpath)comp ⍝ And add it to the master directory
                         spath←(tn _find cn)sub ⍝ Get a not-found pointer into the new (empty) subdirectory
                     :EndIf
                     cn←tn _append newdata ⍝ Create a new data component
                     cn(tn _insert spath)sub ⍝ And add it to the (possibly new) subdirectory
                 :Else ⍝ Create a new scalar component
                     cn←tn _append newdata ⍝ Create a new data component
                     cn(tn _insert dpath)comp ⍝ And add it to the master directory
                 :EndIf
             :EndIf
         :EndIf
     :EndIf
 :EndHold
     
 ⎕FUNTIE untie ⍝ Untie any temporary file tie when we're done
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 :Return
     
Signal:⎕FUNTIE untie ⍝ Untie any temporary file tie when we exit with an error
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 ⎕SIGNAL/⌽sig ⍝ Produce a specific APL error (⎕EN,⎕DM)
     
Crash:⎕FUNTIE untie ⍝ Untie any temporary file tie when we get an error
 :If hold[1] ⋄ ⎕FHOLD ⍬ ⋄ :EndIf ⍝ All ⎕FHOLDs may be released
 (⊃⎕DM)⎕SIGNAL ⎕EN ⍝ Pass any errors upwards to caller
∇

∇ {was}←Sharing is
     ⍝ Query or set the FilePlus auto-hold feature to manage shared data files
     ⍝ Provide a ⍬ to query the current auto-hold setting.
     ⍝ Provide an integer from 0 through 3 to change the current auto-hold setting.
     ⍝   0=No holding
     ⍝   1=Perform ⎕FHOLD
     ⍝   2=Perform :Hold
     ⍝   3=Perform both kinds of holding
     ⍝ Returns the value of the previous setting.
     ⍝
     ⍝ Written 5 June 2022 by Davin Church of Creative Software Design
     
 was←AutoHold
 :If 0≠≢is
     'Invalid setting (use 0, 1, 2, or 3)'⎕SIGNAL 11/⍨~(⊂is)∊0 1 2 3
     AutoHold←⌊⊃is
 :EndIf
∇

∇ tienum←{exclusive}Tie file;⎕TRAP;t;UC;relative
     ⍝ Tie or untie a FilePlus or standard APL component file
     ⍝ Provide a file name to tie to next available number; or number(s) to untie.
     ⍝ Tying a file returns the new file tie number (possibly negative, see below).
     ⍝ If a file name given is a full path, then that is the full file name.
     ⍝ If only a partial path is specified, then it is assumed to be relative to
     ⍝ the directory in which ⎕WSID resides.
     ⍝
     ⍝ This utility is only needed if:
     ⍝   * a relative file name is being supplied
     ⍝   * detection of an already-tied file (where possible) is desired
     ⍝   * special tying options are desired
     ⍝ otherwise a simple ⎕FTIE/⎕FSTIE is sufficient.
     ⍝ If the above options are desired (such as relative naming), it may be used
     ⍝ by itself (without using IO) to perform the work on standard files.
     ⍝
     ⍝ An optional left argument may be supplied with one to three values:
     ⍝   [1] Specify file tie number to use (if needed and available) [0=default]
     ⍝   [2] Exclusively tie (1) the file instead of share-tying it (0) [default]
     ⍝       This is ignored if the file is already tied.
     ⍝   [3] Require (1) read/write access to the file, or don't check (0) [default]
     ⍝
     ⍝ Written 27 November 2005 by Davin Church of Creative Software Design
     ⍝ Converted to Dyalog APL 23 April 2021 by Davin Church of Creative Software Design
     ⍝ Last modified 4 April 2022 by Davin Church of Creative Software Design
     
 ⎕TRAP←,⊂0 'C' '→Crash' ⍝ Errors should exit via error-handling code
 :If 1 3 5 7∊⍨10|⎕DR file
     :If ×≢t←|(,file∊⎕FNUMS,-⎕FNUMS)/,file ⋄ ⎕FUNTIE t ⋄ :EndIf ⍝ Just untie normally-tied file(s)
 :Else ⍝ We want to tie the file
          ⍝ Clean up file name
     'Not a file name'⎕SIGNAL 22/⍨((,1)≢⍴⍴1/file)∨~0 2∊⍨10|⎕DR file
     'Missing file name'⎕SIGNAL 22/⍨0=≢file←∆dlt file
     :If ':'=⊃1↓⊃1 ⎕NPARTS'' ⍝ Are we running on a Windows system?
         :If 18≤2⊃⎕VFI 4↑2⊃'.'⎕WG'APLVersion' ⋄ UC←1∘⎕C ⋄ :Else ⋄ UC←1∘(819⌶) ⋄ :EndIf ⍝ Upper-case checking
         relative←{~((⊃⍵)∊'/\')∨':'∊⊃1↓⍵}
     :Else ⍝ Unix-style naming
         UC←⊢ ⋄ relative←{'/'≠⊃⍵}
     :EndIf
     :If relative file ⋄ file←(⊃1 ⎕NPARTS ⎕WSID),file ⋄ :EndIf ⍝ It's not a full path, so make file name relative to WS directory
     file←⊃,/1 ⎕NPARTS file ⍝ Convert to a full name
     :If 0=⎕NC'exclusive' ⋄ exclusive←⍬ ⋄ :EndIf
     exclusive←3↑exclusive ⋄ exclusive[1]←0⌈⌊exclusive[1]
     'Argument flags must be boolean'⎕SIGNAL 11/⍨~∧/exclusive[2 3]∊0 1
          ⍝ See if it's already tied (any capitalization if Windows)
     :If ∨/t←(UC¨⊃¨,/¨1 ⎕NPARTS ∆dlt¨↓⎕FNAMES)∊⊂UC file
              ⍝ The named file is already tied - return its tie number, but negatively
         tienum←-⊃t/⎕FNUMS ⍝ Show that it's already tied (a negative number)
     :Else
         'Not an actual file name'⎕SIGNAL 22/⍨2≠1 ⎕NINFO file ⍝ Verify type of tie
         :If exclusive[3] ⍝ They say they've got to have R/W access
         :AndIf 1≠12 ⎕NINFO⍠('Follow' 1)⊢file ⍝ But we've only got R/O access
             'Only read access is available'⎕SIGNAL 19
         :EndIf
              ⍝ Tie the file to a new or requested-available tie number
         exclusive[1]←exclusive[1]×~exclusive[1]∊⎕FNUMS ⍝ Ignore tie number if already in use elsewhere
         :If exclusive[2]
             tienum←file ⎕FTIE exclusive[1] ⍝ Exclusive-tie the file
         :Else
             tienum←file ⎕FSTIE exclusive[1] ⍝ Share-tie the file
         :EndIf
     :EndIf
 :EndIf
     
 :Return ⍝ All done
     
Crash:(⊃⎕DM)⎕SIGNAL ⎕EN ⍝ Pass any errors upwards to caller
∇

∇ trim←{rmv}∆dlt data;⎕IO;⎕ML;keep
     ⍝∇ <D>eletes <L>eading and <T>railing spaces
     ⍝∇ (or zeros/prototypes/∆dlt-prototypes) from the rows of any array.
     ⍝∇ A left argument may be specified with a vector of item values
     ⍝∇ to be removed instead of spaces/zeros/[∆dlt-]prototypes.
     ⍝ A "∆dlt-prototype", defined as the ∆dlt of the prototype,
     ⍝ is additionally removed when the data is nested.
     ⍝ For convenience, if both the left and right arguments are given as
     ⍝ simple (unnested) values, and their datatypes (character or numeric)
     ⍝ are different, then the right argument will be returned unchanged
     ⍝ (not even ravelled, as can otherwise be common for this function).
     ⍝ For instance, this allows the removal of spaces from each item
     ⍝ of a nested array without ravelling any numeric scalars that may
     ⍝ also be found in that array.
     ⍝
     ⍝ Last modified 10 October 2011 by Davin Church of Creative Software Design
     ⍝ Converted to Dyalog 12 October 2019 by Davin Church of Creative Software Design
     
 ⎕IO←⎕ML←1
 :If 0≠⎕NC'rmv' ⋄ :AndIf ~6∊10|⎕DR¨rmv data ⋄ :AndIf ≠/⊃¨0⍴¨rmv data
     trim←data ⋄ :Return ⍝ Different datatypes - return input unchanged
 :EndIf
 :If 0=⎕NC'rmv' ⋄ :AndIf 1<|≡rmv←1↑0⍴data ⋄ rmv,←∆dlt¨rmv ⋄ :EndIf
 keep←~data∊rmv ⋄ keep←(∨\keep)∧⌽∨\⌽keep
 trim←+/keep ⋄ trim←trim∘.≥⍳⌈/0,,trim ⋄ trim←(⍴trim)⍴(,trim)\(,keep)/,data
∇

∇ component←(tn _append)data;at;unused;reserved
⍝ Logically append a new data component to the file (reuse free space if available)

 :If 0≠at←1⊃(tn _find ¯1)⎕UCS 127 ⍝ Do we already have a free-space component?
 :AndIf ×≢unused←⎕FREAD tn,at ⍝ And it's not empty
     data ⎕FREPLACE tn,component←⊃unused ⍝ Use the oldest available component # & write their data to it
     (1↓unused)⎕FREPLACE tn,at ⍝ Remove it from the free-list
 :Else ⍝ Nothing is free for reuse
     :If 0≠at←⊃(tn _find ¯1)⎕UCS 0 ⋄ reserved←⎕FREAD tn,at ⍝ Need to skip over any reservations?
         :While (2⊃⎕FSIZE tn)∊reserved ⋄ :Until 0=''⎕FAPPEND tn
     :EndIf
     component←data ⎕FAPPEND tn ⍝ Create a fresh component with the data
 :EndIf
∇

∇ free←(tn _delete)path;root;at;ptrs;keys;bmax;bmin;rebalance;limbs;limb1;limb2;st;branch;leaf
⍝ Remove the item at this path and return list of component numbers to be freed (including path[1])
⍝ {path} is defined as the result of _find, where path[1]≠0

 'Unable to delete missing component'⎕SIGNAL 11/⍨0=free←⊃path
 (root at)←⊃path←1↓path ⍝ Where will we start searching?
 bmax←4⌈⌊|⊃∊TreeSize ⋄ bmin←¯1+⌈bmax÷2 ⍝ Adjustable B-tree size
 :If =/≢¨(ptrs keys)←⎕FREAD tn,root ⍝ This is a leaf node - just remove this item by itself
     (ptrs keys)/⍨←⊂at≠⍳≢ptrs ⍝ Remove this item from the node & update
     ptrs keys ⎕FREPLACE tn,root
     rebalance←(bmin>≢keys)/⊃¨path ⍝ Will this path need rebalancing?
 :Else ⍝ This is an internal node so reconstruction is required
     limbs←ptrs[¯1 1+2×at] ⋄ limb1←limb2←⍬ ⍝ Check predecessor and successor child branches
     :If bmin<≢2⊃limb1←⎕FREAD tn,st←limbs[1] ⍝ Check size of left child - above minimum size?
     :OrIf bmin<≢2⊃limb2←⎕FREAD tn,st←limbs[2] ⍝ Check size of right child - above minimum size?
     :OrIf (×st←limbs[2])∧×≢2⊃limb2 ⍝ Remove from a deficient right child (there better be some)
     :OrIf (×st←limbs[1])∧×≢2⊃limb1 ⍝ Remove from a deficient left child (there better be some)
         :Select st ⍝ Locate largest/smallest key value in that subtree
         :Case limbs[1] ⋄ branch←(tn _highest st)⍬
         :Case limbs[2] ⋄ branch←(tn _lowest st)⍬
         :EndSelect
         ptrs[2×at]←branch[1] ⋄ keys[at]←branch[2] ⍝ Move it up to replace the deleted key
         ptrs keys ⎕FREPLACE tn,root
         leaf←⎕FREAD tn,3 1⊃branch ⍝ Now it's time to get rid of the leaf that was moved
         leaf/¨⍨←⊂branch[1]≠1⊃leaf ⍝ Remove moved item from leaf & update
         leaf ⎕FREPLACE tn,3 1⊃branch
         rebalance←(bmin>≢2⊃leaf)/⊣/¨(2↓branch),path ⍝ Will this path need rebalancing?
     :Else ⍝ Both predecessor and successor child branches are empty!
         'Both empty neighbor siblings found in B-Tree!'⎕SIGNAL 23
     :EndIf
 :EndIf
 :If ×≢rebalance ⋄ free∪←(tn _rebalance)rebalance ⋄ :EndIf ⍝ Rebalance underflow nodes
∇

∇ (tn _fillto)comp;tn;at;reserved;size
⍝ Prepare the file for appending to a specific component number (beyond the end of the existing file)

 :If comp≤size←2⊃⎕FSIZE tn ⋄ :Return ⋄ :EndIf ⍝ It doesn't need any filling
 reserved←⍬ ⋄ :If 0≠at←⊃(tn _find ¯1)⎕UCS 0 ⋄ reserved←⎕FREAD tn,at ⋄ :EndIf ⍝ Need to skip over any reservations?
 ⍝ Now let's fill the file up to that point so they can append their data and mark the unused ones as free
 tn _free reserved~⍨((comp-size)⍴⊂'')⎕FAPPEND¨tn
∇

∇ path←{route}(tn _find root)key;bmax;read;ptrs;keys;at;free;lptr;hptr;limb1;limb2;pptrs;pkeys;t;pk;st;⎕CT
⍝ Locate a key in the B-tree starting at the given root.
⍝ If full nodes are encountered along the way, pre-split them to leave enough room for insertions.
⍝ Right operand:
⍝      File component # containing the root of the B-tree.
⍝      If root<0, then this is a read-only operation starting at |root (don't pre-split nodes).
⍝ Right argument:
⍝      The key value to be located within the B-tree.
⍝ Result:
⍝      path[1]←Component # (scalar) that contains the data for the requested key
⍝          If path[1]=0 then the key was not found and path[2] is cmp/ndx where it should be inserted.
⍝      (1↓path)←Nested vector of the reverse-path back through the B-tree
⍝          (1⊃¨1↓path)←Component # of the tree node in the path
⍝          (2⊃¨1↓path)←Key-subscript into that node that is ≥ the requested key

 bmax←4⌈⌊|⊃∊TreeSize ⍝ Adjustable B-tree size
 ⎕CT←0 ⍝ ≡ needs to perform exact comparisons like ⍋/⍸
 read←root<0 ⋄ :If 0=⎕NC'route' ⋄ route←⍬ ⋄ :EndIf ⍝ Route is used internally for recursive calls
 (ptrs keys)←⎕FREAD tn,root←|root ⍝ Obtain the B-tree root node to search

 :If (~read)∧bmax≤≢keys ⍝ Pre-split this large (full) node before proceeding
     at←⌈2÷⍨1+≢keys ⋄ free←⍬ ⍝ Determine split point (the key value to move up into parent)
     ⍝ It would be possible to split new keys unevenly but that has advantages only if the keys are
     ⍝ mostly created in order, and that isn't necessarily how it would usually be done.
     :If =/≢¨ptrs keys ⍝ This is a leaf node being split (to leave room for inserting)
         :If 0=≢route ⍝ Check for a parent component
             ⍝ If no parent exists (this is the tree root and only leaf node),
             ⍝ reuse this for a new root separating two new children.
             lptr←tn _append limb1←(at-1)↑¨ptrs keys ⍝ Create two new subtrees
             hptr←tn _append limb2←at↓¨ptrs keys
             ((ptrs←lptr,ptrs[at],hptr)(keys←,keys[at]))⎕FREPLACE tn,root ⍝ Redefine the parent tree limb safely
         :Else ⍝ If we have a parent, we have to modify it
             at-←keys[at]≡⊂key ⍝ Let's never move the desired key up into the parent where we can no longer see it
             (pptrs pkeys)←⎕FREAD tn,1 1⊃route ⍝ Get the parent to hold the new pointers
             hptr←tn _append limb2←at↓¨ptrs keys ⍝ Make one new subtree to be the right child
             t←1 2⊃route ⍝ This is the pptrs location after which we need to insert the new key + child ptr
             pptrs←(t↑pptrs),ptrs[at],hptr,t↓pptrs ⍝ Insert new parent separator pointers
             lptr←tn _append limb1←(at-1)↑¨ptrs keys ⍝ Redefine split (left) child subtree
             pptrs[pptrs⍳root]←lptr ⋄ free,←root ⍝ Point to the fresh copy of the child and mark old one dead
             t←2÷⍨t-1 ⍝ This is the pkeys location after which we need to insert the new key value
             pkeys←(t↑pkeys),(⊂pk←at⊃keys),t↓pkeys ⍝ Insert new parent key
             ⍝ Update parent with above changes
             pptrs pkeys ⎕FREPLACE tn,1 1⊃route ⍝ (A direct replacement is safe - it's the last step in the split process)
             ⍝ Now, figure out which of my split children now points to the desired search key
             :Select ⊃⍋⍋key pk ⍝ Which do we want to continue with?
             :Case 1 ⋄ (ptrs keys)←limb1 ⋄ root←lptr ⍝ Search left child
             :Case 2 ⋄ (ptrs keys)←limb2 ⋄ root←hptr ⍝ Search right child
             :EndSelect
         :EndIf
     :Else ⍝ This is a branch node being split
         :If 0=≢route ⍝ Check for a parent component
             ⍝ If no parent exists (this is the tree root), reuse this for a new root splitting into two new children
             lptr←tn _append limb1←(1 0+2 1×at-1)↑¨ptrs keys ⍝ Create two new subtrees
             hptr←tn _append limb2←(2 1×at)↓¨ptrs keys
             ((ptrs←lptr,ptrs[2×at],hptr)(keys←,keys[at]))⎕FREPLACE tn,root ⍝ Redefine the parent tree limb safely
         :Else ⍝ If we have a parent, we have to modify it instead
             at-←keys[at]≡⊂key ⍝ Let's never move the desired key up into the parent where we can no longer see it
             (pptrs pkeys)←⎕FREAD tn,1 1⊃route ⍝ Get the parent to hold the new pointers
             hptr←tn _append limb2←(2 1×at)↓¨ptrs keys  ⍝ Make one new subtree to be the right child
             t←1 2⊃route ⍝ This is the pptrs location after which we need to insert the new key + child ptr
             pptrs←(t↑pptrs),ptrs[2×at],hptr,t↓pptrs ⍝ Insert new parent separator pointers
             lptr←tn _append limb1←(1-⍨2 1×at)↑¨ptrs keys ⍝ Redefine split (left) child subtree
             pptrs[pptrs⍳root]←lptr ⋄ free,←root ⍝ Point to the fresh copy of the child
             t←2÷⍨t-1 ⍝ This is the pkeys location after which we need to insert the new key value
             pkeys←(t↑pkeys),(⊂pk←at⊃keys),t↓pkeys ⍝ Insert new parent key
             ⍝ Update parent with above changes
             pptrs pkeys ⎕FREPLACE tn,1 1⊃route ⍝ (A direct replacement is safe - it's the last step in the split process)
             ⍝ Now, figure out which of my split children now points to the desired search key
             :Select ⊃⍋⍋key pk ⍝ Which do we want to continue with?
             :Case 1 ⋄ (ptrs keys)←limb1 ⋄ root←lptr ⍝ Search left child
             :Case 2 ⋄ (ptrs keys)←limb2 ⋄ root←hptr ⍝ Search right child
             :EndSelect
         :EndIf
     :EndIf
     tn _free free ⍝ We may need to create/update the free list with new component #s
 :EndIf

 :If ×(1+≢keys)|at←keys⍸⊂key ⍝ Where should this go in the list of keys?
 :AndIf key≡at⊃keys ⍝ Is it an exact match?
     ⍝ This is found directly in this node (most often a leaf) - just use it
     path←(ptrs[at×2-=/≢¨keys ptrs])(root,at)
 :Else ⍝ Time for a B-tree search
     :If =/≢¨ptrs keys ⍝ This is a leaf node
         path←0,⊂root,at+1 ⍝ Key value not found - return where it should be inserted
     :Else
         st←1+2×at ⍝ The sub-tree pointer position
         path←((,⊂root,st)(tn _find(ptrs[st]×¯1*read))key),⊂root,at+1 ⍝ Follow the branch recursively
     :EndIf
 :EndIf
∇

∇ (tn _free)components;at;cn
⍝ Mark listed component numbers as unused and reusable

 :If 0=≢components←∪components ⋄ :Return ⋄ :EndIf ⍝ Nothing to be freed
 :If 0≠⊃at←(tn _find 1)⎕UCS 127 ⍝ Do we already have a free-space component in the master directory?
     (components∪⎕FREAD tn,⊃at)⎕FREPLACE tn,⊃at ⍝ Just in-place update the list we've already got
 :Else
     cn←,tn _append,components ⍝ Create the new free-list component
     cn(tn _insert at)⎕UCS 127 ⍝ Add it to our master directory
 :EndIf
∇

∇ path←(tn _highest root)empty;ptrs;keys
⍝ Find the highest key in the B-tree starting at {root}
⍝
⍝ Argument:
⍝       The value to be returned as a result in path[2] if the whole tree is empty
⍝
⍝ Result:
⍝      path[1]←Component # (scalar) that contains the data for the highest key
⍝          If path[1]=0 then the tree is empty and there is no highest key
⍝      path[2]←The largest key value in the tree (or the supplied {empty} value if none)
⍝      (2↓path)←Nested vector of the reverse-path back through the B-tree
⍝          (1⊃¨2↓path)←Component # of the tree node in the path
⍝          (2⊃¨2↓path)←Key-subscript into that node [always 1+≢keys for branches; ≢keys for leaves]

 (ptrs keys)←⎕FREAD tn,root ⋄ path←⊂root,1+≢keys ⍝ Follow the pointer-path through the tree, starting here
 ⍝ Traversing the highest branch-path through the tree
 :While ≠/≢¨ptrs keys ⋄ (ptrs keys)←⎕FREAD tn,root←⊢/ptrs ⋄ path←(⊂root,1+≢keys),path ⋄ ⋄ :EndWhile
 ⍝ Now we're at a leaf node - return the largest key value & location (if any)
 :If 0=≢keys ⋄ path←0 empty,path ⋄ :Else ⋄ path←(⊢/ptrs),(⊢/keys),(⊂root,≢keys),1↓path ⋄ :EndIf
∇

∇ component(tn _insert path)key;leaf;t
⍝ Insert a new data component number with its key to the B-tree at the location specified by path
⍝ Right operand:
⍝      path must have been pre-defined by _find and path[1] must be 0
⍝ Left argument:
⍝      component number where the actual data has already been stored
⍝ Right argument:
⍝      key to be inserted into the B-tree at the given path-location

 ⍝ Insert new component # & key value into B-tree leaf node (this must be a leaf node to get here)
 leaf←⎕FREAD tn,2 1⊃path ⍝ Get the leaf node to modify with a new entry
 t←1-⍨2 2⊃path ⋄ leaf←(t↑¨leaf),¨component(⊂key),¨t↓¨leaf ⍝ There will always be room
 leaf ⎕FREPLACE tn,2 1⊃path ⍝ Put the modified leaf node back
∇

 _keyrank←{ ⍝ Determine if this is a subscripted name, and if so, its rank
     ~⍺⍺:0 ⍝ If not working on the master directory, it's never a subscripted name
     ~(0 2∊⍨10|⎕DR ⍵)∧(1=≢⍴⍵)∧'['∊⍵:0 ⍝ Must be a simple character vector containing a '['
     ~(1=≢⍵∩'[')∧(1=≢⍵∩']')∧(']'=⊢/⍵)∧'['≠⊣/⍵:0 ⍝ Must have exactly one '[' and one ']' and end with ']' but not begin with '['
     ~(∧/r←';'=(⍵⍳'[')↓¯1↓⍵):0 ⍝ Must have only ';' (if anything) between '[]'
     1+≢r ⍝ The number of ';' is 1 fewer than the array rank
 }


∇ list←{depth}(tn _list root)search;ptrs;keys;this;match
⍝ Get a list of all the key values (2⊃{list}) and their ultimate data pointers (1⊃{list}) in the B-tree starting at {root}
⍝ When (×≢search)∧depth≠0, pre-limit results to those keys containing that search value as a substring (1∊⍷) or prefix (⊃⍷).
⍝ If depth=1, search within entire key value; if depth=2, search for multiple (nested) keys at once in matching dimensions.
⍝ If depth∊¯1 ¯2, search for (1-or-2-type) values as prefixes instead of contents.

 :If 0=⎕NC'depth' ⋄ depth←0 ⋄ :EndIf ⍝ Default search depth to not search at all
 match←1⍨ ⍝ Typically just return everything (always matches) in list (when not searching)
 :Select depth                                                  ⍝ See if they want to restrict the results
 :Case 1 ⋄ :If ×≢search ⋄ match←search{1∊⍺⍺⍷⍵} ⋄ :EndIf         ⍝ Whole value contains ⍵
 :Case 2 ⋄ :If ×≢search ⋄ match←search{∧/1∊¨⍺⍺⍷¨,¨⍵} ⋄ :EndIf   ⍝ Each item (⍴ must match) contains each ⍵
 :Case ¯1 ⋄ :If ×≢search ⋄ match←search{⊃⍺⍺⍷⍵} ⋄ :EndIf         ⍝ Whole value begins with ⍵
 :Case ¯2 ⋄ :If ×≢search ⋄ match←search{∧/⊃¨⍺⍺⍷¨,¨⍵} ⋄ :EndIf   ⍝ Each item (⍴ must match) begins with each ⍵
 :EndSelect
 ⍝ Prefix-searching might be improved by using TAO knowledge to check only a range of keys in certain circumstances,
 ⍝ but it probably won't be worth the effort for such uncommon situations.

 :If =/≢¨(ptrs keys)←⎕FREAD tn,root ⍝ This is a leaf node - just return the keys & pointers
     list←(⊂match¨keys)/¨ptrs keys ⍝ Return all matching items of leaf node
 :Else ⍝ A branch node contains mixed keys and subtrees in interleaved order
     list←2⍴⊂⍬ ⍝ Accumulate entire tree (from here)
     :While ×≢ptrs ⍝ Loop through limbs one at a time
         list,¨←depth(tn _list(⊃ptrs))search ⋄ ptrs↓⍨←1 ⍝ Recurse down through the tree at each limb
         :If ×≢keys ⍝ If there are still leaf values remaining
         :AndIf match⊃keys ⍝ And this one matches
             list,¨←1↑¨ptrs keys ⍝ Append next (matching) search value
         :EndIf
         (ptrs keys)↓⍨←1 ⍝ Until there aren't any more left
     :EndWhile
 :EndIf
∇

∇ path←(tn _lowest root)empty;ptrs;keys
⍝ Find the lowest key in the B-tree starting at {root}
⍝
⍝ Argument:
⍝       The value to be returned as a result in path[2] if the whole tree is empty
⍝
⍝ Result:
⍝      path[1]←Component # (scalar) that contains the data for the lowest key
⍝          If path[1]=0 then the tree is empty and there is no lowest key
⍝      path[2]←The smallest key value in the tree (or the supplied {empty} value if none)
⍝      (2↓path)←Nested vector of the reverse-path back through the B-tree
⍝          (1⊃¨2↓path)←Component # of the tree node in the path
⍝          (2⊃¨2↓path)←Key-subscript into that node [always 1]

 (ptrs keys)←⎕FREAD tn,root ⋄ path←⊂root,1 ⍝ Follow the pointer-path through the tree, starting here
 ⍝ Traversing the lowest branch-path through the tree
 :While ≠/≢¨ptrs keys ⋄ (ptrs keys)←⎕FREAD tn,root←⊣/ptrs ⋄ path←(⊂root,1),path ⋄ :EndWhile
 ⍝ Now we're at a leaf node - return the smallest key value & location (if any)
 :If 0=≢keys ⋄ path←0 empty,path ⋄ :Else ⋄ path←(⊣/ptrs),(⊣/keys),path ⋄ :EndIf
∇

∇ prevkey←(tn _predecessor root)key;ptrs;keys;at;path;found
⍝ Find the predecessor (or last) key value in a B-tree (⍬ if non-existant)

 :If ∧/0=≢¨key ⍝ Are we looking for the highest (last) key in the tree?
     prevkey←2⊃(tn _highest root)⍬ ⍬ ⍝ We only return the (last) key value itself
 :Else
     found←0≠⊃path←(tn _find(-root))key
     :While ×≢path←1↓path
         (ptrs keys)←⎕FREAD tn,1 1⊃path ⋄ at←1 2⊃path
         :If at>1-found∧≠/≢¨ptrs keys ⋄ :Leave ⋄ :Else ⋄ found←0 ⋄ :EndIf
     :EndWhile
     :If 0=≢path
         prevkey←⍬
     :ElseIf found∧≠/≢¨ptrs keys
         prevkey←2⊃(tn _highest((¯1+2×at)⊃ptrs))⍬ ⍬ ⍝ Look for the lowest key value in the following sub-tree
     :Else
         prevkey←(at-1)⊃keys
     :EndIf
 :EndIf
∇

∇ free←(tn _rebalance)path;ptrs;keys;bmax;bmin;limbs;limb1;limb2;st;branch;leaf;pptrs;pkeys;sibling;sib;sibat;lptr;at
⍝ Rebalance the nodes in this reverse-path through the tree and return any new component numbers that need to be freed
⍝ {path} is the complete reverse-path (component #s only) through the B-tree starting with the deficient node

 bmax←4⌈⌊|⊃∊TreeSize ⋄ bmin←¯1+⌈bmax÷2 ⍝ Adjustable B-tree size
 path,⍨←0 ⋄ free←⍬ ⍝ The bottom-up ancestor-path through which we need to balance nodes
 :While 2≤≢path←1↓path ⍝ Rebalance up to but not including the tree root
     (ptrs keys)←⎕FREAD tn,path[1] ⍝ Start with the node that needs rebalancing
     :If bmin≤≢keys ⋄ :Leave ⋄ :EndIf ⍝ This node already has sufficient keys - why did we get here?
     (pptrs pkeys)←⎕FREAD tn,path[2] ⍝ We need to rotate through the parent node
     at←pptrs⍳path[1] ⍝ Where does the parent point to us?
     :While bmin>≢keys ⍝ Loop in case we're deficient by more than one key
         ⍝ It's feasible to rotate more than one key at a time, but this would be advantageous only when keys are
         ⍝ added or deleted generally in order, which isn't necessarily likely to be the case.
         :If (at+2)≤≢pptrs ⍝ Check right sibling (if any) for sufficiency
         :AndIf bmin<≢2⊃sibling←⎕FREAD tn,sib←pptrs[sibat←at+2] ⍝ Does it have enough?
             leaf←=/≢¨ptrs keys ⍝ Is it a leaf?
             ⍝ Rotate successor key/pointer down from parent node
             ptrs,←pptrs[at+1] ⋄ keys,←pkeys[2÷⍨at+1]
             :If ~leaf ⍝ We're working with branch nodes - handle an extra subtree pointer
                 ⍝ Rotate first subtree pointer from beginning of right sibling to me
                 ptrs,←1↑1⊃sibling ⋄ (1⊃sibling)↓⍨←1
             :EndIf
             ⍝ Rotate right sibling's first key/pointer up into parent node
             pptrs[at+1]←⊣/1⊃sibling ⋄ pkeys[2÷⍨at+1]←⊣/2⊃sibling
             sibling↓¨⍨←1 ⍝ Remove first key/pointer from right sibling

         :ElseIf (at-2)≥1 ⍝ Check left sibling (if any) for sufficiency
         :AndIf bmin<≢2⊃sibling←⎕FREAD tn,sib←pptrs[sibat←at-2] ⍝ Does it have enough?
             leaf←=/≢¨ptrs keys ⍝ Is it a leaf?
             ⍝ Rotate predecessor key/pointer down from parent node
             ptrs,⍨←pptrs[at-1] ⋄ keys,⍨←pkeys[2÷⍨at-1]
             :If ~leaf ⍝ We're working with branch nodes - handle an extra subtree pointer
                 ⍝ Rotate last subtree pointer from end of left sibling to me
                 ptrs,⍨←⊢/1⊃sibling ⋄ (1⊃sibling)↓⍨←¯1
             :EndIf
             ⍝ Rotate left sibling's last key/pointer up into parent node
             pptrs[at-1]←⊢/1⊃sibling ⋄ pkeys[2÷⍨at-1]←⊢/2⊃sibling
             sibling↓¨⍨←¯1 ⍝ Remove last key/pointer from left sibling

         :Else ⍝ Rotation not available - must merge a sibling
             :If (at-2)≥1 ⍝ Might as well merge the left one, since we have it in hand
                 keys,⍨←pkeys[2÷⍨at-1] ⍝ Prefix my keys with the left separator from parent
                 pkeys/⍨←(⍳≢pkeys)≠2÷⍨at-1 ⍝ ... and remove it from parent
                 ptrs,⍨←pptrs[at-1] ⍝ Prefix pointers with parent key pointer
                 pptrs/⍨←~(⍳≢pptrs)∊at-1 2 ⋄ at←at-2 ⍝ ... and remove left sibling & separator pointers from parent
                 (ptrs keys),⍨←sibling ⍝ Merge left sibling to mine
             :ElseIf (at+2)≤≢pptrs ⍝ Ok, then we have to merge the right one instead (it's still in hand here)
                 keys,←pkeys[2÷⍨at+1] ⍝ Suffix my keys with the right separator from parent
                 pkeys/⍨←(⍳≢pkeys)≠2÷⍨at+1 ⍝ ... and remove it from parent
                 ptrs,←pptrs[at+1] ⍝ Suffix pointers with parent key pointer
                 pptrs/⍨←~(⍳≢pptrs)∊at+1 2 ⍝ ... and remove right sibling & separator pointers from parent
                 (ptrs keys),←sibling ⍝ Merge right sibling to mine
             :Else
                 'No sibling available for merging'⎕SIGNAL 23
             :EndIf
             free∪←sib ⍝ Mark sibling component to be discarded later
         :EndIf

         :If ~sib∊free ⍝ If there's anything to update in the sibling
             free∪←sib ⍝ Mark the original component # to be discarded later anyway
             sib←tn _append sibling ⍝ Add the new version as a substitute
             pptrs[sibat]←sib ⍝ Tell parent to point to the revised copy instead
         :EndIf
     :EndWhile

     :If ~(1⊃path)∊free ⍝ Only update the primary node if we're not deleting (due to merging) it
         lptr←tn _append ptrs keys ⍝ Add the new version as a substitute
         pptrs[at]←lptr ⍝ Tell parent to point to the revised copy instead
         free∪←1⊃path ⍝ Mark original to be discarded later (since it wasn't already)
         (1⊃path)←lptr ⍝ Make a note that we're routing to the new #, too
     :EndIf
     pptrs pkeys ⎕FREPLACE tn,2⊃path ⍝ And the parent has changed as well

     ⍝ Finally, check to see if the root has gone away and replace it with sole child if so
     :If (2≥≢path)∧(0=≢pkeys)∧1=≢pptrs ⍝ Have we collapsed the root to nothing at all?
     :AndIf pptrs≡1↑path ⍝ (And a safety check to make sure it's really us)
         ⍝ Remove it from the tree by replacing it with my merged node (happens infrequently)
         free∪←1⊃path ⍝ Discard only child (that got moved to root)
         ((pptrs pkeys)←ptrs keys)⎕FREPLACE tn,2⊃path ⋄ (ptrs keys)←bmin⍴¨0 0
     :EndIf
 :Until bmin≤≢pkeys ⍝ The parent node now has sufficient keys - all done

 :If 1=≢path ⍝ Are we at the root?
 :AndIf ∧/0=≢¨⎕FREAD tn,path ⍝ and is it empty?
     ⍬(0⍴⊂⍬)⎕FREPLACE tn,path ⍝ The whole tree is now entirely empty - force the prototype key to ⍬
 :EndIf
∇

∇ subs←(io _subscript)term;t
⍝ Decode a user specification of a name with optional subscripts
⍝ Subscripted names are of the form: "name[subscript]".
⍝ Any name of this form is considered to be subscripted and is not used as a raw value.
⍝ Subscripts may be of any number of dimensions, each dimension separated by ';'.
⍝ All simple text names (subscripted or not) have leading and trailing spaces trimmed off.
⍝ All subscripts are themselves trimmed and positive integer representations are converted to numbers.
⍝
⍝ No checking is done of any required subscripts, only the values present or not present are returned.
⍝
⍝ In the future, some special kinds subscripts will be processed here. Until that time, those special
⍝ cases will be reserved. This code will enforce those reservations until it is time to process them.
⍝
⍝ Result:
⍝       If the argument is not a subscripted name, then it is returned just the same as it was given,
⍝           but enclosed as the first and only item of the nested vector result.
⍝       If the argument is subscripted, it is decomposed and returned as follows:
⍝           [1]  ←  Base component name followed by an empty subscript notation ('FOO[;…;]')
⍝                   If base component name is empty then this result is left entirely ''
⍝           [2+] ←  Parsed subscripts, one per rank.
⍝                   Empty subscript elements produce '' items.
⍝                   Numeric subscript elements are decoded.

 subs←,⊂term ⍝ Start by assuming non-subscripted result
 :If (0 2∊⍨10|⎕DR term)∧1=≢⍴term ⍝ If this is a simple character vector, do some friendly processing on it
 :AndIf ×≢⊃subs←,⊂term←∆dlt term ⍝ Trim simple text, even if it's not subscripted
 :AndIf (1=≢term∩'[')∧(1=≢term∩']')∧(']'=⊢/term)∧'['≠⊣/term ⍝ Subscripts must have exactly one '[' and one ']' and end with ']' but not begin with '['
     subs←(t←term⍳'[')↓¯1↓term ⋄ term←∆dlt(t-1)↑term ⍝ Split off root name
     subs←∆dlt¨1↓¨(1,subs∊';')⊂';',subs ⍝ Split apart dimensions
     :If ∨/t←(×≢¨subs)∧∧/¨subs∊¨⊂⎕D ⍝ Look for numeric subscripts (non-negative integers)
     :AndIf ∨/t∧←(~∧/¨subs='0')∨io=0 ⍝ Special-case '0'=char if ⎕IO=1
     :AndIf ∨/t\9≥≢¨t/subs ⍝ Allow up to 9-digit integer numerics
         (t/subs)←(io=0)+(⊃2⊃⎕VFI)¨t/subs ⍝ Decode all-numeric subscripts
     :EndIf
     'The subscript "⎕" is reserved for future use'⎕SIGNAL 16/⍨(⊂,'⎕')∊subs
     'The subscript "," is reserved for future use'⎕SIGNAL 16/⍨(⊂,',')∊subs
     'Subscripts beginning with "⍎" are reserved for future use'⎕SIGNAL 16/⍨'⍎'∊⊃¨subs
     subs←(⊂term,(×≢term)/'[',(';'⍴⍨1-⍨⍴subs),']'),subs ⍝ Return final result
 :EndIf
∇

∇ nextkey←(tn _successor root)key;ptrs;keys;at;path;found
⍝ Find the successor (or first) key value in a B-tree (⍬ if non-existant)

 :If ∧/0=≢¨key ⍝ Are we looking for the lowest (first) key in the tree?
     nextkey←2⊃(tn _lowest root)⍬ ⍬ ⍝ We only return the (first) key value itself
 :Else
     found←0≠⊃path←(tn _find(-root))key
     :While ×≢path←1↓path
         (ptrs keys)←⎕FREAD tn,1 1⊃path ⋄ at←(1 2⊃path)-~found
         :If at<(≢keys)+found∧≠/≢¨ptrs keys ⋄ :Leave ⋄ :Else ⋄ found←0 ⋄ :EndIf
     :EndWhile
     :If 0=≢path
         nextkey←⍬
     :ElseIf found∧≠/≢¨ptrs keys
         nextkey←2⊃(tn _lowest((1+2×at)⊃ptrs))⍬ ⍬ ⍝ Look for the lowest key value in the following sub-tree
     :Else
         nextkey←(1+at)⊃keys
     :EndIf
 :EndIf
∇

∇ used←fences(tn _validate root)rank;t;ptrs;keys;master;r;p;posts;u;x;bmax;bmin
⍝ Validate the B-tree recursively starting at the node {root} and return used/indexed component numbers.
⍝ If rank=¯1 (root will be 1), some keys may point to subdirectory B-trees which need to be recursively analyzed and included in the result.
⍝ If rank≠¯1, all key values must imply the given rank: each a vector (if rank>0) of sub-keys where rank=≢key
⍝ {fences} contains lower and upper bounds on the possible key values in the node, or '∞' if unbounded at that end

 'Damaged file!  Non-numeric file component number in referring directory'⎕SIGNAL 23/⍨~(1 3∊⍨10|⎕DR root)∧⍬≡⍴root
 ('Damaged file!  No such file component number for directory: ',⍕root)⎕SIGNAL 23/⍨(root<1⊃⎕FSIZE tn)∨(root≥2⊃⎕FSIZE tn)∨root≠⌊|root
 :If (,2)≢⍴x←⎕FREAD tn,used←,root ⍝ Is it the right shape & size?
 :OrIf ~(∧/1=(≢⍴)¨x)∧(1≤|≡2⊃x)∧(1=|≡1⊃x)∧1 3∊⍨10|⎕DR 1⊃x ⍝ And does it have the right structure & datatypes
 :OrIf (≠/≢¨x)∧≠/0 1+1 2×≢¨x ⍝ And do the two halves have B-tree-compatible lengths?
     ('Damaged file!  Invalid directory structure in: ',⍕root)⎕SIGNAL 23
 :EndIf
 (ptrs keys)←x ⍝ Separate into halves for easier processing
 master←rank=¯1 ⍝ Are we checking the master file directory (special rules apply)?
 bmax←4⌈⌊|⊃∊TreeSize ⋄ bmin←¯1+⌈bmax÷2 ⍝ Adjustable B-tree size
 ('Damaged file!  Scalar names found in directory in: ',⍕root)⎕SIGNAL 23/⍨0∊(≢⍴)¨keys~⎕UCS master/0 127
 ('Damaged file!  Empty names found in directory in: ',⍕root)⎕SIGNAL 23/⍨∨/(0∊⍴)¨keys
 ('Damaged file!  Duplicate names found in directory node in: ',⍕root)⎕SIGNAL 23/⍨~∧/≠keys
 ('Damaged file!  Empty directory has bad prototype in: ',⍕root)⎕SIGNAL 23/⍨(0=≢keys)∧⍬≢⊃keys
 ('Damaged file!  Directory not in sorted order in: ',⍕root)⎕SIGNAL 23/⍨((⍳≢)≢⍋)(fences[1]~'∞'),keys,fences[2]~'∞'
 ⍝ ('Damaged file!  Directory branch not within standard size range: ',⍕root)⎕SIGNAL 23/⍨(bmax<≢keys)∨(bmin>≢keys)∧fences≢'∞' '∞' ⍝ Ok if TreeSize has changed!
 :If rank≥0 ⍝ Make sure all subscripts have the right number of sub-elements
     ('Damaged file!  Directory subscripts of improper rank: ',⍕root)⎕SIGNAL 23/⍨~∧/rank=≢¨keys
 :EndIf

 ⍝ Process this node one key (and separator) at a time
 :If =/≢¨ptrs keys ⍝ Is this a leaf node?
     r←master _keyrank¨keys ⍝ Which keys might have a specific-rank subdirectory?
     used,←(r=0)/ptrs ⍝ The rest of them are just scalar data pointers
     :For p r :InEach ((r≠0)/ptrs)(r~0) ⍝ Check subscripted names recursively
         used,←'∞' '∞'(tn _validate p)r ⍝ Analyze the subdirectory tree from its root
     :EndFor
 :Else ⍝ This is a branch node
     posts←fences[1],keys,fences[2] ⋄ u←⍬ ⍝ New fence posts for children
     :While ×≢ptrs
         used,←(2↑posts)(tn _validate(⊣/ptrs))rank ⍝ Check subtree preceeding next key
         (ptrs posts)↓⍨←1 ⍝ Subtree and preceeding post are complete
         :If ×≢keys ⍝ Examine next key
             :If ×r←master _keyrank⊃keys ⍝ We have a subdirectory for this key
                 used,←'∞' '∞'(tn _validate(⊣/ptrs))r ⍝ Analyze the subdirectory tree from its independent root
             :Else
                 u,←⊣/ptrs ⍝ Just note a straight data component (quickly)
             :EndIf
             (ptrs keys)↓⍨←1 ⍝ Key plus data/subtree pointer is complete
         :EndIf
     :EndWhile
     used,←u ⍝ Append short list accumulated from node to full list - faster than repeatedly appending to full list
 :EndIf

 ⍝ Check built-in file component management data
 :If master ⍝ Codes only present in master directory; only check once at top-of-file
     :If ×t←⊃(tn _find(-root))⎕UCS 0 ⍝ Have any component numbers been reserved?
         used,←x←⎕FREAD tn,t
         'Damaged file!  Reserved component list is invalid'⎕SIGNAL 23/⍨~{((,1)≡⍴⍴⍵)∧1 3∊⍨10|⎕DR ⍵}x ⍝ Require integer vector
     :EndIf
     :If ×t←⊃(tn _find(-root))⎕UCS 127 ⍝ Have any component numbers been freed (available for re-use)?
         used,←x←⎕FREAD tn,t
         'Damaged file!  Free component list is invalid'⎕SIGNAL 23/⍨~{((,1)≡⍴⍴⍵)∧1 3∊⍨10|⎕DR ⍵}x ⍝ Require integer vector
     :EndIf
 :EndIf
∇

:EndNamespace 
