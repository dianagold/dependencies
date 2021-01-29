# Dependencies
Stata command for managing user-written commands required in a project (_dependencies_) to ensure reproducibility of all code, as ado files available online may change.
This is achieved by freezing the current version of installed packages into a zip file, and later unfreezing it into an adopath that takes top priority.

## Package description

'DEPENDENCIES': manages required user-written commands (ado version freeze)

Keywords: _dependencies | reproducibility | community-contributed commands | user-written commands | version freeze | adopath_

## Installation

  The most recent version of **dependencies** (version 0.2) is currently published on [SSC](https://www.stata.com/support/ssc-installation/), so it can be installed through this code:
```
ssc install dependencies 
```
  The same version of **dependencies** can be installed using this code:
```
net install dependencies, from("https://raw.githubusercontent.com/dianagold/dependencies/master/src") replace
```

  Please check the help file, installed with the package, for more information on how to use **dependencies**.


## Author

  **Diana Goldemberg** [ [diana_goldemberg@g.harvard.edu](mailto:diana_goldemberg@g.harvard.edu) ]

### Acknowledgements

Kristoffer Bjarkefur and Joao Pedro Azevedo provided invaluable contributions to this package. The idea for the command was originated in this [statalist discussion](https://www.statalist.org/forums/forum/general-stata-discussion/general/1523554-version-control-of-user-written-ados). A big thank you to all contributors creating commands for the Stata community, especially in SSC! Without your time and effort, this command would be useless.
