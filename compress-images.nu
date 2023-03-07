#!/usr/bin/env nu


def compress_image [
    input_path: string
    output_path: string
    --quality: int = 25
] {
    cwebp -progress -short $input_path -o $output_path -q $quality
}

def get_output_path [
    input_path: string
] {
    if ($input_path | str ends-with '.webp') {
        (tempfile | lines | first)
    } else {
        ($input_path |path parse | update extension webp | path join)
    }
}

def image_cleanup_step [
    root_path: string
    input_path: string
    output_path: string
] {
    if ($input_path | str ends-with '.webp') {
        mv -f $output_path $input_path
    } else {
        let relative_input_path = ($input_path | path relative-to $root_path)
        let relative_output_path = ($output_path | path relative-to $root_path)
        rg -l $relative_input_path $root_path | lines | each { 
            sd $relative_input_path $relative_output_path $in
        }
        rm $input_path
    }
}

def main [
    path: string
    --quality: int = 25
] {
    let to_translate_list = (fd -e png -e jpg -e jpeg -e webp --search-path $path | lines)
    for $file_path in $to_translate_list {
        let output_path = get_output_path $file_path
        compress_image $file_path $output_path --quality $quality
        image_cleanup_step $path $file_path $output_path
    }
}