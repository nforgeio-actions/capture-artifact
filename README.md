# capture-artifact

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Uploads a file to a folder in the nforgeio/artifacts repo, prefixing the file name with a UTC timestamp.

## Examples

**Capture an artifact to the TESTS directory:**
```
- uses: nforgeio/capture-artifact@master
  with:
    path: "C:\Hello World.txt"
    folder: "TESTS"
```

**Capture an artifact to the FOOBAR directory using the GREETING.TXT file name:**
```
- uses: nforgeio/capture-artifact@master
  with:
    path: "C:\Hello World.txt"
    folder: "TESTS"
    name: "GREETINGS.TXT"
```
