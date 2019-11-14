*! version 0.1  11nov2019  Diana Goldemberg, diana_goldemberg@g.harvard.edu

/*------------------------------------------------------------------------------
Freeze and unfreeze versions of user-written ado commands (dependencies)
  into an ado-path that takes top priority (most likely, C:/ado/dependencies)
------------------------------------------------------------------------------*/

cap program drop dependencies
program define   dependencies, rclass

  syntax, [           /// ---------- sub-programs-------------------------------
    freeze            /// save a zip with the dependencies in adolist / all
    unfreeze          /// unzip to DEPENDENCIES ado-path the frozen dependency
    which             /// list whethever is currently in the DEPENDENCIES ado-path
    remove            /// remove the DEPENDENCIES ado-path and all its contents
                      /// ---------- other options -----------------------------
    using(string)     /// using zipfile is mandatory for freeze and unfreeze
    adolist(string)   /// list of ados to be frozen as current installed version
    all               /// freeze everything found in the PLUS ado-path
    replace           /// freeze will replace (overwrite) existing zipfile if found
    ]

    version 13

    * Store pwd to restore after program run
    local saved_pwd `"`c(pwd)'"'
    * To avoid macro expansion problems
    local saved_pwd : subinstr local saved_pwd "\" "/", all

    *---------------------------------------------------------------------------

    * Check that SUB-PROGRAM options specified are consistent
    local command_list freeze unfreeze which remove

    * Tracks how many options were chosen and which one to use (the last one)
    local n_options 0
    foreach option in `command_list' {
      if "``option''" != "" {
        local my_option `option'
        local ++n_options
      }
    }

    if `n_options' > 1 {
      dis as error "Options cannot be combined. Choose only one option in: `command_list'."
      exit 198
    }

    if `n_options' == 0 {
      dis as error "No option specified. Choose one option in: `command_list'."
      exit 198
    }

    *---------------------------------------------------------------------------

    * Check -freze- suboptions: either -all- or -adolist- must be chosen (not both)

    if "`my_option'" == "freeze" {

      if ("`adolist'" == "" & "`all'" == "") | ("`adolist'" != "" & "`all'" != "") {
        dis as error "Freeze must be used with either -all- or -adolist- options."
        exit 198
      }

      * If adolist local is used, rewrites to pass it on to dependencies_freeze
      if "`adolist'" != ""  local adolist "adolist(`adolist')"

    }

    else {

      if ("`adolist'" != "") | ("`all'" != "") {
        dis as error "Only -freeze- accepts the -all- or -adolist- options."
        exit 198
      }

    }

    *---------------------------------------------------------------------------

    * Check the - using - option, mandatory for freeze/unfreeze,
    * must be a *.zip that exists (unfreeze) or can be created (freeze)

    if inlist("`my_option'", "freeze", "unfreeze") {

      if `"`using'"' == "" {
        dis as error "The commands -freeze- and -unfreeze- requires option using(filename.zip)"
        exit 198
      }

      * The zipfile passed in option using must be accessible
      * and we need it to be full path, but the user may have specified relative
      local pwd_using `"`saved_pwd'/`using'"'

      * The goal is to end with local using being a full filepath/filename

      if "`my_option'" == "unfreeze" {
        * Try full path first, that is, pwd_using
        cap confirm file `pwd_using'
        * If it works, great: update to full filename
        if _rc == 0 local using `"`pwd_using'"'
        * Try just what was provided (assume it is already a full path)
        else confirm file `using'
        * If this confirm fails, let it break and display error
      }

      if "`my_option'" == "freeze" {

        * Try full path first, that is, pwd_using
        cap confirm new file `pwd_using'
        * If it works, or exists but set to replace: update to full filename
        if (_rc == 0) | (_rc == 602 & "`replace'" == "replace")  local using `"`pwd_using'"'
        * If it doesn't work because of replace, better error message
        else if (_rc == 602 & "`replace'" != "replace") {
          dis as error `"Must specify -replace- or choose another filename, for `using' already exists."'
          exit 602
        }
        * Try just what was provided (assume it is already a full path)
        else {
          cap confirm new file `using'
          * If it works, or exists but set to replace: nothing to do
          if (_rc == 0) | (_rc == 602 & "`replace'" == "replace") local keepgoing = 1 // useless action, there must be a more elegant way to just continue
          * If it doesn't work because of replace, better error message
          else if (_rc == 602 & "`replace'" != "replace") {
            dis as error `"Must specify -replace- or choose another filename, for `using' already exists."'
            exit 602
          }
          * If not, repeat original error message if the problem is something else
          else if confirm new file `using'
        }
      }

      * To avoid macro expansion problems
      local using : subinstr local using "\" "/", all

      * Now we know `using' is accessible and a full filepath
      * Parse zipfile info into zipdir and zipfn
      _getfilename "`using'"
      local zipfn  "`r(filename)'"
      local zipdir = subinstr(`"`using'"', `"`zipfn'"', "", 1)

      // Lines that helped when debugging quotes issues
      //noi disp as res `"This is using: `using'"'
      //noi disp as res `"This is zipdir: `zipdir'"'
      //noi disp as res `"This is zipfn: `zipfn'"'

      * Test that the using file is a zip
      if substr(`"`zipfn'"', -4, 4) != ".zip" {
        noi dis as error `"The using option must end with .zip - you provided `using'"'
        exit 198
      }

      * Pass it organized to subcommands
      local zip `"zipdir(`zipdir') zipfn(`zipfn')"'

    }

    *---------------------------------------------------------------------------

    * Determines the intended DEPENDENCIES ado-path, which is not needed for freeze
    if "`my_option'" != "freeze" local depfolder `"depfolder(`c(sysdir_oldplace)'dependencies)"'

    * Call appropriate subprogram
    dependencies_`my_option', `depfolder' `zip' `adolist' `all'

    * Change back to original directory
    qui cd `"`saved_pwd'"'

end


*-------------------------------------------------------------------------------


cap program drop dependencies_freeze
program define   dependencies_freeze
* This subprogram:
*   save a zip with dependencies specified in adolist

  syntax, zipdir(string) zipfn(string) [adolist(string) all]

  * This is the only subprogram that will open data, so preserve user-data
  preserve

  * Create tempfolder within zipdir, where files will be copied then zipped
  local tempfolder `"`zipdir'/temp4dependencies"'

  * Check if the folder already exists
  mata : st_numscalar("r(dirExist)", direxists(`"`tempfolder'"'))

  * If not, create it
  if `r(dirExist)' == 0  mkdir `"`tempfolder'"'

  * If yes, erase contents to be sure it won't have conflicting versions of ados
  else dependencies_clear_dir, dir2clear(`tempfolder')

  dis as text _newline "Freezing files..."

  quietly {

    *---------------------------------------------------------------------------

    * Reads information on installed packages

    cap findfile "stata.trk", path(PLUS)
    if _rc != 0 {
      noi dis as text "... could not find stata.trk, will only attempt to freeze standalone files"
    }

    else {
      local stata_trk_dir = subinstr("`r(fn)'", "stata.trk", "", .)

      * Each line is considered a single observation - then parsed later
      import delimited using "`r(fn)'", delimiter(`"`=char(10)'"') clear

      * First character marks: S (source) N (name) D (installation date) d (description) f (files) U(stata tracker) e(end)
      gen marker = substr(v1, 1, 1)

      * Making sense of stata.trk means tagging which lines refer to which pkg (N)
      gen pkg_name = substr(v1, 3, .) if marker == "N"
      forvalues i = 1/`=_N' {
        if marker[`i'] == "S" replace    pkg_name = pkg_name[`i' + 1] in `i'
        if marker[`i'] == "N" local last_pkg_name = pkg_name[`i']
        if inlist(marker[`i'], "d", "e", "f", "D") replace pkg_name = "`last_pkg_name'" in `i'
      }

      *-------------------------------------------------------------------------

      * Option -all- will freeze everything found in stata.trk
      if "`all'" == "all" {
        gen byte to_freeze = 1
        replace  to_freeze = 0 if inlist(marker, "*", "U")
      }

      * Option -adolist- will only freeze the selected commands
      else {
        gen byte to_freeze = 0
        foreach command of local adolist {
          * If the command matches a package name, flag file as to_freeze
          forvalues i = 1/`=_N' {
            if "`command'.pkg" == "`= pkg_name[`i']'" replace to_freeze = 1 in `i'
          }
        }
      }

      * Add some metadata in the first observation
      replace to_freeze = 1 in 1
      replace v1 = `"*! dependencies frozen in $S_DATE"' in 1
      keep if to_freeze == 1

      * Will later export this metadata file (akin to stata.trk) for documentation
      save `"`tempfolder'/dependencies.dta"'
      noi dis as text "... 1 metadata file dependencies.trk"

      * Now deals only with the files to freeze
      keep if marker == "f"
      gen f_name      = substr(v1, 3, .)
      gen full_f_name = `"`stata_trk_dir'"' + f_name
      replace full_f_name = subinstr(full_f_name, "\", "/", .)

      * Some nice info to display
      tab pkg_name
      noi dis as text "... `r(N)' files from `r(r)' packages"

      * Local to keep track of packages and files frozen
      local frozen_pkgs  ""
      local frozen_files ""

      * Loops through all observations (each being a file)
      if `r(N)' > 0 {
        forvalues i = 1/`r(N)' {
          local pkg_to_copy  = pkg_name[`i']
          local file_to_copy = full_f_name[`i']
          _getfilename "`file_to_copy'"
          local filename `"`r(filename)'"'
          * Most important line in this program: copy what needs to be frozen
          copy `"`file_to_copy'"'  `"`tempfolder'/`r(filename)'"', replace
          * Update locals with frozen file and package
          local frozen_pkgs  : list frozen_pkgs  | pkg_to_copy
          local frozen_files : list frozen_files | filename
        }
      }

      * Create the metadata file (akin to stata.trk)
      use `"`tempfolder'/dependencies.dta"', clear
      keep v1
      export delimited using `"`tempfolder'/dependencies.trk"', delimiter(`"`=char(10)'"') novarnames replace
      * The dta was only created to avoid messing up with the possibly preserved userdata
      * but we don't want it saved in the zipfile
      erase `"`tempfolder'/dependencies.dta"'

    * End of section that depends on stata.trk
    }

    *---------------------------------------------------------------------------

    * Option -adolist- will also search for stand-alone commands
    if "`adolist'" != "" {

      * Local to keep track of stand-alone files frozen
      local n_standalone_files = 0

      foreach command of local adolist {
        foreach ending in ado dlg hlp sthlp {

          local file_to_search = "`command'.`ending'"

          * Search along the current ado-path (first instance)
          cap findfile `"`file_to_search'"'
          if _rc == 0 {
            * Is the file found the same that was already frozen from a package?
            local already_copied : list file_to_search in frozen_files
            if `already_copied' == 0 {
              copy `"`r(fn)'"' `"`tempfolder'/`command'.`ending'"', replace
              local ++n_standalone_files
            }
          }

          * It's okay to not find other endings, but command.ado displays warning
          * unless it was already found and interpreted as a package
          else {
            if "`ending'" == "ado" & strpos("`frozen_pkgs'", "`command'.pkg") == 0 {
             noi dis as error `"Warning! Could not find `command' in adopath. Skipped."'
           }
          }

        }
      }

      if `n_standalone_files' > 0 noi dis as text "... `n_standalone_files' stand-alone files"
    }

    *---------------------------------------------------------------------------

    * Zip all files copied in tempfolder into using zipfile.zip
    cd `"`tempfolder'"'
    zipfile *.*, saving(`"`zipdir'`zipfn'"', replace)
    cd `"`zipdir'"'

  }

  * Erase the tempfolder and all its contents
  dependencies_clear_dir, dir2clear(`tempfolder') rmdir

  dis as text `"Successfully frozen dependencies in `zipdir'`zipfn'"'

end


*-------------------------------------------------------------------------------


cap program drop dependencies_unfreeze
program define   dependencies_unfreeze
* This subprogram:
*   unzip to DEPENDENCIES ado-path the dependency ados

  syntax, depfolder(string) zipdir(string) zipfn(string)

  * Check if the folder already exists
  mata : st_numscalar("r(dirExist)", direxists(`"`depfolder'"'))

  * If not, create it
  if `r(dirExist)' == 0  mkdir `"`depfolder'"'

  * If yes, erase contents to be sure it won't have conflicting versions of ados
  else qui dependencies_clear_dir, dir2clear(`depfolder')

  * Change to the dependencies ado-path (likely C:/ado/dependencies)
  qui cd `"`depfolder'"'

  * Make this folder the top priority ado-path
  * (this allows users to keep same-name ado in another ado-path)
  qui adopath ++ `"`depfolder'"'

  * Copy the specified zip with frozen version
  qui copy `"`zipdir'/`zipfn'"' `"`depfolder'/temp.zip"', replace

  * Extract the frozen version of the dependency
  qui unzipfile temp.zip, replace
  qui erase temp.zip

  * Display warning if no ado was just unfrozen
  qui local ado_files : dir "`depfolder'" files "*.ado", respectcase
  qui local n_ado_files : word count "`ado_files'"
  if `n_ado_files' == 0 {
    dis as error `"Warning! There were no ado files (*.ado) in `zipfn'."'
  }
  else {
    dis as text `"The `n_ado_files' ado files in `zipfn' were unfrozen in `depfolder'."'
  }

  cap confirm file `"`depfolder'/dependencies.trk"'
  if _rc == 0 type `"`depfolder'/dependencies.trk"', starbang

end


*-------------------------------------------------------------------------------


cap program drop dependencies_which
program define   dependencies_which
* This subprogram:
*   list whethever is currently in the DEPENDENCIES ado-path

  syntax, depfolder(string)

  * Check if the folder already exists
  mata : st_numscalar("r(dirExist)", direxists(`"`depfolder'"'))
  if `r(dirExist)' == 0  dis as result `"There is no -dependencies- ado path set up."'

  * Display info about all ados currently in DEPENDENCIES ado-path
  else {

    * Starts by displaying metadata file if it exists
    cap confirm file `"`depfolder'/dependencies.trk"'
    if _rc == 0 type `"`depfolder'/dependencies.trk"', starbang

    local ado_files : dir "`depfolder'" files "*.ado", respectcase
    if `"`ado_files'"' == "" {
      dis as result _newline `"There are no ado files (*.ado) in `depfolder'."'
    }

    else {
      dis as result _newline `"Ado files (*.ado) currently in `depfolder':"' _newline
      foreach  command of local ado_files {
        which `command'
      }
    }

  }

end


*-------------------------------------------------------------------------------


cap program drop dependencies_remove
program define   dependencies_remove
* This subprogram
*   remove the DEPENDENCIES ado-path and its contents

  syntax, depfolder(string)

  * Check if the folder already exists
  mata : st_numscalar("r(dirExist)", direxists(`"`depfolder'"'))

  if `r(dirExist)' == 0  dis as result `"There is no -dependencies- ado path set up (nothing to be removed)."'

  else {

    * Erase any possible contents in folder and the folder itself
    dependencies_clear_dir, dir2clear(`depfolder') rmdir

    * Remove it from the ado-path list
    cap adopath - `"`depfolder'"'
    * The capture prevents errors if the folder was never added to the adopath (ie: unfrozen)

    dis as text `"Successfully removed dependencies ado-path and all its contents (`depfolder')."'

  }

end


*-------------------------------------------------------------------------------


cap program drop dependencies_clear_dir
program define   dependencies_clear_dir
* This auxprogram
*   erase all contents in a folder and optionally also remove the folder

  syntax, dir2clear(string) [rmdir]

  local files2clear : dir `"`dir2clear'"' files "*"
  foreach file of local files2clear {
    erase `"`dir2clear'/`file'"'
  }

  if "`rmdir'" == "rmdir"  rmdir `"`dir2clear'"'

end
