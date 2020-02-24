
#### Building conda package

````
$ conda build --debug conda-recipe --output-folder bld-dir -c tidair-packages -c tidair-tag -c conda-forge
$ conda activate
$ anaconda upload bld-dir/linux-64/rogue-.....
````
