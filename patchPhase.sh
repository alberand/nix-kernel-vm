local -a patchesArray
patchesArray=( ${patches[@]:-} )
for p in "${patchesArray[@]}"; do
  echo "applying patch $p"
  cat $p | patch -p1
done
