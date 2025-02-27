#!/usr/bin/env bash

# Update this to the coverage file you want to upload to the standards repo
COVERAGE_SOURCE_FILE=${COVERAGE_SOURCE_FILE}

# -=- Nothing below here should need to be changed -=-

echo "Starting the coverage data push to the standards repo..."
echo "Generating the SHA.txt file"
PROJECT_NAME=$(basename `git rev-parse --show-toplevel`)
echo $PROJECT_NAME
echo "Seeing if there are any non-.github/ changes"
LAST_MERGE_COMMIT=$(git log --merges -n 2 --format=%H | tail -1)
NON_CI_DIFF_FILES=$(git diff HEAD $LAST_MERGE_COMMIT --name-only | grep -v ^.github/)
if [[ -z $NON_CI_DIFF_FILES ]]; then
  echo "Only .github/ files found, skipping upload"
  exit 0;
else
  echo "Found non-.github/ files"
  echo $NON_CI_DIFF_FILES
fi
COVERAGE_SHA=$(git rev-list HEAD | head -1)
echo $COVERAGE_SHA > SHA.txt
echo "Processing coverage for report belonging to latest commit"
echo "Calling https://api.codecov.io/api/v2/gh/codecov/repos/$PROJECT_NAME/commits/$COVERAGE_SHA"
PROD_COVERAGE=$(curl "https://api.codecov.io/api/v2/gh/codecov/repos/$PROJECT_NAME/commits/$COVERAGE_SHA"| \
python3 -c "import sys, json; print(json.load(sys.stdin)['totals']['coverage'])")
echo "Validating if production coverage is a number"
if ! [[ $PROD_COVERAGE =~ ^[0-9]+([.][0-9]+)?$ ]] ; then
  echo "error: Not a number" >&2; exit 1
fi
echo "Generating coverage_totals.txt file"
echo $PROD_COVERAGE > coverage_totals.txt
echo "Cloning the standards repo in the parent directory"
cd ..
git clone https://codecov:${GH_TOKEN}@github.com/codecov/standards.git
cd standards
echo "Deleting content in coverage_data if it exists"
COVERAGE_DEST_DIR="coverage_data/$PROJECT_NAME"
rm -rf $COVERAGE_DEST_DIR
echo "Commiting deletion of coverage data"
git config --global user.email "devops@codecov.io"
git config --global user.name "Codecov Devops"
git add .
git commit -m "Deleting existing coverage data for $PROJECT_NAME with SHA $COVERAGE_SHA"
echo "Recreating coverage directory"
mkdir -p $COVERAGE_DEST_DIR
echo "Copying the coverage file and SHA.txt to the coverage directory"
cp ../$PROJECT_NAME/$COVERAGE_SOURCE_FILE $COVERAGE_DEST_DIR/
cp ../$PROJECT_NAME/SHA.txt $COVERAGE_DEST_DIR/
cp ../$PROJECT_NAME/coverage_totals.txt $COVERAGE_DEST_DIR/
echo "Commiting and pushing the coverage data to the standards repo."
git add coverage_data
git commit -m "Updating coverage data for $PROJECT_NAME with SHA $COVERAGE_SHA"
git push origin --force
echo "Push to upstream complete!"
