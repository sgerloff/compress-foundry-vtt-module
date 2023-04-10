#!/usr/bin/env nu

def main [
    source_dir: string
    --output: string = "bundled_modules.zip"
] {
    let $current_dir = (pwd)
    cd $source_dir
    let zip_file_list = (ls | get name | filter {|it| $it | path parse | $in.extension == "zip"})
    for zip_file in $zip_file_list {
        print $zip_file
        let extract_dir = ($source_dir | path join ($zip_file | path parse | $in.stem))
        unzip -d $extract_dir $zip_file
        ^zip -m -u -r $output $extract_dir
    }
}