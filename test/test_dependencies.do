*! version 0.2  16nov2019  Diana Goldemberg, diana_goldemberg@g.harvard.edu

/*------------------------------------------------------------------------------
  Tests the dependencies.ado before making it available in SSC
------------------------------------------------------------------------------*/


**********************
**** Test set-up  ****
**********************

* Option 1 - after cloning the repo in Github

* Sandbox: my local clone of repo
global mypath "C:/Users/`c(username)'/Documents/GitHub/dependencies"

* Load the package from the clone
qui do "${mypath}/src/dependencies.ado"


* Option 2 - install pkg on the fly from web

//* Sandbox: wherever you plan to run this test.do and save the dependencies.zip
//global mypath "C:/Users/YOURNAME/WHATEVER/dependencies"
//cap mkdir `"${mypath}/test"'

//* Install the package from the web
//net install dependencies, from("https://raw.githubusercontent.com/dianagold/dependencies/master/src") replace


* Install the package that will be frozen as a test (could be any package but ietoolkit is cool!)
cap which ietoolkit
if _rc == 111 ssc install ietoolkit



**********************
*** Which / Remove ***
**********************

* Which: without prior use, should say 'empty' but not give any error
dependencies which

* Remove: without prior use, should say 'empty' but not give any error
dependencies remove



**********************
*****   Freeze   *****
**********************


* Test with and without full path
qui cd "${mypath}/test"

* Ensure that preserve/restore is okay
qui sysuse auto, clear

* Those quotes do no harm, though not needed
dependencies freeze using test_me.zip, adolist(iegraph iematch) replace
dependencies freeze using "test_me.zip", adolist("iegraph iematch") replace

* NOT OKAY: without the replace, there will be an error
//dependencies freeze using "test_me.zip", adolist(iegraph iematch)

* Specifying the package makes it redundand to specify its components
dependencies freeze using "test_me.zip", adolist(ietoolkit) replace
dependencies freeze using "test_me.zip", adolist(ietoolkit iegraph iematch) replace

* Specifying ados that dont exist gives an error but doesnt break
dependencies freeze using "test_me.zip", adolist(iegraph fakename) replace

* Full path or semi-full path is equally okay
qui cd "${mypath}"
dependencies freeze using "${mypath}/test/test_me.zip", adolist(ietoolkit) replace
qui cd ../..
dependencies freeze using "${mypath}/test/test_me.zip", adolist(ietoolkit) replace

* Given that I had version 5.2 of ietoolkit installed, I will freeze and save to the repo
//dependencies freeze using "${mypath}/test/ietoolkit_v52.zip", adolist(ietoolkit) replace


* Use option -all-
dependencies freeze using "${mypath}/test/test_me.zip", all replace



**********************
*****  Unfreeze  *****
**********************

* NOT OKAY: file doesn't exit in pwd
//cd "`c(sysdir_plus)'"
//dependencies, unfreeze using("test_me.zip")

* NOT OKAY: file ends with wrong extension
* note that this error msg only shows if file exists
//dependencies, unfreeze using("test_me.foo")

* Call right zip name in the right dir
qui cd "${mypath}/test"
dependencies unfreeze using test_me.zip

* Full path is equally okay
qui cd ..
dependencies unfreeze using "${mypath}/test/test_me.zip"

* Unfreeze older version of ietoolkit package
dependencies unfreeze using "${mypath}/test/ietoolkit_v52.zip"


* Check that some files (like this component of ietoolkit.pkg) will have old/new versions
* Yet, the one that comes with 'priority' is the old one, in dependencies
which iegraph, all



**********************
*** Which / Remove ***
**********************

* Which: after prior use, should list ado files
dependencies which

* Remove: after prior use, should wipe out dependencies
dependencies remove

* Which: after remove, should accuse `empty' again
dependencies which

* And the adofile that will come will be only the new version again
which iegraph, all


exit
