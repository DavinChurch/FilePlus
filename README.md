# Introduction to FilePlus
This document describes a Dyalog namespace that contains a set of component file management routines written in APL by Davin Church of Creative Software Design for use in APL applications.  Use of this code for any purpose is hereby granted, but credit (comments left inside the code, for instance) is requested and modification is not generally recommended (to allow for later updates).  Dyalog APL v17.0 or later is required.

These functions implement a simple and high-performance method of using named components in Dyalog component files.  They are designed as extensions to the standard file system and may be used in conjunction with the native `⎕F…` system functions.  Both numbered and named components can coexist in the same file and operations may be performed interchangeably.

Of course, most APL programmers have written similar tools over the years, sometimes several different sets of such tools.  But many of them have often had significant restrictions, inflexibility, bugs, or efficiency concerns to deal with.  This set of tools does not have any significant drawbacks of this sort and are well-suited for general use for all but the most extreme application needs.  These functions are being distributed in the hopes that they may satisfy any and all future named-component file needs, without any need to “reinvent the wheel” when such facilities are desired.

The mere fact that many programmers have created such tools time after time for many different purposes points to their general usefulness.  The reason they are not more widely used likely has a lot to do with the bother in producing a useful and efficient system while in the midst of writing an application.  With tools like these readily available they often make application coding easier in several respects, even when it isn’t otherwise important enough to build a custom system for those needs.

## Overview
The following functions are available for use:
| Name | Purpose |
| ---- | ------- |
| `IO` | Read, replace, or append a named (or numbered) component. |
| `Dir` | Perform named-component directory management, if needed. |
| `Tie` | Tie and untie files.  (Only needed if special functionality is desired.) |
| `Create` | Create a new file.  (Only needed if special functionality is desired.) |

## General Notes
Component names can be almost any APL value except for empty arrays and simple scalars.  Simple character scalars are accepted but raveled before use.  Component names that are simple character vectors are further processed for more convenient use but other names are used exactly as given.  Therefore it is reasonable to use matrices, nested arrays, etc. of any reasonable size, shape, depth, or type as component names.  (Floating point values are discouraged within a component name due to representational rounding difficulties.)

In addition, component names that are simple character vectors have been extended to allow the use of “array components”.  This means that a single name may be followed by a subscript notation (in traditional APL form) to create a component that is an item of a vector (or other array of any rank).  These subscripts may be integers as usual for APL, but they need not begin at `⎕IO` nor do they need to be consecutive.  In addition, subscripts may themselves be names, and names and integers may be mixed within the same dimension.

Component arrays may be of any rank and any size and even extremely large component arrays are stored and accessed very efficiently with high-performance B-Tree data structures.  In addition, an array and a non-array component can have the same base name, as can arrays of multiple ranks.  In other words, components named `FOO`, `FOO[]`, `FOO[;]`, `FOO[;;]`, etc., can all exist in the same file at the same time.

# Repository Organization

This is a member of the APLTree project at https://github.com/aplteam/apltree.

## The Distribution Directory

This directory contains a workspace copy of the code for those that desire that form.  However, it is expected that most distribution will be done with the individual source code text files in the Source directory.

## The Documentation Directory

This directory contains a PDF file with extensive documentation on the toolkit and its components.  It begins with an introduction
and overview of the package.  It then goes on to describe the flexible types of component naming that are supported and some suggestions on how these tools might be used.  Finally it gives a quick reference on the use of the tools followed by detailed descriptions of all the public functions.


## The Source/FilePlus Directory

This directory is intended to be imported and used as a complete namespace and contains all the code needed to use this package.  Locally-assigned references to any of the functions may be placed in the application namespace for easier use, if desired.

## The Source/Testing Directory

This directory is its own namespace which contains facilities for testing all the FilePlus functionality, which is expected to be found in the #.FilePlus namespace.  This code is provided only for testing the main toolkit and is not needed for any application use.

The testing functions herein are provided as related groups of tests to be performed and named Group01, Group02, etc.  Simply execute any of these functions here to test that group.  If all the groups are to be tested, the `Test` function may be invoked with a list of function names (in almost any reasonable structure and format) as a right argument.  These names may include an `*` wild-card character, so `Test '*'` will execute all the functions in the workspace.

For more details on using `Test` and the testing engine, see the `Tester` package in the companion repository.