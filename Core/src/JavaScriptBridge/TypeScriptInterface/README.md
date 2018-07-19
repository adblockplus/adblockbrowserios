MODULARIZATION GUIDELINE
------------------------

### modules
```bridge.ts```: native bridge implementation

```api_(base|full).ts```: "_browser abstraction_" goes between chrome functions implementation and the native bridge.

Separation to two files is necessary to limit the raw amount of JS code being injected for each content script.

```chrome_(base|full).ts```: constructs complete chrome-like object out of the separate modules in ```chrome``` subfolder. Uses respective ```api_*.ts``` module.

**userscript-facing but not chrome-specific implementations**
```XMLHttpRequest``` and ```console``` window objects

### chrome
**modules per each (partially) implemented chrome namespace**

- returns objects with chrome-compliant function signatures
- does not require the API module, instead takes the reference as parameter to abstract from full/partial knowledge


### main_* : toplevel starting modules required by browserify

**background**

- sets up global callback entry
- instantiates native caller with addon context
- instantiates **full** API
- exports set of objects used by client scripts

**popup**

- dtto plus function to override window.close (not available in background)

**content_callback**

- injected once per webview tab
- sets up global callback entry
- no API needed

**content**

- used per each injected content script separately
- does not set up callback entry
- native caller with addon and tab id context
- instantiates **base** API

