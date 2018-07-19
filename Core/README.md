# Kitt Core

This repo is now just the sources, supporting scripts and (outdated) documentation. XCode project produces a library, not an application.It is supposed to go to branding-specific XCode projects as submodule and be a dependency of the branding-specific compilation. This approach is awkward, but less so than duplicating the whole tree around. This way, it will just require some extra git drill whenever the submodule is changed in either of the importing brand projects. Because this kitt "core" will be changing all the time, on behalf of different projects. Which kind of goes against the grain of how submodules are perceived (mostly readonly 3rd party libs). The ultimate goal is to gradually rearchitect/modularize/rip apart the core so that only "stable" parts stay, and all the fluctuation goes to the branding projects. But it's a long shot into the darkness. At the moment it's not even known what everything will be removed/added/modified on behalf of the first known branding.

## Build Instructions
In order for the targets to build successfully, you must first run 'npm install' in the root directory.

