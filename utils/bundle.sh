# Bundles UnicodeMathML for release, i.e. clears out the dist/ directory and
# repopulates it. Run this script from the root of the repository, for example:
# > bash utils/bundle.sh

# check if we're running in the correct directory
if [[ ! -f "utils/bundle.sh" ]]; then
    echo "You must run this script from the root of the UnicodeMathML repository."
    exit 1
fi

# reset dist
DIST_PATH="./dist/"
rm -r "$DIST_PATH"
mkdir "$DIST_PATH"

# populate dist
cp "src/unicodemathml.js" "$DIST_PATH"
cp "src/integration/unicodemathml-integration.js" "$DIST_PATH"

cp "lib/markdeep-1.11.js" "$DIST_PATH"

REGEX="s/\.\.\/unicodemathml\.js/unicodemathml\.js/;s/\.\.\/\.\.\/dist\/unicodemathml-parser\.js/unicodemathml-parser\.js/;s/\.\.\/\.\.\/lib\/markdeep-1\.11\.js/markdeep-1\.11\.js/"
sed "$REGEX" "src/integration/example.md.html" > "${DIST_PATH}example.md.html"
sed "$REGEX" "src/integration/example.html" > "${DIST_PATH}example.html"

# alrighty
echo "Okay. Now all that's left to do is regenerating the parser:"
echo "Open ./utils/generate-parser.html in any browser and move the downloaded file into ./dist/."
