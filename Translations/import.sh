# import routine for new languages

# run these scripts before importing from crowdin
# sed -i "x" 's/\"en-US\"/\"en\"/g' *.xliff
# sed -i "x" 's/\"AdBlockBrowser\/Localizable\.strings\"/\"AdBlockBrowser\/en\.lproj\/Localizable\.strings\"/g' *.xliff
# sed -i "x" 's/\"ExtensionShare\/Localizable\.strings\"/\"ExtensionShare\/en\.lproj\/Localizable\.strings\"/g' *.xliff

TRANSLATIONS=$1

for file in AdBlockBrowser/*.lproj
do
  filename=$(basename "$file")
  filename="${filename%.*}"
  if [ ! -f "${TRANSLATIONS}/${filename}.xliff" ] && [ "${filename}" != "Base" ]
  then
    printf "\e[0;31mXliff for localization ${file} doesn't exist\e[0m\n"
  fi
done

# import translations
for file in "${TRANSLATIONS}"/*.xliff
do
  printf "\e[0;32mImporting ${file}\e[0m\n"
  xcodebuild -importLocalizations -localizationPath "${file}" -project ./AdblockBrowser.xcodeproj
done
