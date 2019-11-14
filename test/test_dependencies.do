*! version 0.1  11nov2019  Diana Goldemberg, diana_goldemberg@g.harvard.edu

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
dependencies, which

* Remove: without prior use, should say 'empty' but not give any error
dependencies, remove



**********************
*****   Freeze   *****
**********************


* Test with and without full path
qui cd "${mypath}/test"

* Ensure that preserve/restore is okay
qui sysuse auto, clear

* Those quotes do no harm, though not needed
dependencies, freeze adolist(iegraph iematch)   using(test_me.zip)   replace
dependencies, freeze adolist("iegraph iematch") using("test_me.zip") replace

* NOT OKAY: without the replace, there will be an error
//dependencies, freeze adolist(iegraph iematch)   using(test_me.zip)

* Specifying the package makes it redundand to specify its components
dependencies, freeze adolist(ietoolkit) using(test_me.zip) replace
dependencies, freeze adolist(ietoolkit iegraph iematch) using(test_me.zip) replace

* Specifying ados that dont exist gives an error but doesnt break
dependencies, freeze adolist(iegraph fakename) using("test_me.zip") replace

* Full path or semi-full path is equally okay
qui cd "${mypath}"
dependencies, freeze adolist(ietoolkit) using("${mypath}/test/test_me.zip") replace
qui cd ../..
dependencies, freeze adolist(ietoolkit) using("${mypath}/test/test_me.zip") replace


* Given that I had version 5.2 of ietoolkit installed, I will freeze and save to the repo
//dependencies, freeze adolist(ietoolkit) using("${mypath}/test/ietoolkit_v52.zip") replace


* Use option -all-
dependencies, freeze all using("${mypath}/test/test_me.zip") replace



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
dependencies, unfreeze using(test_me.zip)

* Full path is equally okay
qui cd ..
dependencies, unfreeze using("${mypath}/test/test_me.zip")

* Unfreeze older version of ietoolkit package
dependencies, unfreeze using("${mypath}/test/ietoolkit_v52.zip")


* Check that some files (like this component of ietoolkit.pkg) will have old/new versions
* Yet, the one that comes with 'priority' is the old one, in dependencies
which iegraph, all



**********************
*** Which / Remove ***
**********************

* Which: after prior use, should list ado files
dependencies, which

* Remove: after prior use, should wipe out dependencies
dependencies, remove

* Which: after remove, should accuse `empty' again
dependencies, which

* And the adofile that will come will be only the new version again
which iegraph, all


exit
