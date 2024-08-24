mkdir ./release/
rm ./release/release.gma
../../../bin/gmad.exe create -folder "./" -out "./release/release.gma"
echo "$1"
../../../bin/gmpublish.exe update -addon "./release/release.gma" -id "2256491552" -changes "$1"