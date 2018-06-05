### Exporting base language

Current "known" english import in Crowdin (which other language's completenes is derived from) has two glitches in it:

#### Issue 1: wrong `source-language` attribute

Currently exported source (development) language code is `en`. The existing export however has `en-US` which gets **ignored** since XCode7 (it worked in XCode6). This is being attempted to fix by reimporting a fresh `en.xliff` with `en` language code next time. **@TODO document the result next time**

#### Issue 2: wrong `<file original>` path

Some past XCode version which was used for initial localization round, did probably export different paths than later versions - at least XCode6.3 and XCode7.x

Previous: `/AdblockBrowser/Localizable.strings`

Current: `/AdblockBrowser/en.lproj/Localizable.strings`

**Mind that this applies only to `Localizable.strings` not `InfoPlist.strings`**

The new path (when imported) is considered a new localization by Crowdin, and existing languages are thrown away. Ideally the file is migrated by Crowdin (support request underway). Until done so, manual path switching is necessary:

**When exporting to Crowdin: `en.xliff`**

`(<file original="\w+?)\/en.lproj\/Localizable.strings"` => `$1/Localizable.strings`

**When importing to XCode: `*.xliff`**

`(<file original="\w+?)\/Localizable.strings"` => `$1/en.lproj/$2`

### Crowdin


1. Make sure the export filenames are configured as follows:
   
   `Core.strings` => `/core/%osx_code%/Localizable.strings`
   
   `UI.xliff` => `/%osx_locale%.xliff`
   
   This produces underscore country separators instead of dashes, but is still the best option. See **Crowdin bugs** below.

2. Click Build Project
3. Download whole project or specific languages

### Import

#### 1. unzip zip(s)

will get subfolders `ui` and `core`

#### 2. delete `en*` translations

these **must not** be overwritten to retain clean mergeable source

#### 3. rename `language_Country` to `language-Country`

Applies namely to `zh`, `es`, `pt` and a few more. File/folder names as well as inside related XLIFF. This is an unfortunate result of Crowdin `%osx*%` naming tokens being outdated.

#### 4. Prevailing country tweak

**Does NOT apply to chinese `zh-*` as it does not have a prevailing primary country**

**Spanish**

Is exported by Crowdin as `Spain Spanish` despite it being a generic Spanish in the web UI. If it was imported like this, Mexican Spanish would have no fallback and display English.

1. rename `es-ES.xliff` to `es.xliff` (drop the `country` specifier)
2. the file content can be left as is. Target language is correctly `"es"` there (regardless of the file being still wrongly named `es-ES`)

**Portuguese**

More complicated due to a bug in iOS8. iOS8 is failing to recognize `pt-BR` and maps _Portuguese (Brazilian)_ to plain `pt`. iOS9+ does it right. Meanwhile _Portuguese (Portugal)_ is mapped correctly to `pt-PT` in both iOS8 and 9. So for _Portuguese (Brazilian)_ to work correctly on both iOS versions, the _default language country_ (`pt` without specifier) must be **Brazilian**.  Portugal Portuguese is mapped to a country subtype `pt-PT`.

1. `pt-PT.xliff` can be left as is. Correctly it should be named `pt.xliff` (it's declared without country specifier in Crowdin) at which situation it would have to be renamed to `pt-PT.xliff`
2. open `pt-PT.xliff` and rename all occurences of `"pt"` to `"pt-PT"` (mind the quotes)
3. rename `pt-BR.xliff` to `pt.xliff`
4. open `pt.xliff` and replace all occurences of `"pt-BR"` to just `"pt"` (mind the quotes)
 
### Xcode

1. verify that the diffs of `Core/Resources/Localizable.strings/` are what was expected
2. verify that the diffs of `Translations/*.xliff` are what was expected
3. Editor/Import Localizations all changed xliffs

**If nothing gets imported (existing translations cleared), check compliance of `source-language` attribute. Should be equal to the latest XCode export. (Used to be `en-US`, now is `en`, can change again)**


### Crowdin bugs

1. Exports languages with default country even if it's qualified as country-unspecific (`pt-PT` instead of `pt`, `es-ES` instead of `es`). This used to apply to both filename and the language codes inside XLIFF, now it is just the filename.

2. Exports languages with wrong variants - namely `zh-CN`, `zh-TW` instead of `Hans`/`Hant` despite the languages being qualified as Simplified/Traditional, not China/Taiwan. **Can be overriden with custom export file naming.**

3. `%osx*%` tokens are outdated, as it produces underscore separators (`es_MX`), which was already deprecated by Xcode in favor of dashes (`es-MX`). Unfortunately it's the only way to get country-less codes for languages with prevailing primary country, as expected by Xcode. The only alternative producing dashes is `%locale%` but it attaches country to everything.

4. escapes  " \(variableName)" - controversial
